"""Bash command fixtures. Does not run Qt, a compositor, jq, or wl-copy itself."""
from pathlib import Path
import os, shutil, subprocess, tempfile
root = Path(__file__).resolve().parent.parent
bash = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else shutil.which('bash')
def posix(p):
    return subprocess.check_output([bash, '-c', 'cygpath -u "$1"', 'test', str(p)], text=True).strip() if os.name == 'nt' else str(p)
checks = root / '.checks'
checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks, prefix='bar-tools-') as directory:
    box = Path(directory)
    def command(name, body):
        p = box/name
        p.write_text('#!/usr/bin/env bash\n'+body+'\n', encoding='utf-8', newline='\n')
        p.chmod(0o700)
    command('cliphist', r'''[[ $1 == -config-path && $2 == /dev/null && $3 == -db-path ]] || exit 9
case $5 in
    decode)
        IFS= read -r id && exit 8
        [[ $id == 42 ]] || exit 3
        [[ ${EMPTY_DECODE:-0} == 0 ]] || exit 0
        printf '\211PNG\000binary\n'
        exit "${DECODE_FAIL:-0}" ;;
    list) printf '42\tImage\n' ;;
    *) exit 9 ;;
esac''')
    command('wl-copy', 'cat > "$COPIED"; exit "${COPY_FAIL:-0}"')
    command('flock', 'exit "${LOCK_FAIL:-0}"')
    command('qs', 'exit 0')
    command('swaync-client', 'exit 0')
    command('hyprctl', '[[ ${QUERY_FAIL:-0} == 0 ]] || exit 1; printf "[]"')
    # jq unavailable on this host: fixture validates the surrounding Bash workflow only.
    command('jq', r'''cat >/dev/null
case "$*" in
    *modifiers*) echo 'Windows | Custom $(touch forbidden) | Super+Q' ;;
    *focused*) echo '90 14' ;;
    *'.str'*) echo grp:alt_shift_toggle ;;
    *) exit 9 ;;
esac''')
    command('fuzzel', 'printf "%s\n" "$@" > "$ARGS"; cat > "$MENU"; echo "touch forbidden"; exit "${CANCEL:-0}"')
    env = {**os.environ, 'PATH':posix(box)+':/usr/bin:/bin', 'HOME':posix(box),
           'XDG_RUNTIME_DIR':posix(box), 'XDG_CACHE_HOME':posix(box/'cache'),
           'COPIED':posix(box/'copied'), 'MENU':posix(box/'menu'), 'ARGS':posix(box/'args')}
    def run(script, *args, code=0, **extra):
        result = subprocess.run([bash, str(root/'stow/desktop/.local/lib/graphite'/script), *args], env={**env, **extra}, cwd=box, capture_output=True, text=True)
        assert result.returncode == code, (result.returncode,result.stdout,result.stderr)
        return result
    assert run('clipboard.sh','list-json').stdout.strip() == '[]'
    run('clipboard.sh','restore','42')
    assert (box/'copied').read_bytes() == b'\x89PNG\0binary\n'
    (box/'copied').write_bytes(b'previous clipboard')
    run('clipboard.sh','restore','42', code=1, DECODE_FAIL='1')
    assert (box/'copied').read_bytes() == b'previous clipboard'
    run('clipboard.sh','restore','42',code=1,EMPTY_DECODE='1')
    assert (box/'copied').read_bytes() == b'previous clipboard'
    run('clipboard.sh','restore','$(touch forbidden)',code=2)
    run('clipboard.sh','restore','missing',code=2)
    run('clipboard.sh','restore','7',code=1)
    run('clipboard.sh','restore','42',code=1,COPY_FAIL='1')
    assert not list(box.glob('graphite-clipboard-*'))
    assert not (box/'forbidden').exists()
    ime=box/'.config/graphite/fcitx5/config'
    ime.parent.mkdir(parents=True)
    ime.write_text('[Hotkey/TriggerKeys]\n0=Control+space\n[Other]\n0=ignored\n',encoding='utf-8')
    run('shortcuts.sh')
    assert 'Control+space' in (box/'menu').read_text() and 'ignored' not in (box/'menu').read_text()
    assert '--width=90' in (box/'args').read_text() and '--lines=14' in (box/'args').read_text()
    assert 'Custom $(touch forbidden)' in (box/'menu').read_text()
    assert 'grp:alt_shift_toggle' in (box/'menu').read_text()
    assert not (box/'forbidden').exists()
    run('shortcuts.sh', CANCEL='1')
    run('shortcuts.sh', LOCK_FAIL='1')
    run('shortcuts.sh', QUERY_FAIL='1',code=1)
print('PASS: clipboard binary restoration, decode/copy failures, invalid IDs, temp cleanup; shortcut sizing, read-only selection, cancellation, lock and query failure (jq stubbed).')

# Source-level collision check; actual Lua execution is in test-bindings.lua.
import re
bindings=(root/'stow/desktop/.config/graphite/hypr/graphite/bindings.lua').read_text(encoding='utf-8')
keys=re.findall(r'^(?:hl\.bind|script|run)\("([^"\n]+)"\s*,',bindings,re.M)
keys += ['SUPER + '+d for d in ['left','right','up','down']]
keys += [prefix+str(i%10) for i in range(1,11) for prefix in ['SUPER + ','SUPER + SHIFT + ']]
assert len(keys)==len(set(k.lower() for k in keys))
for line in bindings.splitlines():
    if line.lstrip().startswith(('hl.bind(', 'script(', 'run(')):
        assert 'description =' in line, line
print('PASS source-level shortcut uniqueness and description coverage; Lua execution remains separate.')
