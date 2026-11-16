"""Capture geometry, file handling and shared recording lifecycle in a disposable home."""
from pathlib import Path
import json, os, shutil, subprocess, sys, tempfile, time

root=Path(__file__).resolve().parent.parent
if os.name!='posix' or not shutil.which('jq'):
    print('SKIP capture fixtures: require Unix Bash, flock and jq.');sys.exit()
helpers=root/'stow/desktop/.local/lib/graphite'
with tempfile.TemporaryDirectory(prefix='graphite-capture-') as folder:
    box=Path(folder);bin_=box/'bin';bin_.mkdir()
    stub='''#!/usr/bin/env python3
from pathlib import Path
import json,os,sys,time
box=Path(os.environ['FIXTURE']);name=Path(sys.argv[0]).name;args=sys.argv[1:]
with (box/'events').open('a') as f:f.write(json.dumps([name,*args])+'\\n')
if name=='hyprctl':
    print((box/('monitors.json' if 'monitors' in args else 'window.json')).read_text())
elif name=='slurp':
    if os.environ.get('CANCEL')=='1':sys.exit(1)
    if os.environ.get('SELECT_WAIT')=='1':
        (box/'selecting').touch()
        while not (box/'release').exists():time.sleep(.02)
    print(os.environ.get('GEOMETRY','10,20 120x80'))
elif name=='systemctl':
    if 'show' in args:
        if '--property=Description' in args:print((box/'description').read_text() if (box/'description').exists() else '')
        else:print((box/'state').read_text())
    elif 'stop' in args:(box/'state').write_text('inactive')
    elif 'is-active' in args:sys.exit(0 if os.environ.get('SESSION_ACTIVE','1')=='1' else 3)
elif name=='systemd-run':
    try:os.fstat(9);raise AssertionError('recording guard leaked into launcher')
    except OSError:pass
    if os.environ.get('RUN_EXIT'):sys.exit(int(os.environ['RUN_EXIT']))
    (box/'state').write_text('active')
    (box/'description').write_text(next(arg.split('=',1)[1] for arg in args if arg.startswith('--description=')))
elif name=='grim':
    if os.environ.get('GRIM_FAIL')=='1':sys.exit(1)
    Path(args[-1]).write_bytes(b'fixture PNG')
elif name=='wl-copy':(box/'clipboard').write_bytes(sys.stdin.buffer.read())
'''
    for name in ['hyprctl','slurp','systemctl','systemd-run','wf-recorder','notify-send','grim','wl-copy']:
        p=bin_/name;p.write_text(stub);p.chmod(0o700)
    monitors=[{'id':1,'name':'TEST-1','focused':True,'x':-1000,'y':0,'width':1000,'height':800,'scale':1,'transform':0}]
    window={'address':'0x123','mapped':True,'hidden':False,'monitor':1,'at':[-950,70],'size':[200,100]}
    (box/'monitors.json').write_text(json.dumps(monitors));(box/'window.json').write_text(json.dumps(window));(box/'state').write_text('inactive')
    env={**os.environ,'PATH':str(bin_)+':'+os.environ['PATH'],'HOME':folder,'XDG_RUNTIME_DIR':folder,'WAYLAND_DISPLAY':'fixture','FIXTURE':folder}
    def run(script,*args,code=0,**extra):
        p=subprocess.run(['bash',str(helpers/script),*args],env={**env,**extra},capture_output=True,text=True,timeout=6)
        assert p.returncode==code,(script,args,p.returncode,p.stdout,p.stderr)
        return p
    def events():return [json.loads(line) for line in (box/'events').read_text().splitlines()]
    def reset():
        (box/'events').write_text('');(box/'state').write_text('inactive')
    reset()
    assert json.loads(run('capture-target.sh','window').stdout)=={'output':'TEST-1','geometry':'-950,70 200x100'}
    assert json.loads(run('capture-target.sh','full').stdout)=={'output':'TEST-1'}
    window['at']=[-50,70];(box/'window.json').write_text(json.dumps(window))
    assert json.loads(run('capture-target.sh','window').stdout)['geometry']=='-50,70 50x100'
    window['at']=[50,70];(box/'window.json').write_text(json.dumps(window));run('capture-target.sh','window',code=4)
    monitors[0].update(x=0,width=1920,height=1080,scale=1.5,transform=1)
    window.update(at=[100,1200],size=[100,200]);(box/'monitors.json').write_text(json.dumps(monitors));(box/'window.json').write_text(json.dumps(window))
    assert json.loads(run('capture-target.sh','window').stdout)['geometry']=='100,1200 100x80'
    window.update(at=[100.4,60.2],size=[100.3,80.4]);(box/'window.json').write_text(json.dumps(window))
    assert json.loads(run('capture-target.sh','window').stdout)['geometry']=='100,60 101x81'
    for mode in ['full','region','window']:
        reset();run('screenshot.sh',mode)
        capture=next(e for e in events() if e[0]=='grim')
        assert ('-g' in capture)==(mode!='full')
        assert (box/'clipboard').read_bytes()==b'fixture PNG'
        label={'full':'Full-screen','region':'Region','window':'Window'}[mode]
        assert ['notify-send',label+' screenshot saved and copied',capture[-1]] in events()
    before=set((box/'Pictures/Screenshots').iterdir());run('screenshot.sh','region',CANCEL='1');assert set((box/'Pictures/Screenshots').iterdir())==before
    run('screenshot.sh','window',GRIM_FAIL='1',code=1);assert set((box/'Pictures/Screenshots').iterdir())==before
    for mode in ['region','full','window']:
        reset();run('record.sh','start',mode)
        start=next(e for e in events() if e[0]=='systemd-run')
        assert '--unit=graphite-recorder' in start and '--property=KillSignal=SIGINT' in start
        assert '--property=TimeoutStopSec=30' in start and '--property=PartOf=graphite-session.service' in start
        assert ('-g' in start)==(mode!='full') and ('-o' in start)==(mode!='region')
        if '-o' in start:assert start[start.index('-o')+1]=='TEST-1'
        label={'full':'Full-screen','region':'Region','window':'Window'}[mode]+' recording'
        assert '--description='+label in start
        assert any(e[:2]==['notify-send',label+' started'] for e in events())
        launches=len([e for e in events() if e[0]=='systemd-run'])
        run('record.sh','start','full',code=1)
        run('record.sh','toggle','window')
        assert len([e for e in events() if e[0]=='systemd-run'])==launches
        assert any(e[0]=='systemctl' and 'stop' in e for e in events())
        assert any(e[:2]==['notify-send',label+' stopped'] for e in events()), (mode,events())
    for state in ['activating','reloading','deactivating']:
        reset();(box/'state').write_text(state)
        run('record.sh','start','window',code=1)
        assert not any(e[0]=='systemd-run' for e in events())
    reset();(box/'state').write_text('deactivating');run('record.sh','toggle','full',code=1)
    assert not any(e[0]=='systemd-run' for e in events())
    reset();run('record.sh','start','region',CANCEL='1');assert not any(e[0]=='systemd-run' for e in events())
    run('record.sh','start','region',GEOMETRY='invalid',code=1);assert not any(e[0]=='systemd-run' for e in events())
    before=set((box/'Videos/Recordings').iterdir());run('record.sh','start','full',RUN_EXIT='9',code=1);assert set((box/'Videos/Recordings').iterdir())==before
    reset();run('record.sh','start','window',SESSION_ACTIVE='0',code=1);assert not any(e[0]=='systemd-run' for e in events())
    # A second mode cannot enter while the region selector holds the real flock.
    reset();first=subprocess.Popen(['bash',str(helpers/'record.sh'),'start','region'],env={**env,'SELECT_WAIT':'1'},stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    try:
        deadline=time.monotonic()+3
        while not (box/'selecting').exists() and time.monotonic()<deadline:time.sleep(.02)
        assert (box/'selecting').exists()
        run('record.sh','start','full')
        assert not any(e[0]=='systemd-run' for e in events())
        (box/'release').touch();out,err=first.communicate(timeout=4);assert first.returncode==0,out+err
        assert len([e for e in events() if e[0]=='systemd-run'])==1
    finally:
        if first.poll() is None:first.kill();first.wait()
    for script in ['record.sh','screenshot.sh','capture-target.sh']:
        run(script,'--help')
    run('record.sh','start','other',code=2)
print('PASS capture: native jq geometry with clipping/rotation/scaling, screenshot modes/cancellation, shared recorder states, exclusive selection, guard cleanup and failed-launch file cleanup.')
