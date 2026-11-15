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
    signal openSettings()
    property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery.ready && battery.isPresent
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
    readonly property bool busy: profileAction.running || queuedProfile !== ""
    property string queuedProfile: ""
    property string activeProfile: ""
    property var profiles: []
    property bool profilesLoaded: false
    property string message: ""
    spacing: 12
    function duration(seconds) {
        if (!Number.isFinite(seconds) || seconds <= 0) return "Estimating…";
        const minutes = Math.ceil(seconds / 60);
        return Math.floor(minutes / 60) + "h " + (minutes % 60) + "m";
    }
    function refresh() { if (!profileQuery.running && !root.busy) profileQuery.running = true; }
    function setProfile(profile) {
        if (root.busy) return;
        if (profileQuery.running) { root.queuedProfile = profile; return; }
        root.message = "";
        profileAction.command = ["timeout", "7s", "bash", root.helpers + "quick-settings-control.sh", "power-profile", profile];
        profileAction.running = true;
    }
    Component.onCompleted: root.refresh()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refresh() }
    Caption {
        text: root.hasBattery ? Math.round(root.battery.percentage * 100) + "%" : "Battery information unavailable"
        font.pixelSize: root.hasBattery ? 32 : 16
        Layout.fillWidth: true
    }
    ProgressBar {
        id: chargeBar
        visible: root.hasBattery
        Layout.fillWidth: true
        from: 0; to: 1; value: root.hasBattery ? root.battery.percentage : 0
        background: Rectangle { implicitHeight: 8; radius: 4; color: Theme.surface }
        contentItem: Item {
            implicitHeight: 8
            Rectangle { width: parent.width * chargeBar.visualPosition; height: parent.height; radius: 4; color: Theme.green }
        }
    }
    Caption {
        visible: root.hasBattery
        text: !root.hasBattery ? "" : root.battery.state === UPowerDeviceState.FullyCharged ? "Fully charged"
            : root.charging ? "Charging · " + root.duration(root.battery.timeToFull) + " until full"
            : root.battery.state === UPowerDeviceState.Discharging ? "On battery · " + root.duration(root.battery.timeToEmpty) + " remaining"
            : root.battery.state === UPowerDeviceState.Empty ? "Battery empty"
            : root.battery.state === UPowerDeviceState.PendingCharge ? "Connected · waiting to charge"
            : root.battery.state === UPowerDeviceState.PendingDischarge ? "Waiting to discharge" : "Battery status unavailable"
        Layout.fillWidth: true
    }
    Caption {
        visible: root.hasBattery && Math.abs(root.battery.changeRate) > 0
        text: (root.charging ? "Charging power: " : "Power consumption: ") + Math.abs(root.battery.changeRate).toFixed(1) + " W"
        color: Theme.muted; Layout.fillWidth: true
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
    Caption { text: "Power mode"; font.bold: true }
    Repeater {
        model: root.profiles
        delegate: ActionButton {
            required property string modelData
            text: modelData === "power-saver" ? "Power saving" : modelData === "balanced" ? "Balanced" : "Performance"
            selected: root.activeProfile === modelData
            enabled: !root.busy
            Layout.fillWidth: true
            onClicked: root.setProfile(modelData)
        }
    }
    Caption { visible: root.profilesLoaded && !root.busy && root.profiles.length === 0; text: "No active power profile service is available."; color: Theme.muted; Layout.fillWidth: true }
    Caption { visible: root.message !== ""; text: root.message; color: Theme.red; Layout.fillWidth: true }
    Item { Layout.fillHeight: true }
    ActionButton { text: "Settings"; Layout.fillWidth: true; onClicked: root.openSettings() }
    Process {
        id: profileQuery
        command: ["timeout", "7s", "bash", root.helpers + "quick-settings-control.sh", "power-profiles"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(text);
                    root.activeProfile = next.active;
                    // Preserve delegates, hover and focus when only the active mode changes.
                    if (JSON.stringify(root.profiles) !== JSON.stringify(next.profiles)) root.profiles = next.profiles;
                } catch (e) { root.message = "Cannot read power profiles."; }
            }
        }
        stderr: StdioCollector { id: queryErrors }
        onExited: (code, status) => {
            root.profilesLoaded = true;
            if (code !== 0) root.message = queryErrors.text.trim() || "Cannot read power profiles.";
            // A click during a read is applied as soon as that read finishes.
            if (root.queuedProfile !== "") Qt.callLater(() => {
                const profile = root.queuedProfile;
                root.queuedProfile = "";
                root.setProfile(profile);
            });
        }
    }
    Process {
        id: profileAction
        stderr: StdioCollector { id: profileErrors }
        onExited: (code, status) => {
            if (code !== 0) root.message = profileErrors.text.trim() || "Cannot change the power profile.";
            Qt.callLater(root.refresh);
        }
    }
}
