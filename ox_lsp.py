#!/usr/bin/env python3
"""
Oxybelis Language Server Protocol (LSP) server.
Provides diagnostics, syntax highlighting (semantic tokens), hover, and completions.

Usage:  python ox_lsp.py            # stdio LSP server (for VSCode, neovim, etc.)
        python ox_lsp.py check <file.ox>   # CLI diagnostic check
"""

from __future__ import annotations

import sys, os, re
import json
import traceback
from dataclasses import dataclass, field
from typing import Optional, List as PyList, Any

_LOG_FILE = None
def _log(msg: str):
    global _LOG_FILE
    if _LOG_FILE is None:
        _LOG_FILE = open(os.path.join(os.path.dirname(__file__), 'ox_lsp_debug.log'), 'w', encoding='utf-8')
    _LOG_FILE.write(msg + '\n')
    _LOG_FILE.flush()

_log('=== ox_lsp.py starting ===')
_log(f'sys.argv={sys.argv!r}')
_log(f'cwd={os.getcwd()!r}')
_log(f'__file__={__file__!r}')

try:
    from oxybelis import (Lexer, Parser, TypeChecker, compile_source, TT,
                          FnDef, ClassDef, VarDecl, ImportStmt, Ident, ModuleResolver,
                          IfStmt, ForStmt, WhileStmt, MatchStmt)
    _log('imported oxybelis OK')
except Exception as e:
    _log(f'IMPORT ERROR oxybelis: {e}')
    raise

try:
    from ox_diag import (Span, Severity, Diagnostic, SourceFile,
                         render_diagnostics, highlight_ox)
    _log('imported ox_diag OK')
except Exception as e:
    _log(f'IMPORT ERROR ox_diag: {e}')
    raise

try:
    from ox_fmt import format_source
    _log('imported ox_fmt OK')
except Exception as e:
    _log(f'IMPORT ERROR ox_fmt: {e}')
    raise


# ═══════════════════════════════════════════════════════════════
#  UTF-16 helpers  (LSP spec §3.1 – offsets are UTF-16 code units)
# ═══════════════════════════════════════════════════════════════

def _utf16_len(s: str) -> int:
    """Number of UTF-16 code units in *s* (BMP = 1, supplementary = 2)."""
    return sum(2 if ord(c) > 0xFFFF else 1 for c in s)

def _col_to_utf16(line_text: str, char_col: int) -> int:
    """Convert a Python char-index column to a UTF-16 code-unit column."""
    return _utf16_len(line_text[:char_col])

def _src_lines(source: str) -> PyList[str]:
    return source.splitlines()


# ═══════════════════════════════════════════════════════════════
#  JSON-RPC over stdio
# ═══════════════════════════════════════════════════════════════

@dataclass
class LSPMessage:
    method: str = ''
    params: dict = field(default_factory=dict)
    id: Optional[int] = None
    result: Optional[Any] = None
    error: Optional[dict] = None


class LSPConnection:
    def __init__(self):
        self._buf = b''
        self._content_length = 0
        if os.name == 'nt':
            import msvcrt
            try:
                msvcrt.setmode(0, os.O_BINARY)
                msvcrt.setmode(1, os.O_BINARY)
            except Exception:
                pass

    def read_message(self) -> Optional[LSPMessage]:
        while True:
            if self._content_length == 0 and b'\r\n\r\n' in self._buf:
                header, _, rest = self._buf.partition(b'\r\n\r\n')
                self._buf = rest
                for line in header.decode('ascii').split('\r\n'):
                    if line.lower().startswith('content-length:'):
                        self._content_length = int(line.split(':')[1].strip())

            if self._content_length > 0 and len(self._buf) >= self._content_length:
                raw = self._buf[:self._content_length]
                self._buf = self._buf[self._content_length:]
                self._content_length = 0
                try:
                    msg = json.loads(raw.decode('utf-8'))
                    return LSPMessage(
                        method=msg.get('method', ''),
                        params=msg.get('params', {}),
                        id=msg.get('id'),
                        result=msg.get('result'),
                        error=msg.get('error'),
                    )
                except json.JSONDecodeError:
                    return None

            chunk = os.read(0, 4096)
            if not chunk:
                return None
            self._buf += chunk

    def send_notification(self, method: str, params: dict = None):
        self._send({'jsonrpc': '2.0', 'method': method, 'params': params or {}})

    def send_response(self, msg_id: int, result: Any = None):
        self._send({'jsonrpc': '2.0', 'id': msg_id, 'result': result})

    def send_error(self, msg_id: int, code: int, message: str):
        self._send({'jsonrpc': '2.0', 'id': msg_id,
                    'error': {'code': code, 'message': message}})

    def _send(self, obj: dict):
        data = json.dumps(obj, ensure_ascii=False)
        body = data.encode('utf-8')
        header = f'Content-Length: {len(body)}\r\n\r\n'
        os.write(1, header.encode('ascii'))
        os.write(1, body)


# ═══════════════════════════════════════════════════════════════
#  DOCUMENT STORE
# ═══════════════════════════════════════════════════════════════

@dataclass
class Document:
    uri: str
    source: str
    version: int = 0


class LSPState:
    def __init__(self):
        self.documents: dict[str, Document] = {}
        self.capabilities: dict = {}

    def get_or_create(self, uri: str) -> Document:
        if uri not in self.documents:
            self.documents[uri] = Document(uri, '')
        return self.documents[uri]


state = LSPState()
conn = LSPConnection()


# ═══════════════════════════════════════════════════════════════
#  DIAGNOSTICS (errors/warnings)
# ═══════════════════════════════════════════════════════════════

_SEV_MAP = {
    Severity.ERROR: 1,
    Severity.WARNING: 2,
    Severity.NOTE: 3,
    Severity.HELP: 4,
}


def get_diagnostics(source: str) -> PyList[dict]:
    _, diags = compile_source(source, check_only=True)

    lsp_diags = []
    for d in diags:
        diag: dict = {
            'severity': _SEV_MAP.get(d.severity, 1),
            'message': d.message,
            'source': 'oxybelis',
        }
        if d.code:
            diag['code'] = d.code
        if d.span:
            diag['range'] = {
                'start': {'line': d.span.start_line - 1, 'character': d.span.start_col - 1},
                'end': {'line': d.span.end_line - 1, 'character': d.span.end_col - 1},
            }
        else:
            diag['range'] = {
                'start': {'line': 0, 'character': 0},
                'end': {'line': 0, 'character': 1},
            }
        if d.notes:
            related = []
            for note_msg, note_span in d.notes:
                related.append({
                    'message': note_msg,
                    'location': {
                        'uri': '',
                        'range': {
                            'start': {'line': 0, 'character': 0},
                            'end': {'line': 0, 'character': 0},
                        }
                    }
                })
            if related:
                diag['relatedInformation'] = related
        lsp_diags.append(diag)

    if not lsp_diags:
        try:
            tokens = Lexer(source).tokenize()
            parser = Parser(tokens, source)
            parser.parse()
        except Exception as e:
            line = getattr(e, 'line', 0)
            col = getattr(e, 'col', 0)
            lsp_diags.append({
                'severity': 1,
                'message': str(e),
                'source': 'oxybelis',
                'range': {
                    'start': {'line': line - 1, 'character': col - 1},
                    'end': {'line': line - 1, 'character': col},
                }
            })

    return lsp_diags


# ═══════════════════════════════════════════════════════════════
#  SEMANTIC TOKENS
#
#  Bugs fixed in this version:
#
#  1. delta_col was computed using the token's *end* column as the new
#     baseline (prev_col = col + length).  The LSP spec (§3.16.6) says
#     deltaCharacter is relative to the *start* column of the previous
#     token on the same line.  Fix: prev_col = col  (start, not end).
#
#  2. tok.length reflected the decoded string value length, not the raw
#     source span.  For a string literal "foo\nbar" the decoded value is
#     7 chars but the source span is 9 chars.  The LSP client uses the
#     reported length to highlight exactly that many source characters, so
#     the wrong value caused the highlight to end mid-token or run over.
#     Fix: compute source_length = pos_after_token - pos_before_token at
#     lex time, stored as tok.length.  The Lexer already does this for
#     most tokens; the one gap was STR_LIT where length was set to
#     len(decoded_value) instead of the raw source span.
#
#  3. All column values are now converted to UTF-16 code units as required
#     by the LSP specification §3.1.  For pure ASCII source this is a
#     no-op, but it prevents colour shifts in files that contain non-BMP
#     characters (emoji, mathematical symbols, etc.) in comments or strings.
# ═══════════════════════════════════════════════════════════════

_OX_KEYWORDS = frozenset({
    'fn', 'let', 'var', 'class', 'if', 'else', 'elif',
    'for', 'in', 'while', 'return', 'match', 'lazy', 'pub',
    'true', 'false', 'None', 'Some', 'import', 'and', 'or', 'not',
    'break', 'continue',
})
_OX_TYPES = frozenset({'int', 'float', 'bool', 'str', 'void', 'long', 'List', 'Map', 'Option'})

TOKEN_KEYWORD  = 0
TOKEN_TYPE     = 1
TOKEN_STRING   = 2
TOKEN_NUMBER   = 3
TOKEN_OPERATOR = 4
TOKEN_VARIABLE = 5
TOKEN_FUNCTION = 6
TOKEN_PARAMETER = 7
TOKEN_COMMENT  = 8


def get_semantic_tokens(source: str) -> PyList[int]:
    src_line_list = _src_lines(source)

    def line_text(line0: int) -> str:
        """Return source line (0-based) or empty string if out of range."""
        return src_line_list[line0] if 0 <= line0 < len(src_line_list) else ''

    tokens_data: PyList[int] = []

    try:
        ltokens = list(Lexer(source).tokenize())
    except Exception:
        return []

    # ── prev_line / prev_col track the *start* of the last emitted token ──
    prev_line = 0
    prev_col  = 0   # FIX 1: was initialised and updated to the *end* col
    was_fn_keyword = False  # track if previous non-whitespace token was 'fn'

    for i, tok in enumerate(ltokens):
        if tok.type == TT.EOF:
            break

        # tok.line / tok.col are 1-based from the Lexer
        line = tok.line - 1   # convert to 0-based for LSP
        col  = tok.col  - 1   # convert to 0-based for LSP
        word = tok.value

        # ── FIX 2: source-span length ─────────────────────────────────────
        # tok.length is set by the Lexer to len(tok.value) for most tokens.
        # For STR_LIT the decoded value is shorter than the source span.
        # We detect this by checking the actual source character at the
        # expected end position.
        if tok.type == TT.STR_LIT:
            # Re-measure: opening quote + raw source chars until closing quote.
            raw_length = _measure_str_lit_length(source, line, col)
            length = raw_length if raw_length > 0 else max(len(word) + 2, 1)
        else:
            # For all other token types the Lexer sets length = len(value)
            # which equals the source span (operators, keywords, identifiers
            # are all ASCII and their decoded == raw lengths).
            length = max(tok.length, 1)

        # ── FIX 3: convert column to UTF-16 code units ────────────────────
        lt = line_text(line)
        col_utf16 = _col_to_utf16(lt, col)

        # ── Classify the token ─────────────────────────────────────────────
        tok_type = -1
        if tok.type in (TT.FN, TT.LET, TT.VAR, TT.CLASS, TT.IF, TT.ELSE, TT.ELIF,
                        TT.FOR, TT.IN, TT.WHILE, TT.RETURN, TT.MATCH, TT.LAZY,
                        TT.PUB, TT.BREAK, TT.CONTINUE, TT.IMPORT, TT.YIELD,
                        TT.DEFER, TT.TRY, TT.CATCH, TT.AND, TT.OR, TT.NOT,
                        TT.AS):
            tok_type = TOKEN_KEYWORD
            if tok.type == TT.FN:
                was_fn_keyword = True
        elif word in ('true', 'false', 'None', 'Some', 'and', 'or', 'not'):
            tok_type = TOKEN_KEYWORD
        elif tok.type in (TT.T_INT, TT.T_FLOAT, TT.T_BOOL, TT.T_STR, TT.T_VOID, TT.T_LONG):
            tok_type = TOKEN_TYPE
        elif word in _OX_TYPES:
            tok_type = TOKEN_TYPE
        elif tok.type in (TT.INT_LIT, TT.FLOAT_LIT):
            tok_type = TOKEN_NUMBER
        elif tok.type == TT.STR_LIT:
            tok_type = TOKEN_STRING
        elif tok.type == TT.IDENT:
            if word == '_':
                continue   # wildcard – skip, no highlight
            # Function definition name (IDENT after 'fn')
            if was_fn_keyword:
                tok_type = TOKEN_FUNCTION
            # Known function call (builtin/math name)
            elif word in _KNOWN_FUNCTIONS:
                tok_type = TOKEN_FUNCTION
            # Function call (IDENT followed by LPAREN)
            elif i + 1 < len(ltokens) and ltokens[i + 1].type == TT.LPAREN:
                tok_type = TOKEN_FUNCTION
            else:
                tok_type = TOKEN_VARIABLE
            was_fn_keyword = False
        elif tok.type in (TT.PLUS, TT.MINUS, TT.STAR, TT.SLASH, TT.PERCENT,
                          TT.EQ, TT.NEQ, TT.LT, TT.GT, TT.LEQ, TT.GEQ,
                          TT.ASSIGN, TT.PLUS_ASSIGN, TT.MINUS_ASSIGN,
                          TT.STAR_ASSIGN, TT.SLASH_ASSIGN,
                          TT.DOTDOT, TT.ARROW, TT.FAT_ARROW, TT.BANG,
                          TT.AND, TT.OR, TT.NOT):
            tok_type = TOKEN_OPERATOR
        elif tok.type in (TT.LBRACE, TT.RBRACE, TT.LPAREN, TT.RPAREN,
                          TT.LBRACKET, TT.RBRACKET,
                          TT.COLON, TT.COMMA, TT.SEMI, TT.DOT, TT.QUESTION):
            tok_type = TOKEN_OPERATOR

        if tok_type < 0:
            continue

        # ── Encode as LSP relative (delta) values ─────────────────────────
        delta_line = line - prev_line
        if delta_line == 0:
            # FIX 1: delta is start-to-start on the same line.
            # prev_col is the *start* column of the last token (UTF-16 units).
            delta_col = col_utf16 - prev_col
        else:
            # New line: delta_col is the absolute start column on this line.
            delta_col = col_utf16

        tokens_data.extend([delta_line, delta_col, length, tok_type, 0])

        prev_line = line
        prev_col  = col_utf16   # FIX 1: store START column, not end column


    return tokens_data


def _measure_str_lit_length(source: str, line0: int, col0: int) -> int:
    """
    Re-measure a string literal's raw source length by scanning from its
    opening quote.  Returns the number of source characters it occupies
    (including both quote characters).
    """
    # Convert 0-based line/col back to a source offset
    lines = source.split('\n')
    if line0 >= len(lines):
        return 0
    offset = sum(len(lines[i]) + 1 for i in range(line0)) + col0
    if offset >= len(source) or source[offset] != '"':
        return 0
    i = offset + 1
    while i < len(source):
        c = source[i]
        if c == '\\':
            i += 2   # skip escaped character
            continue
        if c == '"':
            return i - offset + 1   # include both quotes
        if c == '\n':
            break    # unterminated string
        i += 1
    return 0


# ═══════════════════════════════════════════════════════════════
#  HOVER (with robust token-level fallback)
# ═══════════════════════════════════════════════════════════════

def get_hover(source: str, line: int, col: int, filepath: str = '') -> Optional[dict]:
    """Try full type-check hover; if that fails, fall back to token doc lookup."""

    # ── 1. Complex attempt: parse + type-check and get inferred type ──
    try:
        _log(f'get_hover: trying type-based hover for {filepath} at {line}:{col}')
        tokens = Lexer(source).tokenize()
        parser = Parser(tokens, source)
        ast = parser.parse()
        spans = parser.get_spans()
        src_file = SourceFile(source)

        offset = 0
        for _ in range(line):
            offset = source.find('\n', offset) + 1
            if offset == 0:
                break
        offset += col

        # ── Module resolution ──
        module_fns = {}
        resolver = ModuleResolver(filepath)
        for stmt in list(ast.stmts):
            if isinstance(stmt, ImportStmt):
                try:
                    mod_src, _ = resolver.resolve(stmt.path)
                except ImportError:
                    continue
                mod_name = '.'.join(stmt.path)
                mod_lexer = Lexer(mod_src)
                mod_tokens = mod_lexer.tokenize()
                mod_parser = Parser(mod_tokens, mod_src)
                mod_ast = mod_parser.parse()
                mod_spans = mod_parser.get_spans()
                mod_checker = TypeChecker(mod_spans, SourceFile(mod_src))
                mod_checker.check(mod_ast)
                fns = {}
                for fn_name, sig in mod_checker.fns.items():
                    if fn_name.startswith('_ox_') or fn_name in (
                        'main', 'print', 'len', 'push', 'pop',
                        'range', 'str', 'int', 'float', 'bool', 'sqrt', 'abs', 'pow',
                        'contains', 'read_file', 'read_line', 'read_lines', 'write_file',
                        'exec', 'eprint', 'eprintln', 'append_file', 'temp_dir', 'temp_file',
                        'exit', 'to_int', 'to_float', 'str_get', 'str_sub', 'args',
                        'is_digit', 'is_alpha', 'is_alnum', 'str_contains',
                        'str_split', 'str_trim', 'str_trim_start', 'str_trim_end',
                        'str_replace', 'str_replace_all', 'str_join',
                        'to_upper', 'to_lower',
                        'starts_with', 'ends_with',
                        'str_repeat', 'str_reverse', 'str_find',
                        'map_contains', 'map_get', 'map_set',
                        'list_insert', 'list_remove',
                        'fs_exists', 'fs_is_file', 'fs_is_dir', 'fs_mkdir',
                        'fs_list_dir', 'fs_remove', 'fs_rename', 'fs_copy', 'fs_cwd',
                        '_ox_math_zeros', '_ox_math_ones', '_ox_math_linspace', '_ox_math_arange',
                        '_ox_math_dot', '_ox_math_matmul', '_ox_math_transpose',
                        '_ox_math_norm', '_ox_math_inv', '_ox_math_det', '_ox_math_solve',
                        '_ox_math_sin', '_ox_math_cos', '_ox_math_tan',
                        '_ox_math_sqrt', '_ox_math_abs', '_ox_math_exp', '_ox_math_log',
                        '_ox_math_floor', '_ox_math_ceil',
                        '_ox_math_add', '_ox_math_sub', '_ox_math_mul', '_ox_math_div',
                        '_ox_math_sum', '_ox_math_mean', '_ox_math_min', '_ox_math_max',
                        '_ox_math_reshape'):
                        continue
                    fns[fn_name] = sig
                if fns:
                    module_fns[mod_name] = fns

        # ── Type-check with module symbols ──
        checker = TypeChecker(spans, src_file, module_fns=module_fns)
        checker.check(ast)
        for node, sp in spans.items():
            if sp.start <= offset < sp.end:
                try:
                    node_obj = _find_node_in_stmt_list(ast.stmts, node)
                    if node_obj is not None:
                        ty = getattr(node_obj, '_type', None) or checker._infer_type(node_obj)
                        if ty and ty != 'void':
                            return {
                                'contents': {
                                    'kind': 'markdown',
                                    'value': f"```oxybelis\n{ty}\n```"
                                }
                            }
                except Exception:
                    pass
                break
        _log('get_hover: type-based approach found nothing, trying fallbacks')
    except Exception as e:
        _log(f'get_hover: type-based error: {e}')

    # ── 2. Fallback: token-based doc lookup for builtins / math ──
    try:
        tokens = list(Lexer(source).tokenize())
        for tok in tokens:
            if tok.type == TT.IDENT and tok.line - 1 == line:
                tok_start = tok.col - 1
                tok_len   = max(tok.length, len(tok.value))
                tok_end   = tok_start + tok_len
                if tok_start <= col < tok_end:
                    word = tok.value
                    docs = _ALL_DOCS.get(word)
                    if docs:
                        _log(f'get_hover: token-based match for {word}')
                        return {
                            'contents': {
                                'kind': 'markdown',
                                'value': docs,
                            }
                        }
                    break
    except Exception as e:
        _log(f'get_hover: token-based error: {e}')

    return None


_CHILD_ATTRS = [
    'body', 'then_body', 'else_body', 'elif_clauses', 'arms',
    'left', 'right', 'operand', 'value', 'expr', 'cond',
    'func', 'obj', 'idx', 'target', 'iterable', 'subject',
    'name_node', 'init',
]


def _find_node_in_stmt_list(stmts, target_id):
    for s in stmts:
        result = _recurse_find(s, target_id)
        if result:
            return result
    return None


def _recurse_find(node, target_id):
    if node is None:
        return None
    if id(node) == target_id:
        return node
    if isinstance(node, (list, tuple)):
        for child in node:
            result = _recurse_find(child, target_id)
            if result:
                return result
        return None
    for attr in _CHILD_ATTRS:
        child = getattr(node, attr, None)
        if child is not None:
            result = _recurse_find(child, target_id)
            if result:
                return result
    if hasattr(node, 'args'):
        for arg in node.args:
            result = _recurse_find(arg, target_id)
            if result:
                return result
    if hasattr(node, 'fields'):
        for _, fval in node.fields:
            result = _recurse_find(fval, target_id)
            if result:
                return result
    if hasattr(node, 'elems'):
        for elem in node.elems:
            result = _recurse_find(elem, target_id)
            if result:
                return result
    if hasattr(node, 'params'):
        for p in node.params:
            if isinstance(p, tuple) and len(p) == 3:
                result = _recurse_find(p[2], target_id)
                if result:
                    return result
    return None


# ═══════════════════════════════════════════════════════════════
#  GO TO DEFINITION
# ═══════════════════════════════════════════════════════════════

def get_definition(source: str, line: int, col: int, uri: str) -> Optional[dict]:
    """Return an LSP Location for the definition of the identifier at the given position."""
    try:
        tokens = Lexer(source).tokenize()
        parser = Parser(tokens, source)
        ast = parser.parse()
        spans = parser.get_spans()

        offset = 0
        for _ in range(line):
            npos = source.find('\n', offset)
            if npos < 0:
                break
            offset = npos + 1
        offset += col

        best_id = None
        best_span = None
        for node_id, sp in spans.items():
            if sp.start <= offset < sp.end:
                span_len = sp.end - sp.start
                if best_span is None or span_len < (best_span.end - best_span.start):
                    best_span = sp
                    best_id = node_id

        if best_id is None:
            return None

        node_obj = _find_node_in_stmt_list(ast.stmts, best_id)
        if node_obj is None or not isinstance(node_obj, Ident):
            return None

        name = node_obj.name
        if name in _ALL_DOCS:
            return None

        defs = _build_def_index(ast.stmts, spans, len(source))
        def_span = _resolve_def(name, offset, defs)
        if def_span is None:
            return None

        return {
            'uri': uri,
            'range': {
                'start': {'line': def_span.start_line - 1, 'character': def_span.start_col - 1},
                'end': {'line': def_span.end_line - 1, 'character': def_span.end_col - 1},
            }
        }
    except Exception:
        return None


def _build_def_index(stmts, spans, source_len: int) -> list:
    """
    Walk the AST and collect all definitions with scope boundaries.
    Returns list of tuples: (name, def_span_or_None, scope_start, scope_end)
    """
    defs: list = []

    def _walk(stmt_list, scope_start: int, scope_end: int):
        for s in stmt_list:
            if isinstance(s, FnDef):
                s_span = spans.get(id(s))
                if s_span:
                    defs.append((s.name, s_span, scope_start, scope_end))
                fn_ss = s_span.start if s_span else scope_start
                fn_se = s_span.end if s_span else scope_end
                for p in s.params:
                    ps = spans.get(id(p[3])) if len(p) > 3 else None
                    defs.append((p[0], ps, fn_ss, fn_se))
                _walk(s.body, fn_ss, fn_se)

            elif isinstance(s, ClassDef):
                s_span = spans.get(id(s))
                if s_span:
                    defs.append((s.name, s_span, scope_start, scope_end))
                _walk(s.methods, scope_start, scope_end)

            elif isinstance(s, VarDecl):
                ns = spans.get(id(s.name_node)) if hasattr(s, 'name_node') else None
                defs.append((s.name, ns or spans.get(id(s)), scope_start, scope_end))

            elif isinstance(s, IfStmt):
                _walk(s.then_body, scope_start, scope_end)
                for _, eb in s.elif_clauses:
                    _walk(eb, scope_start, scope_end)
                if s.else_body:
                    _walk(s.else_body, scope_start, scope_end)

            elif isinstance(s, ForStmt):
                _walk(s.body, scope_start, scope_end)

            elif isinstance(s, WhileStmt):
                _walk(s.body, scope_start, scope_end)

            elif isinstance(s, MatchStmt):
                for _, arm_body in s.arms:
                    _walk(arm_body, scope_start, scope_end)

    _walk(stmts, 0, source_len)
    return defs


def _resolve_def(name: str, offset: int, defs: list) -> Optional[Span]:
    """Find the best definition for *name* at source *offset*."""
    candidates = [(span, ss, se) for n, span, ss, se in defs if n == name and span is not None]
    if not candidates:
        return None

    best = None
    best_size = None
    for span, ss, se in candidates:
        if ss <= offset <= se:
            size = se - ss
            if best is None or size < best_size:
                best = span
                best_size = size

    if best is None:
        best = candidates[0][0]

    return best


# ═══════════════════════════════════════════════════════════════
#  COMPLETIONS
# ═══════════════════════════════════════════════════════════════

_BUILTIN_DOCS: dict[str, str] = {
    'print': 'Print a value to stdout.\n\n```oxybelis\nfn print(value: any) -> void\n```',
    'len': 'Return the length of a string or list.\n\n```oxybelis\nfn len(obj: str|List) -> int\n```',
    'push': 'Append a value to a list.\n\n```oxybelis\nfn push(list: List<T>, value: T) -> void\n```',
    'pop': 'Remove and return the last element of a list.\n\n```oxybelis\nfn pop(list: List<T>) -> T\n```',
    'range': 'Create a range of integers.\n\n```oxybelis\nfn range(end: int) -> List<int>\nfn range(start: int, end: int) -> List<int>\nfn range(start: int, end: int, step: int) -> List<int>\n```',
    'str': 'Convert a value to a string.\n\n```oxybelis\nfn str(value: any) -> str\n```',
    'int': 'Convert a value to an integer.\n\n```oxybelis\nfn int(value: any) -> int\n```',
    'float': 'Convert a value to a float.\n\n```oxybelis\nfn float(value: any) -> float\n```',
    'bool': 'Convert a value to a boolean.\n\n```oxybelis\nfn bool(value: any) -> bool\n```',
    'sqrt': 'Compute the square root of a number.\n\n```oxybelis\nfn sqrt(x: float) -> float\n```',
    'abs': 'Compute the absolute value of a number.\n\n```oxybelis\nfn abs(x: float) -> float\n```',
    'pow': 'Raise a number to a power.\n\n```oxybelis\nfn pow(base: float, exp: float) -> float\n```',
    'contains': 'Check if a substring or element exists.\n\n```oxybelis\nfn contains(container: str|List, item: any) -> bool\n```',
    'to_int': 'Parse a string to an integer.\n\n```oxybelis\nfn to_int(s: str) -> int\n```',
    'to_float': 'Parse a string to a float.\n\n```oxybelis\nfn to_float(s: str) -> float\n```',
    'parse_int': 'Parse a string to an integer with base.\n\n```oxybelis\nfn parse_int(s: str, base: int) -> int\n```',
    'str_format': 'Format a string with replacement and format specs.\n\nSupports `{}` replacement, `{:.Nf}` (float), `{:x}`/`{:X}` (hex), `{:o}` (octal), `{:b}` (binary), `{:e}`/`{:E}` (scientific), `{:>N}`/`{:<N}`/`{:^N}` (alignment).\n\n```oxybelis\nfn str_format(fmt: str, args: List<str>) -> str\n```',
    'is_digit': 'Check if a character is a digit.\n\n```oxybelis\nfn is_digit(c: str) -> bool\n```',
    'is_alpha': 'Check if a character is alphabetic.\n\n```oxybelis\nfn is_alpha(c: str) -> bool\n```',
    'is_alnum': 'Check if a character is alphanumeric.\n\n```oxybelis\nfn is_alnum(c: str) -> bool\n```',
    'str_get': 'Get a character from a string by index.\n\n```oxybelis\nfn str_get(s: str, i: int) -> str\n```',
    'str_sub': 'Extract a substring.\n\n```oxybelis\nfn str_sub(s: str, start: int, end: int) -> str\n```',
    'str_contains': 'Check if a string contains a substring.\n\n```oxybelis\nfn str_contains(s: str, sub: str) -> bool\n```',
    'str_split': 'Split a string by a delimiter.\n\n```oxybelis\nfn str_split(s: str, delim: str) -> List<str>\n```',
    'str_trim': 'Trim whitespace from both ends.\n\n```oxybelis\nfn str_trim(s: str) -> str\n```',
    'str_trim_start': 'Trim leading whitespace.\n\n```oxybelis\nfn str_trim_start(s: str) -> str\n```',
    'str_trim_end': 'Trim trailing whitespace.\n\n```oxybelis\nfn str_trim_end(s: str) -> str\n```',
    'str_replace': 'Replace first occurrence of a substring.\n\n```oxybelis\nfn str_replace(s: str, from: str, to: str) -> str\n```',
    'str_replace_all': 'Replace all occurrences of a substring.\n\n```oxybelis\nfn str_replace_all(s: str, from: str, to: str) -> str\n```',
    'str_join': 'Join a list of strings with a separator.\n\n```oxybelis\nfn str_join(list: List<str>, sep: str) -> str\n```',
    'to_upper': 'Convert a string to uppercase.\n\n```oxybelis\nfn to_upper(s: str) -> str\n```',
    'to_lower': 'Convert a string to lowercase.\n\n```oxybelis\nfn to_lower(s: str) -> str\n```',
    'starts_with': 'Check if a string starts with a prefix.\n\n```oxybelis\nfn starts_with(s: str, prefix: str) -> bool\n```',
    'ends_with': 'Check if a string ends with a suffix.\n\n```oxybelis\nfn ends_with(s: str, suffix: str) -> bool\n```',
    'str_repeat': 'Repeat a string n times.\n\n```oxybelis\nfn str_repeat(s: str, n: int) -> str\n```',
    'str_reverse': 'Reverse a string.\n\n```oxybelis\nfn str_reverse(s: str) -> str\n```',
    'str_find': 'Find the index of a substring.\n\n```oxybelis\nfn str_find(s: str, sub: str) -> int\n```',
    'args': 'Return command-line arguments.\n\n```oxybelis\nfn args() -> List<str>\n```',
    'read_file': 'Read a file as a string.\n\n```oxybelis\nfn read_file(path: str) -> str\n```',
    'read_line': 'Read a line from stdin.\n\n```oxybelis\nfn read_line() -> str\n```',
    'read_lines': 'Read a file into a list of lines.\n\n```oxybelis\nfn read_lines(path: str) -> List<str>\n```',
    'write_file': 'Write a string to a file.\n\n```oxybelis\nfn write_file(path: str, content: str) -> void\n```',
    'exec': 'Execute a system command.\n\n```oxybelis\nfn exec(cmd: str) -> int\n```',
    'eprint': 'Print a message to stderr.\n\n```oxybelis\nfn eprint(msg: str) -> void\n```',
    'eprintln': 'Print a message to stderr with a newline.\n\n```oxybelis\nfn eprintln(msg: str) -> void\n```',
    'append_file': 'Append a string to a file.\n\n```oxybelis\nfn append_file(path: str, content: str) -> void\n```',
    'temp_dir': 'Return the system temp directory path.\n\n```oxybelis\nfn temp_dir() -> str\n```',
    'temp_file': 'Return a temporary file path.\n\n```oxybelis\nfn temp_file() -> str\n```',
    'exit': 'Exit the program with a status code.\n\n```oxybelis\nfn exit(code: int) -> void\n```',
    'chr': 'Convert an integer to a character string.\n\n```oxybelis\nfn chr(code: int) -> str\n```',
    'ord': 'Get the Unicode code point of the first character of a string.\n\n```oxybelis\nfn ord(s: str) -> int\n```',
    'isinstance': 'Check if a value has a given type.\n\n```oxybelis\nfn isinstance(value: any, type: str) -> bool\n```',
    'zip': 'Combine two lists into a list of pairs.\n\n```oxybelis\nfn zip(a: List<T>, b: List<U>) -> List<(T, U)>\n```',
    'enumerate': 'Return index-value pairs from a list or string.\n\n```oxybelis\nfn enumerate(list: List<T>) -> List<(int, T)>\nfn enumerate(s: str) -> List<(int, str)>\n```',
    'batched': 'Split a list or string into batches of size n.\n\n```oxybelis\nfn batched(list: List<T>, n: int) -> List<List<T>>\nfn batched(s: str, n: int) -> List<List<str>>\n```',
    'map_keys': 'Get all keys from a map as a list.\n\n```oxybelis\nfn map_keys(map: Map<K,V>) -> List<K>\n```',
    'map_values': 'Get all values from a map as a list.\n\n```oxybelis\nfn map_values(map: Map<K,V>) -> List<V>\n```',
    'map_items': 'Get all key-value pairs from a map as a list of tuples.\n\n```oxybelis\nfn map_items(map: Map<K,V>) -> List<(K, V)>\n```',
    'json_parse': 'Parse a JSON string into a JsonValue.\n\n```oxybelis\nfn json_parse(s: str) -> JsonValue\n```',
    'json_serialize': 'Serialize a JsonValue to a JSON string.\n\n```oxybelis\nfn json_serialize(v: JsonValue) -> str\n```',
    'json_is_list': 'Check if a JsonValue is a JSON array.\n\n```oxybelis\nfn json_is_list(v: JsonValue) -> bool\n```',
    'json_is_dict': 'Check if a JsonValue is a JSON object.\n\n```oxybelis\nfn json_is_dict(v: JsonValue) -> bool\n```',
    'json_is_int': 'Check if a JsonValue is an integer.\n\n```oxybelis\nfn json_is_int(v: JsonValue) -> bool\n```',
    'json_is_str': 'Check if a JsonValue is a string.\n\n```oxybelis\nfn json_is_str(v: JsonValue) -> bool\n```',
    'json_is_bool': 'Check if a JsonValue is a boolean.\n\n```oxybelis\nfn json_is_bool(v: JsonValue) -> bool\n```',
    'json_is_float': 'Check if a JsonValue is a float.\n\n```oxybelis\nfn json_is_float(v: JsonValue) -> bool\n```',
    'json_as_int': 'Get the integer value of a JsonValue.\n\n```oxybelis\nfn json_as_int(v: JsonValue) -> int\n```',
    'json_as_str': 'Get the string value of a JsonValue.\n\n```oxybelis\nfn json_as_str(v: JsonValue) -> str\n```',
    'json_as_list': 'Get the array value of a JsonValue.\n\n```oxybelis\nfn json_as_list(v: JsonValue) -> List<JsonValue>\n```',
    'json_as_dict': 'Get the object value of a JsonValue.\n\n```oxybelis\nfn json_as_dict(v: JsonValue) -> Map<str, JsonValue>\n```',
    'json_keys': 'Get the keys of a JSON object.\n\n```oxybelis\nfn json_keys(v: JsonValue) -> List<str>\n```',
    'json_get': 'Get a value by key from a JSON object.\n\n```oxybelis\nfn json_get(v: JsonValue, key: str) -> Option<JsonValue>\n```',
    'json_contains': 'Check if a JSON object contains a key.\n\n```oxybelis\nfn json_contains(v: JsonValue, key: str) -> bool\n```',
    'json_size': 'Get the size of a JSON array or object.\n\n```oxybelis\nfn json_size(v: JsonValue) -> int\n```',
    'map_contains': 'Check if a map contains a key.\n\n```oxybelis\nfn map_contains(map: Map<K,V>, key: K) -> bool\n```',
    'map_get': 'Get a value from a map by key.\n\n```oxybelis\nfn map_get(map: Map<K,V>, key: K) -> Option<V>\n```',
    'map_set': 'Set a value in a map by key.\n\n```oxybelis\nfn map_set(map: Map<K,V>, key: K, value: V) -> void\n```',
    'list_insert': 'Insert a value at an index in a list.\n\n```oxybelis\nfn list_insert(list: List<T>, index: int, value: T) -> void\n```',
    'list_remove': 'Remove a value at an index from a list.\n\n```oxybelis\nfn list_remove(list: List<T>, index: int) -> T\n```',
    'fs_exists': 'Check if a file or directory exists.\n\n```oxybelis\nfn fs_exists(path: str) -> bool\n```',
    'fs_is_file': 'Check if path is a file.\n\n```oxybelis\nfn fs_is_file(path: str) -> bool\n```',
    'fs_is_dir': 'Check if path is a directory.\n\n```oxybelis\nfn fs_is_dir(path: str) -> bool\n```',
    'fs_mkdir': 'Create a directory.\n\n```oxybelis\nfn fs_mkdir(path: str) -> void\n```',
    'fs_list_dir': 'List contents of a directory.\n\n```oxybelis\nfn fs_list_dir(path: str) -> List<str>\n```',
    'fs_remove': 'Remove a file or directory.\n\n```oxybelis\nfn fs_remove(path: str) -> void\n```',
    'fs_rename': 'Rename a file or directory.\n\n```oxybelis\nfn fs_rename(old: str, new: str) -> void\n```',
    'fs_copy': 'Copy a file.\n\n```oxybelis\nfn fs_copy(src: str, dst: str) -> void\n```',
    'fs_cwd': 'Get the current working directory.\n\n```oxybelis\nfn fs_cwd() -> str\n```',
    'map': 'Transform each element of a list using a mapper function.\n\n```oxybelis\nfn map(list: List<T>, fn: T -> U) -> List<U>\n```',
    'filter': 'Keep elements of a list that satisfy a predicate function.\n\n```oxybelis\nfn filter(list: List<T>, fn: T -> bool) -> List<T>\n```',
    'sorted': 'Sort elements of a list.\n\n```oxybelis\nfn sorted(list: List<T>) -> List<T>\nfn sorted(list: List<T>, key: T -> U) -> List<T>\n```',
    'reduce': 'Reduce a list to a single value using an accumulator function.\n\n```oxybelis\nfn reduce(list: List<T>, initial: U, fn: (U, T) -> U) -> U\n```',
    'for_each': 'Apply a function to each element of a list.\n\n```oxybelis\nfn for_each(list: List<T>, fn: T -> void) -> void\n```',
    'each': 'Apply a function to each element of a list.\n\n```oxybelis\nfn each(list: List<T>, fn: T -> void) -> void\n```',
    'any': 'Check if any element of a list satisfies a predicate function.\n\n```oxybelis\nfn any(list: List<T>, fn: T -> bool) -> bool\n```',
    'all': 'Check if all elements of a list satisfy a predicate function.\n\n```oxybelis\nfn all(list: List<T>, fn: T -> bool) -> bool\n```',
    'find': 'Find the first element of a list that satisfies a predicate function.\n\n```oxybelis\nfn find(list: List<T>, fn: T -> bool) -> Option<T>\n```',
    'take_while': 'Take elements from a list while a predicate function is true.\n\n```oxybelis\nfn take_while(list: List<T>, fn: T -> bool) -> List<T>\n```',
    'drop_while': 'Drop elements from a list while a predicate function is true.\n\n```oxybelis\nfn drop_while(list: List<T>, fn: T -> bool) -> List<T>\n```',
    'reversed': 'Reverse a list.\n\n```oxybelis\nfn reversed(list: List<T>) -> List<T>\n```',
    '_ox_http_request': 'Send an HTTP request and return the response body.\n\n```oxybelis\nfn _ox_http_request(method: str, url: str, headers: str, body: str, timeout: int) -> str\n```',
    '_ox_http_headers_to_json': 'Convert HTTP headers to a JSON string.\n\n```oxybelis\nfn _ox_http_headers_to_json(headers: void) -> str\n```',
}

_MATH_DOCS: dict[str, str] = {
    'zeros': 'Create an array of zeros.\n\n```oxybelis\nfn zeros(rows: int, cols: int) -> Array<float>\n```',
    'ones': 'Create an array of ones.\n\n```oxybelis\nfn ones(rows: int, cols: int) -> Array<float>\n```',
    'linspace': 'Create evenly spaced values over an interval.\n\n```oxybelis\nfn linspace(start: float, stop: float, n: int) -> Array<float>\n```',
    'arange': 'Create evenly spaced values with a step.\n\n```oxybelis\nfn arange(start: float, stop: float, step: float) -> Array<float>\n```',
    'dot': 'Compute dot product of two arrays.\n\n```oxybelis\nfn dot(a: Array<float>, b: Array<float>) -> float\n```',
    'matmul': 'Matrix multiplication.\n\n```oxybelis\nfn matmul(a: Array<float>, b: Array<float>) -> Array<float>\n```',
    'transpose': 'Transpose a matrix.\n\n```oxybelis\nfn transpose(a: Array<float>) -> Array<float>\n```',
    'norm': 'Compute the Frobenius norm.\n\n```oxybelis\nfn norm(a: Array<float>) -> float\n```',
    'inv': 'Compute the inverse of a matrix.\n\n```oxybelis\nfn inv(a: Array<float>) -> Array<float>\n```',
    'det': 'Compute the determinant of a matrix.\n\n```oxybelis\nfn det(a: Array<float>) -> float\n```',
    'solve': 'Solve a linear system Ax = b.\n\n```oxybelis\nfn solve(a: Array<float>, b: Array<float>) -> Array<float>\n```',
    'reshape': 'Reshape an array.\n\n```oxybelis\nfn reshape(a: Array<float>, rows: int, cols: int) -> Array<float>\n```',
    'sin': 'Compute the sine (element-wise).\n\n```oxybelis\nfn sin(a: Array<float>) -> Array<float>\n```',
    'cos': 'Compute the cosine (element-wise).\n\n```oxybelis\nfn cos(a: Array<float>) -> Array<float>\n```',
    'tan': 'Compute the tangent (element-wise).\n\n```oxybelis\nfn tan(a: Array<float>) -> Array<float>\n```',
    'exp': 'Compute exp(x) (element-wise).\n\n```oxybelis\nfn exp(a: Array<float>) -> Array<float>\n```',
    'log': 'Compute the natural log (element-wise).\n\n```oxybelis\nfn log(a: Array<float>) -> Array<float>\n```',
    'floor': 'Round down (element-wise).\n\n```oxybelis\nfn floor(a: Array<float>) -> Array<float>\n```',
    'ceil': 'Round up (element-wise).\n\n```oxybelis\nfn ceil(a: Array<float>) -> Array<float>\n```',
    'sum': 'Sum all elements.\n\n```oxybelis\nfn sum(a: Array<float>) -> float\n```',
    'mean': 'Compute the mean of all elements.\n\n```oxybelis\nfn mean(a: Array<float>) -> float\n```',
    'min': 'Minimum of all elements (or two values).\n\n```oxybelis\nfn min(a: Array<float>) -> float\n```',
    'max': 'Maximum of all elements (or two values).\n\n```oxybelis\nfn max(a: Array<float>) -> float\n```',
    'add': 'Element-wise addition.\n\n```oxybelis\nfn add(a: Array<float>, b: Array<float>) -> Array<float>\n```',
    'sub': 'Element-wise subtraction.\n\n```oxybelis\nfn sub(a: Array<float>, b: Array<float>) -> Array<float>\n```',
    'mul': 'Element-wise multiplication.\n\n```oxybelis\nfn mul(a: Array<float>, b: Array<float>) -> Array<float>\n```',
    'div': 'Element-wise division.\n\n```oxybelis\nfn div(a: Array<float>, b: Array<float>) -> Array<float>\n```',
}

_ALL_DOCS: dict[str, str] = {**_BUILTIN_DOCS, **_MATH_DOCS}

_KEYWORD_COMPLETIONS: list[dict] = [
    {'label': 'fn',       'kind': 14, 'detail': 'keyword',     'insertText': 'fn '},
    {'label': 'let',      'kind': 14, 'detail': 'keyword',     'insertText': 'let '},
    {'label': 'var',      'kind': 14, 'detail': 'keyword',     'insertText': 'var '},
    {'label': 'class',    'kind': 14, 'detail': 'keyword',     'insertText': 'class '},
    {'label': 'if',       'kind': 14, 'detail': 'keyword',     'insertText': 'if '},
    {'label': 'else',     'kind': 14, 'detail': 'keyword',     'insertText': 'else '},
    {'label': 'elif',     'kind': 14, 'detail': 'keyword',     'insertText': 'elif '},
    {'label': 'for',      'kind': 14, 'detail': 'keyword',     'insertText': 'for '},
    {'label': 'while',    'kind': 14, 'detail': 'keyword',     'insertText': 'while '},
    {'label': 'return',   'kind': 14, 'detail': 'keyword',     'insertText': 'return '},
    {'label': 'match',    'kind': 14, 'detail': 'keyword',     'insertText': 'match '},
    {'label': 'true',     'kind': 14, 'detail': 'literal',     'insertText': 'true'},
    {'label': 'false',    'kind': 14, 'detail': 'literal',     'insertText': 'false'},
    {'label': 'None',     'kind': 14, 'detail': 'literal',     'insertText': 'None'},
    {'label': 'Some',     'kind': 14, 'detail': 'constructor', 'insertText': 'Some($1)', 'insertTextFormat': 2},
    {'label': 'pub',      'kind': 14, 'detail': 'keyword',     'insertText': 'pub '},
    {'label': 'import',   'kind': 14, 'detail': 'keyword',     'insertText': 'import '},
    {'label': 'break',    'kind': 14, 'detail': 'keyword',     'insertText': 'break'},
    {'label': 'continue', 'kind': 14, 'detail': 'keyword',     'insertText': 'continue'},
    {'label': 'int',      'kind': 22, 'detail': 'type',        'insertText': 'int'},
    {'label': 'float',    'kind': 22, 'detail': 'type',        'insertText': 'float'},
    {'label': 'bool',     'kind': 22, 'detail': 'type',        'insertText': 'bool'},
    {'label': 'str',      'kind': 22, 'detail': 'type',        'insertText': 'str'},
    {'label': 'void',     'kind': 22, 'detail': 'type',        'insertText': 'void'},
    {'label': 'List',     'kind': 22, 'detail': 'type',        'insertText': 'List<'},
    {'label': 'Map',      'kind': 22, 'detail': 'type',        'insertText': 'Map<'},
    {'label': 'Option',   'kind': 22, 'detail': 'type',        'insertText': 'Option<'},
]

# Build full built-in completions from doc map
_BUILTIN_KINDS: dict[str, int] = {
    'print': 3, 'len': 3, 'push': 3, 'pop': 3, 'range': 3,
    'str': 3, 'int': 3, 'float': 3, 'bool': 3,
    'sqrt': 3, 'abs': 3, 'pow': 3, 'contains': 3,
    'to_int': 3, 'to_float': 3,
    'is_digit': 3, 'is_alpha': 3, 'is_alnum': 3,
    'str_get': 3, 'str_sub': 3, 'str_contains': 3,
    'str_split': 3, 'str_trim': 3, 'str_trim_start': 3, 'str_trim_end': 3,
    'str_replace': 3, 'str_replace_all': 3, 'str_join': 3,
    'to_upper': 3, 'to_lower': 3, 'starts_with': 3, 'ends_with': 3,
    'str_repeat': 3, 'str_reverse': 3, 'str_find': 3,
    'args': 3, 'read_file': 3, 'read_line': 3, 'read_lines': 3, 'write_file': 3,
    'exec': 3, 'eprint': 3, 'eprintln': 3, 'append_file': 3, 'temp_dir': 3, 'temp_file': 3, 'exit': 3,
    'chr': 3, 'ord': 3, 'isinstance': 3, 'zip': 3, 'enumerate': 3, 'batched': 3,
    'map_keys': 3, 'map_values': 3, 'map_items': 3,
    'map_contains': 3, 'map_get': 3, 'map_set': 3,
    'json_parse': 3, 'json_serialize': 3,
    'json_is_list': 3, 'json_is_dict': 3, 'json_is_int': 3, 'json_is_str': 3, 'json_is_bool': 3, 'json_is_float': 3,
    'json_as_int': 3, 'json_as_str': 3, 'json_as_list': 3, 'json_as_dict': 3,
    'json_keys': 3, 'json_get': 3, 'json_contains': 3, 'json_size': 3,
    'list_insert': 3, 'list_remove': 3,
    'fs_exists': 3, 'fs_is_file': 3, 'fs_is_dir': 3, 'fs_mkdir': 3,
    'fs_list_dir': 3, 'fs_remove': 3, 'fs_rename': 3, 'fs_copy': 3, 'fs_cwd': 3,
    'map': 3, 'filter': 3, 'sorted': 3, 'reduce': 3, 'for_each': 3, 'each': 3, 'any': 3, 'all': 3, 'find': 3, 'take_while': 3, 'drop_while': 3, 'reversed': 3,
    'parse_int': 3, 'str_format': 3,
    '_ox_http_request': 3,
    '_ox_http_headers_to_json': 3,
}

for _name, _kind in _BUILTIN_KINDS.items():
    _doc = _ALL_DOCS.get(_name)
    _item: dict = {
        'label': _name, 'kind': _kind, 'detail': 'builtin',
        'insertText': _name + '($1)',
        'insertTextFormat': 2,
    }
    if _doc:
        _item['documentation'] = {'kind': 'markdown', 'value': _doc}
    _KEYWORD_COMPLETIONS.append(_item)

# Math module completions (triggered when typing e.g. math.sin)
_MATH_COMPLETIONS: list[dict] = []
for _name, _docs in _MATH_DOCS.items():
    _MATH_COMPLETIONS.append({
        'label': f'math.{_name}',
        'kind': 3,
        'detail': 'math',
        'insertText': _name + '($1)',
        'insertTextFormat': 2,
        'filterText': _name,
        'documentation': {'kind': 'markdown', 'value': _docs},
    })

# Known function names for semantic token highlighting
_KNOWN_FUNCTIONS: set = set(_BUILTIN_KINDS.keys()) | set(_MATH_DOCS.keys())

# ── Signature help database ──────────────────────────────────

def _parse_signatures(doc: str) -> list[dict]:
    """Parse doc string into signature entries with label, doc, and parameters."""
    sigs: list[dict] = []
    for m in re.finditer(r'```oxybelis\n(.*?)```', doc, re.DOTALL):
        block = m.group(1).strip()
        for line in block.split('\n'):
            line = line.strip()
            if not line.startswith('fn '):
                continue
            params: list[dict] = []
            pm = re.match(r'fn\s+\w+\(([^)]*)\)', line)
            if pm:
                raw = pm.group(1).strip()
                if raw:
                    for p in raw.split(','):
                        p = p.strip()
                        if p:
                            params.append({'label': p, 'documentation': ''})
            sigs.append({
                'label': line,
                'documentation': {'kind': 'markdown', 'value': doc},
                'parameters': params,
            })
    return sigs

_SIGNATURES: dict[str, list[dict]] = {}
for _name, _doc in _ALL_DOCS.items():
    _sigs = _parse_signatures(_doc)
    if _sigs:
        _SIGNATURES[_name] = _sigs

# ═══════════════════════════════════════════════════════════════
#  LSP HANDLERS
# ═══════════════════════════════════════════════════════════════

def handle_initialize(msg: LSPMessage):
    conn.send_response(msg.id, {
        'capabilities': {
            'textDocumentSync': {
                'openClose': True,
                'change': 1,
                'save': True,
            },
            'semanticTokensProvider': {
                'legend': {
                    'tokenTypes': [
                        'keyword', 'type', 'string', 'number',
                        'operator', 'variable', 'function', 'parameter', 'comment',
                    ],
                    'tokenModifiers': [],
                },
                'range': False,
                'full': {'delta': False},
            },
            'definitionProvider': True,
            'hoverProvider': True,
            'completionProvider': {
                'triggerCharacters': [':', '.', '<'],
            },
            'signatureHelpProvider': {
                'triggerCharacters': ['(', ','],
            },
            'documentFormattingProvider': True,
        },
        'serverInfo': {
            'name': 'ox-lsp',
            'version': '0.5.0',
        }
    })


def handle_did_open(msg: LSPMessage):
    params = msg.params
    uri = params['textDocument']['uri']
    text = params['textDocument']['text']
    doc = state.get_or_create(uri)
    doc.source = text
    _publish_diagnostics(uri)


def handle_did_change(msg: LSPMessage):
    params = msg.params
    uri = params['textDocument']['uri']
    text = params['contentChanges'][0]['text']
    doc = state.get_or_create(uri)
    doc.source = text
    _publish_diagnostics(uri)


def _publish_diagnostics(uri: str):
    doc = state.documents.get(uri)
    if not doc:
        return
    diags = get_diagnostics(doc.source)
    conn.send_notification('textDocument/publishDiagnostics', {
        'uri': uri,
        'diagnostics': diags,
    })


def handle_hover(msg: LSPMessage):
    params = msg.params
    uri = params['textDocument']['uri']
    pos = params['position']
    doc = state.documents.get(uri)
    if not doc:
        conn.send_response(msg.id, None)
        return
    # Extract filesystem path from URI (file:///C:/... or file:///...)
    filepath = uri
    if filepath.startswith('file:///'):
        filepath = filepath[8:]  # strip 'file:///'
    result = get_hover(doc.source, pos['line'], pos['character'], filepath)
    conn.send_response(msg.id, result)


def _collect_symbols(stmts, seen, items):
    """Recursively collect FnDef, ClassDef, and VarDecl from statement lists."""
    for s in stmts:
        if isinstance(s, FnDef) and s.name not in seen:
            seen.add(s.name)
            items.append({'label': s.name, 'kind': 3, 'detail': 'function', 'insertText': f'{s.name}($1)', 'insertTextFormat': 2})
            _collect_symbols(s.body, seen, items)
        elif isinstance(s, ClassDef) and s.name not in seen:
            seen.add(s.name)
            items.append({'label': s.name, 'kind': 7, 'detail': 'class', 'insertText': s.name})
            for m in s.methods:
                _collect_symbols(m.body, seen, items)
        elif isinstance(s, VarDecl) and s.name not in seen:
            seen.add(s.name)
            items.append({'label': s.name, 'kind': 6, 'detail': s.type_ann or 'variable', 'insertText': s.name})
        elif isinstance(s, IfStmt):
            _collect_symbols(s.then_body, seen, items)
            for _, eb in s.elif_clauses:
                _collect_symbols(eb, seen, items)
            if s.else_body:
                _collect_symbols(s.else_body, seen, items)
        elif isinstance(s, ForStmt):
            _collect_symbols(s.body, seen, items)
        elif isinstance(s, WhileStmt):
            _collect_symbols(s.body, seen, items)
        elif isinstance(s, MatchStmt):
            for _, arm_body in s.arms:
                _collect_symbols(arm_body, seen, items)

_COMPLETION_RANKS: dict[int, int] = {
    3:  10,  # Function
    6:  11,  # Variable
    7:  12,  # Class
    22: 20,  # TypeParameter
    14: 30,  # Keyword
}

_MODULE_CACHE: dict[str, dict[str, dict]] = {}

def _get_oxlib_dir() -> str:
    base = os.path.dirname(os.path.abspath(__file__))
    oxlib = os.path.join(base, 'oxlib')
    if os.path.isdir(oxlib):
        return oxlib
    return ''

def _load_module_functions(mod_name: str) -> dict[str, dict]:
    if mod_name in _MODULE_CACHE:
        return _MODULE_CACHE[mod_name]
    oxlib = _get_oxlib_dir()
    if not oxlib:
        _log(f'oxlib dir not found')
        return {}
    filepath = os.path.join(oxlib, f'{mod_name}.ox')
    if not os.path.isfile(filepath):
        _log(f'module file not found: {filepath}')
        return {}
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            src = f.read()
        tokens = Lexer(src).tokenize()
        parser = Parser(tokens, src)
        ast = parser.parse()
        functions: dict[str, dict] = {}
        for s in ast.stmts:
            if isinstance(s, FnDef):
                if s.params:
                    placeholders = '${1:' + s.params[0][0] + '}'
                    for p in s.params[1:]:
                        placeholders += f', ${{1:{p[0]}}}'
                    insert = f'{s.name}({placeholders})'
                else:
                    insert = f'{s.name}($1)'
                functions[s.name] = {
                    'label': s.name,
                    'kind': 3,
                    'detail': f'{mod_name} function',
                    'insertText': insert,
                    'insertTextFormat': 2,
                }
            if isinstance(s, ClassDef):
                functions[s.name] = {
                    'label': s.name,
                    'kind': 7,
                    'detail': f'{mod_name} class',
                    'insertText': s.name,
                }
        _MODULE_CACHE[mod_name] = functions
        _log(f'Loaded {len(functions)} items from module {mod_name}')
        return functions
    except Exception as e:
        _log(f'Error loading module {mod_name}: {e}')
        return {}

def _find_imported_modules(stmts) -> list[str]:
    modules = []
    for s in stmts:
        if isinstance(s, ImportStmt):
            modules.append(s.path[0])
        if isinstance(s, FnDef):
            modules.extend(_find_imported_modules(s.body))
        if isinstance(s, ClassDef):
            for m in s.methods:
                modules.extend(_find_imported_modules(m.body))
    return modules

_LIST_METHODS: dict[str, dict] = {
    'push':           {'kind': 3, 'detail': 'List method', 'insertText': 'push($1)', 'insertTextFormat': 2},
    'pop':            {'kind': 3, 'detail': 'List method', 'insertText': 'pop()', 'insertTextFormat': 2},
    'len':            {'kind': 3, 'detail': 'List method', 'insertText': 'len()', 'insertTextFormat': 2},
    'contains':       {'kind': 3, 'detail': 'List method', 'insertText': 'contains($1)', 'insertTextFormat': 2},
    'filter':         {'kind': 3, 'detail': 'List method', 'insertText': 'filter($1)', 'insertTextFormat': 2},
    'map':            {'kind': 3, 'detail': 'List method', 'insertText': 'map($1)', 'insertTextFormat': 2},
    'reduce':         {'kind': 3, 'detail': 'List method', 'insertText': 'reduce($1)', 'insertTextFormat': 2},
    'for_each':       {'kind': 3, 'detail': 'List method', 'insertText': 'for_each($1)', 'insertTextFormat': 2},
    'each':           {'kind': 3, 'detail': 'List method', 'insertText': 'each($1)', 'insertTextFormat': 2},
    'any':            {'kind': 3, 'detail': 'List method', 'insertText': 'any($1)', 'insertTextFormat': 2},
    'all':            {'kind': 3, 'detail': 'List method', 'insertText': 'all($1)', 'insertTextFormat': 2},
    'find':           {'kind': 3, 'detail': 'List method', 'insertText': 'find($1)', 'insertTextFormat': 2},
    'sorted':         {'kind': 3, 'detail': 'List method', 'insertText': 'sorted()', 'insertTextFormat': 2},
    'reversed':       {'kind': 3, 'detail': 'List method', 'insertText': 'reversed()', 'insertTextFormat': 2},
    'sum':            {'kind': 3, 'detail': 'List method', 'insertText': 'sum()', 'insertTextFormat': 2},
    'min':            {'kind': 3, 'detail': 'List method', 'insertText': 'min()', 'insertTextFormat': 2},
    'max':            {'kind': 3, 'detail': 'List method', 'insertText': 'max()', 'insertTextFormat': 2},
    'take_while':     {'kind': 3, 'detail': 'List method', 'insertText': 'take_while($1)', 'insertTextFormat': 2},
    'drop_while':     {'kind': 3, 'detail': 'List method', 'insertText': 'drop_while($1)', 'insertTextFormat': 2},
    'chunked':        {'kind': 3, 'detail': 'List method', 'insertText': 'chunked($1)', 'insertTextFormat': 2},
    'windowed':       {'kind': 3, 'detail': 'List method', 'insertText': 'windowed($1)', 'insertTextFormat': 2},
    'pairwise':       {'kind': 3, 'detail': 'List method', 'insertText': 'pairwise()', 'insertTextFormat': 2},
    'cycle':          {'kind': 3, 'detail': 'List method', 'insertText': 'cycle()', 'insertTextFormat': 2},
    'combinations':   {'kind': 3, 'detail': 'List method', 'insertText': 'combinations($1)', 'insertTextFormat': 2},
    'permutations':   {'kind': 3, 'detail': 'List method', 'insertText': 'permutations()', 'insertTextFormat': 2},
    'list_insert':    {'kind': 3, 'detail': 'List method', 'insertText': 'list_insert($1)', 'insertTextFormat': 2},
    'list_remove':    {'kind': 3, 'detail': 'List method', 'insertText': 'list_remove($1)', 'insertTextFormat': 2},
}

_MAP_METHODS: dict[str, dict] = {
    'map_contains':   {'kind': 3, 'detail': 'Map method', 'insertText': 'map_contains($1)', 'insertTextFormat': 2},
    'map_get':        {'kind': 3, 'detail': 'Map method', 'insertText': 'map_get($1)', 'insertTextFormat': 2},
    'map_set':        {'kind': 3, 'detail': 'Map method', 'insertText': 'map_set($1)', 'insertTextFormat': 2},
    'len':            {'kind': 3, 'detail': 'Map method', 'insertText': 'len()', 'insertTextFormat': 2},
    'keys':           {'kind': 3, 'detail': 'Map method', 'insertText': 'keys()', 'insertTextFormat': 2},
    'values':         {'kind': 3, 'detail': 'Map method', 'insertText': 'values()', 'insertTextFormat': 2},
    'contains':       {'kind': 3, 'detail': 'Map method', 'insertText': 'contains($1)', 'insertTextFormat': 2},
    'filter':         {'kind': 3, 'detail': 'Map method', 'insertText': 'filter($1)', 'insertTextFormat': 2},
    'map':            {'kind': 3, 'detail': 'Map method', 'insertText': 'map($1)', 'insertTextFormat': 2},
    'for_each':       {'kind': 3, 'detail': 'Map method', 'insertText': 'for_each($1)', 'insertTextFormat': 2},
    'each':           {'kind': 3, 'detail': 'Map method', 'insertText': 'each($1)', 'insertTextFormat': 2},
}

_STR_METHODS: dict[str, dict] = {
    'len':            {'kind': 3, 'detail': 'str method', 'insertText': 'len()', 'insertTextFormat': 2},
    'contains':       {'kind': 3, 'detail': 'str method', 'insertText': 'contains($1)', 'insertTextFormat': 2},
    'str_sub':        {'kind': 3, 'detail': 'str method', 'insertText': 'str_sub($1)', 'insertTextFormat': 2},
    'str_get':        {'kind': 3, 'detail': 'str method', 'insertText': 'str_get($1)', 'insertTextFormat': 2},
    'str_split':      {'kind': 3, 'detail': 'str method', 'insertText': 'str_split($1)', 'insertTextFormat': 2},
    'str_trim':       {'kind': 3, 'detail': 'str method', 'insertText': 'str_trim()', 'insertTextFormat': 2},
    'str_trim_start': {'kind': 3, 'detail': 'str method', 'insertText': 'str_trim_start()', 'insertTextFormat': 2},
    'str_trim_end':   {'kind': 3, 'detail': 'str method', 'insertText': 'str_trim_end()', 'insertTextFormat': 2},
    'str_replace':    {'kind': 3, 'detail': 'str method', 'insertText': 'str_replace($1)', 'insertTextFormat': 2},
    'str_replace_all':{'kind': 3, 'detail': 'str method', 'insertText': 'str_replace_all($1)', 'insertTextFormat': 2},
    'str_repeat':     {'kind': 3, 'detail': 'str method', 'insertText': 'str_repeat($1)', 'insertTextFormat': 2},
    'str_reverse':    {'kind': 3, 'detail': 'str method', 'insertText': 'str_reverse()', 'insertTextFormat': 2},
    'str_find':       {'kind': 3, 'detail': 'str method', 'insertText': 'str_find($1)', 'insertTextFormat': 2},
    'to_upper':       {'kind': 3, 'detail': 'str method', 'insertText': 'to_upper()', 'insertTextFormat': 2},
    'to_lower':       {'kind': 3, 'detail': 'str method', 'insertText': 'to_lower()', 'insertTextFormat': 2},
    'starts_with':    {'kind': 3, 'detail': 'str method', 'insertText': 'starts_with($1)', 'insertTextFormat': 2},
    'ends_with':      {'kind': 3, 'detail': 'str method', 'insertText': 'ends_with($1)', 'insertTextFormat': 2},
    'is_digit':       {'kind': 3, 'detail': 'str method', 'insertText': 'is_digit()', 'insertTextFormat': 2},
    'is_alpha':       {'kind': 3, 'detail': 'str method', 'insertText': 'is_alpha()', 'insertTextFormat': 2},
    'is_alnum':       {'kind': 3, 'detail': 'str method', 'insertText': 'is_alnum()', 'insertTextFormat': 2},
    'str_contains':   {'kind': 3, 'detail': 'str method', 'insertText': 'str_contains($1)', 'insertTextFormat': 2},
    'str_join':       {'kind': 3, 'detail': 'str method', 'insertText': 'str_join($1)', 'insertTextFormat': 2},
}

_OPTION_METHODS: dict[str, dict] = {
    'value':          {'kind': 10, 'detail': 'Option field', 'insertText': 'value'},
    'is_some':        {'kind': 3, 'detail': 'Option method', 'insertText': 'is_some()', 'insertTextFormat': 2},
    'is_none':        {'kind': 3, 'detail': 'Option method', 'insertText': 'is_none()', 'insertTextFormat': 2},
    'unwrap':         {'kind': 3, 'detail': 'Option method', 'insertText': 'unwrap()', 'insertTextFormat': 2},
    'unwrap_or':      {'kind': 3, 'detail': 'Option method', 'insertText': 'unwrap_or($1)', 'insertTextFormat': 2},
}

_TYPE_METHODS: dict[str, dict[str, dict]] = {
    'List':   _LIST_METHODS,
    'Map':    _MAP_METHODS,
    'str':    _STR_METHODS,
    'Option': _OPTION_METHODS,
}

def _base_type(ty: str) -> str:
    idx = ty.find('<')
    if idx >= 0:
        return ty[:idx]
    return ty

def _find_class_def(stmts, name: str):
    for s in stmts:
        if isinstance(s, ClassDef):
            if s.name == name:
                return s
            for m in s.methods:
                found = _find_class_def(m.body, name)
                if found:
                    return found
        if isinstance(s, FnDef):
            found = _find_class_def(s.body, name)
            if found:
                return found
    return None

def _get_member_methods(ty: str) -> dict[str, dict]:
    base = _base_type(ty)
    return _TYPE_METHODS.get(base, {})

def _completion_sort_key(item: dict) -> tuple[int, str]:
    kind = item.get('kind', 99)
    rank = _COMPLETION_RANKS.get(kind, 50)
    return (rank, item.get('label', ''))

def _find_var_type_text(source: str, var_name: str) -> str:
    for m in re.finditer(rf'\b(?:var|let)\s+{re.escape(var_name)}\s*:\s*([^\s=;]+)', source):
        return m.group(1).strip()
    return ''

def _find_var_type(ast, var_name: str) -> str:
    for s in ast.stmts:
        if isinstance(s, VarDecl) and s.name == var_name:
            return s.type_ann or ''
        if isinstance(s, FnDef):
            found = _find_var_type_stmts(s.body, var_name)
            if found:
                return found
        if isinstance(s, ClassDef):
            for m in s.methods:
                found = _find_var_type_stmts(m.body, var_name)
                if found:
                    return found
    return ''

def _find_var_type_stmts(stmts, var_name: str) -> str:
    for s in stmts:
        if isinstance(s, VarDecl) and s.name == var_name:
            return s.type_ann or ''
        if isinstance(s, ForStmt):
            if getattr(s, 'var', '') == var_name or var_name in getattr(s, 'vars', []):
                return ''
            found = _find_var_type_stmts(s.body, var_name)
            if found:
                return found
        if isinstance(s, IfStmt):
            found = _find_var_type_stmts(s.then_body, var_name)
            if found:
                return found
            for _, eb in s.elif_clauses:
                found = _find_var_type_stmts(eb, var_name)
                if found:
                    return found
            if s.else_body:
                found = _find_var_type_stmts(s.else_body, var_name)
                if found:
                    return found
        if isinstance(s, WhileStmt):
            found = _find_var_type_stmts(s.body, var_name)
            if found:
                return found
        if isinstance(s, MatchStmt):
            for _, arm_body in s.arms:
                found = _find_var_type_stmts(arm_body, var_name)
                if found:
                    return found
    return ''

def _detect_member_access(source: str, line: int, col: int) -> tuple[str, str] | None:
    """Check if cursor is after 'expr.' and return (var_name, prefix)."""
    lines = source.split('\n')
    if line >= len(lines):
        return None
    line_text = lines[line]
    before = line_text[:col]
    stripped = before.rstrip()
    dot_idx = stripped.rfind('.')
    if dot_idx < 0:
        return None
    before_dot = stripped[:dot_idx].rstrip()
    if not before_dot:
        return None
    var_name = ''
    for ch in reversed(before_dot):
        if ch.isalnum() or ch == '_':
            var_name = ch + var_name
        else:
            break
    if not var_name:
        return None
    prefix = stripped[dot_idx + 1:]
    return (var_name, prefix)

def handle_completion(msg: LSPMessage):
    params = msg.params
    uri = params.get('textDocument', {}).get('uri', '')
    pos = params.get('position', {})
    line = pos.get('line', 0)
    col = pos.get('character', 0)
    doc = state.documents.get(uri)
    member_info = None
    if doc:
        member_info = _detect_member_access(doc.source, line, col)
    items: list[dict] = []
    if member_info and doc:
        _log(f'Member access: var={member_info[0]!r} prefix={member_info[1]!r}')
        var_name, prefix = member_info
        if var_name == 'math':
            for name, doc_text in _MATH_DOCS.items():
                if name.startswith(prefix):
                    items.append({
                        'label': name,
                        'kind': 3,
                        'detail': 'math',
                        'insertText': f'{name}($1)',
                        'insertTextFormat': 2,
                        'documentation': {'kind': 'markdown', 'value': doc_text},
                    })
        else:
            var_type = ''
            ast = None
            imported = []
            try:
                tokens = Lexer(doc.source).tokenize()
                parser = Parser(tokens, doc.source)
                ast = parser.parse()
                var_type = _find_var_type(ast, var_name)
                imported = _find_imported_modules(ast.stmts)
                _log(f'AST lookup: var={var_name!r} type={var_type!r} imported={imported}')
            except Exception:
                _log(f'AST parse failed, trying text/fallback')
            if not imported and not var_type:
                for m in re.finditer(r'\bimport\s+(\w+)', doc.source):
                    imported.append(m.group(1))
            if var_name in imported:
                mod_fns = _load_module_functions(var_name)
                for name, meta in mod_fns.items():
                    if name.startswith(prefix):
                        item = {
                            'label': meta['label'],
                            'kind': meta['kind'],
                            'detail': meta['detail'],
                            'insertText': meta['insertText'],
                        }
                        if 'insertTextFormat' in meta:
                            item['insertTextFormat'] = meta['insertTextFormat']
                        items.append(item)
            if not var_type:
                var_type = _find_var_type_text(doc.source, var_name)
                _log(f'Text lookup: var={var_name!r} type={var_type!r}')
            if var_type:
                base = _base_type(var_type)
                cls = None
                if ast is not None:
                    cls = _find_class_def(ast.stmts, base)
                _log(f'Type: base={base!r} cls={cls is not None}')
                if cls is not None:
                    seen = set()
                    for fn in cls.methods:
                        if fn.name.startswith(prefix) and fn.name not in seen:
                            seen.add(fn.name)
                            items.append({
                                'label': fn.name,
                                'kind': 3,
                                'detail': f'{cls.name} method',
                                'insertText': f'{fn.name}($1)',
                                'insertTextFormat': 2,
                            })
                    for fname, _ in cls.fields:
                        if fname.startswith(prefix) and fname not in seen:
                            seen.add(fname)
                            items.append({
                                'label': fname,
                                'kind': 6,
                                'detail': f'{cls.name} field',
                                'insertText': fname,
                            })
                else:
                    methods = _get_member_methods(var_type)
                    for name, meta in methods.items():
                        if name.startswith(prefix):
                            item = {
                                'label': name,
                                'kind': meta['kind'],
                                'detail': meta['detail'],
                                'insertText': meta['insertText'],
                            }
                            if 'insertTextFormat' in meta:
                                item['insertTextFormat'] = meta['insertTextFormat']
                            doc_text = _ALL_DOCS.get(name)
                            if doc_text:
                                item['documentation'] = {'kind': 'markdown', 'value': doc_text}
                            items.append(item)
    if not items:
        _log('Falling back to full completions')
        items = list(_KEYWORD_COMPLETIONS)
        if doc:
            try:
                tokens = Lexer(doc.source).tokenize()
                parser = Parser(tokens, doc.source)
                ast = parser.parse()
                seen = {c['label'] for c in _KEYWORD_COMPLETIONS}
                _collect_symbols(ast.stmts, seen, items)
            except Exception:
                pass
        items.extend(_MATH_COMPLETIONS)
    items.sort(key=_completion_sort_key)
    conn.send_response(msg.id, {
        'isIncomplete': False,
        'items': items,
    })


def handle_semantic_tokens(msg: LSPMessage):
    params = msg.params
    uri = params['textDocument']['uri']
    doc = state.documents.get(uri)
    if not doc:
        conn.send_response(msg.id, {'data': []})
        return
    tokens = get_semantic_tokens(doc.source)
    conn.send_response(msg.id, {'data': tokens})


def handle_formatting(msg: LSPMessage):
    params = msg.params
    uri = params['textDocument']['uri']
    doc = state.documents.get(uri)
    if not doc:
        conn.send_response(msg.id, None)
        return
    try:
        formatted = format_source(doc.source)
        conn.send_response(msg.id, [
            {
                'range': {
                    'start': {'line': 0, 'character': 0},
                    'end': {'line': len(doc.source.splitlines()), 'character': 0},
                },
                'newText': formatted,
            }
        ])
    except Exception as e:
        conn.send_error(msg.id, -32603, str(e))


def handle_definition(msg: LSPMessage):
    params = msg.params
    uri = params['textDocument']['uri']
    pos = params['position']
    doc = state.documents.get(uri)
    if not doc:
        conn.send_response(msg.id, None)
        return
    result = get_definition(doc.source, pos['line'], pos['character'], uri)
    conn.send_response(msg.id, result)


def handle_shutdown(msg: LSPMessage):
    conn.send_response(msg.id, None)
    sys.exit(0)


def handle_signature_help(msg: LSPMessage):
    params = msg.params
    uri = params['textDocument']['uri']
    pos = params['position']
    doc = state.documents.get(uri)
    if not doc:
        conn.send_response(msg.id, None)
        return
    line = pos['line']
    col = pos['character']
    source = doc.source
    try:
        tokens = list(Lexer(source).tokenize())
    except Exception:
        conn.send_response(msg.id, None)
        return

    # ── Find the function call that encloses cursor ──
    # Walk tokens to find the last LPAREN before position with matching nesting
    fn_name = None
    active_param = 0
    paren_depth = 0
    best_fn = None
    best_lparen = None  # (token_index, line, col)

    for i, tok in enumerate(tokens):
        if tok.type == TT.EOF:
            break
        if tok.line - 1 > line or (tok.line - 1 == line and tok.col - 1 >= col):
            break
        # Track nesting
        if tok.type == TT.LPAREN:
            # Check if there's an IDENT just before this LPAREN (function call)
            fn_candidate = None
            if i > 0 and tokens[i - 1].type == TT.IDENT:
                fn_candidate = tokens[i - 1].value
            paren_depth += 1
            best_fn = fn_candidate
            best_lparen = (i, tok.line - 1, tok.col - 1)
        elif tok.type == TT.RPAREN:
            if paren_depth > 0:
                paren_depth -= 1
            if paren_depth == 0:
                best_fn = None
                best_lparen = None
        elif tok.type == TT.COMMA and best_lparen is not None and paren_depth > 0:
            # Only count commas at the same paren depth as the best LPAREN
            # For simplicity, count all commas at any depth if we're inside the call
            pass  # We'll count commas inside the active call range

    if best_lparen is None or best_fn is None:
        conn.send_response(msg.id, None)
        return

    # ── Count active parameter by scanning between LPAREN and cursor ──
    lparen_idx, lp_line, lp_col = best_lparen
    # Find cursor offset in source
    source_lines = source.split('\n')
    offset = 0
    for sl in range(line):
        offset += len(source_lines[sl]) + 1
    offset += col

    # Find LPAREN offset
    lp_offset = 0
    for sl in range(lp_line):
        lp_offset += len(source_lines[sl]) + 1
    lp_offset += lp_col

    # Count commas between LPAREN and cursor at depth 0
    depth = 0
    active_param = 0
    for j in range(lp_offset + 1, offset):
        c = source[j]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
        elif c == ',' and depth == 0:
            active_param += 1

    # ── Look up signature ──
    sigs = _SIGNATURES.get(best_fn)
    if not sigs:
        conn.send_response(msg.id, None)
        return

    conn.send_response(msg.id, {
        'signatures': sigs,
        'activeSignature': 0,
        'activeParameter': min(active_param, len(sigs[0]['parameters']) - 1 if sigs[0]['parameters'] else 0),
    })


_HANDLERS = {
    'initialize':                         handle_initialize,
    'initialized':                        lambda msg: None,
    'textDocument/didOpen':               handle_did_open,
    'textDocument/didChange':             handle_did_change,
    'textDocument/definition':            handle_definition,
    'textDocument/hover':                 handle_hover,
    'textDocument/completion':            handle_completion,
    'textDocument/signatureHelp':         handle_signature_help,
    'textDocument/semanticTokens/full':   handle_semantic_tokens,
    'textDocument/formatting':            handle_formatting,
    '$/cancelRequest':                    lambda msg: None,
    'shutdown':                           handle_shutdown,
}


# ═══════════════════════════════════════════════════════════════
#  CLI DIAGNOSTIC CHECK
# ═══════════════════════════════════════════════════════════════

def cli_check(filepath: str):
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    with open(filepath, encoding='utf-8') as f:
        src = f.read()
    _, diags = compile_source(src, filepath, check_only=True)
    src_file = SourceFile(src, filepath)
    if diags:
        print(render_diagnostics(diags, src_file))
    has_error = any(d.severity == Severity.ERROR for d in diags)
    if has_error:
        sys.exit(1)
    print(f"\033[32m✓ {filepath} – no errors\033[0m")


# ═══════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════

def main():
    _log('=== main() called ===')
    if hasattr(sys.stdout, 'reconfigure'):
        try:
            sys.stdout.reconfigure(encoding='utf-8')
            _log('stdout reconfigured to utf-8')
        except Exception as e:
            _log(f'stdout reconfigure failed: {e}')
    if len(sys.argv) > 1:
        if sys.argv[1] == 'check':
            cli_check(sys.argv[2])
            return
        if sys.argv[1] == 'highlight':
            with open(sys.argv[2], encoding='utf-8') as f:
                print(highlight_ox(f.read()))
            return

    _log('entering main loop')
    while True:
        msg = conn.read_message()
        if msg is None:
            _log('read_message returned None – breaking')
            break
        _log(f'got message: method={msg.method} id={msg.id}')
        if msg.method == 'exit':
            _log('exit notification – breaking')
            break
        handler = _HANDLERS.get(msg.method)
        if handler:
            try:
                handler(msg)
                _log(f'handler {msg.method} OK')
            except Exception as e:
                _log(f'HANDLER ERROR {msg.method}: {e}\n{traceback.format_exc()}')
                if msg.id:
                    conn.send_error(msg.id, -32603, str(e))
                traceback.print_exc()
        elif msg.id:
            conn.send_response(msg.id, None)
            _log(f'sent null response for unknown method {msg.method}')
    _log('main loop exited')


if __name__ == '__main__':
    main()
