"""Display menu command tests; no real compositor, jq or GUI is exercised."""
from pathlib import Path
import os, shutil, subprocess, tempfile

root = Path(__file__).resolve().parent.parent
bash = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else shutil.which('bash')
def posix(path):
    return subprocess.check_output([bash, '-c', 'cygpath -u "$1"', 'test', str(path)], text=True).strip() if os.name == 'nt' else str(path)

checks = root / '.checks'
checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks, prefix='displays-') as directory:
    box = Path(directory)
    commands = {
        'fuzzel': '''cat >/dev/null
if [[ -f $HOME/second ]]; then
    [[ ${CANCEL_SECOND:-0} == 0 ]] || exit 1
    echo "${SELECTED:-0}"
else
    touch "$HOME/second"
    [[ ${CANCEL:-0} == 0 ]] || exit 1
    echo "${CHOICE:-0}"
fi
''',
        'hyprctl': '''printf '%s\\n' "$*" >> "$EVENTS"
case $1 in
    -j) [[ ${QUERY_FAIL:-0} == 0 ]] || exit 1; echo 'mock JSON' ;;
    eval) [[ ${APPLY_FAIL:-0} == 0 ]] || exit 1; echo "${REPLY:-ok}" ;;
    reload) echo ok ;;
    *) exit 9 ;;
esac
''',
        'jq': '''cat >/dev/null
[[ ${BAD_DATA:-0} == 0 ]] || exit 1
if [[ ${CHANGED:-0} == 1 && -f $HOME/queried ]]; then echo eDP-1; exit 0; fi
touch "$HOME/queried"
printf '%s\\n' "${FIRST:-eDP-1}" "${SECOND:-HDMI-A-1}"
''',
        'wdisplays': 'echo gui >> "$EVENTS"',
        'notify-send': 'echo notice >> "$EVENTS"',
    }
    for name, text in commands.items():
        p = box/name
        p.write_text('#!/usr/bin/env bash\n'+text+'\n', newline='\n')
        p.chmod(0o700)
    env = {**os.environ, 'PATH':posix(box)+':/usr/bin:/bin', 'HOME':posix(box), 'EVENTS':posix(box/'events')}
    def run(extra=None, code=0, args=()):
        for name in ['second', 'queried']:
            (box/name).unlink(missing_ok=True)
        (box/'events').write_text('')
        result = subprocess.run([bash, str(root/'stow/desktop/.local/lib/graphite/display-menu.sh'),*args], env={**env, **(extra or {})}, cwd=box, capture_output=True, text=True)
        assert result.returncode == code, result.stdout+result.stderr
        return (box/'events').read_text()
    assert 'auto-right' in run()
    only=run(args=['only','eDP-1'])
    assert only.index('disabled = false') < only.index('disabled = true')
    assert 'output = "HDMI-A-1", disabled = true' in only
    other=run(args=['other','eDP-1'])
    assert 'output = "eDP-1", disabled = true' in other
    assert 'eval ' not in run({'CHANGED':'1'},args=['only','eDP-1'],code=1)
    assert 'auto-left' in run(args=['left','eDP-1'])
    assert 'mirror = "HDMI-A-1"' in run(args=['mirror','HDMI-A-1'])
    assert 'eval ' not in run(args=['right','disconnected'],code=1)
    run(args=['invalid','eDP-1'],code=2)
    run(args=['right'],code=2)
    assert 'auto-left' in run({'CHOICE':'1'})
    assert 'mirror = "eDP-1"' in run({'CHOICE':'2'})
    assert 'mirror = "HDMI-A-1"' in run({'CHOICE':'2', 'SELECTED':'1'})
    assert run({'CHOICE':'3'}) == 'gui\n'
    assert run({'CHOICE':'4'}) == 'reload\n'
    assert run({'CANCEL':'1'}) == ''
    for extra in [{'CANCEL_SECOND':'1'}, {'SELECTED':'99'}]:
        assert 'eval ' not in run(extra)
    for extra in [{'BAD_DATA':'1'}, {'QUERY_FAIL':'1'}, {'CHANGED':'1'}, {'SECOND':'eDP-1'}, {'FIRST':'bad";os.exit()'}]:
        assert 'eval ' not in run(extra, code=1)
    run({'APPLY_FAIL':'1'}, code=1)
    assert 'notice' in run({'REPLY':'Lua error'}, code=1)
    print('PASS display menu: extend/mirror selection, GUI/reload, cancellation, discovery failures, changed outputs, duplicate/unsafe names and apply errors (hyprctl/jq/Fuzzel mocked).')
if not list(checks.iterdir()):
    checks.rmdir()
