pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var model
    required property string helpers
    spacing: 16
    Caption { text: "Laptop backlight"; font.bold: true }
    LevelSlider {
        label: "Brightness"; Layout.fillWidth: true; minimum: 5
        level: root.model.level
        onEdited: amount => root.model.edit(amount)
        onReleased: root.model.release()
    }
    Caption {
        text: root.model.level < 0 ? "No accessible laptop backlight. External displays usually use their own brightness controls." : "Function-key changes update this slider automatically. External display brightness is controlled separately."
        color: "#a89984"; Layout.fillWidth: true
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#665c54" }
    NightLightControls { helpers: root.helpers; Layout.fillWidth: true }
    Item { Layout.fillHeight: true }
}
