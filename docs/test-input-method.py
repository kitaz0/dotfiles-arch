"""Fcitx startup/isolation guards and status output; commands are mocked."""
from pathlib import Path
import json, os, shutil, subprocess, tempfile
root = Path(__file__).resolve().parent.parent
bash = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else shutil.which('bash')
def posix(path):
    return subprocess.check_output([bash,'-c','cygpath -u "$1"','test',str(path)],text=True).strip() if os.name == 'nt' else str(path)
checks=root/'.checks'; checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks,prefix='ime-') as folder:
    box=Path(folder)
    stubs={
        'pgrep':'[[ ${RUNNING:-0} == 1 ]]',
        'busctl':'[[ $* == "--user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.fcitx.Fcitx5" ]] || exit 2; echo "b ${OWNER:-false}"',
        'fcitx5':'printf "start %s\\n" "$FCITX_CONFIG_HOME" >> "$EVENTS"',
        'fcitx5-configtool':'printf "config %s\\n" "$FCITX_CONFIG_HOME" >> "$EVENTS"',
        'fcitx5-remote':'[[ ${REMOTE_FAIL:-0} == 0 ]] || exit 1; if [[ ${1:-} == -n ]]; then echo "${ENGINE:-mozc}"; else echo "${STATE:-2}"; fi',
        'timeout':'shift; exec "$@"'
    }
    for name,body in stubs.items():
        p=box/name;p.write_text('#!/usr/bin/env bash\n'+body+'\n',newline='\n');p.chmod(0o700)
    env={**os.environ,'PATH':posix(box)+':/usr/bin:/bin','HOME':posix(box),'EVENTS':posix(box/'events'),'XDG_CURRENT_DESKTOP':'Graphite:Hyprland','QT_IM_MODULE':'fcitx','GTK_IM_MODULE':''}
    def run(mode='start',extra=None):
        (box/'events').write_text('')
        result=subprocess.run([bash,str(root/'stow/desktop/.local/lib/graphite/input-method.sh'),mode],env={**env,**(extra or {})},text=True,capture_output=True,timeout=10)
        assert result.returncode==0,result.stderr
        return (box/'events').read_text(),result.stdout
    assert '/.config/graphite/fcitx5' in run()[0]
    assert '/.config/graphite/fcitx5' in run('configure')[0]
    for extra in [{'RUNNING':'1'},{'OWNER':'true'},{'OWNER':'unexpected'},{'XDG_CURRENT_DESKTOP':'KDE'},{'GTK_IM_MODULE':'ibus'},{'QT_IM_MODULE':'ibus'}]:
        assert run(extra=extra)[0]=='',extra
    assert json.loads(run('status',{'RUNNING':'1'})[1])['text']=='JA'
    for extra in [{'RUNNING':'1','STATE':'1'},{'RUNNING':'1','ENGINE':'keyboard-us'},{'RUNNING':'1','REMOTE_FAIL':'1'}]:
        assert json.loads(run('status',extra)[1])['text']=='A'
    assert json.loads(run('status')[1])['text']==''
    (box/'fcitx5').rename(box/'fcitx5.saved')
    missing=box/'missing.sh'
    missing.write_text('command() { if [[ $1 == -v && ${2:-} == fcitx5 ]]; then return 1; fi; builtin command "$@"; }\n')
    assert run(extra={'BASH_ENV':posix(missing)})[0]==''
print('PASS input-method fixtures: private profile, existing daemon/bus owner/framework preservation, KDE exclusion, missing dependency and queried JA/direct status. No Fcitx engine or toolkit executed.')
if not list(checks.iterdir()): checks.rmdir()
