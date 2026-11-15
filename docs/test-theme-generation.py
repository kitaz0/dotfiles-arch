"""Exercise theme edits and native imports in a disposable checkout, never the live desktop."""
from pathlib import Path
import ctypes
import ctypes.util
import json
import os
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='graphite-theme-build-') as folder:
    box = Path(folder)
    shutil.copytree(root/'theme', box/'theme')
    shutil.copytree(root/'stow', box/'stow')
    shutil.copy2(root/'theme.py', box/'theme.py')

    def run(*args, code=0):
        result = subprocess.run([sys.executable, str(box/'theme.py'), *args], capture_output=True, text=True, timeout=10)
        assert result.returncode == code, result.stdout + result.stderr
        return result

    def snapshot():
        return {p.relative_to(box): (p.read_bytes(), p.stat().st_mtime_ns) for p in (box/'stow').rglob('*') if p.is_file()}

    baseline = snapshot()
    run('--check')
    run()  # A no-op build must not touch mtimes or unrelated configuration.
    assert snapshot() == baseline
    source = json.loads((box/'theme/palette.json').read_text())
    original_accent = source['colors'][source['roles']['accent']]
    fixture_accent = '#d65d0e' if original_accent != '#d65d0e' else '#fe8019'
    source['colors']['fixture_accent'] = fixture_accent
    source['roles']['accent'] = 'fixture_accent'
    (box/'theme/palette.json').write_text(json.dumps(source))
    run('--check', code=1)
    assert snapshot() == baseline
    run()
    run('--check')
    changed = {path for path, data in snapshot().items() if data[0] != baseline[path][0]}
    # Every package must receive the edit, including decimal RGB, ANSI and native includes.
    assert {path.parts[1] for path in changed} == {'desktop','kitty','starship','nvim','vscode','fastfetch','btop','lazygit'}
    config = box/'stow/desktop/.config/graphite'
    rgb = [str(int(fixture_accent[i:i+2],16)) for i in [1,3,5]]
    assert 'rgba('+fixture_accent[1:]+'ff)' in (config/'hypr/graphite/appearance.lua').read_text()
    assert 'match='+fixture_accent[1:]+'ff' in (config/'fuzzel/fuzzel.ini').read_text()
    assert 'BackgroundNormal='+','.join(rgb) in (config/'dolphin/kdeglobals').read_text()
    fetch = json.loads((box/'stow/fastfetch/.config/fastfetch/config.jsonc').read_text())
    assert '{#38;2;'+';'.join(rgb)+'}GRAPHITE' in fetch['modules'][0]['format']
    original_fetch = json.loads((root/'stow/fastfetch/.config/fastfetch/config.jsonc').read_text())
    assert [m for m in fetch['modules'] if m['type'] != 'custom'] == [m for m in original_fetch['modules'] if m['type'] != 'custom']
    assert json.loads((box/'stow/vscode/.config/Code/User/settings.json').read_text())['cmake.debugConfig'] == {'type':'lldb','console':'internalConsole'}
    assert (config/'quick-settings/PowerPage.qml').read_bytes() == (root/'stow/desktop/.config/graphite/quick-settings/PowerPage.qml').read_bytes()

    # Reject invalid palette data and even a bad token in the LAST template before writing outputs.
    built = snapshot()
    source['colors']['fixture_accent'] = 'invalid'
    (box/'theme/palette.json').write_text(json.dumps(source))
    run(code=2)
    assert snapshot() == built
    source['colors']['fixture_accent'] = fixture_accent
    (box/'theme/palette.json').write_text(json.dumps(source))
    manifest = json.loads((box/'theme/templates.json').read_text())
    last = box/'theme/templates'/list(manifest)[-1]
    last.write_text(last.read_text() + '\n{{missing_role}}\n')
    run(code=2)
    assert snapshot() == built
    last.write_text(last.read_text().replace('\n{{missing_role}}\n', ''))
    run('--check')
    print('PASS theme generation: all eight packages follow one edit; no-op/check do not write; invalid input causes no partial updates.')

    library = ctypes.util.find_library('gtk-3') if os.name == 'posix' else None
    if library:
        gtk = ctypes.CDLL(library)
        gtk.gtk_css_provider_new.restype = ctypes.c_void_p
        gtk.gtk_css_provider_load_from_path.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_void_p)]
        gtk.gtk_css_provider_load_from_path.restype = ctypes.c_int
        for app in ['waybar','swaync']:
            error = ctypes.c_void_p()
            assert gtk.gtk_css_provider_load_from_path(gtk.gtk_css_provider_new(), os.fsencode(config/app/'style.css'), ctypes.byref(error))
        print('PASS native GTK: both stylesheets load their shared palette through relative imports.')
    else:
        print('SKIP native GTK palette imports: GTK 3 unavailable.')

    qml = shutil.which('qml') or ('/usr/lib/qt6/bin/qml' if Path('/usr/lib/qt6/bin/qml').is_file() else None)
    if qml:
        script = box/'check.qml'
        script.write_text('import QtQuick\n'
            'import "'+(config/'quick-settings').as_uri()+'" as Graphite\n'
            'import "'+(config/'quick-settings/Theme.js').as_uri()+'" as Theme\n'
            'Item {\n'
            '  Graphite.ActionButton { id: button; selected: true }\n'
            '  Graphite.Caption { id: caption }\n'
            '  Graphite.RadioSwitch { activeState: true }\n'
            '  Graphite.LevelSlider { label: "Test"; level: 50 }\n'
            '  Component.onCompleted: Qt.callLater(function() {\n'
            '    Qt.exit(Theme.accent === "'+fixture_accent+'" && button.background.color == "'+fixture_accent+'" && caption.color == Theme.foreground ? 0 : 1);\n'
            '  })\n}\n')
        env = {**os.environ, 'QT_QPA_PLATFORM':'offscreen', 'QT_QUICK_CONTROLS_STYLE':'Fusion',
               'XDG_CACHE_HOME':str(box/'cache'), 'XDG_RUNTIME_DIR':folder}
        result = subprocess.run([qml, str(script)], env=env, capture_output=True, text=True, timeout=10)
        assert result.returncode == 0, result.stdout + result.stderr
        assert 'Error:' not in result.stderr and 'ReferenceError' not in result.stderr, result.stderr
        print('PASS native Qt Quick: shared JS palette loads and recolors real button, caption, switch and slider components offscreen.')
    else:
        print('SKIP native Qt Quick palette imports: qml runtime unavailable.')
