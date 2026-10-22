pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Bluetooth

ColumnLayout {
    id: root
    property bool busy: false
    signal operation(string method, string path)
    signal pairDevice(string address)
    spacing: 10
    // Quickshell 0.3.2 runtime API; incomplete generated qmltypes.
    // qmllint disable missing-property
    Caption { visible: Bluetooth.adapters.values.length === 0; text: "No Bluetooth adapter. Check the existing BlueZ service and hardware radio switch."; Layout.fillWidth: true }
    // qmllint enable missing-property
    ScrollView {
        id: scroll
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth; spacing: 12
            Repeater {
                model: Bluetooth.adapters
                delegate: ColumnLayout {
                    id: adapter
                    required property var modelData
                    property bool ownsScan: false
                    Layout.fillWidth: true
                    function stopScan() {
                        if (ownsScan) { modelData.discovering = false; ownsScan = false; }
                    }
                    Connections { target: root; function onVisibleChanged() { if (!root.visible) adapter.stopScan(); } }
                    Component.onDestruction: stopScan()
                    RowLayout {
                        Caption { text: adapter.modelData.name; font.bold: true; Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight }
                        RadioSwitch {
                            // Quickshell 0.3.2 runtime API; incomplete generated qmltypes.
                            // qmllint disable missing-property
                            visible: Bluetooth.adapters.values.length > 1
                            // qmllint enable missing-property
                            activeState: adapter.modelData.enabled
                            enabled: !root.busy
                            Accessible.name: adapter.modelData.name + " power"
                            onRequested: root.operation(adapter.modelData.enabled ? "off" : "on", adapter.modelData.dbusPath)
                        }
                        ActionButton {
                            text: adapter.modelData.discovering ? "Stop scan" : "Scan"
                            enabled: adapter.modelData.enabled && !root.busy && (!adapter.modelData.discovering || adapter.ownsScan)
                            onClicked: {
                                if (adapter.modelData.discovering) adapter.stopScan();
                                else { adapter.ownsScan = true; adapter.modelData.discovering = true; }
                            }
                        }
                    }
                    Caption { visible: adapter.modelData.discovering; text: adapter.ownsScan ? "Scanning for nearby devices…" : "Another application is scanning."; color: "#a89984" }
                    Repeater {
                        model: adapter.modelData.devices
                        delegate: ColumnLayout {
                            id: device
                            required property var modelData
                            property bool confirmRemoval: false
                            Layout.fillWidth: true
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 2
                                    Caption { text: device.modelData.name; font.bold: device.modelData.connected; Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight }
                                    Caption {
                                        text: (device.modelData.blocked ? "Blocked" : device.modelData.connected ? "Connected" : device.modelData.paired ? "Paired" : "Available") + (device.modelData.batteryAvailable ? " \u00b7 " + Math.round(device.modelData.battery * 100) + "%" : "")
                                        color: "#a89984"; font.pixelSize: 11; Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight
                                    }
                                    Caption { text: device.modelData.address; color: "#a89984"; font.pixelSize: 10; Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight }
                                }
                                ActionButton {
                                    text: device.modelData.connected ? "Disconnect" : device.modelData.paired ? "Connect" : "Pair…"
                                    enabled: adapter.modelData.enabled && !device.modelData.blocked && !root.busy
                                    onClicked: {
                                        if (!device.modelData.paired) root.pairDevice(device.modelData.address);
                                        else root.operation(device.modelData.connected ? "disconnect" : "connect", device.modelData.dbusPath);
                                    }
                                }
                                ActionButton {
                                    visible: device.modelData.paired
                                    text: device.confirmRemoval ? "\uf00c" : "\uf1f8"
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                                    Accessible.name: device.confirmRemoval ? "Confirm forget device" : "Forget device"
                                    ToolTip.visible: hovered; ToolTip.text: device.confirmRemoval ? "Confirm forget" : "Forget device"
                                    enabled: !root.busy
                                    onClicked: {
                                        if (device.confirmRemoval) root.operation("forget", device.modelData.dbusPath);
                                        else device.confirmRemoval = true;
                                    }
                                }
                            }
                            Rectangle { color: "#665c54"; implicitHeight: 1; Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }
    Caption { text: "Pairing opens the existing BlueDevil authentication wizard. The popup closes first so PIN and confirmation prompts can receive focus."; color: "#a89984"; Layout.fillWidth: true }
}
