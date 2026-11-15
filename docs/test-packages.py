"""Pacman command-review tests; no package operations."""
from pathlib import Path
import os, shutil, subprocess, tempfile
root=Path(__file__).resolve().parent.parent
bash=r'C:\Program Files\Git\bin\bash.exe' if os.name=='nt' else shutil.which('bash')
checks=root/'.checks';checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks,prefix='packages-') as folder:
    box=Path(folder)
    path=subprocess.check_output([bash,'-c','cygpath -u "$1"','test',str(box)],text=True).strip() if os.name=='nt' else str(box)
    mock=box/'pacman'
    mock.write_text('''#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$PACMAN_CALLS"
case $1 in
    -Si) [[ $2 != "${UNAVAILABLE:-none}" ]] ;;
    -Q) [[ $2 == "${ALTERNATIVE:-none}" || $2 == "${PRESENT:-none}" ]] ;;
    *) echo 'Unexpected package mutation' >&2; exit 99 ;;
esac
''',newline='\n');mock.chmod(0o700)
    env=os.environ.copy();env.pop('BASH_ENV',None);env.update(PATH=path+':/usr/bin:/bin',PACMAN_CALLS=path+'/calls')
    supplies=box/'supplies';supplies.mkdir()
    runner=box/'install-deps.sh'
    supplies_path=path+'/supplies'
    quoted_supplies="'"+supplies_path.replace("'", "'\\''")+"'"
    runner.write_text((root/'install-deps.sh').read_text().replace('/sys/class/power_supply',quoted_supplies),newline='\n')
    (box/'packages.tsv').write_bytes((root/'packages.tsv').read_bytes())
    def run(arg,extra=None,code=0):
        e=env.copy();e.update(extra or {})
        (box/'calls').unlink(missing_ok=True)
        args=arg if isinstance(arg,list) else [arg]
        p=subprocess.run([bash,str(runner),*args],env=e,cwd=root,text=True,capture_output=True)
        assert p.returncode==code,p.stdout+p.stderr
        return p.stdout+p.stderr
    for flag in ['--help','-h']:
        help_text=run(flag)
        assert '--list-optional' in help_text and '--optional=CATEGORY' in help_text
        assert not (box/'calls').exists()
    listing=run('--list-optional')
    assert not (box/'calls').exists() and 'sudo pacman' not in listing
    for line in (root/'packages.tsv').read_text(encoding='utf-8').splitlines():
        if line.startswith(('optional\t','development\t')):
            tier,category,package,purpose=line.split('\t')
            assert any(category in row and tier in row and package in row and purpose in row for row in listing.splitlines())
    assert 'obs-studio' in listing and 'shellcheck' in listing
    assert 'separately' in run(['--list-optional','--optional=obs'],code=2)
    assert 'obs-studio' not in run('--review') and 'wf-recorder' in run('--review')
    full=run('--review')
    assert 'Missing: stow' in full and 'Missing: starship' in full and 'Missing: neovim' in full
    desktop=run(['--review','--desktop-only'])
    assert 'Missing: stow' in desktop and 'Missing: kitty' in desktop
    assert 'Missing: starship' not in desktop and 'Missing: neovim' not in desktop
    assert 'Missing: neovim' not in run(['--desktop-only','--with-optional'])

    assert 'wf-recorder' not in run('--minimal')
    assert 'obs-studio' in run('--optional=obs')
    for args in [['--review','--optional=obs'], ['--optional=obs','--review'], ['--dry-run','--optional=obs']]:
        result=run(args)
        assert 'Missing: obs-studio' in result
        command=next(line for line in result.splitlines() if line.startswith('sudo pacman '))
        assert 'obs-studio' in command.split()
    result=run(['--review','--optional=obs'],{'PRESENT':'obs-studio'})
    assert 'Present: obs-studio' in result
    assert 'obs-studio' not in next(line for line in result.splitlines() if line.startswith('sudo pacman ')).split()
    result=run(['--review','--optional=obs'],{'UNAVAILABLE':'obs-studio'},code=1)
    assert 'UNAVAILABLE: obs-studio' in result and 'sudo pacman' not in result
    assert 'Invalid argument' in run(['--review','--typo'],code=2)
    assert 'Invalid argument' in run('--optional=',code=2)
    assert 'Choose one package selection' in run(['--minimal','--optional=obs'],code=2)
    assert 'obs-studio' not in run([])
    assert 'shellcheck' in run('--optional=checks')
    assert 'Unknown optional category' in run('--optional=unknown',code=2)
    assert 'UNAVAILABLE: kitty' in run('--review',{'UNAVAILABLE':'kitty'},code=1)
    result=run('--review',{'ALTERNATIVE':'pulseaudio'},code=1)
    assert 'REVIEW REQUIRED' in result and 'sudo pacman' not in result
    assert 'REVIEW REQUIRED' in run('--review',{'ALTERNATIVE':'ibus'},code=1)
    assert 'REVIEW REQUIRED' in run('--review',{'ALTERNATIVE':'fcitx'},code=1)
    assert 'Missing: hyprsunset' in run('--review')
    assert 'Missing: power-profiles-daemon' not in run('--review')
    peripheral=supplies/'mouse';peripheral.mkdir()
    (peripheral/'type').write_text('Battery\n');(peripheral/'scope').write_text('Device\n')
    assert 'Missing: power-profiles-daemon' not in run('--with-optional')
    battery=supplies/'BAT0';battery.mkdir()
    (battery/'type').write_text('Battery\n');(battery/'scope').write_text('System\n')
    result=run('--review')
    assert 'Missing: power-profiles-daemon' in result and 'enable --now power-profiles-daemon.service' in result
    for manager in ['tlp','tlp-pd','tuned','tuned-ppd','auto-cpufreq','system76-power']:
        result=run('--review',{'ALTERNATIVE':manager})
        assert 'Preserving '+manager in result and 'Missing: power-profiles-daemon' not in result
        assert 'enable --now power-profiles-daemon' not in result
        assert 'Missing: hyprsunset' in result
    print('PASS packages: local help/list without pacman calls, manifest-complete optional/development list, tiers, combined/reordered review and optional flags, installed/missing OBS, rejected trailing/conflicting arguments, unknown/unavailable packages and alternative audio stack (pacman mocked)')
if not list(checks.iterdir()): checks.rmdir()
