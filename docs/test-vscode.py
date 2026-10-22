"""Extension CLI boundary checks; no extensions downloaded and no real VS Code launched."""
from pathlib import Path
import json, os, shutil, subprocess, tempfile
root=Path(__file__).resolve().parent.parent
bash=shutil.which('bash')
checks=root/'.checks';checks.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=checks,prefix='vscode-') as folder:
    box=Path(folder);(box/'extensions').mkdir();(box/'bin').mkdir()
    shutil.copyfile(root/'install-vscode-extensions.sh',box/'install-vscode-extensions.sh')
    listing=box/'extensions/vscode.txt'
    listing.write_text('# comment\nPublisher.Existing\r\npublisher.missing\npublisher.existing\n')
    cli=box/'bin/mock-code'
    cli.write_text('''#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$CALLS"
case $1 in
    --list-extensions)
        [[ ${LIST_FAIL:-0} != 1 ]] || exit 5
        printf 'Publisher.Existing\\npublisher.unrelated\\n' ;;
    --install-extension)
        [[ $# == 2 && $2 == publisher.missing ]] || exit 99
        [[ ${INSTALL_FAIL:-0} != 1 ]] || exit 7 ;;
    *) exit 99 ;;
esac
''');cli.chmod(0o700)
    calls=box/'calls'
    env={**os.environ,'PATH':str(box/'bin')+':/usr/bin:/bin','CODE_BIN':'mock-code','CALLS':str(calls)}
    env.pop('BASH_ENV',None)
    def run(*args,code=0,extra=None):
        calls.unlink(missing_ok=True)
        p=subprocess.run([bash,str(box/'install-vscode-extensions.sh'),*args],env={**env,**(extra or {})},text=True,capture_output=True,timeout=10)
        assert p.returncode==code,p.stdout+p.stderr
        return p, calls.read_text().splitlines() if calls.exists() else []
    p,events=run('--dry-run');assert not events and p.stdout.count('ENSURE:')==2
    p,events=run('--check',code=1)
    assert events==['--list-extensions'] and 'MISSING: publisher.missing' in p.stdout
    p,events=run()
    assert events==['--list-extensions','--install-extension publisher.missing']
    assert '1 already installed, 1 installed' in p.stdout
    p,events=run(extra={'INSTALL_FAIL':'1'},code=1);assert '1 failed' in p.stdout
    p,events=run(extra={'LIST_FAIL':'1'},code=1);assert events==['--list-extensions']
    for bad in ['--force','publisher.bad;touch forbidden','publisher/name','publisher.name@1.0.0','publisher.name secret']:
        listing.write_text('publisher.valid\n'+bad+'\n')
        p,events=run(code=2);assert not events
    listing.write_text('# empty\n');p,events=run();assert not events
    listing.write_text('publisher.missing\n')
    p,events=run('--dry-run',extra={'CODE_BIN':'nonexistent-editor'});assert not events
    run('--check',extra={'CODE_BIN':'nonexistent-editor'},code=1)
    run('--check','--dry-run',code=2);run('--unknown',code=2)
    p,events=run('--help');assert not events and '--check' in p.stdout
settings=json.loads((root/'stow/vscode/.config/Code/User/settings.json').read_text())
assert isinstance(settings,dict)
ids=[line for line in (root/'extensions/vscode.txt').read_text().splitlines() if line and not line.startswith('#')]
assert len(ids)==len(set(ids)) and 'jdinhlife.gruvbox' in ids
assert [p.relative_to(root/'stow/vscode').as_posix() for p in (root/'stow/vscode').rglob('*') if p.is_file()]==['.config/Code/User/settings.json']
print('PASS VS Code: no-download preview/check, case-insensitive installed IDs, duplicate handling, missing-only installs, failure exit codes, rejected arguments/IDs and settings-only Stow package (CLI mocked).')
