"""Bluetooth popup fixtures; does not exercise BlueZ, pairing, D-Bus or hardware."""
from pathlib import Path
import os, shutil, subprocess, tempfile

root = Path(__file__).resolve().parent.parent
bash = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else shutil.which('bash')
def posix(path):
    return subprocess.check_output([bash, '-c', 'cygpath -u "$1"', 'test', str(path)], text=True).strip() if os.name == 'nt' else str(path)

checks = root/'.checks'
checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks, prefix='bluetooth-') as directory:
    box = Path(directory)
    commands = {
        'fuzzel': '''cat > "$HOME/menu"
[[ ${CANCEL:-0} == 0 ]] || exit 1
echo "${CHOICE:-3}"
''',
        'systemctl': 'exit "${INACTIVE:-0}"',
        'notify-send': 'printf "notice %s\\n" "$*" >> "$EVENTS"',
        'bluedevil-wizard': 'echo wizard >> "$EVENTS"',
        'kcmshell6': 'printf "settings %s\\n" "$*" >> "$EVENTS"',
        'timeout': '''[[ $1 == --kill-after=1s && $2 == 10s && $3 == bluetoothctl ]] || exit 9
shift 2
exec "$@"
''',
        'bluetoothctl': '''[[ $1 != --timeout ]] || exit 9
printf 'bt %s\\n' "$*" >> "$EVENTS"
case "$*" in
    list)
        [[ ${QUERY_FAIL:-0} == 0 ]] || exit 1
        [[ ${NO_ADAPTER:-0} == 0 ]] || exit 0
        echo 'Controller 00:11:22:33:44:55 Laptop [default]'
        [[ ${MULTIPLE:-0} == 0 ]] || echo 'Controller 11:22:33:44:55:66 USB' ;;
    show) echo "Powered: ${POWERED:-yes}" ;;
    'devices Paired')
        [[ ${NO_DEVICES:-0} == 0 ]] || exit 0
        echo 'Device AA:BB:CC:DD:EE:FF Headphones $(touch forbidden)'
        echo 'Device INVALID bad address' ;;
    'devices Connected')
        [[ ${CONNECTED_QUERY_FAIL:-0} == 0 ]] || exit 1
        [[ ${CONNECTED:-yes} != yes ]] || echo 'Device AA:BB:CC:DD:EE:FF Headphones' ;;
    'power off'|'power on'|'connect AA:BB:CC:DD:EE:FF'|'disconnect AA:BB:CC:DD:EE:FF') exit "${ACTION_FAIL:-0}" ;;
    *) exit 9 ;;
esac
''',
    }
    for name, text in commands.items():
        p=box/name;p.write_text('#!/usr/bin/env bash\n'+text+'\n',newline='\n');p.chmod(0o700)
    env={**os.environ,'PATH':posix(box)+':/usr/bin:/bin','HOME':posix(box),'EVENTS':posix(box/'events')}
    def run(extra=None, code=0):
        (box/'events').write_text('')
        result=subprocess.run([bash,str(root/'stow/desktop/.local/lib/graphite/bluetooth-menu.sh')],env={**env,**(extra or {})},cwd=box,text=True,capture_output=True)
        assert result.returncode == code, result.stdout+result.stderr
        assert not (box/'forbidden').exists()
        return (box/'events').read_text()
    events=run()
    assert 'bt disconnect AA:BB:CC:DD:EE:FF' in events
    assert len([line for line in events.splitlines() if line.startswith('bt ')]) == 5
    assert 'bt info' not in events
    assert 'CONNECTED:' in (box/'menu').read_text(encoding='utf-8')
    assert 'bt connect AA:BB:CC:DD:EE:FF' in run({'CONNECTED':'no'})
    assert 'bt power off' in run({'CHOICE':'0'})
    assert 'bt power on' in run({'CHOICE':'0','POWERED':'no'})
    assert 'wizard' in run({'CHOICE':'1'})
    assert 'settings kcm_bluetooth' in run({'CHOICE':'2'})
    assert 'settings kcm_bluetooth' in run({'MULTIPLE':'1'})
    assert 'bt show' not in run({'NO_ADAPTER':'1'})
    assert 'bt ' not in run({'INACTIVE':'1'},code=1)
    assert 'notice' in run({'QUERY_FAIL':'1'},code=1)
    assert 'notice' in run({'CONNECTED_QUERY_FAIL':'1'},code=1)
    assert 'notice' in run({'ACTION_FAIL':'1'},code=1)
    assert 'notice' in run({'ACTION_FAIL':'1','CHOICE':'0'},code=1)
    for extra in [{'CANCEL':'1'},{'CHOICE':'999'},{'CHOICE':'abc'},{'CHOICE':'4'},{'NO_DEVICES':'1'}]:
        events=run(extra)
        assert 'bt disconnect' not in events and 'bt connect ' not in events
    # Missing client fails with a diagnostic; no service activation is attempted.
    (box/'bluetoothctl').rename(box/'bluetoothctl.saved')
    assert 'notice' in run(code=1)
    # Shared-menu routing with isolated sibling helpers.
    shutil.copyfile(root/'stow/desktop/.local/lib/graphite/connectivity-menu.sh',box/'connectivity-menu.sh')
    for name in ['network','bluetooth']:
        p=box/(name+'-menu.sh');p.write_text('#!/usr/bin/env bash\necho '+name+' >> "$EVENTS"\n',newline='\n');p.chmod(0o700)
    for choice,expected in [('0','network'),('1','bluetooth'),('9','')]:
        (box/'events').write_text('')
        result=subprocess.run([bash,str(box/'connectivity-menu.sh')],env={**env,'CHOICE':choice},cwd=box,capture_output=True,text=True)
        assert result.returncode == 0, result.stderr
        assert (box/'events').read_text().strip() == expected
    print('PASS Bluetooth/connectivity menus: power, connect/disconnect, pairing/settings routing, cancellation, unsafe names, missing client/service/adapter, multiple adapters and failures (commands mocked).')
if not list(checks.iterdir()):
    checks.rmdir()
