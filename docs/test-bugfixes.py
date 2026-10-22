"""Execute logging and preference helpers with disposable command fixtures."""
from pathlib import Path
import os, shutil, subprocess, tempfile
root=Path(__file__).resolve().parent.parent
bash=r'C:\Program Files\Git\bin\bash.exe' if os.name=='nt' else shutil.which('bash')
def posix(p):
    return subprocess.check_output([bash,'-c','cygpath -u "$1"','test',str(p)],text=True).strip() if os.name=='nt' else str(p)
checks=root/'.checks'; checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks,prefix='fixes-') as directory:
    box=Path(directory)
    def stub(name,body):
        p=box/name;p.write_text('#!/usr/bin/env bash\n'+body+'\n',encoding='utf-8',newline='\n');p.chmod(0o700)
    stub('gsettings', '''case $1 in
    get) cat "$PREFERENCE" ;;
    set) [[ ${SET_FAIL:-0} == 0 ]] || exit 4; value=$4; value=${value//\\\'/}; printf "\'%s\'\\n" "$value" > "$PREFERENCE" ;;
    *) exit 9 ;;
esac''')
    stub('flock','exit 0')
    stub('jq','cat')
    statuses=['Full','Charging','Discharging','Not charging','Unknown','Plugged']
    preserved=['useful stdout','warning: useful stderr','[warning] Full','Discharging: device error','Not charging unexpectedly','Unknown device','Plugged adapter missing']
    messages='\\n'.join(statuses+preserved)+'\\n'
    stub('waybar', 'printf "'+messages+'"; printf "'+messages+'" >&2; exit "${BAR_EXIT:-0}"')
    state=box/'state/graphite/appearance';state.mkdir(parents=True)
    config=box/'.config/graphite/waybar';config.mkdir(parents=True)
    (config/'config.jsonc').write_text('{}')
    shim=box/'env.sh';shim.write_text('mkdir() { [[ -d ${!#} ]]; }\n',newline='\n')
    pref=box/'preference';pref.write_text("'default'\n")
    env={**os.environ,'PATH':posix(box)+':/usr/bin:/bin','HOME':posix(box),'XDG_STATE_HOME':posix(box/'state'),
         'XDG_RUNTIME_DIR':posix(box),'PREFERENCE':posix(pref),'BASH_ENV':posix(shim)}
    def run(name,action=None,code=0,**extra):
        p=subprocess.run([bash,str(root/'stow/desktop/.local/lib/graphite'/name),*([action] if action else [])],env={**env,**extra},capture_output=True,text=True,cwd=box)
        assert p.returncode==code,(p.returncode,p.stdout,p.stderr)
        return p
    run('appearance.sh','dark')
    assert pref.read_text().strip()=="'prefer-dark'"
    run('appearance.sh','dark')
    assert (state/'color-scheme.before').read_text().strip()=="'default'"
    pref.write_text("'prefer-light'\n")
    run('appearance.sh','restore',code=1)
    assert pref.read_text().strip()=="'prefer-light'"
    pref.write_text("'prefer-dark'\n")
    run('appearance.sh','restore')
    assert pref.read_text().strip()=="'default'" and not (state/'color-scheme.before').exists()
    run('appearance.sh','dark',code=4,SET_FAIL='1')
    assert pref.read_text().strip()=="'default'" and (state/'color-scheme.before').exists()
    run('appearance.sh','restore')
    for code in [0,7]:
        p=run('waybar.sh',code=code,BAR_EXIT=str(code))
        assert not p.stdout
        assert p.stderr.splitlines() == preserved + preserved
        assert not list(box.glob('graphite-waybar-*.json'))
print('PASS logging: all six bare battery statuses removed; prefixed/suffixed diagnostics preserved, stdout/stderr diagnostics and Waybar exit status retained; appearance apply/reapply/restore/conflict/write failure (commands mocked).')
