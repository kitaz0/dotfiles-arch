"""Popup command boundary regressions. No Qt, Wayland, jq evaluation or hardware."""
from pathlib import Path
import json, os, shutil, subprocess, tempfile

root = Path(__file__).resolve().parent.parent
bash = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else shutil.which('bash')
def posix(path):
    return subprocess.check_output([bash, '-c', 'cygpath -u "$1"', 'test', str(path)], text=True).strip() if os.name == 'nt' else str(path)

checks = root/'.checks'
checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks, prefix='quick-settings-') as folder:
    box = Path(folder)
    commands = {
        'timeout': '[[ $1 != --kill-after=* ]] || shift; shift; exec "$@"',
        'brightnessctl': '''printf 'brightness %s\\n' "$*" >> "$EVENTS"
[[ ${BRIGHTNESS_FAIL:-0} == 0 ]] || { echo 'Permission denied' >&2; exit 1; }
echo 'intel_backlight,backlight,50,50%,100'
''',
        'wpctl': '''printf 'audio %s\\n' "$*" >> "$EVENTS"
[[ ${AUDIO_FAIL:-0} == 0 ]] || exit 1
[[ $1 != get-volume ]] || echo 'Volume: 0.42 [MUTED]'
''',
        'systemctl': 'exit "${INACTIVE:-0}"',
        'nmcli': '''printf 'network %s\\n' "$*" >> "$EVENTS"
case "$*" in
    'radio wifi') echo enabled ;;
    '-g UUID connection show --active') echo 11111111-1111-1111-1111-111111111111 ;;
    '-t -f UUID,TYPE connection show') echo 11111111-1111-1111-1111-111111111111:802-11-wireless ;;
    '-g 802-11-wireless.ssid connection show uuid 11111111-1111-1111-1111-111111111111') echo 'WiFi $(touch forbidden)' ;;
esac
exit "${NETWORK_FAIL:-0}"
''',
        'bluetoothctl': '''printf 'bluetooth %s\\n' "$*" >> "$EVENTS"
[[ $1 != --timeout ]] || exit 9
[[ ${BT_FAIL:-0} == 0 ]] || exit 1
case "$*" in
    list)
        [[ ${NO_ADAPTER:-0} == 0 ]] || exit 0
        echo 'Controller 00:11:22:33:44:55 Laptop'
        [[ ${MULTIPLE:-0} == 0 ]] || echo 'Controller 11:22:33:44:55:66 USB' ;;
    show) echo 'Powered: yes' ;;
    'devices Paired'|'devices Connected') echo 'Device AA:BB:CC:DD:EE:FF Headphones $(touch forbidden)' ;;
esac
''',
        'pactl': 'printf "pactl <%s>\\n" "$@" >> "$EVENTS"; exit "${AUDIO_FAIL:-0}"',
        'jq': '''printf 'json <%s>\\n' "$@" >> "$EVENTS"
cat >/dev/null
echo '{"items":[]}'
''',
        'busctl': 'printf "busctl <%s>\\n" "$@" >> "$EVENTS"; exit "${BT_FAIL:-0}"',
        'swaync-client': 'printf "swaync <%s>\\n" "$@" >> "$EVENTS"',
        'notify-send': 'echo notice >> "$EVENTS"',
        'flock': 'exit "${LOCK_BUSY:-0}"',
        'qs': 'printf "qs-command %s\\n" "$1" >> "$EVENTS"; printf "qs <%s>\\n" "$@" >> "$EVENTS"; printf "page %s style %s\\n" "$GRAPHITE_SETTINGS_PAGE" "$QT_QUICK_CONTROLS_STYLE" >> "$EVENTS"',
    }
    for name, body in commands.items():
        p = box/name
        p.write_text('#!/usr/bin/env bash\n'+body+'\n', newline='\n')
        p.chmod(0o700)
    env = {**os.environ, 'PATH':posix(box)+':/usr/bin:/bin', 'HOME':posix(box), 'EVENTS':posix(box/'events'), 'XDG_RUNTIME_DIR':posix(box), 'WAYLAND_DISPLAY':'fixture'}
    def run(args, extra=None, code=0, launcher=False):
        (box/'events').write_text('')
        script='quick-settings.sh' if launcher else 'quick-settings-control.sh'
        p=subprocess.run([bash,str(root/'stow/desktop/.local/lib/graphite'/script),*args],env={**env,**(extra or {})},cwd=box,text=True,capture_output=True,timeout=15)
        assert p.returncode == code, (args,p.returncode,p.stdout,p.stderr)
        assert not (box/'forbidden').exists()
        return (box/'events').read_text(), p
    events,_=run(['brightness','35'])
    assert 'brightness -c backlight --min-value=1 set 35%' in events
    events,result=run(['brightness','35'],{'BRIGHTNESS_FAIL':'1'},1)
    assert 'Permission denied' in result.stderr
    for value in ['0','4','101','-5','5%;touch forbidden','nan','9999']:
        events,_=run(['brightness',value],code=1)
        assert 'brightness ' not in events
    for value in ['5','100','050']:
        run(['brightness',value])
    events,_=run(['volume','42'])
    assert 'audio set-volume -l 1 @DEFAULT_AUDIO_SINK@ 42%' in events
    run(['volume','42'],{'AUDIO_FAIL':'1'},1)
    for args in [['volume','101'],['unknown']]: run(args,code=1)
    events,_=run(['backlight'])
    assert 'json <intel_backlight>' in events and 'json <100>' in events
    _,result=run(['backlight'],{'BRIGHTNESS_FAIL':'1'})
    assert json.loads(result.stdout)=={'device':'','maximum':0}
    events,_=run(['levels'])
    assert 'json <42>' in events and 'json <50>' in events and 'json <true>' in events
    events,_=run(['levels'],{'BRIGHTNESS_FAIL':'1','AUDIO_FAIL':'1'})
    assert events.count('json <null>') >= 2
    events,_=run(['wifi'])
    assert 'WiFi $(touch forbidden)' in events and 'json <true>' in events
    run(['wifi'],{'INACTIVE':'1'},1)
    run(['wifi-connect','bad'],code=2)
    run(['wifi-connect','11111111-1111-1111-1111-111111111111'],{'NETWORK_FAIL':'1'},1)
    events,_=run(['bluetooth'])
    assert 'Headphones $(touch forbidden)' in events
    assert 'bluetooth info' not in events
    for extra in [{'NO_ADAPTER':'1'},{'MULTIPLE':'1'},{'BT_FAIL':'1'},{'INACTIVE':'1'}]:
        events,_=run(['bluetooth-connect','AA:BB:CC:DD:EE:FF'],extra,1)
        assert 'bluetooth connect' not in events
    run(['bluetooth-connect','AA:BB:CC:DD:EE:FF'])
    run(['bluetooth-disconnect','bad'],code=2)
    events,_=run(['sink','name $(touch forbidden)'])
    assert 'pactl <name $(touch forbidden)>' in events
    run(['sink','-bad'],code=2)
    events,_=run(['bt-operation','connect','/org/bluez/hci1/dev_AA_BB_CC_DD_EE_FF'])
    assert 'busctl <org.bluez.Device1>' in events and 'busctl <Connect>' in events
    events,_=run(['bt-operation','forget','/org/bluez/hci1/dev_AA_BB_CC_DD_EE_FF'])
    assert 'busctl <RemoveDevice>' in events and 'busctl </org/bluez/hci1>' in events
    run(['bt-operation','on','/org/bluez/hci0'],{'BT_FAIL':'1'},1)
    for bad in ['/org/bluez/hci0/../../system', '/org/bluez/hci0;touch forbidden', 'hci0']:
        events,_=run(['bt-operation','on',bad],code=1)
        assert 'busctl ' not in events
    events,_=run(['notifications'],launcher=True)
    assert 'qs <close>' in events and 'swaync <--toggle-panel>' in events
    assert events.index('qs <close>') < events.index('swaync <--toggle-panel>')
    events,_=run(['audio'],launcher=True)
    assert 'page audio style Basic' in events and 'qs <-p>' in events and 'shell.qml>' in events
    events,_=run(['brightness'],launcher=True)
    assert 'page brightness style Basic' in events
    events,_=run(['wifi'],{'LOCK_BUSY':'1'},launcher=True)
    assert 'qs <ipc>' in events and 'qs <toggle>' in events and 'qs <wifi>' in events
    assert 'qs-command -p' not in events
    events,_=run(['home'],{'LOCK_BUSY':'1'},launcher=True)
    assert 'qs <ipc>' in events and 'qs <toggle>' in events
    events,_=run(['clipboard'],{'LOCK_BUSY':'1'},launcher=True)
    assert 'qs <ipc>' in events and 'qs <toggle>' in events and 'qs <clipboard>' in events
    run(['invalid'],code=2,launcher=True)
    (box/'qs').rename(box/'qs.saved')
    missing=box/'missing.sh'
    missing.write_text('command() { if [[ $1 == -v && ${2:-} == qs ]]; then return 1; fi; builtin command "$@"; }\n')
    events,_=run(['home'],{'BASH_ENV':posix(missing)},code=1,launcher=True)
    assert 'notice' in events

config=json.loads((root/'stow/desktop/.config/graphite/waybar/config.jsonc').read_text(encoding='utf-8'))
assert not any('/slider' in key or key.startswith('group/') for key in config)
for key in ['network','bluetooth','wireplumber','backlight','custom/displays']:
    assert 'quick-settings.sh' in config[key]['on-click']
print('PASS quick-settings command fixtures: brightness bounds/access failure, volume failure, unavailable hardware, Wi-Fi/Bluetooth guards, literal device names, popup routing and duplicate-launch guard (commands/jq mocked).')
print('SKIP quick-settings GUI/QML and jq transformation execution: requires installed Qt/Quickshell and jq on Linux. Waybar slider removal checked statically.')
if not list(checks.iterdir()): checks.rmdir()
