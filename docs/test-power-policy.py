"""Idle policy validation, native shell lifetime and signal regressions in a disposable home."""
from pathlib import Path
import copy, json, os, shutil, signal, subprocess, tempfile, time

root=Path(__file__).resolve().parent.parent
bash=shutil.which('bash')
if os.name=='nt' or not shutil.which('jq'):
    print('SKIP power policy integration: requires Linux, Bash and jq.')
    raise SystemExit(0)
helper=root/'stow/desktop/.local/lib/graphite/power-policy.sh'
defaults=root/'stow/desktop/.config/graphite/power/defaults.json'
with tempfile.TemporaryDirectory(prefix='graphite-policy-',dir='/tmp') as folder:
    box=Path(folder); runtime=box/'runtime'; runtime.mkdir(mode=0o700)
    config=box/'.config/graphite/power'; config.mkdir(parents=True)
    shutil.copyfile(defaults,config/'defaults.json')
    hooks=box/'.config/graphite/hypr'; hooks.mkdir()
    shutil.copyfile(root/'stow/desktop/.config/graphite/hypr/hypridle.conf',hooks/'hypridle.conf')
    binary=box/'bin'; binary.mkdir()
    events=box/'events'; events.touch()
    source=box/'source'; source.write_text('mains')
    stream=box/'stream'; os.mkfifo(stream)
    commands={
        'systemctl': '''printf 'manager %s\\n' "$*" >> "$EVENTS"
if [[ $* == *'is-active --quiet graphite-power.service' ]]; then exit "${INACTIVE:-0}"; fi
if [[ $* == *'is-active --quiet graphite-lock.service' ]]; then exit "${UNLOCKED:-1}"; fi
exit "${MANAGER_FAIL:-0}"
''',
        'systemd-run': '''printf 'service %s\\n' "$*" >> "$EVENTS"
exit "${RUN_FAIL:-0}"
''',
        'busctl': '''printf 'query\\n' >> "$EVENTS"
if [[ $(cat "$SOURCE") == battery ]]; then echo 'b true'; else echo 'b false'; fi
''',
        'upower': 'exec cat "$STREAM"',
        'hyprctl': 'printf "display-wake\\n" >> "$EVENTS"',
        'hypridle': '''printf 'idle-start %s pid=%s\\n' "$*" "$$" >> "$EVENTS"
trap 'echo idle-stop >> "$EVENTS"; exit 0' TERM
while true; do sleep 0.05; done
'''
    }
    for name,body in commands.items():
        p=binary/name; p.write_text('#!/usr/bin/env bash\n'+body+'\n'); p.chmod(0o700)
    env={**os.environ,'HOME':str(box),'XDG_RUNTIME_DIR':str(runtime),'PATH':str(binary)+':/usr/bin:/bin',
         'EVENTS':str(events),'SOURCE':str(source),'STREAM':str(stream),'INVOCATION_ID':'fixture',
         'XDG_CURRENT_DESKTOP':'Graphite:Hyprland','WAYLAND_DISPLAY':'fixture','HYPRLAND_INSTANCE_SIGNATURE':'fixture'}
    def run(args,extra=None,code=0):
        events.write_text('')
        result=subprocess.run([bash,str(helper),*args],env={**env,**(extra or {})},capture_output=True,text=True,timeout=8)
        assert result.returncode==code,(args,result.returncode,result.stdout,result.stderr)
        return result,events.read_text()
    original=json.loads(defaults.read_text())
    result,logged=run(['settings']); assert json.loads(result.stdout)==original and not logged
    result,_=run(['render'])
    assert 'timeout = 300' in result.stdout and 'timeout = 420' in result.stdout
    assert 'systemctl suspend' not in result.stdout and 'inhibit_sleep = 3' in result.stdout
    assert 'power-policy.sh lock' in result.stdout and 'resume.sh' in (hooks/'hypridle.conf').read_text()
    policy=copy.deepcopy(original)
    policy['battery']={'lock':60,'screenOff':120,'suspend':1800}
    _,logged=run(['save',json.dumps(policy)])
    assert json.loads((config/'settings.json').read_text())==policy
    assert '--kill-whom=main --signal=HUP graphite-power.service' in logged
    assert 'restart' not in logged and 'stop' not in logged and 'service ' not in logged
    source.write_text('battery')
    result,_=run(['render']); assert all(f'timeout = {n}' in result.stdout for n in [60,120,1800])
    assert 'on-timeout = systemctl suspend' in result.stdout
    assert 'on-resume = hyprctl dispatch' in result.stdout
    malformed=[{},[],None,'',False,{'mains':{}},json.dumps(policy)+'\n'+json.dumps(policy)]
    bad=copy.deepcopy(policy); bad['battery']['lock']='300; touch forbidden'; malformed.append(bad)
    bad=copy.deepcopy(policy); bad['mains']['suspend']=-1; malformed.append(bad)
    bad=copy.deepcopy(policy); bad['lockBeforeSleep']='false'; malformed.append(bad)
    for bad in malformed:
        argument=bad if isinstance(bad,str) else json.dumps(bad)
        _,logged=run(['save',argument],code=1)
        assert not logged and json.loads((config/'settings.json').read_text())==policy
    assert not (box/'forbidden').exists()
    assert run(['save',json.dumps(original)],{'XDG_CURRENT_DESKTOP':'KDE'},1)[1]==''
    assert json.loads((config/'settings.json').read_text())==policy
    (config/'settings.json').unlink(); (config/'settings.json').symlink_to(config/'defaults.json')
    run(['save',json.dumps(policy)],code=1)
    assert json.loads((config/'defaults.json').read_text())==original
    (config/'settings.json').unlink()
    never=copy.deepcopy(original)
    never['lockBeforeSleep']=False
    never['mains']=never['battery']={'lock':0,'screenOff':0,'suspend':0}
    (config/'settings.json').write_text(json.dumps(never))
    result,_=run(['render'])
    assert 'before_sleep_cmd = \n' in result.stdout and 'inhibit_sleep = 0' in result.stdout
    assert 'on-timeout = true' in result.stdout
    assert 'on-timeout = systemctl suspend' not in result.stdout and 'on-timeout = ~/.local/' not in result.stdout
    (config/'settings.json').unlink()
    _,logged=run(['start'],{'INACTIVE':'1'})
    assert '--unit=graphite-power' in logged and 'PartOf=graphite-session.service' in logged
    assert 'KillMode=control-group' in logged and '--setenv=WAYLAND_DISPLAY=fixture' in logged
    assert run(['start'])[1].count('service ')==0
    run(['start'],{'INACTIVE':'1','RUN_FAIL':'7'},7)
    _,logged=run(['lock'])
    assert '--unit=graphite-lock' in logged and 'PartOf=graphite-session.service' in logged
    assert 'PartOf=graphite-power' not in logged and logged.strip().endswith('/lock.sh')
    assert 'service ' not in run(['lock'],{'UNLOCKED':'0'})[1]
    assert run(['lock'],{'XDG_CURRENT_DESKTOP':'KDE'},1)[1]==''
    assert run(['--help'])[1]==''
    print('PASS idle settings: defaults, validation, atomic saves, source-specific rendering, Never, suspend hooks, foreign desktop/symlink protection and isolated locker service (service commands mocked).')
    # Exercise a real Bash supervisor and HUP handling, including changes during read().
    (config/'settings.json').write_text(json.dumps(policy)); source.write_text('mains'); events.write_text('')
    fifo=os.open(stream,os.O_RDWR|os.O_NONBLOCK)
    log=box/'run.log'
    with log.open('w') as output:
        process=subprocess.Popen([bash,str(helper),'run'],env=env,stdout=output,stderr=subprocess.STDOUT)
        def await_event(predicate):
            deadline=time.monotonic()+6
            while time.monotonic()<deadline:
                assert process.poll() is None,log.read_text()
                if predicate(events.read_text()): return
                time.sleep(0.02)
            raise AssertionError(events.read_text()+log.read_text())
        try:
            await_event(lambda text:text.count('idle-start')==1)
            initial=(runtime/'graphite-hypridle.conf').read_text()
            assert 'timeout = 300' in initial
            queries=events.read_text().count('query')
            os.write(fifo,b'daemon changed\n')
            await_event(lambda text:text.count('query')>queries)
            time.sleep(0.1)
            assert events.read_text().count('idle-start')==1
            source.write_text('battery'); os.write(fifo,b'daemon changed\n')
            await_event(lambda text:text.count('idle-start')==2)
            assert 'timeout = 1800' in (runtime/'graphite-hypridle.conf').read_text()
            policy['battery']['lock']=120
            (config/'settings.json').write_text(json.dumps(policy))
            process.send_signal(signal.SIGHUP)
            await_event(lambda text:text.count('idle-start')==3)
            assert 'timeout = 60\n' not in (runtime/'graphite-hypridle.conf').read_text()
            assert 'timeout = 120\n' in (runtime/'graphite-hypridle.conf').read_text()
            assert 'timeout = 1800\n' in (runtime/'graphite-hypridle.conf').read_text()
            assert 'inhibit_sleep = 3' in (runtime/'graphite-hypridle.conf').read_text()
            # Repeated identical updates must keep the existing timers alive.
            queries=events.read_text().count('query'); process.send_signal(signal.SIGHUP)
            await_event(lambda text:text.count('query')>queries)
            time.sleep(0.1)
            assert events.read_text().count('idle-start')==3
            # A bad file must preserve the running idle process and generated config.
            previous=(runtime/'graphite-hypridle.conf').read_text()
            (config/'settings.json').write_text('{}')
            process.send_signal(signal.SIGHUP)
            await_event(lambda text:'Power policy reload failed' in log.read_text())
            assert process.poll() is None and events.read_text().count('idle-start')==3
            assert (runtime/'graphite-hypridle.conf').read_text()==previous
            # Losing the idle daemon must fail the supervised unit, allowing systemd's restart.
            idle_line=[line for line in events.read_text().splitlines() if line.startswith('idle-start')][-1]
            os.kill(int(idle_line.rsplit('pid=',1)[1]),signal.SIGTERM)
            assert process.wait(timeout=5)==1,log.read_text()
            assert 'Hypridle exited; restarting power policy.' in log.read_text()
        finally:
            process.terminate(); process.wait(timeout=5); os.close(fifo)
        assert events.read_text().count('idle-stop')==3,events.read_text()+log.read_text()
        assert events.read_text().count('display-wake')==2
        assert not (runtime/'graphite-hypridle.conf').exists()
    print('PASS real idle supervisor: charger events, unchanged-policy deduplication, HUP reload during blocked reads, invalid-file preservation, idle-daemon failure and child cleanup (idle daemon/UPower mocked; no display or suspend actions).')
