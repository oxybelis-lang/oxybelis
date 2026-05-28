"""
Oxybelis code formatter.

Usage:  python ox_fmt.py <file.ox>          # format file in-place
        python ox_fmt.py <file.ox> --check  # check formatting, exit 1 if unformatted
        python oxybelis.py <file.ox> --fmt   # via transpiler
"""

from __future__ import annotations
import sys
from typing import Optional, List as PyList, Tuple, Any

from oxybelis import (Lexer, Parser, Program,
    FnDef, ClassDef, ImportStmt, VarDecl, Assignment,
    ReturnStmt, BreakStmt, ContinueStmt,
    IfStmt, ForStmt, WhileStmt, MatchStmt, ExprStmt,
    BinOp, UnaryOp, FnCall, MethodCall, Attr, Index,
    Ident, IntLit, FloatLit, StrLit, BoolLit,
    NoneLit, SomeLit, ListLit, StructLit, RangeLit, WildCard)


def _escape(s: str) -> str:
    """Reverse of lexer's string decoding."""
    escapes = {'\n': '\\n', '\t': '\\t', '\\': '\\\\', '"': '\\"', '\r': '\\r'}
    out = []
    for ch in s:
        out.append(escapes.get(ch, ch))
    return ''.join(out)


class Formatter:
    def __init__(self, indent_size: int = 4, max_line: int = 100,
                 use_semicolons: bool = True):
        self.indent_size = indent_size
        self.max_line = max_line
        self.use_semicolons = use_semicolons
        self._level = 0
        self._lines: PyList[str] = []
        self._cur = ''

    # ── lower-level helpers ─────────────────────────────────

    def _w(self, s: str = ''):
        self._cur += s

    def _ws(self):
        if self._cur:
            self._cur += ' '

    def _nl(self, text: str = ''):
        if self._cur:
            self._lines.append(self._indent() + self._cur)
        self._cur = ''
        if text:
            self._lines.append(self._indent() + text)

    def _indent(self) -> str:
        return ' ' * (self._level * self.indent_size)

    def _push(self):
        self._level += 1

    def _pop(self):
        self._level -= 1

    def _blank(self):
        if self._lines and self._lines[-1] != '':
            self._lines.append('')

    def _semi(self):
        if self.use_semicolons:
            self._w(';')

    def _flush_comments_before(self, node):
        sp = self._spans.get(id(node))
        if sp is None:
            return
        node_start = (sp.start_line, sp.start_col)
        while self._comment_idx < len(self._comments):
            text, line, col = self._comments[self._comment_idx]
            if (line, col) < node_start:
                if self._last_comment_line and line > self._last_comment_line + 1:
                    if not self._lines or self._lines[-1] != '':
                        self._lines.append('')
                self._nl()
                self._lines.append(self._indent() + text)
                self._last_comment_line = line
                self._comment_idx += 1
            else:
                break

    def _flush_remaining_comments(self):
        while self._comment_idx < len(self._comments):
            text, line, col = self._comments[self._comment_idx]
            if self._last_comment_line and line > self._last_comment_line + 1:
                if not self._lines or self._lines[-1] != '':
                    self._lines.append('')
            self._nl()
            self._lines.append(self._indent() + text)
            self._last_comment_line = line
            self._comment_idx += 1

    # ── top-level format entry ──────────────────────────────

    def format(self, prog: Program,
               comments: Optional[PyList[Tuple[str,int,int]]] = None,
               spans: Optional[dict] = None) -> str:
        self._level = 0
        self._lines = []
        self._cur = ''
        self._comments = sorted(comments or [], key=lambda c: (c[1], c[2]))
        self._comment_idx = 0
        self._spans = spans or {}
        self._last_comment_line = 0
        for i, stmt in enumerate(prog.stmts):
            if i > 0:
                self._blank()
            self._stmt(stmt)
        self._flush_remaining_comments()
        if self._cur:
            self._nl()
        return '\n'.join(self._lines) + '\n'

    # ── statements ──────────────────────────────────────────

    def _stmt(self, node):
        self._flush_comments_before(node)
        if isinstance(node, FnDef):       self._fn_def(node)
        elif isinstance(node, ClassDef):  self._class_def(node)
        elif isinstance(node, ImportStmt): self._import(node)
        elif isinstance(node, VarDecl):    self._var_decl(node)
        elif isinstance(node, Assignment): self._assign(node)
        elif isinstance(node, ReturnStmt): self._return(node)
        elif isinstance(node, BreakStmt):  self._break(node)
        elif isinstance(node, ContinueStmt): self._continue(node)
        elif isinstance(node, IfStmt):     self._if(node)
        elif isinstance(node, ForStmt):    self._for(node)
        elif isinstance(node, WhileStmt):  self._while(node)
        elif isinstance(node, MatchStmt):  self._match(node)
        elif isinstance(node, ExprStmt):   self._expr_stmt(node)
        else:                              self._expr(node)

    # ── top-level items ─────────────────────────────────────

    def _fn_def(self, node: FnDef):
        if node.is_pub:
            self._w('pub ')
        if node.is_lazy:
            self._w('lazy ')
        self._w('fn ')
        self._w(node.name)
        if node.generics:
            self._w('<' + ', '.join(node.generics) + '>')
        self._w('(')
        if node.has_self:
            self._w('self')
            if node.params:
                self._w(', ')
        for i, (pname, ptype) in enumerate(node.params):
            if i > 0:
                self._w(', ')
            self._w(pname)
            if ptype:
                self._w(': ')
                self._w(ptype)
        self._w(')')
        if node.return_type != 'void':
            self._w(' -> ')
            self._w(node.return_type)
        self._w(' {')
        self._nl()
        self._push()
        for s in node.body:
            self._stmt(s)
        self._pop()
        self._nl('}')

    def _class_def(self, node: ClassDef):
        self._w('class ')
        self._w(node.name)
        if node.generics:
            self._w('<' + ', '.join(node.generics) + '>')
        self._w(' {')
        self._nl()
        self._push()
        for fname, ftype in node.fields:
            self._w(fname)
            self._w(': ')
            self._w(ftype)
            self._semi()
            self._nl()
        for m in node.methods:
            self._blank()
            self._flush_comments_before(m)
            self._fn_def(m)
        self._pop()
        self._nl('}')

    def _import(self, node: ImportStmt):
        self._w('import ')
        self._w('.'.join(node.path))
        self._semi()
        self._nl()

    # ── variable / assignment ───────────────────────────────

    def _var_decl(self, node: VarDecl):
        self._w('var ' if node.mutable else 'let ')
        self._w(node.name)
        if node.type_ann:
            self._w(': ')
            self._w(node.type_ann)
        self._w(' = ')
        self._expr(node.value)
        self._semi()
        self._nl()

    def _assign(self, node: Assignment):
        self._expr(node.target)
        self._ws()
        self._w(node.op)
        self._ws()
        self._expr(node.value)
        self._semi()
        self._nl()

    def _return(self, node: ReturnStmt):
        self._w('return')
        if node.value is not None:
            self._ws()
            self._expr(node.value)
        self._semi()
        self._nl()

    def _break(self, _):
        self._w('break')
        self._semi()
        self._nl()

    def _continue(self, _):
        self._w('continue')
        self._semi()
        self._nl()

    # ── control flow ────────────────────────────────────────

    def _if(self, node: IfStmt):
        self._w('if ')
        self._expr(node.cond)
        self._ws()
        self._block(node.then_body)
        for cond, body in node.elif_clauses:
            self._ws()
            self._w('elif ')
            self._expr(cond)
            self._ws()
            self._block(body)
        if node.else_body:
            self._ws()
            self._w('else ')
            self._block(node.else_body)
        self._nl()

    def _for(self, node: ForStmt):
        self._w('for ')
        self._w(node.var)
        self._w(' in ')
        self._expr(node.iterable)
        self._ws()
        self._block(node.body)
        self._nl()

    def _while(self, node: WhileStmt):
        self._w('while ')
        self._expr(node.cond)
        self._ws()
        self._block(node.body)
        self._nl()

    def _match(self, node: MatchStmt):
        self._w('match ')
        self._expr(node.subject)
        self._w(' {')
        self._nl()
        self._push()
        for pat, body in node.arms:
            self._pattern(pat)
            self._w(' => ')
            if len(body) == 1:
                self._stmt(body[0])
            else:
                self._block(body)
                self._nl()
        self._pop()
        self._nl('}')

    # ── expression statements ───────────────────────────────

    def _expr_stmt(self, node: ExprStmt):
        self._expr(node.expr)
        self._semi()
        self._nl()

    # ── blocks ──────────────────────────────────────────────

    def _block(self, body: PyList[Any]):
        self._w('{')
        if not body:
            self._w(' }')
            return
        self._nl()
        self._push()
        for s in body:
            self._stmt(s)
        self._pop()
        self._nl('}')

    # ── patterns (match) ────────────────────────────────────

    def _pattern(self, node):
        if isinstance(node, IntLit):
            self._w(str(node.value))
        elif isinstance(node, FloatLit):
            self._w(str(node.value))
        elif isinstance(node, StrLit):
            self._w('"' + _escape(node.value) + '"')
        elif isinstance(node, BoolLit):
            self._w('true' if node.value else 'false')
        elif isinstance(node, RangeLit):
            self._expr(node.start)
            self._w('..')
            self._expr(node.end)
        elif isinstance(node, Ident):
            self._w(node.name)
        elif isinstance(node, NoneLit):
            self._w('None')
        elif isinstance(node, WildCard):
            self._w('_')
        else:
            self._expr(node)

    # ── expressions ─────────────────────────────────────────

    def _expr(self, node):
        if isinstance(node, IntLit):
            self._w(str(node.value))
        elif isinstance(node, FloatLit):
            self._w(str(node.value))
        elif isinstance(node, StrLit):
            self._w('"' + _escape(node.value) + '"')
        elif isinstance(node, BoolLit):
            self._w('true' if node.value else 'false')
        elif isinstance(node, NoneLit):
            self._w('None')
        elif isinstance(node, SomeLit):
            self._w('Some(')
            self._expr(node.value)
            self._w(')')
        elif isinstance(node, ListLit):
            self._w('[')
            for i, e in enumerate(node.elems):
                if i > 0:
                    self._w(', ')
                self._expr(e)
            self._w(']')
        elif isinstance(node, RangeLit):
            self._expr(node.start)
            self._w('..')
            self._expr(node.end)
        elif isinstance(node, WildCard):
            self._w('_')
        elif isinstance(node, Ident):
            self._w(node.name)
        elif isinstance(node, BinOp):
            self._expr(node.left)
            self._ws()
            self._w(node.op)
            self._ws()
            self._expr(node.right)
        elif isinstance(node, UnaryOp):
            self._w(node.op)
            self._expr(node.operand)
        elif isinstance(node, FnCall):
            self._expr(node.func)
            if node.type_args:
                self._w('<' + ', '.join(node.type_args) + '>')
            self._w('(')
            for i, arg in enumerate(node.args):
                if i > 0:
                    self._w(', ')
                self._expr(arg)
            self._w(')')
        elif isinstance(node, MethodCall):
            self._expr(node.obj)
            self._w('.')
            self._w(node.name)
            self._w('(')
            for i, arg in enumerate(node.args):
                if i > 0:
                    self._w(', ')
                self._expr(arg)
            self._w(')')
        elif isinstance(node, Attr):
            self._expr(node.obj)
            self._w('.')
            self._w(node.name)
        elif isinstance(node, Index):
            self._expr(node.obj)
            self._w('[')
            self._expr(node.idx)
            self._w(']')
        elif isinstance(node, StructLit):
            self._w(node.type_name)
            self._w(' {')
            if not node.fields:
                self._w(' }')
                return
            self._w(' ')
            for i, (fn, fv) in enumerate(node.fields):
                if i > 0:
                    self._w(', ')
                self._w(fn)
                self._w(': ')
                self._expr(fv)
            self._w(' }')
        else:
            self._w('<unknown>')


def format_source(source: str) -> str:
    lexer = Lexer(source)
    tokens = lexer.tokenize()
    comments = list(lexer.comments)
    parser = Parser(tokens, source)
    prog = parser.parse()
    spans = parser.get_spans()
    fmt = Formatter()
    return fmt.format(prog, comments, spans)


def cli():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')

    import argparse
    p = argparse.ArgumentParser(description='Oxybelis code formatter')
    p.add_argument('source', help='Source file (.ox)')
    p.add_argument('--check', action='store_true',
                   help='Check formatting without modifying (exit 1 if unformatted)')
    p.add_argument('--stdout', action='store_true',
                   help='Print formatted source to stdout instead of modifying file')
    args = p.parse_args()

    with open(args.source, encoding='utf-8') as f:
        src = f.read()

    formatted = format_source(src)
    trimmed_src = src.rstrip('\n')
    trimmed_fmt = formatted.rstrip('\n')

    if args.stdout:
        sys.stdout.write(formatted)
        return

    if args.check:
        if trimmed_src != trimmed_fmt:
            print(f"\033[31m✗ {args.source} – not formatted\033[0m")
            sys.exit(1)
        print(f"\033[32m✓ {args.source} – formatted\033[0m")
        return

    if trimmed_src == trimmed_fmt:
        print(f"\033[32m✓ {args.source} – already formatted\033[0m")
        return

    with open(args.source, 'w', encoding='utf-8') as f:
        f.write(formatted)
    print(f"\033[32m✓ {args.source} – formatted\033[0m")


if __name__ == '__main__':
    cli()
