#!/usr/bin/env python3
"""
Oxybelis – A statically-typed, Python-inspired language that transpiles to C++.
Usage:  python oxybelis.py <source.ox>            # → source.exe
        python oxybelis.py <source.ox> -o out.cpp # C++ only
        python oxybelis.py <source.ox> -S         # C++ to stdout
        python oxybelis.py <source.ox> --check    # type-check only
        python oxybelis.py <source.ox> --highlight # syntax-highlight & exit
"""

import sys
import os
from dataclasses import dataclass, field

__version__ = '0.5.0'
__version_info__ = (0, 4, 0)
from typing import Optional, List as PyList, Any, Tuple
from enum import Enum, auto
from ox_diag import (Span, Severity, Diagnostic, SourceFile,
                     render_diagnostics, highlight_ox)

# ═══════════════════════════════════════════════════════════════
#  TOKEN TYPES
# ═══════════════════════════════════════════════════════════════

class TT(Enum):
    INT_LIT=auto(); FLOAT_LIT=auto(); STR_LIT=auto()
    IDENT=auto()
    # Keywords
    FN=auto(); LET=auto(); VAR=auto(); CLASS=auto()
    IF=auto(); ELSE=auto(); ELIF=auto()
    FOR=auto(); IN=auto(); WHILE=auto()
    RETURN=auto(); MATCH=auto(); LAZY=auto()
    PUB=auto(); TRUE=auto(); FALSE=auto()
    KL_NONE=auto(); SOME=auto(); IMPORT=auto()
    AND=auto(); OR=auto(); NOT=auto()
    BREAK=auto(); CONTINUE=auto(); YIELD=auto()
    # Built-in types
    T_INT=auto(); T_FLOAT=auto(); T_BOOL=auto()
    T_STR=auto(); T_VOID=auto()
    # Operators
    PLUS=auto(); MINUS=auto(); STAR=auto(); SLASH=auto(); PERCENT=auto()
    EQ=auto(); NEQ=auto(); LT=auto(); GT=auto(); LEQ=auto(); GEQ=auto()
    ASSIGN=auto(); PLUS_ASSIGN=auto(); MINUS_ASSIGN=auto()
    STAR_ASSIGN=auto(); SLASH_ASSIGN=auto()
    DOTDOT=auto(); ARROW=auto(); FAT_ARROW=auto(); DOT=auto()
    BANG=auto(); QUESTION=auto(); PIPE=auto()
    # Delimiters
    LBRACE=auto(); RBRACE=auto(); LPAREN=auto(); RPAREN=auto()
    LBRACKET=auto(); RBRACKET=auto()
    COLON=auto(); COMMA=auto(); SEMI=auto()
    UNDERSCORE=auto(); EOF=auto()

KEYWORDS = {
    'fn': TT.FN, 'let': TT.LET, 'var': TT.VAR, 'class': TT.CLASS,
    'if': TT.IF, 'else': TT.ELSE, 'elif': TT.ELIF,
    'for': TT.FOR, 'in': TT.IN, 'while': TT.WHILE,
    'return': TT.RETURN, 'match': TT.MATCH, 'lazy': TT.LAZY,
    'pub': TT.PUB, 'true': TT.TRUE, 'false': TT.FALSE,
    'None': TT.KL_NONE, 'Some': TT.SOME, 'import': TT.IMPORT,
    'and': TT.AND, 'or': TT.OR, 'not': TT.NOT,
    'break': TT.BREAK, 'continue': TT.CONTINUE, 'yield': TT.YIELD,
    '_': TT.UNDERSCORE,
    'int': TT.T_INT, 'float': TT.T_FLOAT, 'bool': TT.T_BOOL,
    'str': TT.T_STR, 'void': TT.T_VOID,
}

@dataclass
class Token:
    type: TT
    value: str
    line: int = 0
    col: int = 0
    pos: int = 0
    length: int = 0
    def __repr__(self): return f"[{self.type.name} {self.value!r} {self.line}:{self.col}]"

# ═══════════════════════════════════════════════════════════════
#  LEXER
# ═══════════════════════════════════════════════════════════════

class LexError(Exception):
    def __init__(self, msg, line=0, col=0):
        self.line = line
        self.col = col
        super().__init__(msg)

class Lexer:
    def __init__(self, src: str):
        self.src = src
        self.pos = 0
        self.line = 1
        self.col = 1
        self.comments: PyList[Tuple[str,int,int]] = []  # (text, line, col)

    def peek(self, offset=0) -> str:
        i = self.pos + offset
        return self.src[i] if i < len(self.src) else '\0'

    def advance(self) -> str:
        ch = self.src[self.pos]; self.pos += 1
        if ch == '\n': self.line += 1; self.col = 1
        else: self.col += 1
        return ch

    def tok(self, tt: TT, val: str, line: int, col: int, length: int = 0) -> Token:
        return Token(tt, val, line, col, self.pos, length or len(val))

    def tok_eof(self) -> Token:
        return Token(TT.EOF, '', self.line, self.col, self.pos, 0)

    def skip_trivia(self):
        while self.pos < len(self.src):
            ch = self.peek()
            if ch in ' \t\r\n':
                self.advance()
            elif ch == '/' and self.peek(1) == '/':
                line, col = self.line, self.col
                start = self.pos
                while self.pos < len(self.src) and self.peek() != '\n':
                    self.advance()
                self.comments.append((self.src[start:self.pos], line, col))
            elif ch == '/' and self.peek(1) == '*':
                line, col = self.line, self.col
                start = self.pos
                self.advance(); self.advance()
                while self.pos < len(self.src):
                    if self.peek() == '*' and self.peek(1) == '/':
                        self.advance(); self.advance(); break
                    self.advance()
                self.comments.append((self.src[start:self.pos], line, col))
            else:
                break

    def tokenize(self) -> PyList[Token]:
        tokens: PyList[Token] = []
        while True:
            self.skip_trivia()
            if self.pos >= len(self.src):
                tokens.append(self.tok_eof()); break

            line, col = self.line, self.col
            ch = self.peek()

            # ── Numbers ───────────────────────────────────────
            if ch.isdigit():
                num = ''; is_f = False
                while self.pos < len(self.src) and (self.peek().isdigit() or self.peek() == '.'):
                    if self.peek() == '.':
                        if is_f or self.peek(1) == '.': break
                        is_f = True
                    num += self.advance()
                tokens.append(self.tok(TT.FLOAT_LIT if is_f else TT.INT_LIT, num, line, col))
                continue

            # ── Strings ───────────────────────────────────────
            if ch == '"':
                tok_pos = self.pos
                self.advance(); s = ''
                while self.pos < len(self.src) and self.peek() != '"':
                    c = self.advance()
                    if c == '\\':
                        esc = self.advance()
                        s += {'n':'\n','t':'\t','\\':'\\','"':'"','r':'\r'}.get(esc, esc)
                    else:
                        s += c
                if self.pos >= len(self.src):
                    raise LexError("Unterminated string", line, col)
                self.advance()
                tok_len = self.pos - tok_pos
                tokens.append(self.tok(TT.STR_LIT, s, line, col, tok_len)); continue

            # ── Identifiers & keywords ────────────────────────
            if ch.isalpha() or ch == '_':
                word = ''
                while self.pos < len(self.src) and (self.peek().isalnum() or self.peek() == '_'):
                    word += self.advance()
                tokens.append(self.tok(KEYWORDS.get(word, TT.IDENT), word, line, col)); continue

            # ── Operators & delimiters ────────────────────────
            self.advance(); nxt = self.peek()
            def op2(s, tt2, tt1):
                nonlocal nxt
                if nxt == s: self.advance(); tokens.append(self.tok(tt2, ch+s, line, col))
                else: tokens.append(self.tok(tt1, ch, line, col))

            if   ch == '-':
                if nxt == '>': self.advance(); tokens.append(self.tok(TT.ARROW,       '->', line, col))
                elif nxt=='=': self.advance(); tokens.append(self.tok(TT.MINUS_ASSIGN,'-=', line, col))
                else:                          tokens.append(self.tok(TT.MINUS,       '-',  line, col))
            elif ch == '=':
                if nxt == '=': self.advance(); tokens.append(self.tok(TT.EQ,          '==',line, col))
                elif nxt=='>': self.advance(); tokens.append(self.tok(TT.FAT_ARROW,   '=>', line, col))
                else:                          tokens.append(self.tok(TT.ASSIGN,      '=',  line, col))
            elif ch == '!': op2('=', TT.NEQ, TT.BANG)
            elif ch == '<':
                if nxt == '=': self.advance(); tokens.append(self.tok(TT.LEQ, '<=', line, col))
                else:                          tokens.append(self.tok(TT.LT,  '<',  line, col))
            elif ch == '>':
                if nxt == '=': self.advance(); tokens.append(self.tok(TT.GEQ, '>=', line, col))
                else:                          tokens.append(self.tok(TT.GT,  '>',  line, col))
            elif ch == '+':
                if nxt == '=': self.advance(); tokens.append(self.tok(TT.PLUS_ASSIGN, '+=', line, col))
                else:                          tokens.append(self.tok(TT.PLUS,        '+',  line, col))
            elif ch == '*':
                if nxt == '=': self.advance(); tokens.append(self.tok(TT.STAR_ASSIGN, '*=', line, col))
                else:                          tokens.append(self.tok(TT.STAR,        '*',  line, col))
            elif ch == '/':
                if nxt == '=': self.advance(); tokens.append(self.tok(TT.SLASH_ASSIGN,'/=', line, col))
                else:                          tokens.append(self.tok(TT.SLASH,       '/',  line, col))
            elif ch == '.':
                if nxt == '.': self.advance(); tokens.append(self.tok(TT.DOTDOT, '..', line, col))
                else:                          tokens.append(self.tok(TT.DOT,    '.',  line, col))
            elif ch == '%':  tokens.append(self.tok(TT.PERCENT,  '%', line, col))
            elif ch == '{':  tokens.append(self.tok(TT.LBRACE,   '{', line, col))
            elif ch == '}':  tokens.append(self.tok(TT.RBRACE,   '}', line, col))
            elif ch == '(':  tokens.append(self.tok(TT.LPAREN,   '(', line, col))
            elif ch == ')':  tokens.append(self.tok(TT.RPAREN,   ')', line, col))
            elif ch == '[':  tokens.append(self.tok(TT.LBRACKET, '[', line, col))
            elif ch == ']':  tokens.append(self.tok(TT.RBRACKET, ']', line, col))
            elif ch == ':':  tokens.append(self.tok(TT.COLON,    ':', line, col))
            elif ch == ',':  tokens.append(self.tok(TT.COMMA,    ',', line, col))
            elif ch == ';':  tokens.append(self.tok(TT.SEMI,     ';', line, col))
            elif ch == '?':  tokens.append(self.tok(TT.QUESTION,'?', line, col))
            elif ch == '|':  tokens.append(self.tok(TT.PIPE,    '|', line, col))
            else: raise LexError(f"Unknown character {ch!r}", line, col)

        return tokens

# ═══════════════════════════════════════════════════════════════
#  AST NODES
# ═══════════════════════════════════════════════════════════════

@dataclass
class Program:      stmts: PyList[Any]
@dataclass
class FnDef:
    name: str; params: PyList[Tuple[str,str]]; return_type: str; body: PyList[Any]
    is_pub: bool=False; is_lazy: bool=False
    generics: PyList[str]=field(default_factory=list); has_self: bool=False
@dataclass
class ClassDef:
    name: str; fields: PyList[Tuple[str,str]]; methods: PyList[Any]
    generics: PyList[str]=field(default_factory=list)
@dataclass
class ImportStmt:   path: PyList[str]
@dataclass
class VarDecl:      name: str; type_ann: Optional[str]; value: Any; mutable: bool
@dataclass
class Assignment:   target: Any; value: Any; op: str='='
@dataclass
class ReturnStmt:   value: Optional[Any]
@dataclass
class BreakStmt:    pass
@dataclass
class ContinueStmt: pass
@dataclass
class YieldStmt:    value: Any
@dataclass
class IfStmt:
    cond: Any; then_body: PyList[Any]
    elif_clauses: PyList[Tuple[Any,PyList[Any]]]; else_body: Optional[PyList[Any]]
@dataclass
class ForStmt:
    var: str; iterable: Any; body: PyList[Any]
    vars: PyList[str] = field(default_factory=list)
@dataclass
class WhileStmt:    cond: Any; body: PyList[Any]
@dataclass
class MatchStmt:    subject: Any; arms: PyList[Tuple[Any,PyList[Any]]]
@dataclass
class ExprStmt:     expr: Any
# Expressions
@dataclass
class BinOp:        op: str; left: Any; right: Any
@dataclass
class UnaryOp:      op: str; operand: Any
@dataclass
class FnCall:       func: Any; args: PyList[Any]; type_args: PyList[str]=field(default_factory=list)
@dataclass
class MethodCall:   obj: Any; name: str; args: PyList[Any]
@dataclass
class Attr:         obj: Any; name: str
@dataclass
class Index:        obj: Any; idx: Any
@dataclass
class Ident:        name: str
@dataclass
class IntLit:       value: int
@dataclass
class FloatLit:     value: float
@dataclass
class StrLit:       value: str
@dataclass
class BoolLit:      value: bool
@dataclass
class NoneLit:      pass
@dataclass
class SomeLit:      value: Any
@dataclass
class ListLit:      elems: PyList[Any]
@dataclass
class TupleLit:     elems: PyList[Any]
@dataclass
class LambdaExpr:   params: PyList[str]; body: Any
@dataclass
class TernaryExpr:  then_expr: Any; cond: Any; else_expr: Any
@dataclass
class StructLit:    type_name: str; fields: PyList[Tuple[str,Any]]
@dataclass
class RangeLit:     start: Any; end: Any
@dataclass
class SliceLit:
    start: Optional[Any] = None
    end: Optional[Any] = None
    step: Optional[Any] = None
@dataclass
class WildCard:     pass
@dataclass
class TryOp:        value: Any

# ═══════════════════════════════════════════════════════════════
#  PARSER
# ═══════════════════════════════════════════════════════════════

class ParseError(Exception):
    def __init__(self, msg, line=0, col=0):
        self.line = line
        self.col = col
        super().__init__(msg)

class Parser:
    def __init__(self, tokens: PyList[Token], source: str = ''):
        self.tokens = tokens; self.pos = 0
        self._source = source
        self._spans: dict = {}  # id(node) -> Span

    def _tok_span(self, t) -> Span:
        if isinstance(t, Token):
            start = t.pos - t.length if t.length > 0 else t.pos
            end = t.pos
            return Span(start, end, t.line, t.col, t.line, t.col + max(t.length, 1))
        return t  # already a Span

    def _set_span(self, node, t):
        self._spans[id(node)] = self._tok_span(t)

    def _set_span_range(self, node, start, end):
        s = self._tok_span(start)
        e = self._tok_span(end)
        self._spans[id(node)] = Span(s.start, e.end, s.start_line, s.start_col, e.end_line, e.end_col)

    def _span_of(self, node) -> Optional[Span]:
        return self._spans.get(id(node))

    def get_spans(self) -> dict:
        return self._spans

    def peek(self, offset=0) -> Token:
        i = self.pos + offset
        return self.tokens[i] if i < len(self.tokens) else self.tokens[-1]

    def check(self, *tts: TT) -> bool:
        return self.peek().type in tts

    def advance(self) -> Token:
        t = self.tokens[self.pos]
        if self.pos < len(self.tokens)-1: self.pos += 1
        return t

    def expect(self, *tts: TT) -> Token:
        t = self.peek()
        if t.type not in tts:
            exp = ', '.join(tt.name for tt in tts)
            raise ParseError(f"Expected {exp}, got {t.type.name} ({t.value!r})", t.line, t.col)
        return self.advance()

    def match_tok(self, *tts: TT) -> Optional[Token]:
        return self.advance() if self.check(*tts) else None

    def skip_semis(self):
        while self.match_tok(TT.SEMI): pass

    # ── Top level ──────────────────────────────────────────────

    def parse(self) -> Program:
        stmts: PyList[Any] = []
        while not self.check(TT.EOF):
            self.skip_semis()
            if self.check(TT.EOF): break
            stmts.append(self.parse_top())
            self.skip_semis()
        return Program(stmts)

    def parse_top(self):
        is_pub  = bool(self.match_tok(TT.PUB))
        is_lazy = bool(self.match_tok(TT.LAZY))
        if self.check(TT.FN):     return self.parse_fn(is_pub, is_lazy)
        if self.check(TT.CLASS):  return self.parse_class()
        if self.check(TT.IMPORT): return self.parse_import()
        if self.check(TT.LET, TT.VAR): return self.parse_var_decl()
        t = self.peek()
        raise ParseError(f"Unexpected token {t.type.name} ({t.value!r}) at top level", t.line, t.col)

    def parse_import(self) -> ImportStmt:
        self.expect(TT.IMPORT)
        path = [self.expect(TT.IDENT).value]
        while self.match_tok(TT.DOT):
            path.append(self.expect(TT.IDENT).value)
        return ImportStmt(path)

    def parse_generics(self) -> PyList[str]:
        gs: PyList[str] = []
        if self.match_tok(TT.LT):
            while not self.check(TT.GT):
                gs.append(self.expect(TT.IDENT).value)
                if not self.match_tok(TT.COMMA): break
            self.expect(TT.GT)
        return gs

    def parse_fn(self, is_pub=False, is_lazy=False) -> FnDef:
        fn_tok = self.peek()
        self.expect(TT.FN)
        name_tok = self.peek()
        name = self.expect(TT.IDENT).value
        generics = self.parse_generics()
        self.expect(TT.LPAREN)
        params: PyList[Tuple[str,str]] = []
        has_self = False

        if not self.check(TT.RPAREN):
            # self parameter
            if self.peek().value == 'self' and self.peek().type == TT.IDENT:
                has_self = True; self.advance()
                self.match_tok(TT.COMMA)
            while not self.check(TT.RPAREN, TT.EOF):
                pname_tok = self.peek()
                pname = self.expect(TT.IDENT).value
                pname_node = Ident(pname)
                self._set_span(pname_node, pname_tok)
                self.expect(TT.COLON)
                ptype = self.parse_type()
                default = None
                if self.match_tok(TT.ASSIGN):
                    default = self.parse_expr()
                params.append((pname, ptype, default, pname_node))
                if not self.match_tok(TT.COMMA): break

        self.expect(TT.RPAREN)
        ret = 'void'
        if self.match_tok(TT.ARROW): ret = self.parse_type()
        body = self.parse_block()
        n = FnDef(name, params, ret, body, is_pub, is_lazy, generics, has_self)
        self._set_span_range(n, fn_tok, self.peek())
        return n

    def parse_class(self) -> ClassDef:
        st = self.peek()
        self.expect(TT.CLASS)
        name = self.expect(TT.IDENT).value
        generics = self.parse_generics()
        self.expect(TT.LBRACE)
        fields: PyList[Tuple[str,str]] = []
        methods: PyList[FnDef] = []
        while not self.check(TT.RBRACE, TT.EOF):
            self.skip_semis()
            if self.check(TT.RBRACE): break
            is_pub  = bool(self.match_tok(TT.PUB))
            is_lazy = bool(self.match_tok(TT.LAZY))
            if self.check(TT.FN):
                methods.append(self.parse_fn(is_pub, is_lazy))
            else:
                fname = self.expect(TT.IDENT).value
                self.expect(TT.COLON)
                ftype = self.parse_type()
                fields.append((fname, ftype))
                self.skip_semis()
        self.expect(TT.RBRACE)
        n = ClassDef(name, fields, methods, generics)
        self._set_span_range(n, st, self.peek())
        return n

    def parse_type(self) -> str:
        type_kws = {TT.T_INT:'int', TT.T_FLOAT:'float', TT.T_BOOL:'bool',
                    TT.T_STR:'str', TT.T_VOID:'void'}
        t = self.peek()
        if t.type in type_kws:
            self.advance(); return type_kws[t.type]
        if t.type == TT.LPAREN:
            self.advance()
            types = []
            while not self.check(TT.RPAREN):
                types.append(self.parse_type())
                if not self.match_tok(TT.COMMA): break
            self.expect(TT.RPAREN)
            return f"({', '.join(types)})"
        if t.type == TT.IDENT:
            name = self.advance().value
            type_aliases = {'list':'List', 'option':'Option', 'result':'Result', 'map':'Map'}
            name = type_aliases.get(name, name)
            if self.match_tok(TT.LT):
                args = []
                while not self.check(TT.GT):
                    args.append(self.parse_type())
                    if not self.match_tok(TT.COMMA): break
                self.expect(TT.GT)
                return f"{name}<{', '.join(args)}>"
            return name
        raise ParseError(f"Expected type, got {t.value!r}", t.line, t.col)

    def parse_block(self) -> PyList[Any]:
        self.expect(TT.LBRACE)
        stmts: PyList[Any] = []
        while not self.check(TT.RBRACE, TT.EOF):
            self.skip_semis()
            if self.check(TT.RBRACE): break
            stmts.append(self.parse_stmt())
            self.skip_semis()
        self.expect(TT.RBRACE)
        return stmts

    # ── Statements ─────────────────────────────────────────────

    def parse_stmt(self):
        if self.check(TT.LET, TT.VAR):   return self.parse_var_decl()
        if self.check(TT.RETURN):         return self.parse_return()
        if self.check(TT.IF):             return self.parse_if()
        if self.check(TT.FOR):            return self.parse_for()
        if self.check(TT.WHILE):          return self.parse_while()
        if self.check(TT.MATCH):          return self.parse_match()
        if self.check(TT.FN):             return self.parse_fn()
        if self.check(TT.BREAK):
            t = self.peek(); self.advance(); n = BreakStmt(); self._set_span(n, t); return n
        if self.check(TT.CONTINUE):
            t = self.peek(); self.advance(); n = ContinueStmt(); self._set_span(n, t); return n
        if self.check(TT.YIELD):
            t = self.peek(); self.advance()
            value = self.parse_expr()
            n = YieldStmt(value)
            self._set_span_range(n, t, self.peek())
            return n
        expr = self.parse_expr()
        if self.check(TT.ASSIGN, TT.PLUS_ASSIGN, TT.MINUS_ASSIGN,
                      TT.STAR_ASSIGN, TT.SLASH_ASSIGN):
            op_t = self.peek()
            op = self.advance().value
            rhs = self.parse_expr()
            n = Assignment(expr, rhs, op)
            self._set_span_range(n, self._spans.get(id(expr), op_t), self.peek())
            return n
        n = ExprStmt(expr)
        sp = self._spans.get(id(expr))
        if sp: self._spans[id(n)] = sp
        return n

    def parse_var_decl(self) -> VarDecl:
        st = self.peek()
        mutable = self.advance().type == TT.VAR
        name_tok = self.peek()
        if self.check(TT.LPAREN):
            # Tuple destructuring: let (a, b, c) = expr
            self.advance()
            var_names = []
            while not self.check(TT.RPAREN, TT.EOF):
                var_names.append(self.expect(TT.IDENT).value)
                if not self.match_tok(TT.COMMA): break
            self.expect(TT.RPAREN)
            name = ','.join(var_names)
            type_ann = None
            if self.match_tok(TT.COLON): type_ann = self.parse_type()
            self.expect(TT.ASSIGN)
            value = self.parse_expr()
            n = VarDecl(name, type_ann, value, mutable)
            n._destructure_vars = var_names
            self._set_span_range(n, st, self.peek())
            return n
        name = self.expect(TT.IDENT).value
        name_node = Ident(name)
        self._set_span(name_node, name_tok)
        type_ann = None
        if self.match_tok(TT.COLON): type_ann = self.parse_type()
        self.expect(TT.ASSIGN)
        value = self.parse_expr()
        n = VarDecl(name, type_ann, value, mutable)
        n.name_node = name_node
        self._set_span_range(n, st, self.peek())
        return n

    def parse_return(self) -> ReturnStmt:
        st = self.peek()
        self.expect(TT.RETURN)
        if self.check(TT.RBRACE, TT.SEMI, TT.EOF):
            n = ReturnStmt(None); self._set_span(n, st); return n
        val = self.parse_expr()
        n = ReturnStmt(val); self._set_span_range(n, st, self.peek()); return n

    def parse_if(self) -> IfStmt:
        st = self.peek()
        self.expect(TT.IF)
        cond = self.parse_expr()
        then = self.parse_block()
        elifs: PyList[Tuple[Any,PyList[Any]]] = []
        else_b: Optional[PyList[Any]] = None
        while self.check(TT.ELIF):
            self.advance()
            ec = self.parse_expr()
            eb = self.parse_block()
            elifs.append((ec, eb))
        if self.match_tok(TT.ELSE): else_b = self.parse_block()
        n = IfStmt(cond, then, elifs, else_b)
        self._set_span_range(n, st, self.peek())
        return n

    def parse_for(self) -> ForStmt:
        st = self.peek()
        self.expect(TT.FOR)
        if self.check(TT.LPAREN):
            self.advance()
            vars = []
            while not self.check(TT.RPAREN, TT.EOF):
                vars.append(self.expect(TT.IDENT).value)
                if not self.match_tok(TT.COMMA): break
            self.expect(TT.RPAREN)
            var = ','.join(vars)
        else:
            var = self.expect(TT.IDENT).value
            vars = [var]
        self.expect(TT.IN)
        iterable = self.parse_expr()
        body = self.parse_block()
        n = ForStmt(var, iterable, body, vars=vars)
        self._set_span_range(n, st, self.peek())
        return n

    def parse_while(self) -> WhileStmt:
        st = self.peek()
        self.expect(TT.WHILE)
        cond = self.parse_expr()
        body = self.parse_block()
        n = WhileStmt(cond, body)
        self._set_span_range(n, st, self.peek())
        return n

    def parse_match(self) -> MatchStmt:
        st = self.peek()
        self.expect(TT.MATCH)
        subject = self.parse_expr()
        self.expect(TT.LBRACE)
        arms: PyList[Tuple[Any,PyList[Any]]] = []
        while not self.check(TT.RBRACE, TT.EOF):
            self.skip_semis()
            if self.check(TT.RBRACE): break
            pat = self.parse_pattern()
            self.expect(TT.FAT_ARROW)
            body = self.parse_block() if self.check(TT.LBRACE) else [self.parse_stmt()]
            arms.append((pat, body))
            self.skip_semis()
        self.expect(TT.RBRACE)
        n = MatchStmt(subject, arms)
        self._set_span_range(n, st, self.peek())
        return n

    def parse_pattern(self):
        if self.check(TT.UNDERSCORE): self.advance(); return WildCard()
        expr = self.parse_primary()
        if self.match_tok(TT.DOTDOT):
            end = self.parse_primary()
            return RangeLit(expr, end)
        return expr

    # ── Expressions ────────────────────────────────────────────

    def parse_if_expr(self):
        expr = self.parse_or()
        if self.check(TT.IF):
            saved = self.pos
            self.advance()  # consume 'if'
            cond = self.parse_or()
            if self.check(TT.ELSE):
                self.advance()
                else_expr = self.parse_if_expr()
                n = TernaryExpr(expr, cond, else_expr)
                self._set_span_range(n, getattr(expr, '_span_start', None) or self.peek(), self.peek())
                return n
            self.pos = saved  # backtrack — not a ternary
        return expr

    def parse_expr(self):
        expr = self.parse_if_expr()
        # Range: a..b  (lower precedence than everything else)
        if self.match_tok(TT.DOTDOT):
            end = self.parse_if_expr()
            return RangeLit(expr, end)
        return expr

    def _binop(self, left_gen, ops):
        left = left_gen()
        while self.check(*ops):
            op_tok = self.peek()
            op = self.advance().value
            right = left_gen()
            n = BinOp(op, left, right)
            self._set_span_range(n, self._spans.get(id(left), op_tok), self._spans.get(id(right), op_tok))
            left = n
        return left

    def parse_or(self):
        return self._binop(self.parse_and, [TT.OR])

    def parse_and(self):
        return self._binop(self.parse_compare, [TT.AND])

    def parse_compare(self):
        return self._binop(self.parse_add, [TT.EQ, TT.NEQ, TT.LT, TT.GT, TT.LEQ, TT.GEQ, TT.IN])

    def parse_add(self):
        return self._binop(self.parse_mul, [TT.PLUS, TT.MINUS])

    def parse_mul(self):
        return self._binop(self.parse_unary, [TT.STAR, TT.SLASH, TT.PERCENT])

    def parse_unary(self):
        if self.check(TT.MINUS, TT.NOT, TT.BANG):
            op_t = self.peek()
            op = self.advance().value
            operand = self.parse_unary()
            n = UnaryOp(op, operand)
            self._set_span_range(n, op_t, self._spans.get(id(operand), op_t))
            return n
        return self.parse_postfix()

    def parse_postfix(self):
        expr = self.parse_primary()
        while True:
            if self.check(TT.DOT):
                dt = self.peek()
                self.advance()
                name_tok = self.peek()
                if self.check(TT.INT_LIT):
                    name = self.advance().value
                    n = Attr(expr, name)
                    self._set_span_range(n, dt, name_tok)
                    expr = n
                    continue
                name = self.expect(TT.IDENT).value
                # Generic type args on method call: obj.method<Type>(args)
                if self.check(TT.LT):
                    saved = self.pos; self.advance()
                    next_t = self.peek()
                    type_kw_set = {TT.T_INT, TT.T_FLOAT, TT.T_BOOL, TT.T_STR, TT.T_VOID}
                    if (next_t.type == TT.IDENT and next_t.value and next_t.value[0].isupper()) or next_t.type in type_kw_set:
                        args: PyList[str] = []
                        while not self.check(TT.GT):
                            args.append(self.parse_type())
                            if not self.match_tok(TT.COMMA): break
                        self.expect(TT.GT)
                        name = f"{name}<{', '.join(args)}>"
                    else:
                        self.pos = saved
                if self.check(TT.LPAREN):
                    lp = self.peek()
                    self.advance()
                    args: PyList[Any] = []
                    while not self.check(TT.RPAREN, TT.EOF):
                        args.append(self.parse_expr())
                        if not self.match_tok(TT.COMMA): break
                    rp = self.peek()
                    self.expect(TT.RPAREN)
                    n = MethodCall(expr, name, args)
                    self._set_span_range(n, dt, rp)
                    expr = n
                else:
                    n = Attr(expr, name)
                    self._set_span_range(n, dt, name_tok)
                    expr = n
            elif self.check(TT.LPAREN):
                lp = self.peek()
                self.advance()
                args = []
                while not self.check(TT.RPAREN, TT.EOF):
                    args.append(self.parse_expr())
                    if not self.match_tok(TT.COMMA): break
                rp = self.peek()
                self.expect(TT.RPAREN)
                n = FnCall(expr, args)
                self._set_span_range(n, lp, rp)
                expr = n
            elif self.check(TT.LBRACKET):
                lb = self.peek()
                self.advance()
                if self.check(TT.COLON):
                    # slice without start: [:end:step]
                    self.advance()
                    end = self.parse_expr() if not self.check(TT.COLON, TT.RBRACKET) else None
                    step = None
                    if self.match_tok(TT.COLON):
                        step = self.parse_expr() if not self.check(TT.RBRACKET) else None
                    rb = self.peek()
                    self.expect(TT.RBRACKET)
                    n = Index(expr, SliceLit(None, end, step))
                    self._set_span_range(n, lb, rb)
                    expr = n
                else:
                    idx = self.parse_expr()
                    if self.match_tok(TT.COLON):
                        # slice with start: [start:end:step]
                        end = self.parse_expr() if not self.check(TT.COLON, TT.RBRACKET) else None
                        step = None
                        if self.match_tok(TT.COLON):
                            step = self.parse_expr() if not self.check(TT.RBRACKET) else None
                        rb = self.peek()
                        self.expect(TT.RBRACKET)
                        n = Index(expr, SliceLit(idx, end, step))
                        self._set_span_range(n, lb, rb)
                        expr = n
                    else:
                        rb = self.peek()
                        self.expect(TT.RBRACKET)
                        n = Index(expr, idx)
                        self._set_span_range(n, lb, rb)
                        expr = n
            elif self.check(TT.QUESTION):
                q = self.peek(); self.advance()
                n = TryOp(expr)
                self._set_span_range(n, q, q)
                expr = n
            else:
                break
        return expr

    def parse_primary(self):
        t = self.peek()
        if t.type == TT.INT_LIT:   n = IntLit(int(t.value)); self.advance(); self._set_span(n, t); return n
        if t.type == TT.FLOAT_LIT: n = FloatLit(float(t.value)); self.advance(); self._set_span(n, t); return n
        if t.type == TT.STR_LIT:   n = StrLit(t.value); self.advance(); self._set_span(n, t); return n
        if t.type == TT.TRUE:      n = BoolLit(True); self.advance(); self._set_span(n, t); return n
        if t.type == TT.FALSE:     n = BoolLit(False); self.advance(); self._set_span(n, t); return n
        if t.type == TT.KL_NONE:   n = NoneLit(); self.advance(); self._set_span(n, t); return n
        if t.type == TT.SOME:
            st = t
            self.advance(); self.expect(TT.LPAREN)
            v = self.parse_expr(); et = self.peek(); self.expect(TT.RPAREN)
            n = SomeLit(v); self._set_span_range(n, st, et); return n
        if t.type == TT.UNDERSCORE: n = WildCard(); self.advance(); self._set_span(n, t); return n
        if t.type == TT.LBRACKET:
            st = t; self.advance(); elems: PyList[Any] = []
            while not self.check(TT.RBRACKET, TT.EOF):
                elems.append(self.parse_expr())
                if not self.match_tok(TT.COMMA): break
            et = self.peek(); self.expect(TT.RBRACKET)
            n = ListLit(elems); self._set_span_range(n, st, et); return n
        if t.type == TT.LPAREN:
            st = t; self.advance()
            if self.check(TT.RPAREN):
                et = self.peek(); self.expect(TT.RPAREN)
                n = TupleLit([]); self._set_span_range(n, st, et); return n
            expr = self.parse_expr()
            if self.match_tok(TT.COMMA):
                elems = [expr]
                while not self.check(TT.RPAREN, TT.EOF):
                    elems.append(self.parse_expr())
                    if not self.match_tok(TT.COMMA): break
                et = self.peek(); self.expect(TT.RPAREN)
                n = TupleLit(elems); self._set_span_range(n, st, et); return n
            et = self.peek(); self.expect(TT.RPAREN)
            self._set_span(expr, st)
            return expr
        if t.type == TT.PIPE:
            st = t; self.advance()
            params = []
            while not self.check(TT.PIPE, TT.EOF):
                params.append(self.expect(TT.IDENT).value)
                if not self.match_tok(TT.COMMA): break
            self.expect(TT.PIPE)
            body = self.parse_expr()
            n = LambdaExpr(params, body)
            self._set_span_range(n, st, self.peek())
            return n

        # Identifier or struct literal
        if t.type == TT.IDENT:
            name = self.advance().value
            # Generic type: Ident < Type, ... >  (heuristic: next token starts uppercase)
            if self.check(TT.LT):
                saved = self.pos
                self.advance()
                next_t = self.peek()
                type_kw_set = {TT.T_INT, TT.T_FLOAT, TT.T_BOOL, TT.T_STR, TT.T_VOID}
                if (next_t.type == TT.IDENT and next_t.value and next_t.value[0].isupper()) or next_t.type in type_kw_set:
                    args: PyList[str] = []
                    while not self.check(TT.GT):
                        args.append(self.parse_type())
                        if not self.match_tok(TT.COMMA): break
                    self.expect(TT.GT)
                    type_name = f"{name}<{', '.join(args)}>"
                    # Generic struct literal: TypeName<T> { field: val, ... }
                    if self.check(TT.LBRACE):
                        saved2 = self.pos; self.advance()
                        if self.check(TT.IDENT) and self.peek(1).type == TT.COLON:
                            flds: PyList[Tuple[str,Any]] = []
                            while not self.check(TT.RBRACE, TT.EOF):
                                fn_ = self.expect(TT.IDENT).value
                                self.expect(TT.COLON)
                                fv = self.parse_expr()
                                flds.append((fn_, fv))
                                if not self.match_tok(TT.COMMA): break
                            et = self.peek(); self.expect(TT.RBRACE)
                            n = StructLit(type_name, flds); self._set_span_range(n, t, et); return n
                        else:
                            self.pos = saved2
                    n = Ident(type_name); self._set_span(n, t); return n
                else:
                    self.pos = saved  # backtrack, treat as comparison
            # Struct literal: TypeName { field: val, ... }
            if self.check(TT.LBRACE):
                saved = self.pos; self.advance()
                if self.check(TT.IDENT) and self.peek(1).type == TT.COLON:
                    flds: PyList[Tuple[str,Any]] = []
                    while not self.check(TT.RBRACE, TT.EOF):
                        fn_ = self.expect(TT.IDENT).value
                        self.expect(TT.COLON)
                        fv = self.parse_expr()
                        flds.append((fn_, fv))
                        if not self.match_tok(TT.COMMA): break
                    et = self.peek(); self.expect(TT.RBRACE)
                    n = StructLit(name, flds); self._set_span_range(n, t, et); return n
                else:
                    self.pos = saved  # backtrack
            n = Ident(name); self._set_span(n, t); return n

        # Allow type keywords as identifiers in some contexts
        type_kws = {TT.T_INT, TT.T_FLOAT, TT.T_BOOL, TT.T_STR, TT.T_VOID}
        if t.type in type_kws:
            n = Ident(t.value); self.advance(); self._set_span(n, t); return n

        raise ParseError(f"Unexpected token {t.type.name} ({t.value!r}) in expression", t.line, t.col)

# ═══════════════════════════════════════════════════════════════
#  C++ RUNTIME HEADER
# ═══════════════════════════════════════════════════════════════

RUNTIME = r"""// ── Generated by Oxybelis ───────────────────────────────────────────────────
#include <iostream>
#include <string>
#include <vector>
#include <optional>
#include <unordered_map>
#include <functional>
#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <sstream>
#include <iomanip>
#include <fstream>
#include <cstdlib>
#include <cctype>
#include <filesystem>
#include <type_traits>
#include <NumCpp/Core.hpp>
#include <NumCpp/NdArray.hpp>
#include <NumCpp/Functions/sin.hpp>
#include <NumCpp/Functions/cos.hpp>
#include <NumCpp/Functions/tan.hpp>
#include <NumCpp/Functions/sqrt.hpp>
#include <NumCpp/Functions/abs.hpp>
#include <NumCpp/Functions/exp.hpp>
#include <NumCpp/Functions/log.hpp>
#include <NumCpp/Functions/floor.hpp>
#include <NumCpp/Functions/ceil.hpp>
#include <NumCpp/Functions/zeros.hpp>
#include <NumCpp/Functions/ones.hpp>
#include <NumCpp/Functions/linspace.hpp>
#include <NumCpp/Functions/arange.hpp>
#include <NumCpp/Functions/dot.hpp>
#include <NumCpp/Functions/matmul.hpp>
#include <NumCpp/Functions/norm.hpp>
#include <NumCpp/Functions/sum.hpp>
#include <NumCpp/Functions/mean.hpp>
#include <NumCpp/Functions/min.hpp>
#include <NumCpp/Functions/max.hpp>
#include <NumCpp/Linalg.hpp>
#ifdef _WIN32
#include <windows.h>
#endif

// ── Oxybelis stdlib types ────────────────────────────────────────────────────
template<typename T>          using List   = std::vector<T>;
template<typename K,typename V> using Map  = std::unordered_map<K,V>;
template<typename T>          using Option = std::optional<T>;

template<typename T, typename = std::enable_if_t<!std::is_array_v<T>>>
Option<T> Some(T val) { return std::optional<T>(val); }
inline Option<std::string> Some(const char* val) { return std::optional<std::string>(val); }
inline constexpr std::nullopt_t None = std::nullopt;

// ── Result<T,E> ────────────────────────────────────────────────────────────
template<typename T, typename E>
struct Result {
    T value;
    E error;
    bool is_ok = false;
};

template<typename T>
struct _ox_OkHelper {
    T value;
    _ox_OkHelper(const T& v) : value(v) {}
    template<typename E> operator Result<T, E>() const {
        Result<T, E> r; r.is_ok = true; r.value = value; return r;
    }
};
template<typename T, typename = std::enable_if_t<!std::is_array_v<T>>>
_ox_OkHelper<T> Ok(const T& v) { return _ox_OkHelper<T>(v); }
inline _ox_OkHelper<std::string> Ok(const char* v) { return _ox_OkHelper<std::string>(v); }

template<typename E>
struct _ox_ErrHelper {
    E error;
    _ox_ErrHelper(const E& e) : error(e) {}
    template<typename T> operator Result<T, E>() const {
        Result<T, E> r; r.is_ok = false; r.error = error; return r;
    }
};
template<typename E, typename = std::enable_if_t<!std::is_array_v<E>>>
_ox_ErrHelper<E> Err(const E& e) { return _ox_ErrHelper<E>(e); }
inline _ox_ErrHelper<std::string> Err(const char* e) { return _ox_ErrHelper<std::string>(e); }

template<typename T, typename E>
T _ox_try(const Result<T, E>& r) {
    if (!r.is_ok) { std::cerr << "\nError: " << r.error << "\n"; std::abort(); }
    return r.value;
}
template<typename T>
    T _ox_try(const std::optional<T>& o) {
        if (!o) { std::cerr << "\nError: unwrapped None\n"; std::abort(); }
        return *o;
    }

    // ── _ox_value ────────────────────────────────────────────────────────────────
    template<typename T>
    auto& _ox_value(std::optional<T>& o) { return *o; }
    template<typename T>
    auto _ox_value(const std::optional<T>& o) { return *o; }
    template<typename T>
    auto& _ox_value(T& o) { return o.value; }

// ── Generator<T> ────────────────────────────────────────────────────────────
template<typename T>
class Generator {
public:
    std::function<Option<T>()> _next_fn;

    Generator() = default;
    template<typename F> Generator(F fn) : _next_fn(std::move(fn)) {}

    bool next() { auto r = _next_fn(); if (r) { _current = r; return true; } return false; }
    T value() { return *_current; }

    class Iterator {
    public:
        Generator* _gen;
        bool _done;
        Iterator(Generator* gen, bool done) : _gen(gen), _done(done) {
            if (!_done && _gen->_next_fn) { _done = !_gen->next(); }
        }
        T operator*() { return _gen->value(); }
        bool operator!=(const Iterator& o) { return _done != o._done; }
        Iterator& operator++() { _done = !_gen->next(); return *this; }
    };

    Iterator begin() { return Iterator(this, false); }
    Iterator end() { return Iterator(this, true); }

private:
    Option<T> _current;
};

    // ── make_list (initializer_list helper) ──────────────────────────────────────
template<typename T>
List<T> _ox_make_list(std::initializer_list<T> il) {
    return List<T>(il);
}

inline List<std::string> _ox_make_list(std::initializer_list<const char*> il) {
    List<std::string> r;
    for (auto* s : il) r.push_back(std::string(s));
    return r;
}

// ── str (declared before print) ─────────────────────────────────────────────
inline std::string str(const std::string& v){ return v; }
inline std::string str(const char* v)     { return std::string(v); }
inline std::string str(int v)        { return std::to_string(v); }
inline std::string str(long v)       { return std::to_string(v); }
inline std::string str(unsigned long v) { return std::to_string(v); }
inline std::string str(long long v)  { return std::to_string(v); }
inline std::string str(unsigned long long v) { return std::to_string(v); }
inline std::string str(double v)     { return std::to_string(v); }
inline std::string str(bool v)       { return v?"true":"false"; }
template<typename T>
std::string str(const std::optional<T>& v) {
    if(v) return "Some("+str(*v)+")"; else return "None";
}
template<typename T, typename E>
std::string str(const Result<T,E>& r) {
    if(r.is_ok) return "Ok("+str(r.value)+")"; else return "Err("+str(r.error)+")";
}
template<typename T>
std::string str(const std::vector<T>& v) {
    std::string r = "[";
    for (size_t i=0;i<v.size();i++){if(i)r+=", ";r+=str(v[i]);}
    return r+"]";
}
template<typename T>
std::string str(const Generator<T>& g) {
    (void)g; return "<generator>";
}

// ── print (variadic) ─────────────────────────────────────────────────────────
template<typename T>
void _ox_print_one(const T& v) { std::cout << v; }
inline void _ox_print_one(bool v) { std::cout << (v ? "true" : "false"); }
inline void _ox_print_one(const std::string& v) { std::cout << v; }
template<typename T>
void _ox_print_one(const std::vector<T>& v) { std::cout << str(v); }
template<typename T>
void _ox_print_one(const std::optional<T>& o) { if(o) std::cout<<"Some("<<*o<<")"; else std::cout<<"None"; }
template<typename T, typename E>
void _ox_print_one(const Result<T,E>& r) { if(r.is_ok) std::cout<<"Ok("<<r.value<<")"; else std::cout<<"Err("<<r.error<<")"; }

// Variadic print — handles 1+ args space-separated
template<typename T, typename... Rest>
void print(const T& first, const Rest&... rest) {
    _ox_print_one(first);
    ((std::cout << " ", _ox_print_one(rest)), ...);
    std::cout << "\n";
}
inline void print() { std::cout << "\n"; }

// ── collections ───────────────────────────────────────────────────────────
template<typename T> size_t len(const std::vector<T>& v){return v.size();}
inline size_t len(const std::string& s){return s.size();}

template<typename T> void push(std::vector<T>& v,const T& x){v.push_back(x);}
template<typename T> T    pop (std::vector<T>& v){T x=v.back();v.pop_back();return x;}

template<typename T>
bool contains(const std::vector<T>& v, const T& x){
    return std::find(v.begin(),v.end(),x)!=v.end();
}

// ── range ─────────────────────────────────────────────────────────────────
inline std::vector<int> range(int n){
    std::vector<int> r; r.reserve(n);
    for(int i=0;i<n;i++) r.push_back(i); return r;
}
inline std::vector<int> range(int a,int b){
    std::vector<int> r; r.reserve(b-a>0?b-a:0);
    for(int i=a;i<b;i++) r.push_back(i); return r;
}

inline int    to_int(const std::string& s)   { return std::stoi(s); }
inline double to_float(const std::string& s) { return std::stod(s); }
inline int parse_int(const std::string& s, int base) { return std::stoi(s, nullptr, base); }

// ── math ──────────────────────────────────────────────────────────────────
using std::sqrt; using std::abs; using std::pow;
using std::sin;  using std::cos; using std::tan;
using std::floor;using std::ceil;using std::round;
using std::log;  using std::exp;

inline int max(int a,int b){return a>b?a:b;}
inline int min(int a,int b){return a<b?a:b;}
inline double maxf(double a,double b){return a>b?a:b;}
inline double minf(double a,double b){return a<b?a:b;}

// ── string helpers ──────────────────────────────────────────────────────────
inline std::string str_get(const std::string& s, int i) {
    if (i < 0 || i >= (int)s.size()) return "\0";
    return std::string(1, s[i]);
}

inline bool str_contains(const std::string& s, const std::string& sub) {
    return s.find(sub) != std::string::npos;
}

inline std::string str_sub(const std::string& s, int start, int end) {
    if (start < 0) start = 0;
    if (end > (int)s.size()) end = (int)s.size();
    if (start >= end) return "";
    return s.substr(start, end - start);
}

inline bool is_digit(const std::string& c) {
    return c.size() == 1 && std::isdigit(static_cast<unsigned char>(c[0]));
}

inline bool is_alpha(const std::string& c) {
    return c.size() == 1 && std::isalpha(static_cast<unsigned char>(c[0]));
}

inline bool is_alnum(const std::string& c) {
    return c.size() == 1 && std::isalnum(static_cast<unsigned char>(c[0]));
}

inline std::vector<std::string> str_split(const std::string& s, const std::string& delim) {
    std::vector<std::string> parts;
    size_t start = 0, end;
    while ((end = s.find(delim, start)) != std::string::npos) {
        parts.push_back(s.substr(start, end - start));
        start = end + delim.length();
    }
    parts.push_back(s.substr(start));
    return parts;
}

inline std::string str_trim(const std::string& s) {
    size_t start = s.find_first_not_of(" \t\n\r\f\v");
    if (start == std::string::npos) return "";
    size_t end = s.find_last_not_of(" \t\n\r\f\v");
    return s.substr(start, end - start + 1);
}

inline std::string str_trim_start(const std::string& s) {
    size_t start = s.find_first_not_of(" \t\n\r\f\v");
    if (start == std::string::npos) return "";
    return s.substr(start);
}

inline std::string str_trim_end(const std::string& s) {
    size_t end = s.find_last_not_of(" \t\n\r\f\v");
    if (end == std::string::npos) return "";
    return s.substr(0, end + 1);
}

inline std::string str_replace(const std::string& s, const std::string& old_str, const std::string& new_str) {
    size_t pos = s.find(old_str);
    if (pos == std::string::npos) return s;
    std::string r = s;
    return r.replace(pos, old_str.length(), new_str);
}

inline std::string str_replace_all(const std::string& s, const std::string& old_str, const std::string& new_str) {
    std::string r = s;
    size_t pos = 0;
    while ((pos = r.find(old_str, pos)) != std::string::npos) {
        r.replace(pos, old_str.length(), new_str);
        pos += new_str.length();
    }
    return r;
}

inline std::string str_join(const std::vector<std::string>& v, const std::string& delim) {
    std::string r;
    for (size_t i = 0; i < v.size(); i++) {
        if (i) r += delim;
        r += v[i];
    }
    return r;
}

inline std::string to_upper(const std::string& s) {
    std::string r = s;
    for (auto& c : r) c = std::toupper(static_cast<unsigned char>(c));
    return r;
}

inline std::string to_lower(const std::string& s) {
    std::string r = s;
    for (auto& c : r) c = std::tolower(static_cast<unsigned char>(c));
    return r;
}

inline bool starts_with(const std::string& s, const std::string& prefix) {
    return s.find(prefix) == 0;
}

inline bool ends_with(const std::string& s, const std::string& suffix) {
    if (suffix.size() > s.size()) return false;
    return s.rfind(suffix) == s.size() - suffix.size();
}

inline std::string str_repeat(const std::string& s, int n) {
    std::string r;
    for (int i = 0; i < n; i++) r += s;
    return r;
}

inline std::string str_reverse(const std::string& s) {
    return std::string(s.rbegin(), s.rend());
}

inline std::optional<int> str_find(const std::string& s, const std::string& sub) {
    size_t pos = s.find(sub);
    if (pos == std::string::npos) return std::nullopt;
    return static_cast<int>(pos);
}

// ── str_format with format specs ─────────────────────────────────────────────
inline std::string str_format(const std::string& fmt, const std::vector<std::string>& args) {
    std::string r; size_t ai = 0;
    for (size_t i = 0; i < fmt.size(); i++) {
        if (fmt[i] == '{' && i + 1 < fmt.size() && fmt[i + 1] == '}') {
            r += (ai < args.size()) ? args[ai++] : std::string(); ++i;
        } else if (fmt[i] == '{' && i + 1 < fmt.size() && fmt[i + 1] == ':') {
            size_t end = fmt.find('}', i + 2);
            if (end == std::string::npos) { r += fmt[i]; continue; }
            std::string spec = fmt.substr(i + 2, end - i - 2);
            std::string val = (ai < args.size()) ? args[ai++] : std::string();
            char align = 0; size_t width = 0; int precision = -1; char type = 0; size_t pos = 0;
            if (pos < spec.size() && (spec[pos] == '<' || spec[pos] == '>' || spec[pos] == '^')) { align = spec[pos++]; }
            while (pos < spec.size() && isdigit(spec[pos])) { width = width * 10 + (spec[pos++] - '0'); }
            if (pos < spec.size() && spec[pos] == '.') { pos++; precision = 0; while (pos < spec.size() && isdigit(spec[pos])) { precision = precision * 10 + (spec[pos++] - '0'); } }
            if (pos < spec.size()) { type = spec[pos++]; }
            std::string formatted;
            if (type == 'f' || type == 'F') {
                std::ostringstream oss; oss << std::fixed;
                if (precision >= 0) oss << std::setprecision(precision);
                try { double d = std::stod(val); oss << d; } catch (...) { oss << val; }
                formatted = oss.str();
            } else if (type == 'e') {
                std::ostringstream oss; oss << std::scientific;
                if (precision >= 0) oss << std::setprecision(precision);
                try { oss << std::stod(val); } catch (...) { oss << val; }
                formatted = oss.str();
            } else if (type == 'E') {
                std::ostringstream oss; oss << std::scientific << std::uppercase;
                if (precision >= 0) oss << std::setprecision(precision);
                try { oss << std::stod(val); } catch (...) { oss << val; }
                formatted = oss.str();
            } else if (type == 'x') {
                std::ostringstream oss; oss << std::hex;
                try { oss << std::stoi(val); } catch (...) { oss << val; }
                formatted = oss.str();
            } else if (type == 'X') {
                std::ostringstream oss; oss << std::hex << std::uppercase;
                try { oss << std::stoi(val); } catch (...) { oss << val; }
                formatted = oss.str();
            } else if (type == 'o') {
                std::ostringstream oss; oss << std::oct;
                try { oss << std::stoi(val); } catch (...) { oss << val; }
                formatted = oss.str();
            } else if (type == 'b') {
                try { int n = std::stoi(val); std::string b; do { b = char('0' + (n & 1)) + b; n >>= 1; } while (n); formatted = b; } catch (...) { formatted = val; }
            } else { formatted = val; }
            if (width > 0 && formatted.size() < width) {
                size_t pad = width - formatted.size();
                if (align == '^') { formatted = std::string(pad/2,' ') + formatted + std::string(pad-pad/2,' '); }
                else if (align == '>') { formatted = std::string(pad,' ') + formatted; }
                else { formatted = formatted + std::string(pad,' '); }
            }
            r += formatted; i = end;
        } else if (fmt[i] == '}' && i + 1 < fmt.size() && fmt[i + 1] == '}') {
            r += '}'; ++i;
        } else { r += fmt[i]; }
    }
    return r;
}

// ── functional chaining (List<T>) ────────────────────────────────────────
template<typename T, typename F>
auto _ox_map(const std::vector<T>& v, F fn) -> std::vector<std::decay_t<decltype(fn(std::declval<const T&>()))>> {
    using U = std::decay_t<decltype(fn(std::declval<const T&>()))>;
    std::vector<U> r; r.reserve(v.size());
    for (const auto& x : v) r.push_back(fn(x)); return r;
}

template<typename T, typename F>
std::vector<T> _ox_filter(const std::vector<T>& v, F fn) {
    std::vector<T> r;
    for (const auto& x : v) if (fn(x)) r.push_back(x); return r;
}

template<typename T, typename U, typename F>
U _ox_reduce(const std::vector<T>& v, U init, F fn) {
    U acc = init;
    for (const auto& x : v) acc = fn(acc, x); return acc;
}

template<typename T, typename F>
void _ox_for_each(const std::vector<T>& v, F fn) {
    for (const auto& x : v) fn(x);
}

template<typename T, typename F>
bool _ox_any(const std::vector<T>& v, F fn) {
    for (const auto& x : v) if (fn(x)) return true; return false;
}

template<typename T, typename F>
bool _ox_all(const std::vector<T>& v, F fn) {
    for (const auto& x : v) if (!fn(x)) return false; return true;
}

template<typename T, typename F>
std::optional<T> _ox_find(const std::vector<T>& v, F fn) {
    for (const auto& x : v) if (fn(x)) return std::optional<T>(x);
    return std::nullopt;
}

template<typename T>
T _ox_sum(const std::vector<T>& v) {
    T acc = T(); for (const auto& x : v) acc = acc + x; return acc;
}

template<typename T>
T _ox_min(const std::vector<T>& v) {
    T m = v[0]; for (const auto& x : v) if (x < m) m = x; return m;
}

template<typename T>
T _ox_max(const std::vector<T>& v) {
    T m = v[0]; for (const auto& x : v) if (m < x) m = x; return m;
}

// ── itertools (List<T>) ────────────────────────────────────────────────────
template<typename T>
std::vector<std::vector<T>> _ox_combinations(const std::vector<T>& v, int k) {
    std::vector<std::vector<T>> r;
    int n = (int)v.size();
    if (k > n || k <= 0) return r;
    if (k == 0) { r.push_back({}); return r; }
    std::vector<int> idx(k);
    for (int i = 0; i < k; i++) idx[i] = i;
    while (true) {
        std::vector<T> c(k);
        for (int i = 0; i < k; i++) c[i] = v[idx[i]];
        r.push_back(c);
        int i = k - 1;
        while (i >= 0 && idx[i] == n - k + i) i--;
        if (i < 0) break;
        idx[i]++;
        for (int j = i + 1; j < k; j++) idx[j] = idx[j-1] + 1;
    }
    return r;
}

template<typename T>
std::vector<std::vector<T>> _ox_permutations(const std::vector<T>& v, int k) {
    std::vector<std::vector<T>> r;
    int n = (int)v.size();
    if (k > n || k <= 0) return r;
    std::vector<int> idx(k);
    std::vector<bool> used(n, false);
    std::function<void(int)> perm = [&](int pos) {
        if (pos == k) {
            std::vector<T> p(k);
            for (int i = 0; i < k; i++) p[i] = v[idx[i]];
            r.push_back(p);
            return;
        }
        for (int i = 0; i < n; i++) {
            if (!used[i]) {
                used[i] = true;
                idx[pos] = i;
                perm(pos + 1);
                used[i] = false;
            }
        }
    };
    perm(0);
    return r;
}

template<typename T>
std::vector<std::vector<T>> _ox_chunked(const std::vector<T>& v, int n) {
    std::vector<std::vector<T>> r;
    int sz = (int)v.size();
    if (n <= 0) return r;
    for (int i = 0; i < sz; i += n) {
        std::vector<T> chunk;
        int end = (i + n > sz) ? sz : (i + n);
        for (int j = i; j < end; j++) chunk.push_back(v[j]);
        r.push_back(chunk);
    }
    return r;
}

template<typename T>
std::vector<std::vector<T>> _ox_windowed(const std::vector<T>& v, int n) {
    std::vector<std::vector<T>> r;
    int sz = (int)v.size();
    if (n <= 0 || n > sz) return r;
    for (int i = 0; i <= sz - n; i++) {
        std::vector<T> win;
        for (int j = i; j < i + n; j++) win.push_back(v[j]);
        r.push_back(win);
    }
    return r;
}

template<typename T>
std::vector<std::pair<int, T>> _ox_enumerate(const std::vector<T>& v) {
    std::vector<std::pair<int, T>> r;
    for (int i = 0; i < (int)v.size(); i++) {
        r.push_back({i, v[i]});
    }
    return r;
}

std::vector<std::pair<int, char>> _ox_enumerate(const std::string& s) {
    std::vector<std::pair<int, char>> r;
    for (int i = 0; i < (int)s.size(); i++) {
        r.push_back({i, s[i]});
    }
    return r;
}

template<typename T>
std::vector<std::vector<T>> _ox_pairwise(const std::vector<T>& v) {
    return _ox_windowed(v, 2);
}

template<typename T>
std::vector<T> _ox_reversed(const std::vector<T>& v) {
    std::vector<T> r(v.rbegin(), v.rend());
    return r;
}

template<typename T>
std::vector<T> _ox_cycle(const std::vector<T>& v, int n) {
    std::vector<T> r;
    r.reserve(v.size() * n);
    for (int i = 0; i < n; i++) {
        for (const auto& x : v) r.push_back(x);
    }
    return r;
}

// ── slice helper ───────────────────────────────────────────────────────────
template<typename T>
std::vector<T> _ox_slice(const std::vector<T>& v, int start, int end, int step) {
    std::vector<T> r;
    if (step == 0) step = 1;
    int sz = (int)v.size();
    if (start < 0) start = 0;
    if (end < 0 || end > sz) end = sz;
    if (step < 0) { step = -step; }
    for (int i = start; i < end; i += step) {
        r.push_back(v[i]);
    }
    return r;
}

template<typename T>
std::vector<T> _ox_slice(const nc::NdArray<T>& arr, int start, int end, int step) {
    if (step == 0) step = 1;
    int sz = (int)arr.size();
    if (start < 0) start = 0;
    if (end < 0 || end > sz) end = sz;
    if (step < 0) { step = -step; }
    std::vector<T> r;
    for (int i = start; i < end; i += step) {
        r.push_back(arr[i]);
    }
    return r;
}

inline std::string _ox_str_slice(const std::string& s, int start, int end, int step) {
    std::string r;
    if (step == 0) step = 1;
    int sz = (int)s.size();
    if (start < 0) start = 0;
    if (end < 0 || end > sz) end = sz;
    if (step < 0) { step = -step; }
    for (int i = start; i < end; i += step) {
        r += s[i];
    }
    return r;
}

// ── sorted helper ───────────────────────────────────────────────────────
template<typename T>
std::vector<T> _ox_sorted(const std::vector<T>& v, bool reverse=false) {
    std::vector<T> r = v;
    std::sort(r.begin(), r.end());
    if (reverse) std::reverse(r.begin(), r.end());
    return r;
}

inline std::vector<std::string> _ox_sorted(const std::string& s) {
    std::vector<std::string> r;
    for (char c : s) r.push_back(std::string(1, c));
    std::sort(r.begin(), r.end());
    return r;
}

// ── count helper ───────────────────────────────────────────────────────────
template<typename T>
int _ox_count(const std::vector<T>& v, const T& x) {
    return (int)std::count(v.begin(), v.end(), x);
}

inline int str_count(const std::string& s, const std::string& sub) {
    if (sub.empty()) return 0;
    int count = 0;
    size_t pos = 0;
    while ((pos = s.find(sub, pos)) != std::string::npos) {
        count++;
        pos += sub.length();
    }
    return count;
}

// ── list from str helper ──────────────────────────────────────────────────────
inline std::vector<std::string> _ox_list_from_str(const std::string& s) {
    std::vector<std::string> r;
    for (char c : s) {
        r.push_back(std::string(1, c));
    }
    return r;
}

// ── map / list helpers ──────────────────────────────────────────────────────
template<typename K, typename V>
bool map_contains(const std::unordered_map<K,V>& m, const K& k) {
    return m.count(k) > 0;
}

template<typename T, typename F>
std::vector<T> _ox_take_while(const std::vector<T>& v, F fn) {
    std::vector<T> r;
    for (const auto& x : v) { if (!fn(x)) break; r.push_back(x); }
    return r;
}

template<typename T, typename F>
std::vector<T> _ox_drop_while(const std::vector<T>& v, F fn) {
    std::vector<T> r;
    size_t i = 0;
    while (i < v.size() && fn(v[i])) i++;
    for (; i < v.size(); i++) r.push_back(v[i]);
    return r;
}

template<typename K, typename V>
V map_get(const std::unordered_map<K,V>& m, const K& k) {
    return m.at(k);
}
template<typename K, typename V>
void map_set(std::unordered_map<K,V>& m, const K& k, const V& v) {
    m[k] = v;
}
template<typename T>
void list_insert(std::vector<T>& v, int i, const T& x) {
    v.insert(v.begin() + i, x);
}
template<typename T>
T list_remove(std::vector<T>& v, int i) {
    T x = v[i];
    v.erase(v.begin() + i);
    return x;
}

// ── system ──────────────────────────────────────────────────────────────────
static int _ox_argc;
static char** _ox_argv;

inline std::vector<std::string> args() {
    std::vector<std::string> r;
    for (int i = 0; i < _ox_argc; i++) r.push_back(std::string(_ox_argv[i]));
    return r;
}

inline std::string read_file(const std::string& path) {
    std::ifstream f(path);
    if (!f) return "";
    std::ostringstream ss;
    ss << f.rdbuf();
    return ss.str();
}

inline std::vector<std::string> read_lines(const std::string& path) {
    std::vector<std::string> lines;
    std::ifstream f(path);
    if (!f) return lines;
    std::string line;
    while (std::getline(f, line)) {
        lines.push_back(line);
    }
    return lines;
}

inline void write_file(const std::string& path, const std::string& contents) {
    std::ofstream f(path);
    f << contents;
}

inline int exec(const std::string& cmd) {
    return std::system(cmd.c_str());
}

// ── filesystem ────────────────────────────────────────────────────────────────
inline bool fs_exists(const std::string& path) {
    return std::filesystem::exists(path);
}

inline bool fs_is_file(const std::string& path) {
    return std::filesystem::is_regular_file(path);
}

inline bool fs_is_dir(const std::string& path) {
    return std::filesystem::is_directory(path);
}

inline void fs_mkdir(const std::string& path) {
    std::filesystem::create_directories(path);
}

inline std::vector<std::string> fs_list_dir(const std::string& path) {
    std::vector<std::string> r;
    for (const auto& entry : std::filesystem::directory_iterator(path)) {
        r.push_back(entry.path().string());
    }
    return r;
}

inline void fs_remove(const std::string& path) {
    std::filesystem::remove_all(path);
}

inline void fs_rename(const std::string& old_path, const std::string& new_path) {
    std::filesystem::rename(old_path, new_path);
}

inline void fs_copy(const std::string& from, const std::string& to) {
    std::filesystem::copy(from, to,
        std::filesystem::copy_options::recursive
        | std::filesystem::copy_options::overwrite_existing);
}

inline std::string fs_cwd() {
    return std::filesystem::current_path().string();
}

// ── math helpers ──────────────────────────────────────────────────────────
template<typename T>
nc::NdArray<T> _ox_math_to_ndarray(const std::vector<T>& v) {
    return nc::NdArray<T>(v.begin(), v.end());
}

template<typename T>
nc::NdArray<T> _ox_to_ndarray(const std::vector<T>& v) {
    return nc::NdArray<T>(v.begin(), v.end());
}

template<typename T>
std::vector<T> _ox_math_from_ndarray(const nc::NdArray<T>& arr) {
    return arr.toStlVector();
}

template<typename T>
nc::NdArray<T> _ox_math_to_ndarray_2d(const std::vector<std::vector<T>>& v) {
    return nc::NdArray<T>(v);
}

template<typename T>
std::vector<std::vector<T>> _ox_math_from_ndarray_2d(const nc::NdArray<T>& arr) {
    std::vector<std::vector<T>> result(static_cast<size_t>(arr.numRows()),
                                        std::vector<T>(static_cast<size_t>(arr.numCols())));
    for (int32_t r = 0; r < arr.numRows(); ++r)
        for (int32_t c = 0; c < arr.numCols(); ++c)
            result[static_cast<size_t>(r)][static_cast<size_t>(c)] = arr(r, c);
    return result;
}

inline std::vector<double> _ox_math_zeros(int n) {
    return _ox_math_from_ndarray(nc::zeros<double>(1, static_cast<nc::uint32>(n)));
}

inline std::vector<double> _ox_math_ones(int n) {
    return _ox_math_from_ndarray(nc::ones<double>(1, static_cast<nc::uint32>(n)));
}

inline std::vector<double> _ox_math_linspace(double start, double end, int n) {
    return _ox_math_from_ndarray(nc::linspace(start, end, static_cast<nc::uint32>(n)));
}

inline std::vector<double> _ox_math_arange(double start, double end, double step) {
    return _ox_math_from_ndarray(nc::arange(start, end, step));
}

inline double _ox_math_dot(const std::vector<double>& a, const std::vector<double>& b) {
    return nc::dot(_ox_math_to_ndarray(a), _ox_math_to_ndarray(b)).item();
}

inline std::vector<std::vector<double>> _ox_math_matmul(
    const std::vector<std::vector<double>>& a,
    const std::vector<std::vector<double>>& b) {
    return _ox_math_from_ndarray_2d(
        nc::matmul(_ox_math_to_ndarray_2d(a), _ox_math_to_ndarray_2d(b)));
}

inline std::vector<std::vector<double>> _ox_math_transpose(
    const std::vector<std::vector<double>>& a) {
    return _ox_math_from_ndarray_2d(_ox_math_to_ndarray_2d(a).transpose());
}

inline double _ox_math_norm(const std::vector<double>& a) {
    return nc::norm(_ox_math_to_ndarray(a)).item();
}

inline std::vector<std::vector<double>> _ox_math_inv(
    const std::vector<std::vector<double>>& a) {
    return _ox_math_from_ndarray_2d(nc::linalg::inv(_ox_math_to_ndarray_2d(a)));
}

inline double _ox_math_det(const std::vector<std::vector<double>>& a) {
    return nc::linalg::det(_ox_math_to_ndarray_2d(a));
}

inline std::vector<double> _ox_math_solve(
    const std::vector<std::vector<double>>& A,
    const std::vector<double>& b) {
    return _ox_math_from_ndarray(
        nc::linalg::solve(_ox_math_to_ndarray_2d(A), _ox_math_to_ndarray(b)));
}

inline std::vector<double> _ox_math_sin(const std::vector<double>& a) {
    return _ox_math_from_ndarray(nc::sin(_ox_math_to_ndarray(a)));
}

inline std::vector<double> _ox_math_cos(const std::vector<double>& a) {
    return _ox_math_from_ndarray(nc::cos(_ox_math_to_ndarray(a)));
}

inline std::vector<double> _ox_math_tan(const std::vector<double>& a) {
    return _ox_math_from_ndarray(nc::tan(_ox_math_to_ndarray(a)));
}

inline std::vector<double> _ox_math_sqrt(const std::vector<double>& a) {
    return _ox_math_from_ndarray(nc::sqrt(_ox_math_to_ndarray(a)));
}

inline std::vector<double> _ox_math_abs(const std::vector<double>& a) {
    return _ox_math_from_ndarray(nc::abs(_ox_math_to_ndarray(a)));
}

inline std::vector<double> _ox_math_exp(const std::vector<double>& a) {
    return _ox_math_from_ndarray(nc::exp(_ox_math_to_ndarray(a)));
}

inline std::vector<double> _ox_math_log(const std::vector<double>& a) {
    return _ox_math_from_ndarray(nc::log(_ox_math_to_ndarray(a)));
}

inline std::vector<double> _ox_math_floor(const std::vector<double>& a) {
    return _ox_math_from_ndarray(nc::floor(_ox_math_to_ndarray(a)));
}

inline std::vector<double> _ox_math_ceil(const std::vector<double>& a) {
    return _ox_math_from_ndarray(nc::ceil(_ox_math_to_ndarray(a)));
}

inline std::vector<double> _ox_math_add(const std::vector<double>& a, const std::vector<double>& b) {
    return _ox_math_from_ndarray(_ox_math_to_ndarray(a) + _ox_math_to_ndarray(b));
}

inline std::vector<double> _ox_math_sub(const std::vector<double>& a, const std::vector<double>& b) {
    return _ox_math_from_ndarray(_ox_math_to_ndarray(a) - _ox_math_to_ndarray(b));
}

inline std::vector<double> _ox_math_mul(const std::vector<double>& a, const std::vector<double>& b) {
    return _ox_math_from_ndarray(_ox_math_to_ndarray(a) * _ox_math_to_ndarray(b));
}

inline std::vector<double> _ox_math_div(const std::vector<double>& a, const std::vector<double>& b) {
    return _ox_math_from_ndarray(_ox_math_to_ndarray(a) / _ox_math_to_ndarray(b));
}

inline double _ox_math_sum(const std::vector<double>& a) {
    return nc::sum(_ox_math_to_ndarray(a)).item();
}

inline double _ox_math_mean(const std::vector<double>& a) {
    return nc::mean(_ox_math_to_ndarray(a)).item();
}

inline double _ox_math_min(const std::vector<double>& a) {
    return nc::min(_ox_math_to_ndarray(a)).item();
}

inline double _ox_math_max(const std::vector<double>& a) {
    return nc::max(_ox_math_to_ndarray(a)).item();
}

inline std::vector<double> _ox_math_reshape(const std::vector<double>& a, int rows, int cols) {
    auto arr = _ox_math_to_ndarray(a);
    arr.reshape(rows, cols);
    return _ox_math_from_ndarray(arr);
}

template<typename... Ts>
auto _ox_sorted(const std::tuple<Ts...>& t) {
    using T = std::common_type_t<Ts...>;
    std::vector<T> v;
    std::apply([&v](auto&&... args) { ((v.push_back(args)), ...); }, t);
    std::sort(v.begin(), v.end());
    return v;
}

// ── User Code ──────────────────────────────────────────────────────────────
"""

# ═══════════════════════════════════════════════════════════════
#  TYPE MAPPING
# ═══════════════════════════════════════════════════════════════

_TYPE_MAP = {'int':'int','float':'double','bool':'bool','str':'std::string','void':'void'}

def _split_args(s: str) -> PyList[str]:
    args, cur, depth = [], '', 0
    for c in s:
        if c in '<([': depth+=1
        elif c in '>)]': depth-=1
        if c==',' and depth==0: args.append(cur.strip()); cur=''
        else: cur+=c
    if cur.strip(): args.append(cur.strip())
    return args

def map_type(t: str) -> str:
    if t in _TYPE_MAP: return _TYPE_MAP[t]
    if t.startswith('('):
        inner = t[1:-1]
        mapped = ', '.join(map_type(a) for a in _split_args(inner))
        return f"std::tuple<{mapped}>"
    if '<' in t:
        outer = t[:t.index('<')]
        inner = t[t.index('<')+1:t.rindex('>')]
        mapped = ', '.join(map_type(a) for a in _split_args(inner))
        return f"{outer}<{mapped}>"
    return t  # user-defined type

# ═══════════════════════════════════════════════════════════════
#  MODULE RESOLVER
# ═══════════════════════════════════════════════════════════════

class ModuleResolver:
    """Resolves `import foo.bar` to file contents and path."""
    def __init__(self, source_path: str = ''):
        self._cache: dict = {}
        self._resolving: set = set()
        self._search_paths = self._default_paths(source_path)

    def _default_paths(self, source_path):
        paths = ['.']
        if source_path:
            dirname = os.path.dirname(os.path.abspath(source_path))
            if dirname:
                paths.insert(0, dirname)
        compiler_dir = os.path.dirname(os.path.abspath(__file__))
        oxlib = os.path.join(compiler_dir, 'oxlib')
        if os.path.isdir(oxlib):
            paths.append(oxlib)
        return paths

    def add_search_path(self, p: str):
        if p not in self._search_paths:
            self._search_paths.insert(0, p)

    def resolve(self, module_path):
        mod_name = '.'.join(module_path)
        if mod_name in self._cache:
            return self._cache[mod_name]
        if mod_name in self._resolving:
            raise ImportError(f"circular import detected: `{mod_name}`")
        self._resolving.add(mod_name)
        for base in self._search_paths:
            filepath = os.path.join(base, *module_path) + '.ox'
            if os.path.isfile(filepath):
                with open(filepath, 'r', encoding='utf-8') as f:
                    src = f.read()
                result = (src, filepath)
                self._cache[mod_name] = result
                return result
        raise ImportError(f"cannot find module `{mod_name}`")

# ═══════════════════════════════════════════════════════════════
#  CODE GENERATOR
# ═══════════════════════════════════════════════════════════════

class GenTranspiler:
    """Transforms a generator function into a state-machine struct + wrapper.

    Each yield creates a state boundary. While-loops with yields use state
    transitions for the loop check/body/exit. If/elif/else branches with
    yields use the same approach.
    """

    def __init__(self, cg, fn: FnDef):
        self.cg = cg
        self.fn = fn
        self.state_counter = 1  # state 0 is function entry
        self.DONE = 9999
        self.lines: PyList[str] = []
        self._member_names: set = set()
        self._member_types: dict = {}

    def _state(self) -> int:
        s = self.state_counter
        self.state_counter += 1
        return s

    def _emit(self, *args):
        self.lines.extend(args)

    def _case(self, s: int):
        self._emit(f"case {s}:")

    def _any_yield(self, stmts) -> bool:
        for s in stmts:
            if isinstance(s, YieldStmt):
                return True
            if isinstance(s, (IfStmt, WhileStmt, ForStmt)):
                body = getattr(s, 'body', getattr(s, 'then_body', []))
                if self._any_yield(body if isinstance(body, list) else [body]):
                    return True
                if hasattr(s, 'elif_clauses'):
                    for _, eb in s.elif_clauses:
                        if self._any_yield(eb):
                            return True
                if hasattr(s, 'else_body') and s.else_body:
                    if self._any_yield(s.else_body):
                        return True
        return False

    def transpile(self):
        """Returns (struct_cpp, wrapper_cpp)"""
        self._find_members(self.fn.body)
        # Generate state-machine body
        self._case(0)  # function entry
        self._gen_body(self.fn.body)
        self._emit(f"_state = {self.DONE}; return None;")
        self._case(self.DONE)
        self._emit("return None;")
        return self._emit_struct(), self._emit_wrapper()

    @staticmethod
    def _infer_type_from(expr) -> str:
        if isinstance(expr, IntLit): return 'int'
        if isinstance(expr, FloatLit): return 'double'
        if isinstance(expr, BoolLit): return 'bool'
        if isinstance(expr, StrLit): return 'std::string'
        if isinstance(expr, UnaryOp): return GenTranspiler._infer_type_from(expr.operand)
        if isinstance(expr, BinOp):
            lt = GenTranspiler._infer_type_from(expr.left)
            rt = GenTranspiler._infer_type_from(expr.right)
            if lt == 'double' or rt == 'double': return 'double'
            if lt == 'int' or rt == 'int': return 'int'
            return lt or rt
        return 'int'

    def _find_members(self, stmts):
        for s in stmts:
            if isinstance(s, VarDecl):
                self._member_names.add(s.name)
                if s.type_ann:
                    self._member_types[s.name] = map_type(s.type_ann)
                else:
                    self._member_types[s.name] = self._infer_type_from(s.value)
            elif isinstance(s, (IfStmt, WhileStmt, ForStmt)):
                body = getattr(s, 'body', getattr(s, 'then_body', []))
                if body:
                    self._find_members(body if isinstance(body, list) else [body])
                if hasattr(s, 'elif_clauses'):
                    for _, eb in s.elif_clauses:
                        self._find_members(eb)
                if hasattr(s, 'else_body') and s.else_body:
                    self._find_members(s.else_body)

    def _get_inner_type(self) -> str:
        rt = self.fn.return_type
        if rt.startswith('Generator<'):
            return rt[len('Generator<'):-1]
        return 'void'

    def _emit_struct(self) -> str:
        sn = f"_gen_{self.fn.name}"
        inner = self._get_inner_type()
        lines: PyList[str] = [f"struct {sn} {{"]
        lines.append(f"    int _state = 0;")
        # Parameters as members
        for pname, ptype, *_ in self.fn.params:
            lines.append(f"    {map_type(ptype)} {pname};")
        # Local vars as members
        for vname in sorted(self._member_names):
            if not any(p[0] == vname for p in self.fn.params):
                lines.append(f"    {self._member_types[vname]} {vname};")
        # Constructor
        cons = ', '.join(f"{map_type(pt)} {pn}" for pn, pt, *_ in self.fn.params)
        init = ', '.join(f"{pn}({pn})" for pn, _, *_ in self.fn.params)
        lines.append(f"    {sn}({cons}) : {init} {{}}")
        # _next method
        lines.append(f"    Option<{map_type(inner)}> _next() {{")
        lines.append(f"        while (true) {{")
        lines.append(f"            switch (_state) {{")
        for ln in self.lines:
            lines.append(f"                {ln}")
        lines.append(f"            }}")
        lines.append(f"        }}")
        lines.append(f"    }}")
        lines.append(f"}};")
        return '\n'.join(lines)

    def _emit_wrapper(self) -> str:
        sn = f"_gen_{self.fn.name}"
        inner = self._get_inner_type()
        ret = f"Generator<{map_type(inner)}>"
        parts = []
        for pn, pt, dflt, *_ in self.fn.params:
            p = f"{map_type(pt)} {pn}"
            if dflt is not None:
                p += f" = {self.cg.expr(dflt)}"
            parts.append(p)
        params = ', '.join(parts)
        args = ', '.join(pn for pn, _, *_ in self.fn.params)
        return f"{ret} {self.fn.name}({params}) {{\n    auto gen = {sn}({args});\n    return {ret}([gen]() mutable -> Option<{map_type(inner)}> {{ return gen._next(); }});\n}}"

    def _gen_body(self, stmts):
        for stmt in stmts:
            if isinstance(stmt, YieldStmt):
                cont = self._state()
                val = self.cg.expr(stmt.value)
                self._emit(f"{{ _state = {cont}; return Some({val}); }}")
                self._case(cont)
            elif isinstance(stmt, WhileStmt):
                self._gen_while(stmt)
            elif isinstance(stmt, IfStmt):
                self._gen_if(stmt)
            elif isinstance(stmt, ForStmt):
                self._gen_for(stmt)
            elif isinstance(stmt, VarDecl):
                val = self.cg.expr(stmt.value)
                # Variable is already a struct member, just assign
                self._emit(f"{stmt.name} = {val};")
            elif isinstance(stmt, Assignment):
                self._emit(f"{self.cg.expr(stmt.target)} {stmt.op} {self.cg.expr(stmt.value)};")
            elif isinstance(stmt, ExprStmt):
                self._emit(f"{self.cg.expr(stmt.expr)};")
            elif isinstance(stmt, ReturnStmt):
                self._emit(f"_state = {self.DONE}; return None;")
            elif isinstance(stmt, BreakStmt):
                self._emit("break;")
            elif isinstance(stmt, ContinueStmt):
                self._emit("continue;")

    def _gen_while(self, s: WhileStmt):
        cond = self.cg.expr(s.cond)
        check = self._state()
        exit_s = self._state()
        # End prior state, transition to loop check
        self._emit(f"_state = {check}; break;")
        self._case(check)
        self._emit(f"if (!({cond})) {{ _state = {exit_s}; break; }}")
        self._gen_body(s.body)
        self._emit(f"_state = {check}; break;")
        self._case(exit_s)

    def _gen_if(self, s: IfStmt):
        has_yield = self._any_yield(s.then_body)
        if s.else_body:
            has_yield = has_yield or self._any_yield(s.else_body)
        for _, eb in s.elif_clauses:
            has_yield = has_yield or self._any_yield(eb)

        if has_yield:
            self._gen_if_stateful(s)
        else:
            cond = self.cg.expr(s.cond)
            self._emit(f"if ({cond}) {{")
            self._gen_body(s.then_body)
            self._emit(f"}} else {{")
            if s.else_body:
                self._gen_body(s.else_body)
            for ec, eb in s.elif_clauses:
                self._emit(f"}} else if ({self.cg.expr(ec)}) {{")
                self._gen_body(eb)
            self._emit(f"}}")

    def _gen_if_stateful(self, s: IfStmt):
        """Generate if/elif/else using state transitions."""
        if_check = self._state()
        after_s = self._state()
        self._emit(f"_state = {if_check}; break;")
        self._case(if_check)
        cond = self.cg.expr(s.cond)
        # Flatten elif into recursive else-if
        all_branches: PyList[tuple] = [(s.cond, s.then_body)]
        for ec, eb in s.elif_clauses:
            all_branches.append((ec, eb))
        if s.else_body is not None:
            all_branches.append((None, s.else_body))

        # For each branch except the last, check its condition
        for i, (br_cond, br_body) in enumerate(all_branches):
            branch_state = self._state()
            if i < len(all_branches) - 1:
                next_cond = all_branches[i+1][0]
                if br_cond is not None:
                    cond_str = self.cg.expr(br_cond)
                    self._emit(f"if ({cond_str}) {{ _state = {branch_state}; break; }}")
                else:
                    self._emit(f"_state = {branch_state}; break;")
                self._case(branch_state)
                self._gen_body(br_body)
                self._emit(f"_state = {after_s}; break;")
            else:
                # Last branch (may be else)
                if br_cond is not None:
                    cond_str = self.cg.expr(br_cond)
                    self._emit(f"if ({cond_str}) {{ _state = {branch_state}; break; }} else {{ _state = {after_s}; break; }}")
                    self._case(branch_state)
                self._gen_body(br_body)
                self._emit(f"_state = {after_s}; break;")
        self._case(after_s)

    def _gen_for(self, s: ForStmt):
        it = s.iterable
        if isinstance(it, RangeLit):
            start = self.cg.expr(it.start)
            end = self.cg.expr(it.end)
            # Check if body has yields
            if self._any_yield(s.body):
                # State-machine for-loop
                check = self._state()
                exit_s = self._state()
                self._emit(f"_state = {check}; break;")
                self._case(check)
                self._emit(f"if ({s.var} >= {end}) {{ _state = {exit_s}; break; }}")
                self._gen_body(s.body)
                self._emit(f"{s.var}++; _state = {check}; break;")
                self._case(exit_s)
            else:
                self._emit(f"for (int {s.var} = {start}; {s.var} < {end}; ++{s.var}) {{")
                self._gen_body(s.body)
                self._emit(f"}}")
        else:
            it_expr = self.cg.expr(it)
            if self._any_yield(s.body):
                check = self._state()
                exit_s = self._state()
                self._emit(f"auto&& _it = {it_expr}; auto _ip = _it.begin();")
                self._emit(f"_state = {check}; break;")
                self._case(check)
                self._emit(f"if (_ip == _it.end()) {{ _state = {exit_s}; break; }}")
                self._emit(f"auto& {s.var} = *_ip;")
                self._gen_body(s.body)
                self._emit(f"++_ip; _state = {check}; break;")
                self._case(exit_s)
            else:
                self._emit(f"for (auto& {s.var} : {it_expr}) {{")
                self._gen_body(s.body)
                self._emit(f"}}")

class CodeGen:
    def __init__(self, module_namespace: str = '', modules: set = None):
        self.out: PyList[str] = []
        self.depth = 0
        self.in_class: Optional[str] = None
        self._tmp = 0
        self.module_namespace = module_namespace
        self.modules: set = modules or set()

    def w(self, line=''):
        self.out.append('    '*self.depth + line)

    def tmp(self) -> str:
        self._tmp += 1; return f"_ox_{self._tmp}"

    def generate(self, prog: Program, include_runtime: bool = True) -> str:
        if include_runtime:
            self.w(RUNTIME)
        # Inside a namespace module: structs are forward-declared inside it
        if self.module_namespace:
            self.w(f"namespace {self.module_namespace} {{")
            self.depth += 1
        node_class = None
        for s in prog.stmts:
            if isinstance(s, ClassDef):
                templ = f"template<{', '.join('typename '+g for g in s.generics)}> " if s.generics else ''
                self.w(f"{templ}struct {s.name};")
                if s.name == 'Node':
                    node_class = s
        if node_class:
            self.w('')
            self.gen_class(node_class)  # full def early so List<Node> globals are valid
        if any(isinstance(s, ClassDef) and s is not node_class for s in prog.stmts):
            self.w('')
        # Forward-declare all free functions so they can reference each other
        for s in prog.stmts:
            if isinstance(s, FnDef):
                self.gen_fn_decl(s)
        self.w('')
        for s in prog.stmts:
            if s is node_class: continue
            self.gen_top(s)
        if self.module_namespace:
            self.depth -= 1
            self.w("}")
            self.w('')
        return '\n'.join(self.out)

    def gen_top(self, node):
        if   isinstance(node, ClassDef):  self.gen_class(node)
        elif isinstance(node, FnDef):     self.gen_fn(node)
        elif isinstance(node, ImportStmt): self.w(f"// import {'.'.join(node.path)}")
        elif isinstance(node, VarDecl):   self.gen_var_decl(node); self.w('')
        else: self.gen_stmt(node)

    # ── Class ──────────────────────────────────────────────────

    def gen_class(self, cls: ClassDef):
        if cls.generics:
            self.w(f"template<{', '.join('typename '+g for g in cls.generics)}>")
        self.w(f"struct {cls.name} {{")
        self.depth += 1
        for fn, ft in cls.fields:
            self.w(f"{map_type(ft)} {fn};")
        if cls.fields and cls.methods: self.w('')
        old = self.in_class; self.in_class = cls.name
        for m in cls.methods: self.gen_method(m)
        self.in_class = old
        self.depth -= 1
        self.w('};'); self.w('')

    def gen_method(self, fn: FnDef):
        parts = []
        for n, t, dflt, *_ in fn.params:
            p = f"{map_type(t)} {n}"
            if dflt is not None:
                p += f" = {self.expr(dflt)}"
            parts.append(p)
        params = ', '.join(parts)
        self.w(f"{map_type(fn.return_type)} {fn.name}({params}) {{")
        self.depth += 1
        for s in fn.body: self.gen_stmt(s)
        self.depth -= 1
        self.w('}'); self.w('')

    def _has_yield(self, stmts) -> bool:
        for s in stmts:
            if isinstance(s, YieldStmt):
                return True
            if isinstance(s, (IfStmt, WhileStmt, ForStmt)):
                body = getattr(s, 'body', getattr(s, 'then_body', []))
                if self._has_yield(body if isinstance(body, list) else [body]):
                    return True
                if hasattr(s, 'elif_clauses'):
                    for _, eb in s.elif_clauses:
                        if self._has_yield(eb):
                            return True
                if hasattr(s, 'else_body') and s.else_body:
                    if self._has_yield(s.else_body):
                        return True
        return False

    def gen_fn(self, fn: FnDef):
        if self._has_yield(fn.body):
            return self.gen_generator_fn(fn)
        if fn.generics:
            # Add defaults for params not appearing in function parameters (e.g. deque_new<T>())
            param_types = {t for _, t, *_ in fn.params}
            used_in_params = set()
            for pt in param_types:
                for g in fn.generics:
                    if g in pt:
                        used_in_params.add(g)
            defaults = []
            for g in fn.generics:
                if g not in used_in_params:
                    defaults.append(f"typename {g} = int")
                else:
                    defaults.append(f"typename {g}")
            self.w(f"template<{', '.join(defaults)}>")
        params_list = list(fn.params)
        primitives = {'int', 'float', 'bool', 'str', 'void'}
        generic_set = set(fn.generics)
        parts = []
        for n, t, dflt, *_ in params_list:
            base = _base_type(t)
            if base not in primitives and base not in ('List', 'Map', 'Option') and base not in generic_set:
                p = f"{map_type(t)}& {n}"
            else:
                p = f"{map_type(t)} {n}"
            if dflt is not None:
                p += f" = {self.expr(dflt)}"
            parts.append(p)
        params = ', '.join(parts)
        # C++ requires main() to return int
        ret = 'int' if fn.name == 'main' else map_type(fn.return_type)
        if fn.name == 'main':
            self.w(f"int main(int argc, char* argv[]) {{")
            self.depth += 1
            self.w('_ox_argc = argc; _ox_argv = argv;')
            self.w('#ifdef _WIN32')
            self.w('SetConsoleOutputCP(CP_UTF8);')
            self.w('#endif')
            for s in fn.body: self.gen_stmt(s)
            self.w('return 0;')
        else:
            self.w(f"{ret} {fn.name}({params}) {{")
            self.depth += 1
            for s in fn.body: self.gen_stmt(s)
        self.depth -= 1
        self.w('}'); self.w('')

    def gen_fn_decl(self, fn: FnDef):
        """Forward-declare a free function so it can be referenced before definition."""
        if self._has_yield(fn.body):
            return
        if fn.generics:
            param_types = {t for _, t, *_ in fn.params}
            used_in_params = set()
            for pt in param_types:
                for g in fn.generics:
                    if g in pt:
                        used_in_params.add(g)
            defaults = []
            for g in fn.generics:
                if g not in used_in_params:
                    defaults.append(f"typename {g} = int")
                else:
                    defaults.append(f"typename {g}")
            self.w(f"template<{', '.join(defaults)}>")
        params_list = list(fn.params)
        primitives = {'int', 'float', 'bool', 'str', 'void'}
        generic_set = set(fn.generics)
        parts = []
        for n, t, dflt, *_ in params_list:
            base = _base_type(t)
            if base not in primitives and base not in ('List', 'Map', 'Option') and base not in generic_set:
                p = f"{map_type(t)}& {n}"
            else:
                p = f"{map_type(t)} {n}"
            if dflt is not None:
                p += f" = {self.expr(dflt)}"
            parts.append(p)
        params = ', '.join(parts)
        ret = 'int' if fn.name == 'main' else map_type(fn.return_type)
        if fn.name == 'main':
            self.w(f"int main(int argc, char* argv[]);")
        else:
            self.w(f"{ret} {fn.name}({params});")

    # ── Statements ─────────────────────────────────────────────

    def gen_stmt(self, node):
        if isinstance(node, VarDecl):     self.gen_var_decl(node)
        elif isinstance(node, Assignment): self.gen_assign(node)
        elif isinstance(node, ReturnStmt):
            v = self.expr(node.value) if node.value is not None else ''
            self.w(f"return{' '+v if v else ''};")
        elif isinstance(node, BreakStmt):    self.w('break;')
        elif isinstance(node, ContinueStmt): self.w('continue;')
        elif isinstance(node, IfStmt):     self.gen_if(node)
        elif isinstance(node, ForStmt):    self.gen_for(node)
        elif isinstance(node, WhileStmt):  self.gen_while(node)
        elif isinstance(node, MatchStmt):  self.gen_match(node)
        elif isinstance(node, ExprStmt):   self.w(f"{self.expr(node.expr)};")
        elif isinstance(node, FnDef):      self.gen_fn(node)
        else: self.w(f"/* unhandled {type(node).__name__} */")

    def gen_var_decl(self, v: VarDecl):
        val = self.expr(v.value)
        if hasattr(v, '_destructure_vars'):
            self.w(f"auto [{', '.join(v._destructure_vars)}] = {val};")
        elif v.type_ann:
            self.w(f"{map_type(v.type_ann)} {v.name} = {val};")
        else:
            self.w(f"auto {v.name} = {val};")

    def gen_assign(self, a: Assignment):
        self.w(f"{self.expr(a.target)} {a.op} {self.expr(a.value)};")

    def gen_if(self, node: IfStmt):
        self.w(f"if ({self.expr(node.cond)}) {{")
        self.depth += 1
        for s in node.then_body: self.gen_stmt(s)
        self.depth -= 1; self.w('}')
        for ec, eb in node.elif_clauses:
            self.w(f"else if ({self.expr(ec)}) {{")
            self.depth += 1
            for s in eb: self.gen_stmt(s)
            self.depth -= 1; self.w('}')
        if node.else_body is not None:
            self.w('else {'); self.depth += 1
            for s in node.else_body: self.gen_stmt(s)
            self.depth -= 1; self.w('}')

    def gen_for(self, node: ForStmt):
        it = node.iterable
        if isinstance(it, RangeLit):
            s = self.expr(it.start); e = self.expr(it.end)
            self.w(f"for (int {node.var} = {s}; {node.var} < {e}; ++{node.var}) {{")
        elif isinstance(it, StrLit):
            self.w(f"for (auto {node.var} : std::string({self.expr(it)})) {{")
        elif len(node.vars) > 1:
            self.w(f"for (auto [{', '.join(node.vars)}] : {self.expr(it)}) {{")
        else:
            self.w(f"for (auto {node.var} : {self.expr(it)}) {{")
        self.depth += 1
        for s in node.body: self.gen_stmt(s)
        self.depth -= 1; self.w('}')

    def gen_while(self, node: WhileStmt):
        self.w(f"while ({self.expr(node.cond)}) {{")
        self.depth += 1
        for s in node.body: self.gen_stmt(s)
        self.depth -= 1; self.w('}')

    def gen_generator_fn(self, fn: FnDef):
        """Generate state-machine C++ for a generator function."""
        t = GenTranspiler(self, fn)
        struct_code, wrapper_code = t.transpile()
        for ln in struct_code.split('\n'):
            self.w(ln)
        self.w('')
        for ln in wrapper_code.split('\n'):
            self.w(ln)

    def gen_match(self, node: MatchStmt):
        sv = self.tmp()
        self.w(f"auto {sv} = {self.expr(node.subject)};")
        first = True
        for pat, body in node.arms:
            if isinstance(pat, WildCard):
                kw = '{' if first else 'else {'
            elif isinstance(pat, RangeLit):
                s = self.expr(pat.start); e = self.expr(pat.end)
                cond = f"({sv} >= {s} && {sv} < {e})"
                kw = f"if ({cond}) {{" if first else f"else if ({cond}) {{"
            else:
                pv = self.expr(pat)
                kw = f"if ({sv} == {pv}) {{" if first else f"else if ({sv} == {pv}) {{"
            self.w(kw); first = False
            self.depth += 1
            for s in body: self.gen_stmt(s)
            self.depth -= 1; self.w('}')

    # ── Expressions ────────────────────────────────────────────

    def expr(self, node) -> str:
        if isinstance(node, IntLit):    return str(node.value)
        if isinstance(node, FloatLit):
            s = str(node.value)
            return s if '.' in s or 'e' in s else s+'.0'
        if isinstance(node, StrLit):
            esc = (node.value
                   .replace('\\','\\\\').replace('"','\\"')
                   .replace('\n','\\n').replace('\t','\\t').replace('\r','\\r'))
            return f'"{esc}"'
        if isinstance(node, BoolLit):  return 'true' if node.value else 'false'
        if isinstance(node, NoneLit):  return 'std::nullopt'
        if isinstance(node, SomeLit):  return f"Some({self.expr(node.value)})"
        if isinstance(node, WildCard): return '_'
        if isinstance(node, Ident):
            # self → (*this) inside class methods
            if node.name == 'self' and self.in_class:
                return '(*this)'
            if '<' in node.name:
                return map_type(node.name)
            return node.name
        if isinstance(node, BinOp):
            op = node.op
            lt = getattr(node.left, '_type', '')
            rt = getattr(node.right, '_type', '')
            lbase = _base_type(lt) if lt else ''
            rbase = _base_type(rt) if rt else ''
            both_primitive = (lt in ('int','float','bool','str','void') or not lt) and (rt in ('int','float','bool','str','void') or not rt)
            op_methods = {'+': 'op_add', '-': 'op_sub', '*': 'op_mul', '/': 'op_div', '%': 'op_mod'}
            if not both_primitive and op in op_methods:
                left = self.expr(node.left)
                right = self.expr(node.right)
                return f"{left}.{op_methods[op]}({right})"
            if op == 'in':
                return f"(contains({self.expr(node.right)}, {self.expr(node.left)}))"
            op = {'and':'&&','or':'||'}.get(node.op, node.op)
            return f"({self.expr(node.left)} {op} {self.expr(node.right)})"
        if isinstance(node, UnaryOp):
            return f"({node.op} {self.expr(node.operand)})"
        if isinstance(node, FnCall):
            fn   = self.expr(node.func)
            args = ', '.join(self.expr(a) for a in node.args)
            if isinstance(node.func, Ident):
                if node.func.name == 'Ok':
                    return f"Ok({args})"
                if node.func.name == 'Err':
                    return f"Err({args})"
                if node.func.name == 'list':
                    return f"_ox_list_from_str({args})"
                if node.func.name == 'sorted':
                    return f"_ox_sorted({args})"
                if node.func.name == 'enumerate':
                    return f"_ox_enumerate({args})"
                if node.func.name == 'int':
                    return f"static_cast<int>({args})"
                if node.func.name == 'float':
                    return f"static_cast<double>({args})"
                if node.func.name == 'bool':
                    return f"static_cast<bool>({args})"
                if '<' in node.func.name:
                    fn = map_type(node.func.name)
            return f"{fn}({args})"
        if isinstance(node, MethodCall):
            obj  = self.expr(node.obj)
            args = ', '.join(self.expr(a) for a in node.args)
            mname = map_type(node.name) if '<' in node.name else node.name
            obj_type = getattr(node.obj, '_type', '')
            obj_base = _base_type(obj_type) if obj_type else ''
            if isinstance(node.obj, Ident) and node.obj.name in self.modules:
                return f"_oxm_{node.obj.name}::{mname}({args})"
            if node.name == 'sorted':
                if args:
                    return f"_ox_sorted({obj}, {args})"
                return f"_ox_sorted({obj})"
            # String method dispatch (checked before list chaining)
            str_methods = {
                'length': 'len', 'contains': 'str_contains',
                'starts_with': 'starts_with', 'ends_with': 'ends_with',
                'count': 'str_count', 'find': 'str_find',
                'to_upper': 'to_upper', 'to_lower': 'to_lower',
                'replace': 'str_replace', 'reverse': 'str_reverse',
            }
            if obj_base == 'str' and node.name in str_methods:
                func = str_methods[node.name]
                return f"{func}({obj}{', ' + args if args else ''})"
            # List methods dispatch
            list_methods = {
                'length': 'len', 'contains': 'contains', 'count': '_ox_count',
            }
            if obj_base == 'List' and node.name in list_methods:
                func = list_methods[node.name]
                return f"{func}({obj}{', ' + args if args else ''})"
            # List chaining methods
            if node.name in ('map','filter','reduce','for_each','each','any','all',
                             'find','sum','min','max','combinations','permutations',
                             'chunked','windowed','pairwise','reversed','cycle',
                             'take_while','drop_while'):
                fn_args = []
                for a in node.args:
                    if isinstance(a, Attr) and isinstance(a.obj, Ident) and getattr(a.obj, '_type', '') == 'type':
                        cls = a.obj.name
                        mname = a.name
                        fn_args.append(f"[](const {cls}& x) {{ return const_cast<{cls}&>(x).{mname}(); }}")
                    else:
                        fn_args.append(self.expr(a))
                fn_args_str = ', '.join(fn_args)
                return f"_ox_{node.name}({obj}{', ' + fn_args_str if fn_args_str else ''})"
            return f"{obj}.{mname}({args})"
        if isinstance(node, Attr):
            if node.name.isdigit():
                obj_type = getattr(node.obj, '_type', '')
                if obj_type.startswith('('):
                    return f"std::get<{node.name}>({self.expr(node.obj)})"
            if node.name == 'value' and isinstance(node.obj, (Ident, FnCall, MethodCall)):
                obj_type = getattr(node.obj, '_type', '')
                if _base_type(obj_type) == 'Option':
                    return f"_ox_value({self.expr(node.obj)})"
            return f"{self.expr(node.obj)}.{node.name}"
        if isinstance(node, Index):
            obj = self.expr(node.obj)
            obj_type = getattr(node.obj, '_type', '')
            base = _base_type(obj_type) if obj_type else ''
            _known_bracket_types = {'List','Map','Option','Result','Generator','str','int','float','bool','void','NdArray'}
            is_user_class = bool(base and base not in _known_bracket_types and obj_type != 'void')
            if isinstance(node.idx, SliceLit):
                s = node.idx
                start = self.expr(s.start) if s.start is not None else '0'
                end = self.expr(s.end) if s.end is not None else '-1'
                step = self.expr(s.step) if s.step is not None else '1'
                if is_user_class:
                    return f"{obj}.op_slice({start}, {end}, {step})"
                if base == 'str':
                    return f"_ox_str_slice({obj}, {start}, {end}, {step})"
                return f"_ox_slice({obj}, {start}, {end}, {step})"
            if is_user_class:
                return f"{obj}.op_index({self.expr(node.idx)})"
            return f"{obj}[{self.expr(node.idx)}]"
        if isinstance(node, TryOp):
            return f"_ox_try({self.expr(node.value)})"
        if isinstance(node, ListLit):
            elems = ', '.join(self.expr(e) for e in node.elems)
            if not elems:
                lt = getattr(node, '_type', '')
                if lt:
                    return f'{map_type(lt)}()'
                return '{}'
            return '_ox_make_list({' + elems + '})'
        if isinstance(node, TupleLit):
            elems = ', '.join(self.expr(e) for e in node.elems)
            return f'std::make_tuple({elems})'
        if isinstance(node, TernaryExpr):
            return f"({self.expr(node.cond)} ? {self.expr(node.then_expr)} : {self.expr(node.else_expr)})"
        if isinstance(node, LambdaExpr):
            params = ', '.join(f'auto {p}' for p in node.params)
            body = self.expr(node.body)
            return f'[&]({params}) {{ return {body}; }}'
        if isinstance(node, StructLit):
            flds = ', '.join(f".{n}={self.expr(v)}" for n,v in node.fields)
            return f"{node.type_name}{{{flds}}}"
        if isinstance(node, RangeLit):
            return f"range({self.expr(node.start)}, {self.expr(node.end)})"
        return f"/* ? {type(node).__name__} */"

# ═══════════════════════════════════════════════════════════════
#  TYPE CHECKER  (semantic analysis)
# ═══════════════════════════════════════════════════════════════

_PRIMITIVE_TYPES = {'int', 'float', 'bool', 'str', 'void'}
_CONTAINER_TYPES = {'List', 'Map', 'Option', 'Result', 'Generator'}

def _base_type(t: str) -> str:
    return t.split('<')[0] if '<' in t else t

def _type_params(t: str) -> PyList[str]:
    if '<' not in t:
        if t.startswith('('):
            return [t]
        return []
    inner = t[t.index('<') + 1:t.rindex('>')]
    depth, cur, parts = 0, '', []
    for c in inner:
        if c in '<([':
            depth += 1
        elif c in '>)]':
            depth -= 1
        if c == ',' and depth == 0:
            parts.append(cur.strip())
            cur = ''
        else:
            cur += c
    if cur.strip():
        parts.append(cur.strip())
    return parts

class TypeChecker:
    def __init__(self, spans: dict, source_file: SourceFile,
                 module_fns: dict = None, module_classes: dict = None):
        self.diags: PyList[Diagnostic] = []
        self.spans = spans
        self.src = source_file
        self.vars: PyList[dict] = [{}]  # scopes
        self._used: PyList[set] = [set()]  # used vars per scope
        self._unreachable: bool = False
        self.fns: dict = {}  # name -> (params: [(name,type)], return_type)
        self.classes: dict = {}  # name -> ClassDef
        self.in_fn_ret: Optional[str] = None
        self.in_class: Optional[str] = None
        self.modules: dict = {}  # mod_name -> {fn_name: (params, ret, node), ...}
        self.module_classes: dict = {}  # mod_name -> {cls_name: ClassDef}
        self.generic_params: set = set()  # generic type params in scope (T, K, V, etc.)
        if module_fns:
            for mod_name, fns in module_fns.items():
                # Register module name in scope
                self.vars[0][mod_name] = 'module'
                # Store module info for MethodCall resolution
                self.modules[mod_name] = {}
                for fn_name, (params, ret, node) in fns.items():
                    prefixed = f"_oxm_{mod_name}_{fn_name}"
                    self.fns[prefixed] = (params, ret, node)
                    if fn_name not in self.fns:
                        self.fns[fn_name] = (params, ret, node)
                    self.modules[mod_name][fn_name] = (params, ret, node)
        if module_classes:
            for mod_name, classes in module_classes.items():
                self.module_classes[mod_name] = {}
                for cls_name, cls_def in classes.items():
                    prefixed = f"_oxm_{mod_name}_{cls_name}"
                    self.classes[prefixed] = cls_def
                    self.classes[cls_name] = cls_def
                    self.module_classes[mod_name][cls_name] = cls_def

    def _init_builtins(self):
        builtin_fns = {
            'print': ([], 'void'),  # special-cased: accepts any type
            'len': ([('x', 'void')], 'int'),
            'push': ([('list', 'void'), ('val', 'void')], 'void'),
            'pop': ([('list', 'void')], 'void'),
            'range': ([('a', 'int'), ('b', 'int')], 'List<int>'),
            'str': ([('x', 'void')], 'str'),
            'int': ([('x', 'void')], 'int'),
            'float': ([('x', 'void')], 'float'),
            'bool': ([('x', 'void')], 'bool'),
            'sqrt': ([('x', 'float')], 'float'),
            'abs': ([('x', 'float')], 'float'),
            'pow': ([('x', 'float'), ('y', 'float')], 'float'),
            'sin': ([('x', 'float')], 'float'),
            'cos': ([('x', 'float')], 'float'),
            'tan': ([('x', 'float')], 'float'),
            'floor': ([('x', 'float')], 'float'),
            'ceil': ([('x', 'float')], 'float'),
            'round': ([('x', 'float')], 'float'),
            'log': ([('x', 'float')], 'float'),
            'exp': ([('x', 'float')], 'float'),
            'min': ([('a', 'int'), ('b', 'int')], 'int'),
            'max': ([('a', 'int'), ('b', 'int')], 'int'),
            'contains': ([('list', 'void'), ('x', 'void')], 'bool'),
            'read_file': ([('path', 'str')], 'str'),
            'read_lines': ([('path', 'str')], 'List<str>'),
            'write_file': ([('path', 'str'), ('contents', 'str')], 'void'),
            'exec': ([('cmd', 'str')], 'int'),
            'exit': ([('code', 'int')], 'void'),
            'to_int': ([('s', 'str')], 'int'),
            'to_float': ([('s', 'str')], 'float'),
            'parse_int': ([('s', 'str'), ('base', 'int')], 'int'),
            'str_get': ([('s', 'str'), ('i', 'int')], 'str'),
            'str_sub': ([('s', 'str'), ('start', 'int'), ('end', 'int')], 'str'),
            'str_contains': ([('s', 'str'), ('sub', 'str')], 'bool'),
            'args': ([], 'List<str>'),
            'is_digit': ([('c', 'str')], 'bool'),
            'is_alpha': ([('c', 'str')], 'bool'),
            'is_alnum': ([('c', 'str')], 'bool'),
            'str_split': ([('s', 'str'), ('delim', 'str')], 'List<str>'),
            'str_trim': ([('s', 'str')], 'str'),
            'str_trim_start': ([('s', 'str')], 'str'),
            'str_trim_end': ([('s', 'str')], 'str'),
            'str_replace': ([('s', 'str'), ('old_str', 'str'), ('new_str', 'str')], 'str'),
            'str_replace_all': ([('s', 'str'), ('old_str', 'str'), ('new_str', 'str')], 'str'),
            'str_join': ([('v', 'List<str>'), ('delim', 'str')], 'str'),
            'to_upper': ([('s', 'str')], 'str'),
            'to_lower': ([('s', 'str')], 'str'),
            'starts_with': ([('s', 'str'), ('prefix', 'str')], 'bool'),
            'ends_with': ([('s', 'str'), ('suffix', 'str')], 'bool'),
            'str_repeat': ([('s', 'str'), ('n', 'int')], 'str'),
            'str_reverse': ([('s', 'str')], 'str'),
            'str_find': ([('s', 'str'), ('sub', 'str')], 'Option<int>'),
            'map_contains': ([('m', 'void'), ('k', 'void')], 'bool'),
            'map_get': ([('m', 'void'), ('k', 'void')], 'void'),
            'map_set': ([('m', 'void'), ('k', 'void'), ('v', 'void')], 'void'),
            'list_insert': ([('v', 'void'), ('i', 'int'), ('x', 'void')], 'void'),
            'list_remove': ([('v', 'void'), ('i', 'int')], 'void'),
            '_ox_count': ([('v', 'void'), ('x', 'void')], 'int'),
            'str_count': ([('s', 'str'), ('sub', 'str')], 'int'),
            '_ox_list_from_str': ([('s', 'str')], 'List<str>'),
            '_ox_to_ndarray': ([('v', 'void')], 'NdArray'),
            'fs_exists': ([('path', 'str')], 'bool'),
            'fs_is_file': ([('path', 'str')], 'bool'),
            'fs_is_dir': ([('path', 'str')], 'bool'),
            'fs_mkdir': ([('path', 'str')], 'void'),
            'fs_list_dir': ([('path', 'str')], 'List<str>'),
            'fs_remove': ([('path', 'str')], 'void'),
            'fs_rename': ([('old_path', 'str'), ('new_path', 'str')], 'void'),
            'fs_copy': ([('from', 'str'), ('to', 'str')], 'void'),
            'fs_cwd': ([], 'str'),
            'str_format': ([('fmt', 'str'), ('args', 'List<str>')], 'str'),
            'eprint': ([('msg', 'str')], 'void'),
            # ── math builtins (called by oxlib/math.ox) ──
            '_ox_math_zeros': ([('n', 'int')], 'List<float>'),
            '_ox_math_ones': ([('n', 'int')], 'List<float>'),
            '_ox_math_linspace': ([('start', 'float'), ('end', 'float'), ('n', 'int')], 'List<float>'),
            '_ox_math_arange': ([('start', 'float'), ('end', 'float'), ('step', 'float')], 'List<float>'),
            '_ox_math_dot': ([('a', 'List<float>'), ('b', 'List<float>')], 'float'),
            '_ox_math_matmul': ([('a', 'List<List<float>>'), ('b', 'List<List<float>>')], 'List<List<float>>'),
            '_ox_math_transpose': ([('a', 'List<List<float>>')], 'List<List<float>>'),
            '_ox_math_norm': ([('a', 'List<float>')], 'float'),
            '_ox_math_inv': ([('a', 'List<List<float>>')], 'List<List<float>>'),
            '_ox_math_det': ([('a', 'List<List<float>>')], 'float'),
            '_ox_math_solve': ([('A', 'List<List<float>>'), ('b', 'List<float>')], 'List<float>'),
            '_ox_math_sin': ([('a', 'List<float>')], 'List<float>'),
            '_ox_math_cos': ([('a', 'List<float>')], 'List<float>'),
            '_ox_math_tan': ([('a', 'List<float>')], 'List<float>'),
            '_ox_math_sqrt': ([('a', 'List<float>')], 'List<float>'),
            '_ox_math_abs': ([('a', 'List<float>')], 'List<float>'),
            '_ox_math_exp': ([('a', 'List<float>')], 'List<float>'),
            '_ox_math_log': ([('a', 'List<float>')], 'List<float>'),
            '_ox_math_floor': ([('a', 'List<float>')], 'List<float>'),
            '_ox_math_ceil': ([('a', 'List<float>')], 'List<float>'),
            '_ox_math_add': ([('a', 'List<float>'), ('b', 'List<float>')], 'List<float>'),
            '_ox_math_sub': ([('a', 'List<float>'), ('b', 'List<float>')], 'List<float>'),
            '_ox_math_mul': ([('a', 'List<float>'), ('b', 'List<float>')], 'List<float>'),
            '_ox_math_div': ([('a', 'List<float>'), ('b', 'List<float>')], 'List<float>'),
            '_ox_math_sum': ([('a', 'List<float>')], 'float'),
            '_ox_math_mean': ([('a', 'List<float>')], 'float'),
            '_ox_math_min': ([('a', 'List<float>')], 'float'),
            '_ox_math_max': ([('a', 'List<float>')], 'float'),
            '_ox_math_reshape': ([('a', 'List<float>'), ('rows', 'int'), ('cols', 'int')], 'List<float>'),
        }
        for name, (params, ret) in builtin_fns.items():
            self.fns[name] = (params, ret, None)

    def _push_scope(self):
        self.vars.append({})
        self._used.append(set())

    def _pop_scope(self):
        if not self.vars or not self._used:
            return
        unused = set(self.vars[-1]) - self._used[-1]
        for var in unused:
            if not var.startswith('_'):
                sp = self.spans.get(id(self.vars[-1].get(var)))
                self.diags.append(Diagnostic(
                    Severity.WARNING, f"unused variable `{var}`",
                    sp, code='W0001'))
        self.vars.pop()
        self._used.pop()

    def _lookup_var(self, name: str) -> Optional[str]:
        for i, scope in enumerate(reversed(self.vars)):
            if name in scope:
                self._used[-(i + 1)].add(name)
                return scope[name]
        return None

    def _declare_var(self, name: str, ty: str, node) -> None:
        if not self.vars:
            return
        if name in self.vars[-1]:
            sp = self.spans.get(id(node))
            self.diags.append(Diagnostic(
                Severity.ERROR, f"variable `{name}` already declared in this scope",
                sp, code='E0002'))
            return
        for i in range(len(self.vars) - 2, -1, -1):
            if name in self.vars[i]:
                sp = self.spans.get(id(node))
                self.diags.append(Diagnostic(
                    Severity.WARNING, f"variable `{name}` shadows outer declaration",
                    sp, code='W0002'))
                break
        self.vars[-1][name] = ty

    def _error(self, msg: str, node, code: str = '', notes=None):
        sp = self.spans.get(id(node))
        d = Diagnostic(Severity.ERROR, msg, sp, code=code)
        if notes:
            d.notes = notes
        self.diags.append(d)

    def _type_error(self, expected: str, found: str, node, detail: str = ''):
        sp = self.spans.get(id(node))
        msg = f"expected `{expected}`, found `{found}`"
        notes = []
        if detail:
            notes.append((detail, None))
        self.diags.append(Diagnostic(
            Severity.ERROR, msg, sp, code='E0308', notes=notes
        ))

    def _split_tuple_types(self, inner: str) -> PyList[str]:
        parts, depth, cur = [], 0, ''
        for c in inner:
            if c in '(<[':
                depth += 1
            elif c in ')>]':
                depth -= 1
            if c == ',' and depth == 0:
                parts.append(cur.strip())
                cur = ''
            else:
                cur += c
        if cur.strip():
            parts.append(cur.strip())
        return parts

    def check(self, prog: Program) -> None:
        self._init_builtins()
        # First pass: collect all function and class signatures
        for s in prog.stmts:
            if isinstance(s, FnDef):
                self.fns[s.name] = (s.params, s.return_type, s)
            elif isinstance(s, ClassDef):
                self.classes[s.name] = s

        # Second pass: check top-level statements
        for s in prog.stmts:
            self._check_stmt(s)

    def _infer_type(self, node) -> str:
        t = self._infer_type_impl(node)
        # Don't set _type for empty ListLit — let explicit propagation set it instead.
        # This prevents emitting List<void>() in generated C++.
        if not (isinstance(node, ListLit) and not node.elems):
            node._type = t
        return t

    def _infer_type_impl(self, node) -> str:
        if isinstance(node, IntLit):
            return 'int'
        if isinstance(node, FloatLit):
            return 'float'
        if isinstance(node, StrLit):
            return 'str'
        if isinstance(node, BoolLit):
            return 'bool'
        if isinstance(node, NoneLit):
            return 'Option<void>'
        if isinstance(node, SomeLit):
            inner = self._infer_type(node.value)
            return f'Option<{inner}>'
        if isinstance(node, ListLit):
            elem_types = [self._infer_type(e) for e in node.elems]
            return f'List<{elem_types[0]}>' if elem_types else 'List<void>'
        if isinstance(node, WildCard):
            return '_'
        if isinstance(node, Ident):
            if node.name in ('true', 'false'):
                return 'bool'
            if node.name == 'self':
                if self.in_class:
                    return self.in_class
                self._error("`self` is only valid inside class methods", node, 'E0401')
                return 'void'
            ty = self._lookup_var(node.name)
            if ty is not None:
                return ty
            if node.name in self.fns:
                return 'fn'
            if node.name in self.classes:
                return 'type'
            self._error(f"cannot find value `{node.name}` in this scope", node, 'E0425')
            return 'void'
        if isinstance(node, BinOp):
            lt = self._infer_type(node.left)
            rt = self._infer_type(node.right)
            op = node.op
            if op in ('==', '!=', '<', '>', '<=', '>=', 'and', 'or', 'in'):
                if op in ('and', 'or') and lt == 'bool' and rt == 'bool':
                    return 'bool'
                if op == 'in':
                    return 'bool'
                if op in ('==', '!='):
                    return 'bool'
                if op in ('<', '>', '<=', '>='):
                    if lt in ('int', 'float') and rt in ('int', 'float'):
                        return 'bool'
                    self._type_error('int|float', rt, node.right)
                    return 'bool'
                return 'bool'
            if op in ('+', '-', '*', '/', '%'):
                if lt in ('int', 'float') and rt in ('int', 'float'):
                    return lt if lt == rt else 'float'
                if lt == 'str' and op == '+':
                    return 'str'
                # Check operator overloading for class types
                op_methods = {'+': 'op_add', '-': 'op_sub', '*': 'op_mul', '/': 'op_div', '%': 'op_mod'}
                if op in op_methods:
                    method_name = op_methods[op]
                    lbase = _base_type(lt)
                    if lbase in self.classes:
                        cls = self.classes[lbase]
                        for m in cls.methods:
                            if m.name == method_name:
                                return m.return_type
                self._type_error('int|float|str', f'{lt} {op} {rt}', node)
                return lt
            return 'void'
        if isinstance(node, UnaryOp):
            operand_t = self._infer_type(node.operand)
            if node.op == '-':
                if operand_t in ('int', 'float'):
                    return operand_t
                self._type_error('int|float', operand_t, node)
            return operand_t
        if isinstance(node, FnCall):
            fn_expr = node.func
            if isinstance(fn_expr, Ident) and fn_expr.name == 'Ok':
                inner = self._infer_type(node.args[0])
                return f'Result<{inner}, void>'
            if isinstance(fn_expr, Ident) and fn_expr.name == 'Err':
                inner = self._infer_type(node.args[0])
                return f'Result<void, {inner}>'
            if isinstance(fn_expr, Ident) and fn_expr.name == 'list':
                for a in node.args:
                    self._infer_type(a)
                return 'List<str>'
            if isinstance(fn_expr, Ident) and fn_expr.name == 'sorted':
                if node.args:
                    arg_t = self._infer_type(node.args[0])
                    base = _base_type(arg_t)
                    if base == 'List':
                        return arg_t
                    if base == 'str':
                        return 'List<str>'
                    if arg_t.startswith('('):
                        inner = arg_t[1:-1]
                        elem_types = self._split_tuple_types(inner)
                        elem = elem_types[0] if elem_types else 'void'
                        return f'List<{elem}>'
                return 'List<void>'
            if isinstance(fn_expr, Ident) and fn_expr.name == 'enumerate':
                if node.args:
                    arg_t = self._infer_type(node.args[0])
                    base = _base_type(arg_t)
                    if base == 'List':
                        params = _type_params(arg_t)
                        elem = params[0] if params else 'void'
                        return f'List<(int, {elem})>'
                    if base == 'str':
                        return 'List<(int, str)>'
                return 'List<(int, void)>'
            if isinstance(fn_expr, Ident) and fn_expr.name in self.fns:
                fn_name = fn_expr.name
                params, ret, fn_node = self.fns[fn_name]
                old_generic = set(self.generic_params)
                if fn_node:
                    for g in fn_node.generics:
                        self.generic_params.add(g)
                if fn_name == 'print':
                    for arg in node.args:
                        self._infer_type(arg)
                    self.generic_params = old_generic
                    return 'void'  # print accepts any type
                # Count required params (handles both 3-element old format and 4-element with defaults)
                min_args = sum(1 for p in params if len(p) < 4 or p[2] is None)
                if len(node.args) > len(params) or len(node.args) < min_args:
                    self._error(
                        f"function `{fn_name}` takes {len(params)} arguments ({min_args}-{len(params)}) but {len(node.args)} were given",
                        node, 'E0060',
                    )
                    self.generic_params = old_generic
                    return ret
                for i, (arg, p) in enumerate(zip(node.args, params)):
                    pname, ptype = p[0], p[1]
                    arg_t = self._infer_type(arg)
                    if ptype == 'void':
                        continue
                    if arg_t != ptype and not self._is_compatible(arg_t, ptype):
                        self._type_error(ptype, arg_t, arg,
                                         f"argument `{pname}` to `{fn_name}`")
                self.generic_params = old_generic
                return ret
            if isinstance(fn_expr, Ident) and _base_type(fn_expr.name) in _CONTAINER_TYPES:
                return fn_expr.name
            for arg in node.args:
                self._infer_type(arg)
            fn_t = self._infer_type(fn_expr)
            return 'void'
        if isinstance(node, MethodCall):
            if isinstance(node.obj, Ident) and node.obj.name in self.modules:
                mod_name = node.obj.name
                for arg in node.args:
                    self._infer_type(arg)
                base_name = _base_type(node.name)
                if base_name in self.modules[mod_name]:
                    params, ret, fn_node = self.modules[mod_name][base_name]
                    old_generic = set(self.generic_params)
                    if fn_node:
                        for g in fn_node.generics:
                            self.generic_params.add(g)
                    if len(node.args) != len(params):
                        self._error(
                            f"function `{base_name}` in module `{mod_name}` takes {len(params)} argument{'s' if len(params) != 1 else ''} but {len(node.args)} {'were' if len(node.args) != 1 else 'was'} given",
                            node, 'E0060')
                    for i, (arg, p) in enumerate(zip(node.args, params)):
                        pname, ptype = p[0], p[1]
                        arg_t = self._infer_type(arg)
                        if ptype != 'void' and not self._is_compatible(arg_t, ptype):
                            self._type_error(ptype, arg_t, arg, f"argument `{pname}` to `{mod_name}.{base_name}`")
                    self.generic_params = old_generic
                    return ret
                self._error(f"no function named `{base_name}` in module `{mod_name}`", node, 'E0599')
                return 'void'
            obj_t = self._infer_type(node.obj)
            for arg in node.args:
                self._infer_type(arg)
            base = _base_type(obj_t)
            if base in self.classes:
                cls = self.classes[base]
                for m in cls.methods:
                    if m.name == node.name:
                        total = len(m.params)
                        min_args = sum(1 for p in m.params if len(p) < 4 or p[2] is None)
                        if len(node.args) > total or len(node.args) < min_args:
                            self._error(
                                f"method `{node.name}` takes {total} argument{'s' if total != 1 else ''} ({min_args}-{total}) but {len(node.args)} {'were' if len(node.args) != 1 else 'was'} given",
                                node, 'E0060')
                        return m.return_type
                self._error(f"no method named `{node.name}` found in class `{base}`", node, 'E0599')
            # Built-in list chaining methods
            if base == 'List':
                params = _type_params(obj_t)
                elem_type = params[0] if params else 'void'
                if node.name == 'map':
                    for a in node.args:
                        if isinstance(a, Ident) and a.name in self.fns:
                            _, ret, _ = self.fns[a.name]
                            return f'List<{ret}>'
                        if isinstance(a, Attr) and isinstance(a.obj, Ident):
                            cls_name = a.obj.name
                            if cls_name in self.classes:
                                cls = self.classes[cls_name]
                                for m in cls.methods:
                                    if m.name == a.name:
                                        return f'List<{m.return_type}>'
                    return f'List<{elem_type}>'
                if node.name == 'filter':
                    return f'List<{elem_type}>'
                if node.name == 'reduce':
                    if node.args:
                        return self._infer_type(node.args[0])
                    return elem_type
                if node.name in ('for_each', 'each'):
                    return 'void'
                if node.name in ('any', 'all'):
                    return 'bool'
                if node.name == 'find':
                    return f'Option<{elem_type}>'
                if node.name in ('sum', 'min', 'max'):
                    return elem_type
                if node.name in ('combinations', 'permutations', 'chunked', 'windowed', 'pairwise'):
                    return f'List<List<{elem_type}>>'
                if node.name in ('reversed', 'cycle'):
                    return f'List<{elem_type}>'
                if node.name in ('take_while', 'drop_while'):
                    return f'List<{elem_type}>'
                if node.name == 'length':
                    return 'int'
                if node.name == 'contains':
                    return 'bool'
                if node.name == 'count':
                    return 'int'
                return 'void'
            # Built-in str methods
            if base == 'str':
                if node.name == 'length':
                    return 'int'
                if node.name in ('contains', 'starts_with', 'ends_with'):
                    return 'bool'
                if node.name == 'count':
                    return 'int'
                if node.name == 'find':
                    return 'Option<int>'
                if node.name in ('to_upper', 'to_lower', 'reverse', 'replace'):
                    return 'str'
                return 'void'
            return 'void'
        if isinstance(node, VarDecl):
            if node.type_ann:
                return node.type_ann
            if node.value is not None:
                return self._infer_type(node.value)
            return 'void'
        if isinstance(node, TryOp):
            inner = self._infer_type(node.value)
            base = _base_type(inner)
            if base == 'Result':
                params = _type_params(inner)
                return params[0] if params else 'void'
            if base == 'Option':
                params = _type_params(inner)
                return params[0] if params else 'void'
            self._type_error('Result or Option', inner, node)
            return 'void'
        if isinstance(node, Attr):
            obj_t = self._infer_type(node.obj)
            base = _base_type(obj_t)
            if obj_t.startswith('(') and node.name.isdigit():
                # Tuple element access: t.0, t.1, etc.
                inner = obj_t[1:-1]
                elems = self._split_tuple_types(inner)
                idx = int(node.name)
                if 0 <= idx < len(elems):
                    return elems[idx]
                self._error(f"tuple index {idx} out of range (has {len(elems)} elements)", node, 'E0560')
                return 'void'
            if base in self.classes:
                cls = self.classes[base]
                for fn, ft in cls.fields:
                    if fn == node.name:
                        return ft
                for m in cls.methods:
                    if m.name == node.name:
                        return m.return_type
                self._error(f"no field named `{node.name}` on class `{base}`", node, 'E0560')
                return 'void'
            if base == 'Option' and node.name == 'value':
                params = _type_params(obj_t)
                return params[0] if params else 'void'
            return 'void'
        if isinstance(node, Index):
            obj_t = self._infer_type(node.obj)
            base = _base_type(obj_t)
            if isinstance(node.idx, SliceLit):
                if base == 'List':
                    return obj_t
                if base == 'str':
                    return 'str'
                if base in self.classes:
                    cls = self.classes[base]
                    for m in cls.methods:
                        if m.name == 'op_slice':
                            return m.return_type
                return 'void'
            self._infer_type(node.idx)
            if base == 'List':
                params = _type_params(obj_t)
                return params[0] if params else 'void'
            if base == 'str':
                return 'str'
            if base == 'Map':
                params = _type_params(obj_t)
                return params[1] if len(params) > 1 else 'void'
            if base in self.classes:
                cls = self.classes[base]
                for m in cls.methods:
                    if m.name == 'op_index':
                        return m.return_type
            if base and base not in _PRIMITIVE_TYPES and base not in _CONTAINER_TYPES:
                return 'void'
            self._type_error('List|str|Map', obj_t, node.obj)
            return 'void'
        if isinstance(node, StructLit):
            base = _base_type(node.type_name)
            if base in self.classes:
                cls = self.classes[base]
                field_map = dict(cls.fields)
                for fn, fv in node.fields:
                    self._infer_type(fv)
                    if isinstance(fv, ListLit) and not fv.elems and fn in field_map:
                        fv._type = field_map[fn]
                return node.type_name
            for _, fv in node.fields:
                self._infer_type(fv)
            self._error(f"no class named `{node.type_name}`", node, 'E0412')
            return node.type_name
        if isinstance(node, TupleLit):
            elem_types = [self._infer_type(e) for e in node.elems]
            return f"({', '.join(elem_types)})"
        if isinstance(node, LambdaExpr):
            return 'void'
        if isinstance(node, TernaryExpr):
            ct = self._infer_type(node.cond)
            if ct != 'bool':
                self._error(f"expected bool cond, got `{ct}`", node.cond, 'E0020')
            tt = self._infer_type(node.then_expr)
            ec = self._infer_type(node.else_expr)
            if not self._is_compatible(tt, ec):
                self._type_error(tt, ec, node.else_expr)
            return tt
        if isinstance(node, RangeLit):
            return 'List<int>'
        if isinstance(node, SliceLit):
            return 'void'
        return 'void'

    def _is_compatible(self, found: str, expected: str) -> bool:
        if found == expected:
            return True
        if expected in self.generic_params or found in self.generic_params:
            return True
        base_f = _base_type(found)
        base_e = _base_type(expected)
        if base_f == base_e:
            return True
        if expected == 'float' and found == 'int':
            return True
        if expected.startswith('Option<') and found == 'Option<void>':
            return True
        return False

    def _check_stmt(self, node) -> None:
        if self._unreachable and not isinstance(node, (FnDef, ClassDef)):
            sp = self.spans.get(id(node))
            self.diags.append(Diagnostic(
                Severity.WARNING, "unreachable statement",
                sp, code='W0003'))
        if isinstance(node, VarDecl):
            if hasattr(node, '_destructure_vars'):
                # Tuple destructuring: let (a, b, c) = expr
                val_t = self._infer_type(node.value)
                if node.type_ann:
                    if not self._is_compatible(val_t, node.type_ann):
                        self._type_error(node.type_ann, val_t, node.value)
                    if node.type_ann.startswith('('):
                        inner = node.type_ann[1:-1]
                        ann_types = self._split_tuple_types(inner)
                        for i, vn in enumerate(node._destructure_vars):
                            if i < len(ann_types):
                                self._declare_var(vn, ann_types[i], node)
                            else:
                                self._declare_var(vn, 'void', node)
                    else:
                        for vn in node._destructure_vars:
                            self._declare_var(vn, 'void', node)
                elif val_t.startswith('('):
                    inner = val_t[1:-1]
                    elem_types = self._split_tuple_types(inner)
                    for i, vn in enumerate(node._destructure_vars):
                        if i < len(elem_types):
                            self._declare_var(vn, elem_types[i], node)
                        else:
                            self._declare_var(vn, 'void', node)
                else:
                    for vn in node._destructure_vars:
                        self._declare_var(vn, 'void', node)
                return
            val_t = self._infer_type(node.value)
            resolved = node.type_ann or val_t
            if node.type_ann:
                if not self._is_compatible(val_t, node.type_ann):
                    self._type_error(node.type_ann, val_t, node.value)
                self._declare_var(node.name, node.type_ann, node)
                # Propagate annotation type to empty list literals for correct codegen
                if isinstance(node.value, ListLit) and not node.value.elems:
                    node.value._type = node.type_ann
            else:
                self._declare_var(node.name, val_t, node)
            if hasattr(node, 'name_node'):
                node.name_node._type = resolved
        elif isinstance(node, Assignment):
            target_t = self._infer_type(node.target)
            val_t = self._infer_type(node.value)
            if not self._is_compatible(val_t, target_t):
                self._type_error(target_t, val_t, node.value)
        elif isinstance(node, YieldStmt):
            if node.value is not None:
                self._infer_type(node.value)
        elif isinstance(node, ReturnStmt):
            if node.value is not None:
                val_t = self._infer_type(node.value)
                if self.in_fn_ret and not self._is_compatible(val_t, self.in_fn_ret):
                    self._type_error(self.in_fn_ret, val_t, node.value)
                if isinstance(node.value, ListLit) and not node.value.elems and self.in_fn_ret:
                    node.value._type = self.in_fn_ret
            elif self.in_fn_ret and self.in_fn_ret != 'void':
                self._error(f"expected `{self.in_fn_ret}` return value", node, 'E0057')
            self._unreachable = True
        elif isinstance(node, IfStmt):
            self._infer_type(node.cond)
            old_unreachable = self._unreachable
            self._unreachable = False
            self._push_scope()
            for s in node.then_body:
                self._check_stmt(s)
            self._pop_scope()
            self._unreachable = False
            for _, eb in node.elif_clauses:
                self._push_scope()
                for s in eb:
                    self._check_stmt(s)
                self._pop_scope()
            self._unreachable = False
            if node.else_body:
                self._push_scope()
                for s in node.else_body:
                    self._check_stmt(s)
                self._pop_scope()
            self._unreachable = old_unreachable
        elif isinstance(node, ForStmt):
            iter_t = self._infer_type(node.iterable)
            old_unreachable = self._unreachable
            self._unreachable = False
            self._push_scope()
            if isinstance(node.iterable, RangeLit):
                var_type = 'int'
            elif _base_type(iter_t) in _CONTAINER_TYPES:
                params = _type_params(iter_t)
                var_type = params[0] if params else 'void'
            elif _base_type(iter_t) == 'str':
                var_type = 'str'
            else:
                var_type = 'void'
            if len(node.vars) > 1:
                # Tuple destructuring in for loop
                if var_type.startswith('('):
                    inner = var_type[1:-1]
                    elem_types = self._split_tuple_types(inner)
                    for i, vn in enumerate(node.vars):
                        if i < len(elem_types):
                            self.vars[-1][vn] = elem_types[i]
                        else:
                            self.vars[-1][vn] = 'void'
                else:
                    for vn in node.vars:
                        self.vars[-1][vn] = var_type
            else:
                self.vars[-1][node.var] = var_type
            for s in node.body:
                self._check_stmt(s)
            self._pop_scope()
            self._unreachable = old_unreachable
        elif isinstance(node, WhileStmt):
            old_unreachable = self._unreachable
            self._unreachable = False
            self._infer_type(node.cond)
            self._push_scope()
            for s in node.body:
                self._check_stmt(s)
            self._pop_scope()
            self._unreachable = old_unreachable
        elif isinstance(node, MatchStmt):
            old_unreachable = self._unreachable
            self._infer_type(node.subject)
            for _, body in node.arms:
                self._unreachable = False
                self._push_scope()
                for s in body:
                    self._check_stmt(s)
                self._pop_scope()
            self._unreachable = old_unreachable
        elif isinstance(node, FnDef):
            self._unreachable = False
            old_ret = self.in_fn_ret
            self.in_fn_ret = node.return_type
            old_generic = set(self.generic_params)
            for g in node.generics:
                self.generic_params.add(g)
            self._push_scope()
            for p in node.params:
                pname, ptype = p[0], p[1]
                self.vars[-1][pname] = ptype
                # p[2]=default, p[3]=name_node
                if len(p) >= 4 and p[3] is not None:
                    p[3]._type = ptype
            old_cls = self.in_class
            if any(p[0] == 'self' for p in node.params):
                self.in_class = self.in_class or 'Self'
            for s in node.body:
                self._check_stmt(s)
            self.in_class = old_cls
            self._pop_scope()
            self.generic_params = old_generic
            self.in_fn_ret = old_ret
        elif isinstance(node, ClassDef):
            old_cls = self.in_class
            self.in_class = node.name
            for m in node.methods:
                self._check_stmt(m)
            self.in_class = old_cls
        elif isinstance(node, ImportStmt):
            mod_name = '.'.join(node.path)
            if mod_name not in self.modules:
                self._error(f"cannot find module `{mod_name}`", node, 'E0432')
        elif isinstance(node, ExprStmt):
            self._infer_type(node.expr)
        elif isinstance(node, BreakStmt):
            self._unreachable = True
        elif isinstance(node, ContinueStmt):
            self._unreachable = True

# ═══════════════════════════════════════════════════════════════
#  ENTRY POINT
# ═══════════════════════════════════════════════════════════════

def fmt_error(src: str, path: str, msg: str, line: int = 0, col: int = 0) -> str:
    if line and col:
        lines = src.split('\n')
        if 1 <= line <= len(lines):
            source = lines[line - 1]
            sn = str(line)
            pad = ' ' * len(sn)
            loc = f" --> {path}:{line}:{col}\n" if path else f" --> {line}:{col}\n"
            return (
                f"\033[1;31merror\033[0m: {msg}\n"
                f"{loc}"
                f"{pad} |\n"
                f"{sn} | {source}\n"
                f"{pad} | {' ' * (col - 1)}\033[1;31m^\033[0m\n"
            )
    return f"\033[1;31merror\033[0m: {msg}\n"

def compile_source(src: str, path: str = '', check_only: bool = False,
                   search_paths: PyList[str] = None) -> Tuple[str, PyList[Diagnostic]]:
    diags: PyList[Diagnostic] = []
    src_file = SourceFile(src, path)
    try:
        lexer = Lexer(src)
        tokens = lexer.tokenize()
        parser = Parser(tokens, src)
        ast = parser.parse()
        spans = parser.get_spans()

        # ── Module resolution ──────────────────────────────────
        resolver = ModuleResolver(path)
        if search_paths:
            for p in search_paths:
                resolver.add_search_path(p)

        module_fns = {}
        module_classes = {}
        module_cpps: PyList[str] = []

        for stmt in list(ast.stmts):
            if isinstance(stmt, ImportStmt):
                try:
                    mod_src, mod_path = resolver.resolve(stmt.path)
                except ImportError as e:
                    diags.append(Diagnostic(
                        Severity.ERROR, str(e), spans.get(id(stmt)), code='E0432'
                    ))
                    continue

                mod_name = '.'.join(stmt.path)

                # Parse module
                mod_lexer = Lexer(mod_src)
                mod_tokens = mod_lexer.tokenize()
                mod_parser = Parser(mod_tokens, mod_src)
                mod_ast = mod_parser.parse()

                # Type-check module independently
                mod_checker = TypeChecker(mod_parser.get_spans(), SourceFile(mod_src, mod_path))
                mod_checker.check(mod_ast)
                diags.extend(mod_checker.diags)

                if any(d.severity == Severity.ERROR for d in diags):
                    continue

                # Collect module symbols (skip builtins and main)
                fns = {}
                for fn_name, sig in mod_checker.fns.items():
                    if fn_name.startswith('_ox_') or fn_name in ('main', 'print', 'len', 'push', 'pop',
                        'range', 'str', 'int', 'float', 'bool', 'sqrt', 'abs', 'pow',
                        'contains', 'read_file', 'read_lines', 'write_file', 'exec',
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

                classes = {}
                for cls_name, cls_def in mod_checker.classes.items():
                    if cls_name.startswith('_ox_'):
                        continue
                    classes[cls_name] = cls_def
                if classes:
                    module_classes[mod_name] = classes

                # Generate C++ for module (inside namespace, no runtime header)
                mod_cgen = CodeGen(module_namespace=f"_oxm_{mod_name}")
                module_cpps.append(mod_cgen.generate(mod_ast, include_runtime=False))

        # ── Type checking (with module symbols) ──
        checker = TypeChecker(spans, src_file, module_fns=module_fns, module_classes=module_classes)
        checker.check(ast)
        diags.extend(checker.diags)

        if check_only or any(d.severity == Severity.ERROR for d in diags):
            return '', diags

        # ── Codegen ──
        cgen = CodeGen(modules=set(module_fns.keys()))
        main_cpp = cgen.generate(ast)

        # Assemble final C++: runtime is in main_cpp, module cpp between runtime and user code
        # Find the user code marker and insert module code there
        # Insert module C++ code between the runtime header and the user code
        if module_cpps:
            module_block = '\n'.join(module_cpps)
            # main_cpp ends with the user-code section (the "// import ..." comment + main function)
            # Find the split between the RUNTIME header and the user's main code
            user_start = main_cpp.find('// import')
            if user_start == -1:
                user_start = main_cpp.find('int main(')
            if user_start != -1:
                cpp = main_cpp[:user_start] + '\n// ── Module Code ──────────────────────────────────\n' + module_block + '\n\n' + main_cpp[user_start:]
            else:
                cpp = main_cpp
        else:
            cpp = main_cpp
        return cpp, diags
    except (LexError, ParseError) as e:
        line = getattr(e, 'line', 0)
        col = getattr(e, 'col', 0)
        span = None
        if line and col:
            offset = 0
            for _ in range(line - 1):
                offset = src.find('\n', offset) + 1
                if offset == 0:
                    break
            span = Span(offset, offset + 1, line, col, line, col + 1) if offset else None
        diags.append(Diagnostic(
            Severity.ERROR, e.args[0], span, code='E0001'
        ))
        return '', diags


def main():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    import argparse, subprocess, os, shlex
    p = argparse.ArgumentParser(description='Oxybelis → C++ transpiler')
    p.add_argument('source', help='Source file (.ox)')
    p.add_argument('-o', '--output', help='Emit C++ to FILE and stop')
    p.add_argument('-S', '--emit-cpp', action='store_true',
                   help='Print C++ to stdout (for piping)')
    p.add_argument('--cc', default='g++',
                   help='C++ compiler command (default: g++)')
    p.add_argument('--cflags', default='-O3 -std=c++20',
                   help='C++ compiler flags (default: -O3 -std=c++20)')
    p.add_argument('--check', action='store_true',
                   help='Type-check only, no code generation')
    p.add_argument('--fmt', action='store_true',
                   help='Format source code in-place')
    p.add_argument('--highlight', action='store_true',
                   help='Print syntax-highlighted source and exit')
    p.add_argument('--ox-path', action='append', default=[],
                   help='Additional search path for module imports')
    args = p.parse_args()

    with open(args.source, encoding='utf-8') as f:
        src = f.read()

    if args.highlight:
        print(highlight_ox(src))
        return

    if args.fmt:
        from ox_fmt import format_source
        formatted = format_source(src)
        trimmed_src = src.rstrip('\n')
        trimmed_fmt = formatted.rstrip('\n')
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
        return

    cpp, diags = compile_source(src, args.source, check_only=args.check, search_paths=args.ox_path)

    src_file = SourceFile(src, args.source)
    if diags:
        print(render_diagnostics(diags, src_file), file=sys.stderr)

    has_error = any(d.severity == Severity.ERROR for d in diags)
    if has_error:
        sys.exit(1)
    if args.check:
        print(f"\033[32m✓ {args.source} – no errors found\033[0m")
        return

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f: f.write(cpp)
        print(f"\033[32m✓ {args.source} → {args.output}\033[0m")
    elif args.emit_cpp:
        print(cpp)
    else:
        base = os.path.splitext(args.source)[0]
        cpp_file = base + '.cpp'
        exe_file = base + '.exe'
        with open(cpp_file, 'w', encoding='utf-8') as f:
            f.write(cpp)
        try:
            # Auto-detect NumCpp include path
            numcpp_dirs = [
                os.path.join(os.path.dirname(os.path.abspath(__file__)), 'NumCpp', 'include'),
                os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), 'NumCpp', 'include'),
                os.path.join(os.getcwd(), 'NumCpp', 'include'),
            ]
            extra_flags = []
            for d in numcpp_dirs:
                if os.path.isdir(d):
                    extra_flags = [f'-I{d}']
                    break
            mconsole = ['-mconsole'] if sys.platform == 'win32' else []
            cflags_list = shlex.split(args.cflags) if hasattr(shlex, 'split') else args.cflags.split()
            subprocess.run([args.cc] + extra_flags + cflags_list + mconsole +
                           [cpp_file, '-o', exe_file], check=True)
            print(f"\033[32m✓ {args.source} → {exe_file}\033[0m")
            subprocess.run([exe_file])
        except subprocess.CalledProcessError:
            print(f"\033[31m✗ Compilation failed (see {cpp_file})\033[0m",
                  file=sys.stderr)
            sys.exit(1)

if __name__ == '__main__':
    main()
