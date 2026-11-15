"""Night Light IPC and service lifetime fixtures; never changes display colors."""
from pathlib import Path
import json, os, shlex, shutil, subprocess, tempfile

root=Path(__file__).resolve().parent.parent
bash=r'C:\Program Files\Git\bin\bash.exe' if os.name=='nt' else shutil.which('bash')
native_hyprsunset=shutil.which('hyprsunset')
def posix(path):
    return subprocess.check_output([bash,'-c','cygpath -u "$1"','test',str(path)],text=True).strip() if os.name=='nt' else str(path)
checks=root/'.checks';checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks,prefix='night-light-') as folder:
    box=Path(folder)
    commands={
        'hyprsunset':'exit 99',
        'systemctl':'''case $* in
    '--user is-active --quiet graphite-night-light.service') [[ -f $READY ]] ;;
    '--user is-active --quiet graphite-session.service') [[ ${GRAPHITE_ACTIVE:-1} == 1 ]] ;;
    *) exit 9 ;;
esac''',
        'systemd-run':'''printf 'start %s\\n' "$*" >> "$EVENTS"
[[ ${RUN_FAIL:-0} == 0 ]] || exit 7
touch "$READY"''',
        'pgrep':'[[ ${FOREIGN:-0} == 1 ]]',
        'timeout':'shift; exec "$@"',
        'hyprctl':'''printf 'ipc %s\\n' "$*" >> "$EVENTS"
[[ ${IPC_FAIL:-0} == 0 ]] || exit 6
case $* in
    'hyprsunset identity get') cat "$IDENTITY" ;;
    'hyprsunset temperature') cat "$TEMPERATURE" ;;
    'hyprsunset identity false') echo false > "$IDENTITY" ;;
    'hyprsunset identity') echo true > "$IDENTITY" ;;
    'hyprsunset temperature '*) echo "$3" > "$TEMPERATURE"; echo false > "$IDENTITY" ;;
    *) exit 9 ;;
esac'''
    }
    for name,body in commands.items():
        p=box/name;p.write_text('#!/usr/bin/env bash\n'+body+'\n',newline='\n');p.chmod(0o700)
    ready=box/'ready';identity=box/'identity';temperature=box/'temperature'
    identity.write_text('true\n');temperature.write_text('4500\n')
    env={**os.environ,'PATH':posix(box)+':/usr/bin:/bin','HOME':posix(box),'READY':posix(ready),
         'IDENTITY':posix(identity),'TEMPERATURE':posix(temperature),'EVENTS':posix(box/'events'),
         'XDG_CURRENT_DESKTOP':'Graphite:Hyprland','WAYLAND_DISPLAY':'wayland-fixture','HYPRLAND_INSTANCE_SIGNATURE':'fixture-signature'}
    def run(args,extra=None,code=0):
        (box/'events').write_text('')
        result=subprocess.run([bash,str(root/'stow/desktop/.local/lib/graphite/night-light.sh'),*args],env={**env,**(extra or {})},capture_output=True,text=True,timeout=10)
        assert result.returncode==code,(result.returncode,result.stdout,result.stderr)
        return result,(box/'events').read_text()
    result,events=run(['status'])
    assert json.loads(result.stdout)==dict(installed=True,available=False,enabled=False,temperature=4500) and not events
    assert run(['off'])[1]=='' and not ready.exists()
    _,events=run(['start'])
    assert 'PartOf=graphite-session.service' in events and 'After=graphite-session.service' in events
    assert '--unit=graphite-night-light' in events and '--setenv=WAYLAND_DISPLAY=wayland-fixture' in events
    assert '--setenv=HYPRLAND_INSTANCE_SIGNATURE=fixture-signature' in events
    assert '--setenv=XDG_CONFIG_HOME='+posix(box)+'/.config/graphite' in events
    assert 'hyprsunset --identity --temperature 4500' in events and '--config' not in events
    if native_hyprsunset:
        # Exercise the installed argument parser with the actual generated flags.
        # --help exits before config loading or connecting to any display.
        launch=shlex.split(events.splitlines()[0])
        arguments=launch[launch.index('hyprsunset')+1:]
        parsed=subprocess.run([native_hyprsunset,*arguments,'--help'],capture_output=True,text=True,timeout=5)
        assert parsed.returncode==0,(parsed.stdout,parsed.stderr)
        print('PASS installed Hyprsunset accepts generated launch flags (--help; no display connection).')
    else:
        print('SKIP installed Hyprsunset argument check: binary unavailable.')
    assert run(['start'])[1]==''
    run(['on']);assert identity.read_text().strip()=='false'
    assert json.loads(run(['status'])[0].stdout)['enabled'] is True
    run(['temperature','3700']);assert temperature.read_text().strip()=='3700'
    run(['off']);assert identity.read_text().strip()=='true' and temperature.read_text().strip()=='3700'
    for value in ['2499','6501','nan','4500;touch forbidden','-1']:
        assert run(['temperature',value],code=1)[1]==''
    result,_=run(['status'],{'IPC_FAIL':'1'})
    assert json.loads(result.stdout)['available'] is False
    run(['on'],{'IPC_FAIL':'1'},6)
    for extra in [{'XDG_CURRENT_DESKTOP':'KDE'},{'WAYLAND_DISPLAY':''},{'HYPRLAND_INSTANCE_SIGNATURE':''}]:
        assert run(['on'],extra,1)[1]==''
    ready.unlink()
    assert run(['start'],{'FOREIGN':'1'},1)[1]==''
    assert run(['start'],{'GRAPHITE_ACTIVE':'0'},1)[1]==''
    run(['start'],{'RUN_FAIL':'1'},7)
    assert run(['--help'])[1]==''
    missing=box/'missing.sh'
    missing.write_text('command() { if [[ $1 == -v && ${2:-} == hyprsunset ]]; then return 1; fi; builtin command "$@"; }\n')
    result,_=run(['status'],{'BASH_ENV':posix(missing)})
    assert json.loads(result.stdout)['installed'] is False
    assert run(['start'],{'BASH_ENV':posix(missing)})[1]==''
    run(['on'],{'BASH_ENV':posix(missing)},1)
print('PASS Night Light: off-by-default launch, PartOf lifetime, explicit compositor environment, IPC state/warmth, bounds, foreign desktop/instance preservation, absent package and command failures. No compositor or daemon executed.')
