"""Public Fastfetch output and portable btop configuration; no live app settings changed."""
from pathlib import Path
import json, os, re, shutil, socket, subprocess, tempfile

root=Path(__file__).resolve().parent.parent
config=root/'stow/fastfetch/.config/fastfetch/config.jsonc'
fetch=json.loads(config.read_text())
# Only explicitly selected, non-identifying fields may enter the default text summary.
allowed={'custom','os','kernel','wm','terminal','cpu','gpu','memory'}
assert all(module['type'] in allowed for module in fetch['modules'])
for module in fetch['modules']:
    fields=set(re.findall(r'\{([a-z-]+)\}',module.get('format','')))
    assert not fields.intersection({'host-name','user-name','serial','ipv4','ipv6','exe-path','tty'})
logo=root/'stow/fastfetch/.config/fastfetch/arch.txt'
assert all(len(line)<=32 for line in logo.read_text().splitlines())
native=shutil.which('fastfetch')
if native:
    with tempfile.TemporaryDirectory(prefix='graphite-fetch-') as folder:
        env={**os.environ,'HOME':folder,'XDG_CONFIG_HOME':folder,'XDG_CACHE_HOME':folder,'USER':'PRIVATE_FETCH_USER','LOGNAME':'PRIVATE_FETCH_USER'}
        result=subprocess.run([native,'--config',str(config),'--logo',str(logo),'--pipe','true','--show-errors','true'],env=env,capture_output=True,text=True,timeout=15)
        assert result.returncode==0,result.stderr
        assert 'GRAPHITE' in result.stdout and 'OS' in result.stdout
        for value in ['PRIVATE_FETCH_USER',folder,str(Path.home()),socket.gethostname()]:
            if value: assert value not in result.stdout,(value,result.stdout)
        assert not re.search(r'\b(?:\d{1,3}\.){3}\d{1,3}\b',result.stdout)
        assert not result.stderr,result.stderr
    print('PASS native Fastfetch: installed parser, original text logo and default text output without username, hostname, home path or IP addresses.')
else:
    print('SKIP native Fastfetch output: executable unavailable; module/field privacy allowlist checked.')

btop=root/'stow/btop/.config/btop/btop.conf'
settings=dict(re.findall(r'^(\w+)\s*=\s*(.+)$',btop.read_text(),re.M))
assert settings['save_config_on_exit']=='false'
assert not any(key.startswith('custom_gpu_name') for key in settings)
assert settings['color_theme']=='"graphite"'
assert set(settings['shown_boxes'].strip('"').split())=={'cpu','mem','net','proc'}
for preset in settings['presets'].strip('"').split():
    panels=[part.split(':')[0] for part in preset.split(',')]
    if any(panel.startswith('gpu') for panel in panels):
        assert len(panels)==1,'GPU detail views must not force a tall combined dashboard'
if shutil.which('btop'):
    defaults=subprocess.check_output(['btop','--default-config'],text=True,timeout=5)
    keys=set(re.findall(r'^(\w+)\s*=',defaults,re.M))
    assert set(settings)<=keys,set(settings)-keys
    print('PASS native btop config keys: all settings supported by installed btop; detected GPU names retained and exit-time rewriting disabled.')
theme=(btop.parent/'themes/graphite.theme').read_text()
assert re.findall(r'^theme\[(\w+)\]="(#[0-9a-f]{6})"$',theme,re.M)
assert not any(value in btop.read_text() for value in ['GeForce','Radeon','Intel HD','card0'])

if os.name=='posix' and shutil.which('btop'):
    import fcntl, pty, select, signal, struct, termios, time
    with tempfile.TemporaryDirectory(prefix='graphite-btop-') as folder:
        home=Path(folder); destination=home/'.config/btop';destination.mkdir(parents=True)
        shutil.copyfile(btop,destination/'btop.conf')
        shutil.copytree(btop.parent/'themes',destination/'themes')
        before=(destination/'btop.conf').read_bytes()
        pid,fd=pty.fork()
        if pid==0:
            os.environ.update(HOME=folder,XDG_CONFIG_HOME=str(home/'.config'),XDG_STATE_HOME=str(home/'state'),TERM='xterm-256color',COLORTERM='truecolor',LANG='C.UTF-8')
            os.execvp('btop',['btop','--config',str(destination/'btop.conf')])
        fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',30,100,0,0))
        output=b'';reaped=False
        try:
            deadline=time.monotonic()+1.2
            while time.monotonic()<deadline:
                if select.select([fd],[],[],0.05)[0]:
                    try:output+=os.read(fd,65536)
                    except OSError:break
            os.write(fd,b'q')
            deadline=time.monotonic()+4
            while time.monotonic()<deadline:
                ended,status=os.waitpid(pid,os.WNOHANG)
                if ended:reaped=True;break
                if select.select([fd],[],[],0.05)[0]:
                    try:output+=os.read(fd,65536)
                    except OSError:pass
            assert reaped,'btop did not exit normally'
            assert os.waitstatus_to_exitcode(status)==0,output.decode(errors='replace')
            assert b'Terminal size too small' not in output
            assert len(output)>1000,'btop did not draw its dashboard'
            assert (destination/'btop.conf').read_bytes()==before
        finally:
            if not reaped:
                os.kill(pid,signal.SIGTERM);os.waitpid(pid,0)
            os.close(fd)
    print('PASS native btop in a 100-column, 30-row terminal: compact startup, normal exit and unchanged config; GPU telemetry is not simulated.')
