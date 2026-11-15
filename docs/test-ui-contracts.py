"""Static safeguards for the reported UI regressions, not a QML runtime test."""
from pathlib import Path
import json, xml.etree.ElementTree as ET
root=Path(__file__).resolve().parent.parent
config=json.loads((root/'stow/desktop/.config/graphite/waybar/config.jsonc').read_text(encoding='utf-8'))
assert 'custom/quick-settings' not in config
assert set(['network','bluetooth','wireplumber','custom/brightness','custom/displays']) <= set(config['modules-right'])
assert config['modules-center']==['clock']
for module,page in [('network','wifi'),('bluetooth','bluetooth'),('wireplumber','audio'),('custom/brightness','brightness'),('custom/displays','displays')]:
    assert config[module]['on-click'].endswith('quick-settings.sh '+page)
assert '{essid}' in config['network']['tooltip-format-wifi']
assert '{bandwidthDownBytes}' in config['network']['tooltip-format-wifi']
assert config['clock']['locale']=='C' and '%m/%d/%Y' in config['clock']['format'] and '%I:%M %p' in config['clock']['format']
battery=config['battery']
assert len(set(battery['format-icons']))==5
assert '\u26a1' in battery['format-charging']
assert '\u2713' in battery['format-full']
for state in ['charging','full','plugged','not-charging']:
    assert '{icon}' in battery['format-'+state] and '{capacity}' in battery['format-'+state]
assert battery['justify']=='center' and battery['align']==0.5
assert 'hyprland/language' not in config['modules-right']
qml=(root/'stow/desktop/.config/graphite/quick-settings/shell.qml').read_text(encoding='utf-8')
assert qml.startswith('pragma ComponentBehavior: Bound\n')
assert 'id: action\n' not in qml and 'id: deviceAction' in qml
assert 'HyprlandFocusGrab' not in qml
assert 'margins.top: popup.barBottom' in qml
assert 'popup.primary ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None' in qml
assert 'acceptedButtons: Qt.AllButtons; onClicked: Qt.quit()' in qml
assert 'active: popup.primary' in qml and 'sourceComponent:' in qml
assert 'else if (receivedFocus) Qt.quit()' not in qml
assert 'if (code !== 0 || !root.geometryValid)' in qml
assert '"--skip-wait", "--subscribe"' in qml
assert 'target: "settings"' in qml and 'function toggle(' in qml
assert 'PwObjectTracker' in qml
brightness=(root/'stow/desktop/.config/graphite/quick-settings/BrightnessModel.qml').read_text()
assert 'FileView' in brightness and 'interval: 200' in brightness and 'blockLoading: true' not in brightness
assert 'loadPage' not in brightness and 'page' not in brightness
assert 'Layout.preferredHeight: 30' in qml
assert 'model: Pipewire.nodes' in (root/'stow/desktop/.config/graphite/quick-settings/AudioPage.qml').read_text()
assert not (root/'stow/desktop/.config/graphite/quick-settings/Overview.qml').exists()
assert 'Overview {' not in qml and 'text: "Back"' not in qml
assert 'NumberAnimation { id: pageFade; target: pageLoader;' in qml
assert 'onLoaded:' in qml and 'pageFade.restart()' in qml
assert 'tabButton' not in qml
assert '"Back to battery" : "Back to audio"' in qml
assert 'onClicked: root.navigate(root.page === "power-settings" ? "power" : "audio")' in qml
assert 'onOpenMixer: root.navigate("mixer")' in qml and 'AudioPage { streams: true }' in qml
assert 'Accessible.name: "Wi-Fi power"' in qml and 'Accessible.name: "Bluetooth power"' in qml
switch=(root/'stow/desktop/.config/graphite/quick-settings/RadioSwitch.qml').read_text(encoding='utf-8')
assert 'Switch {' in switch and 'checked = Qt.binding(() => control.activeState)' in switch
wifi=(root/'stow/desktop/.config/graphite/quick-settings/WifiPage.qml').read_text(encoding='utf-8')
assert 'delegate: RowLayout {\n                            id: networkRow' in wifi
assert 'Accessible.name: "Connected network"' in wifi
assert 'selected: networkRow.modelData.connected' not in wifi
bt=(root/'stow/desktop/.config/graphite/quick-settings/BluetoothPage.qml').read_text(encoding='utf-8')
assert 'RadioSwitch {' in bt and 'Bluetooth.adapters.values.length > 1' in bt
assert 'RowLayout {\n                                Layout.fillWidth: true\n                                ColumnLayout {' in bt
audio=(root/'stow/desktop/.config/graphite/quick-settings/AudioPage.qml').read_text(encoding='utf-8')
assert 'row.modelData.isStream === root.streams' in audio
assert '\n                        text: row.modelData.audio && row.modelData.audio.muted ? "Unmute"' not in audio
# The mute control and slider are siblings in one row, not stacked blocks.
start=audio.index('                RowLayout {')
end=audio.index('                RowLayout {',start+1)
assert 'onClicked: row.modelData.audio.muted' in audio[start:end] and 'LevelSlider {' in audio[start:end]
assert 'brightnessPage; BrightnessPage' in qml
brightness_page=(root/'stow/desktop/.config/graphite/quick-settings/BrightnessPage.qml').read_text()
assert 'root.model.edit(amount)' in brightness_page and 'root.model.release()' in brightness_page
assert config['modules-right'].count('custom/input-method')==1
assert config['tray']['ignore-list']==['Fcitx']
assert config['custom/input-method']['exec'].endswith('input-method.sh watch')
assert 'interval' not in config['custom/input-method']
assert config['custom/input-method']['exec-on-event'] is False
assert 'PreferTextIcon=True' in (root/'defaults/fcitx5/conf/classicui.conf').read_text()
bindings=(root/'stow/desktop/.config/graphite/hypr/graphite/bindings.lua').read_text()
assert 'script("SUPER + SHIFT + P", "quick-settings.sh", "displays",' in bindings
display=(root/'stow/desktop/.config/graphite/quick-settings/DisplayChoices.qml').read_text(encoding='utf-8')
assert 'selectedMode' not in display and 'Apply:' not in display
assert display.startswith('pragma ComponentBehavior: Bound\n')
assert 'required property int index' in display and 'required property var modelData' in display
assert 'onClicked: tile.activate()' in display
assert 'root.apply(tile.modelData.mode, reference.currentText)' in display
for key in ['Left', 'Right', 'Up', 'Down', 'Return', 'Enter']:
    assert 'Keys.on' + key + 'Pressed:' in display
assert 'item.enabled' in display and 'forceActiveFocus' in display
assert 'else if (root.page === "displays") Qt.quit();' in qml
for name in ['extend','mirror','single','external','arrange']:
    ET.parse(root/'stow/desktop/.config/graphite/quick-settings'/f'{name}.svg')
palette=json.loads((root/'stow/desktop/.local/share/graphite/palette.json').read_text())
assert all(role in palette for role in ['background','foreground','accent','secondary','tertiary'])
assert 'font: control.font' in (root/'stow/desktop/.config/graphite/quick-settings/ActionButton.qml').read_text()
print('PASS static UI contracts: direct settings icons, US clock, centered battery states, modal dismissal with accessible bar, same-window page transition, native audio, independent brightness, single input-mode indicator, visual monitors and Gruvbox palette.')
print('SKIP QML compilation/rendering and live input: these source assertions do not validate Qt imports, signals, focus or hardware behavior.')

assert "custom/clipboard" in config["modules-right"]
assert "clipboardPage; ClipboardPage" in qml
assert "WlrKeyboardFocus.Exclusive" not in qml

# Actual QML mistakes fixed independently of the narrow upstream metadata annotations.
clipboard=(root/'stow/desktop/.config/graphite/quick-settings/ClipboardPage.qml').read_text(encoding='utf-8')
assert 'currentItem.clicked()' not in clipboard and 'root.restoreEntry(entry.modelData.id)' in clipboard
assert 'root.restoreCurrent()' in clipboard and 'import Quickshell\n' not in clipboard
assert 'const pageItem = item as Item;' in qml and 'pageItem.forceActiveFocus()' in qml
assert r'\uf6a9' not in audio
for component in ['AudioPage.qml','BluetoothPage.qml','shell.qml']:
    source=(root/'stow/desktop/.config/graphite/quick-settings'/component).read_text(encoding='utf-8')
    assert source.count('// qmllint disable ') == source.count('// qmllint enable ')
    assert '// qmllint disable\n' not in source
