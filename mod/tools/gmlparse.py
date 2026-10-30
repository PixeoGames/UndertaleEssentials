"""Minimal GML (GameMaker Studio 1.4, as decompiled by UndertaleModTool) parser.

Produces a small AST good enough to find assignments, calls and with-blocks.
"""
import re

TOKEN_RE = re.compile(r'''
 (?P<ws>\s+)|
 (?P<comment>//[^\n]*|/\*.*?\*/)|
 (?P<str>"[^"]*"|'[^']*')|
 (?P<num>\#[0-9A-Fa-f]{6}|\$[0-9A-Fa-f]+|0x[0-9A-Fa-f]+|\d+\.\d*(?:[eE][-+]?\d+)?|\.\d+|\d+(?:[eE][-+]?\d+)?)|
 (?P<id>[A-Za-z_][A-Za-z0-9_]*)|
 (?P<op><<=|>>=|\+\+|--|\+=|-=|\*=|/=|%=|&=|\|=|\^=|==|!=|<=|>=|&&|\|\||\^\^|<<|>>|[-+*/%&|^!~<>=?:;,.\[\]{}()@#])
''', re.X | re.S)

KEYWORDS = {'if', 'else', 'while', 'do', 'until', 'for', 'repeat', 'with', 'switch', 'case',
            'default', 'break', 'continue', 'exit', 'return', 'var', 'globalvar', 'div', 'mod',
            'and', 'or', 'xor', 'not', 'begin', 'end', 'then'}

ASSIGN_OPS = {'=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>='}


class Tok:
    __slots__ = ('kind', 'val', 'pos')

    def __init__(self, kind, val, pos):
        self.kind, self.val, self.pos = kind, val, pos

    def __repr__(self):
        return f'{self.kind}:{self.val}'


def tokenize(src):
    out = []
    pos = 0
    n = len(src)
    while pos < n:
        m = TOKEN_RE.match(src, pos)
        if not m:
            raise SyntaxError(f'bad char {src[pos]!r} at {pos}: {src[pos:pos+40]!r}')
        kind = m.lastgroup
        if kind not in ('ws', 'comment'):
            val = m.group(kind)
            if kind == 'id' and val in KEYWORDS:
                kind = 'kw'
            out.append(Tok(kind, val, pos))
        pos = m.end()
    out.append(Tok('eof', None, pos))
    return out


# --- AST node constructors (tuples keep it light) ---
# Expressions: ('num', v) ('str', v) ('id', name) ('member', base, name) ('index', base, [idx])
#              ('call', name_or_expr, [args]) ('un', op, e) ('bin', op, a, b) ('tern', c, a, b)
# Statements:  ('block', [stmts]) ('var', [(name, init)]) ('assign', op, lhs, rhs) ('incdec', op, lhs)
#              ('expr', e) ('if', c, s, else_s) ('while', c, s) ('do', s, c) ('for', init, c, step, s)
#              ('repeat', e, s) ('with', e, s) ('switch', e, [(case_expr_or_None, [stmts])])
#              ('break',) ('continue',) ('exit',) ('return', e)

BINPREC = [
    ({'||', 'or'}, ),
    ({'&&', 'and'}, ),
    ({'^^', 'xor'}, ),
    ({'==', '!=', '<', '>', '<=', '>=', '='}, ),
    ({'|'}, ),
    ({'^'}, ),
    ({'&'}, ),
    ({'<<', '>>'}, ),
    ({'+', '-'}, ),
    ({'*', '/', '%', 'div', 'mod'}, ),
]


class Parser:
    def __init__(self, src):
        self.t = tokenize(src)
        self.i = 0

    def peek(self, k=0):
        return self.t[self.i + k]

    def next(self):
        tok = self.t[self.i]
        self.i += 1
        return tok

    def at(self, val, k=0):
        tok = self.t[self.i + k]
        return tok.val == val and tok.kind in ('op', 'kw')

    def expect(self, val):
        tok = self.next()
        if tok.val != val:
            raise SyntaxError(f'expected {val!r} got {tok.val!r} at {tok.pos}')
        return tok

    def accept(self, val):
        if self.at(val):
            self.i += 1
            return True
        return False

    def parse_program(self):
        stmts = []
        while self.peek().kind != 'eof':
            stmts.append(self.statement())
        return ('block', stmts)

    def statement(self):
        tok = self.peek()
        if tok.kind == 'op':
            if tok.val == '{':
                self.next()
                stmts = []
                while not self.at('}'):
                    stmts.append(self.statement())
                self.next()
                return ('block', stmts)
            if tok.val == ';':
                self.next()
                return ('block', [])
        if tok.kind == 'kw':
            v = tok.val
            if v == 'var' or v == 'globalvar':
                self.next()
                decls = []
                while True:
                    name = self.next().val
                    init = None
                    if self.accept('='):
                        init = self.expr()
                    decls.append((name, init))
                    if not self.accept(','):
                        break
                self.accept(';')
                return ('var' if v == 'var' else 'globalvar', decls)
            if v == 'if':
                self.next()
                c = self.expr()
                self.accept('then')
                s = self.statement()
                e = None
                if self.accept('else'):
                    e = self.statement()
                return ('if', c, s, e)
            if v == 'while':
                self.next()
                c = self.expr()
                s = self.statement()
                return ('while', c, s)
            if v == 'do':
                self.next()
                s = self.statement()
                self.expect('until')
                c = self.expr()
                self.accept(';')
                return ('do', s, c)
            if v == 'for':
                self.next()
                self.expect('(')
                if self.at(';'):
                    init = None
                elif self.at('var'):
                    self.next()
                    decls = []
                    while True:
                        name = self.next().val
                        vinit = None
                        if self.accept('='):
                            vinit = self.expr()
                        decls.append((name, vinit))
                        if not self.accept(','):
                            break
                    init = ('var', decls)
                else:
                    init = self.simple_statement()
                self.expect(';')
                c = None if self.at(';') else self.expr()
                self.expect(';')
                step = None if self.at(')') else self.simple_statement()
                self.expect(')')
                s = self.statement()
                return ('for', init, c, step, s)
            if v == 'repeat':
                self.next()
                e = self.expr()
                s = self.statement()
                return ('repeat', e, s)
            if v == 'with':
                self.next()
                e = self.expr()
                s = self.statement()
                return ('with', e, s)
            if v == 'switch':
                self.next()
                e = self.expr()
                self.expect('{')
                cases = []
                cur = None
                while not self.at('}'):
                    if self.accept('case'):
                        ce = self.expr()
                        self.expect(':')
                        cur = (ce, [])
                        cases.append(cur)
                    elif self.accept('default'):
                        self.expect(':')
                        cur = (None, [])
                        cases.append(cur)
                    else:
                        if cur is None:
                            cur = ('<pre>', [])
                            cases.append(cur)
                        cur[1].append(self.statement())
                self.next()
                return ('switch', e, cases)
            if v in ('break', 'continue', 'exit'):
                self.next()
                self.accept(';')
                return (v,)
            if v == 'return':
                self.next()
                e = None
                if not self.at(';') and not self.at('}'):
                    e = self.expr()
                self.accept(';')
                return ('return', e)
        s = self.simple_statement()
        self.accept(';')
        return s

    def simple_statement(self):
        # prefix ++/--
        if self.at('++') or self.at('--'):
            op = self.next().val
            lhs = self.postfix()
            return ('incdec', op, lhs)
        lhs = self.postfix()
        tok = self.peek()
        if tok.kind == 'op' and tok.val in ASSIGN_OPS:
            op = self.next().val
            rhs = self.expr()
            return ('assign', op, lhs, rhs)
        if tok.kind == 'op' and tok.val in ('++', '--'):
            self.next()
            return ('incdec', tok.val, lhs)
        return ('expr', lhs)

    def expr(self):
        c = self.binary(0)
        if self.at('?'):
            self.next()
            a = self.expr()
            self.expect(':')
            b = self.expr()
            return ('tern', c, a, b)
        return c

    def binary(self, level):
        if level >= len(BINPREC):
            return self.unary()
        ops = BINPREC[level][0]
        a = self.binary(level + 1)
        while True:
            tok = self.peek()
            if tok.kind in ('op', 'kw') and tok.val in ops:
                self.next()
                b = self.binary(level + 1)
                a = ('bin', tok.val, a, b)
            else:
                return a

    def unary(self):
        tok = self.peek()
        if tok.kind in ('op', 'kw') and tok.val in ('!', '-', '~', '+', 'not'):
            self.next()
            return ('un', tok.val, self.unary())
        if tok.kind == 'op' and tok.val in ('++', '--'):
            self.next()
            return ('preinc', tok.val, self.unary())
        e = self.postfix()
        if self.at('++') or self.at('--'):
            # postfix inc inside an expression (rare in decompiled code)
            op = self.next().val
            return ('postinc', op, e)
        return e

    def postfix(self):
        e = self.primary()
        while True:
            if self.at('('):
                self.next()
                args = []
                if not self.at(')'):
                    while True:
                        args.append(self.expr())
                        if not self.accept(','):
                            break
                self.expect(')')
                e = ('call', e, args)
            elif self.at('['):
                self.next()
                idx = [self.expr()]
                while self.accept(','):
                    idx.append(self.expr())
                self.expect(']')
                e = ('index', e, idx)
            elif self.at('.'):
                self.next()
                name = self.next()
                e = ('member', e, name.val)
            else:
                return e

    def primary(self):
        tok = self.next()
        if tok.kind == 'num':
            return ('num', tok.val)
        if tok.kind == 'str':
            return ('str', tok.val)
        if tok.kind == 'id':
            return ('id', tok.val)
        if tok.kind == 'op' and tok.val == '(':
            e = self.expr()
            self.expect(')')
            return ('paren', e)
        if tok.kind == 'kw' and tok.val in ('self', 'other', 'global'):
            return ('id', tok.val)
        raise SyntaxError(f'unexpected {tok.val!r} at {tok.pos}')


def parse(src):
    return Parser(src).parse_program()
