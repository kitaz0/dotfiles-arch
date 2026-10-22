pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "PopupState.js" as PopupState

ColumnLayout {
    id: root
    property var displays: []
    property bool busy: false
    readonly property string currentMode: PopupState.displayMode(displays, reference.currentText)
    signal apply(string mode, string output)
    signal configure()
    spacing: 8
    function focusChoice(start, step) {
        for (let n = 0; n < choices.count; ++n) {
            const index = (start + n * step + choices.count * choices.count) % choices.count;
            const item = choices.itemAt(index);
            if (item && item.enabled) {
                item.forceActiveFocus(Qt.OtherFocusReason);
                return;
            }
        }
    }
    function focusInitialChoice() {
        if (root.visible && !root.busy) Qt.callLater(() => root.focusChoice(Math.max(0, ["right", "left", "mirror", "only", "other", "configure"].indexOf(root.currentMode)), 1));
    }
    onDisplaysChanged: focusInitialChoice()
    onVisibleChanged: root.focusInitialChoice()
    onBusyChanged: root.focusInitialChoice()
    Component.onCompleted: root.focusInitialChoice()
    Text {
        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#a89984"; font.pixelSize: 12
        text: root.displays.map(d => d.id + (d.disabled ? " (off)" : d.mirrorOf && d.mirrorOf !== "none" ? " (mirroring)" : " (active, " + d.x + "," + d.y + ")")).join("\n")
    }
    ComboBox {
        id: reference
        Layout.fillWidth: true
        model: root.displays
        textRole: "id"
        Accessible.name: "Reference display"
        onActivated: root.focusChoice(0, 1)
        palette.button: "#3c3836"; palette.buttonText: "#ebdbb2"; palette.base: "#3c3836"; palette.text: "#ebdbb2"; palette.highlight: "#b8bb26"; palette.highlightedText: "#282828"
    }
    GridLayout {
        columns: 3; columnSpacing: 8; rowSpacing: 8; Layout.fillWidth: true
        Repeater {
            id: choices
            model: [
                {mode:"right", title:"Extend right", hint:"Other display to the right", image:"extend.svg"},
                {mode:"left", title:"Extend left", hint:"Other display to the left", image:"extend.svg"},
                {mode:"mirror", title:"Mirror", hint:"Repeat the selected display", image:"mirror.svg"},
                {mode:"only", title:"Selected only", hint:"Turn off the other display", image:"single.svg"},
                {mode:"other", title:"Other only", hint:"Turn off the selected display", image:"external.svg"},
                {mode:"configure", title:"Arrange / modes", hint:"Open graphical arrangement", image:"arrange.svg"}
            ]
            delegate: Button {
                id: tile
                required property int index
                required property var modelData
                Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 88
                enabled: !root.busy && (modelData.mode === "configure" || root.displays.length === 2 && reference.currentIndex >= 0)
                opacity: enabled ? 1 : 0.4
                Accessible.name: modelData.title + ". " + modelData.hint
                background: Rectangle { radius: 9; color: tile.modelData.mode === root.currentMode ? "#504945" : "#3c3836"; border.width: tile.activeFocus ? 3 : 1; border.color: tile.activeFocus || tile.hovered ? "#b8bb26" : "#665c54" }
                contentItem: ColumnLayout {
                    Image { source: Qt.resolvedUrl(tile.modelData.image); Layout.fillWidth: true; Layout.preferredHeight: 46; fillMode: Image.PreserveAspectFit; mirror: tile.modelData.mode === "left" }
                    Text { text: tile.modelData.title; color: "#ebdbb2"; font.pixelSize: 13; Layout.alignment: Qt.AlignHCenter }
                }
                function activate() {
                    if (!tile.enabled) return;
                    if (tile.modelData.mode === "configure") root.configure();
                    else root.apply(tile.modelData.mode, reference.currentText);
                }
                Keys.onLeftPressed: root.focusChoice(tile.index - 1, -1)
                Keys.onRightPressed: root.focusChoice(tile.index + 1, 1)
                Keys.onUpPressed: root.focusChoice(tile.index - 3, -3)
                Keys.onDownPressed: root.focusChoice(tile.index + 3, 3)
                Keys.onReturnPressed: event => { if (!event.isAutoRepeat) tile.activate(); }
                Keys.onEnterPressed: event => { if (!event.isAutoRepeat) tile.activate(); }
                onClicked: tile.activate()
            }
        }
    }
    Text { text: "Arrows select · Enter or click activates · Escape cancels"; color: "#a89984"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
}
