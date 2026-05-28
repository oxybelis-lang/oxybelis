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
        self._buf = ''
        self._content_length = 0

    def read_message(self) -> Optional[LSPMessage]:
        while True:
            if '\r\n\r\n' in self._buf:
                header, _, rest = self._buf.partition('\r\n\r\n')
                self._buf = rest
                for line in header.split('\r\n'):
                    if line.lower().startswith('content-length:'):
                        self._content_length = int(line.split(':')[1].strip())
                if self._content_length > 0 and len(rest) >= self._content_length:
                    raw = rest[:self._content_length]
                    self._buf = rest[self._content_length:]
                    self._content_length = 0
                    try:
                        msg = json.loads(raw)
                        return LSPMessage(
                            method=msg.get('method', ''),
                            params=msg.get('params', {}),
                            id=msg.get('id'),
                            result=msg.get('result'),
                            error=msg.get('error'),
                        )
                    except json.JSONDecodeError:
                        return None
                return None
            chunk = sys.stdin.buffer.read(4096)
            if not chunk:
                return None
            self._buf += chunk.decode('utf-8')

    def send_notification(self, method: str, params: dict = None):
        self._send({'jsonrpc': '2.0', 'method': method, 'params': params or {}})

    def send_response(self, msg_id: int, result: Any = None):
        self._send({'jsonrpc': '2.0', 'id': msg_id, 'result': result})

    def send_error(self, msg_id: int, code: int, message: str):
        self._send({'jsonrpc': '2.0', 'id': msg_id,
                    'error': {'code': code, 'message': message}})

    def _send(self, obj: dict):
        data = json.dumps(obj, ensure_ascii=False)
        raw = f'Content-Length: {len(data)}\r\n\r\n{data}'
        sys.stdout.buffer.write(raw.encode('utf-8'))
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
    'break', 'continue',
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
    i = 0
    prev_line = 0
    prev_col = 0
    ltokens = list(Lexer(source).tokenize())

    for tok in ltokens:
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
        elif word in ('true', 'false', 'None', 'Some', 'and', 'or', 'not'):
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

        for node, sp in spans.items():
            if sp.start <= offset < sp.end:
                # Found a node — try to get its type
                try:
                    checker = TypeChecker(spans, src_file)
                    checker.check(ast)
                    node_obj = _find_node_in_stmt_list(ast.stmts, id(node))
                    if node_obj:
                        ty = checker._infer_type(node_obj)
                        return {
                            'contents': {
                                'kind': 'markdown',
                                'value': f"```oxybelis\n{ty}\n```"
                            }
                        }
                except Exception:
                    pass
                break
        return None
    except Exception:
        return None


def _find_node_in_stmt_list(stmts, target_id):
    for s in stmts:
        if id(s) == target_id:
            return s
        for attr in ('body', 'then_body', 'else_body', 'arms', 'elif_clauses'):
            children = getattr(s, attr, None)
            if children:
                if isinstance(children, list):
                    for child in children:
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
                'change': {'syncKind': 1},  # Full
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
            'diagnosticsProvider': True,
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
    result = get_hover(doc.source, pos['line'], pos['character'])
    conn.send_response(msg.id, result)


def handle_completion(msg: LSPMessage):
    conn.send_response(msg.id, {
        'isIncomplete': False,
        'items': _KEYWORD_COMPLETIONS,
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
    'textDocument/didOpen': handle_did_open,
    'textDocument/didChange': handle_did_change,
    'textDocument/hover': handle_hover,
    'textDocument/completion': handle_completion,
    'textDocument/semanticTokens/full': handle_semantic_tokens,
    'textDocument/formatting': handle_formatting,
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
            break
        if msg.method == 'exit':
            break
        handler = _HANDLERS.get(msg.method)
        if handler:
            try:
                handler(msg)
            except Exception as e:
                if msg.id:
                    conn.send_error(msg.id, -32603, str(e))
                traceback.print_exc()
        elif msg.id:
            conn.send_response(msg.id, None)


if __name__ == '__main__':
    main()
