# Undertale Essentials. Copyright (C) 2026 Pixeo.
# Free software under the GNU GPL version 3 or later: see LICENSE.
"""Builds Undertale Essentials.

    python mod/tools/build.py [--game DIR] [--out FILE] [--test-save NAME]

Reads DIR/data.win (never modifies it) and writes the modded data file (default
DIR/data_framerate.win). Needs UndertaleModTool's CLI in tools/utmt_cli.
--test-save renames the game's internal name so a test build keeps its saves in its own folder.
"""
import argparse, hashlib, json, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(HERE)
ROOT = os.path.dirname(MOD)
sys.path.insert(0, HERE)
from transform import transform_all  # noqa: E402
from wrappers import gen as gen_wrappers  # noqa: E402

CLI = os.path.join(ROOT, 'tools', 'utmt_cli', 'UndertaleModCli.exe')


def run_cli(args, env=None):
    e = dict(os.environ)
    if env:
        e.update(env)
    p = subprocess.run([CLI] + args, stdin=subprocess.DEVNULL, capture_output=True, text=True, env=e)
    out = '\n'.join(l for l in (p.stdout + p.stderr).splitlines() if '[MESSAGE]' not in l)
    if p.returncode != 0 or 'Exception' in out or 'failed' in out.lower():
        print(out)
        raise SystemExit(f'UndertaleModCli failed ({p.returncode})')
    return out


def file_hash(path):
    h = hashlib.sha1()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def ensure_dump(data_win, work):
    """Decompile all code and dump object/room metadata (cached per data.win hash)."""
    stamp = os.path.join(work, 'dump.sha1')
    digest = file_hash(data_win)
    code_dir = os.path.join(work, 'dump', 'CodeEntries')
    meta = os.path.join(work, 'meta.json')
    if os.path.exists(stamp) and open(stamp).read() == digest and os.path.isdir(code_dir) and os.path.exists(meta):
        return code_dir, meta
    print('decompiling data.win ...')
    if os.path.isdir(os.path.join(work, 'dump')):
        shutil.rmtree(os.path.join(work, 'dump'))
    run_cli(['dump', data_win, '-o', os.path.join(work, 'dump'), '-c', 'UMT_DUMP_ALL'])
    run_cli(['load', data_win, '-s', os.path.join(MOD, 'csx', 'dump_meta.csx')], env={'FL_META_OUT': meta})
    with open(stamp, 'w') as f:
        f.write(digest)
    return code_dir, meta


def split_runtime(path):
    """runtime.gml holds many code entries, each starting with a '// @@ <name>' line."""
    entries = {}
    cur = None
    for line in open(path, encoding='utf-8'):
        if line.startswith('// @@ '):
            cur = line[6:].strip()
            entries[cur] = []
        elif cur:
            entries[cur].append(line)
    return {k: ''.join(v).strip() + '\n' for k, v in entries.items()}


def globals_list_script(meta):
    names = sorted({v['name'] for v in meta['vars'] if v['inst'] == 'Global' and not v['name'].startswith('__fl_')})
    lines = ['// all globals of the original game (generated), for the validation self-check']
    for i, n in enumerate(names):
        lines.append(f'g[{i}] = "{n}";')
    lines.append('return g;')
    lines.insert(1, f'var g;')
    return '\n'.join(lines) + '\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--game', default=ROOT, help='folder containing data.win')
    ap.add_argument('--out', default=None, help='output data file (default: <game>/data_framerate.win)')
    ap.add_argument('--test-save', default=None, help='internal game name for a test build (moves its save folder)')
    ap.add_argument('--room-speed', default='60')
    a = ap.parse_args()

    data_win = os.path.join(a.game, 'data.win')
    out = a.out or os.path.join(a.game, 'data_framerate.win')
    work = os.path.join(ROOT, 'work')
    os.makedirs(work, exist_ok=True)

    code_dir, meta_path = ensure_dump(data_win, work)
    meta = json.load(open(meta_path))

    changed, report = transform_all(code_dir, meta)
    print(f"transform: {report['selected']} entries checked, {report['changed']} changed, {report['barriers']} barriers")
    if report['problems']:
        for p in report['problems']:
            print('  PROBLEM', p)
        raise SystemExit('transform reported problems')

    entries = dict(changed)
    for name, code in gen_wrappers().items():
        entries[name] = code
    runtime = split_runtime(os.path.join(MOD, 'gml', 'runtime.gml'))
    clash = set(runtime) & set(entries)
    if clash:
        raise SystemExit(f'runtime entries clash with generated ones: {clash}')
    entries.update(runtime)
    entries['gml_Script___fl_globals_list'] = globals_list_script(meta)

    gen_dir = os.path.join(MOD, 'gen')
    if os.path.isdir(gen_dir):
        shutil.rmtree(gen_dir)
    os.makedirs(gen_dir)
    for name, code in entries.items():
        with open(os.path.join(gen_dir, name + '.gml'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(code)
    print(f'{len(entries)} code entries written to mod/gen')

    tmp_out = out + '.tmp'
    env = {'FL_GEN_DIR': gen_dir, 'FL_ROOM_SPEED': a.room_speed}
    if a.test_save:
        env['FL_SAVE_NAME'] = a.test_save
    log = run_cli(['load', data_win, '-s', os.path.join(MOD, 'csx', 'build.csx'), '-o', tmp_out, '-f'], env=env)
    print('\n'.join(l for l in log.splitlines() if not l.startswith('Trying')))
    if 'build ok' not in log:
        raise SystemExit('build script did not finish')
    os.replace(tmp_out, out)
    print('wrote', out)


if __name__ == '__main__':
    main()
