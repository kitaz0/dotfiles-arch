"""Command/udev-stream fixtures, not Linux hardware or popup rendering tests."""
from pathlib import Path
import os, shutil, subprocess, tempfile

root = Path(__file__).resolve().parent.parent
bash = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else shutil.which('bash')
def posix(path):
    return subprocess.check_output([bash, '-c', 'cygpath -u "$1"', 'test', str(path)], text=True).strip() if os.name == 'nt' else str(path)

checks = root / '.checks'
checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks, prefix='controls-') as directory:
    box = Path(directory)
    commands = {
        'brightnessctl': '''printf 'brightness %s\n' "$*" >> "$EVENTS"
[[ ${FAIL_CONTROL:-0} == 0 ]] || exit 1
[[ $* == '-c backlight -m --min-value=1 set '* ]] || exit 9
printf 'intel_backlight,backlight,450,45%%,1000\n'
''',
        'wpctl': '''printf 'wpctl %s\n' "$*" >> "$EVENTS"
[[ ${FAIL_CONTROL:-0} == 0 ]] || exit 1
[[ $1 != get-volume ]] || echo "${VOLUME_STATE:-Volume: 0.45}"
''',
        'notify-send': '''printf 'notification %s\n' "$*" >> "$EVENTS"
exit "${NOTIFY_FAIL:-0}"
''',
        'systemctl': 'exit "${NETWORK_INACTIVE:-0}"',
        'nmcli': '''printf 'nmcli %s\n' "$*" >> "$EVENTS"
case "$*" in
    'radio wifi') echo enabled ;;
    '-g UUID connection show --active') echo "${ACTIVE_WIFI:-}" ;;
    '-g UUID connection show') printf 'wifi-id\nethernet-id\n' ;;
    '-g connection.type connection show uuid wifi-id') echo 802-11-wireless ;;
    '-g connection.type connection show uuid ethernet-id') echo 802-3-ethernet ;;
    '-g connection.id connection show uuid wifi-id') echo 'Home $(touch forbidden)' ;;
    '-g 802-11-wireless.ssid connection show uuid wifi-id') echo 'Actual SSID' ;;
    '-g GENERAL.DEVICES connection show uuid wifi-id') echo '../not-an-interface' ;;
    '--wait 15 connection up uuid wifi-id') exit "${CONNECT_FAIL:-0}" ;;
    'radio wifi off') : ;;
    *) exit 9 ;;
esac
''',
        'fuzzel': '''cat > "$MENU"
[[ ${CANCEL:-0} == 0 ]] || exit 1
echo "${CHOICE:-2}"
''',
        'udevadm': 'cat "$UDEV_EVENTS"',
        'dolphin': '''printf 'dolphin %s|config=%s|dirs=%s|theme=%s|style=%s|parent=%s\n' "$*" "${XDG_CONFIG_HOME-unset}" "${XDG_CONFIG_DIRS-unset}" "${QT_QPA_PLATFORMTHEME-unset}" "${QT_STYLE_OVERRIDE-unset}" "${GRAPHITE_PARENT_CONFIG_HOME-unset}" >> "$EVENTS"''',
        'kitty': '''printf 'kitty %s|config=%s|dirs=%s|theme=%s|private=%s\n' "$*" "${XDG_CONFIG_HOME-unset}" "${XDG_CONFIG_DIRS-unset}" "${QT_QPA_PLATFORMTHEME-unset}" "${GRAPHITE_DOLPHIN_CONFIG-unset}" >> "$EVENTS"''',
        'pavucontrol': '''printf 'mixer %s\n' "$*" >> "$EVENTS"''',
        'pactl': '''printf 'pactl %s\n' "$*" >> "$EVENTS"
[[ ${FAIL_PACTL:-0} == 0 ]] || exit 1
case "$*" in
    '--format=json list sinks'|'--format=json list sources') echo '[]' ;;
    get-default-sink|get-default-source) echo sink-a ;;
    'set-default-sink sink-b'|'set-default-source sink-b') : ;;
    *) exit 9 ;;
esac
''',
        # Only command construction is tested here; jq itself is unavailable locally.
        'jq': '''data=$(cat)
case "$*" in
    '-c .[] | {name, description}')
        [[ ${NO_DEVICES:-0} == 0 ]] || exit 0
        printf '{"name":"sink-a"}\n{"name":"sink-b"}\n' ;;
    '-r .name')
        [[ $data != *sink-a* ]] || { echo sink-a; exit 0; }
        echo sink-b ;;
    '-r .description | gsub('* ) echo 'Device $(touch forbidden)' ;;
    *) exit 9 ;;
esac
''',
    }
    for name, contents in commands.items():
        path = box / name
        path.write_text('#!/usr/bin/env bash\n' + contents + '\n', newline='\n')
        path.chmod(0o700)
    shim = box / 'env.sh'
    shim.write_text('compgen() { [[ ${NO_BACKLIGHT:-0} == 0 ]]; }\n', newline='\n')
    env = os.environ.copy()
    env.update(PATH=posix(box) + ':/usr/bin:/bin', HOME=posix(box), EVENTS=posix(box/'events'),
               MENU=posix(box/'menu'), BASH_ENV=posix(shim), UDEV_EVENTS=posix(box/'udev'))
    def run(script, arg=None, extra=None, code=0):
        (box/'events').write_text('')
        args = arg if isinstance(arg, list) else ([arg] if arg else [])
        result = subprocess.run([bash, str(root/'stow/desktop/.local/lib/graphite'/script), *args],
                                env={**env, **(extra or {})}, text=True, capture_output=True, cwd=box)
        assert result.returncode == code, result.stdout + result.stderr
        return (box/'events').read_text()
    for action, suffix in [('up', '+5%'), ('down', '5%-')]:
        events = run('brightness.sh', action)
        assert '--min-value=1 set ' + suffix in events and 'int:value:45' in events
    assert run('brightness.sh', 'down', {'NO_BACKLIGHT':'1'}) == ''
    assert 'notification' not in run('brightness.sh', 'down', {'FAIL_CONTROL':'1'}, code=1)
    run('brightness.sh', 'wrong', code=2)
    run('brightness.sh', 'up', {'NOTIFY_FAIL':'1'})
    for action in ['up', 'down', 'mute', 'mic']:
        assert 'boolean:transient:true' in run('volume.sh', action)
    assert 'Microphone muted' in run('volume.sh', 'mic', {'VOLUME_STATE':'Volume: 0.00 [MUTED]'})
    assert 'int:value:100' in run('volume.sh', 'up', {'VOLUME_STATE':'Volume: 1.20'})
    assert 'notification' not in run('volume.sh', 'down', {'FAIL_CONTROL':'1'}, code=1)
    run('volume.sh', 'invalid', code=2)
    events = run('network-menu.sh')
    assert 'connection up uuid wifi-id' in events
    assert 'Home $(touch forbidden)' in (box/'menu').read_text() and not (box/'forbidden').exists()
    assert 'connection up' not in run('network-menu.sh', extra={'CANCEL':'1'})
    assert 'radio wifi off' in run('network-menu.sh', extra={'CHOICE':'0'})
    assert 'Wi-Fi connection failed' in run('network-menu.sh', extra={'CONNECT_FAIL':'1'}, code=1)
    assert 'nmcli' not in run('network-menu.sh', extra={'NETWORK_INACTIVE':'1'})
    events = run('network-menu.sh', extra={'ACTIVE_WIFI':'wifi-id'})
    assert 'CONNECTED: Actual SSID' in (box/'menu').read_text()
    assert 'connection up' not in events and not (box/'forbidden').exists()
    # Separate audio menu must not toggle the notification centre.
    for choice, tab in [('8','1'), ('9','2'), ('10','3'), ('11','4'), ('12','5')]:
        assert 'mixer --tab='+tab in run('audio-menu.sh', extra={'CHOICE':choice})
    assert 'mixer' not in run('audio-menu.sh', extra={'CANCEL':'1'})
    # Root selection then device selection: Fuzzel receives each menu independently.
    fuzzel = box/'fuzzel'
    fuzzel.write_text('''#!/usr/bin/env bash
cat > "$MENU"
case "$*" in
    *'Audio device:'*) echo "${DEVICE_CHOICE:-1}" ;;
    *) echo "${CHOICE:-6}" ;;
esac
''', newline='\n')
    for choice, kind in [('6','sink'), ('7','source')]:
        events = run('audio-menu.sh', extra={'CHOICE':choice})
        assert 'set-default-'+kind+' sink-b' in events
        assert 'CURRENT:' in (box/'menu').read_text() and not (box/'forbidden').exists()
    assert 'set-default-' not in run('audio-menu.sh', extra={'NO_DEVICES':'1'})
    assert 'set-default-' not in run('audio-menu.sh', extra={'FAIL_PACTL':'1'}, code=1)
    assert 'set-default-' not in run('audio-menu.sh', extra={'DEVICE_CHOICE':'999'}, code=1)
    # Only Graphite-launched Dolphin is isolated. Its Kitty/editor child is restored.
    local = box/'.local/lib/graphite'
    local.mkdir(parents=True)
    shutil.copyfile(root/'stow/desktop/.local/lib/graphite/dolphin.sh', local/'dolphin.sh')
    (local/'dolphin.sh').chmod(0o700)
    personal = box/'.config/kdeglobals'
    personal.parent.mkdir()
    personal.write_text('personal KDE configuration\n')
    context = {'XDG_CURRENT_DESKTOP':'Graphite:Hyprland','XDG_CONFIG_HOME':'/personal-config',
               'XDG_CONFIG_DIRS':'/personal-dirs','QT_QPA_PLATFORMTHEME':'original-theme'}
    events = run('dolphin.sh', arg=['folder with spaces'], extra=context)
    assert '/.config/graphite/dolphin' in events and 'dirs=/personal-config:/personal-dirs' in events
    assert 'theme=kde' in events and 'dolphin --new-window folder with spaces' in events
    events = run('dolphin.sh', extra={**context,'XDG_CURRENT_DESKTOP':'KDE'})
    assert 'config=/personal-config' in events and 'theme=original-theme' in events
    assert '--new-window' not in events and '/.config/graphite/dolphin' not in events
    run('launch-app.sh', ['dolphin','folder with spaces'], extra=context)
    assert 'kitty --version' in run('launch-app.sh', ['kitty','--version'])
    events = run('terminal.sh', ['-e','vim','file with spaces.txt'], extra={
        **context, 'GRAPHITE_DOLPHIN_CONFIG':'1', 'GRAPHITE_PARENT_CONFIG_HOME':'/normal-config',
        'GRAPHITE_PARENT_CONFIG_DIRS':'/normal-dirs','GRAPHITE_PARENT_QT_PLATFORM':'original-theme'})
    assert 'config=/normal-config' in events and 'dirs=/normal-dirs' in events and 'private=unset' in events
    assert 'theme=original-theme' in events and '-e vim file with spaces.txt' in events
    assert personal.read_text() == 'personal KDE configuration\n'
    print('PASS popup/profile commands: active Wi-Fi marker, separate audio controls/device selection/failures (pactl/jq mocked), private Dolphin argv/env and terminal restoration; KDE file unchanged')
    (box/'udev').write_text('''monitor will print the received events for:

UDEV [10.0] add /devices/pci/usb/block/sdb (block)
ACTION=add
DEVTYPE=disk
ID_BUS=usb

UDEV [10.1] add /devices/pci/usb/block/sdb/sdb1 (block)
ACTION=add
DEVTYPE=partition
ID_BUS=usb

ACTION=change
DEVTYPE=disk
ID_BUS=usb

ACTION=add
DEVTYPE=disk
ID_BUS=ata

ACTION=remove
DEVTYPE=disk
ID_BUS=usb

''', newline='\n')
    assert run('usb-notify.sh').count('USB drive connected') == 1
    print('PASS desktop controls: brightness option/absence/failure, volume/mute popups, network menu cancellation/UUID selection/failure, USB disk-only event notifications (mocks)')
if not list(checks.iterdir()):
    checks.rmdir()
