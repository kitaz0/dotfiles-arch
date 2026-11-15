"""Audit source/config layout and disposable fixtures; never deploy to the real home."""
from pathlib import Path
import argparse, configparser, json, os, re, shutil, subprocess, sys, tomllib
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser(description=__doc__)
parser.parse_args()
root = Path(__file__).resolve().parent.parent
excluded = {'backups', '.checks', '__pycache__', '.git', '.agents', '.aws', '.codex'}
checks = root / '.checks'
records = []
def log(message):
    print(message, flush=True)
    records.append(message)
def run(args):
    result = subprocess.run(args, cwd=root, text=True, capture_output=True)
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout

bash = shutil.which('bash')
assert bash, 'Bash is required'
files = [p for p in root.rglob('*') if not excluded.intersection(p.relative_to(root).parts) and p.is_file()]
for p in files:
    if p.suffix in {'.png', '.zip', '.pyc', '.pyo', '.log', '.core'}:
        continue
    data = p.read_bytes()
    assert not data.startswith(b'\xef\xbb\xbf') and b'\r' not in data, p
    assert not re.search(rb'^-----BEGIN (?:OPENSSH|RSA|EC|DSA|PGP) PRIVATE KEY', data, re.M), p
    assert not re.search(rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16})\b', data), p
for p in [*root.glob('*.sh'), *(root/'stow/desktop').rglob('*.sh')]:
    run([bash, '-n', str(p)])
    for line in p.read_text().splitlines():
        assert not line.startswith('\t') and (len(line)-len(line.lstrip(' '))) % 4 == 0, (p,line)
log('PASS: shell syntax, formatting, LF text and common private-key/token signatures.')

packages = ['desktop', 'kitty', 'starship', 'nvim', 'vscode', 'fastfetch', 'btop', 'lazygit']
owned = {}
for package in packages:
    folder = root/'stow'/package
    assert folder.is_dir()
    for p in folder.rglob('*'):
        assert not p.is_symlink(), p
        assert not {'.ssh','.gnupg','.aws','node_modules','__pycache__','cache','state','data'}.intersection(p.relative_to(folder).parts), p
        assert p.suffix not in {'.pem','.key','.pub','.p12','.pfx'}, p
        if not p.is_file(): continue
        destination = p.relative_to(folder).as_posix()
        assert destination not in owned, (destination,package,owned.get(destination))
        owned[destination] = package
        if p.suffix == '.sh': assert os.access(p,os.X_OK), p
assert all(not name.startswith('.config/graphite/fcitx5/') for name in owned)
for rel in ['config','profile','conf/classicui.conf']: assert (root/'defaults/fcitx5'/rel).is_file()
assert not (root/'deploy.tsv').exists()
assert not (root/'docs/ROLLBACK.md').exists()
log(f'PASS: {len(owned)} unique Stow destinations, executable helpers, local Fcitx defaults and config-only package layout.')

desktop = root/'stow/desktop'
config = desktop/'.config/graphite'
helpers = desktop/'.local/lib/graphite'
for path in [config/'waybar/config.jsonc', config/'swaync/config.json', config/'power/defaults.json', desktop/'.local/share/graphite/palette.json', *(root/'stow/nvim').rglob('*.json'), root/'stow/vscode/.config/Code/User/settings.json', root/'stow/fastfetch/.config/fastfetch/config.jsonc']:
    json.loads(path.read_text())
for path in (root/'stow').rglob('*.toml'): tomllib.loads(path.read_text())
ET.parse(desktop/'.local/share/graphite/optional/fontconfig/graphite.conf')
for path in desktop.rglob('*.ini'):
    ini = configparser.ConfigParser(interpolation=None)
    ini.read(path,encoding='utf-8')
assert (desktop/'.local/share/graphite/wallpaper.png').read_bytes()[:8] == b'\x89PNG\r\n\x1a\n'
for name in re.findall(r'script\("[^"]+", "([^"]+)"',(config/'hypr/graphite/bindings.lua').read_text()): assert (helpers/name).is_file(),name
for path in helpers.glob('*.sh'):
    source = path.read_text()
    assert not re.search(r'\bpython[23]?\b',source)
    if path.name != 'terminal.sh': assert 'export XDG_CONFIG_HOME=' not in source
log('PASS: JSON/TOML/XML/INI, wallpaper, binding helpers and normal session XDG lookup.')
for path in [root/'README.md', *(root/'docs').glob('*.md')]:
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)',path.read_text()):
        if '://' not in target and not target.startswith('#'):
            assert (path.parent/target.split('#')[0]).is_file(), (path,target)
log('PASS: local documentation links.')

lua = shutil.which('lua') or shutil.which('lua5.4') or shutil.which('luajit')
if lua:
    for name in ['test-monitors.lua','test-bindings.lua']: log(run([lua,'docs/'+name]).strip())
else: log('SKIP Lua command fixtures: interpreter unavailable.')
luac = shutil.which('luac')
if luac:
    for path in (root/'stow/nvim').rglob('*.lua'): run([luac,'-p',str(path)])
    log('PASS: imported LazyVim Lua syntax; plugins not loaded/downloaded.')
else: log('SKIP imported Lua syntax: luac unavailable.')
node = shutil.which('node')
if node: log(run([node,'docs/test-popup-state.js']).strip())
else: log('SKIP popup JavaScript execution: Node unavailable.')
for path in sorted((root/'docs').glob('test-*.py')):
    log(run([sys.executable,str(path)]).strip())
log('NOT TESTED: live desktop/cgroups, SDDM, lock/suspend, plugins and physical hardware. See docs/TESTING.md.')
checks.mkdir(exist_ok=True)
(checks/'validation.md').write_text('# Local validation\n\nCommand fixtures on '+sys.platform+'; not a desktop integration test.\n\n'+'\n'.join('- '+line for line in records)+'\n')

def tree(folder,prefix=''):
    entries=sorted((p for p in folder.iterdir() if p.name not in excluded and p.suffix not in {'.pyc','.pyo','.log','.core'}),key=lambda p:(not p.is_dir(),p.name.lower()))
    lines=[]
    for i,p in enumerate(entries):
        last=i==len(entries)-1
        lines.append(prefix+('`-- ' if last else '|-- ')+p.name+('/' if p.is_dir() else ''))
        if p.is_dir(): lines.extend(tree(p,prefix+('    ' if last else '|   ')))
    return lines
(root/'docs/TREE.txt').write_text('hyprland-setup/\n'+'\n'.join(tree(root))+'\n')
