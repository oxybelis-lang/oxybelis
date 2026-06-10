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
    // Source-span tracking for diagnostics
    s_line: int
    s_col: int
    node_type: str  // inferred type cache (set by type checker)
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
                   has_self: false, s_line: -1, s_col: -1, node_type: "" }
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

fn node_yield_stmt(value: int) -> int {
    let id = alloc_node()
    node_pool[id].kind = "YieldStmt"
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
    node_pool[id].type_ann = ptype
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

fn set_span(node_id: int, line: int, col: int) -> void {
    node_pool[node_id].s_line = line
    node_pool[node_id].s_col = col
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
    var pad: str = ""
    j = 0
    while j < len(str(line)) { pad = pad + " "; j = j + 1 }
    print(pad + " |")
    print(str(line) + " | " + source_line)
    print(pad + " | " + indent + "^")
}

// ── Type helpers ────────────────────────────────────────────
fn base_type(ty: str) -> str {
    var i = 0
    while i < len(ty) {
        if str_get(ty, i) == "<" { return str_sub(ty, 0, i) }
        i = i + 1
    }
    return ty
}

fn type_params(ty: str) -> List<str> {
    var i = 0
    while i < len(ty) {
        if str_get(ty, i) == "<" {
            let inner = str_sub(ty, i + 1, len(ty) - 1)
            return split_args(inner)
        }
        i = i + 1
    }
    return []
}

// ── Diagnostic types (mirror ox_diag.py) ─────────────────────
let OX_SEVERITY_ERROR   = "error"
let OX_SEVERITY_WARNING = "warning"
let OX_SEVERITY_NOTE    = "note"
let OX_SEVERITY_HELP    = "help"

class Span {
    start_line: int
    start_col: int
    end_line: int
    end_col: int
}

class Diagnostic {
    severity: str
    message: str
    code: str
    s_line: int
    s_col: int
}

fn make_diag(severity: str, msg: str, code: str, line: int, col: int) -> Diagnostic {
    return Diagnostic { severity: severity, message: msg, code: code, s_line: line, s_col: col }
}

fn render_diags(diags: List<Diagnostic>, src: str, path: str) -> List<str> {
    var lines: List<str> = []
    var i = 0
    while i < len(diags) {
        push(lines, render_one(diags[i], src, path))
        i = i + 1
    }
    return lines
}

fn render_one(d: Diagnostic, src: str, path: str) -> str {
    var result: str = ""
    if d.code != "" { result = d.code + ": " }
    result = result + d.message
    if d.s_line >= 1 {
        var src_lines: List<str> = []
        var cur: str = ""
        var j = 0
        while j < len(src) {
            let c: str = str_get(src, j)
            if c == "\n" { push(src_lines, cur); cur = "" }
            else { cur = cur + c }
            j = j + 1
        }
        push(src_lines, cur)
        var source_line: str = ""
        if d.s_line <= len(src_lines) { source_line = src_lines[d.s_line - 1] }
        result = result + "\n"
        if path != "" { result = result + " --> " + path }
        result = result + ":" + str(d.s_line) + ":" + str(d.s_col)
        var indent: str = ""
        var j2 = 0
        while j2 < d.s_col - 1 { indent = indent + " "; j2 = j2 + 1 }
        var pad: str = ""
        j2 = 0
        while j2 < len(str(d.s_line)) { pad = pad + " "; j2 = j2 + 1 }
        result = result + "\n" + pad + " |"
        result = result + "\n" + str(d.s_line) + " | " + source_line
        result = result + "\n" + pad + " | " + indent + "^"
    }
    return result
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
let TT_YIELD        = "YIELD"
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
    if word == "yield"    { return TT_YIELD }
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
    cur_tok: Token

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
        self.cur_tok = t
        return t
    }

    fn span(self, node_id: int) -> int {
        set_span(node_id, self.cur_tok.line, self.cur_tok.col)
        return node_id
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
        return self.span(node_program(stmts))
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
        let p1: Token = self.expect([TT_IDENT])
        let path: List<int> = [self.span(node_str_id(p1.lexeme))]
        while self.matched(self.match_tok([TT_DOT])) {
            let pn: Token = self.expect([TT_IDENT])
            push(path, self.span(node_str_id(pn.lexeme)))
        }
        return self.span(node_import(path))
    }

    fn parse_generics(self) -> List<int> {
        let gs: List<int> = []
        if self.matched(self.match_tok([TT_LT])) {
            while not self.check([TT_GT]) {
                let g_tok: Token = self.expect([TT_IDENT])
                push(gs, self.span(node_str_id(g_tok.lexeme)))
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
                push(params, self.span(node_param(pname, ptype)))
                if not self.matched(self.match_tok([TT_COMMA])) { break }
            }
        }
        self.expect([TT_RPAREN])
        var ret: str = "void"
        if self.matched(self.match_tok([TT_ARROW])) { ret = self.parse_type() }
        let body: List<int> = self.parse_block()
        return self.span(node_fn_def(name, params, ret, body, is_pub, is_lazy, generics, has_self))
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
                push(fields, self.span(node_param(fname, ftype)))
                self.skip_semis()
            }
        }
        self.expect([TT_RBRACE])
        return self.span(node_class_def(name, fields, methods, generics))
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
        if self.check([TT_YIELD])          { return self.parse_yield() }
        if self.check([TT_IF])             { return self.parse_if() }
        if self.check([TT_FOR])            { return self.parse_for() }
        if self.check([TT_WHILE])          { return self.parse_while() }
        if self.check([TT_MATCH])          { return self.parse_match() }
        if self.check([TT_FN])             { return self.parse_fn(false, false) }
        if self.check([TT_BREAK])          { self.advance(); return self.span(node_break()) }
        if self.check([TT_CONTINUE])       { self.advance(); return self.span(node_continue()) }
        let expr: int = self.parse_expr()
        if self.check([TT_ASSIGN, TT_PLUS_ASSIGN, TT_MINUS_ASSIGN,
                       TT_STAR_ASSIGN, TT_SLASH_ASSIGN]) {
            let op_tok: Token = self.advance()
            let rhs: int = self.parse_expr()
            let id = node_assign(expr, rhs, op_tok.lexeme)
            set_span(id, op_tok.line, op_tok.col)
            return id
        }
        return self.span(node_expr_stmt(expr))
    }

    fn parse_var_decl(self) -> int {
        let is_mut: bool = self.advance().type_name == TT_VAR
        let name: str = self.expect([TT_IDENT]).lexeme
        var type_ann: str = ""
        if self.matched(self.match_tok([TT_COLON])) { type_ann = self.parse_type() }
        self.expect([TT_ASSIGN])
        let value: int = self.parse_expr()
        return self.span(node_var_decl(name, type_ann, value, is_mut))
    }

    fn parse_return(self) -> int {
        self.expect([TT_RETURN])
        if self.check([TT_RBRACE, TT_SEMI, TT_EOF]) { return self.span(node_return(-1)) }
        return self.span(node_return(self.parse_expr()))
    }

    fn parse_yield(self) -> int {
        self.expect([TT_YIELD])
        let value: int = self.parse_expr()
        return self.span(node_yield_stmt(value))
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
            push(elifs, self.span(node_elif(ec, eb)))
        }
        if self.matched(self.match_tok([TT_ELSE])) { else_body = self.parse_block() }
        return self.span(node_if(cond, then_body, elifs, else_body))
    }

    fn parse_for(self) -> int {
        self.expect([TT_FOR])
        let var_name: str = self.expect([TT_IDENT]).lexeme
        self.expect([TT_IN])
        let iterable: int = self.parse_expr()
        let body: List<int> = self.parse_block()
        return self.span(node_for(var_name, iterable, body))
    }

    fn parse_while(self) -> int {
        self.expect([TT_WHILE])
        let cond: int = self.parse_expr()
        let body: List<int> = self.parse_block()
        return self.span(node_while(cond, body))
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
            push(arms, self.span(node_arm(pat, body)))
            self.skip_semis()
        }
        self.expect([TT_RBRACE])
        return self.span(node_match(subject, arms))
    }

    fn parse_pattern(self) -> int {
        if self.check([TT_UNDERSCORE]) { self.advance(); return self.span(node_wild()) }
        let expr: int = self.parse_primary()
        if self.matched(self.match_tok([TT_DOTDOT])) {
            let end: int = self.parse_primary()
            return self.span(node_range_lit(expr, end))
        }
        return expr
    }

    // ── Expressions ──
    fn parse_expr(self) -> int {
        let expr: int = self.parse_or()
        if self.matched(self.match_tok([TT_DOTDOT])) {
            let end: int = self.parse_or()
            return self.span(node_range_lit(expr, end))
        }
        return expr
    }

    fn parse_or(self) -> int {
        var left: int = self.parse_and()
        while self.check([TT_OR]) {
            let op_tok: Token = self.advance()
            let right: int = self.parse_and()
            left = node_bin_op(op_tok.lexeme, left, right)
            set_span(left, op_tok.line, op_tok.col)
        }
        return left
    }

    fn parse_and(self) -> int {
        var left: int = self.parse_compare()
        while self.check([TT_AND]) {
            let op_tok: Token = self.advance()
            let right: int = self.parse_compare()
            left = node_bin_op(op_tok.lexeme, left, right)
            set_span(left, op_tok.line, op_tok.col)
        }
        return left
    }

    fn parse_compare(self) -> int {
        var left: int = self.parse_add()
        while self.check([TT_EQ, TT_NEQ, TT_LT, TT_GT, TT_LEQ, TT_GEQ]) {
            let op_tok: Token = self.advance()
            let right: int = self.parse_add()
            left = node_bin_op(op_tok.lexeme, left, right)
            set_span(left, op_tok.line, op_tok.col)
        }
        return left
    }

    fn parse_add(self) -> int {
        var left: int = self.parse_mul()
        while self.check([TT_PLUS, TT_MINUS]) {
            let op_tok: Token = self.advance()
            let right: int = self.parse_mul()
            left = node_bin_op(op_tok.lexeme, left, right)
            set_span(left, op_tok.line, op_tok.col)
        }
        return left
    }

    fn parse_mul(self) -> int {
        var left: int = self.parse_unary()
        while self.check([TT_STAR, TT_SLASH, TT_PERCENT]) {
            let op_tok: Token = self.advance()
            let right: int = self.parse_unary()
            left = node_bin_op(op_tok.lexeme, left, right)
            set_span(left, op_tok.line, op_tok.col)
        }
        return left
    }

    fn parse_unary(self) -> int {
        if self.check([TT_MINUS]) { let t = self.advance(); let id = node_unary_op("-", self.parse_unary()); set_span(id, t.line, t.col); return id }
        if self.check([TT_NOT])   { let t = self.advance(); let id = node_unary_op("!", self.parse_unary()); set_span(id, t.line, t.col); return id }
        if self.check([TT_BANG])  { let t = self.advance(); let id = node_unary_op("!", self.parse_unary()); set_span(id, t.line, t.col); return id }
        return self.parse_postfix()
    }

    fn parse_postfix(self) -> int {
        var expr: int = self.parse_primary()
        while true {
            if self.check([TT_DOT]) {
                let dot_tok: Token = self.advance()
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
                    set_span(expr, dot_tok.line, dot_tok.col)
                } else {
                    expr = node_attr(expr, name)
                    set_span(expr, dot_tok.line, dot_tok.col)
                }
            } elif self.check([TT_LPAREN]) {
                let lp_tok: Token = self.advance()
                let args: List<int> = []
                while not self.check([TT_RPAREN, TT_EOF]) {
                    push(args, self.parse_expr())
                    if not self.matched(self.match_tok([TT_COMMA])) { break }
                }
                self.expect([TT_RPAREN])
                expr = node_fn_call(expr, args)
                set_span(expr, lp_tok.line, lp_tok.col)
            } elif self.check([TT_LBRACKET]) {
                let lb_tok: Token = self.advance()
                let idx: int = self.parse_expr()
                self.expect([TT_RBRACKET])
                expr = node_index(expr, idx)
                set_span(expr, lb_tok.line, lb_tok.col)
            } elif self.check([TT_QUESTION]) {
                let q_tok: Token = self.advance()
                expr = node_try_op(expr)
                set_span(expr, q_tok.line, q_tok.col)
            } else { break }
        }
        return expr
    }

    fn parse_primary(self) -> int {
        let t = self.peek(0)
        if t.type_name == TT_INT_LIT   { self.advance(); return self.span(node_int_lit(to_int(t.lexeme))) }
        if t.type_name == TT_FLOAT_LIT { self.advance(); return self.span(node_float_lit(to_float(t.lexeme))) }
        if t.type_name == TT_STR_LIT   { self.advance(); return self.span(node_str_lit(t.lexeme)) }
        if t.type_name == TT_TRUE      { self.advance(); return self.span(node_bool_lit(true)) }
        if t.type_name == TT_FALSE     { self.advance(); return self.span(node_bool_lit(false)) }
        if t.type_name == TT_NONE_KW   { self.advance(); return self.span(node_none_lit()) }
        if t.type_name == TT_SOME_KW {
            self.advance(); self.expect([TT_LPAREN])
            let v: int = self.parse_expr(); self.expect([TT_RPAREN])
            return self.span(node_some_lit(v))
        }
        if t.type_name == TT_UNDERSCORE { self.advance(); return self.span(node_wild()) }
        if t.type_name == TT_LBRACKET {
            self.advance(); let elems: List<int> = []
            while not self.check([TT_RBRACKET, TT_EOF]) {
                push(elems, self.parse_expr())
                if not self.matched(self.match_tok([TT_COMMA])) { break }
            }
            self.expect([TT_RBRACKET]); return self.span(node_list_lit(elems))
        }
        if t.type_name == TT_LPAREN {
            self.advance(); let expr: int = self.parse_expr()
            self.expect([TT_RPAREN]); return expr
        }

        // Identifier or struct literal
        if t.type_name == TT_IDENT {
            let name_tok: Token = self.advance()
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
                    var full_name: str = name_tok.lexeme + "<" + args[0]
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
                                push(flds, self.span(node_field(fn_name, fv)))
                                if not self.matched(self.match_tok([TT_COMMA])) { break }
                            }
                            self.expect([TT_RBRACE])
                            return self.span(node_struct_lit(full_name, flds))
                        }
                        self.pos = saved2
                    }
                    return self.span(node_ident(full_name))
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
                        push(flds, self.span(node_field(fn_name, fv)))
                        if not self.matched(self.match_tok([TT_COMMA])) { break }
                    }
                    self.expect([TT_RBRACE])
                    return self.span(node_struct_lit(name_tok.lexeme, flds))
                } else {
                    self.pos = saved
                }
            }
            return self.span(node_ident(name_tok.lexeme))
        }

        // Allow type keywords as identifiers
        if t.type_name == TT_T_INT or t.type_name == TT_T_FLOAT or
           t.type_name == TT_T_BOOL or t.type_name == TT_T_STR or
           t.type_name == TT_T_VOID {
            self.advance(); return self.span(node_ident(t.lexeme))
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
            push(result, str_trim(cur))
            cur = ""
        } else { cur = cur + c }
        i = i + 1
    }
    if cur != "" { push(result, str_trim(cur)) }
    return result
}

fn map_type(t: str) -> str {
    if t == "int"   { return "int" }
    if t == "float" { return "double" }
    if t == "bool"  { return "bool" }
    if t == "str"   { return "std::string" }
    if t == "void"  { return "void" }
    if t == "Option" or t == "List" or t == "Map" or t == "Set" or t == "Result" { return t }
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
    // Generator state-machine temporaries
    _gen_lines: List<str>
    _gen_state: int
    _gen_DONE: int
    _gen_member_names: List<str>
    _gen_member_types: List<str>

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
            if func_node.kind == "Ident" and func_node.name == "int" {
                return "static_cast<int>(" + self.expr(node.args[0]) + ")"
            }
            if func_node.kind == "Ident" and func_node.name == "float" {
                return "static_cast<double>(" + self.expr(node.args[0]) + ")"
            }
            if func_node.kind == "Ident" and func_node.name == "bool" {
                return "static_cast<bool>(" + self.expr(node.args[0]) + ")"
            }
            var as: str = ""
            var i = 0
            while i < len(node.args) {
                if i > 0 { as = as + ", " }
                as = as + self.expr(node.args[i])
                i = i + 1
            }
            if func_node.kind == "Ident" and func_node.name == "sorted" {
                return "_ox_sorted(" + as + ")"
            }
            if func_node.kind == "Ident" and func_node.name == "list" {
                return "_ox_list_from_str(" + as + ")"
            }
            if func_node.kind == "Ident" and func_node.name == "enumerate" {
                return "_ox_enumerate(" + as + ")"
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
            if node.name == "map" or node.name == "filter" or node.name == "reduce" or node.name == "for_each" or node.name == "each" or node.name == "any" or node.name == "all" or node.name == "find" or node.name == "sum" or node.name == "min" or node.name == "max" or node.name == "combinations" or node.name == "permutations" or node.name == "chunked" or node.name == "windowed" or node.name == "pairwise" or node.name == "reversed" or node.name == "cycle" or node.name == "take_while" or node.name == "drop_while" or node.name == "sorted" {
                if node.name == "sorted" {
                    if as != "" { return "_ox_sorted(" + obj_str + ", " + as + ")" }
                    return "_ox_sorted(" + obj_str + ")"
                }
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
            if es == "" { return "{}" }
            return "_ox_make_list({" + es + "})"
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
        elif node.kind == "YieldStmt" {
            self.w("/* unexpected yield outside generator */")
        }
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
            self.w("for (auto " + node.var_name + " : " + self.expr(node.iterable) + ") {")
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

    fn _has_yield(self, stmt_ids: List<int>) -> bool {
        var i = 0
        while i < len(stmt_ids) {
            let s = node_pool[stmt_ids[i]]
            if s.kind == "YieldStmt" { return true }
            if s.kind == "IfStmt" {
                if self._has_yield(s.then_body) { return true }
                var j = 0
                while j < len(s.elif_clauses) {
                    let ec = node_pool[s.elif_clauses[j]]
                    if self._has_yield(ec.body) { return true }
                    j = j + 1
                }
                if self._has_yield(s.else_body) { return true }
            }
            if s.kind == "WhileStmt" {
                if self._has_yield(s.body) { return true }
            }
            if s.kind == "ForStmt" {
                if self._has_yield(s.body) { return true }
            }
            i = i + 1
        }
        return false
    }

    // ── Generator helpers ──────────────────────────────────────
    fn _gen_next_state(self) -> int {
        let s = self._gen_state
        self._gen_state = self._gen_state + 1
        return s
    }

    fn _gen_emit(self, line: str) -> void {
        push(self._gen_lines, line)
    }

    fn _gen_case(self, s: int) -> void {
        self._gen_emit("case " + str(s) + ":")
    }

    fn _gen_get_inner_type(self, fn_id: int) -> str {
        let rt = node_pool[fn_id].return_type
        var i = 0
        while i < len(rt) {
            if str_get(rt, i) == "<" {
                return str_sub(rt, i + 1, len(rt) - 1)
            }
            i = i + 1
        }
        return "void"
    }

    fn _gen_infer_type(self, expr_id: int) -> str {
        let node = node_pool[expr_id]
        if node.kind == "IntLit" { return "int" }
        if node.kind == "FloatLit" { return "double" }
        if node.kind == "BoolLit" { return "bool" }
        if node.kind == "StrLit" { return "std::string" }
        if node.kind == "UnaryOp" { return self._gen_infer_type(node.operand) }
        if node.kind == "BinOp" {
            let lt = self._gen_infer_type(node.left)
            let rt = self._gen_infer_type(node.right)
            if lt == "double" or rt == "double" { return "double" }
            if lt == "int" or rt == "int" { return "int" }
            if lt != "" { return lt }
            return rt
        }
        return "int"
    }

    fn _gen_find_members(self, stmt_ids: List<int>) -> void {
        var i = 0
        while i < len(stmt_ids) {
            let s = node_pool[stmt_ids[i]]
            if s.kind == "VarDecl" {
                var found = false
                var j = 0
                while j < len(self._gen_member_names) {
                    if self._gen_member_names[j] == s.name { found = true; break }
                    j = j + 1
                }
                if not found {
                    push(self._gen_member_names, s.name)
                    if s.type_ann != "" {
                        push(self._gen_member_types, map_type(s.type_ann))
                    } else {
                        push(self._gen_member_types, self._gen_infer_type(s.inner))
                    }
                }
            }
            if s.kind == "IfStmt" {
                self._gen_find_members(s.then_body)
                var j = 0
                while j < len(s.elif_clauses) {
                    let ec = node_pool[s.elif_clauses[j]]
                    self._gen_find_members(ec.body)
                    j = j + 1
                }
                self._gen_find_members(s.else_body)
            }
            if s.kind == "WhileStmt" { self._gen_find_members(s.body) }
            if s.kind == "ForStmt"   { self._gen_find_members(s.body) }
            i = i + 1
        }
    }

    fn _gen_body(self, stmt_ids: List<int>) -> void {
        var i = 0
        while i < len(stmt_ids) {
            let stmt = node_pool[stmt_ids[i]]
            if stmt.kind == "YieldStmt" {
                let cont = self._gen_next_state()
                let val = self.expr(stmt.inner)
                self._gen_emit("{ _state = " + str(cont) + "; return Some(" + val + "); }")
                self._gen_case(cont)
            } elif stmt.kind == "WhileStmt" {
                self._gen_while(stmt_ids[i])
            } elif stmt.kind == "IfStmt" {
                self._gen_generator_if(stmt_ids[i])
            } elif stmt.kind == "ForStmt" {
                self._gen_generator_for(stmt_ids[i])
            } elif stmt.kind == "VarDecl" {
                let val = self.expr(stmt.inner)
                self._gen_emit(stmt.name + " = " + val + ";")
            } elif stmt.kind == "Assignment" {
                self._gen_emit(self.expr(stmt.target) + " " + stmt.op + " " + self.expr(stmt.inner) + ";")
            } elif stmt.kind == "ExprStmt" {
                self._gen_emit(self.expr(stmt.inner) + ";")
            } elif stmt.kind == "ReturnStmt" {
                self._gen_emit("_state = " + str(self._gen_DONE) + "; return None;")
            } elif stmt.kind == "BreakStmt" {
                self._gen_emit("break;")
            } elif stmt.kind == "ContinueStmt" {
                self._gen_emit("continue;")
            }
            i = i + 1
        }
    }

    fn _gen_while(self, s_id: int) -> void {
        let s = node_pool[s_id]
        let cond = self.expr(s.cond)
        let check = self._gen_next_state()
        let exit_s = self._gen_next_state()
        self._gen_emit("_state = " + str(check) + "; break;")
        self._gen_case(check)
        self._gen_emit("if (!(" + cond + ")) { _state = " + str(exit_s) + "; break; }")
        self._gen_body(s.body)
        self._gen_emit("_state = " + str(check) + "; break;")
        self._gen_case(exit_s)
    }

    fn _gen_generator_for(self, s_id: int) -> void {
        let s = node_pool[s_id]
        let it = node_pool[s.iterable]
        if it.kind == "RangeLit" {
            let start = self.expr(it.start)
            let end = self.expr(it.end)
            if self._has_yield(s.body) {
                let check = self._gen_next_state()
                let exit_s = self._gen_next_state()
                self._gen_emit("_state = " + str(check) + "; break;")
                self._gen_case(check)
                self._gen_emit("if (" + s.var_name + " >= " + end + ") { _state = " + str(exit_s) + "; break; }")
                self._gen_body(s.body)
                self._gen_emit(s.var_name + "++; _state = " + str(check) + "; break;")
                self._gen_case(exit_s)
            } else {
                self._gen_emit("for (int " + s.var_name + " = " + start + "; " + s.var_name + " < " + end + "; ++" + s.var_name + ") {")
                self._gen_body(s.body)
                self._gen_emit("}")
            }
        } else {
            let it_expr = self.expr(s.iterable)
            if self._has_yield(s.body) {
                let check = self._gen_next_state()
                let exit_s = self._gen_next_state()
                self._gen_emit("auto&& _it = " + it_expr + "; auto _ip = _it.begin();")
                self._gen_emit("_state = " + str(check) + "; break;")
                self._gen_case(check)
                self._gen_emit("if (_ip == _it.end()) { _state = " + str(exit_s) + "; break; }")
                self._gen_emit("auto& " + s.var_name + " = *_ip;")
                self._gen_body(s.body)
                self._gen_emit("++_ip; _state = " + str(check) + "; break;")
                self._gen_case(exit_s)
            } else {
                self._gen_emit("for (auto " + s.var_name + " : " + it_expr + ") {")
                self._gen_body(s.body)
                self._gen_emit("}")
            }
        }
    }

    fn _gen_generator_if(self, s_id: int) -> void {
        let s = node_pool[s_id]
        var has_yield = self._has_yield(s.then_body)
        if len(s.else_body) > 0 {
            if self._has_yield(s.else_body) { has_yield = true }
        }
        var j = 0
        while j < len(s.elif_clauses) {
            let ec = node_pool[s.elif_clauses[j]]
            if self._has_yield(ec.body) { has_yield = true }
            j = j + 1
        }
        if has_yield {
            self._gen_if_stateful(s_id)
        } else {
            let cond = self.expr(s.cond)
            self._gen_emit("if (" + cond + ") {")
            self._gen_body(s.then_body)
            self._gen_emit("} else {")
            if len(s.else_body) > 0 {
                self._gen_body(s.else_body)
            }
            var jj = 0
            while jj < len(s.elif_clauses) {
                let ec = node_pool[s.elif_clauses[jj]]
                self._gen_emit("} else if (" + self.expr(ec.cond) + ") {")
                self._gen_body(ec.body)
                jj = jj + 1
            }
            self._gen_emit("}")
        }
    }

    fn _gen_if_stateful(self, s_id: int) -> void {
        let s = node_pool[s_id]
        let if_check = self._gen_next_state()
        let after_s = self._gen_next_state()
        self._gen_emit("_state = " + str(if_check) + "; break;")
        self._gen_case(if_check)
        var br_conds: List<int> = []
        var br_bodies: List<List<int>> = []
        push(br_conds, s.cond)
        push(br_bodies, s.then_body)
        var j = 0
        while j < len(s.elif_clauses) {
            let ec = node_pool[s.elif_clauses[j]]
            push(br_conds, ec.cond)
            push(br_bodies, ec.body)
            j = j + 1
        }
        if len(s.else_body) > 0 {
            push(br_conds, -1)
            push(br_bodies, s.else_body)
        }
        var i = 0
        while i < len(br_conds) {
            let cond_node = br_conds[i]
            let branch_s = self._gen_next_state()
            if cond_node != -1 {
                let cond_str = self.expr(cond_node)
                if i < len(br_conds) - 1 {
                    self._gen_emit("if (" + cond_str + ") { _state = " + str(branch_s) + "; break; }")
                } else {
                    self._gen_emit("if (" + cond_str + ") { _state = " + str(branch_s) + "; break; } else { _state = " + str(after_s) + "; break; }")
                }
            } else {
                self._gen_emit("_state = " + str(branch_s) + "; break;")
            }
            self._gen_case(branch_s)
            self._gen_body(br_bodies[i])
            self._gen_emit("_state = " + str(after_s) + "; break;")
            i = i + 1
        }
        self._gen_case(after_s)
    }

    fn _gen_emit_struct(self, fn_id: int) -> void {
        let fn_node = node_pool[fn_id]
        let sn = "_gen_" + fn_node.name
        let inner = self._gen_get_inner_type(fn_id)
        self.w("struct " + sn + " {")
        self.depth = self.depth + 1
        self.w("int _state = 0;")
        var pi = 0
        while pi < len(fn_node.params) {
            let p = node_pool[fn_node.params[pi]]
            self.w(map_type(p.type_ann) + " " + p.name + ";")
            pi = pi + 1
        }
        var vi = 0
        while vi < len(self._gen_member_names) {
            let vname = self._gen_member_names[vi]
            var found = false
            var pi2 = 0
            while pi2 < len(fn_node.params) {
                let p = node_pool[fn_node.params[pi2]]
                if p.name == vname { found = true; break }
                pi2 = pi2 + 1
            }
            if not found {
                self.w(self._gen_member_types[vi] + " " + vname + ";")
            }
            vi = vi + 1
        }
        var cons_params: str = ""
        var init_list: str = ""
        var pi3 = 0
        while pi3 < len(fn_node.params) {
            let p = node_pool[fn_node.params[pi3]]
            if pi3 > 0 { cons_params = cons_params + ", "; init_list = init_list + ", " }
            cons_params = cons_params + map_type(p.type_ann) + " " + p.name
            init_list = init_list + p.name + "(" + p.name + ")"
            pi3 = pi3 + 1
        }
        self.w(sn + "(" + cons_params + ") : " + init_list + " {}")
        self.w("Option<" + map_type(inner) + "> _next() {")
        self.depth = self.depth + 1
        self.w("while (true) {")
        self.depth = self.depth + 1
        self.w("switch (_state) {")
        self.depth = self.depth + 1
        var li = 0
        while li < len(self._gen_lines) {
            self.w(self._gen_lines[li])
            li = li + 1
        }
        self.depth = self.depth - 1
        self.w("}")
        self.depth = self.depth - 1
        self.w("}")
        self.depth = self.depth - 1
        self.w("}")
        self.depth = self.depth - 1
        self.w("};")
    }

    fn _gen_emit_wrapper(self, fn_id: int) -> void {
        let fn_node = node_pool[fn_id]
        let sn = "_gen_" + fn_node.name
        let inner = self._gen_get_inner_type(fn_id)
        var params: str = ""
        var args: str = ""
        var pi = 0
        while pi < len(fn_node.params) {
            let p = node_pool[fn_node.params[pi]]
            if pi > 0 { params = params + ", "; args = args + ", " }
            params = params + map_type(p.type_ann) + " " + p.name
            args = args + p.name
            pi = pi + 1
        }
        let ret = "Generator<" + map_type(inner) + ">"
        self.w(ret + " " + fn_node.name + "(" + params + ") {")
        self.depth = self.depth + 1
        self.w("auto gen = " + sn + "(" + args + ");")
        self.w("return " + ret + "([gen]() mutable -> Option<" + map_type(inner) + "> { return gen._next(); });")
        self.depth = self.depth - 1
        self.w("}")
        self.w("")
    }

    fn gen_generator_fn(self, node_id: int) -> void {
        // Initialize generator state
        self._gen_lines = []
        self._gen_state = 1
        self._gen_DONE = 9999
        self._gen_member_names = []
        self._gen_member_types = []
        // Build state machine
        self._gen_find_members(node_pool[node_id].body)
        self._gen_case(0)
        self._gen_body(node_pool[node_id].body)
        self._gen_emit("_state = " + str(self._gen_DONE) + "; return None;")
        self._gen_case(self._gen_DONE)
        self._gen_emit("return None;")
        // Emit struct + wrapper
        self._gen_emit_struct(node_id)
        self._gen_emit_wrapper(node_id)
    }

    fn gen_fn(self, node_id: int) -> void {
        let node = node_pool[node_id]
        if self._has_yield(node.body) {
            self.gen_generator_fn(node_id)
            return
        }
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
            ps = ps + map_type(p.type_ann) + " " + p.name
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
            self.w(map_type(f.type_ann) + " " + f.name + ";")
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
            ps = ps + map_type(p.type_ann) + " " + p.name
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
            self.w("#include <unordered_set>")
            self.w("#include <functional>")
            self.w("#include <algorithm>")
            self.w("#include <cmath>")
            self.w("#include <stdexcept>")
            self.w("#include <sstream>")
            self.w("#include <iomanip>")
            self.w("#include <fstream>")
            self.w("#include <random>")
            self.w("#include <cstdlib>")
            self.w("#include <cctype>")
            self.w("#include <filesystem>")
            self.w("#include <NumCpp/Core.hpp>")
            self.w("#include <NumCpp/NdArray.hpp>")
            self.w("#include <NumCpp/Functions/sin.hpp>")
            self.w("#include <NumCpp/Functions/cos.hpp>")
            self.w("#include <NumCpp/Functions/tan.hpp>")
            self.w("#include <NumCpp/Functions/sqrt.hpp>")
            self.w("#include <NumCpp/Functions/abs.hpp>")
            self.w("#include <NumCpp/Functions/exp.hpp>")
            self.w("#include <NumCpp/Functions/log.hpp>")
            self.w("#include <NumCpp/Functions/floor.hpp>")
            self.w("#include <NumCpp/Functions/ceil.hpp>")
            self.w("#include <NumCpp/Functions/zeros.hpp>")
            self.w("#include <NumCpp/Functions/ones.hpp>")
            self.w("#include <NumCpp/Functions/linspace.hpp>")
            self.w("#include <NumCpp/Functions/arange.hpp>")
            self.w("#include <NumCpp/Functions/dot.hpp>")
            self.w("#include <NumCpp/Functions/matmul.hpp>")
            self.w("#include <NumCpp/Functions/norm.hpp>")
            self.w("#include <NumCpp/Functions/sum.hpp>")
            self.w("#include <NumCpp/Functions/mean.hpp>")
            self.w("#include <NumCpp/Functions/min.hpp>")
            self.w("#include <NumCpp/Functions/max.hpp>")
            self.w("#include <NumCpp/Linalg.hpp>")
            self.w("#ifdef _WIN32")
            self.w("#include <windows.h>")
            self.w("#endif")
            self.w("")
            self.w("// ── Oxybelis stdlib types ───")
            self.w("template<typename T> using List = std::vector<T>;")
            self.w("template<typename K,typename V> using Map = std::unordered_map<K,V>;")
            self.w("template<typename T> using Set = std::unordered_set<T>;")
            self.w("template<typename T> using Option = std::optional<T>;")
            self.w("")
            self.w("// ── make_list (initializer_list helper) ───")
            self.w("template<typename T>")
            self.w("List<T> _ox_make_list(std::initializer_list<T> il) {")
            self.depth = self.depth + 1
            self.w("return List<T>(il);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline List<std::string> _ox_make_list(std::initializer_list<const char*> il) {")
            self.depth = self.depth + 1
            self.w("List<std::string> r;")
            self.w("for (auto* s : il) r.push_back(std::string(s));")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
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
            self.w("// ── conversions ───")
            self.w("inline std::string str(const std::string& v){ return v; }")
            self.w("inline std::string str(const char* v){ return std::string(v); }")
            self.w("inline std::string str(int v) { return std::to_string(v); }")
            self.w("inline std::string str(long v) { return std::to_string(v); }")
            self.w("inline std::string str(unsigned long v) { return std::to_string(v); }")
            self.w("inline std::string str(long long v) { return std::to_string(v); }")
            self.w("inline std::string str(unsigned long long v) { return std::to_string(v); }")
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
            self.w("template<typename T> std::string str(const std::vector<T>& v){")
            self.depth = self.depth + 1
            self.w("std::string r=\"[\";")
            self.w("for(size_t i=0;i<v.size();i++){if(i)r+=\", \";r+=str(v[i]);}")
            self.w("return r+\"]\";")
            self.depth = self.depth - 1
            self.w("}")
            self.w("")
            self.w("// ── print ───")
            self.w("template<typename T> void print(const T& v) { std::cout << v << \"\\n\"; }")
            self.w("inline void print(bool v) { std::cout << (v ? \"true\" : \"false\") << \"\\n\"; }")
            self.w("inline void print(const std::string& v) { std::cout << v << \"\\n\"; }")
            self.w("template<typename T> void print(const std::vector<T>& v) {")
            self.depth = self.depth + 1
            self.w("std::cout << str(v) << \"\\n\";")
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
            self.w("template<typename T> size_t len(const std::unordered_set<T>& s){return s.size();}")
            self.w("template<typename T> void push(std::vector<T>& v,const T& x){v.push_back(x);}")
            self.w("template<typename T> T pop(std::vector<T>& v){T x=v.back();v.pop_back();return x;}")
            self.w("template<typename T> bool contains(const std::vector<T>& v, const T& x){")
            self.depth = self.depth + 1
            self.w("return std::find(v.begin(),v.end(),x)!=v.end();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> bool contains(const std::unordered_set<T>& s, const T& x){return s.find(x) != s.end();}")
            self.w("")
            self.w("template<typename K, typename V> bool map_contains(const std::unordered_map<K,V>& m, const K& k){ return m.count(k) > 0; }")
            self.w("template<typename K, typename V> V map_get(const std::unordered_map<K,V>& m, const K& k){ return m.at(k); }")
            self.w("template<typename K, typename V> void map_set(std::unordered_map<K,V>& m, const K& k, const V& v){ m[k] = v; }")
            self.w("template<typename T> void list_insert(std::vector<T>& v, int i, const T& x){ v.insert(v.begin() + i, x); }")
            self.w("template<typename T> T list_remove(std::vector<T>& v, int i){ T x = v[i]; v.erase(v.begin() + i); return x; }")
            self.w("template<typename T> std::string str(const std::unordered_set<T>& s){ std::string r=\"{\"; bool first=true; for(const auto &x: s){ if(!first) r+=\", \"; first=false; r+=str(x);} return r+\"}\"; }")
            self.w("template<typename T> void print(const std::unordered_set<T>& s){ std::cout<<str(s)<<std::endl; }")
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
            self.w("template<typename T> std::vector<T> _ox_sorted(const std::vector<T>& v, bool reverse = false){")
            self.depth = self.depth + 1
            self.w("std::vector<T> r(v);")
            self.w("if (!reverse) std::sort(r.begin(), r.end());")
            self.w("else std::sort(r.begin(), r.end(), std::greater<T>());")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("// ── itertools (List<T>) ───")
            self.w("template<typename T> std::vector<std::vector<T>> _ox_combinations(const std::vector<T>& v,int k){")
            self.depth = self.depth + 1
            self.w("std::vector<std::vector<T>> r; int n=(int)v.size();")
            self.w("if(k>n||k<=0)return r;")
            self.w("std::vector<int> idx(k); for(int i=0;i<k;i++)idx[i]=i;")
            self.w("while(true){")
            self.depth = self.depth + 1
            self.w("std::vector<T> c(k); for(int i=0;i<k;i++)c[i]=v[idx[i]]; r.push_back(c);")
            self.w("int i=k-1; while(i>=0&&idx[i]==n-k+i)i--;")
            self.w("if(i<0)break; idx[i]++;")
            self.w("for(int j=i+1;j<k;j++)idx[j]=idx[j-1]+1;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> std::vector<std::vector<T>> _ox_permutations(const std::vector<T>& v,int k){")
            self.depth = self.depth + 1
            self.w("std::vector<std::vector<T>> r; int n=(int)v.size();")
            self.w("if(k>n||k<=0)return r;")
            self.w("std::vector<int> idx(k); std::vector<bool> used(n,false);")
            self.w("std::function<void(int)> perm=[&](int pos){")
            self.depth = self.depth + 1
            self.w("if(pos==k){std::vector<T> p(k); for(int i=0;i<k;i++)p[i]=v[idx[i]]; r.push_back(p); return;}")
            self.w("for(int i=0;i<n;i++){if(!used[i]){used[i]=true; idx[pos]=i; perm(pos+1); used[i]=false;}}")
            self.depth = self.depth - 1
            self.w("};")
            self.w("perm(0); return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> std::vector<std::vector<T>> _ox_chunked(const std::vector<T>& v,int n){")
            self.depth = self.depth + 1
            self.w("std::vector<std::vector<T>> r; int sz=(int)v.size();")
            self.w("if(n<=0)return r;")
            self.w("for(int i=0;i<sz;i+=n){std::vector<T> chunk; int end=(i+n>sz)?sz:(i+n); for(int j=i;j<end;j++)chunk.push_back(v[j]); r.push_back(chunk);}")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> std::vector<std::vector<T>> _ox_windowed(const std::vector<T>& v,int n){")
            self.depth = self.depth + 1
            self.w("std::vector<std::vector<T>> r; int sz=(int)v.size();")
            self.w("if(n<=0||n>sz)return r;")
            self.w("for(int i=0;i<=sz-n;i++){std::vector<T> win; for(int j=i;j<i+n;j++)win.push_back(v[j]); r.push_back(win);}")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> std::vector<std::vector<T>> _ox_pairwise(const std::vector<T>& v){ return _ox_windowed(v,2); }")
            self.w("template<typename T> std::vector<T> _ox_reversed(const std::vector<T>& v){ return std::vector<T>(v.rbegin(),v.rend()); }")
            self.w("template<typename T> std::vector<T> _ox_cycle(const std::vector<T>& v,int n){")
            self.depth = self.depth + 1
            self.w("std::vector<T> r; r.reserve(v.size()*n); for(int i=0;i<n;i++){for(const auto& x:v)r.push_back(x);} return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> std::vector<T> _ox_take_while(const std::vector<T>& v,bool(*fn)(T)){")
            self.depth = self.depth + 1
            self.w("std::vector<T> r; for(const auto& x:v){if(!fn(x))break; r.push_back(x);} return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T> std::vector<T> _ox_drop_while(const std::vector<T>& v,bool(*fn)(T)){")
            self.depth = self.depth + 1
            self.w("std::vector<T> r; bool dropping=true; for(const auto& x:v){if(dropping&&fn(x))continue; dropping=false; r.push_back(x);} return r;")
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
            self.w("// ── Generator<T> ───")
            self.w("template<typename T>")
            self.w("class Generator {")
            self.depth = self.depth + 1
            self.w("public:")
            self.w("std::function<Option<T>()> _next_fn;")
            self.w("Generator() = default;")
            self.w("template<typename F> Generator(F fn) : _next_fn(std::move(fn)) {}")
            self.w("bool next() { auto r = _next_fn(); if (r) { _current = r; return true; } return false; }")
            self.w("T value() { return *_current; }")
            self.w("class Iterator {")
            self.depth = self.depth + 1
            self.w("public:")
            self.w("Generator* _gen; bool _done;")
            self.w("Iterator(Generator* gen, bool done) : _gen(gen), _done(done) {")
            self.depth = self.depth + 1
            self.w("if (!_done && _gen->_next_fn) { _done = !_gen->next(); }")
            self.depth = self.depth - 1
            self.w("}")
            self.w("T operator*() { return _gen->value(); }")
            self.w("bool operator!=(const Iterator& o) { return _done != o._done; }")
            self.w("Iterator& operator++() { _done = !_gen->next(); return *this; }")
            self.depth = self.depth - 1
            self.w("};")
            self.w("Iterator begin() { return Iterator(this, false); }")
            self.w("Iterator end() { return Iterator(this, true); }")
            self.depth = self.depth - 1
            self.w("private:")
            self.w("Option<T> _current;")
            self.depth = self.depth - 1
            self.w("};")
            self.w("template<typename T> std::string str(const Generator<T>& g){")
            self.depth = self.depth + 1
            self.w("(void)g; return \"<generator>\";")
            self.depth = self.depth - 1
            self.w("}")
            self.w("")
            self.w("inline int to_int(const std::string& s) { return std::stoi(s); }")
            self.w("inline double to_float(const std::string& s) { return std::stod(s); }")
            self.w("inline int parse_int(const std::string& s, int base) { return std::stoi(s, nullptr, base); }")
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
            self.w("inline std::vector<std::string> str_split(const std::string& s, const std::string& delim) {")
            self.depth = self.depth + 1
            self.w("std::vector<std::string> parts;")
            self.w("size_t start = 0, end;")
            self.w("while ((end = s.find(delim, start)) != std::string::npos) {")
            self.depth = self.depth + 1
            self.w("parts.push_back(s.substr(start, end - start));")
            self.w("start = end + delim.length();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("parts.push_back(s.substr(start));")
            self.w("return parts;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string str_trim(const std::string& s) {")
            self.depth = self.depth + 1
            self.w("size_t start = s.find_first_not_of(\" \\t\\n\\r\\f\\v\");")
            self.w("if (start == std::string::npos) return \"\";")
            self.w("size_t end = s.find_last_not_of(\" \\t\\n\\r\\f\\v\");")
            self.w("return s.substr(start, end - start + 1);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string str_trim_start(const std::string& s) {")
            self.depth = self.depth + 1
            self.w("size_t start = s.find_first_not_of(\" \\t\\n\\r\\f\\v\");")
            self.w("if (start == std::string::npos) return \"\";")
            self.w("return s.substr(start);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string str_trim_end(const std::string& s) {")
            self.depth = self.depth + 1
            self.w("size_t end = s.find_last_not_of(\" \\t\\n\\r\\f\\v\");")
            self.w("if (end == std::string::npos) return \"\";")
            self.w("return s.substr(0, end + 1);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string str_replace(const std::string& s, const std::string& old_str, const std::string& new_str) {")
            self.depth = self.depth + 1
            self.w("size_t pos = s.find(old_str);")
            self.w("if (pos == std::string::npos) return s;")
            self.w("std::string r = s;")
            self.w("return r.replace(pos, old_str.length(), new_str);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string str_replace_all(const std::string& s, const std::string& old_str, const std::string& new_str) {")
            self.depth = self.depth + 1
            self.w("std::string r = s;")
            self.w("size_t pos = 0;")
            self.w("while ((pos = r.find(old_str, pos)) != std::string::npos) {")
            self.depth = self.depth + 1
            self.w("r.replace(pos, old_str.length(), new_str);")
            self.w("pos += new_str.length();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string str_join(const std::vector<std::string>& v, const std::string& delim) {")
            self.depth = self.depth + 1
            self.w("std::string r;")
            self.w("for (size_t i = 0; i < v.size(); i++) {")
            self.depth = self.depth + 1
            self.w("if (i) r += delim;")
            self.w("r += v[i];")
            self.depth = self.depth - 1
            self.w("}")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string to_upper(const std::string& s) {")
            self.depth = self.depth + 1
            self.w("std::string r = s;")
            self.w("for (auto& c : r) c = std::toupper((unsigned char)c);")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string to_lower(const std::string& s) {")
            self.depth = self.depth + 1
            self.w("std::string r = s;")
            self.w("for (auto& c : r) c = std::tolower((unsigned char)c);")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline bool starts_with(const std::string& s, const std::string& prefix) {")
            self.depth = self.depth + 1
            self.w("return s.find(prefix) == 0;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline bool ends_with(const std::string& s, const std::string& suffix) {")
            self.depth = self.depth + 1
            self.w("if (suffix.size() > s.size()) return false;")
            self.w("return s.rfind(suffix) == s.size() - suffix.size();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string str_repeat(const std::string& s, int n) {")
            self.depth = self.depth + 1
            self.w("std::string r;")
            self.w("for (int i = 0; i < n; i++) r += s;")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string str_reverse(const std::string& s) {")
            self.depth = self.depth + 1
            self.w("return std::string(s.rbegin(), s.rend());")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::optional<int> str_find(const std::string& s, const std::string& sub) {")
            self.depth = self.depth + 1
            self.w("size_t pos = s.find(sub);")
            self.w("if (pos == std::string::npos) return std::nullopt;")
            self.w("return static_cast<int>(pos);")
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
            self.w("inline void panic(const std::string& msg) {")
            self.depth = self.depth + 1
            self.w("std::cerr << msg << std::endl; std::abort();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline void ox_assert(bool cond) {")
            self.depth = self.depth + 1
            self.w("if (!cond) { std::cerr << \"Assertion failed\" << std::endl; std::abort(); }")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::string read_line() {")
            self.depth = self.depth + 1
            self.w("std::string line; std::getline(std::cin, line); return line;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline void eprint(const std::string& msg) { std::cerr << msg; }")
            self.w("// ── str_format ──")
            self.w("inline std::string str_format(const std::string& fmt, const std::vector<std::string>& args) {")
            self.depth = self.depth + 1
            self.w("std::string r; size_t ai = 0;")
            self.w("for (size_t i = 0; i < fmt.size(); i++) {")
            self.depth = self.depth + 1
            self.w("if (fmt[i] == '{' && i + 1 < fmt.size() && fmt[i + 1] == '}') {")
            self.depth = self.depth + 1
            self.w("r += (ai < args.size()) ? args[ai++] : std::string(); ++i;")
            self.depth = self.depth - 1
            self.w("} else if (fmt[i] == '{' && i + 1 < fmt.size() && fmt[i + 1] == ':') {")
            self.depth = self.depth + 1
            self.w("size_t end = fmt.find('}', i + 2);")
            self.w("if (end == std::string::npos) { r += fmt[i]; continue; }")
            self.w("std::string spec = fmt.substr(i + 2, end - i - 2);")
            self.w("std::string val = (ai < args.size()) ? args[ai++] : std::string();")
            self.w("char align = 0; size_t width = 0; int precision = -1; char type = 0; size_t pos = 0;")
            self.w("if (pos < spec.size() && (spec[pos] == '<' || spec[pos] == '>' || spec[pos] == '^')) { align = spec[pos++]; }")
            self.w("while (pos < spec.size() && isdigit(spec[pos])) { width = width * 10 + (spec[pos++] - '0'); }")
            self.w("if (pos < spec.size() && spec[pos] == '.') { pos++; precision = 0; while (pos < spec.size() && isdigit(spec[pos])) { precision = precision * 10 + (spec[pos++] - '0'); } }")
            self.w("if (pos < spec.size()) { type = spec[pos++]; }")
            self.w("std::string formatted;")
            self.w("if (type == 'f' || type == 'F') {")
            self.depth = self.depth + 1
            self.w("std::ostringstream oss; oss << std::fixed;")
            self.w("if (precision >= 0) oss << std::setprecision(precision);")
            self.w("try { double d = std::stod(val); oss << d; } catch (...) { oss << val; }")
            self.w("formatted = oss.str();")
            self.depth = self.depth - 1
            self.w("} else if (type == 'e') {")
            self.depth = self.depth + 1
            self.w("std::ostringstream oss; oss << std::scientific;")
            self.w("if (precision >= 0) oss << std::setprecision(precision);")
            self.w("try { oss << std::stod(val); } catch (...) { oss << val; }")
            self.w("formatted = oss.str();")
            self.depth = self.depth - 1
            self.w("} else if (type == 'E') {")
            self.depth = self.depth + 1
            self.w("std::ostringstream oss; oss << std::scientific << std::uppercase;")
            self.w("if (precision >= 0) oss << std::setprecision(precision);")
            self.w("try { oss << std::stod(val); } catch (...) { oss << val; }")
            self.w("formatted = oss.str();")
            self.depth = self.depth - 1
            self.w("} else if (type == 'x') {")
            self.depth = self.depth + 1
            self.w("std::ostringstream oss; oss << std::hex;")
            self.w("try { oss << std::stoi(val); } catch (...) { oss << val; }")
            self.w("formatted = oss.str();")
            self.depth = self.depth - 1
            self.w("} else if (type == 'X') {")
            self.depth = self.depth + 1
            self.w("std::ostringstream oss; oss << std::hex << std::uppercase;")
            self.w("try { oss << std::stoi(val); } catch (...) { oss << val; }")
            self.w("formatted = oss.str();")
            self.depth = self.depth - 1
            self.w("} else if (type == 'o') {")
            self.depth = self.depth + 1
            self.w("std::ostringstream oss; oss << std::oct;")
            self.w("try { oss << std::stoi(val); } catch (...) { oss << val; }")
            self.w("formatted = oss.str();")
            self.depth = self.depth - 1
            self.w("} else if (type == 'b') {")
            self.depth = self.depth + 1
            self.w("try { int n = std::stoi(val); std::string b; do { b = char('0' + (n & 1)) + b; n >>= 1; } while (n); formatted = b; } catch (...) { formatted = val; }")
            self.depth = self.depth - 1
            self.w("} else { formatted = val; }")
            self.w("if (width > 0 && formatted.size() < width) {")
            self.depth = self.depth + 1
            self.w("size_t pad = width - formatted.size();")
            self.w("if (align == '^') { formatted = std::string(pad/2,' ') + formatted + std::string(pad-pad/2,' '); }")
            self.w("else if (align == '>') { formatted = std::string(pad,' ') + formatted; }")
            self.w("else { formatted = formatted + std::string(pad,' '); }")
            self.depth = self.depth - 1
            self.w("}")
            self.w("r += formatted; i = end;")
            self.depth = self.depth - 1
            self.w("} else if (fmt[i] == '}' && i + 1 < fmt.size() && fmt[i + 1] == '}') {")
            self.depth = self.depth + 1
            self.w("r += '}'; ++i;")
            self.depth = self.depth - 1
            self.w("} else { r += fmt[i]; }")
            self.depth = self.depth - 1
            self.w("}")
            self.w("return r;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("// ── random ───")
            self.w("static std::mt19937 _ox_rng(std::random_device{}());")
            self.w("inline int _ox_randint(int min, int max) {")
            self.depth = self.depth + 1
            self.w("std::uniform_int_distribution<int> dist(min, max); return dist(_ox_rng);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline double _ox_randfloat() {")
            self.depth = self.depth + 1
            self.w("std::uniform_real_distribution<double> dist(0.0, 1.0); return dist(_ox_rng);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline void _ox_randseed(unsigned int seed) { _ox_rng.seed(seed); }")
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
            self.w("// ── math helpers ───")
            self.w("template<typename T>")
            self.w("nc::NdArray<T> _ox_math_to_ndarray(const std::vector<T>& v) {")
            self.depth = self.depth + 1
            self.w("return nc::NdArray<T>(v.begin(), v.end());")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T>")
            self.w("std::vector<T> _ox_math_from_ndarray(const nc::NdArray<T>& arr) {")
            self.depth = self.depth + 1
            self.w("return arr.toStlVector();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T>")
            self.w("nc::NdArray<T> _ox_math_to_ndarray_2d(const std::vector<std::vector<T>>& v) {")
            self.depth = self.depth + 1
            self.w("return nc::NdArray<T>(v);")
            self.depth = self.depth - 1
            self.w("}")
            self.w("template<typename T>")
            self.w("std::vector<std::vector<T>> _ox_math_from_ndarray_2d(const nc::NdArray<T>& arr) {")
            self.depth = self.depth + 1
            self.w("std::vector<std::vector<T>> result(arr.numRows(), std::vector<T>(arr.numCols()));")
            self.w("for (int32_t r = 0; r < arr.numRows(); ++r)")
            self.w("    for (int32_t c = 0; c < arr.numCols(); ++c)")
            self.w("        result[r][c] = arr(r, c);")
            self.w("return result;")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_zeros(int n) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::zeros<double>(1, static_cast<nc::uint32>(n)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_ones(int n) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::ones<double>(1, static_cast<nc::uint32>(n)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_linspace(double start, double end, int n) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::linspace(start, end, static_cast<nc::uint32>(n)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_arange(double start, double end, double step) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::arange(start, end, step));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline double _ox_math_dot(const std::vector<double>& a, const std::vector<double>& b) {")
            self.depth = self.depth + 1
            self.w("return nc::dot(_ox_math_to_ndarray(a), _ox_math_to_ndarray(b)).item();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<std::vector<double>> _ox_math_matmul(")
            self.depth = self.depth + 1
            self.w("const std::vector<std::vector<double>>& a, const std::vector<std::vector<double>>& b) {")
            self.w("return _ox_math_from_ndarray_2d(")
            self.w("    nc::matmul(_ox_math_to_ndarray_2d(a), _ox_math_to_ndarray_2d(b)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<std::vector<double>> _ox_math_transpose(")
            self.depth = self.depth + 1
            self.w("const std::vector<std::vector<double>>& a) {")
            self.w("return _ox_math_from_ndarray_2d(_ox_math_to_ndarray_2d(a).transpose());")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline double _ox_math_norm(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return nc::norm(_ox_math_to_ndarray(a)).item();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<std::vector<double>> _ox_math_inv(")
            self.depth = self.depth + 1
            self.w("const std::vector<std::vector<double>>& a) {")
            self.w("return _ox_math_from_ndarray_2d(nc::linalg::inv(_ox_math_to_ndarray_2d(a)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline double _ox_math_det(const std::vector<std::vector<double>>& a) {")
            self.depth = self.depth + 1
            self.w("return nc::linalg::det(_ox_math_to_ndarray_2d(a));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_solve(")
            self.depth = self.depth + 1
            self.w("const std::vector<std::vector<double>>& A, const std::vector<double>& b) {")
            self.w("return _ox_math_from_ndarray(")
            self.w("    nc::linalg::solve(_ox_math_to_ndarray_2d(A), _ox_math_to_ndarray(b)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_sin(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::sin(_ox_math_to_ndarray(a)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_cos(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::cos(_ox_math_to_ndarray(a)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_tan(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::tan(_ox_math_to_ndarray(a)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_sqrt(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::sqrt(_ox_math_to_ndarray(a)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_abs(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::abs(_ox_math_to_ndarray(a)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_exp(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::exp(_ox_math_to_ndarray(a)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_log(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::log(_ox_math_to_ndarray(a)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_floor(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::floor(_ox_math_to_ndarray(a)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_ceil(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(nc::ceil(_ox_math_to_ndarray(a)));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_add(const std::vector<double>& a, const std::vector<double>& b) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(_ox_math_to_ndarray(a) + _ox_math_to_ndarray(b));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_sub(const std::vector<double>& a, const std::vector<double>& b) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(_ox_math_to_ndarray(a) - _ox_math_to_ndarray(b));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_mul(const std::vector<double>& a, const std::vector<double>& b) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(_ox_math_to_ndarray(a) * _ox_math_to_ndarray(b));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_div(const std::vector<double>& a, const std::vector<double>& b) {")
            self.depth = self.depth + 1
            self.w("return _ox_math_from_ndarray(_ox_math_to_ndarray(a) / _ox_math_to_ndarray(b));")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline double _ox_math_sum(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return nc::sum(_ox_math_to_ndarray(a)).item();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline double _ox_math_mean(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return nc::mean(_ox_math_to_ndarray(a)).item();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline double _ox_math_min(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return nc::min(_ox_math_to_ndarray(a)).item();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline double _ox_math_max(const std::vector<double>& a) {")
            self.depth = self.depth + 1
            self.w("return nc::max(_ox_math_to_ndarray(a)).item();")
            self.depth = self.depth - 1
            self.w("}")
            self.w("inline std::vector<double> _ox_math_reshape(const std::vector<double>& a, int rows, int cols) {")
            self.depth = self.depth + 1
            self.w("auto arr = _ox_math_to_ndarray(a);")
            self.w("arr.reshape(rows, cols);")
            self.w("return _ox_math_from_ndarray(arr);")
            self.depth = self.depth - 1
            self.w("}")
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
        // Forward-declare free functions for C++ single-pass compilation
        i = 0
        while i < len(prog.stmts) {
            let n = node_pool[prog.stmts[i]]
            if n.kind == "FnDef" and n.name != "main" {
                if len(n.generics) > 0 {
                    var tmpl: str = "template<"
                    var ti = 0
                    while ti < len(n.generics) {
                        if ti > 0 { tmpl = tmpl + ", " }
                        tmpl = tmpl + "typename " + node_pool[n.generics[ti]].str_val
                        ti = ti + 1
                    }
                    tmpl = tmpl + ">"
                    self.w(tmpl)
                }
                var ps: str = ""
                var pi = 0
                while pi < len(n.params) {
                    if pi > 0 { ps = ps + ", " }
                    let p = node_pool[n.params[pi]]
                    ps = ps + map_type(p.type_ann) + " " + p.name
                    pi = pi + 1
                }
                self.w(map_type(n.return_type) + " " + n.name + "(" + ps + ");")
            }
            i = i + 1
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

// ── TypeChecker ─────────────────────────────────────────────
class Binding {
    name: str
    ty: str
}

fn substitute_type_params(t: str, bindings: List<Binding>) -> str {
    var bi = 0
    while bi < len(bindings) {
        if bindings[bi].name == t { return bindings[bi].ty }
        bi = bi + 1
    }
    var i = 0
    while i < len(t) {
        if str_get(t, i) == "<" {
            let outer: str = str_sub(t, 0, i)
            let inner_start = i + 1
            let inner_end = len(t) - 1
            let args: List<str> = split_args(str_sub(t, inner_start, inner_end))
            var substituted: str = outer + "<"
            var j = 0
            while j < len(args) {
                if j > 0 { substituted = substituted + ", " }
                substituted = substituted + substitute_type_params(args[j], bindings)
                j = j + 1
            }
            return substituted + ">"
        }
        i = i + 1
    }
    return t
}

class TypeChecker {
    src: str
    source_path: str
    diags: List<Diagnostic>
    scopes: List<List<Binding>>
    // Function registry
    fn_names: List<str>
    fn_param_types: List<List<str>>
    fn_rets: List<str>
    fn_nodes: List<int>
    // Class registry
    cls_names: List<str>
    cls_field_names: List<List<str>>
    cls_field_types: List<List<str>>
    // Context
    in_fn_ret: str
    in_class: str
    generic_params: List<str>
    type_bindings: List<Binding>

    fn _bi(self, name: str, param_types: List<str>, ret: str) -> void {
        push(self.fn_names, name)
        push(self.fn_param_types, param_types)
        push(self.fn_rets, ret)
        push(self.fn_nodes, -1)
    }

    fn init_builtins(self) -> void {
        self._bi("print", [], "void")
        self._bi("len",     ["void"], "int")
        self._bi("push",    ["void", "void"], "void")
        self._bi("pop",     ["void"], "void")
        self._bi( "range",   ["int", "int"], "List<int>")
        self._bi( "str",     ["void"], "str")
        self._bi( "int",     ["void"], "int")
        self._bi( "float",   ["void"], "float")
        self._bi( "bool",    ["void"], "bool")
        self._bi( "sqrt",    ["float"], "float")
        self._bi( "abs",     ["float"], "float")
        self._bi( "pow",     ["float", "float"], "float")
        self._bi( "sin",     ["float"], "float")
        self._bi( "cos",     ["float"], "float")
        self._bi( "tan",     ["float"], "float")
        self._bi( "floor",   ["float"], "float")
        self._bi( "ceil",    ["float"], "float")
        self._bi( "round",   ["float"], "float")
        self._bi( "log",     ["float"], "float")
        self._bi( "exp",     ["float"], "float")
        self._bi( "min",     ["int", "int"], "int")
        self._bi( "max",     ["int", "int"], "int")
        self._bi( "contains",["void", "void"], "bool")
        self._bi( "read_file",   ["str"], "str")
        self._bi( "read_lines",  ["str"], "List<str>")
        self._bi( "write_file",  ["str", "str"], "void")
        self._bi( "exec",    ["str"], "int")
        self._bi( "exit",    ["int"], "void")
        self._bi( "to_int",  ["str"], "int")
        self._bi( "to_float",["str"], "float")
        self._bi( "parse_int", ["str", "int"], "int")
        self._bi( "str_get", ["str", "int"], "str")
        self._bi( "str_sub", ["str", "int", "int"], "str")
        self._bi( "str_contains", ["str", "str"], "bool")
        self._bi( "args",    [], "List<str>")
        self._bi( "is_digit", ["str"], "bool")
        self._bi( "is_alpha", ["str"], "bool")
        self._bi( "is_alnum", ["str"], "bool")
        self._bi( "str_split",   ["str", "str"], "List<str>")
        self._bi( "str_trim",    ["str"], "str")
        self._bi( "str_trim_start", ["str"], "str")
        self._bi( "str_trim_end",   ["str"], "str")
        self._bi( "str_replace",    ["str", "str", "str"], "str")
        self._bi( "str_replace_all", ["str", "str", "str"], "str")
        self._bi( "str_join",  ["List<str>", "str"], "str")
        self._bi( "to_upper",  ["str"], "str")
        self._bi( "to_lower",  ["str"], "str")
        self._bi( "starts_with", ["str", "str"], "bool")
        self._bi( "ends_with",   ["str", "str"], "bool")
        self._bi( "str_repeat",  ["str", "int"], "str")
        self._bi( "str_reverse", ["str"], "str")
        self._bi( "str_find",    ["str", "str"], "Option<int>")
        self._bi( "map_contains", ["void", "void"], "bool")
        self._bi( "map_get",  ["void", "void"], "void")
        self._bi( "map_set",  ["void", "void", "void"], "void")
        self._bi( "set_contains", ["void", "void"], "bool")
        self._bi( "set_add",  ["void", "void"], "void")
        self._bi( "set_remove",  ["void", "void"], "void")
        self._bi( "set_union", ["void", "void"], "void")
        self._bi( "set_intersection", ["void", "void"], "void")
        self._bi( "set_difference", ["void", "void"], "void")
        self._bi( "set_symdiff", ["void", "void"], "void")
        self._bi( "set_is_subset", ["void", "void"], "bool")
        self._bi( "set_is_superset", ["void", "void"], "bool")
        self._bi( "list_insert", ["void", "int", "void"], "void")
        self._bi( "list_remove", ["void", "int"], "void")
        self._bi( "fs_exists",  ["str"], "bool")
        self._bi( "fs_is_file", ["str"], "bool")
        self._bi( "fs_is_dir",  ["str"], "bool")
        self._bi( "fs_mkdir",   ["str"], "void")
        self._bi( "fs_list_dir", ["str"], "List<str>")
        self._bi( "fs_remove",  ["str"], "void")
        self._bi( "fs_rename",  ["str", "str"], "void")
        self._bi( "fs_copy",    ["str", "str"], "void")
        self._bi( "fs_cwd",     [], "str")
        self._bi( "panic",      ["str"], "void")
        self._bi( "ox_assert",  ["bool"], "void")
        self._bi( "read_line",  [], "str")
        self._bi( "eprint",     ["str"], "void")
        self._bi( "str_format", ["str", "List<str>"], "str")
        self._bi( "_ox_randint",  ["int", "int"], "int")
        self._bi( "_ox_randfloat", [], "float")
        self._bi( "_ox_randseed",  ["int"], "void")
    }

    fn push_scope(self) -> void {
        push(self.scopes, [])
    }

    fn pop_scope(self) -> void {
        if len(self.scopes) > 0 { pop(self.scopes) }
    }

    fn declare_var(self, name: str, ty: str) -> void {
        if len(self.scopes) == 0 { return }
        let si = len(self.scopes) - 1
        var exists = false
        var i = 0
        while i < len(self.scopes[si]) {
            if self.scopes[si][i].name == name { exists = true; break }
            i = i + 1
        }
        if exists {
            push(self.diags, make_diag(OX_SEVERITY_ERROR,
                "variable `" + name + "` already declared in this scope", "E0002", 0, 0))
            return
        }
        push(self.scopes[si], Binding { name: name, ty: ty })
    }

    fn lookup_var(self, name: str) -> str {
        var si = len(self.scopes)
        while si > 0 {
            si = si - 1
            let scope = self.scopes[si]
            var i = 0
            while i < len(scope) {
                if scope[i].name == name { return scope[i].ty }
                i = i + 1
            }
        }
        return ""
    }

    fn find_fn(self, name: str) -> int {
        var i = 0
        while i < len(self.fn_names) {
            if self.fn_names[i] == name { return i }
            i = i + 1
        }
        return -1
    }

    fn find_fn_all(self, name: str) -> List<int> {
        let result: List<int> = []
        var i = 0
        while i < len(self.fn_names) {
            if self.fn_names[i] == name { push(result, i) }
            i = i + 1
        }
        return result
    }

    fn resolve_fn_call(self, name: str, arg_types: List<str>) -> int {
        let candidates = self.find_fn_all(name)
        if len(candidates) == 0 { return -1 }
        if len(candidates) == 1 { return candidates[0] }
        // Multiple candidates: filter by arity first
        var arity_match: List<int> = []
        var ci = 0
        while ci < len(candidates) {
            if len(self.fn_param_types[candidates[ci]]) == len(arg_types) {
                push(arity_match, candidates[ci])
            }
            ci = ci + 1
        }
        if len(arity_match) == 0 {
            return candidates[0]  // for error reporting
        }
        if len(arity_match) == 1 {
            return arity_match[0]
        }
        // Multiple arity matches: score by param type compatibility
        var best_idx = arity_match[0]
        var best_score = -1
        ci = 0
        while ci < len(arity_match) {
            let fi = arity_match[ci]
            let pts = self.fn_param_types[fi]
            var score = 0
            var pi = 0
            while pi < len(pts) {
                if pts[pi] == arg_types[pi] { score = score + 2 }
                elif self.is_compatible(arg_types[pi], pts[pi]) { score = score + 1 }
                pi = pi + 1
            }
            if score > best_score { best_score = score; best_idx = fi }
            ci = ci + 1
        }
        return best_idx
    }

    fn find_cls(self, name: str) -> int {
        var i = 0
        while i < len(self.cls_names) {
            if self.cls_names[i] == name { return i }
            i = i + 1
        }
        return -1
    }

    fn infer_type_bindings(self, expected: str, found: str) -> void {
        if self.is_generic(expected) {
            var bi = 0
            while bi < len(self.type_bindings) {
                if self.type_bindings[bi].name == expected {
                    if self.type_bindings[bi].ty != found {
                        self.err("type mismatch for `" + expected + "`: inferred `" +
                            self.type_bindings[bi].ty + "` and `" + found + "`", 0, "E0308")
                    }
                    return
                }
                bi = bi + 1
            }
            push(self.type_bindings, Binding { name: expected, ty: found })
            return
        }
        if base_type(expected) == base_type(found) {
            let e_params = type_params(expected)
            let f_params = type_params(found)
            if len(e_params) > 0 and len(e_params) == len(f_params) {
                var i = 0
                while i < len(e_params) {
                    self.infer_type_bindings(e_params[i], f_params[i])
                    i = i + 1
                }
            }
        }
    }

    fn is_generic(self, name: str) -> bool {
        var i = 0
        while i < len(self.generic_params) {
            if self.generic_params[i] == name { return true }
            i = i + 1
        }
        return false
    }

    // ── Main check entry ──
    fn check(self, prog_id: int) -> void {
        self.init_builtins()
        self.push_scope()  // global scope

        let prog = node_pool[prog_id]
        // First pass: collect function and class signatures
        var si = 0
        while si < len(prog.stmts) {
            let s = node_pool[prog.stmts[si]]
            if s.kind == "FnDef" {
                var pt_types: List<str> = []
                var pi = 0
                while pi < len(s.params) {
                    push(pt_types, node_pool[s.params[pi]].type_ann)
                    pi = pi + 1
                }
                push(self.fn_names, s.name)
                push(self.fn_param_types, pt_types)
                push(self.fn_rets, s.return_type)
                push(self.fn_nodes, prog.stmts[si])
            }
            if s.kind == "ClassDef" {
                push(self.cls_names, s.name)
                var fns: List<str> = []
                var fts: List<str> = []
                var fi = 0
                while fi < len(s.fields) {
                    let f = node_pool[s.fields[fi]]
                    push(fns, f.name)
                    push(fts, f.type_ann)
                    fi = fi + 1
                }
                var mi = 0
                while mi < len(s.methods) {
                    let m = node_pool[s.methods[mi]]
                    push(fns, m.name)
                    push(fts, m.return_type)
                    mi = mi + 1
                }
                push(self.cls_field_names, fns)
                push(self.cls_field_types, fts)
            }
            si = si + 1
        }

        // Second pass: check top-level statements
        si = 0
        while si < len(prog.stmts) {
            self.check_stmt(prog.stmts[si])
            si = si + 1
        }
    }

    // ── Type inference ──
    fn infer_type(self, node_id: int) -> str {
        let t = self.infer_type_impl(node_id)
        node_pool[node_id].node_type = t
        return t
    }

    fn infer_type_impl(self, node_id: int) -> str {
        let node = node_pool[node_id]
        if node.kind == "IntLit"    { return "int" }
        if node.kind == "FloatLit"  { return "float" }
        if node.kind == "StrLit"    { return "str" }
        if node.kind == "BoolLit"   { return "bool" }
        if node.kind == "NoneLit"   { return "Option<void>" }
        if node.kind == "WildCard"  { return "_" }
        if node.kind == "SomeLit" {
            let inner = self.infer_type(node.inner)
            return "Option<" + inner + ">"
        }
        if node.kind == "ListLit" {
            var et: str = "void"
            if len(node.elems) > 0 { et = self.infer_type(node.elems[0]) }
            var i = 1
            while i < len(node.elems) {
                self.infer_type(node.elems[i])
                i = i + 1
            }
            return "List<" + et + ">"
        }
        if node.kind == "Ident" {
            if node.name == "true" or node.name == "false" { return "bool" }
            if node.name == "self" {
                if self.in_class != "" { return self.in_class }
                self.err("`self` is only valid inside class methods", node_id, "E0401")
                return "void"
            }
            let ty = self.lookup_var(node.name)
            if ty != "" { return ty }
            if self.find_fn(node.name) >= 0 { return "fn" }
            if self.find_cls(node.name) >= 0 { return "type" }
            self.err("cannot find value `" + node.name + "` in this scope", node_id, "E0425")
            return "void"
        }
        if node.kind == "BinOp" {
            let lt = self.infer_type(node.left)
            let rt = self.infer_type(node.right)
            if node.op == "==" or node.op == "!=" { return "bool" }
            if node.op == "<" or node.op == ">" or node.op == "<=" or node.op == ">=" {
                if (lt == "int" or lt == "float") and (rt == "int" or rt == "float") { return "bool" }
                self.type_err("int|float", rt, node.right)
                return "bool"
            }
            if node.op == "and" or node.op == "or" {
                if lt == "bool" and rt == "bool" { return "bool" }
                self.type_err("bool", lt, node.left)
                return "bool"
            }
            if node.op == "+" or node.op == "-" or node.op == "*" or node.op == "/" or node.op == "%" {
                if (lt == "int" or lt == "float") and (rt == "int" or rt == "float") {
                    if lt == rt { return lt }
                    return "float"
                }
                if lt == "str" and node.op == "+" { return "str" }
                self.type_err("int|float|str", lt + " " + node.op + " " + rt, node_id)
                return lt
            }
            return "void"
        }
        if node.kind == "UnaryOp" {
            let ot = self.infer_type(node.operand)
            if node.op == "-" or node.op == "!" {
                if ot == "int" or ot == "float" or ot == "bool" { return ot }
                self.type_err("int|float|bool", ot, node.operand)
            }
            return ot
        }
        if node.kind == "FnCall" {
            let fn_expr = node_pool[node.func]
            if fn_expr.kind == "Ident" and fn_expr.name == "Ok" {
                if len(node.args) > 0 {
                    let inner = self.infer_type(node.args[0])
                    return "Result<" + inner + ", void>"
                }
                return "Result<void, void>"
            }
            if fn_expr.kind == "Ident" and fn_expr.name == "Err" {
                if len(node.args) > 0 {
                    let inner = self.infer_type(node.args[0])
                    return "Result<void, " + inner + ">"
                }
                return "Result<void, void>"
            }
            if fn_expr.kind == "Ident" {
                let fn_name = fn_expr.name
                // Phase 1: Infer arg types independently (before generic context)
                var arg_types: List<str> = []
                var ai = 0
                while ai < len(node.args) {
                    push(arg_types, self.infer_type(node.args[ai]))
                    ai = ai + 1
                }
                // Phase 2: Resolve best overload match
                let fi = self.resolve_fn_call(fn_name, arg_types)
                if fi >= 0 {
                    let pts = self.fn_param_types[fi]
                    let ret = self.fn_rets[fi]
                    // Phase 3: Set up callee's generic params for binding inference
                    let fn_node_id = self.fn_nodes[fi]
                    let old_generic = self.generic_params
                    if fn_node_id >= 0 {
                        let fn_node = node_pool[fn_node_id]
                        var gp: List<str> = []
                        var gi = 0
                        while gi < len(fn_node.generics) {
                            push(gp, node_pool[fn_node.generics[gi]].str_val)
                            gi = gi + 1
                        }
                        self.generic_params = gp
                    }
                    // Phase 4: Check arg compatibility (print is variadic)
                    if fn_name == "print" {
                        self.generic_params = old_generic
                        return "void"
                    }
                    var expected = len(pts)
                    if len(node.args) != expected {
                        self.err("function `" + fn_name + "` takes " + str(expected) +
                            " arguments but " + str(len(node.args)) + " were given",
                            node_id, "E0060")
                        self.generic_params = old_generic
                        return ret
                    }
                    ai = 0
                    while ai < len(node.args) {
                        let ptype = pts[ai]
                        if ptype != "void" and not self.is_compatible(arg_types[ai], ptype) {
                            self.type_err(ptype, arg_types[ai], node.args[ai])
                        }
                        ai = ai + 1
                    }
                    // Phase 5: Build type bindings for generic inference
                    self.type_bindings = []
                    ai = 0
                    while ai < len(node.args) {
                        let ptype = pts[ai]
                        if ptype != "void" {
                            self.infer_type_bindings(ptype, arg_types[ai])
                        }
                        ai = ai + 1
                    }
                    let concrete_ret = ret
                    if len(self.type_bindings) > 0 {
                        concrete_ret = substitute_type_params(ret, self.type_bindings)
                    }
                    self.generic_params = old_generic
                    return concrete_ret
                }
            }
            // Fallback: generic call or method on type
            var ai = 0
            while ai < len(node.args) { self.infer_type(node.args[ai]); ai = ai + 1 }
            self.infer_type(node.func)
            return "void"
        }
        if node.kind == "MethodCall" {
            let obj_t = self.infer_type(node.obj)
            var ai = 0
            while ai < len(node.args) { self.infer_type(node.args[ai]); ai = ai + 1 }
            let base = base_type(obj_t)
            // Try class methods
            let ci = self.find_cls(base)
            if ci >= 0 {
                var mi = 0
                while mi < len(self.cls_field_names[ci]) {
                    if self.cls_field_names[ci][mi] == node.name {
                        return self.cls_field_types[ci][mi]
                    }
                    mi = mi + 1
                }
            }
            // Built-in list chaining methods
            if base == "List" {
                let params = type_params(obj_t)
                var elem_type: str = "void"
                if len(params) > 0 { elem_type = params[0] }
                if node.name == "map" {
                    // Try to infer return type from the passed function
                    if len(node.args) > 0 and node_pool[node.args[0]].kind == "Ident" {
                        let fn_name = node_pool[node.args[0]].name
                        let fi2 = self.find_fn(fn_name)
                        if fi2 >= 0 { return "List<" + self.fn_rets[fi2] + ">" }
                    }
                    return "List<" + elem_type + ">"
                }
                if node.name == "filter" or node.name == "take_while" or node.name == "drop_while" {
                    return "List<" + elem_type + ">"
                }
                if node.name == "reduce" {
                    if len(node.args) > 0 { return self.infer_type(node.args[0]) }
                    return elem_type
                }
                if node.name == "for_each" or node.name == "each" { return "void" }
                if node.name == "any" or node.name == "all" { return "bool" }
                if node.name == "find" { return "Option<" + elem_type + ">" }
                if node.name == "sum" or node.name == "min" or node.name == "max" { return elem_type }
                if node.name == "reversed" or node.name == "cycle" { return "List<" + elem_type + ">" }
                if node.name == "combinations" or node.name == "permutations" or
                   node.name == "chunked" or node.name == "windowed" or node.name == "pairwise" {
                    return "List<List<" + elem_type + ">>"
                }
            }
            return "void"
        }
        if node.kind == "Attr" {
            let obj_t = self.infer_type(node.obj)
            let base = base_type(obj_t)
            let ci = self.find_cls(base)
            if ci >= 0 {
                var fi = 0
                while fi < len(self.cls_field_names[ci]) {
                    if self.cls_field_names[ci][fi] == node.name {
                        return self.cls_field_types[ci][fi]
                    }
                    fi = fi + 1
                }
                // Check methods
                // methods were not stored; skip for now
            }
            if base == "Option" and node.name == "value" {
                let params = type_params(obj_t)
                if len(params) > 0 { return params[0] }
                return "void"
            }
            return "void"
        }
        if node.kind == "Index" {
            let obj_t = self.infer_type(node.obj)
            self.infer_type(node.start)
            let base = base_type(obj_t)
            if base == "List" {
                let params = type_params(obj_t)
                if len(params) > 0 { return params[0] }
                return "void"
            }
            if base == "str" { return "str" }
            if base == "Map" {
                let params = type_params(obj_t)
                if len(params) > 1 { return params[1] }
                return "void"
            }
            self.type_err("List|str|Map", obj_t, node.obj)
            return "void"
        }
        if node.kind == "StructLit" {
            var fi = 0
            while fi < len(node.fields) { self.infer_type(node_pool[node.fields[fi]].inner); fi = fi + 1 }
            let base = base_type(node.type_name)
            if self.find_cls(base) >= 0 { return node.type_name }
            self.err("no class named `" + node.type_name + "`", node_id, "E0412")
            return node.type_name
        }
        if node.kind == "RangeLit" { return "List<int>" }
        if node.kind == "TryOp" {
            let inner = self.infer_type(node.operand)
            let base = base_type(inner)
            let params = type_params(inner)
            if base == "Result" or base == "Option" {
                if len(params) > 0 { return params[0] }
                return "void"
            }
            self.type_err("Result or Option", inner, node.operand)
            return "void"
        }
        if node.kind == "VarDecl" {
            if node.type_ann != "" {
                if node.inner >= 0 {
                    let vt = self.infer_type(node.inner)
                    if not self.is_compatible(vt, node.type_ann) {
                        self.type_err(node.type_ann, vt, node.inner)
                    }
                }
                return node.type_ann
            }
            if node.inner >= 0 { return self.infer_type(node.inner) }
            return "void"
        }
        return "void"
    }

    fn is_compatible(self, found: str, expected: str) -> bool {
        if found == expected { return true }
        if self.is_generic(expected) or self.is_generic(found) { return true }
        if base_type(found) == base_type(expected) { return true }
        if expected == "float" and found == "int" { return true }
        if expected == "Option<void>" and found == "Option<void>" { return true }
        if starts_with(expected, "Option<") and found == "Option<void>" { return true }
        return false
    }

    fn check_stmt(self, node_id: int) -> void {
        let node = node_pool[node_id]
        if node.kind == "VarDecl" {
            if node.inner >= 0 {
                let vt = self.infer_type(node.inner)
                if node.type_ann != "" and not self.is_compatible(vt, node.type_ann) {
                    self.type_err(node.type_ann, vt, node.inner)
                }
                let resolved = node.type_ann
                if resolved == "" { resolved = vt }
                self.declare_var(node.name, resolved)
            } else {
                if node.type_ann != "" { self.declare_var(node.name, node.type_ann) }
                else { self.declare_var(node.name, "void") }
            }
        } elif node.kind == "Assignment" {
            let tt = self.infer_type(node.target)
            let vt = self.infer_type(node.inner)
            if not self.is_compatible(vt, tt) {
                self.type_err(tt, vt, node.inner)
            }
        } elif node.kind == "ReturnStmt" {
            if node.inner >= 0 {
                let vt = self.infer_type(node.inner)
                if self.in_fn_ret != "" and not self.is_compatible(vt, self.in_fn_ret) {
                    self.type_err(self.in_fn_ret, vt, node.inner)
                }
            } elif self.in_fn_ret != "" and self.in_fn_ret != "void" {
                self.err("expected `" + self.in_fn_ret + "` return value", node_id, "E0057")
            }
        } elif node.kind == "YieldStmt" {
            if node.inner >= 0 { self.infer_type(node.inner) }
        } elif node.kind == "IfStmt" {
            self.infer_type(node.cond)
            self.push_scope()
            var si = 0
            while si < len(node.then_body) { self.check_stmt(node.then_body[si]); si = si + 1 }
            self.pop_scope()
            var ei = 0
            while ei < len(node.elif_clauses) {
                let elif_node = node_pool[node.elif_clauses[ei]]
                self.infer_type(elif_node.cond)
                self.push_scope()
                var esi = 0
                while esi < len(elif_node.then_body) { self.check_stmt(elif_node.then_body[esi]); esi = esi + 1 }
                self.pop_scope()
                ei = ei + 1
            }
            if len(node.else_body) > 0 {
                self.push_scope()
                var esi = 0
                while esi < len(node.else_body) { self.check_stmt(node.else_body[esi]); esi = esi + 1 }
                self.pop_scope()
            }
        } elif node.kind == "ForStmt" {
            let iter_t = self.infer_type(node.iterable)
            self.push_scope()
            var var_type: str = "void"
            if node_pool[node.iterable].kind == "RangeLit" { var_type = "int" }
            else {
                let base = base_type(iter_t)
                if base == "List" or base == "Map" or base == "str" {
                    let params = type_params(iter_t)
                    if len(params) > 0 { var_type = params[0] }
                }
            }
            self.declare_var(node.var_name, var_type)
            var si = 0
            while si < len(node.body) { self.check_stmt(node.body[si]); si = si + 1 }
            self.pop_scope()
        } elif node.kind == "WhileStmt" {
            self.infer_type(node.cond)
            self.push_scope()
            var si = 0
            while si < len(node.body) { self.check_stmt(node.body[si]); si = si + 1 }
            self.pop_scope()
        } elif node.kind == "MatchStmt" {
            self.infer_type(node.subject)
            var ai = 0
            while ai < len(node.arms) {
                let arm = node_pool[node.arms[ai]]
                self.push_scope()
                var si = 0
                while si < len(arm.body) { self.check_stmt(arm.body[si]); si = si + 1 }
                self.pop_scope()
                ai = ai + 1
            }
        } elif node.kind == "FnDef" {
            let old_ret = self.in_fn_ret
            self.in_fn_ret = node.return_type
            let old_generic = self.generic_params
            var gp: List<str> = []
            var gi = 0
            while gi < len(node.generics) { push(gp, node_pool[node.generics[gi]].str_val); gi = gi + 1 }
            self.generic_params = gp
            let old_cls = self.in_class
            if node.has_self { self.in_class = self.in_class }
            self.push_scope()
            var pi = 0
            while pi < len(node.params) {
                let p = node_pool[node.params[pi]]
                self.declare_var(p.name, p.type_ann)
                pi = pi + 1
            }
            var si = 0
            while si < len(node.body) { self.check_stmt(node.body[si]); si = si + 1 }
            self.pop_scope()
            self.in_class = old_cls
            self.generic_params = old_generic
            self.in_fn_ret = old_ret
        } elif node.kind == "ClassDef" {
            let old_cls = self.in_class
            self.in_class = node.name
            var mi = 0
            while mi < len(node.methods) {
                self.check_stmt(node.methods[mi])
                mi = mi + 1
            }
            self.in_class = old_cls
        } elif node.kind == "ImportStmt" {
            // Modules already resolved by compile_source; nothing to check
        } elif node.kind == "ExprStmt" {
            self.infer_type(node.inner)
        } elif node.kind == "BreakStmt" or node.kind == "ContinueStmt" {
            // No validation yet
        }
    }

    fn err(self, msg: str, node_id: int, code: str) -> void {
        let n = node_pool[node_id]
        push(self.diags, make_diag(OX_SEVERITY_ERROR, msg, code, n.s_line, n.s_col))
    }

    fn type_err(self, expected: str, found: str, node_id: int) -> void {
        let msg = "expected `" + expected + "`, found `" + found + "`"
        let n = node_pool[node_id]
        push(self.diags, make_diag(OX_SEVERITY_ERROR, msg, "E0308", n.s_line, n.s_col))
    }
}

// ── Type-check entry ─────────────────────────────────────────
fn check_source(src: str, source_path: str) -> void {
    node_pool = []
    let lexer = Lexer { src: src, pos: 0, line: 1, col: 1 }
    let tokens = lexer.tokenize()
    let parser = Parser { tokens: tokens, pos: 0, src: src, cur_tok: tokens[0] }
    let ast = parser.parse()

    let tc = TypeChecker {
        src: src, source_path: source_path,
        diags: [], scopes: [],
        fn_names: [], fn_param_types: [], fn_rets: [],
        cls_names: [], cls_field_names: [], cls_field_types: [],
        in_fn_ret: "", in_class: "", generic_params: []
    }
    tc.check(ast)

    if len(tc.diags) > 0 {
        var i = 0
        while i < len(tc.diags) {
            print(render_one(tc.diags[i], src, source_path))
            i = i + 1
        }
        exit(1)
    }
    print("No errors found")
}

// ── Entry point ─────────────────────────────────────────────
fn compile_source(src: str, source_path: str) -> int {
    node_pool = []
    let lexer = Lexer { src: src, pos: 0, line: 1, col: 1 }
    let tokens = lexer.tokenize()
    let parser = Parser { tokens: tokens, pos: 0, src: src, cur_tok: tokens[0] }
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
            let mod_parser = Parser { tokens: mod_tokens, pos: 0, src: mod_src, cur_tok: mod_tokens[0] }
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
        print("Usage: oxybelis <source.ox> [--check] [--cc CXX] [--cflags FLAGS] [-o FILE] [-S]")
        exit(1)
    }
    let source_path: str = cli_args[1]
    var output_path: str = ""
    var do_compile = true
    var emit_cpp = false
    var do_check = false
    var cc: str = "g++"
    var cflags: str = "-O3 -std=c++20"

    var ai = 2
    while ai < len(cli_args) {
        if cli_args[ai] == "-o" and ai + 1 < len(cli_args) {
            output_path = cli_args[ai + 1]; ai = ai + 1
        } elif cli_args[ai] == "-S" { emit_cpp = true; do_compile = false }
        elif cli_args[ai] == "--check" { do_check = true; do_compile = false }
        elif cli_args[ai] == "--cc" and ai + 1 < len(cli_args) { cc = cli_args[ai + 1]; ai = ai + 1 }
        elif cli_args[ai] == "--cflags" and ai + 1 < len(cli_args) { cflags = cli_args[ai + 1]; ai = ai + 1 }
        ai = ai + 1
    }

    let src: str = read_file(source_path)
    if src == "" {
        print("Error: Could not read " + source_path)
        exit(1)
    }

    if do_check {
        check_source(src, source_path)
        exit(0)
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
        // Auto-detect NumCpp include path
        var numcpp_inc: str = ""
        if fs_exists("NumCpp/include") { numcpp_inc = " -INumCpp/include" }
        if fs_exists("../NumCpp/include") { numcpp_inc = " -I../NumCpp/include" }
        let status = exec(cc + " " + cflags + numcpp_inc + mconsole + " " + cpp_file + " -o " + exe_file)
        if status == 0 {
            print("✓ " + source_path + " → " + exe_file)
            exec(exe_file)
        } else {
            print("✗ Compilation failed (see " + cpp_file + ")")
            exit(1)
        }
    }
}
