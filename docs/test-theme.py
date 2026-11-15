"""Keep the same Gruvbox accent roles across native application theme formats."""
from pathlib import Path
import configparser, json, os, re, shutil, subprocess, tempfile, tomllib

root=Path(__file__).resolve().parent.parent
desktop=root/'stow/desktop'
palette=json.loads((desktop/'.local/share/graphite/palette.json').read_text())
primary,secondary,tertiary=(palette[k] for k in ['accent','secondary','tertiary'])
css=(desktop/'.config/graphite/theme/colors.css').read_text()
for app in ['waybar','swaync']:
    assert '@import "../theme/colors.css";' in (desktop/f'.config/graphite/{app}/style.css').read_text()
for name,color in [('accent',primary),('secondary',secondary),('tertiary',tertiary)]:
    assert re.search(r'@define-color '+name+r'\s+'+color+r';',css)
fuzzel=configparser.ConfigParser(interpolation=None)
fuzzel.read(desktop/'.config/graphite/fuzzel/fuzzel.ini')
assert fuzzel['colors']['match']==primary[1:]+'ff'
kitty=dict(line.split(maxsplit=1) for line in (root/'stow/kitty/.config/kitty/colors.conf').read_text().splitlines() if line and not line.startswith('#'))
assert 'include colors.conf' in (root/'stow/kitty/.config/kitty/kitty.conf').read_text()
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
lazygit_source=(root/'stow/lazygit/.config/lazygit/config.yml').read_text()
lazygit={key:json.loads(value) for key,value in re.findall(r'^    (\w+): (\[.*\])$',lazygit_source,re.M)}
assert lazygit['optionsTextColor']==[secondary]
assert lazygit['selectedLineBgColor']==[palette['surface']]
assert lazygit['selectedLineFgColor']==[palette['foreground'],'bold']
def luminance(color):
    values=[int(color[i:i+2],16)/255 for i in [1,3,5]]
    linear=[v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4 for v in values]
    return sum(v*w for v,w in zip(linear,[0.2126,0.7152,0.0722]))
def contrast(a,b):
    values=sorted([luminance(a),luminance(b)])
    return (values[1]+0.05)/(values[0]+0.05)
assert contrast(lazygit['optionsTextColor'][0],lazygit['selectedLineBgColor'][0])>=4.5
assert contrast(lazygit['selectedLineFgColor'][0],lazygit['selectedLineBgColor'][0])>=7
nvim=(root/'stow/nvim/.config/nvim/lua/plugins/colorscheme.lua').read_text()
assert 'bright_aqua = colors.secondary' in nvim and 'neutral_aqua = colors.gold' in nvim
assert 'PmenuSel = { fg = colors.background, bg = colors.accent' in nvim
assert 'contrast = ""' in nvim
def rgb(color): return ','.join(str(int(color[i:i+2],16)) for i in [1,3,5])
for file in [desktop/'.config/graphite/dolphin/kdeglobals',desktop/'.local/share/color-schemes/Gruvbox.colors']:
    ini=configparser.ConfigParser(interpolation=None);ini.read(file)
    assert ini['Colors:Selection']['BackgroundNormal']==rgb(primary)
    assert ini['Colors:Window']['ForegroundLink']==rgb(secondary)
    assert ini['Colors:Window']['ForegroundPositive']==rgb(palette['green'])
print('PASS shared Gruvbox roles: accents agree across desktop/apps; Lazygit shortcut and selected-text contrast checked; status green retained.')

plugin=Path.home()/'.local/share/nvim/lazy/gruvbox.nvim'
if os.name=='posix' and shutil.which('nvim') and plugin.is_dir():
    with tempfile.TemporaryDirectory(prefix='graphite-theme-') as folder:
        box=Path(folder);script=box/'check.lua'
        source=root/'stow/nvim/.config/nvim/lua/plugins/colorscheme.lua'
        script.write_text('vim.opt.rtp:prepend('+json.dumps(str(plugin))+')\n'
            'vim.opt.rtp:prepend('+json.dumps(str(root/'stow/nvim/.config/nvim'))+')\n'
            'vim.o.background = "dark"\n'
            'local opts = dofile('+json.dumps(str(source))+')[1].opts\n'
            'require("gruvbox").setup(opts)\n'
            'vim.cmd.colorscheme("gruvbox")\n'
            'assert(vim.api.nvim_get_hl(0, {name="Normal"}).bg == '+str(int(palette['background'][1:],16))+')\n'
            'assert(vim.api.nvim_get_hl(0, {name="GruvboxAqua"}).fg == '+str(int(palette['secondary'][1:],16))+')\n'
            'assert(vim.api.nvim_get_hl(0, {name="PmenuSel"}).bg == '+str(int(palette['accent'][1:],16))+')\n'
            'assert(vim.api.nvim_get_hl(0, {name="CursorLineNr"}).fg == '+str(int(palette['accent'][1:],16))+')\n'
            'assert(vim.api.nvim_get_hl(0, {name="Directory"}).fg == '+str(int(palette['secondary'][1:],16))+')\n')
        env={**os.environ,'XDG_STATE_HOME':str(box/'state'),'XDG_CACHE_HOME':str(box/'cache')}
        result=subprocess.run(['nvim','--headless','-u','NONE','-i','NONE','-l',str(script)],env=env,capture_output=True,text=True,timeout=8)
        assert result.returncode==0,result.stdout+result.stderr
        snacks=plugin.parent/'snacks.nvim'
        if snacks.is_dir():
            # Run Snacks' real generator; stub only the terminal launch, not its theme merge.
            expected={key:values[0] for key,values in lazygit.items()}
            script.write_text(script.read_text()
                +'vim.opt.rtp:prepend('+json.dumps(str(snacks))+')\n'
                +'local snacks = require("snacks")\n'
                +'snacks.setup(dofile('+json.dumps(str(root/'stow/nvim/.config/nvim/lua/plugins/lazygit.lua'))+')[1].opts)\n'
                +'vim.fn.mkdir(vim.fn.stdpath("cache"), "p")\n'
                +'snacks.terminal = function() return {} end\n'
                +'snacks.lazygit()\n')
            result=subprocess.run(['nvim','--headless','-u','NONE','-i','NONE','-l',str(script)],env=env,capture_output=True,text=True,timeout=8)
            assert result.returncode==0,result.stdout+result.stderr
            generated=(box/'cache/nvim/lazygit-theme.yml').read_text()
            for key,color in expected.items():
                assert re.search(key+r':\s*-\s*"'+re.escape(color)+'"',generated), (key,color,generated)
            print('PASS native Snacks: generated Lazygit theme agrees with every shared standalone theme role.')
    print('PASS native Neovim/Gruvbox: medium background, orange focus/selection and gold aqua replacement; no LazyVim startup or downloads.')
else:
    print('SKIP native Neovim/Gruvbox highlights: local plugin/runtime unavailable.')
