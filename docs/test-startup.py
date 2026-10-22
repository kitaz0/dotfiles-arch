"""Command-level lifecycle regressions. Does not emulate systemd/Wayland."""
from pathlib import Path
import os, shutil, subprocess, tempfile
root=Path(__file__).resolve().parent.parent
bash=r'C:\Program Files\Git\bin\bash.exe' if os.name=='nt' else shutil.which('bash')
def posix(p):
    return subprocess.check_output([bash,'-c','cygpath -u "$1"','test',str(p)],text=True).strip() if os.name=='nt' else str(p)
checks=root/'.checks'; checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks,prefix='startup-') as directory:
    box=Path(directory); (box/'bin').mkdir(); (box/'runtime').mkdir()
    env=os.environ.copy()
    for key in ['BASH_ENV','DISPLAY','WAYLAND_DISPLAY','AQ_DRM_DEVICES','INVOCATION_ID']: env.pop(key,None)
    env.update(HOME=posix(box),XDG_RUNTIME_DIR=posix(box/'runtime'),PATH=posix(box/'bin')+':/usr/bin:/bin',EVENTS=posix(box/'events'))
    # SDDM's supplied wayland-session ends with unquoted exec $@.
    # Quotes embedded in a single command-string argument are not shell syntax.
    entry=(root/'session/graphite-hyprland.desktop').read_text()
    assert 'Name=Hyprland (Graphite/Gruvbox)' in entry
    command=next(line[5:] for line in entry.splitlines() if line.startswith('Exec='))
    for home_name in ['session-home']:
        home=box/home_name
        launcher=home/'.local/lib/graphite/start-session.sh'
        launcher.parent.mkdir(parents=True)
        launcher.write_text('#!/bin/sh\nprintf "session-entry-ok\\n"\n',newline='\n')
        launcher.chmod(0o700)
        trial={**env,'HOME':posix(home)}
        old='/bin/sh -c "exec ~/.local/lib/graphite/start-session.sh"'
        failed=subprocess.run([bash,'-c','exec $@','wayland-session',old],env=trial,text=True,capture_output=True)
        assert failed.returncode==2,failed.stdout+failed.stderr
        for args in [(command,),tuple(command.split())]:
            result=subprocess.run([bash,'-c','exec $@','wayland-session',*args],env=trial,text=True,capture_output=True)
            assert result.returncode==0 and result.stdout.strip()=='session-entry-ok',result.stdout+result.stderr
    print('PASS SDDM entry: old quoting reproduces exit 2; corrected entry launches with command string or argv (shell fixture only; conventional HOME path)')
    stubs={
        'systemctl':'''printf 'systemctl %s\n' "$*" >> "$EVENTS"
[[ ${FAIL_MANAGER:-0} != 1 || $* != '--user show-environment' ]]''',
        'start-hyprland':'''printf 'watchdog %s | gpu=%s | config_home=%s\n' "$*" "${AQ_DRM_DEVICES-unset}" "${XDG_CONFIG_HOME-unset}" >> "$EVENTS"
exit "${WATCHDOG_EXIT:-0}"''',
        'dbus-update-activation-environment':'''printf 'dbus %s\n' "$*" >> "$EVENTS"
exit "${DBUS_EXIT:-0}"''',
        'systemd-run':'''printf 'run %s\n' "$*" >> "$EVENTS"
exit "${RUN_EXIT:-0}"''',
    }
    for name,body in stubs.items():
        p=box/'bin'/name;p.write_text('#!/usr/bin/env bash\n'+body+'\n',newline='\n');p.chmod(0o700)
    def run(script,args=(),extra=None,expected=0):
        trial=env.copy();trial.update(extra or {});(box/'events').write_text('')
        p=subprocess.run([bash,str(root/'stow/desktop/.local/lib/graphite'/script),*args],cwd=root,env=trial,text=True,capture_output=True)
        assert p.returncode==expected,p.stdout+p.stderr
        return (box/'events').read_text()
    for gpu,code in [(None,0),('/dev/dri/card7:/dev/dri/card3',0),(None,7)]:
        extra={'WATCHDOG_EXIT':str(code),'XDG_CONFIG_HOME':'/personal-config'}
        if gpu:extra['AQ_DRM_DEVICES']=gpu
        events=run('start-session.sh',extra=extra,expected=code)
        assert 'gpu='+str(gpu or 'unset') in events and 'config_home=/personal-config' in events
        assert '/.config/graphite/hypr/hyprland.lua' in events
        assert events.index('stop graphite-recorder.service') < events.index('stop graphite-session.service')
        assert 'set-environment' not in events and 'portal' not in events
    assert 'watchdog' not in run('start-session.sh',extra={'FAIL_MANAGER':'1'},expected=1)
    assert run('start-session.sh',extra={'WAYLAND_DISPLAY':'existing'},expected=1)==''
    assert run('start-session.sh',args=('--invalid',),expected=2)==''
    session={'XDG_CURRENT_DESKTOP':'Graphite:Hyprland','WAYLAND_DISPLAY':'wayland-1','HYPRLAND_INSTANCE_SIGNATURE':'test-signature'}
    events=run('session-start.sh',extra=session)
    assert events.index('dbus ') < events.index('run ')
    assert '--property=ExitType=cgroup' in events and '--property=KillMode=control-group' in events
    assert '--setenv=WAYLAND_DISPLAY=wayland-1' in events and 'portal' not in events
    run('session-start.sh',extra={**session,'RUN_EXIT':'6'},expected=6)
    events=run('session-start.sh',extra={**session,'DBUS_EXIT':'5'},expected=5)
    assert 'run ' not in events
    assert run('session-start.sh',extra={**session,'XDG_CURRENT_DESKTOP':'KDE'},expected=1)==''
    print('PASS startup: native GPU/environment preservation, dedicated config, watchdog failure, ordered cleanup, manager/nested/argument rejection')
    print('PASS startup: helper cgroup properties, environment barrier, launch/bus failures, foreign desktop rejection (command mocks only)')
    # Resume recovery must never touch a foreign desktop or unlock the session.
    for name,body in {
        'hyprctl': '''printf 'hyprctl %s\\n' "$*" >> "$EVENTS"
[[ ${FAIL_WAKE:-0} != 1 || $* != *dpms* ]]''',
        'sleep': '''printf 'sleep %s\\n' "$*" >> "$EVENTS"''',
    }.items():
        p=box/'bin'/name;p.write_text('#!/usr/bin/env bash\n'+body+'\n',newline='\n');p.chmod(0o700)
    events=run('resume.sh',extra=session)
    assert events.splitlines()==[
        'hyprctl dispatch hl.dsp.dpms({ action = "enable" })',
        'sleep 0.5',
        'hyprctl dispatch hl.dsp.force_renderer_reload()',
    ],events
    assert 'force_renderer_reload' not in run('resume.sh',extra={**session,'FAIL_WAKE':'1'},expected=1)
    for extra in [{'XDG_CURRENT_DESKTOP':'KDE'}, {'HYPRLAND_INSTANCE_SIGNATURE':''}, {'WAYLAND_DISPLAY':''}]:
        assert run('resume.sh',extra={**session,**extra})==''
    print('PASS resume: desktop/session guards, wake-before-refresh and failed-wake handling; no unlock (mocked, not a suspend test)')
    # Execute the finite helper launcher with short-lived command substitutes.
    for name in ['waybar','swaybg','hypridle','swaync','wl-paste','cliphist']:
        p=box/'bin'/name
        p.write_text('#!/usr/bin/env bash\nprintf "helper '+name+' %s\\n" "$*" >> "$EVENTS"\n',newline='\n');p.chmod(0o700)
    p=box/'bin/busctl';p.write_text('#!/usr/bin/env bash\necho "b false"\n',newline='\n');p.chmod(0o700)
    # Simulate an existing foreign polkit agent (absolute host agent is never run).
    p=box/'bin/pgrep';p.write_text('#!/usr/bin/env bash\n[[ $* == *polkit* ]]\n',newline='\n');p.chmod(0o700)
    (box/'.local/lib/graphite').mkdir(parents=True)
    p=box/'.local/lib/graphite/waybar.sh';p.write_text('#!/usr/bin/env bash\nwaybar\n',newline='\n');p.chmod(0o700)
    p=box/'.local/lib/graphite/usb-notify.sh';p.write_text('#!/usr/bin/env bash\necho "helper usb-notify" >> "$EVENTS"\n',newline='\n');p.chmod(0o700)
    p=box/'.local/lib/graphite/input-method.sh';p.write_text('#!/usr/bin/env bash\necho "helper input-method" >> "$EVENTS"\n',newline='\n');p.chmod(0o700)
    events=run('session-services.sh',extra={**session,'INVOCATION_ID':'mock'})
    for name in ['waybar','swaybg','hypridle','swaync','usb-notify','input-method']:
        assert 'helper '+name in events
    assert events.count('helper wl-paste')==2 and 'clipboard.sh store' in events
    assert 'systemctl' not in events
    run('session-services.sh',extra=session,expected=1)
    print('PASS helpers: finite launcher exits, starts expected children/two watchers, respects foreign agent; cgroup lifetime not simulated')
    # Exercise recorder cancellation and systemd properties without recording.
    for name,body in {
        'flock':'exit 0',
        'mkdir':'[[ -d ${!#} ]]',
        'slurp':'[[ ${CANCEL:-0} == 0 ]] || exit 1; echo "0,0 100x100"',
        'wf-recorder':'exit 0',
        'notify-send':'exit 0',
        'systemctl':'''printf 'systemctl %s\n' "$*" >> "$EVENTS"
if [[ $* == *'is-active'* && $* == *'graphite-recorder.service'* ]]; then exit 3; fi
exit 0''',
    }.items():
        p=box/'bin'/name;p.write_text('#!/usr/bin/env bash\n'+body+'\n',newline='\n');p.chmod(0o700)
    (box/'Videos/Recordings').mkdir(parents=True)
    shim=box/'test-env.sh'
    shim.write_text('mkdir() { [[ -d ${!#} ]]; }\n',newline='\n')
    env['BASH_ENV']=posix(shim)
    events=run('record.sh',extra={**session,'CANCEL':'1'})
    assert 'run ' not in events and not list((box/'Videos/Recordings').iterdir())
    events=run('record.sh',extra=session)
    assert 'KillSignal=SIGINT' in events and 'TimeoutStopSec=30' in events and 'PartOf=graphite-session.service' in events
    assert 'After=graphite-session.service' in events
    assert 'wf-recorder -y -g' in events  # mktemp reserved the file; no interactive overwrite prompt
    events=run('record.sh',extra={**session,'RUN_EXIT':'9'},expected=1)
    assert len(list((box/'Videos/Recordings').iterdir()))==1
    print('PASS recording: cancellation, SIGINT/timeout/dependency arguments and failed-launch empty-file cleanup (no media captured)')
if not list(checks.iterdir()): checks.rmdir()
