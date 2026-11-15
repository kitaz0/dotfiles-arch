"""Fcitx startup/isolation guards and status output; commands are mocked."""
from pathlib import Path
import json, os, selectors, shutil, subprocess, tempfile
root = Path(__file__).resolve().parent.parent
bash = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else shutil.which('bash')
def posix(path):
    return subprocess.check_output([bash,'-c','cygpath -u "$1"','test',str(path)],text=True).strip() if os.name == 'nt' else str(path)
checks=root/'.checks'; checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks,prefix='ime-') as folder:
    box=Path(folder)
    stubs={
        'pgrep':'[[ ${RUNNING:-0} == 1 ]]',
        'busctl':'''if [[ ${!#} == monitor ]]; then
    printf 'monitor %s %s\\n' "$$" "$*" >> "$EVENTS"
    while IFS= read -r message; do printf '%s\\n' "$message"; done < "$MONITOR_EVENTS"
    exit 0
fi
[[ $* == "--user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.fcitx.Fcitx5" ]] || exit 2
echo "b ${OWNER:-false}"''',
        'fcitx5':'printf "start %s\\n" "$FCITX_CONFIG_HOME" >> "$EVENTS"',
        'fcitx5-config-qt':'printf "config %s %s\\n" "$FCITX_CONFIG_HOME" "$*" >> "$EVENTS"',
        'fcitx5-remote':'''[[ ${REMOTE_FAIL:-0} == 0 ]] || exit 1
case ${1:-} in
    -t) printf 'toggle\\n' >> "$EVENTS" ;;
    -n) echo "${ENGINE-mozc}" ;;
    *) echo "${STATE:-2}" ;;
esac''',
        'timeout':'shift; exec "$@"'
    }
    for name,body in stubs.items():
        p=box/name;p.write_text('#!/usr/bin/env bash\n'+body+'\n',newline='\n');p.chmod(0o700)
    env={**os.environ,'PATH':posix(box)+':/usr/bin:/bin','HOME':posix(box),'EVENTS':posix(box/'events'),'XDG_CURRENT_DESKTOP':'Graphite:Hyprland','QT_IM_MODULE':'fcitx','GTK_IM_MODULE':''}
    def run(mode='start',extra=None,code=0):
        (box/'events').write_text('')
        result=subprocess.run([bash,str(root/'stow/desktop/.local/lib/graphite/input-method.sh'),mode],env={**env,**(extra or {})},text=True,capture_output=True,timeout=10)
        assert result.returncode==code,result.stderr
        return (box/'events').read_text(),result.stdout
    assert '/.config/graphite/fcitx5' in run()[0]
    assert '/.config/graphite/fcitx5' in run('configure')[0]
    assert '-style Fusion -stylesheet ' in run('configure')[0]
    assert '/.config/graphite/qt/widgets.qss' in run('configure')[0]
    for extra in [{'RUNNING':'1'},{'OWNER':'true'},{'OWNER':'unexpected'},{'XDG_CURRENT_DESKTOP':'KDE'},{'GTK_IM_MODULE':'ibus'},{'QT_IM_MODULE':'ibus'}]:
        assert run(extra=extra)[0]=='',extra
    assert json.loads(run('status',{'RUNNING':'1'})[1])['text']=='あ'
    # An inactive Mozc engine must not leave a stale Japanese label behind.
    for extra in [{'RUNNING':'1','STATE':'0'}, {'RUNNING':'1','STATE':'1','ENGINE':'mozc'}, {'RUNNING':'1','ENGINE':'keyboard-us'}]:
        assert json.loads(run('status',extra)[1])['text']=='EN'
    for extra in [{'RUNNING':'1','REMOTE_FAIL':'1'}, {'RUNNING':'1','ENGINE':''}, {'RUNNING':'1','STATE':'unexpected'}]:
        state=json.loads(run('status',extra)[1])
        assert state['text']=='?' and state['class']=='unavailable'
    assert json.loads(run('status',{'RUNNING':'1','ENGINE':'pinyin'})[1])['text']=='IM'
    assert json.loads(run('status')[1])['text']=='EN'
    assert run('toggle',{'RUNNING':'1'})[0]=='toggle\n'
    assert run('toggle',code=1)[0]==''
    run('toggle',{'RUNNING':'1','REMOTE_FAIL':'1'},code=1)
    if os.name != 'nt':
        # Exercise the real streaming loop with a controllable bus, not a timer.
        state_file=box/'state.sh'
        state_file.write_text('export RUNNING=1 STATE=1 ENGINE=mozc\n')
        fifo=box/'notifications';os.mkfifo(fifo)
        (box/'events').write_text('')
        watch=subprocess.Popen([bash,str(root/'stow/desktop/.local/lib/graphite/input-method.sh'),'watch'],
            env={**env,'BASH_ENV':str(state_file),'MONITOR_EVENTS':str(fifo)},
            stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        selector=selectors.DefaultSelector();selector.register(watch.stdout,selectors.EVENT_READ)
        def expect(text):
            assert selector.select(timeout=1),'Indicator did not react within one second'
            line=watch.stdout.readline()
            assert line,watch.stderr.read()
            assert json.loads(line)['text']==text,line
        try:
            expect('EN')
            with fifo.open('w') as notifications:
                # Repeated notifications must not emit duplicate state lines.
                for state,text in [(2,'あ'),(1,'EN'),(2,'あ')]:
                    state_file.write_text(f'export RUNNING=1 STATE={state} ENGINE=mozc\n')
                    notifications.write('{}\n{}\n');notifications.flush()
                    expect(text)
                state_file.write_text('export RUNNING=0 STATE=1\n')
                notifications.write('{}\n');notifications.flush();expect('EN')
                state_file.write_text('export RUNNING=1 STATE=2 ENGINE=mozc\n')
                notifications.write('{}\n');notifications.flush();expect('あ')
                assert not selector.select(timeout=0.1),'Duplicate state emitted'
            # A disconnected monitor ends the stream so Waybar can restart it.
            assert watch.wait(timeout=2)==1
            assert watch.stdout.read()==''
            args=(box/'events').read_text()
            assert 'member=\'NewIcon\'' in args and "arg0='org.fcitx.Fcitx5'" in args
        finally:
            if watch.poll() is None:
                watch.terminate();watch.wait(timeout=2)
            selector.close();watch.stdout.close();watch.stderr.close()
    (box/'fcitx5').rename(box/'fcitx5.saved')
    missing=box/'missing.sh'
    missing.write_text('command() { if [[ $1 == -v && ${2:-} == fcitx5 ]]; then return 1; fi; builtin command "$@"; }\n')
    assert run(extra={'BASH_ENV':posix(missing)})[0]==''
print('PASS input-method fixtures: isolation guards, queried modes, guarded toggling and event-driven EN/あ changes, duplicate suppression, daemon exit/restart and monitor disconnect (stream fixtures on Unix). No Fcitx engine or toolkit executed.')
if not list(checks.iterdir()): checks.rmdir()
