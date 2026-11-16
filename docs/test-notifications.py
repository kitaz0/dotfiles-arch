"""Unread bell state and subscription lifetime, without reading real notification content."""
from pathlib import Path
import json, os, shutil, subprocess, sys, tempfile

root=Path(__file__).resolve().parent.parent
if os.name!='posix' or not shutil.which('jq'):
    print('SKIP notification stream fixtures: require Unix Bash and jq.');sys.exit()
script=root/'stow/desktop/.local/lib/graphite/notification-status.sh'
with tempfile.TemporaryDirectory(prefix='graphite-notifications-') as folder:
    box=Path(folder);stub=box/'swaync-client'
    stub.write_text('''#!/usr/bin/env python3
import os,time
from pathlib import Path
box=Path(os.environ['FIXTURE']);(box/'child').write_text(str(os.getpid()))
print((box/'input').read_text(),end='',flush=True)
if os.environ.get('HOLD')=='1':
    while True:time.sleep(1)
''');stub.chmod(0o700)
    env={**os.environ,'PATH':folder+':'+os.environ['PATH'],'XDG_RUNTIME_DIR':folder,'FIXTURE':folder}
    def event(count,visible=False,dnd=False,inhibited=False):return dict(count=count,visible=visible,dnd=dnd,inhibited=inhibited)
    def run(items):
        (box/'input').write_text('\n'.join(json.dumps(x) for x in items)+'\n')
        p=subprocess.run(['bash',str(script)],env=env,capture_output=True,text=True,timeout=5)
        assert p.returncode==1,p.stderr
        return [json.loads(line) for line in p.stdout.splitlines()]
    rows=run([event(0),event(1),event(1,True),event(1),event(1,dnd=True),event(2,dnd=True),event(2,dnd=True,inhibited=True),event(0,dnd=True,inhibited=True)])
    assert [r['alt'] for r in rows]==['none','notification','none','none','dnd-none','dnd-notification','dnd-inhibited-notification','dnd-inhibited-none']
    assert 'unread' in rows[1]['class'] and 'unread' not in rows[2]['class']
    run([event(3,True),event(3)])
    assert run([event(3),event(3),event(4)])[0]['alt']=='none'
    assert run([event(4),event(5)])[-1]['alt']=='notification'
    assert run([{},event(-1),event(0)])[-1]['alt']=='none'
    (box/'input').write_text(json.dumps(event(0))+'\n')
    watch=subprocess.Popen(['bash',str(script)],env={**env,'HOLD':'1'},stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    try:
        import selectors
        selector=selectors.DefaultSelector();selector.register(watch.stdout,selectors.EVENT_READ)
        assert selector.select(timeout=3);assert json.loads(watch.stdout.readline())['alt']=='none'
        child=int((box/'child').read_text());watch.terminate();watch.wait(timeout=3)
        try:os.kill(child,0)
        except ProcessLookupError:pass
        else:raise AssertionError('SwayNC subscriber survived bar/helper shutdown')
        selector.close()
    finally:
        if watch.poll() is None:watch.kill();watch.wait()
        watch.stdout.close();watch.stderr.close()
config=json.loads((root/'stow/desktop/.config/graphite/waybar/config.jsonc').read_text())['custom/notifications']
assert config['format-icons']['notification']==chr(0xf009e)
assert config['format-icons']['none']==chr(0xf009a)
assert all(v==chr(0xf009b) for k,v in config['format-icons'].items() if k.startswith('dnd-'))
print('PASS unread bell: arrivals, panel acknowledgement, duplicate events, bar restart, clear, DND/inhibition icons and subscriber cleanup.')
