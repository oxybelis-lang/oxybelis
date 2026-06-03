// ────────────────────────────────────────────────────────────
//  Oxybelis Compiler – self-hosting bootstrap
//  AST uses a flat node pool (int indices) to avoid
//  C++ self-referential struct issues.
// ────────────────────────────────────────────────────────────

// ── Node pool ───────────────────────────────────────────────
var node_pool: List<Node> = []

class Node {
    kind: str
    // Children stored as indices into node_pool (-1 = null)
    left: int
    right: int
    operand: int
    func: int
    obj: int
    start: int
    end: int
    inner: int
    cond: int
    iterable: int
    subject: int
    target: int
    // Lists of child indices
    params: List<int>
    args: List<int>
    fields: List<int>
    elems: List<int>
    body: List<int>
    then_body: List<int>
    elif_clauses: List<int>
    else_body: List<int>
    stmts: List<int>
    methods: List<int>
    arms: List<int>
    path: List<int>
    type_args: List<int>
    generics: List<int>
    // Scalar data
    int_val: int
    float_val: float
    str_val: str
    bool_val: bool
    name: str
    op: str
    type_name: str
    var_name: str
    return_type: str
    type_ann: str  // empty = no annotation
    is_mutable: bool
    is_pub: bool
    is_lazy: bool
    has_self: bool
}

fn alloc_node() -> int {
    let n = Node { kind: "",
                   left: -1, right: -1, operand: -1, func: -1, obj: -1,
                    start: -1, end: -1, inner: -1, cond: -1,
                   iterable: -1, subject: -1, target: -1,
                   params: [], args: [], fields: [], elems: [],
                   body: [], then_body: [],
                   elif_clauses: [], else_body: [],
                   stmts: [], methods: [],
                   arms: [], path: [],
                   type_args: [], generics: [],
                   int_val: 0, float_val: 0.0,
                   str_val: "", bool_val: false,
                   name: "", op: "", type_name: "",
                   var_name: "", return_type: "", type_ann: "",
                   is_mutable: false, is_pub: false, is_lazy: false,
                   has_self: false }
    push(node_pool, n)
    return len(node_pool) - 1
}

fn node_ref(idx: int) -> Node { return node_pool[idx] }

// ── Node constructors ──────────────────────────────────────
fn node_program(stmts: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "Program"
    node_pool[id].stmts = stmts
    return id
}

fn node_fn_def(name: str, params: List<int>, return_type: str, body: List<int>,
               is_pub: bool, is_lazy: bool, generics: List<int>, has_self: bool) -> int {
    let id = alloc_node()
    node_pool[id].kind = "FnDef"
    node_pool[id].name = name
    node_pool[id].params = params
    node_pool[id].return_type = return_type
    node_pool[id].body = body
    node_pool[id].is_pub = is_pub
    node_pool[id].is_lazy = is_lazy
    node_pool[id].generics = generics
    node_pool[id].has_self = has_self
    return id
}

fn node_class_def(name: str, fields: List<int>, methods: List<int>, generics: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "ClassDef"
    node_pool[id].name = name
    node_pool[id].fields = fields
    node_pool[id].methods = methods
    node_pool[id].generics = generics
    return id
}

fn node_import(path: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "ImportStmt"
    node_pool[id].path = path
    return id
}

fn node_var_decl(name: str, type_ann: str, value: int, is_mutable: bool) -> int {
    let id = alloc_node()
    node_pool[id].kind = "VarDecl"
    node_pool[id].name = name
    node_pool[id].type_ann = type_ann
    node_pool[id].inner = value
    node_pool[id].is_mutable = is_mutable
    return id
}

fn node_assign(target: int, value: int, op: str) -> int {
    let id = alloc_node()
    node_pool[id].kind = "Assignment"
    node_pool[id].target = target
    node_pool[id].inner = value
    node_pool[id].op = op
    return id
}

fn node_return(value: int) -> int {
    let id = alloc_node()
    node_pool[id].kind = "ReturnStmt"
    node_pool[id].inner = value
    return id
}

fn node_break() -> int {
    let id = alloc_node()
    node_pool[id].kind = "BreakStmt"
    return id
}

fn node_continue() -> int {
    let id = alloc_node()
    node_pool[id].kind = "ContinueStmt"
    return id
}

fn node_if(cond: int, then_body: List<int>, elif_clauses: List<int>,
           else_body: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "IfStmt"
    node_pool[id].cond = cond
    node_pool[id].then_body = then_body
    node_pool[id].elif_clauses = elif_clauses
    node_pool[id].else_body = else_body
    return id
}

fn node_for(var_name: str, iterable: int, body: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "ForStmt"
    node_pool[id].var_name = var_name
    node_pool[id].iterable = iterable
    node_pool[id].body = body
    return id
}

fn node_while(cond: int, body: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "WhileStmt"
    node_pool[id].cond = cond
    node_pool[id].body = body
    return id
}

fn node_match(subject: int, arms: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "MatchStmt"
    node_pool[id].subject = subject
    node_pool[id].arms = arms
    return id
}

fn node_expr_stmt(expr: int) -> int {
    let id = alloc_node()
    node_pool[id].kind = "ExprStmt"
    node_pool[id].inner = expr
    return id
}

fn node_bin_op(op: str, left: int, right: int) -> int {
    let id = alloc_node()
    node_pool[id].kind = "BinOp"
    node_pool[id].op = op
    node_pool[id].left = left
    node_pool[id].right = right
    return id
}

fn node_unary_op(op: str, operand: int) -> int {
    let id = alloc_node()
    node_pool[id].kind = "UnaryOp"
    node_pool[id].op = op
    node_pool[id].operand = operand
    return id
}

fn node_fn_call(func: int, args: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "FnCall"
    node_pool[id].func = func
    node_pool[id].args = args
    return id
}

fn node_method_call(obj: int, name: str, args: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "MethodCall"
    node_pool[id].obj = obj
    node_pool[id].name = name
    node_pool[id].args = args
    return id
}

fn node_attr(obj: int, name: str) -> int {
    let id = alloc_node()
    node_pool[id].kind = "Attr"
    node_pool[id].obj = obj
    node_pool[id].name = name
    return id
}

fn node_index(obj: int, idx: int) -> int {
    let id = alloc_node()
    node_pool[id].kind = "Index"
    node_pool[id].obj = obj
    node_pool[id].start = idx
    return id
}

fn node_ident(name: str) -> int {
    let id = alloc_node()
    node_pool[id].kind = "Ident"
    node_pool[id].name = name
    return id
}

fn node_int_lit(value: int) -> int {
    let id = alloc_node()
    node_pool[id].kind = "IntLit"
    node_pool[id].int_val = value
    return id
}

fn node_float_lit(value: float) -> int {
    let id = alloc_node()
    node_pool[id].kind = "FloatLit"
    node_pool[id].float_val = value
    return id
}

fn node_str_lit(value: str) -> int {
    let id = alloc_node()
    node_pool[id].kind = "StrLit"
    node_pool[id].str_val = value
    return id
}

fn node_bool_lit(value: bool) -> int {
    let id = alloc_node()
    node_pool[id].kind = "BoolLit"
    node_pool[id].bool_val = value
    return id
}

fn node_none_lit() -> int {
    let id = alloc_node()
    node_pool[id].kind = "NoneLit"
    return id
}

fn node_some_lit(value: int) -> int {
    let id = alloc_node()
    node_pool[id].kind = "SomeLit"
    node_pool[id].inner = value
    return id
}

fn node_list_lit(elems: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "ListLit"
    node_pool[id].elems = elems
    return id
}

fn node_struct_lit(type_name: str, fields: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "StructLit"
    node_pool[id].type_name = type_name
    node_pool[id].fields = fields
    return id
}

fn node_range_lit(start: int, end: int) -> int {
    let id = alloc_node()
    node_pool[id].kind = "RangeLit"
    node_pool[id].start = start
    node_pool[id].end = end
    return id
}

fn node_try_op(operand: int) -> int {
    let id = alloc_node()
    node_pool[id].kind = "TryOp"
    node_pool[id].operand = operand
    return id
}

fn node_wild() -> int {
    let id = alloc_node()
    node_pool[id].kind = "WildCard"
    return id
}

fn node_param(name: str, ptype: str) -> int {
    let id = alloc_node()
    node_pool[id].kind = "Param"
    node_pool[id].name = name
    node_pool[id].return_type = ptype
    return id
}

fn node_field(name: str, value: int) -> int {
    let id = alloc_node()
    node_pool[id].kind = "Field"
    node_pool[id].name = name
    node_pool[id].inner = value
    return id
}

fn node_elif(cond: int, body: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "ElifClause"
    node_pool[id].cond = cond
    node_pool[id].body = body
    return id
}

fn node_arm(pat: int, body: List<int>) -> int {
    let id = alloc_node()
    node_pool[id].kind = "Arm"
    node_pool[id].left = pat
    node_pool[id].body = body
    return id
}

fn node_str_id(value: str) -> int {
    let id = alloc_node()
    node_pool[id].kind = "StrId"
    node_pool[id].str_val = value
    return id
}

// ── Error reporting ─────────────────────────────────────────
fn report_error(src: str, line: int, col: int, msg: str) -> void {
    var lines: List<str> = []
    var cur: str = ""
    var i = 0
    while i < len(src) {
        let c: str = str_get(src, i)
        if c == "\n" { push(lines, cur); cur = "" }
        else { cur = cur + c }
        i = i + 1
    }
    push(lines, cur)
    var source_line: str = ""
    if line >= 1 and line <= len(lines) { source_line = lines[line - 1] }
    var indent: str = ""
    var j = 0
    while j < col - 1 { indent = indent + " "; j = j + 1 }
    print("error: " + msg)
    print(" --> " + str(line) + ":" + str(col))
    print("  |")
    print(str(line) + " | " + source_line)
    print("  | " + indent + "^")
}

// ── Token type constants ────────────────────────────────────
let TT_INT_LIT      = "INT_LIT"
let TT_FLOAT_LIT    = "FLOAT_LIT"
let TT_STR_LIT      = "STR_LIT"
let TT_IDENT        = "IDENT"
let TT_FN           = "FN"
let TT_LET          = "LET"
let TT_VAR          = "VAR"
let TT_CLASS        = "CLASS"
let TT_IF           = "IF"
let TT_ELSE         = "ELSE"
let TT_ELIF         = "ELIF"
let TT_FOR          = "FOR"
let TT_IN           = "IN"
let TT_WHILE        = "WHILE"
let TT_RETURN       = "RETURN"
let TT_MATCH        = "MATCH"
let TT_LAZY         = "LAZY"
let TT_PUB          = "PUB"
let TT_TRUE         = "TRUE"
let TT_FALSE        = "FALSE"
let TT_NONE_KW      = "NONE_KW"
let TT_SOME_KW      = "SOME_KW"
let TT_IMPORT       = "IMPORT"
let TT_AND          = "AND"
let TT_OR           = "OR"
let TT_NOT          = "NOT"
let TT_BREAK        = "BREAK"
let TT_CONTINUE     = "CONTINUE"
let TT_T_INT        = "T_INT"
let TT_T_FLOAT      = "T_FLOAT"
let TT_T_BOOL       = "T_BOOL"
let TT_T_STR        = "T_STR"
let TT_T_VOID       = "T_VOID"
let TT_PLUS         = "PLUS"
let TT_MINUS        = "MINUS"
let TT_STAR         = "STAR"
let TT_SLASH        = "SLASH"
let TT_PERCENT      = "PERCENT"
let TT_EQ           = "EQ"
let TT_NEQ          = "NEQ"
let TT_LT           = "LT"
let TT_GT           = "GT"
let TT_LEQ          = "LEQ"
let TT_GEQ          = "GEQ"
let TT_ASSIGN       = "ASSIGN"
let TT_PLUS_ASSIGN  = "PLUS_ASSIGN"
let TT_MINUS_ASSIGN = "MINUS_ASSIGN"
let TT_STAR_ASSIGN  = "STAR_ASSIGN"
let TT_SLASH_ASSIGN = "SLASH_ASSIGN"
let TT_DOTDOT       = "DOTDOT"
let TT_ARROW        = "ARROW"
let TT_FAT_ARROW    = "FAT_ARROW"
let TT_DOT          = "DOT"
let TT_BANG         = "BANG"
let TT_QUESTION     = "QUESTION"
let TT_LBRACE       = "LBRACE"
let TT_RBRACE       = "RBRACE"
let TT_LPAREN       = "LPAREN"
let TT_RPAREN       = "RPAREN"
let TT_LBRACKET     = "LBRACKET"
let TT_RBRACKET     = "RBRACKET"
let TT_COLON        = "COLON"
let TT_COMMA        = "COMMA"
let TT_SEMI         = "SEMI"
let TT_UNDERSCORE   = "UNDERSCORE"
let TT_EOF          = "EOF"

fn keyword_type(word: str) -> str {
    if word == "fn"       { return TT_FN }
    if word == "let"      { return TT_LET }
    if word == "var"      { return TT_VAR }
    if word == "class"    { return TT_CLASS }
    if word == "if"       { return TT_IF }
    if word == "else"     { return TT_ELSE }
    if word == "elif"     { return TT_ELIF }
    if word == "for"      { return TT_FOR }
    if word == "in"       { return TT_IN }
    if word == "while"    { return TT_WHILE }
    if word == "return"   { return TT_RETURN }
    if word == "match"    { return TT_MATCH }
    if word == "lazy"     { return TT_LAZY }
    if word == "pub"      { return TT_PUB }
    if word == "true"     { return TT_TRUE }
    if word == "false"    { return TT_FALSE }
    if word == "None"     { return TT_NONE_KW }
    if word == "Some"     { return TT_SOME_KW }
    if word == "import"   { return TT_IMPORT }
    if word == "and"      { return TT_AND }
    if word == "or"       { return TT_OR }
    if word == "not"      { return TT_NOT }
    if word == "break"    { return TT_BREAK }
    if word == "continue" { return TT_CONTINUE }
    if word == "int"      { return TT_T_INT }
    if word == "float"    { return TT_T_FLOAT }
    if word == "bool"     { return TT_T_BOOL }
    if word == "str"      { return TT_T_STR }
    if word == "void"     { return TT_T_VOID }
    if word == "_"        { return TT_UNDERSCORE }
    return ""
}

// ── Token ──────────────────────────────────────────────────
class Token {
    type_name: str
    lexeme: str
    line: int
    col: int
}

fn make_token(type_name: str, value: str, line: int, col: int) -> Token {
    return Token { type_name: type_name, lexeme: value, line: line, col: col }
}

// ── Lexer ──────────────────────────────────────────────────
class Lexer {
    src: str
    pos: int
    line: int
    col: int

    fn peek(self, offset: int) -> str {
        let i = self.pos + offset
        if i < len(self.src) { return str_get(self.src, i) }
        return "\0"
    }

    fn advance(self) -> str {
        let ch: str = str_get(self.src, self.pos)
        self.pos = self.pos + 1
        if ch == "\n" { self.line = self.line + 1; self.col = 1 }
        else { self.col = self.col + 1 }
        return ch
    }

    fn skip_trivia(self) -> void {
        while self.pos < len(self.src) {
            let ch: str = self.peek(0)
            if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" {
                self.advance()
            } elif ch == "/" and self.peek(1) == "/" {
                while self.pos < len(self.src) and self.peek(0) != "\n" {
                    self.advance()
                }
            } elif ch == "/" and self.peek(1) == "*" {
                self.advance(); self.advance()
                while self.pos < len(self.src) {
                    if self.peek(0) == "*" and self.peek(1) == "/" {
                        self.advance(); self.advance(); break
                    }
                    self.advance()
                }
            } else { break }
        }
    }

    fn tokenize(self) -> List<Token> {
        let tokens: List<Token> = []
        while true {
            self.skip_trivia()
            if self.pos >= len(self.src) {
                push(tokens, make_token(TT_EOF, "", self.line, self.col))
                break
            }

            let line = self.line
            let col = self.col
            let ch: str = self.peek(0)

            // Numbers
            if is_digit(ch) {
                var num: str = ""
                var is_f = false
                while self.pos < len(self.src) {
                    let nc: str = self.peek(0)
                    if is_digit(nc) { num = num + self.advance(); continue }
                    if nc == "." {
                        if is_f or self.peek(1) == "." { break }
                        is_f = true
                        num = num + self.advance()
                        continue
                    }
                    break
                }
                if is_f { push(tokens, make_token(TT_FLOAT_LIT, num, line, col)) }
                else    { push(tokens, make_token(TT_INT_LIT,   num, line, col)) }
                continue
            }

            // Strings
            if ch == "\"" {
                self.advance()
                var s: str = ""
                while self.pos < len(self.src) and self.peek(0) != "\"" {
                    let c: str = self.advance()
                    if c == "\\" {
                        let esc: str = self.advance()
                        if esc == "n" { s = s + "\n" }
                        elif esc == "t" { s = s + "\t" }
                        elif esc == "\\" { s = s + "\\" }
                        elif esc == "\"" { s = s + "\"" }
                        elif esc == "r" { s = s + "\r" }
                        else { s = s + esc }
                    }
                    else { s = s + c }
                }
                if self.pos >= len(self.src) {
                    report_error(self.src, line, col, "Unterminated string")
                    exit(1)
                }
                self.advance()
                push(tokens, make_token(TT_STR_LIT, s, line, col))
                continue
            }

            // Identifiers & keywords
            if is_alpha(ch) or ch == "_" {
                var word: str = ""
                while self.pos < len(self.src) {
                    let nc: str = self.peek(0)
                    if is_alnum(nc) or nc == "_" { word = word + self.advance() }
                    else { break }
                }
                let kw: str = keyword_type(word)
                if kw != "" { push(tokens, make_token(kw, word, line, col)) }
                else        { push(tokens, make_token(TT_IDENT, word, line, col)) }
                continue
            }

            // Operators & delimiters
            self.advance()
            let nxt: str = self.peek(0)

            if ch == "-" {
                if nxt == ">" { self.advance(); push(tokens, make_token(TT_ARROW, "->", line, col))
                } elif nxt == "=" { self.advance(); push(tokens, make_token(TT_MINUS_ASSIGN, "-=", line, col))
                } else { push(tokens, make_token(TT_MINUS, "-", line, col)) }
            } elif ch == "=" {
                if nxt == "=" { self.advance(); push(tokens, make_token(TT_EQ, "==", line, col))
                } elif nxt == ">" { self.advance(); push(tokens, make_token(TT_FAT_ARROW, "=>", line, col))
                } else { push(tokens, make_token(TT_ASSIGN, "=", line, col)) }
            } elif ch == "!" {
                if nxt == "=" { self.advance(); push(tokens, make_token(TT_NEQ, "!=", line, col))
                } else { push(tokens, make_token(TT_BANG, "!", line, col)) }
            } elif ch == "<" {
                if nxt == "=" { self.advance(); push(tokens, make_token(TT_LEQ, "<=", line, col))
                } else { push(tokens, make_token(TT_LT, "<", line, col)) }
            } elif ch == ">" {
                if nxt == "=" { self.advance(); push(tokens, make_token(TT_GEQ, ">=", line, col))
                } else { push(tokens, make_token(TT_GT, ">", line, col)) }
            } elif ch == "+" {
                if nxt == "=" { self.advance(); push(tokens, make_token(TT_PLUS_ASSIGN, "+=", line, col))
                } else { push(tokens, make_token(TT_PLUS, "+", line, col)) }
            } elif ch == "*" {
                if nxt == "=" { self.advance(); push(tokens, make_token(TT_STAR_ASSIGN, "*=", line, col))
                } else { push(tokens, make_token(TT_STAR, "*", line, col)) }
            } elif ch == "/" {
                if nxt == "=" { self.advance(); push(tokens, make_token(TT_SLASH_ASSIGN, "/=", line, col))
                } else { push(tokens, make_token(TT_SLASH, "/", line, col)) }
            } elif ch == "." {
                if nxt == "." { self.advance(); push(tokens, make_token(TT_DOTDOT, "..", line, col))
                } else { push(tokens, make_token(TT_DOT, ".", line, col)) }
            } elif ch == "%"  { push(tokens, make_token(TT_PERCENT,  "%", line, col))
            } elif ch == "{"  { push(tokens, make_token(TT_LBRACE,   "{", line, col))
            } elif ch == "}"  { push(tokens, make_token(TT_RBRACE,   "}", line, col))
            } elif ch == "("  { push(tokens, make_token(TT_LPAREN,   "(", line, col))
            } elif ch == ")"  { push(tokens, make_token(TT_RPAREN,   ")", line, col))
            } elif ch == "["  { push(tokens, make_token(TT_LBRACKET, "[", line, col))
            } elif ch == "]"  { push(tokens, make_token(TT_RBRACKET, "]", line, col))
            } elif ch == ":"  { push(tokens, make_token(TT_COLON,    ":", line, col))
            } elif ch == ","  { push(tokens, make_token(TT_COMMA,    ",", line, col))
            } elif ch == ";"  { push(tokens, make_token(TT_SEMI,     ";", line, col))
            } elif ch == "?"  { push(tokens, make_token(TT_QUESTION, "?", line, col))
            } else {
                report_error(self.src, line, col, "Unknown character " + ch)
                exit(1)
            }
        }
        return tokens
    }
}

// ── Parser ──────────────────────────────────────────────────
class Parser {
    tokens: List<Token>
    pos: int
    src: str

    fn peek(self, offset: int) -> Token {
        let i = self.pos + offset
        if i < len(self.tokens) { return self.tokens[i] }
        return self.tokens[len(self.tokens) - 1]
    }

    fn check(self, type_names: List<str>) -> bool {
        let t = self.peek(0)
        var i = 0
        while i < len(type_names) {
            if t.type_name == type_names[i] { return true }
            i = i + 1
        }
        return false
    }

    fn advance(self) -> Token {
        let t = self.tokens[self.pos]
        if self.pos < len(self.tokens) - 1 { self.pos = self.pos + 1 }
        return t
    }

    fn expect(self, type_names: List<str>) -> Token {
        let t = self.peek(0)
        var found = false
        var i = 0
        while i < len(type_names) {
            if t.type_name == type_names[i] { found = true; break }
            i = i + 1
        }
        if not found {
            report_error(self.src, t.line, t.col,
                "Expected " + type_names[0] + ", got " + t.type_name + " (" + t.lexeme + ")")
            exit(1)
        }
        return self.advance()
    }

    fn match_tok(self, type_names: List<str>) -> Token {
        if self.check(type_names) { return self.advance() }
        return Token { type_name: "", lexeme: "", line: 0, col: 0 }
    }

    fn matched(self, tok: Token) -> bool { return tok.type_name != "" }

    fn skip_semis(self) -> void {
        while self.check([TT_SEMI]) { self.advance() }
    }

    // ── Top level ──
    fn parse(self) -> int {
        let stmts: List<int> = []
        while not self.check([TT_EOF]) {
            self.skip_semis()
            if self.check([TT_EOF]) { break }
            push(stmts, self.parse_top())
            self.skip_semis()
        }
        return node_program(stmts)
    }

    fn parse_top(self) -> int {
        var has_pub = false
        let pub_tok = self.match_tok([TT_PUB])
        if pub_tok.type_name != "" { has_pub = true }

        var has_lazy = false
        let lazy_tok = self.match_tok([TT_LAZY])
        if lazy_tok.type_name != "" { has_lazy = true }

        if self.check([TT_FN])    { return self.parse_fn(has_pub, has_lazy) }
        if self.check([TT_CLASS]) { return self.parse_class() }
        if self.check([TT_IMPORT]){ return self.parse_import() }
        if self.check([TT_LET, TT_VAR]) { return self.parse_var_decl() }

        let t = self.peek(0)
        report_error(self.src, t.line, t.col, "Unexpected token " + t.type_name + " at top level")
        exit(1)
        return -1
    }

    fn parse_import(self) -> int {
        self.expect([TT_IMPORT])
        let path: List<int> = [node_str_id(self.expect([TT_IDENT]).lexeme)]
        while self.matched(self.match_tok([TT_DOT])) {
            push(path, node_str_id(self.expect([TT_IDENT]).lexeme))
        }
        return node_import(path)
    }

    fn parse_generics(self) -> List<int> {
        let gs: List<int> = []
        if self.matched(self.match_tok([TT_LT])) {
            while not self.check([TT_GT]) {
                push(gs, node_str_id(self.expect([TT_IDENT]).lexeme))
                if not self.matched(self.match_tok([TT_COMMA])) { break }
            }
            self.expect([TT_GT])
        }
        return gs
    }

    fn parse_fn(self, is_pub: bool, is_lazy: bool) -> int {
        self.expect([TT_FN])
        let name: str = self.expect([TT_IDENT]).lexeme
        let generics: List<int> = self.parse_generics()
        self.expect([TT_LPAREN])
        let params: List<int> = []
        var has_self = false

        if not self.check([TT_RPAREN]) {
            let fp = self.peek(0)
            if fp.lexeme == "self" and fp.type_name == TT_IDENT {
                has_self = true; self.advance()
                self.match_tok([TT_COMMA])
            }
            while not self.check([TT_RPAREN, TT_EOF]) {
                let pname: str = self.expect([TT_IDENT]).lexeme
                self.expect([TT_COLON])
                let ptype: str = self.parse_type()
                push(params, node_param(pname, ptype))
                if not self.matched(self.match_tok([TT_COMMA])) { break }
            }
        }
        self.expect([TT_RPAREN])
        var ret: str = "void"
        if self.matched(self.match_tok([TT_ARROW])) { ret = self.parse_type() }
        let body: List<int> = self.parse_block()
        return node_fn_def(name, params, ret, body, is_pub, is_lazy, generics, has_self)
    }

    fn parse_class(self) -> int {
        self.expect([TT_CLASS])
        let name: str = self.expect([TT_IDENT]).lexeme
        let generics: List<int> = self.parse_generics()
        self.expect([TT_LBRACE])
        let fields: List<int> = []
        let methods: List<int> = []
        while not self.check([TT_RBRACE, TT_EOF]) {
            self.skip_semis()
            if self.check([TT_RBRACE]) { break }
            var has_pub = false
            let pt = self.match_tok([TT_PUB])
            if pt.type_name != "" { has_pub = true }
            var has_lazy = false
            let lt = self.match_tok([TT_LAZY])
            if lt.type_name != "" { has_lazy = true }
            if self.check([TT_FN]) {
                push(methods, self.parse_fn(has_pub, has_lazy))
            } else {
                let fname: str = self.expect([TT_IDENT]).lexeme
                self.expect([TT_COLON])
                let ftype: str = self.parse_type()
                push(fields, node_param(fname, ftype))
                self.skip_semis()
            }
        }
        self.expect([TT_RBRACE])
        return node_class_def(name, fields, methods, generics)
    }

    fn parse_type(self) -> str {
        let t = self.peek(0)
        if t.type_name == TT_T_INT   { self.advance(); return "int" }
        if t.type_name == TT_T_FLOAT { self.advance(); return "float" }
        if t.type_name == TT_T_BOOL  { self.advance(); return "bool" }
        if t.type_name == TT_T_STR   { self.advance(); return "str" }
        if t.type_name == TT_T_VOID  { self.advance(); return "void" }
        if t.type_name == TT_IDENT {
            let name: str = self.advance().lexeme
            if self.matched(self.match_tok([TT_LT])) {
                let args: List<str> = []
                while not self.check([TT_GT]) {
                    push(args, self.parse_type())
                    if not self.matched(self.match_tok([TT_COMMA])) { break }
                }
                self.expect([TT_GT])
                var result: str = name + "<"
                var i = 0
                while i < len(args) {
                    if i > 0 { result = result + ", " }
                    result = result + args[i]
                    i = i + 1
                }
                result = result + ">"
                return result
            }
            return name
        }
        report_error(self.src, t.line, t.col, "Expected type")
        exit(1)
        return ""
    }

    fn parse_block(self) -> List<int> {
        self.expect([TT_LBRACE])
        let stmts: List<int> = []
        while not self.check([TT_RBRACE, TT_EOF]) {
            self.skip_semis()
            if self.check([TT_RBRACE]) { break }
            push(stmts, self.parse_stmt())
            self.skip_semis()
        }
        self.expect([TT_RBRACE])
        return stmts
    }

    // ── Statements ──
    fn parse_stmt(self) -> int {
        if self.check([TT_LET, TT_VAR])   { return self.parse_var_decl() }
        if self.check([TT_RETURN])         { return self.parse_return() }
        if self.check([TT_IF])             { return self.parse_if() }
        if self.check([TT_FOR])            { return self.parse_for() }
        if self.check([TT_WHILE])          { return self.parse_while() }
        if self.check([TT_MATCH])          { return self.parse_match() }
        if self.check([TT_FN])             { return self.parse_fn(false, false) }
        if self.check([TT_BREAK])          { self.advance(); return node_break() }
        if self.check([TT_CONTINUE])       { self.advance(); return node_continue() }
        let expr: int = self.parse_expr()
        if self.check([TT_ASSIGN, TT_PLUS_ASSIGN, TT_MINUS_ASSIGN,
                       TT_STAR_ASSIGN, TT_SLASH_ASSIGN]) {
            let op: str = self.advance().lexeme
            let rhs: int = self.parse_expr()
            return node_assign(expr, rhs, op)
        }
        return node_expr_stmt(expr)
    }

    fn parse_var_decl(self) -> int {
        let is_mut: bool = self.advance().type_name == TT_VAR
        let name: str = self.expect([TT_IDENT]).lexeme
        var type_ann: str = ""
        if self.matched(self.match_tok([TT_COLON])) { type_ann = self.parse_type() }
        self.expect([TT_ASSIGN])
        let value: int = self.parse_expr()
        return node_var_decl(name, type_ann, value, is_mut)
    }

    fn parse_return(self) -> int {
        self.expect([TT_RETURN])
        if self.check([TT_RBRACE, TT_SEMI, TT_EOF]) { return node_return(-1) }
        return node_return(self.parse_expr())
    }

    fn parse_if(self) -> int {
        self.expect([TT_IF])
        let cond: int = self.parse_expr()
        let then_body: List<int> = self.parse_block()
        let elifs: List<int> = []
        var else_body: List<int> = []
        while self.check([TT_ELIF]) {
            self.advance()
            let ec: int = self.parse_expr()
            let eb: List<int> = self.parse_block()
            push(elifs, node_elif(ec, eb))
        }
        if self.matched(self.match_tok([TT_ELSE])) { else_body = self.parse_block() }
        return node_if(cond, then_body, elifs, else_body)
    }

    fn parse_for(self) -> int {
        self.expect([TT_FOR])
        let var_name: str = self.expect([TT_IDENT]).lexeme
        self.expect([TT_IN])
        let iterable: int = self.parse_expr()
        let body: List<int> = self.parse_block()
        return node_for(var_name, iterable, body)
    }

    fn parse_while(self) -> int {
        self.expect([TT_WHILE])
        let cond: int = self.parse_expr()
        let body: List<int> = self.parse_block()
        return node_while(cond, body)
    }

    fn parse_match(self) -> int {
        self.expect([TT_MATCH])
        let subject: int = self.parse_expr()
        self.expect([TT_LBRACE])
        let arms: List<int> = []
        while not self.check([TT_RBRACE, TT_EOF]) {
            self.skip_semis()
            if self.check([TT_RBRACE]) { break }
            let pat: int = self.parse_pattern()
            self.expect([TT_FAT_ARROW])
            var body: List<int> = []
            if self.check([TT_LBRACE]) { body = self.parse_block() }
            else { push(body, self.parse_stmt()) }
            push(arms, node_arm(pat, body))
            self.skip_semis()
        }
        self.expect([TT_RBRACE])
        return node_match(subject, arms)
    }

    fn parse_pattern(self) -> int {
        if self.check([TT_UNDERSCORE]) { self.advance(); return node_wild() }
        let expr: int = self.parse_primary()
        if self.matched(self.match_tok([TT_DOTDOT])) {
            let end: int = self.parse_primary()
            return node_range_lit(expr, end)
        }
        return expr
    }

    // ── Expressions ──
    fn parse_expr(self) -> int {
        let expr: int = self.parse_or()
        if self.matched(self.match_tok([TT_DOTDOT])) {
            let end: int = self.parse_or()
            return node_range_lit(expr, end)
        }
        return expr
    }

    fn parse_or(self) -> int {
        var left: int = self.parse_and()
        while self.check([TT_OR]) {
            let op: str = self.advance().lexeme
            let right: int = self.parse_and()
            left = node_bin_op(op, left, right)
        }
        return left
    }

    fn parse_and(self) -> int {
        var left: int = self.parse_compare()
        while self.check([TT_AND]) {
            let op: str = self.advance().lexeme
            let right: int = self.parse_compare()
            left = node_bin_op(op, left, right)
        }
        return left
    }

    fn parse_compare(self) -> int {
        var left: int = self.parse_add()
        while self.check([TT_EQ, TT_NEQ, TT_LT, TT_GT, TT_LEQ, TT_GEQ]) {
            let op: str = self.advance().lexeme
            let right: int = self.parse_add()
            left = node_bin_op(op, left, right)
        }
        return left
    }

    fn parse_add(self) -> int {
        var left: int = self.parse_mul()
        while self.check([TT_PLUS, TT_MINUS]) {
            let op: str = self.advance().lexeme
            let right: int = self.parse_mul()
            left = node_bin_op(op, left, right)
        }
        return left
    }

    fn parse_mul(self) -> int {
        var left: int = self.parse_unary()
        while self.check([TT_STAR, TT_SLASH, TT_PERCENT]) {
            let op: str = self.advance().lexeme
            let right: int = self.parse_unary()
            left = node_bin_op(op, left, right)
        }
        return left
    }

    fn parse_unary(self) -> int {
        if self.check([TT_MINUS]) { self.advance(); return node_unary_op("-", self.parse_unary()) }
        if self.check([TT_NOT])   { self.advance(); return node_unary_op("!", self.parse_unary()) }
        if self.check([TT_BANG])  { self.advance(); return node_unary_op("!", self.parse_unary()) }
        return self.parse_postfix()
    }

    fn parse_postfix(self) -> int {
        var expr: int = self.parse_primary()
        while true {
            if self.check([TT_DOT]) {
                self.advance()
                let name: str = self.expect([TT_IDENT]).lexeme
                // Generic type args on method call: obj.method<Type>(args)
                if self.check([TT_LT]) {
                    let saved = self.pos; self.advance()
                    let next_t = self.peek(0)
                    let type_kw = next_t.type_name == TT_T_INT or next_t.type_name == TT_T_FLOAT or
                                  next_t.type_name == TT_T_BOOL or next_t.type_name == TT_T_STR or
                                  next_t.type_name == TT_T_VOID
                    let caps = next_t.type_name == TT_IDENT and len(next_t.lexeme) > 0
                    if caps {
                        let ch: str = str_get(next_t.lexeme, 0)
                        let uc: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                        caps = false
                        var ui = 0
                        while ui < len(uc) {
                            if ch == str_get(uc, ui) { caps = true; break }
                            ui = ui + 1
                        }
                    }
                    if type_kw or caps {
                        let args: List<str> = []
                        while not self.check([TT_GT]) {
                            push(args, self.parse_type())
                            if not self.matched(self.match_tok([TT_COMMA])) { break }
                        }
                        self.expect([TT_GT])
                        name = name + "<" + args[0]
                        var i = 1
                        while i < len(args) {
                            name = name + ", " + args[i]
                            i = i + 1
                        }
                        name = name + ">"
                    } else {
                        self.pos = saved
                    }
                }
                if self.check([TT_LPAREN]) {
                    self.advance()
                    let args: List<int> = []
                    while not self.check([TT_RPAREN, TT_EOF]) {
                        push(args, self.parse_expr())
                        if not self.matched(self.match_tok([TT_COMMA])) { break }
                    }
                    self.expect([TT_RPAREN])
                    expr = node_method_call(expr, name, args)
                } else {
                    expr = node_attr(expr, name)
                }
            } elif self.check([TT_LPAREN]) {
                self.advance()
                let args: List<int> = []
                while not self.check([TT_RPAREN, TT_EOF]) {
                    push(args, self.parse_expr())
                    if not self.matched(self.match_tok([TT_COMMA])) { break }
                }
                self.expect([TT_RPAREN])
                expr = node_fn_call(expr, args)
            } elif self.check([TT_LBRACKET]) {
                self.advance()
                let idx: int = self.parse_expr()
                self.expect([TT_RBRACKET])
                expr = node_index(expr, idx)
            } elif self.check([TT_QUESTION]) {
                self.advance()
                expr = node_try_op(expr)
            } else { break }
        }
        return expr
    }

    fn parse_primary(self) -> int {
        let t = self.peek(0)
        if t.type_name == TT_INT_LIT   { self.advance(); return node_int_lit(to_int(t.lexeme)) }
        if t.type_name == TT_FLOAT_LIT { self.advance(); return node_float_lit(to_float(t.lexeme)) }
        if t.type_name == TT_STR_LIT   { self.advance(); return node_str_lit(t.lexeme) }
        if t.type_name == TT_TRUE      { self.advance(); return node_bool_lit(true) }
        if t.type_name == TT_FALSE     { self.advance(); return node_bool_lit(false) }
        if t.type_name == TT_NONE_KW   { self.advance(); return node_none_lit() }
        if t.type_name == TT_SOME_KW {
            self.advance(); self.expect([TT_LPAREN])
            let v: int = self.parse_expr(); self.expect([TT_RPAREN])
            return node_some_lit(v)
        }
        if t.type_name == TT_UNDERSCORE { self.advance(); return node_wild() }
        if t.type_name == TT_LBRACKET {
            self.advance(); let elems: List<int> = []
            while not self.check([TT_RBRACKET, TT_EOF]) {
                push(elems, self.parse_expr())
                if not self.matched(self.match_tok([TT_COMMA])) { break }
            }
            self.expect([TT_RBRACKET]); return node_list_lit(elems)
        }
        if t.type_name == TT_LPAREN {
            self.advance(); let expr: int = self.parse_expr()
            self.expect([TT_RPAREN]); return expr
        }

        // Identifier or struct literal
        if t.type_name == TT_IDENT {
            let name: str = self.advance().lexeme
            // Generic type arguments on calls/constructors: Ident<Type, ...>
            if self.check([TT_LT]) {
                let saved = self.pos; self.advance()
                let next_t = self.peek(0)
                let type_kw = next_t.type_name == TT_T_INT or next_t.type_name == TT_T_FLOAT or
                              next_t.type_name == TT_T_BOOL or next_t.type_name == TT_T_STR or
                              next_t.type_name == TT_T_VOID
                let caps = next_t.type_name == TT_IDENT and len(next_t.lexeme) > 0
                if caps {
                    let ch: str = str_get(next_t.lexeme, 0)
                    let uc: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                    caps = false
                    var ui = 0
                    while ui < len(uc) {
                        if ch == str_get(uc, ui) { caps = true; break }
                        ui = ui + 1
                    }
                }
                if type_kw or caps {
                    let args: List<str> = []
                    while not self.check([TT_GT]) {
                        push(args, self.parse_type())
                        if not self.matched(self.match_tok([TT_COMMA])) { break }
                    }
                    self.expect([TT_GT])
                    var full_name: str = name + "<" + args[0]
                    var i = 1
                    while i < len(args) {
                        full_name = full_name + ", " + args[i]
                        i = i + 1
                    }
                    full_name = full_name + ">"
                    if self.check([TT_LBRACE]) {
                        let saved2 = self.pos; self.advance()
                        if self.check([TT_IDENT]) and self.peek(1).type_name == TT_COLON {
                            let flds: List<int> = []
                            while not self.check([TT_RBRACE, TT_EOF]) {
                                let fn_name: str = self.expect([TT_IDENT]).lexeme
                                self.expect([TT_COLON])
                                let fv: int = self.parse_expr()
                                push(flds, node_field(fn_name, fv))
                                if not self.matched(self.match_tok([TT_COMMA])) { break }
                            }
                            self.expect([TT_RBRACE])
                            return node_struct_lit(full_name, flds)
                        }
                        self.pos = saved2
                    }
                    return node_ident(full_name)
                }
                self.pos = saved
            }
            if self.check([TT_LBRACE]) {
                let saved = self.pos; self.advance()
                if self.check([TT_IDENT]) and self.peek(1).type_name == TT_COLON {
                    let flds: List<int> = []
                    while not self.check([TT_RBRACE, TT_EOF]) {
                        let fn_name: str = self.expect([TT_IDENT]).lexeme
                        self.expect([TT_COLON])
                        let fv: int = self.parse_expr()
                        push(flds, node_field(fn_name, fv))
                        if not self.matched(self.match_tok([TT_COMMA])) { break }
                    }
                    self.expect([TT_RBRACE])
                    return node_struct_lit(name, flds)
                } else {
                    self.pos = saved
                }
            }
            return node_ident(name)
        }

        // Allow type keywords as identifiers
        if t.type_name == TT_T_INT or t.type_name == TT_T_FLOAT or
           t.type_name == TT_T_BOOL or t.type_name == TT_T_STR or
           t.type_name == TT_T_VOID {
            self.advance(); return node_ident(t.lexeme)
        }

        report_error(self.src, t.line, t.col, "Unexpected token " + t.type_name + " in expression")
        exit(1)
        return -1
    }
}

// ── Type mapping helpers ───────────────────────────────────
fn split_args(s: str) -> List<str> {
    let result: List<str> = []
    var cur: str = ""
    var depth = 0
    var i = 0
    while i < len(s) {
        let c: str = str_get(s, i)
        if c == "<" { depth = depth + 1 }
        elif c == ">" { depth = depth - 1 }
        if c == "," and depth == 0 {
            push(result, cur)
            cur = ""
        } else { cur = cur + c }
        i = i + 1
    }
    if cur != "" { push(result, cur) }
    return result
}

fn map_type(t: str) -> str {
    if t == "int"   { return "int" }
    if t == "float" { return "double" }
    if t == "bool"  { return "bool" }
    if t == "str"   { return "std::string" }
    if t == "void"  { return "void" }
    if t == "Option" or t == "List" or t == "Map" or t == "Result" { return t }
    var i = 0
    while i < len(t) {
        if str_get(t, i) == "<" {
            let outer: str = str_sub(t, 0, i)
            let inner_start = i + 1
            let inner_end = len(t) - 1
            let args: List<str> = split_args(str_sub(t, inner_start, inner_end))
            var mapped: str = map_type(outer) + "<"
            var j = 0
            while j < len(args) {
                if j > 0 { mapped = mapped + ", " }
                mapped = mapped + map_type(args[j])
                j = j + 1
            }
            mapped = mapped + ">"
            return mapped
        }
        i = i + 1
    }
    return t
}

// ── CodeGen ─────────────────────────────────────────────────
class CodeGen {
    out: List<str>
    depth: int
    in_class: str
    tmp_counter: int
    modules: List<str>

    fn w(self, line: str) -> void {
        var indent: str = ""
        var i = 0
        while i < self.depth {
            indent = indent + "    "
            i = i + 1
        }
        push(self.out, indent + line)
    }

    fn tmp_name(self) -> str {
        self.tmp_counter = self.tmp_counter + 1
        return "_ox_" + str(self.tmp_counter)
    }

    fn expr(self, node_id: int) -> str {
        let node = node_pool[node_id]
        if node.kind == "IntLit"    { return str(node.int_val) }
        if node.kind == "FloatLit" {
            let s: str = str(node.float_val)
            var has_dot = false; var i = 0
            while i < len(s) {
                let c: str = str_get(s, i)
                if c == "." or c == "e" { has_dot = true; break }
                i = i + 1
            }
            if has_dot { return s }
            return s + ".0"
        }
        if node.kind == "StrLit" {
            var esc: str = ""
            var i = 0
            while i < len(node.str_val) {
                let c: str = str_get(node.str_val, i)
                if c == "\\" { esc = esc + "\\\\" }
                elif c == "\"" { esc = esc + "\\\"" }
                elif c == "\n" { esc = esc + "\\n" }
                elif c == "\t" { esc = esc + "\\t" }
                elif c == "\r" { esc = esc + "\\r" }
                else { esc = esc + c }
                i = i + 1
            }
            return "\"" + esc + "\""
        }
        if node.kind == "BoolLit" {
            if node.bool_val { return "true" }
            return "false"
        }
        if node.kind == "NoneLit"  { return "std::nullopt" }
        if node.kind == "SomeLit"  { return "Some(" + self.expr(node.inner) + ")" }
        if node.kind == "TryOp"    { return "_ox_try(" + self.expr(node.operand) + ")" }
        if node.kind == "WildCard" { return "_" }
        if node.kind == "Ident" {
            if node.name == "self" and self.in_class != "" { return "(*this)" }
            if str_contains(node.name, "<") { return map_type(node.name) }
            return node.name
        }
        if node.kind == "BinOp" {
            var op: str = node.op
            if op == "and" { op = "&&" }
            if op == "or"  { op = "||" }
            return "(" + self.expr(node.left) + " " + op + " " + self.expr(node.right) + ")"
        }
        if node.kind == "UnaryOp" {
            return "(" + node.op + self.expr(node.operand) + ")"
        }
        if node.kind == "FnCall" {
            let func_node = node_pool[node.func]
            var fn_name: str = self.expr(node.func)
            if func_node.kind == "Ident" and str_contains(func_node.name, "<") {
                fn_name = map_type(func_node.name)
            }
            if func_node.kind == "Ident" and func_node.name == "Ok" {
                return "Ok(" + self.expr(node.args[0]) + ")"
            }
            if func_node.kind == "Ident" and func_node.name == "Err" {
                return "Err(" + self.expr(node.args[0]) + ")"
            }
            var as: str = ""
            var i = 0
            while i < len(node.args) {
                if i > 0 { as = as + ", " }
                as = as + self.expr(node.args[i])
                i = i + 1
            }
            return fn_name + "(" + as + ")"
        }
        if node.kind == "MethodCall" {
            let obj_str: str = self.expr(node.obj)
            var as: str = ""
            var i = 0
            while i < len(node.args) {
                if i > 0 { as = as + ", " }
                as = as + self.expr(node.args[i])
                i = i + 1
            }
            // Module function call: json.escape(s) → _oxm_json::escape(s)
            var is_mod = false; var mi = 0
            while mi < len(self.modules) {
                if self.modules[mi] == obj_str { is_mod = true; break }
                mi = mi + 1
            }
            var mname: str = node.name
            if str_contains(node.name, "<") { mname = map_type(node.name) }
            if is_mod {
                return "_oxm_" + obj_str + "::" + mname + "(" + as + ")"
            }
            // Built-in list chaining methods
            if node.name == "map" or node.name == "filter" or node.name == "reduce" or node.name == "for_each" or node.name == "each" or node.name == "any" or node.name == "all" or node.name == "find" or node.name == "sum" or node.name == "min" or node.name == "max" {
                if as != "" { return "_ox_" + node.name + "(" + obj_str + ", " + as + ")" }
                return "_ox_" + node.name + "(" + obj_str + ")"
            }
            return obj_str + "." + mname + "(" + as + ")"
        }
        if node.kind == "Attr" {
            // .value → _ox_value(obj)   (works for Option, Result, and struct fields)
            if node.name == "value" {
                let obj_node = node_pool[node.obj]
                if obj_node.kind == "Ident" or obj_node.kind == "FnCall" or obj_node.kind == "MethodCall" {
                    return "_ox_value(" + self.expr(node.obj) + ")"
                }
            }
            return self.expr(node.obj) + "." + node.name
        }
        if node.kind == "Index" {
            return self.expr(node.obj) + "[" + self.expr(node.start) + "]"
        }
        if node.kind == "ListLit" {
            var es: str = ""
            var i = 0
            while i < len(node.elems) {
                if i > 0 { es = es + ", " }
                es = es + self.expr(node.elems[i])
                i = i + 1
            }
            return "{" + es + "}"
        }
        if node.kind == "StructLit" {
            var fs: str = ""
            var i = 0
            while i < len(node.fields) {
                if i > 0 { fs = fs + ", " }
                let f = node_pool[node.fields[i]]
                fs = fs + "." + f.name + "=" + self.expr(f.inner)
                i = i + 1
            }
            return node.type_name + "{" + fs + "}"
        }
        if node.kind == "RangeLit" {
            return "range(" + self.expr(node.start) + ", " + self.expr(node.end) + ")"
        }
        if node.kind == "StrId" {
            return "\"" + node.str_val + "\""
        }
        return "/* ? " + node.kind + " */"
    }

    fn gen_stmt(self, node_id: int) -> void {
        let node = node_pool[node_id]
        if node.kind == "VarDecl"       { self.gen_var_decl(node_id) }
        elif node.kind == "Assignment"  { self.gen_assign(node_id) }
        elif node.kind == "ReturnStmt" {
            if node.inner == -1 { self.w("return;") }
            else { self.w("return " + self.expr(node.inner) + ";") }
        }
        elif node.kind == "BreakStmt"    { self.w("break;") }
        elif node.kind == "ContinueStmt" { self.w("continue;") }
        elif node.kind == "IfStmt"       { self.gen_if(node_id) }
        elif node.kind == "ForStmt"      { self.gen_for(node_id) }
        elif node.kind == "WhileStmt"    { self.gen_while(node_id) }
        elif node.kind == "MatchStmt"    { self.gen_match(node_id) }
        elif node.kind == "ExprStmt"     { self.w(self.expr(node.inner) + ";") }
        elif node.kind == "FnDef"        { self.gen_fn(node_id) }
        else { self.w("/* unhandled " + node.kind + " */") }
    }

    fn gen_var_decl(self, node_id: int) -> void {
        let node = node_pool[node_id]
        let val: str = self.expr(node.inner)
        if node.type_ann != "" {
            self.w(map_type(node.type_ann) + " " + node.name + " = " + val + ";")
        } else {
            self.w("auto " + node.name + " = " + val + ";")
        }
    }

    fn gen_assign(self, node_id: int) -> void {
        let node = node_pool[node_id]
        self.w(self.expr(node.target) + " " + node.op + " " + self.expr(node.inner) + ";")
    }

    fn gen_if(self, node_id: int) -> void {
        let node = node_pool[node_id]
        self.w("if (" + self.expr(node.cond) + ") {")
        self.depth = self.depth + 1
        var i = 0
        while i < len(node.then_body) { self.gen_stmt(node.then_body[i]); i = i + 1 }
        self.depth = self.depth - 1
        self.w("}")
        var j = 0
        while j < len(node.elif_clauses) {
            let ec = node_pool[node.elif_clauses[j]]
            self.w("else if (" + self.expr(ec.cond) + ") {")
            self.depth = self.depth + 1
            var k = 0
            while k < len(ec.body) { self.gen_stmt(ec.body[k]); k = k + 1 }
            self.depth = self.depth - 1
            self.w("}")
            j = j + 1
        }
        if len(node.else_body) > 0 {
            self.w("else {")
            self.depth = self.depth + 1
            var k = 0
            while k < len(node.else_body) { self.gen_stmt(node.else_body[k]); k = k + 1 }
            self.depth = self.depth - 1
            self.w("}")
        }
    }

    fn gen_for(self, node_id: int) -> void {
        let node = node_pool[node_id]
        let it = node_pool[node.iterable]
        if it.kind == "RangeLit" {
            let s: str = self.expr(it.start)
            let e: str = self.expr(it.end)
            self.w("for (int " + node.var_name + " = " + s + "; " +
                   node.var_name + " < " + e + "; ++" + node.var_name + ") {")
        } else {
            self.w("for (auto& " + node.var_name + " : " + self.expr(node.iterable) + ") {")
        }
        self.depth = self.depth + 1
        var i = 0
        while i < len(node.body) { self.gen_stmt(node.body[i]); i = i + 1 }
        self.depth = self.depth - 1
        self.w("}")
    }

    fn gen_while(self, node_id: int) -> void {
        let node = node_pool[node_id]
        self.w("while (" + self.expr(node.cond) + ") {")
        self.depth = self.depth + 1
        var i = 0
        while i < len(node.body) { self.gen_stmt(node.body[i]); i = i + 1 }
        self.depth = self.depth - 1
        self.w("}")
    }

    fn gen_match(self, node_id: int) -> void {
        let node = node_pool[node_id]
        let sv: str = self.tmp_name()
        self.w("auto " + sv + " = " + self.expr(node.subject) + ";")
        var first = true
        var i = 0
        while i < len(node.arms) {
            let arm = node_pool[node.arms[i]]
            let pat_id = arm.left
            let pat = node_pool[pat_id]
            let body: List<int> = arm.body
            if pat.kind == "WildCard" {
                if first { self.w("{") } else { self.w("else {") }
            } elif pat.kind == "RangeLit" {
                let s: str = self.expr(pat.start)
                let e: str = self.expr(pat.end)
                if first { self.w("if (" + sv + " >= " + s + " && " + sv + " < " + e + ") {") }
                else { self.w("else if (" + sv + " >= " + s + " && " + sv + " < " + e + ") {") }
            } else {
                let pv: str = self.expr(pat_id)
                if first { self.w("if (" + sv + " == " + pv + ") {") }
                else { self.w("else if (" + sv + " == " + pv + ") {") }
            }
            first = false
            self.depth = self.depth + 1
            var j = 0
            while j < len(body) { self.gen_stmt(body[j]); j = j + 1 }
            self.depth = self.depth - 1
            self.w("}")
            i = i + 1
        }
    }

    fn gen_fn(self, node_id: int) -> void {
        let node = node_pool[node_id]
        if len(node.generics) > 0 {
            var tmpl: str = "template<"
            var i = 0
            while i < len(node.generics) {
                if i > 0 { tmpl = tmpl + ", " }
                tmpl = tmpl + "typename " + node_pool[node.generics[i]].str_val
                i = i + 1
            }
            tmpl = tmpl + ">"
            self.w(tmpl)
        }
        var ps: str = ""
        var i = 0
        while i < len(node.params) {
            if i > 0 { ps = ps + ", " }
            let p = node_pool[node.params[i]]
            ps = ps + map_type(p.return_type) + " " + p.name
            i = i + 1
        }
        if node.name == "main" {
            self.w("int main(int argc, char* argv[]) {")
            self.depth = self.depth + 1
            self.w("_ox_argc = argc; _ox_argv = argv;")
            self.w("#ifdef _WIN32")
            self.w("SetConsoleOutputCP(CP_UTF8);")
            self.w("#endif")
            var j = 0
            while j < len(node.body) { self.gen_stmt(node.body[j]); j = j + 1 }
            self.w("return 0;")
        } else {
            let ret: str = map_type(node.return_type)
            self.w(ret + " " + node.name + "(" + ps + ") {")
            self.depth = self.depth + 1
            var j = 0
            while j < len(node.body) { self.gen_stmt(node.body[j]); j = j + 1 }
        }
        self.depth = self.depth - 1
        self.w("}")
        self.w("")
    }

    fn gen_class(self, node_id: int) -> void {
        let node = node_pool[node_id]
        if len(node.generics) > 0 {
            var tmpl: str = "template<"
            var i = 0
            while i < len(node.generics) {
                if i > 0 { tmpl = tmpl + ", " }
                tmpl = tmpl + "typename " + node_pool[node.generics[i]].str_val
                i = i + 1
            }
            tmpl = tmpl + ">"
            self.w(tmpl)
        }
        self.w("struct " + node.name + " {")
        self.depth = self.depth + 1
        var i = 0
        while i < len(node.fields) {
            let f = node_pool[node.fields[i]]
            self.w(map_type(f.return_type) + " " + f.name + ";")
            i = i + 1
        }
        if len(node.fields) > 0 and len(node.methods) > 0 { self.w("") }
        let old: str = self.in_class
        self.in_class = node.name
        var j = 0
        while j < len(node.methods) { self.gen_method(node.methods[j]); j = j + 1 }
        self.in_class = old
        self.depth = self.depth - 1
        self.w("};")
        self.w("")
    }

    fn gen_method(self, node_id: int) -> void {
        let node = node_pool[node_id]
        var ps: str = ""
        var i = 0
        while i < len(node.params) {
            if i > 0 { ps = ps + ", " }
            let p = node_pool[node.params[i]]
            ps = ps + map_type(p.return_type) + " " + p.name
            i = i + 1
        }
        self.w(map_type(node.return_type) + " " + node.name + "(" + ps + ") {")
        self.depth = self.depth + 1
        var j = 0
        while j < len(node.body) { self.gen_stmt(node.body[j]); j = j + 1 }
        self.depth = self.depth - 1
        self.w("}")
        self.w("")
    }

    fn gen_top(self, node_id: int) -> void {
        let node = node_pool[node_id]
        if node.kind == "ClassDef"   { self.gen_class(node_id) }
        elif node.kind == "FnDef"    { self.gen_fn(node_id) }
        elif node.kind == "ImportStmt" {
            var p: str = ""
            var i = 0
            while i < len(node.path) {
                if i > 0 { p = p + "." }
                p = p + node_pool[node.path[i]].str_val
                i = i + 1
            }
            self.w("// import " + p)
        }
        elif node.kind == "VarDecl"  { self.gen_var_decl(node_id); self.w("") }
        else { self.gen_stmt(node_id) }
    }

    fn generate(self, prog_id: int) -> str {
        return self._generate(prog_id, "", true)
    }

    fn generate_module(self, prog_id: int, mod_name: str) -> str {
        return self._generate(prog_id, "_oxm_" + mod_name, false)
    }

    fn _generate(self, prog_id: int, ns: str, include_runtime: bool) -> str {
        let prog = node_pool[prog_id]
        if include_runtime {
            self.w("// ── Generated by Oxybelis ───────────────────────────────────────────────────")
            self.w("#include <iostream>")
            self.w("#include <string>")
            self.w("#include <vector>")
            self.w("#include <optional>")
            self.w("#include <unordered_map>")
            self.w("#include <functional>")
            self.w("#include <algorithm>")
            self.w("#include <cmath>")
            self.w("#include <stdexcept>")
            self.w("#include <sstream>")
            self.w("#include <fstream>")
            self.w("#include <cstdlib>")
            self.w("#include <cctype>")
            self.w("#include <filesystem>")
            self.w("#ifdef _WIN32")
            self.w("#include <windows.h>")
            self.w("#endif")
            self.w("")
            self.w("// ── Oxybelis stdlib types ───")
            self.w("template<typename T> using List = std::vector<T>;")
            self.w("template<typename K,typename V> using Map = std::unordered_map<K,V>;")
            self.w("template<typename T> using Option = std::optional<T>;")
            self.w("")
            self.w("template<typename T> Option<T> Some(T val) { return std::optional<T>(val); }")
            self.w("inline constexpr std::nullopt_t None = std::nullopt;")
            self.w("")
            self.w("// ── Result type ───")
            self.w("template<typename T, typename E>")
            self.w("struct Result {")
            self.depth = self.depth + 1
            self.w("bool is_ok;")
            self.w("T value;")
            self.w("E error;")
            self.depth = self.depth - 1
            self.w("};")
            self.w("template<typename T>")
            self.w("struct _ox_OkHelper {")
            self.depth = self.depth + 1
            self.w("T val;")
            self.w("_ox_OkHelper(const T& v) : val(v) {}")
            self.w("template<typename E> operator Result<T, E>() const {")
            self.depth = self.depth + 1
            self.w("Result<T, E> r; r.is_ok = true; r.value = val; return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.depth = self.depth - 1
            self.w("};")
            self.w("template<typename T, typename = std::enable_if_t<!std::is_array_v<T>>>")
            self.w("_ox_OkHelper<T> Ok(const T& v) { return _ox_OkHelper<T>(v); }")
            self.w("inline _ox_OkHelper<std::string> Ok(const char* v) { return _ox_OkHelper<std::string>(v); }")
            self.w("template<typename E>")
            self.w("struct _ox_ErrHelper {")
            self.depth = self.depth + 1
            self.w("E error;")
            self.w("_ox_ErrHelper(const E& e) : error(e) {}")
            self.w("template<typename T> operator Result<T, E>() const {")
            self.depth = self.depth + 1
            self.w("Result<T, E> r; r.is_ok = false; r.error = error; return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.depth = self.depth - 1
            self.w("};")
            self.w("template<typename E, typename = std::enable_if_t<!std::is_array_v<E>>>")
            self.w("_ox_ErrHelper<E> Err(const E& e) { return _ox_ErrHelper<E>(e); }")
            self.w("inline _ox_ErrHelper<std::string> Err(const char* e) { return _ox_ErrHelper<std::string>(e); }")
            self.w("template<typename T, typename E>")
            self.w("T _ox_try(const Result<T, E>& r) {")
            self.depth = self.depth + 1
            self.w("if (!r.is_ok) { std::cerr << \"\\nError: \" << r.error << \"\\n\"; std::abort(); }")
            self.w("return r.value;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T>")
            self.w("T _ox_try(const std::optional<T>& o) {")
            self.depth = self.depth + 1
            self.w("if (!o) { std::cerr << \"\\nError: unwrapped None\\n\"; std::abort(); }")
            self.w("return *o;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("")
            self.w("// ── _ox_value ───")
            self.w("template<typename T>")
            self.w("auto& _ox_value(std::optional<T>& o) { return *o; }")
            self.w("template<typename T>")
            self.w("auto _ox_value(const std::optional<T>& o) { return *o; }")
            self.w("template<typename T>")
            self.w("auto& _ox_value(T& o) { return o.value; }")
            self.w("")

            self.w("// ── print ───")
            self.w("template<typename T> void print(const T& v) { std::cout << v << \"\\n\"; }")
            self.w("inline void print(bool v) { std::cout << (v ? \"true\" : \"false\") << \"\\n\"; }")
            self.w("inline void print(const std::string& v) { std::cout << v << \"\\n\"; }")
            self.w("template<typename T> void print(const std::vector<T>& v) {")
            self.depth = self.depth + 1
            self.w("std::cout << \"[\";")
            self.w("for (size_t i=0;i<v.size();i++){if(i)std::cout<<\", \";std::cout<<v[i];}")
            self.w("std::cout << \"]\\n\";")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> void print(const std::optional<T>& o){")
            self.depth = self.depth + 1
            self.w("if(o) std::cout<<\"Some(\"<<*o<<\")\\n\"; else std::cout<<\"None\\n\";")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T, typename E> void print(const Result<T,E>& r){")
            self.depth = self.depth + 1
            self.w("if(r.is_ok) std::cout<<\"Ok(\"<<r.value<<\")\\n\"; else std::cout<<\"Err(\"<<r.error<<\")\\n\";")
            self.depth = self.depth - 1
            self.w("}")
            self.w("")
            self.w("// ── collections ───")
            self.w("template<typename T> size_t len(const std::vector<T>& v){return v.size();}")
            self.w("inline size_t len(const std::string& s){return s.size();}")
            self.w("template<typename T> void push(std::vector<T>& v,const T& x){v.push_back(x);}")
            self.w("template<typename T> T pop(std::vector<T>& v){T x=v.back();v.pop_back();return x;}")
            self.w("template<typename T> bool contains(const std::vector<T>& v, const T& x){")
            self.depth = self.depth + 1
            self.w("return std::find(v.begin(),v.end(),x)!=v.end();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("")
            self.w("// ── functional chaining (List<T>) ───")
            self.w("template<typename T,typename U> std::vector<U> _ox_map(const std::vector<T>& v,U(*fn)(T)){")
            self.depth = self.depth + 1
            self.w("std::vector<U> r; r.reserve(v.size()); for(const auto& x:v) r.push_back(fn(x)); return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> std::vector<T> _ox_filter(const std::vector<T>& v,bool(*fn)(T)){")
            self.depth = self.depth + 1
            self.w("std::vector<T> r; for(const auto& x:v) if(fn(x)) r.push_back(x); return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T,typename U> U _ox_reduce(const std::vector<T>& v,U init,U(*fn)(U,T)){")
            self.depth = self.depth + 1
            self.w("U acc=init; for(const auto& x:v) acc=fn(acc,x); return acc;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> void _ox_for_each(const std::vector<T>& v,void(*fn)(T)){")
            self.depth = self.depth + 1
            self.w("for(const auto& x:v) fn(x);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> bool _ox_any(const std::vector<T>& v,bool(*fn)(T)){")
            self.depth = self.depth + 1
            self.w("for(const auto& x:v) if(fn(x)) return true; return false;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> bool _ox_all(const std::vector<T>& v,bool(*fn)(T)){")
            self.depth = self.depth + 1
            self.w("for(const auto& x:v) if(!fn(x)) return false; return true;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> std::optional<T> _ox_find(const std::vector<T>& v,bool(*fn)(T)){")
            self.depth = self.depth + 1
            self.w("for(const auto& x:v) if(fn(x)) return std::optional<T>(x); return std::nullopt;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> T _ox_sum(const std::vector<T>& v){")
            self.depth = self.depth + 1
            self.w("T acc=T(); for(const auto& x:v) acc=acc+x; return acc;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> T _ox_min(const std::vector<T>& v){")
            self.depth = self.depth + 1
            self.w("T m=v[0]; for(const auto& x:v) if(x<m) m=x; return m;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> T _ox_max(const std::vector<T>& v){")
            self.depth = self.depth + 1
            self.w("T m=v[0]; for(const auto& x:v) if(m<x) m=x; return m;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("")
            self.w("// ── range ───")
            self.w("inline std::vector<int> range(int n){")
            self.depth = self.depth + 1
            self.w("std::vector<int> r; r.reserve(n);")
            self.w("for(int i=0;i<n;i++) r.push_back(i); return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<int> range(int a,int b){")
            self.depth = self.depth + 1
            self.w("std::vector<int> r; r.reserve(b-a>0?b-a:0);")
            self.w("for(int i=a;i<b;i++) r.push_back(i); return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("")
            self.w("// ── conversions ───")
            self.w("inline std::string str(const std::string& v){ return v; }")
            self.w("inline std::string str(const char* v){ return std::string(v); }")
            self.w("inline std::string str(int v) { return std::to_string(v); }")
            self.w("inline std::string str(double v) { return std::to_string(v); }")
            self.w("inline std::string str(bool v) { return v?\"true\":\"false\"; }")
            self.w("template<typename T> std::string str(const std::optional<T>& v){")
            self.depth = self.depth + 1
            self.w("if(v) return \"Some(\"+str(*v)+\")\"; else return \"None\";")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T, typename E> std::string str(const Result<T,E>& r){")
            self.depth = self.depth + 1
            self.w("if(r.is_ok) return \"Ok(\"+str(r.value)+\")\"; else return \"Err(\"+str(r.error)+\")\";")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline int to_int(const std::string& s) { return std::stoi(s); }")
            self.w("inline double to_float(const std::string& s) { return std::stod(s); }")
            self.w("")
            self.w("// ── math ───")
            self.w("using std::sqrt; using std::abs; using std::pow;")
            self.w("using std::sin; using std::cos; using std::tan;")
            self.w("using std::floor;using std::ceil;using std::round;")
            self.w("using std::log; using std::exp;")
            self.w("inline int max(int a,int b){return a>b?a:b;}")
            self.w("inline int min(int a,int b){return a<b?a:b;}")
            self.w("")
            self.w("// ── string helpers ───")
            self.w("inline std::string str_get(const std::string& s, int i) {")
            self.depth = self.depth + 1
            self.w("if (i < 0 || i >= (int)s.size()) return \"\\0\";")
            self.w("return std::string(1, s[i]);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline bool is_digit(const std::string& c) {")
            self.depth = self.depth + 1
            self.w("return c.size() == 1 && std::isdigit((unsigned char)c[0]);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline bool is_alpha(const std::string& c) {")
            self.depth = self.depth + 1
            self.w("return c.size() == 1 && std::isalpha((unsigned char)c[0]);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline bool is_alnum(const std::string& c) {")
            self.depth = self.depth + 1
            self.w("return c.size() == 1 && std::isalnum((unsigned char)c[0]);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline bool str_contains(const std::string& s, const std::string& sub) { return s.find(sub) != std::string::npos; }")
            self.w("inline std::string str_sub(const std::string& s, int start, int end) {")
            self.depth = self.depth + 1
            self.w("if (start < 0) start = 0;")
            self.w("if (end > (int)s.size()) end = (int)s.size();")
            self.w("if (start >= end) return \"\";")
            self.w("return s.substr(start, end - start);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("")
            self.w("// ── system ───")
            self.w("static int _ox_argc; static char** _ox_argv;")
            self.w("inline std::vector<std::string> args() {")
            self.depth = self.depth + 1
            self.w("std::vector<std::string> r;")
            self.w("for (int i=0;i<_ox_argc;i++) r.push_back(std::string(_ox_argv[i]));")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string read_file(const std::string& path) {")
            self.depth = self.depth + 1
            self.w("std::ifstream f(path); if(!f) return \"\";")
            self.w("std::ostringstream ss; ss << f.rdbuf(); return ss.str();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<std::string> read_lines(const std::string& path) {")
            self.depth = self.depth + 1
            self.w("std::vector<std::string> lines;")
            self.w("std::ifstream f(path); if(!f) return lines;")
            self.w("std::string line; while (std::getline(f, line)) lines.push_back(line);")
            self.w("return lines;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline void write_file(const std::string& path, const std::string& c) {")
            self.depth = self.depth + 1
            self.w("std::ofstream f(path); f << c;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline int exec(const std::string& cmd) { return std::system(cmd.c_str()); }")
            self.w("")
            self.w("// ── filesystem ───")
            self.w("inline bool fs_exists(const std::string& path) { return std::filesystem::exists(path); }")
            self.w("inline bool fs_is_file(const std::string& path) { return std::filesystem::is_regular_file(path); }")
            self.w("inline bool fs_is_dir(const std::string& path) { return std::filesystem::is_directory(path); }")
            self.w("inline void fs_mkdir(const std::string& path) { std::filesystem::create_directories(path); }")
            self.w("inline std::vector<std::string> fs_list_dir(const std::string& path) {")
            self.depth = self.depth + 1
            self.w("std::vector<std::string> r;")
            self.w("for (const auto& entry : std::filesystem::directory_iterator(path))")
            self.w("    r.push_back(entry.path().string());")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline void fs_remove(const std::string& path) { std::filesystem::remove_all(path); }")
            self.w("inline void fs_rename(const std::string& o, const std::string& n) { std::filesystem::rename(o, n); }")
            self.w("inline void fs_copy(const std::string& from, const std::string& to) {")
            self.depth = self.depth + 1
            self.w("std::filesystem::copy(from, to, std::filesystem::copy_options::recursive | std::filesystem::copy_options::overwrite_existing);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string fs_cwd() { return std::filesystem::current_path().string(); }")
            self.w("")
        }
        if ns != "" {
            self.w("// ── Module: " + ns + " ───")
            self.w("namespace " + ns + " {")
            self.depth = self.depth + 1
        } else {
            self.w("// ── User Code ───")
        }
        // Forward-declare structs
        var i = 0
        var node_class_id = -1
        while i < len(prog.stmts) {
            if node_pool[prog.stmts[i]].kind == "ClassDef" {
                self.w("struct " + node_pool[prog.stmts[i]].name + ";")
                if node_pool[prog.stmts[i]].name == "Node" { node_class_id = prog.stmts[i] }
            }
            i = i + 1
        }
        if node_class_id >= 0 {
            self.w("")
            // Emit Node's full definition early so List<Node> globals are valid (libc++ fix)
            self.gen_class(node_class_id)
        }
        // Check if any (other) class defs exist
        var has_class = false; i = 0
        while i < len(prog.stmts) {
            let s = node_pool[prog.stmts[i]]
            if s.kind == "ClassDef" and (node_class_id < 0 or prog.stmts[i] != node_class_id) {
                has_class = true; break
            }
            i = i + 1
        }
        if has_class { self.w("") }
        i = 0
        while i < len(prog.stmts) {
            // Skip Node class if already emitted early
            if node_class_id >= 0 and prog.stmts[i] == node_class_id { i = i + 1; continue }
            self.gen_top(prog.stmts[i])
            i = i + 1
        }
        if ns != "" {
            self.depth = self.depth - 1
            self.w("}")
            self.w("")
        }
        // Join output
        var result: str = ""
        i = 0
        while i < len(self.out) {
            if i > 0 { result = result + "\n" }
            result = result + self.out[i]
            i = i + 1
        }
        return result
    }
}

// ── Entry point ─────────────────────────────────────────────
fn compile_source(src: str, source_path: str) -> int {
    node_pool = []
    let lexer = Lexer { src: src, pos: 0, line: 1, col: 1 }
    let tokens = lexer.tokenize()
    let parser = Parser { tokens: tokens, pos: 0, src: src }
    let ast = parser.parse()

    // ── Module resolution ──
    var module_cpps: List<str> = []
    var module_names: List<str> = []

    // Extract source directory from path
    var src_dir: str = ""
    if source_path != "" {
        var slash_pos = -1
        var i = 0
        while i < len(source_path) {
            let c = str_get(source_path, i)
            if c == "/" or c == "\\" { slash_pos = i }
            i = i + 1
        }
        if slash_pos >= 0 { src_dir = str_sub(source_path, 0, slash_pos) }
    }

    let prog = node_pool[ast]
    var si = 0
    while si < len(prog.stmts) {
        let stmt = node_pool[prog.stmts[si]]
        if stmt.kind == "ImportStmt" {
            // Collect path components
            var mod_parts: List<str> = []
            var pi = 0
            while pi < len(stmt.path) {
                push(mod_parts, node_pool[stmt.path[pi]].str_val)
                pi = pi + 1
            }

            // Build module file name (e.g. "json.ox")
            var mod_file: str = ""
            pi = 0
            while pi < len(mod_parts) {
                if pi > 0 { mod_file = mod_file + "/" }
                mod_file = mod_file + mod_parts[pi]
                pi = pi + 1
            }
            mod_file = mod_file + ".ox"

            var mod_src: str = ""
            var found_mod = false

            // Try source-file directory
            if src_dir != "" {
                mod_src = read_file(src_dir + "/" + mod_file)
                if mod_src != "" { found_mod = true }
            }
            // Try current directory
            if not found_mod {
                mod_src = read_file(mod_file)
                if mod_src != "" { found_mod = true }
            }
            // Try oxlib directory
            if not found_mod {
                mod_src = read_file("oxlib/" + mod_file)
                if mod_src != "" { found_mod = true }
            }

            if not found_mod {
                print("Error: cannot find module `" + mod_file + "`")
                exit(1)
            }

            // Parse module
            let mod_lexer = Lexer { src: mod_src, pos: 0, line: 1, col: 1 }
            let mod_tokens = mod_lexer.tokenize()
            let mod_parser = Parser { tokens: mod_tokens, pos: 0, src: mod_src }
            let mod_ast = mod_parser.parse()

            // Build module name and C++-safe namespace name
            var mod_name: str = ""
            var ns_name: str = ""
            pi = 0
            while pi < len(mod_parts) {
                if pi > 0 { mod_name = mod_name + "."; ns_name = ns_name + "_" }
                mod_name = mod_name + mod_parts[pi]
                ns_name = ns_name + mod_parts[pi]
                pi = pi + 1
            }
            push(module_names, mod_name)

            // Generate module C++ (inside namespace, no runtime header)
            let mod_cgen = CodeGen { out: [], depth: 0, in_class: "", tmp_counter: 0, modules: [] }
            push(module_cpps, mod_cgen.generate_module(mod_ast, ns_name))
        }
        si = si + 1
    }

    // ── Generate main C++ (with module names so codegen resolves mod.fn() calls) ──
    let codegen = CodeGen { out: [], depth: 0, in_class: "", tmp_counter: 0, modules: module_names }
    let main_cpp = codegen.generate(ast)

    // ── Assemble final C++ ──
    var cpp: str = ""
    if len(module_cpps) > 0 {
        // Find split point ── User Code ───
        let marker = "// ── User Code ───"
        var user_start = -1
        var i = 0
        while i < len(main_cpp) - len(marker) {
            var matched = true
            var j = 0
            while j < len(marker) {
                if str_get(main_cpp, i + j) != str_get(marker, j) { matched = false; break }
                j = j + 1
            }
            if matched { user_start = i; break }
            i = i + 1
        }

        if user_start >= 0 {
            cpp = str_sub(main_cpp, 0, user_start)
            cpp = cpp + "// ── Module Code ──────────────────────────────────\n"
            var mi = 0
            while mi < len(module_cpps) {
                if mi > 0 { cpp = cpp + "\n" }
                cpp = cpp + module_cpps[mi]
                mi = mi + 1
            }
            cpp = cpp + "\n\n" + str_sub(main_cpp, user_start, len(main_cpp))
        } else {
            cpp = main_cpp
        }
    } else {
        cpp = main_cpp
    }

    let id = alloc_node()
    node_pool[id].kind = "Result"
    node_pool[id].str_val = cpp
    return id
}

fn main() -> void {
    let cli_args: List<str> = args()
    if len(cli_args) < 2 {
        print("Usage: oxybelis <source.ox> [--cc CXX] [--cflags FLAGS] [-o FILE] [-S]")
        exit(1)
    }
    let source_path: str = cli_args[1]
    var output_path: str = ""
    var do_compile = true
    var emit_cpp = false
    var cc: str = "g++"
    var cflags: str = "-O3 -std=c++20"

    var ai = 2
    while ai < len(cli_args) {
        if cli_args[ai] == "-o" and ai + 1 < len(cli_args) {
            output_path = cli_args[ai + 1]; ai = ai + 1
        } elif cli_args[ai] == "-S" { emit_cpp = true; do_compile = false }
        elif cli_args[ai] == "--cc" and ai + 1 < len(cli_args) { cc = cli_args[ai + 1]; ai = ai + 1 }
        elif cli_args[ai] == "--cflags" and ai + 1 < len(cli_args) { cflags = cli_args[ai + 1]; ai = ai + 1 }
        ai = ai + 1
    }

    let src: str = read_file(source_path)
    if src == "" {
        print("Error: Could not read " + source_path)
        exit(1)
    }

    let result_id = compile_source(src, source_path)
    let cpp: str = node_pool[result_id].str_val

    if output_path != "" {
        write_file(output_path, cpp)
        print("✓ " + source_path + " → " + output_path)
    } elif emit_cpp {
        print(cpp)
    } else {
        // Compile directly
        var dot_pos = -1
        var i = 0
        while i < len(source_path) {
            if str_get(source_path, i) == "." { dot_pos = i }
            i = i + 1
        }
        var exe_name: str = source_path
        if dot_pos >= 0 { exe_name = str_sub(source_path, 0, dot_pos) }
        let cpp_file: str = exe_name + ".cpp"
        let exe_file: str = exe_name + ".exe"
        write_file(cpp_file, cpp)
        // Auto-detect -mconsole on Windows (paths with backslashes)
        var mconsole: str = ""
        var j = 0
        while j < len(cpp_file) { if str_get(cpp_file, j) == "\\" { mconsole = " -mconsole"; break }; j = j + 1 }
        let status = exec(cc + " " + cflags + mconsole + " " + cpp_file + " -o " + exe_file)
        if status == 0 {
            print("✓ " + source_path + " → " + exe_file)
            exec(exe_file)
        } else {
            print("✗ Compilation failed (see " + cpp_file + ")")
            exit(1)
        }
    }
}
