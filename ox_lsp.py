#!/usr/bin/env python3
"""
Oxybelis Language Server Protocol (LSP) server.
Provides diagnostics, syntax highlighting (semantic tokens), hover, and completions.

Usage:  python ox_lsp.py            # stdio LSP server (for VSCode, neovim, etc.)
        python ox_lsp.py check <file.ox>   # CLI diagnostic check
"""

from __future__ import annotations

import sys
import json
import traceback
from dataclasses import dataclass, field
from typing import Optional, List as PyList, Any

import io, os, atexit, sys

_D_FILE = open(rf'D:\Projects\oxybelis\lsp_debug_{os.getpid()}.log', 'w', encoding='utf-8')
def D(*args):
    msg = "[ox-lsp] " + " ".join(str(a) for a in args) + "\n"
    _D_FILE.write(msg)
    _D_FILE.flush()
    # Also write to stderr which VS Code captures
    sys.stderr.write(msg)
    sys.stderr.flush()

D("MODULE LOADED", f"pid={os.getpid()}", f"argv={sys.argv}")

from oxybelis import Lexer, Parser, TypeChecker, compile_source, TT
from ox_diag import (Span, Severity, Diagnostic, SourceFile,
                     render_diagnostics, highlight_ox)
from ox_fmt import format_source


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

    def _fill(self, needed: int) -> bool:
        """Ensure at least `needed` bytes are in the buffer. Returns False on EOF."""
        while len(self._buf) < needed:
            chunk = sys.stdin.buffer.read1(65536)
            if not chunk:
                return False
            self._buf += chunk
        return True

    def read_message(self) -> Optional[LSPMessage]:
        # Read until we have the header delimiter
        if not self._fill(1):
            return None
        while b'\r\n\r\n' not in self._buf:
            if not self._fill(len(self._buf) + 1):
                return None

        header, _, rest = self._buf.partition(b'\r\n\r\n')
        D(f"found header: {header[:100]!r}")
        self._buf = rest
        content_length = 0
        for line in header.decode('ascii').split('\r\n'):
            if line.lower().startswith('content-length:'):
                content_length = int(line.split(':')[1].strip())
                D(f"parsed content_length={content_length}")

        if content_length <= 0:
            D("invalid content_length")
            return None

        # Read full body
        if not self._fill(content_length):
            D("EOF reading body")
            return None
        raw = self._buf[:content_length]
        self._buf = self._buf[content_length:]

        D(f"parsing body of {len(raw)} bytes: {raw[:80]!r}")
        try:
            msg = json.loads(raw.decode('utf-8'))
            D(f"parsed msg: method={msg.get('method','?')}, id={msg.get('id','?')}")
            return LSPMessage(
                method=msg.get('method', ''),
                params=msg.get('params', {}),
                id=msg.get('id'),
                result=msg.get('result'),
                error=msg.get('error'),
            )
        except json.JSONDecodeError as e:
            D(f"JSON decode error: {e}")
            return None

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
        sys.stdout.buffer.write(header.encode('ascii'))
        sys.stdout.buffer.write(body)
        sys.stdout.buffer.flush()


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
        msg = d.message
        if d.notes:
            note_msgs = [n[0] for n in d.notes]
            msg += ' — ' + '; '.join(note_msgs)
        diag: dict = {
            'severity': _SEV_MAP.get(d.severity, 1),
            'message': msg,
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
        lsp_diags.append(diag)

    if not lsp_diags:
        # Parse errors might not appear in compile_source diags
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
#  SYNTACTIC TOKENS for semantic tokens
# ═══════════════════════════════════════════════════════════════

_OX_KEYWORDS = frozenset({
    'fn', 'let', 'var', 'class', 'if', 'else', 'elif',
    'for', 'in', 'while', 'return', 'match', 'lazy', 'pub',
    'true', 'false', 'None', 'Some', 'import', 'and', 'or', 'not',
    'break', 'continue', 'self',
})
_OX_TYPES = frozenset({'int', 'float', 'bool', 'str', 'void', 'List', 'Map', 'Option'})

# LSP semantic token types
TOKEN_KEYWORD = 0
TOKEN_TYPE = 1
TOKEN_STRING = 2
TOKEN_NUMBER = 3
TOKEN_OPERATOR = 4
TOKEN_VARIABLE = 5
TOKEN_FUNCTION = 6
TOKEN_PARAMETER = 7
TOKEN_COMMENT = 8


def get_semantic_tokens(source: str) -> PyList[int]:
    tokens_data: PyList[int] = []
    prev_line = 0
    prev_col = 0
    ltokens = list(Lexer(source).tokenize())

    for i, tok in enumerate(ltokens):
        if tok.type == TT.EOF:
            break

        line = tok.line - 1
        col = tok.col - 1
        length = max(tok.length, 1)
        word = tok.value

        tok_type = -1
        if tok.type in (TT.FN, TT.LET, TT.VAR, TT.CLASS, TT.IF, TT.ELSE, TT.ELIF,
                        TT.FOR, TT.IN, TT.WHILE, TT.RETURN, TT.MATCH, TT.LAZY,
                        TT.PUB, TT.BREAK, TT.CONTINUE):
            tok_type = TOKEN_KEYWORD
        elif word in _OX_KEYWORDS:
            tok_type = TOKEN_KEYWORD
        elif tok.type in (TT.T_INT, TT.T_FLOAT, TT.T_BOOL, TT.T_STR, TT.T_VOID):
            tok_type = TOKEN_TYPE
        elif word in _OX_TYPES:
            tok_type = TOKEN_TYPE
        elif tok.type in (TT.INT_LIT, TT.FLOAT_LIT):
            tok_type = TOKEN_NUMBER
        elif tok.type == TT.STR_LIT:
            tok_type = TOKEN_STRING
        elif tok.type == TT.IDENT:
            if word == '_':
                continue
            prev_tok = ltokens[i - 1] if i > 0 else None
            next_tok = ltokens[i + 1] if i < len(ltokens) - 1 else None
            if prev_tok and prev_tok.type == TT.FN:
                tok_type = TOKEN_FUNCTION
            elif prev_tok and prev_tok.type == TT.CLASS:
                tok_type = TOKEN_TYPE
            elif prev_tok and prev_tok.type == TT.DOT:
                tok_type = TOKEN_FUNCTION
            elif next_tok and next_tok.type == TT.LPAREN:
                tok_type = TOKEN_FUNCTION
            elif prev_tok and prev_tok.type in (TT.LPAREN, TT.COMMA) and next_tok and next_tok.type == TT.COLON:
                tok_type = TOKEN_PARAMETER
            else:
                tok_type = TOKEN_VARIABLE
        elif tok.type in (TT.PLUS, TT.MINUS, TT.STAR, TT.SLASH, TT.PERCENT,
                          TT.EQ, TT.NEQ, TT.LT, TT.GT, TT.LEQ, TT.GEQ,
                          TT.ASSIGN, TT.PLUS_ASSIGN, TT.MINUS_ASSIGN,
                          TT.STAR_ASSIGN, TT.SLASH_ASSIGN,
                          TT.DOTDOT, TT.ARROW, TT.FAT_ARROW, TT.BANG,
                          TT.AND, TT.OR, TT.NOT):
            tok_type = TOKEN_OPERATOR
        elif tok.type in (TT.LBRACE, TT.RBRACE, TT.LPAREN, TT.RPAREN,
                          TT.LBRACKET, TT.RBRACKET,
                          TT.COLON, TT.COMMA, TT.SEMI, TT.DOT):
            tok_type = TOKEN_OPERATOR

        if tok_type >= 0:
            delta_line = line - prev_line
            delta_col = col if delta_line > 0 else col - prev_col
            tokens_data.extend([delta_line, delta_col, length, tok_type, 0])
            prev_line = line
            prev_col = col + length

    return tokens_data


# ═══════════════════════════════════════════════════════════════
#  HOVER
# ═══════════════════════════════════════════════════════════════

def get_hover(source: str, line: int, col: int) -> Optional[dict]:
    try:
        tokens = Lexer(source).tokenize()
        parser = Parser(tokens, source)
        ast = parser.parse()
        spans = parser.get_spans()
        src_file = SourceFile(source)

        # Find the node at the given position
        offset = 0
        for _ in range(line):
            offset = source.find('\n', offset) + 1
            if offset == 0:
                break
        offset += col

        checker = TypeChecker(spans, src_file)
        checker.check(ast)
        for node, sp in spans.items():
            if sp.start <= offset < sp.end:
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
        return None
        return None
    except Exception:
        return None


def _find_node_in_stmt_list(stmts, target_id):
    for s in stmts:
        result = _recurse_find(s, target_id)
        if result:
            return result
    return None


_CHILD_ATTRS = [
    'body', 'then_body', 'else_body', 'elif_clauses', 'arms',
    'left', 'right', 'operand', 'value', 'expr', 'cond',
    'func', 'obj', 'idx', 'target', 'iterable', 'subject',
    'name_node',
]

_EXPR_NODE_TYPES = {}


def _recurse_find(node, target_id):
    if node is None:
        return None
    if id(node) == target_id:
        return node
    if isinstance(node, (list, tuple)):
        for child in node:
            if isinstance(child, tuple):
                for c in child:
                    result = _recurse_find(c, target_id)
                    if result:
                        return result
            else:
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
        for fname, fval in node.fields:
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
#  COMPLETIONS
# ═══════════════════════════════════════════════════════════════

_KEYWORD_COMPLETIONS = [
    {'label': 'fn', 'kind': 14, 'detail': 'keyword', 'insertText': 'fn '},
    {'label': 'let', 'kind': 14, 'detail': 'keyword', 'insertText': 'let '},
    {'label': 'var', 'kind': 14, 'detail': 'keyword', 'insertText': 'var '},
    {'label': 'class', 'kind': 14, 'detail': 'keyword', 'insertText': 'class '},
    {'label': 'if', 'kind': 14, 'detail': 'keyword', 'insertText': 'if '},
    {'label': 'else', 'kind': 14, 'detail': 'keyword', 'insertText': 'else '},
    {'label': 'elif', 'kind': 14, 'detail': 'keyword', 'insertText': 'elif '},
    {'label': 'for', 'kind': 14, 'detail': 'keyword', 'insertText': 'for '},
    {'label': 'while', 'kind': 14, 'detail': 'keyword', 'insertText': 'while '},
    {'label': 'return', 'kind': 14, 'detail': 'keyword', 'insertText': 'return '},
    {'label': 'match', 'kind': 14, 'detail': 'keyword', 'insertText': 'match '},
    {'label': 'true', 'kind': 14, 'detail': 'literal', 'insertText': 'true'},
    {'label': 'false', 'kind': 14, 'detail': 'literal', 'insertText': 'false'},
    {'label': 'None', 'kind': 14, 'detail': 'literal', 'insertText': 'None'},
    {'label': 'Some', 'kind': 14, 'detail': 'constructor', 'insertText': 'Some()'},
    {'label': 'pub', 'kind': 14, 'detail': 'keyword', 'insertText': 'pub '},
    {'label': 'import', 'kind': 14, 'detail': 'keyword', 'insertText': 'import '},
    {'label': 'break', 'kind': 14, 'detail': 'keyword', 'insertText': 'break'},
    {'label': 'continue', 'kind': 14, 'detail': 'keyword', 'insertText': 'continue'},
    {'label': 'int', 'kind': 22, 'detail': 'type', 'insertText': 'int'},
    {'label': 'float', 'kind': 22, 'detail': 'type', 'insertText': 'float'},
    {'label': 'bool', 'kind': 22, 'detail': 'type', 'insertText': 'bool'},
    {'label': 'str', 'kind': 22, 'detail': 'type', 'insertText': 'str'},
    {'label': 'void', 'kind': 22, 'detail': 'type', 'insertText': 'void'},
    {'label': 'List', 'kind': 22, 'detail': 'type', 'insertText': 'List<'},
    {'label': 'Map', 'kind': 22, 'detail': 'type', 'insertText': 'Map<'},
    {'label': 'Option', 'kind': 22, 'detail': 'type', 'insertText': 'Option<'},
    {'label': 'print', 'kind': 3, 'detail': 'builtin', 'insertText': 'print()'},
    {'label': 'len', 'kind': 3, 'detail': 'builtin', 'insertText': 'len()'},
    {'label': 'push', 'kind': 3, 'detail': 'builtin', 'insertText': 'push()'},
    {'label': 'pop', 'kind': 3, 'detail': 'builtin', 'insertText': 'pop()'},
    {'label': 'range', 'kind': 3, 'detail': 'builtin', 'insertText': 'range()'},
]

CompletionItemKind = {
    'Text': 1, 'Method': 2, 'Function': 3, 'Constructor': 4,
    'Field': 5, 'Variable': 6, 'Class': 7, 'Interface': 8,
    'Module': 9, 'Property': 10, 'Unit': 11, 'Value': 12,
    'Enum': 13, 'Keyword': 14, 'Snippet': 15, 'Color': 16,
    'File': 17, 'Reference': 18, 'Folder': 19, 'EnumMember': 20,
    'Constant': 21, 'Struct': 22, 'Event': 23, 'Operator': 24,
    'TypeParameter': 25,
}


# ═══════════════════════════════════════════════════════════════
#  LSP HANDLERS
# ═══════════════════════════════════════════════════════════════

def handle_initialize(msg: LSPMessage):
    conn.send_response(msg.id, {
        'capabilities': {
            'textDocumentSync': {
                'openClose': True,
                'change': 1,  # Full (TextDocumentSyncKind.Full)
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
            'hoverProvider': True,
            'completionProvider': {
                'triggerCharacters': [':', '.', '<'],
            },
            'documentFormattingProvider': True,
        },
        'serverInfo': {
            'name': 'ox-lsp',
            'version': '0.2.0',
        }
    })


def handle_did_open(msg: LSPMessage):
    params = msg.params
    uri = params['textDocument']['uri']
    text = params['textDocument']['text']
    D(f"didOpen: uri={uri}, text_len={len(text)}")
    doc = state.get_or_create(uri)
    doc.source = text
    D(f"didOpen: stored doc, keys={list(state.documents.keys())}")
    _publish_diagnostics(uri)


def handle_did_change(msg: LSPMessage):
    params = msg.params
    uri = params['textDocument']['uri']
    text = params['contentChanges'][0]['text']
    D(f"didChange: uri={uri}, text_len={len(text)}")
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
    D(f"hover: uri={uri}, line={pos['line']}, col={pos['character']}")
    D(f"hover: doc keys={list(state.documents.keys())}")
    doc = state.documents.get(uri)
    if not doc:
        D(f"hover: DOC NOT FOUND for {uri}")
        conn.send_response(msg.id, None)
        return
    result = get_hover(doc.source, pos['line'], pos['character'])
    D(f"hover: result={result}")
    conn.send_response(msg.id, result)


def handle_completion(msg: LSPMessage):
    items = list(_KEYWORD_COMPLETIONS)
    uri = msg.params.get('textDocument', {}).get('uri', '')
    D(f"completion: uri={uri}")
    D(f"completion: doc keys={list(state.documents.keys())}")
    doc = state.documents.get(uri)
    if doc:
        D("completion: doc found, adding user symbols")
        try:
            from oxybelis import Lexer, Parser, FnDef, ClassDef, VarDecl
            tokens = Lexer(doc.source).tokenize()
            parser = Parser(tokens, doc.source)
            ast = parser.parse()
            seen = {c['label'] for c in _KEYWORD_COMPLETIONS}
            for s in ast.stmts:
                if isinstance(s, FnDef) and s.name not in seen:
                    seen.add(s.name)
                    items.append({
                        'label': s.name,
                        'kind': 3,
                        'detail': 'function',
                        'insertText': s.name,
                    })
                if isinstance(s, ClassDef) and s.name not in seen:
                    seen.add(s.name)
                    items.append({
                        'label': s.name,
                        'kind': 7,
                        'detail': 'class',
                        'insertText': s.name,
                    })
                if isinstance(s, VarDecl) and s.name not in seen:
                    seen.add(s.name)
                    items.append({
                        'label': s.name,
                        'kind': 6,
                        'detail': s.type_ann or 'variable',
                        'insertText': s.name,
                    })
        except Exception:
            pass
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


def handle_shutdown(msg: LSPMessage):
    conn.send_response(msg.id, None)
    sys.exit(0)


_HANDLERS = {
    'initialize': handle_initialize,
    'initialized': lambda msg: None,
    'textDocument/didOpen': handle_did_open,
    'textDocument/didChange': handle_did_change,
    'textDocument/hover': handle_hover,
    'textDocument/completion': handle_completion,
    'textDocument/semanticTokens/full': handle_semantic_tokens,
    'textDocument/formatting': handle_formatting,
    '$/cancelRequest': lambda msg: None,
    'shutdown': handle_shutdown,
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
    D("main() entered", f"argv={sys.argv}")
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    if len(sys.argv) > 1:
        if sys.argv[1] == 'check':
            cli_check(sys.argv[2])
            return
        if sys.argv[1] == 'highlight':
            with open(sys.argv[2], encoding='utf-8') as f:
                print(highlight_ox(f.read()))
            return

    # LSP mode: JSON-RPC over stdio
    while True:
        msg = conn.read_message()
        if msg is None:
            D("read_message returned None, exiting")
            break
        if msg.method == 'exit':
            D("got exit notification")
            break
        D(f"handle: method={msg.method}, id={msg.id}")
        handler = _HANDLERS.get(msg.method)
        if handler:
            try:
                handler(msg)
            except Exception as e:
                D(f"handler exception: {e}")
                traceback.print_exc(file=sys.stderr)
                if msg.id:
                    conn.send_error(msg.id, -32603, str(e))
        elif msg.id:
            D(f"no handler for {msg.method}")
            conn.send_response(msg.id, None)


if __name__ == '__main__':
    main()
