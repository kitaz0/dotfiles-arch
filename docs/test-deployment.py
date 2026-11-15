"""Stow-wrapper boundary tests in disposable homes; real Stow integration when available."""
from pathlib import Path
import os, shutil, subprocess, sys, tempfile

root = Path(__file__).resolve().parent.parent
bash = shutil.which('bash')
checks = root / '.checks'
checks.mkdir(exist_ok=True)
if os.name != 'posix':
    print('SKIP Stow deployment fixtures: POSIX symlinks/permissions required.')
    raise SystemExit(0)
real_stow = shutil.which('stow')
mock = r'''import os, pathlib, sys
args=sys.argv[1:]
base=pathlib.Path(next(x.split('=',1)[1] for x in args if x.startswith('--dir=')))
home=pathlib.Path(next(x.split('=',1)[1] for x in args if x.startswith('--target=')))
packages=[x for x in args if not x.startswith('-')]
assert '--no-folding' in args
assert '--adopt' not in args
if os.environ.get('STOW_FAIL')=='1': raise SystemExit(7)
for package in packages:
    for source in sorted((base/package).rglob('*')):
        if not source.is_file(): continue
        target=home/source.relative_to(base/package)
        owned=target.is_symlink() and target.resolve()==source.resolve()
        if '--delete' in args:
            if owned and '--simulate' not in args: target.unlink()
        elif not owned:
            if target.exists() or target.is_symlink(): raise SystemExit('conflict: '+str(target))
            if '--simulate' not in args:
                target.parent.mkdir(parents=True,exist_ok=True)
                target.symlink_to(os.path.relpath(source,target.parent))
'''
def snapshot(folder):
    return {str(p.relative_to(folder)): ('link',os.readlink(p)) if p.is_symlink() else ('file',p.read_bytes(),p.stat().st_mode) for p in folder.rglob('*') if p.is_symlink() or p.is_file()}
with tempfile.TemporaryDirectory(dir=checks,prefix='stow-') as directory:
    box=Path(directory); project=box/'project'; home=box/'home'; commands=box/'bin'
    for p in [project,home,commands]:p.mkdir()
    shutil.copyfile(root/'apply-config.sh',project/'apply-config.sh')
    for package,rel in [('desktop','.config/graphite/example.conf'),('kitty','.config/kitty/kitty.conf'),('starship','.config/starship.toml'),('nvim','.config/nvim/init.lua'),('vscode','.config/Code/User/settings.json'),('fastfetch','.config/fastfetch/config.jsonc'),('btop','.config/btop/btop.conf'),('lazygit','.config/lazygit/config.yml')]:
        p=project/'stow'/package/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(package+' config\n')
    for rel in ['config','profile','conf/classicui.conf']:
        p=project/'defaults/fcitx5'/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('default\n')
    stub=commands/'stow';stub.write_text('#!'+sys.executable+'\n'+mock);stub.chmod(0o755)
    env={**os.environ,'HOME':str(home),'PATH':str(commands)+':/usr/bin:/bin','XDG_STATE_HOME':str(home/'.local/state')}
    for name in ['BASH_ENV','XDG_CONFIG_HOME']:env.pop(name,None)
    def run(*args,code=0,extra=None):
        p=subprocess.run([bash,str(project/'apply-config.sh'),*args],env={**env,**(extra or {})},text=True,capture_output=True,timeout=15)
        assert p.returncode==code,p.stdout+p.stderr
        return p
    original=home/'.config/kitty/kitty.conf';original.parent.mkdir(parents=True);original.write_text('original kitty\n')
    keys=home/'.ssh/id_ed25519';keys.parent.mkdir();keys.write_text('fixture private data stays outside source\n')
    before=snapshot(home);sources=snapshot(project)
    assert 'BACKUP:' in run('--dry-run').stdout
    assert snapshot(home)==before and snapshot(project)==sources
    run('--apply')
    assert original.is_symlink() and original.read_text()=='kitty config\n'
    assert (home/'.config/Code/User/settings.json').is_symlink()
    backups=list((home/'.local/state/graphite/backups').glob('before-stow-*'))
    assert len(backups)==1 and (backups[0]/'.config/kitty/kitty.conf').read_text()=='original kitty\n'
    assert keys.read_text()=='fixture private data stays outside source\n'
    run('--apply');assert len(list(backups[0].parent.iterdir()))==1
    original.write_text('edited through symlink\n')
    assert (project/'stow/kitty/.config/kitty/kitty.conf').read_text()=='edited through symlink\n'
    profile=home/'.config/graphite/fcitx5/profile';profile.write_text('local writable settings\n')
    run('--apply');assert profile.read_text()=='local writable settings\n' and not profile.is_symlink()
    before=snapshot(home);run('--unstow');assert snapshot(home)==before
    run('--unstow','--apply')
    assert not original.exists() and profile.read_text()=='local writable settings\n' and keys.is_file()
    run('--apply','--desktop-only')
    assert (home/'.config/graphite/example.conf').is_symlink() and not original.exists()
    assert not (home/'.config/Code/User/settings.json').exists()
    run('--unstow','--apply','--desktop-only')
    original.parent.rmdir();external=box/'external';external.mkdir();original.parent.symlink_to(external)
    run('--apply',code=1);assert not any(external.iterdir())
    original.parent.unlink();original.parent.mkdir();original.write_text('keep if stow fails\n')
    run('--apply',code=7,extra={'STOW_FAIL':'1'})
    assert any((p/'.config/kitty/kitty.conf').read_text()=='keep if stow fails\n' for p in backups[0].parent.iterdir())
    for arg in ['--rollback','--uninstall','--replace-existing','--unknown']:run(arg,code=2)
    run('--help');run('--apply','--dry-run',code=2)
    assert not (home/'.local/state/graphite/deployments').exists()
    print('PASS Stow wrapper: read-only preview, default/desktop-only selection, initial backup, repeat linking, live edits, local seeds, unstow, ancestor refusal, failed Stow backup preservation and retired flags (Stow mocked).')
    if real_stow:
        integration=box/'integration';integration.mkdir()
        real_env={**env,'HOME':str(integration),'PATH':str(Path(real_stow).parent)+':/usr/bin:/bin','XDG_STATE_HOME':str(integration/'.local/state')}
        for args in [('--apply',),('--apply',),('--unstow','--apply')]:
            p=subprocess.run([bash,str(project/'apply-config.sh'),*args],env=real_env,text=True,capture_output=True)
            assert p.returncode==0,p.stdout+p.stderr
            if '--unstow' not in args:assert (integration/'.config/nvim/init.lua').is_symlink()
        assert not (integration/'.config/nvim/init.lua').exists()
        print('PASS real GNU Stow: link, restow and unstow in disposable home.')
    else:print('SKIP real GNU Stow integration: stow is not installed; command-boundary fixtures only.')
