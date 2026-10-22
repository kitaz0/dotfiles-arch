"""Verifier reporting and read-only session probes using disposable command fixtures."""
from pathlib import Path
import os, re, shutil, subprocess, tempfile

root = Path(__file__).resolve().parent.parent
bash = shutil.which('bash')
if os.name == 'nt':
    print('SKIP verification fixtures: POSIX permissions and target-machine service probes require Linux.')
    raise SystemExit(0)
checks = root / '.checks'
checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks, prefix='verify-') as folder:
    box = Path(folder)
    project = box / 'project'
    home = box / 'home'
    commands = box / 'bin'
    for path in [project, home, commands]:
        path.mkdir()
    (project / 'verify-setup.sh').write_text((root / 'verify-setup.sh').read_text().replace(
        '/usr/lib/hyprpolkitagent/hyprpolkitagent', str(commands / 'hyprpolkitagent')))
    helper_source = project / 'stow/desktop/.local/lib/graphite/helper.sh'
    helper_source.parent.mkdir(parents=True)
    helper_source.write_text('#!/bin/bash\nexit 0\n')
    helper_source.chmod(0o700)
    installed = home / '.local/lib/graphite/helper.sh'
    installed.parent.mkdir(parents=True)
    installed.symlink_to(helper_source)
    for package, rel in [('kitty', '.config/kitty/kitty.conf'), ('starship', '.config/starship.toml'), ('nvim', '.config/nvim/init.lua')]:
        source = project / 'stow' / package / rel
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_text('fixture config\n')
        target = home / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.symlink_to(source)
    for rel in ['config', 'profile', 'conf/classicui.conf']:
        target = home / '.config/graphite/fcitx5' / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('local writable settings\n')
    def stub(name, body):
        path = commands / name
        path.write_text('#!/usr/bin/env bash\n'+body+'\n')
        path.chmod(0o700)
    for name in ['hyprpolkitagent', 'stow', 'starship', 'qs', 'systemd-run', 'dbus-update-activation-environment', 'busctl', 'pgrep',
                 'start-hyprland', 'Hyprland', 'hyprctl', 'kitty', 'dolphin', 'waybar', 'fuzzel',
                 'swaybg', 'hyprlock', 'hypridle', 'swaync', 'swaync-client', 'cliphist', 'wl-copy',
                 'wl-paste', 'wpctl', 'udisksctl', 'udevadm', 'notify-send', 'grim', 'slurp', 'satty',
                 'wf-recorder', 'ffprobe', 'pavucontrol', 'pactl', 'playerctl', 'brightnessctl',
                 'wdisplays', 'bluetoothctl', 'bluedevil-wizard', 'kcmshell6', 'nmcli', 'nmtui',
                 'fcitx5', 'fcitx5-remote', 'fcitx5-configtool', 'zsh', 'pacman']:
        stub(name, 'echo successful-diagnostic-marker')
    stub('nvim', 'echo NVIM v0.11.4')
    stub('fc-match', 'printf "%s\\n" "${!#}"')
    stub('jq', '''if [[ $1 == -er ]]; then
    [[ ${BAD_MONITORS:-0} != 1 ]] || exit 1
    echo 1
else exit 0; fi''')
    stub('timeout', '''[[ $1 != --kill-after=* ]] || shift
shift
if [[ $1 == /usr/lib/qt6/bin/qmllint ]]; then echo successful-diagnostic-marker; exit 0; fi
exec "$@"''')
    stub('hyprctl', '''case $* in
    configerrors) [[ ${BAD_CONFIG:-0} != 1 ]] || { echo 'invalid rule'; exit 0; }; echo ok ;;
    '-j monitors') echo '[{"name":"eDP-1"}]' ;;
    *) exit 99 ;;
esac''')
    stub('busctl', 'echo "b true"')
    stub('systemctl', '''printf '%s\\n' "$*" >> "$CALLS"
case $* in
    '--user show-environment')
        [[ ${NO_MANAGER:-0} != 1 ]] || { echo 'access denied'; exit 1; }
        echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP}"
        echo 'WAYLAND_DISPLAY=wayland-test'
        if [[ ${STALE:-0} == 1 ]]; then echo 'HYPRLAND_INSTANCE_SIGNATURE=stale'; fi ;;
    '--user show graphite-'*)
        if [[ ${LEFTOVER:-0} == 1 ]]; then echo active; else echo inactive; fi ;;
    '--user is-active graphite-session.service') [[ ${HELPERS_DOWN:-0} != 1 ]] ;;
    '--user is-active '*|'is-active '*|'--user status '*) echo active ;;
    'show -p Version --value') [[ ${NO_SYSTEM:-0} != 1 ]] || { echo 'access denied'; exit 1; }; echo 260 ;;
    *) echo 'Unexpected service command' >&2; exit 99 ;;
esac''')
    env = {**os.environ, 'HOME': str(home), 'PATH': str(commands)+':/usr/bin:/bin',
           'XDG_CURRENT_DESKTOP': 'KDE', 'XDG_SESSION_TYPE': 'wayland',
           'WAYLAND_DISPLAY': 'wayland-test', 'CALLS': str(box / 'calls')}
    for name in ['BASH_ENV', 'DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE']:
        env.pop(name, None)
    def snapshot():
        return {str(p.relative_to(home)): (p.read_bytes(), p.stat().st_mode) for p in home.rglob('*') if p.is_file()}
    def run(args=(), extra=None, code=0):
        before = snapshot()
        result = subprocess.run([bash, str(project / 'verify-setup.sh'), *args], env={**env, **(extra or {})}, text=True, capture_output=True, timeout=15)
        assert result.returncode == code, result.stdout+result.stderr
        assert snapshot() == before, 'Verifier changed installed files'
        counts = re.search(r'Summary: (\d+) passed, (\d+) failed, (\d+) warnings, (\d+) skipped', result.stdout)
        if counts:
            actual = [sum(line.startswith(level+' ') for line in result.stdout.splitlines()) for level in ['PASS', 'FAIL', 'WARN', 'SKIP']]
            assert list(map(int, counts.groups())) == actual, result.stdout
        return result.stdout
    text = run()
    assert 'No active Graphite services' in text and 'Fcitx settings are local' in text
    assert 'successful-diagnostic-marker' not in text
    assert 'Application dependencies' not in run(['--desktop-only'])
    installed.unlink()
    installed.write_text('#!/bin/bash\nexit 0\n')
    installed.chmod(0o700)
    assert 'Not linked to this checkout:' in run(code=1)
    installed.unlink()
    installed.symlink_to(helper_source)
    assert 'successful-diagnostic-marker' in run(['--verbose'])
    assert 'Session activation environment differs' in run(extra={'STALE': '1'})
    assert 'Graphite services remain' in run(extra={'LEFTOVER': '1'})
    assert 'user manager unavailable' in run(extra={'NO_MANAGER': '1'})
    assert 'system manager unavailable' in run(extra={'NO_SYSTEM': '1'})
    session = {'XDG_CURRENT_DESKTOP': 'Graphite:Hyprland', 'HYPRLAND_INSTANCE_SIGNATURE': 'test'}
    assert 'Compositor has 1 active output' in run(extra=session)
    assert 'Running compositor configuration errors' in run(extra={**session, 'BAD_CONFIG': '1'}, code=1)
    assert 'Graphite helper service active' in run(extra={**session, 'HELPERS_DOWN': '1'}, code=1)
    assert 'invalid monitor response' in run(extra={**session, 'BAD_MONITORS': '1'}, code=1)
    installed.write_text('#!/bin/bash\nif\n')
    installed.chmod(0o600)
    assert 'Not executable:' in run(code=1)
    installed.unlink()
    assert 'Missing installed file:' in run(code=1)
    (box / 'calls').unlink(missing_ok=True)
    assert 'Usage:' in run(['--help'])
    assert not (box / 'calls').exists()
    run(['--unknown'], code=2)
    run(['--verbose', 'extra'], code=2)
print('PASS verifier: summary counts, compact/verbose output, exit codes, missing/invalid helpers, Stow ownership, local profiles, stale environment, cleanup, inaccessible manager, compositor errors/output validation and unchanged fixture home.')
