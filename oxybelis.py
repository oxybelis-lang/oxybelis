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
    BREAK=auto(); CONTINUE=auto()
    # Built-in types
    T_INT=auto(); T_FLOAT=auto(); T_BOOL=auto()
    T_STR=auto(); T_VOID=auto()
    # Operators
    PLUS=auto(); MINUS=auto(); STAR=auto(); SLASH=auto(); PERCENT=auto()
    EQ=auto(); NEQ=auto(); LT=auto(); GT=auto(); LEQ=auto(); GEQ=auto()
    ASSIGN=auto(); PLUS_ASSIGN=auto(); MINUS_ASSIGN=auto()
    STAR_ASSIGN=auto(); SLASH_ASSIGN=auto()
    DOTDOT=auto(); ARROW=auto(); FAT_ARROW=auto(); DOT=auto()
    BANG=auto(); QUESTION=auto()
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
    'break': TT.BREAK, 'continue': TT.CONTINUE,
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
class IfStmt:
    cond: Any; then_body: PyList[Any]
    elif_clauses: PyList[Tuple[Any,PyList[Any]]]; else_body: Optional[PyList[Any]]
@dataclass
class ForStmt:      var: str; iterable: Any; body: PyList[Any]
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
class StructLit:    type_name: str; fields: PyList[Tuple[str,Any]]
@dataclass
class RangeLit:     start: Any; end: Any
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
            return Span(t.pos, t.pos + max(t.length, 1), t.line, t.col, t.line, t.col + max(t.length, 1))
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
                pname = self.expect(TT.IDENT).value
                self.expect(TT.COLON)
                ptype = self.parse_type()
                params.append((pname, ptype))
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
        if t.type == TT.IDENT:
            name = self.advance().value
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
        nt = self.peek()
        name = self.expect(TT.IDENT).value
        type_ann = None
        if self.match_tok(TT.COLON): type_ann = self.parse_type()
        self.expect(TT.ASSIGN)
        value = self.parse_expr()
        n = VarDecl(name, type_ann, value, mutable)
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
        var = self.expect(TT.IDENT).value
        self.expect(TT.IN)
        iterable = self.parse_expr()
        body = self.parse_block()
        n = ForStmt(var, iterable, body)
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

    def parse_expr(self):
        expr = self.parse_or()
        # Range: a..b  (lower precedence than everything else)
        if self.match_tok(TT.DOTDOT):
            end = self.parse_or()
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
        return self._binop(self.parse_add, [TT.EQ, TT.NEQ, TT.LT, TT.GT, TT.LEQ, TT.GEQ])

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
                name = self.expect(TT.IDENT).value
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
                idx = self.parse_expr()
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
            self.advance(); expr = self.parse_expr(); self.expect(TT.RPAREN); return expr

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
#include <fstream>
#include <cstdlib>
#include <cctype>
#include <filesystem>
#include <type_traits>
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

// ── str (declared before print) ─────────────────────────────────────────────
inline std::string str(const std::string& v){ return v; }
inline std::string str(const char* v)     { return std::string(v); }
inline std::string str(int v)        { return std::to_string(v); }
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

// ── print ──────────────────────────────────────────────────────────────────
template<typename T>
void print(const T& v) { std::cout << v << "\n"; }
inline void print(bool v) { std::cout << (v ? "true" : "false") << "\n"; }
inline void print(const std::string& v) { std::cout << v << "\n"; }
template<typename T>
void print(const std::vector<T>& v) {
    std::cout << "[";
    for (size_t i=0;i<v.size();i++){if(i)std::cout<<", ";std::cout<<v[i];}
    std::cout << "]\n";
}
template<typename T>
void print(const std::optional<T>& o){
    if(o) std::cout<<"Some("<<*o<<")\n"; else std::cout<<"None\n";
}
template<typename T, typename E>
void print(const Result<T,E>& r){
    if(r.is_ok) std::cout<<"Ok("<<r.value<<")\n"; else std::cout<<"Err("<<r.error<<")\n";
}

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

// ── functional chaining (List<T>) ────────────────────────────────────────
template<typename T, typename U>
std::vector<U> _ox_map(const std::vector<T>& v, U (*fn)(T)) {
    std::vector<U> r; r.reserve(v.size());
    for (const auto& x : v) r.push_back(fn(x)); return r;
}

template<typename T>
std::vector<T> _ox_filter(const std::vector<T>& v, bool (*fn)(T)) {
    std::vector<T> r;
    for (const auto& x : v) if (fn(x)) r.push_back(x); return r;
}

template<typename T, typename U>
U _ox_reduce(const std::vector<T>& v, U init, U (*fn)(U, T)) {
    U acc = init;
    for (const auto& x : v) acc = fn(acc, x); return acc;
}

template<typename T>
void _ox_for_each(const std::vector<T>& v, void (*fn)(T)) {
    for (const auto& x : v) fn(x);
}

template<typename T>
bool _ox_any(const std::vector<T>& v, bool (*fn)(T)) {
    for (const auto& x : v) if (fn(x)) return true; return false;
}

template<typename T>
bool _ox_all(const std::vector<T>& v, bool (*fn)(T)) {
    for (const auto& x : v) if (!fn(x)) return false; return true;
}

template<typename T>
std::optional<T> _ox_find(const std::vector<T>& v, bool (*fn)(T)) {
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

// ── map / list helpers ──────────────────────────────────────────────────────
template<typename K, typename V>
bool map_contains(const std::unordered_map<K,V>& m, const K& k) {
    return m.count(k) > 0;
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

// ── User Code ──────────────────────────────────────────────────────────────
"""

# ═══════════════════════════════════════════════════════════════
#  TYPE MAPPING
# ═══════════════════════════════════════════════════════════════

_TYPE_MAP = {'int':'int','float':'double','bool':'bool','str':'std::string','void':'void'}

def _split_args(s: str) -> PyList[str]:
    args, cur, depth = [], '', 0
    for c in s:
        if c=='<': depth+=1
        elif c=='>': depth-=1
        if c==',' and depth==0: args.append(cur.strip()); cur=''
        else: cur+=c
    if cur.strip(): args.append(cur.strip())
    return args

def map_type(t: str) -> str:
    if t in _TYPE_MAP: return _TYPE_MAP[t]
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
        for s in prog.stmts:
            if isinstance(s, ClassDef):
                templ = f"template<{', '.join('typename '+g for g in s.generics)}> " if s.generics else ''
                self.w(f"{templ}struct {s.name};")
        if any(isinstance(s, ClassDef) for s in prog.stmts): self.w('')
        for s in prog.stmts:
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
        params = ', '.join(f"{map_type(t)} {n}" for n,t in fn.params)
        self.w(f"{map_type(fn.return_type)} {fn.name}({params}) {{")
        self.depth += 1
        for s in fn.body: self.gen_stmt(s)
        self.depth -= 1
        self.w('}'); self.w('')

    def gen_fn(self, fn: FnDef):
        if fn.generics:
            # Add defaults for params not appearing in function parameters (e.g. deque_new<T>())
            param_types = {t for _, t in fn.params}
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
        for n, t in params_list:
            base = _base_type(t)
            if base not in primitives and base not in ('List', 'Map', 'Option') and base not in generic_set:
                parts.append(f"{map_type(t)}& {n}")
            else:
                parts.append(f"{map_type(t)} {n}")
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
        if v.type_ann:
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
        else:
            self.w(f"for (auto& {node.var} : {self.expr(it)}) {{")
        self.depth += 1
        for s in node.body: self.gen_stmt(s)
        self.depth -= 1; self.w('}')

    def gen_while(self, node: WhileStmt):
        self.w(f"while ({self.expr(node.cond)}) {{")
        self.depth += 1
        for s in node.body: self.gen_stmt(s)
        self.depth -= 1; self.w('}')

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
                if '<' in node.func.name:
                    fn = map_type(node.func.name)
            return f"{fn}({args})"
        if isinstance(node, MethodCall):
            obj  = self.expr(node.obj)
            args = ', '.join(self.expr(a) for a in node.args)
            if isinstance(node.obj, Ident) and node.obj.name in self.modules:
                return f"_oxm_{node.obj.name}::{node.name}({args})"
            if node.name in ('map','filter','reduce','for_each','each','any','all','find','sum','min','max'):
                return f"_ox_{node.name}({obj}{', ' + args if args else ''})"
            return f"{obj}.{node.name}({args})"
        if isinstance(node, Attr):
            if node.name == 'value' and isinstance(node.obj, (Ident, FnCall)):
                return f"(*{self.expr(node.obj)})"
            return f"{self.expr(node.obj)}.{node.name}"
        if isinstance(node, Index):
            return f"{self.expr(node.obj)}[{self.expr(node.idx)}]"
        if isinstance(node, TryOp):
            return f"_ox_try({self.expr(node.value)})"
        if isinstance(node, ListLit):
            elems = ', '.join(self.expr(e) for e in node.elems)
            return '{' + elems + '}'
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
_CONTAINER_TYPES = {'List', 'Map', 'Option', 'Result'}

def _base_type(t: str) -> str:
    return t.split('<')[0] if '<' in t else t

def _type_params(t: str) -> PyList[str]:
    if '<' not in t:
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
            'str_get': ([('s', 'str'), ('i', 'int')], 'str'),
            'str_sub': ([('s', 'str'), ('start', 'int'), ('end', 'int')], 'str'),
            'str_contains': ([('s', 'str'), ('sub', 'str')], 'bool'),
            'args': ([], 'List<str>'),
            'is_digit': ([('c', 'str')], 'bool'),
            'is_alpha': ([('c', 'str')], 'bool'),
            'is_alnum': ([('c', 'str')], 'bool'),
            'map_contains': ([('m', 'void'), ('k', 'void')], 'bool'),
            'map_get': ([('m', 'void'), ('k', 'void')], 'void'),
            'map_set': ([('m', 'void'), ('k', 'void'), ('v', 'void')], 'void'),
            'list_insert': ([('v', 'void'), ('i', 'int'), ('x', 'void')], 'void'),
            'list_remove': ([('v', 'void'), ('i', 'int')], 'void'),
            'fs_exists': ([('path', 'str')], 'bool'),
            'fs_is_file': ([('path', 'str')], 'bool'),
            'fs_is_dir': ([('path', 'str')], 'bool'),
            'fs_mkdir': ([('path', 'str')], 'void'),
            'fs_list_dir': ([('path', 'str')], 'List<str>'),
            'fs_remove': ([('path', 'str')], 'void'),
            'fs_rename': ([('old_path', 'str'), ('new_path', 'str')], 'void'),
            'fs_copy': ([('from', 'str'), ('to', 'str')], 'void'),
            'fs_cwd': ([], 'str'),
        }
        for name, (params, ret) in builtin_fns.items():
            self.fns[name] = (params, ret, None)

    def _push_scope(self):
        self.vars.append({})
        self._used.append(set())

    def _pop_scope(self):
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
        msg = f"mismatched types{': ' + detail if detail else ''}"
        self.diags.append(Diagnostic(
            Severity.ERROR, msg, sp, code='E0308',
            notes=[(f"expected `{expected}`, found `{found}`", None)]
        ))

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
            if not node.elems:
                return 'List<void>'
            elem_types = [self._infer_type(e) for e in node.elems]
            return f'List<{elem_types[0]}>'
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
            if op in ('==', '!=', '<', '>', '<=', '>=', 'and', 'or'):
                if op in ('and', 'or') and lt == 'bool' and rt == 'bool':
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
                if len(node.args) != len(params):
                    self._error(
                        f"function `{fn_name}` takes {len(params)} arguments but {len(node.args)} were given",
                        node, 'E0060',
                    )
                    self.generic_params = old_generic
                    return ret
                for i, (arg, (pname, ptype)) in enumerate(zip(node.args, params)):
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
                if node.name in self.modules[mod_name]:
                    params, ret, fn_node = self.modules[mod_name][node.name]
                    old_generic = set(self.generic_params)
                    if fn_node:
                        for g in fn_node.generics:
                            self.generic_params.add(g)
                    if len(node.args) != len(params):
                        self._error(
                            f"function `{node.name}` in module `{mod_name}` takes {len(params)} argument{'s' if len(params) != 1 else ''} but {len(node.args)} {'were' if len(node.args) != 1 else 'was'} given",
                            node, 'E0060')
                    for i, (arg, (pname, ptype)) in enumerate(zip(node.args, params)):
                        arg_t = self._infer_type(arg)
                        if ptype != 'void' and not self._is_compatible(arg_t, ptype):
                            self._type_error(ptype, arg_t, arg, f"argument `{pname}` to `{mod_name}.{node.name}`")
                    self.generic_params = old_generic
                    return ret
                self._error(f"no function named `{node.name}` in module `{mod_name}`", node, 'E0599')
                return 'void'
            obj_t = self._infer_type(node.obj)
            for arg in node.args:
                self._infer_type(arg)
            base = _base_type(obj_t)
            if base in self.classes:
                cls = self.classes[base]
                for m in cls.methods:
                    if m.name == node.name:
                        expected = len(m.params)  # self excluded from params
                        if len(node.args) != expected:
                            self._error(
                                f"method `{node.name}` takes {expected} argument{'s' if expected != 1 else ''} but {len(node.args)} {('was' if len(node.args) == 1 else 'were')} given",
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
            if base in self.classes:
                cls = self.classes[base]
                for fn, ft in cls.fields:
                    if fn == node.name:
                        return ft
                self._error(f"no field named `{node.name}` on class `{base}`", node, 'E0560')
                return 'void'
            if base == 'Option' and node.name == 'value':
                params = _type_params(obj_t)
                return params[0] if params else 'void'
            return 'void'
        if isinstance(node, Index):
            obj_t = self._infer_type(node.obj)
            self._infer_type(node.idx)
            base = _base_type(obj_t)
            if base == 'List':
                params = _type_params(obj_t)
                return params[0] if params else 'void'
            if base == 'str':
                return 'str'
            if base == 'Map':
                params = _type_params(obj_t)
                return params[1] if len(params) > 1 else 'void'
            self._type_error('List|str|Map', obj_t, node.obj)
            return 'void'
        if isinstance(node, StructLit):
            for _, fv in node.fields:
                self._infer_type(fv)
            base = _base_type(node.type_name)
            if base in self.classes:
                return node.type_name
            self._error(f"no class named `{node.type_name}`", node, 'E0412')
            return node.type_name
        if isinstance(node, RangeLit):
            return 'List<int>'
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
            val_t = self._infer_type(node.value)
            if node.type_ann:
                if not self._is_compatible(val_t, node.type_ann):
                    self._type_error(node.type_ann, val_t, node.value)
                self._declare_var(node.name, node.type_ann, node)
            else:
                self._declare_var(node.name, val_t, node)
        elif isinstance(node, Assignment):
            target_t = self._infer_type(node.target)
            val_t = self._infer_type(node.value)
            if not self._is_compatible(val_t, target_t):
                self._type_error(target_t, val_t, node.value)
        elif isinstance(node, ReturnStmt):
            if node.value is not None:
                val_t = self._infer_type(node.value)
                if self.in_fn_ret and not self._is_compatible(val_t, self.in_fn_ret):
                    self._type_error(self.in_fn_ret, val_t, node.value)
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
            elif _base_type(iter_t) == 'List':
                params = _type_params(iter_t)
                var_type = params[0] if params else 'void'
            else:
                var_type = 'void'
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
            for pname, ptype in node.params:
                self.vars[-1][pname] = ptype
            old_cls = self.in_class
            if any(pname == 'self' for pname, _ in node.params):
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
            loc = f" --> {path}:{line}:{col}\n" if path else f" --> {line}:{col}\n"
            return (
                f"\033[1;31merror\033[0m: {msg}\n"
                f"{loc}"
                f"  |\n"
                f"{line:4} | {source}\n"
                f"  | {' ' * (col - 1)}\033[1;31m^\033[0m\n"
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
                        'sin', 'cos', 'tan', 'floor', 'ceil', 'round', 'log', 'exp',
                        'min', 'max', 'contains', 'read_file', 'read_lines', 'write_file', 'exec',
                        'exit', 'to_int', 'to_float', 'str_get', 'str_sub', 'args',
                        'is_digit', 'is_alpha', 'is_alnum', 'str_contains',
                        'map_contains', 'map_get', 'map_set',
                        'list_insert', 'list_remove',
                        'fs_exists', 'fs_is_file', 'fs_is_dir', 'fs_mkdir',
                        'fs_list_dir', 'fs_remove', 'fs_rename', 'fs_copy', 'fs_cwd'):
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
    import argparse, subprocess, os
    p = argparse.ArgumentParser(description='Oxybelis → C++ transpiler')
    p.add_argument('source', help='Source file (.ox)')
    p.add_argument('-o', '--output', help='Emit C++ to FILE and stop')
    p.add_argument('-S', '--emit-cpp', action='store_true',
                   help='Print C++ to stdout (for piping)')
    p.add_argument('--cc', default='g++',
                   help='C++ compiler command (default: g++)')
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
            subprocess.run([args.cc, '-O3', '-std=c++20', '-mconsole',
                           cpp_file, '-o', exe_file], check=True)
            print(f"\033[32m✓ {args.source} → {exe_file}\033[0m")
        except subprocess.CalledProcessError:
            print(f"\033[31m✗ Compilation failed (see {cpp_file})\033[0m",
                  file=sys.stderr)
            sys.exit(1)

if __name__ == '__main__':
    main()
