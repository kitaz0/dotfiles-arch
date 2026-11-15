pragma ComponentBehavior: Bound
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
        color: control.selected ? "#282828" : "#ebdbb2"
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }
    background: Rectangle {
        radius: 9
        color: control.selected ? "#fe8019" : control.down ? "#665c54" : control.hovered ? "#504945" : "#3c3836"
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? "#fe8019" : "#665c54"
    }
}
