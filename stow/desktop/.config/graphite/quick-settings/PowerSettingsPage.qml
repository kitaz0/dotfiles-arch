pragma ComponentBehavior: Bound
import "Theme.js" as Theme
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.UPower

ColumnLayout {
    id: root
    required property string helpers
    property bool hasBattery: UPower.displayDevice.ready && UPower.displayDevice.isPresent
    property string source: UPower.onBattery ? "battery" : "mains"
    property var preferences: null
    property var saved: null
    property bool loadingDefaults: false
    property string message: ""
    property bool failed: false
    readonly property bool busy: loader.running || saver.running
    readonly property bool dirty: preferences !== null && JSON.stringify(preferences) !== JSON.stringify(saved)
    readonly property var delays: [
        { text: "Never", seconds: 0 }, { text: "1 minute", seconds: 60 },
        { text: "2 minutes", seconds: 120 }, { text: "3 minutes", seconds: 180 },
        { text: "5 minutes", seconds: 300 }, { text: "7 minutes", seconds: 420 },
        { text: "10 minutes", seconds: 600 }, { text: "15 minutes", seconds: 900 },
        { text: "30 minutes", seconds: 1800 }, { text: "45 minutes", seconds: 2700 },
        { text: "1 hour", seconds: 3600 }, { text: "2 hours", seconds: 7200 }
    ]
    spacing: 12
    function edit(key, value) {
        if (!root.preferences) return;
        const next = JSON.parse(JSON.stringify(root.preferences));
        if (key === "lockBeforeSleep") next.lockBeforeSleep = value;
        else next[root.source][key] = value;
        root.preferences = next;
        root.message = "";
        root.failed = false;
    }
    function loadDefaults() {
        root.loadingDefaults = true;
        loader.command = ["bash", root.helpers + "power-policy.sh", "defaults"];
        loader.running = true;
    }
    function save() {
        root.message = "";
        saver.command = ["timeout", "10s", "bash", root.helpers + "power-policy.sh", "save", JSON.stringify(root.preferences)];
        saver.running = true;
    }
    Component.onCompleted: loader.running = true
    RowLayout {
        Layout.fillWidth: true
        ActionButton { text: "On battery"; visible: root.hasBattery; selected: root.source === "battery"; enabled: !root.busy; Layout.fillWidth: true; onClicked: root.source = "battery" }
        ActionButton { text: root.hasBattery ? "Plugged in" : "Desktop"; selected: root.source === "mains"; enabled: !root.busy; Layout.fillWidth: true; onClicked: root.source = "mains" }
    }
    Caption {
        text: "Delays start from your last activity. Screen off leaves the computer running; suspend puts it to sleep."
        color: Theme.muted; Layout.fillWidth: true
    }
    Repeater {
        model: [ { label: "Lock screen after", key: "lock" }, { label: "Screen off after", key: "screenOff" }, { label: "Suspend after", key: "suspend" } ]
        delegate: RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            Caption { text: row.modelData.label; Layout.fillWidth: true }
            ComboBox {
                id: choice
                Layout.preferredWidth: 142
                implicitHeight: 40
                enabled: root.preferences !== null && !root.busy
                model: root.delays
                textRole: "text"; valueRole: "seconds"
                currentIndex: root.preferences ? root.delays.findIndex(d => d.seconds === root.preferences[root.source][row.modelData.key]) : 0
                onActivated: root.edit(row.modelData.key, currentValue)
                Accessible.name: row.modelData.label
                palette.window: Theme.surface; palette.base: Theme.background; palette.text: Theme.foreground
                palette.button: Theme.surface; palette.buttonText: Theme.foreground; palette.windowText: Theme.foreground
                palette.highlight: Theme.accent; palette.highlightedText: Theme.background; palette.mid: Theme.border
                font.family: "Noto Sans"; font.pixelSize: 13
                background: Rectangle { radius: 9; color: choice.down ? Theme.border : choice.hovered ? Theme.elevated : Theme.surface; border.color: choice.activeFocus ? Theme.accent : Theme.border }
            }
        }
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
    RowLayout {
        Layout.fillWidth: true
        Caption { text: "Lock before suspend"; Layout.fillWidth: true }
        RadioSwitch {
            activeState: root.preferences ? root.preferences.lockBeforeSleep : true
            enabled: root.preferences !== null && !root.busy
            Accessible.name: "Lock before suspend"
            onRequested: root.edit("lockBeforeSleep", !activeState)
        }
    }
    Caption { text: "Applies to both power sources, including lid-close suspend. Manual locking stays available."; color: Theme.muted; Layout.fillWidth: true }
    Item { Layout.fillHeight: true }
    Caption {
        text: root.message || (root.dirty ? "Unsaved changes" : "Applies only in Graphite.")
        color: root.failed ? Theme.red : Theme.muted; Layout.fillWidth: true
    }
    RowLayout {
        Layout.fillWidth: true
        ActionButton { text: "Defaults"; enabled: !root.busy; Layout.fillWidth: true; onClicked: root.loadDefaults() }
        ActionButton { text: root.busy ? "Applying…" : "Apply"; selected: root.dirty; enabled: root.dirty && !root.busy; Layout.fillWidth: true; onClicked: root.save() }
    }
    Process {
        id: loader
        command: ["bash", root.helpers + "power-policy.sh", "settings"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root.preferences = parsed;
                    root.message = ""; root.failed = false;
                    if (root.saved === null && !root.loadingDefaults) root.saved = JSON.parse(JSON.stringify(parsed));
                } catch (e) { root.message = "Cannot read power settings."; root.failed = true; }
            }
        }
        stderr: StdioCollector { id: loadErrors }
        onExited: (code, status) => {
            if (code !== 0) { root.message = loadErrors.text.trim() || "Cannot read power settings."; root.failed = true; }
        }
    }
    Process {
        id: saver
        stderr: StdioCollector { id: saveErrors }
        onExited: (code, status) => {
            root.failed = code !== 0;
            if (code === 0) { root.saved = JSON.parse(JSON.stringify(root.preferences)); root.message = "Saved"; }
            else root.message = saveErrors.text.trim() || "Cannot apply power settings.";
        }
    }
}
