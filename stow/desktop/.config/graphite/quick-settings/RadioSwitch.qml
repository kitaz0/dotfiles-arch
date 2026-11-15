pragma ComponentBehavior: Bound
import "Theme.js" as Theme
import QtQuick
import QtQuick.Controls

Switch {
    id: control
    required property bool activeState
    signal requested()
    checked: activeState
    implicitWidth: 52
    implicitHeight: 36
    padding: 4
    opacity: enabled ? 1 : 0.45
    onToggled: {
        // The backend remains authoritative, including when a request fails.
        checked = Qt.binding(() => control.activeState);
        control.requested();
    }
    indicator: Rectangle {
        implicitWidth: 44; implicitHeight: 24
        x: control.leftPadding; y: (control.height - height) / 2
        radius: 12
        color: control.activeState ? Theme.accent : Theme.elevated
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.foreground : Theme.border
        Rectangle {
            x: control.activeState ? 23 : 3; y: 3
            width: 18; height: 18; radius: 9
            color: control.activeState ? Theme.background : Theme.foreground
        }
    }
    contentItem: Item {}
}
