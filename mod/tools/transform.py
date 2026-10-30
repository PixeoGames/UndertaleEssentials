"""Source-to-source transform of Undertale's decompiled GML for the framerate mod.

For every code entry that can run while a throwaway (interpolated) frame is drawn, this:
  * inserts a rollback barrier before each write to a non-local variable, so the
    controller can undo everything the throwaway draw changed;
  * renames calls to side-effecting builtins to __fl_ wrapper scripts that are
    no-ops (or tracked) while a throwaway frame is being drawn;
  * maps room_speed (the game's logic rate) onto global.__fl_tps.

Usage: python transform.py <dump CodeEntries dir> <meta.json> <out dir>
"""
import os, sys, json, re
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gmlparse import Parser, ASSIGN_OPS  # noqa: E402
from funcs import PURE, WRAP, KEY_PRESS_FUNCS  # noqa: E402


class SpanParser(Parser):
    """Parser that records the source span of every statement/expression node."""

    def __init__(self, src):
        super().__init__(src)
        self.src = src
        self.spans = {}

    def _span(self, fn):
        start = self.peek().pos
        node = fn()
        last = self.t[self.i - 1]
        self.spans[id(node)] = (start, last.pos + len(last.val))
        return node

    def statement(self):
        return self._span(super().statement)

    def simple_statement(self):
        return self._span(super().simple_statement)

    def expr(self):
        return self._span(super().expr)

    def unary(self):
        return self._span(super().unary)

    def postfix(self):
        # re-implemented so every intermediate node (a.b, a[i], f(x)) gets a span
        start = self.peek().pos
        e = self.primary()

        def mark(node):
            last = self.t[self.i - 1]
            self.spans[id(node)] = (start, last.pos + len(last.val))
            return node
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
                e = mark(('call', e, args))
            elif self.at('['):
                self.next()
                idx = [self.expr()]
                while self.accept(','):
                    idx.append(self.expr())
                self.expect(']')
                e = mark(('index', e, idx))
            elif self.at('.'):
                self.next()
                name = self.next()
                e = mark(('member', e, name.val))
            else:
                return mark(e) if id(e) not in self.spans else e

    def primary(self):
        return self._span(super().primary)


BUILTIN_GLOBALS = {
    'room', 'room_caption', 'room_persistent', 'view_xview', 'view_yview', 'view_wview', 'view_hview',
    'view_xport', 'view_yport', 'view_wport', 'view_hport', 'view_angle', 'view_visible', 'view_object',
    'view_hborder', 'view_vborder', 'view_hspeed', 'view_vspeed', 'view_enabled', 'background_x',
    'background_y', 'background_hspeed', 'background_vspeed', 'background_alpha', 'background_blend',
    'background_index', 'background_visible', 'background_foreground', 'background_htiled',
    'background_vtiled', 'background_xscale', 'background_yscale', 'background_color', 'background_colour',
    'background_showcolor', 'background_showcolour', 'score', 'lives', 'health', 'keyboard_string',
    'keyboard_lastkey', 'keyboard_lastchar', 'keyboard_key', 'cursor_sprite', 'show_score', 'show_lives',
    'show_health', 'caption_score', 'error_occurred', 'error_last', 'transition_kind', 'transition_steps',
    'transition_time', 'transition_color'}
# builtin globals the controller snapshots and restores wholesale around a throwaway draw
SNAPSHOT_GLOBALS = {'room_caption', 'view_xview', 'view_yview', 'view_wview', 'view_hview', 'view_xport',
                    'view_yport', 'view_wport', 'view_hport', 'view_angle', 'view_visible', 'view_object',
                    'view_hborder', 'view_vborder', 'view_hspeed', 'view_vspeed', 'background_x',
                    'background_y', 'background_hspeed', 'background_vspeed', 'background_alpha',
                    'background_blend', 'background_index', 'background_visible', 'background_color',
                    'background_showcolor', 'background_xscale', 'background_yscale', 'keyboard_string',
                    'background_foreground', 'background_htiled', 'background_vtiled', 'background_colour',
                    'background_showcolour',
                    'keyboard_lastchar', 'keyboard_lastkey'}


MOTION = {'hspeed', 'vspeed', 'speed', 'direction'}


class TransformError(Exception):
    pass


class Transformer:
    def __init__(self, src, name, scripts, rename_keypress):
        self.src = src
        self.name = name
        self.scripts = scripts
        self.rename_keypress = rename_keypress
        self.p = SpanParser(src)
        self.ast = self.p.parse_program()
        self.spans = self.p.spans
        self.locals = set()
        self._collect_locals(self.ast)
        self.ins = defaultdict(list)     # pos -> list of (order, text)
        self.repl = []                   # (start, end, text) replacements (must not overlap)
        self.hoist_n = 0
        self.calls = Counter()
        self.argcs = defaultdict(set)
        self.barriers = 0
        self.unknown_calls = Counter()

    # ---------- helpers ----------
    def _collect_locals(self, n):
        if isinstance(n, tuple):
            if n and n[0] == 'var':
                for name, _ in n[1]:
                    self.locals.add(name)
            for ch in n[1:]:
                self._collect_locals(ch)
        elif isinstance(n, list):
            for ch in n:
                self._collect_locals(ch)

    def text(self, node):
        s, e = self.spans[id(node)]
        return self.src[s:e]

    def span(self, node):
        return self.spans[id(node)]

    def new_hoist(self):
        n = f'__fl_h{self.hoist_n}'
        self.hoist_n += 1
        return n

    @staticmethod
    def strip_paren(e):
        while e[0] == 'paren':
            e = e[1]
        return e

    def is_simple(self, e):
        e = self.strip_paren(e)
        return e[0] in ('id', 'num', 'str')

    def has_effects(self, e):
        """True if evaluating e twice could differ or have side effects."""
        if isinstance(e, tuple):
            if e and e[0] in ('call', 'preinc', 'postinc'):
                if e[0] == 'call' and e[1][0] == 'id' and e[1][1] in PURE and e[1][1] not in ('random', 'irandom', 'random_range', 'irandom_range', 'choose'):
                    return any(self.has_effects(a) for a in e[2])
                return True
            return any(self.has_effects(c) for c in e[1:] if isinstance(c, (tuple, list)))
        if isinstance(e, list):
            return any(self.has_effects(c) for c in e)
        return False

    # ---------- barrier generation ----------
    def barrier_for(self, lv, prefix_parts, stmt_repl):
        """Return GML barrier code for lvalue node lv (or None if it's local/untracked).
        May append hoist statements to prefix_parts and replacements to stmt_repl."""
        if lv[0] == 'id':
            nm = lv[1]
            if nm in self.locals or nm.startswith('argument'):
                return None
            if nm == 'room_speed':
                return '__fl_bg("__fl_tps");'
            if nm in BUILTIN_GLOBALS:
                if nm not in SNAPSHOT_GLOBALS:
                    raise TransformError(f'write to builtin global {nm}')
                return None
            if nm == 'alarm':
                raise TransformError('bare alarm write')
            if nm in MOTION:
                return '__fl_bmotion();'
            return f'__fl_bs("{nm}");'
        if lv[0] == 'index':
            base = lv[1]
            idx = lv[2]
            idx_txt = []
            for ie in idx:
                if self.has_effects(ie):
                    h = self.new_hoist()
                    self.hoist_expr(ie, h, prefix_parts)
                    stmt_repl.append((*self.span(ie), h))
                    idx_txt.append(h)
                else:
                    idx_txt.append('(' + self.text(ie) + ')')
            if base[0] == 'id':
                nm = base[1]
                if nm in self.locals or nm.startswith('argument'):
                    return None
                if nm in BUILTIN_GLOBALS:
                    if nm not in SNAPSHOT_GLOBALS:
                        raise TransformError(f'write to builtin global array {nm}')
                    return None
                if nm == 'alarm':
                    return f'__fl_balarm({idx_txt[0]});'
                if len(idx_txt) == 1:
                    return f'__fl_ba("{nm}", {idx_txt[0]});'
                return f'__fl_ba2("{nm}", {idx_txt[0]}, {idx_txt[1]});'
            if base[0] == 'member':
                obj = self.strip_paren(base[1])
                nm = base[2]
                if obj[0] == 'id' and obj[1] == 'global':
                    if len(idx_txt) == 1:
                        return f'__fl_bga("{nm}", {idx_txt[0]});'
                    return f'__fl_bga2("{nm}", {idx_txt[0]}, {idx_txt[1]});'
                # index must be evaluated in the caller's context, before the with()
                hidx = []
                for k, ie in enumerate(idx):
                    t = idx_txt[k]
                    if not t.startswith('__fl_h'):
                        h = self.new_hoist()
                        prefix_parts.append(f'var {h} = {t};')
                        stmt_repl.append((*self.span(ie), h))
                        t = h
                    hidx.append(t)
                target = self.target_text(base[1], prefix_parts, stmt_repl)
                if obj[0] == 'id' and obj[1] == 'self':
                    target = None
                call = f'__fl_ba("{nm}", {hidx[0]})' if len(hidx) == 1 else f'__fl_ba2("{nm}", {hidx[0]}, {hidx[1]})'
                if nm == 'alarm':
                    call = f'__fl_balarm({hidx[0]})'
                return f'{call};' if target is None else f'with ({target}) {call};'
            raise TransformError(f'weird indexed lvalue {self.text(lv)!r}')
        if lv[0] == 'member':
            obj = self.strip_paren(lv[1])
            nm = lv[2]
            if obj[0] == 'id' and obj[1] == 'global':
                return f'__fl_bg("{nm}");'
            call = '__fl_bmotion();' if nm in MOTION else f'__fl_bs("{nm}");'
            if obj[0] == 'id' and obj[1] == 'self':
                return call
            if nm == 'alarm':
                raise TransformError('member bare alarm write')
            target = self.target_text(lv[1], prefix_parts, stmt_repl)
            return f'with ({target}) {call}'
        raise TransformError(f'weird lvalue {self.text(lv)!r}')

    def target_text(self, base, prefix_parts, stmt_repl):
        if self.is_simple(base) and not self.has_effects(base):
            return self.text(base)
        h = self.new_hoist()
        prefix_parts.append(f'var {h} = {self.text(base)};')
        stmt_repl.append((*self.span(base), h))
        return h

    def hoist_expr(self, ie, h, prefix_parts):
        """Hoist an index expression with side effects into local h (evaluated once)."""
        e = self.strip_paren(ie)
        if e[0] in ('postinc', 'preinc'):
            op = e[1]
            tgt = e[2]
            tparts, trepl = [], []
            b = self.barrier_for(tgt, tparts, trepl)
            if trepl:
                raise TransformError('nested hoist in inc index')
            tt = self.text(tgt)
            delta = '+= 1' if op == '++' else '-= 1'
            prefix_parts.extend(tparts)
            if e[0] == 'postinc':
                prefix_parts.append(f'var {h} = {tt};')
                if b:
                    prefix_parts.append(f'if (global.__fl_tw) {{ {b} }}')
                prefix_parts.append(f'{tt} {delta};')
            else:
                if b:
                    prefix_parts.append(f'if (global.__fl_tw) {{ {b} }}')
                prefix_parts.append(f'{tt} {delta};')
                prefix_parts.append(f'var {h} = {tt};')
            return
        if self.find_incs(ie):
            raise TransformError(f'inc inside complex index {self.text(ie)!r}')
        # calls etc: evaluate once (renames inside are applied via a fresh rewrite of the text)
        prefix_parts.append(f'var {h} = {self.rewrite_expr_text(ie)};')

    def find_incs(self, e):
        if isinstance(e, tuple):
            if e and e[0] in ('preinc', 'postinc'):
                return True
            return any(self.find_incs(c) for c in e[1:] if isinstance(c, (tuple, list)))
        if isinstance(e, list):
            return any(self.find_incs(c) for c in e)
        return False

    def rewrite_expr_text(self, e):
        """Source text of e with call renames applied (used when hoisting)."""
        s0, e0 = self.span(e)
        edits = []
        self._collect_call_edits(e, edits)
        txt = self.src[s0:e0]
        for s, en, t in sorted(edits, reverse=True):
            txt = txt[:s - s0] + t + txt[en - s0:]
        return txt

    def _collect_call_edits(self, e, edits):
        if isinstance(e, tuple):
            if e and e[0] == 'call' and e[1][0] == 'id':
                new = self.call_rename(e[1][1])
                if new:
                    edits.append((*self.span(e[1]), new))
            if e and e[0] == 'id' and e[1] == 'room_speed':
                edits.append((*self.span(e), 'global.__fl_tps'))
            for c in e[1:]:
                if isinstance(c, (tuple, list)):
                    self._collect_call_edits(c, edits)
        elif isinstance(e, list):
            for c in e:
                self._collect_call_edits(c, edits)

    def call_rename(self, name):
        if name in self.scripts:
            return None
        if name in KEY_PRESS_FUNCS:
            return KEY_PRESS_FUNCS[name] if self.rename_keypress else None
        if name in WRAP:
            return '__fl_' + name
        if name in PURE:
            return None
        self.unknown_calls[name] += 1
        return None

    # ---------- walking ----------
    def add_wrap(self, node, prefix_parts):
        s, e = self.span(node)
        depth = self.depth
        pre = ' '.join(prefix_parts)
        self.ins[s].append((0, -depth, '{ ' + pre + ' '))
        self.ins[e].append((1, -depth, ' }'))  # closers: inner first (higher depth first)

    def stmt(self, n):
        if n is None:
            return
        k = n[0]
        if k == 'block':
            for s in n[1]:
                self.depth += 1
                self.stmt(s)
                self.depth -= 1
        elif k in ('var', 'globalvar'):
            if k == 'globalvar':
                raise TransformError('globalvar')
            for name, init in n[1]:
                if init is not None:
                    self.expr(init)
        elif k in ('assign', 'incdec'):
            lv = n[2]
            prefix, srepl = [], []
            b = self.barrier_for(lv, prefix, srepl)
            # walk index/base subexpressions and rhs for calls; skip spans that got hoisted
            hoisted = {(s, e) for s, e, _ in srepl}
            self.lvalue_exprs(lv, hoisted)
            if k == 'assign':
                self.expr(n[3])
            for s, e, t in srepl:
                self.repl.append((s, e, t))
            if b or prefix:
                parts = list(prefix)
                if b:
                    parts.append(f'if (global.__fl_tw) {{ {b} }}')
                    self.barriers += 1
                self.add_wrap(n, parts)
        elif k == 'expr':
            self.expr(n[1])
        elif k == 'if':
            self.expr(n[1])
            self.sub(n[2])
            self.sub(n[3])
        elif k == 'while':
            self.expr(n[1])
            self.sub(n[2])
        elif k == 'do':
            self.sub(n[1])
            self.expr(n[2])
        elif k == 'for':
            parts = []
            for hs in (n[1], n[3]):
                if hs is None or hs[0] == 'var':
                    if hs is not None:
                        for name, init in hs[1]:
                            if init is not None:
                                self.expr(init)
                    continue
                if hs[0] in ('assign', 'incdec'):
                    srepl = []
                    b = self.barrier_for(hs[2], parts, srepl)
                    if srepl:
                        raise TransformError('hoist in for header')
                    self.lvalue_exprs(hs[2], set())
                    if hs[0] == 'assign':
                        self.expr(hs[3])
                    if b:
                        parts.append(f'if (global.__fl_tw) {{ {b} }}')
                        self.barriers += 1
                elif hs[0] == 'expr':
                    self.expr(hs[1])
            if n[2] is not None:
                self.expr(n[2])
            if parts:
                self.add_wrap(n, list(dict.fromkeys(parts)))
            self.sub(n[4])
        elif k == 'repeat':
            self.expr(n[1])
            self.sub(n[2])
        elif k == 'with':
            self.expr(n[1])
            self.sub(n[2])
        elif k == 'switch':
            self.expr(n[1])
            for ce, body in n[2]:
                if ce not in (None, '<pre>'):
                    self.expr(ce)
                for s in body:
                    self.sub(s)
        elif k == 'return':
            if n[1] is not None:
                self.expr(n[1])
        elif k in ('break', 'continue', 'exit'):
            pass
        else:
            raise TransformError(f'unknown stmt {k}')

    def sub(self, s):
        if s is None:
            return
        self.depth += 1
        self.stmt(s)
        self.depth -= 1

    def lvalue_exprs(self, lv, hoisted):
        if lv[0] == 'index':
            for ie in lv[2]:
                if self.span(ie) not in hoisted:
                    self.expr(ie)
            self.lvalue_exprs(lv[1], hoisted)
        elif lv[0] == 'member':
            if self.span(lv[1]) not in hoisted:
                self.expr(lv[1])
        elif lv[0] == 'id':
            if lv[1] == 'room_speed':
                self.repl.append((*self.span(lv), 'global.__fl_tps'))

    def expr(self, e):
        if e is None:
            return
        k = e[0]
        if k == 'call':
            f = e[1]
            for a in e[2]:
                self.expr(a)
            if f[0] == 'id':
                self.calls[f[1]] += 1
                self.argcs[f[1]].add(len(e[2]))
                new = self.call_rename(f[1])
                if new:
                    self.repl.append((*self.span(f), new))
            else:
                self.expr(f)
        elif k == 'bin':
            self.expr(e[2])
            self.expr(e[3])
        elif k in ('un', 'paren'):
            self.expr(e[-1])
        elif k in ('preinc', 'postinc'):
            raise TransformError(f'inc in expression {self.text(e)!r}')
        elif k == 'tern':
            for s in e[1:]:
                self.expr(s)
        elif k == 'index':
            self.expr(e[1])
            for ie in e[2]:
                self.expr(ie)
        elif k == 'member':
            self.expr(e[1])
        elif k == 'id':
            if e[1] == 'room_speed':
                self.repl.append((*self.span(e), 'global.__fl_tps'))

    def run(self):
        self.depth = 0
        for s in self.ast[1]:
            self.stmt(s)
        return self.render()

    def render(self):
        # merge insertions and replacements; replacements must not overlap insertion points inside them
        edits = []
        for pos, items in self.ins.items():
            closers = sorted([it for it in items if it[0] == 1], key=lambda it: it[1])        # inner first
            openers = sorted([it for it in items if it[0] == 0], key=lambda it: -it[1])      # outer first
            txt = ''.join(t for _, _, t in closers) + ''.join(t for _, _, t in openers)
            edits.append((pos, pos, txt))
        reps = sorted(set(self.repl))
        for i in range(1, len(reps)):
            if reps[i][0] < reps[i - 1][1]:
                raise TransformError(f'overlapping replacements {reps[i-1]} {reps[i]}')
        for s, e, t in reps:
            for pos in self.ins:
                if s < pos < e:
                    raise TransformError('insertion inside replacement')
        edits.extend(reps)
        # apply from the end; at equal positions apply replacements (s<e) before pure insertions
        edits.sort(key=lambda x: (x[0], x[1]), reverse=True)
        out = self.src
        for s, e, t in edits:
            out = out[:s] + t + out[e:]
        return out


ROOM_SPEED_RE = re.compile(r'\broom_speed\b|\bkeyboard_check_(pressed|released|direct)\b|\bdraw_set_(font|halign|valign)\b')


def select_entries(code_dir, meta):
    names = []
    for f in sorted(os.listdir(code_dir)):
        if not f.endswith('.gml'):
            continue
        n = f[:-4]
        m = re.match(r'gml_Object_(.+)_(Draw|Other|Create|PreCreate)_(\d+)$', n)
        sel = False
        if n.startswith('gml_Script_'):
            sel = True
        elif m:
            ev, sub = m.group(2), int(m.group(3))
            if ev in ('Draw', 'Create', 'PreCreate'):
                sel = True
            elif ev == 'Other' and 10 <= sub <= 25:
                sel = True
        if not sel:
            src = open(os.path.join(code_dir, f), encoding='utf-8', errors='replace').read()
            if ROOM_SPEED_RE.search(src):
                sel = True
        if sel:
            names.append(n)
    return names


def transform_all(code_dir, meta):
    """Returns ({entry name: new source}, report dict). Raises SystemExit on problems."""
    from wrappers import SPEC
    scripts = {f[len('gml_Script_'):-4] for f in os.listdir(code_dir) if f.startswith('gml_Script_')}
    entries = select_entries(code_dir, meta)
    changed = {}
    errors = []
    unknown = Counter()
    argcs = defaultdict(set)
    nbar = 0
    for n in entries:
        src = open(os.path.join(code_dir, n + '.gml'), encoding='utf-8', errors='replace').read()
        is_key_event = bool(re.search(r'_(KeyPress|KeyRelease)_\d+$', n))
        try:
            t = Transformer(src, n, scripts, rename_keypress=not is_key_event)
            out = t.run()
        except Exception as ex:  # noqa: BLE001
            errors.append((n, f'{type(ex).__name__}: {ex}'))
            continue
        unknown.update(t.unknown_calls)
        for k, v in t.argcs.items():
            argcs[k] |= v
        nbar += t.barriers
        if out != src:
            changed[n] = out
    problems = []
    if set(WRAP) != set(SPEC):
        problems.append(f'WRAP/SPEC mismatch: {sorted(set(WRAP) ^ set(SPEC))}')
    for name in WRAP:
        if name in argcs and argcs[name] != {SPEC[name][0]}:
            problems.append(f'{name} called with {sorted(argcs[name])} args, wrapper takes {SPEC[name][0]}')
    for n, e in errors:
        problems.append(f'{n}: {e}')
    if unknown:
        problems.append(f'unclassified functions: {dict(unknown.most_common())}')
    report = {'selected': len(entries), 'changed': len(changed), 'barriers': nbar, 'problems': problems}
    return changed, report


def main():
    code_dir, meta_path, out_dir = sys.argv[1:4]
    meta = json.load(open(meta_path))
    changed, report = transform_all(code_dir, meta)
    os.makedirs(out_dir, exist_ok=True)
    for n, out in changed.items():
        with open(os.path.join(out_dir, n + '.gml'), 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(out)
    print(json.dumps(report, indent=1)[:3000])
    if report['problems']:
        sys.exit(1)


if __name__ == '__main__':
    main()
