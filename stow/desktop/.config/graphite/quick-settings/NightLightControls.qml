pragma ComponentBehavior: Bound
import "Theme.js" as Theme
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: root
    required property string helpers
    property var snapshot: ({ installed: false, available: false, enabled: false, temperature: 4500 })
    property int pendingTemperature: -1
    property string message: ""
    readonly property bool busy: writer.running
    spacing: 10
    function refresh() { if (!query.running && !root.busy) query.running = true; }
    function act(operation, value) {
        if (root.busy) return;
        root.message = "";
        writer.command = ["timeout", "15s", "bash", root.helpers + "night-light.sh", operation];
        if (value !== undefined) writer.command = writer.command.concat([String(value)]);
        writer.running = true;
    }
    Component.onCompleted: root.refresh()
    Timer { interval: 1500; running: true; repeat: true; onTriggered: root.refresh() }
    RowLayout {
        Caption { text: "Night Light"; font.bold: true; Layout.fillWidth: true }
        RadioSwitch {
            activeState: root.snapshot.enabled
            enabled: root.snapshot.installed && !root.busy
            Accessible.name: "Night Light"
            onRequested: root.act(root.snapshot.enabled ? "off" : "on")
        }
    }
    Caption {
        text: !root.snapshot.installed ? "Install Hyprsunset to use warmer screen colors."
            : root.snapshot.enabled ? "Warmer screen colors reduce blue light." : "Off · screen colors are unchanged."
        color: Theme.muted; Layout.fillWidth: true
    }
    LevelSlider {
        label: "Warmth"; Layout.fillWidth: true
        level: root.snapshot.available ? Math.max(0, Math.min(100, (6500 - root.snapshot.temperature) / 40)) : -1
        enabled: root.snapshot.enabled && !root.busy
        onEdited: amount => root.pendingTemperature = 6500 - amount * 40
        onReleased: {
            if (root.pendingTemperature >= 2500) root.act("temperature", root.pendingTemperature);
            root.pendingTemperature = -1;
        }
        Accessible.name: "Night Light warmth"
    }
    Caption { visible: root.snapshot.available; text: root.snapshot.temperature + " K · lower is warmer"; color: Theme.muted; Layout.fillWidth: true }
    Caption { visible: root.message !== ""; text: root.message; color: Theme.red; Layout.fillWidth: true }
    Process {
        id: query
        command: ["timeout", "4s", "bash", root.helpers + "night-light.sh", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.snapshot = JSON.parse(text); }
                catch (e) { root.snapshot = { installed: false, available: false, enabled: false, temperature: 4500 }; }
            }
        }
    }
    Process {
        id: writer
        stderr: StdioCollector { id: errors }
        onExited: (code, status) => {
            if (code !== 0) root.message = errors.text.trim() || "Night Light change failed.";
            Qt.callLater(root.refresh);
        }
    }
}
