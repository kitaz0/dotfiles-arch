"""Execute logging and preference helpers with disposable command fixtures."""
from pathlib import Path
import json, os, shutil, subprocess, tempfile, time
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
    cc,jq=shutil.which('cc'),shutil.which('jq')
    if os.name != 'nt' and Path('/proc/self/cmdline').exists() and cc and jq:
        # Use real process arguments/signals and jq, with no compositor or services.
        # A tiny stand-in has Waybar's executable name and records reload signals.
        native=box/'waybar'
        native.unlink()
        subprocess.run([cc,'-x','c','-o',str(native),'-'],input=r'''
#include <fcntl.h>
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>
static int logfd;
static void handle(int sig) {
    if (sig == SIGUSR2) { (void)!write(logfd, "reload\n", 7); }
    else _exit(0);
}
int main(void) {
    logfd = open(getenv("BAR_LOG"), O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (logfd < 0) return 1;
    signal(SIGUSR2, handle); signal(SIGTERM, handle);
    (void)!write(logfd, "ready\n", 6);
    for (;;) pause();
}
''',text=True,check=True,capture_output=True)
        stub('jq','exec "'+jq+'" "$@"')
        source=config/'config.jsonc'
        source.write_text(json.dumps({'modules-right':['custom/input-method','battery','custom/brightness']}))
        log=box/'bar.log';other_log=box/'other-bar.log'
        launcher=root/'stow/desktop/.local/lib/graphite/waybar.sh'
        live_env={**env,'BAR_LOG':str(log)}
        bar=subprocess.Popen([bash,str(launcher)],env=live_env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        foreign=subprocess.Popen([str(native),'-c',str(box/'unrelated.json'),'-s',str(config/'style.css')],env={**env,'BAR_LOG':str(other_log)})
        def await_log(path,text):
            deadline=time.monotonic()+3
            while time.monotonic()<deadline:
                if path.exists() and text in path.read_text(): return
                time.sleep(.01)
            raise AssertionError((path,path.read_text() if path.exists() else 'no log'))
        try:
            await_log(log,'ready');await_log(other_log,'ready')
            generated=list(box.glob('graphite-waybar-*.json'))
            assert len(generated)==1
            initial=json.loads(generated[0].read_text())
            assert set(initial)=={'include','modules-right'} and initial['include']==str(source)
            assert 'custom/input-method' in initial['modules-right']
            # A running bar from the older full-copy launcher must migrate too.
            generated[0].write_text('{"custom/input-method":{"exec":"stale"}}')
            run('waybar.sh','reload')
            await_log(log,'reload')
            assert json.loads(generated[0].read_text())==initial
            assert other_log.read_text()=='ready\n', 'Unrelated bar received a reload'
            assert bar.poll() is None and foreign.poll() is None
        finally:
            bar.terminate();foreign.terminate()
            bar.communicate(timeout=3);foreign.wait(timeout=3)
        assert not list(box.glob('graphite-waybar-*.json'))
        print('PASS native bar reload: source include, hardware override, old-config migration, signal delivery, unrelated-bar isolation and cleanup.')
    else:
        print('SKIP native bar reload: requires Linux /proc, cc and jq.')
print('PASS logging: all six bare battery statuses removed; prefixed/suffixed diagnostics preserved, stdout/stderr diagnostics and Waybar exit status retained; appearance apply/reapply/restore/conflict/write failure (commands mocked).')
