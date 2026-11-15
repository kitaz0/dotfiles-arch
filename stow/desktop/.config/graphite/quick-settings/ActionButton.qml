pragma ComponentBehavior: Bound
import "Theme.js" as Theme
import QtQuick
import QtQuick.Controls

Button {
    id: control
    property bool selected: false
    implicitHeight: 40
    padding: 10
    font.family: "Noto Sans"
    font.pixelSize: 13
    opacity: enabled ? 1 : 0.45
    contentItem: Text {
        text: control.text
        color: control.selected ? Theme.background : Theme.foreground
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }
    background: Rectangle {
        radius: 9
        color: control.selected ? Theme.accent : control.down ? Theme.border : control.hovered ? Theme.elevated : Theme.surface
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Theme.border
    }
}
