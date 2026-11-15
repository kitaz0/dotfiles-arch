pragma ComponentBehavior: Bound
import "Theme.js" as Theme
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Stable control: dragging changes only the value, never its enclosing model.
RowLayout {
    id: control
    required property string label
    property real level: -1
    property int minimum: 0
    signal edited(int amount)
    signal released()
    spacing: 10
    Text { visible: control.label !== ""; text: control.label; color: Theme.foreground; font.family: "Noto Sans"; font.pixelSize: 13; Layout.preferredWidth: 78; elide: Text.ElideRight }
    Slider {
        id: slider
        implicitHeight: 34
        implicitWidth: 160
        Layout.fillWidth: true
        from: control.minimum; to: 100; stepSize: 1
        enabled: control.level >= 0
        Accessible.name: control.Accessible.name || control.label
        Binding { target: slider; property: "value"; value: Math.max(control.minimum, control.level); when: !slider.pressed }
        onMoved: control.edited(Math.round(value))
        onPressedChanged: if (!pressed) control.released()
        background: Rectangle {
            x: slider.leftPadding; y: (slider.height - height) / 2
            width: slider.availableWidth; height: 6; radius: 3; color: Theme.border
            Rectangle { width: slider.visualPosition * parent.width; height: 6; radius: 3; color: Theme.accent }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: (slider.height - height) / 2
            width: 18; height: 18; radius: 9; color: Theme.foreground
            border.width: slider.activeFocus ? 3 : 0; border.color: Theme.accent
        }
    }
    Text { text: control.level < 0 ? "—" : Math.round(slider.value) + "%"; color: Theme.foreground; font.pixelSize: 12; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
}
