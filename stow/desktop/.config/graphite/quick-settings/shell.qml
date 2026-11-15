pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "PopupState.js" as PopupState

ShellRoot {
    id: root
    readonly property string helpers: Quickshell.env("HOME") + "/.local/lib/graphite/"
    property string page: PopupState.normalize(Quickshell.env("GRAPHITE_SETTINGS_PAGE") || "audio")
    property string message: ""
    property string outputName: ""
    property var barEdges: ({})
    property bool geometryReady: false
    property bool geometryValid: false
    property var displays: []
    readonly property bool busy: deviceAction.running
    // Quickshell 0.3.2 runtime API; incomplete generated qmltypes.
    // qmllint disable missing-property
    readonly property var wifiDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
    // qmllint enable missing-property
    // Quickshell 0.3.2 runtime API; incomplete generated qmltypes.
    // qmllint disable missing-property
    readonly property var singleAdapter: Bluetooth.adapters.values.length === 1 ? Bluetooth.adapters.values[0] : null
    // qmllint enable missing-property
    property alias brightness: brightnessModel
    // Quickshell 0.3.2 runtime API; incomplete generated qmltypes.
    // qmllint disable missing-property
    PwObjectTracker { objects: Pipewire.nodes.values }
    // qmllint enable missing-property
    BrightnessModel { id: brightnessModel; helpers: root.helpers; onFailed: text => root.message = text }
    function navigate(next) {
        page = PopupState.normalize(next);
        message = "";
        if (page === "displays" && !displayQuery.running) displayQuery.running = true;
    }
    function toggle(requested) {
        const next = PopupState.toggle(page, requested);
        if (!next) Qt.quit();
        else navigate(next);
    }
    function act(operation, argument, extra) {
        if (deviceAction.running) return;
        message = "";
        deviceAction.command = ["timeout", "--kill-after=1s", "25s", "bash", helpers + "quick-settings-control.sh", operation];
        if (argument !== undefined) deviceAction.command = deviceAction.command.concat([String(argument)]);
        if (extra !== undefined) deviceAction.command = deviceAction.command.concat([String(extra)]);
        deviceAction.running = true;
    }
    function launch(argv) { Quickshell.execDetached(argv); Qt.quit(); }
    IpcHandler {
        target: "settings"
        function toggle(requested: string): void { root.toggle(requested); }
        function close(): void { Qt.quit(); }
    }
    Component.onCompleted: {
        root.outputName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "");
        if (root.page === "displays") displayQuery.running = true;
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // Protocol events, not periodic guesses about focus or workspace state.
            if (["workspace", "workspacev2", "activespecial", "activespecialv2", "monitorremoved"].indexOf(event.name) >= 0) Qt.quit();
        }
    }
    Process {
        // Also coordinate notification-center opens initiated outside our bar.
        command: ["swaync-client", "--skip-wait", "--subscribe"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try { if (JSON.parse(line).visible === true) Qt.quit(); }
                catch (e) { /* Non-JSON diagnostics are not visibility events. */ }
            }
        }
    }
    Process {
        id: geometryQuery
        command: ["timeout", "2s", "hyprctl", "-j", "layers"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.barEdges = PopupState.barEdges(JSON.parse(text)); root.geometryValid = true; }
                catch (e) { console.error("Cannot inspect bar geometry:", e); }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 || !root.geometryValid) {
                console.error("Quick settings closed: hyprctl layers failed; refusing to cover the bar.");
                Qt.quit();
            } else root.geometryReady = true;
        }
    }
    Process {
        id: displayQuery
        command: ["bash", root.helpers + "quick-settings-control.sh", "displays"]
        stdout: StdioCollector { onStreamFinished: { try { root.displays = JSON.parse(text).items; } catch (e) { root.displays = []; } } }
        stderr: StdioCollector { id: displayErrors }
        onExited: (code, status) => { if (code !== 0) root.message = displayErrors.text.trim() || "Display query failed"; }
    }
    Process {
        id: deviceAction
        stdout: StdioCollector {}
        stderr: StdioCollector { id: actionErrors }
        onExited: (code, status) => {
            if (code !== 0) root.message = actionErrors.text.trim() || "The operation failed. Check the service, device or authorization.";
            else if (root.page === "displays") Qt.quit();
        }
    }
    Variants {
        model: Quickshell.screens
        // Quickshell 0.3.2 runtime API; incomplete generated qmltypes.
        // qmllint disable uncreatable-type
        PanelWindow {
        // qmllint enable uncreatable-type
            id: popup
            required property var modelData
            screen: modelData
            readonly property bool primary: popup.modelData.name === root.outputName
            readonly property int barBottom: root.barEdges[popup.modelData.name] || 0
            visible: root.geometryReady
            anchors { top: true; bottom: true; left: true; right: true }
            // Quickshell 0.3.2 runtime API; incomplete generated qmltypes.
            // qmllint disable missing-property
            margins.top: popup.barBottom
            // qmllint enable missing-property
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "graphite-quick-settings"
            WlrLayershell.layer: WlrLayer.Overlay
            // OnDemand preserves keyboard controls without Hyprland exclusive-layer pointer capture.
            // The bar is outside its geometry, so triggers remain clickable.
            WlrLayershell.keyboardFocus: popup.primary ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            Shortcut { enabled: popup.primary; sequence: "Escape"; onActivated: Qt.quit() }
            // Consume the complete dismissal click. Do not forward it to an app.
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: Qt.quit() }
            Rectangle {
                id: card
                visible: popup.primary
                width: Math.min(root.page === "displays" ? 640 : 420, popup.width - 24)
                height: Math.min(root.page === "displays" ? 430 : 600, popup.height - 24)
                x: root.page === "displays" ? (popup.width - width) / 2 : popup.width - width - 12
                y: root.page === "displays" ? Math.max(12, (popup.height + popup.barBottom - height) / 2 - popup.barBottom) : 12
                radius: 14; color: "#282828"; border.color: "#665c54"
                // Empty space inside the card must not reach the backdrop.
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 12
                    RowLayout {
                        ActionButton {
                            visible: root.page === "mixer" || root.page === "power-settings"
                            text: "\uf060"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                            Accessible.name: root.page === "power-settings" ? "Back to battery" : "Back to audio"
                            ToolTip.visible: hovered; ToolTip.text: root.page === "power-settings" ? "Back to battery" : "Back to audio"
                            onClicked: root.navigate(root.page === "power-settings" ? "power" : "audio")
                        }
                        Caption { text: root.page === "wifi" ? "Wi-Fi" : root.page === "bluetooth" ? "Bluetooth" : root.page === "audio" ? "Audio" : root.page === "mixer" ? "Application mixer" : root.page === "brightness" ? "Brightness" : root.page === "clipboard" ? "Clipboard" : root.page === "power" ? "Battery and power" : root.page === "power-settings" ? "Power settings" : "Display arrangement"; font.pixelSize: 18; font.bold: true; Layout.fillWidth: true }
                        RadioSwitch {
                            visible: root.page === "wifi"
                            activeState: Networking.wifiEnabled
                            enabled: root.wifiDevices.length > 0 && Networking.wifiHardwareEnabled && !root.busy
                            Accessible.name: "Wi-Fi power"
                            onRequested: root.act("wifi-power", Networking.wifiEnabled ? "off" : "on")
                        }
                        RadioSwitch {
                            // Quickshell 0.3.2 runtime API; incomplete generated qmltypes.
                            // qmllint disable missing-property
                            visible: root.page === "bluetooth" && Bluetooth.adapters.values.length <= 1
                            // qmllint enable missing-property
                            activeState: root.singleAdapter !== null && root.singleAdapter.enabled
                            enabled: root.singleAdapter !== null && !root.busy
                            Accessible.name: "Bluetooth power"
                            onRequested: { if (root.singleAdapter) root.act("bt-operation", root.singleAdapter.enabled ? "off" : "on", root.singleAdapter.dbusPath); }
                        }
                        ActionButton { visible: root.page !== "wifi" && root.page !== "bluetooth"; text: "Close"; onClicked: Qt.quit() }
                    }
                    Loader {
                        id: pageLoader
                        active: popup.primary
                        Layout.fillWidth: true; Layout.fillHeight: true
                        // Page changes replace content, never the window. Live values do not reload it.
                        sourceComponent: root.page === "wifi" ? wifiPage : root.page === "bluetooth" ? bluetoothPage : root.page === "audio" ? audioPage : root.page === "mixer" ? mixerPage : root.page === "brightness" ? brightnessPage : root.page === "clipboard" ? clipboardPage : root.page === "power" ? powerPage : root.page === "power-settings" ? powerSettingsPage : displayPage
                        onLoaded: {
                            pageFade.restart();
                            const pageItem = item as Item;
                            if (pageItem && root.page !== "displays") pageItem.forceActiveFocus();
                        }
                        NumberAnimation { id: pageFade; target: pageLoader; property: "opacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
                        Component { id: clipboardPage; ClipboardPage { helpers: root.helpers } }
                        Component { id: powerPage; PowerPage { helpers: root.helpers; onOpenSettings: root.navigate("power-settings") } }
                        Component { id: powerSettingsPage; PowerSettingsPage { helpers: root.helpers } }
                        Component { id: brightnessPage; BrightnessPage { model: root.brightness; helpers: root.helpers } }
                        Component { id: wifiPage; WifiPage { devices: root.wifiDevices; onAdvanced: root.launch(["bash", root.helpers + "terminal.sh", "-e", "nmtui"]) } }
                        Component { id: bluetoothPage; BluetoothPage { busy: root.busy; onOperation: (method, path) => root.act("bt-operation", method, path); onPairDevice: address => root.launch(["bluedevil-wizard"]) } }
                        Component { id: audioPage; AudioPage { onOpenMixer: root.navigate("mixer") } }
                        Component { id: mixerPage; AudioPage { streams: true } }
                        Component { id: displayPage; DisplayChoices { displays: root.displays; busy: root.busy || displayQuery.running; onApply: (mode, output) => root.act("display-" + mode, output); onConfigure: root.launch(["wdisplays"]) } }
                    }
                    Caption { text: root.message || (root.busy ? "Applying..." : ""); color: "#fb4934"; Layout.fillWidth: true; Layout.preferredHeight: 30; maximumLineCount: 2; elide: Text.ElideRight }
                }
            }
        }
    }
}
