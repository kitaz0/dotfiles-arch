"""Keep the same Gruvbox accent roles across native application theme formats."""
from pathlib import Path
import configparser, json, os, re, shutil, subprocess, tempfile, tomllib

root=Path(__file__).resolve().parent.parent
desktop=root/'stow/desktop'
palette=json.loads((desktop/'.local/share/graphite/palette.json').read_text())
primary,secondary,tertiary=(palette[k] for k in ['accent','secondary','tertiary'])
assert (primary,secondary,tertiary)==('#fe8019','#fabd2f','#d3869b')
assert palette['gold']=='#d79921'
css=(desktop/'.config/graphite/waybar/style.css').read_text()
for name,color in [('accent',primary),('secondary',secondary),('tertiary',tertiary)]:
    assert re.search(r'@define-color '+name+r'\s+'+color+r';',css)
fuzzel=configparser.ConfigParser(interpolation=None)
fuzzel.read(desktop/'.config/graphite/fuzzel/fuzzel.ini')
assert fuzzel['colors']['match']==primary[1:]+'ff'
kitty=dict(line.split(maxsplit=1) for line in (root/'stow/kitty/.config/kitty/kitty.conf').read_text().splitlines() if line and not line.startswith('#'))
assert kitty['cursor']==kitty['selection_background']==kitty['active_tab_background']==primary
assert kitty['url_color']==kitty['color14']==secondary
assert kitty['color6']==palette['gold']
assert kitty['background']==palette['background'] and kitty['foreground']==palette['foreground']
theme=dict(re.findall(r'^theme\[(\w+)\]="(#[0-9a-f]{6})"$',(root/'stow/btop/.config/btop/themes/graphite.theme').read_text(),re.M))
assert theme['hi_fg']==theme['selected_bg']==theme['cpu_box']==primary
assert theme['mem_box']==theme['net_box']==secondary
assert theme['proc_box']==tertiary
assert theme['main_bg']==palette['background'] and theme['main_fg']==palette['foreground']
fetch=json.loads((root/'stow/fastfetch/.config/fastfetch/config.jsonc').read_text())
assert fetch['display']['color']['keys']==primary
assert fetch['logo']['color']['1']==primary and fetch['logo']['color']['2']==secondary
for module in fetch['modules']:
    if module['type'] in ['cpu','gpu']: assert module['keyColor']==secondary
    if module['type']=='memory': assert module['keyColor']==tertiary
starship=tomllib.loads((root/'stow/starship/.config/starship.toml').read_text())['palettes']['gruvbox_dark']
assert starship['color_orange']==primary and starship['color_gold']==secondary and starship['color_purple']==tertiary
assert starship['color_bg0']==palette['background'] and starship['color_fg0']==palette['foreground']
code=json.loads((root/'stow/vscode/.config/Code/User/settings.json').read_text())
assert code['workbench.colorTheme']=='Gruvbox Dark Medium'
code=code['workbench.colorCustomizations']['[Gruvbox Dark Medium]']
assert code['focusBorder']==code['button.background']==code['editorCursor.foreground']==primary
assert code['textLink.foreground']==code['list.highlightForeground']==code['terminal.ansiBrightCyan']==secondary
assert code['editor.background']==palette['background'] and code['editor.foreground']==palette['foreground']
assert code['terminal.ansiCyan']==kitty['color6']
nvim=(root/'stow/nvim/.config/nvim/lua/plugins/colorscheme.lua').read_text()
assert f'bright_aqua = "{secondary}"' in nvim and f'neutral_aqua = "{palette["gold"]}"' in nvim
assert f'PmenuSel = {{ fg = "{palette["background"]}", bg = "{primary}"' in nvim
assert 'contrast = ""' in nvim
def rgb(color): return ','.join(str(int(color[i:i+2],16)) for i in [1,3,5])
for file in [desktop/'.config/graphite/dolphin/kdeglobals',desktop/'.local/share/color-schemes/Gruvbox.colors']:
    ini=configparser.ConfigParser(interpolation=None);ini.read(file)
    assert ini['Colors:Selection']['BackgroundNormal']==rgb(primary)
    assert ini['Colors:Window']['ForegroundLink']==rgb(secondary)
    assert ini['Colors:Window']['ForegroundPositive']==rgb(palette['green'])
print('PASS shared Gruvbox roles: orange focus, yellow secondary and purple details agree across bar, launcher, Kitty, Starship, Fastfetch, btop, Neovim, VS Code and KDE palette; status green retained.')

plugin=Path.home()/'.local/share/nvim/lazy/gruvbox.nvim'
if os.name=='posix' and shutil.which('nvim') and plugin.is_dir():
    with tempfile.TemporaryDirectory(prefix='graphite-theme-') as folder:
        box=Path(folder);script=box/'check.lua'
        source=root/'stow/nvim/.config/nvim/lua/plugins/colorscheme.lua'
        script.write_text('vim.opt.rtp:prepend('+json.dumps(str(plugin))+')\n'
            'vim.o.background = "dark"\n'
            'local opts = dofile('+json.dumps(str(source))+')[1].opts\n'
            'require("gruvbox").setup(opts)\n'
            'vim.cmd.colorscheme("gruvbox")\n'
            'assert(vim.api.nvim_get_hl(0, {name="Normal"}).bg == 0x282828)\n'
            'assert(vim.api.nvim_get_hl(0, {name="GruvboxAqua"}).fg == 0xfabd2f)\n'
            'assert(vim.api.nvim_get_hl(0, {name="PmenuSel"}).bg == 0xfe8019)\n'
            'assert(vim.api.nvim_get_hl(0, {name="CursorLineNr"}).fg == 0xfe8019)\n'
            'assert(vim.api.nvim_get_hl(0, {name="Directory"}).fg == 0xfabd2f)\n')
        env={**os.environ,'XDG_STATE_HOME':str(box/'state'),'XDG_CACHE_HOME':str(box/'cache')}
        result=subprocess.run(['nvim','--headless','-u','NONE','-i','NONE','-l',str(script)],env=env,capture_output=True,text=True,timeout=8)
        assert result.returncode==0,result.stdout+result.stderr
    print('PASS native Neovim/Gruvbox: medium background, orange focus/selection and gold aqua replacement; no LazyVim startup or downloads.')
else:
    print('SKIP native Neovim/Gruvbox highlights: local plugin/runtime unavailable.')
