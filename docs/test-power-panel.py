"""Power profile command boundaries; no real power service or settings changed."""
from pathlib import Path
import json, os, shutil, subprocess, tempfile

root=Path(__file__).resolve().parent.parent
bash=r'C:\Program Files\Git\bin\bash.exe' if os.name=='nt' else shutil.which('bash')
jq=shutil.which('jq')
if not jq:
    print('SKIP power profile command fixtures: jq unavailable.')
    raise SystemExit(0)
def posix(path):
    return subprocess.check_output([bash,'-c','cygpath -u "$1"','test',str(path)],text=True).strip() if os.name=='nt' else str(path)
checks=root/'.checks';checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks,prefix='power-') as folder:
    box=Path(folder)
    commands={
        'busctl':'''printf 'bus %s\\n' "$*" >> "$EVENTS"
[[ $* == *' NameHasOwner s '* ]] || exit 9
if [[ ${OWNER:-none} == new && ${!#} == org.freedesktop.UPower.PowerProfiles ]] ||
   [[ ${OWNER:-none} == legacy && ${!#} == net.hadess.PowerProfiles ]]; then echo 'b true'; else echo 'b false'; fi''',
        'powerprofilesctl':'''printf 'profile %s\\n' "$*" >> "$EVENTS"
[[ ${PROFILE_FAIL:-0} == 0 ]] || { echo 'Profile denied' >&2; exit 7; }
case $1 in
    get) echo balanced ;;
    list) printf '  performance:\\n    Driver: fixture\\n* balanced:\\n  power-saver:\\n  unsafe;touch forbidden:\\n' ;;
    set) [[ $2 == power-saver || $2 == balanced || $2 == performance ]] || exit 9 ;;
    *) exit 9 ;;
esac''',
        'timeout':'shift; exec "$@"',
        'jq':'exec "'+posix(jq)+'" "$@"'
    }
    for name,body in commands.items():
        p=box/name;p.write_text('#!/usr/bin/env bash\n'+body+'\n',newline='\n');p.chmod(0o700)
    env={**os.environ,'PATH':posix(box)+':/usr/bin:/bin','EVENTS':posix(box/'events')}
    def run(args,extra=None,code=0):
        (box/'events').write_text('')
        result=subprocess.run([bash,str(root/'stow/desktop/.local/lib/graphite/quick-settings-control.sh'),*args],env={**env,**(extra or {})},text=True,capture_output=True,timeout=10,cwd=box)
        assert result.returncode==code,(result.returncode,result.stdout,result.stderr)
        assert not (box/'forbidden').exists()
        return result,(box/'events').read_text()
    result,events=run(['power-profiles'])
    state=json.loads(result.stdout)
    assert state['profiles']==[] and state['active']=='' and 'profile ' not in events
    for owner in ['new','legacy']:
        result,events=run(['power-profiles'],{'OWNER':owner})
        assert json.loads(result.stdout)['profiles']==['performance','balanced','power-saver']
        assert json.loads(result.stdout)['active']=='balanced'
        assert 'profile get' in events and 'profile list' in events
    for profile in ['power-saver','balanced','performance']:
        _,events=run(['power-profile',profile],{'OWNER':'new'})
        assert 'profile set '+profile in events
    for profile in ['', 'turbo', 'balanced;touch forbidden']:
        _,events=run(['power-profile',profile],code=1)
        assert 'profile ' not in events and 'bus ' not in events
    _,events=run(['power-profile','balanced'],code=1)
    assert 'profile set' not in events
    result,_=run(['power-profile','balanced'],{'OWNER':'new','PROFILE_FAIL':'1'},7)
    assert 'Profile denied' in result.stderr
    run(['power-profiles'],{'OWNER':'new','PROFILE_FAIL':'1'},1)
    missing=box/'missing.sh'
    missing.write_text('command() { if [[ $1 == -v && ${2:-} == powerprofilesctl ]]; then return 1; fi; builtin command "$@"; }\n')
    result,events=run(['power-profiles'],{'BASH_ENV':posix(missing)})
    assert json.loads(result.stdout)['profiles']==[] and 'NameHasOwner s org.freedesktop.UPower.PowerProfiles' not in events
print('PASS power profiles: inactive/missing service, modern/legacy owner, supported profiles, literal arguments, rejected values, denied changes. No service started or real profile changed.')
