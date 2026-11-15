pragma ComponentBehavior: Bound
import "Theme.js" as Theme
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking

ColumnLayout {
    id: root
    required property var devices
    property var passwordNetwork: null
    property string message: ""
    signal advanced()
    spacing: 10
    onVisibleChanged: { if (!visible) { passwordNetwork = null; password.clear(); } }
    Caption { text: !Networking.wifiHardwareEnabled ? "Hardware radio blocked" : !root.devices.length ? "No Wi-Fi device / NetworkManager unavailable" : Networking.wifiEnabled ? "Available networks" : "Wi-Fi is off"; color: Theme.muted; Layout.fillWidth: true }
    Caption { text: root.message; visible: text !== ""; color: Theme.red; Layout.fillWidth: true }
    ColumnLayout {
        visible: root.passwordNetwork !== null
        Layout.fillWidth: true
        Caption { text: root.passwordNetwork ? "Password for " + root.passwordNetwork.name : ""; Layout.fillWidth: true }
        TextField {
            id: password
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "Network password"
            selectByMouse: true
            color: Theme.foreground; placeholderTextColor: Theme.muted
            selectionColor: Theme.accent; selectedTextColor: Theme.background
            font.family: "Noto Sans"; font.pixelSize: 13
            padding: 10
            background: Rectangle { radius: 9; color: Theme.surface; border.color: password.activeFocus ? Theme.accent : Theme.border }
            Accessible.name: "Wi-Fi password"
            onAccepted: submit.clicked()
        }
        RowLayout {
            ActionButton {
                id: submit
                text: "Connect"; enabled: root.passwordNetwork !== null && password.text.length > 0
                onClicked: {
                    if (!enabled) return;
                    root.passwordNetwork.connectWithPsk(password.text);
                    password.clear();
                    root.passwordNetwork = null;
                }
            }
            ActionButton { text: "Cancel"; onClicked: { password.clear(); root.passwordNetwork = null; } }
        }
    }
    ScrollView {
        id: scroll
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth; spacing: 12
            Repeater {
                model: root.devices
                delegate: ColumnLayout {
                    id: adapter
                    required property var modelData
                    Layout.fillWidth: true
                    // Binding is restored when this page disappears; no background scanner.
                    Binding { target: adapter.modelData; property: "scannerEnabled"; value: root.visible && Networking.wifiEnabled }
                    Caption { text: adapter.modelData.name; font.bold: true; Layout.fillWidth: true }
                    Repeater {
                        model: adapter.modelData.networks
                        delegate: RowLayout {
                            id: networkRow
                            required property var modelData
                            Layout.fillWidth: true
                            Connections {
                                target: networkRow.modelData
                                function onConnectionFailed(reason) {
                                    if (reason === ConnectionFailReason.NoSecrets && [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].indexOf(networkRow.modelData.security) >= 0) {
                                        root.passwordNetwork = networkRow.modelData;
                                        root.message = "Enter the network password. NetworkManager manages saved credentials.";
                                        password.forceActiveFocus();
                                    } else root.message = "Connection failed: " + ConnectionFailReason.toString(reason) + ". Advanced setup supports enterprise certificates and hidden networks.";
                                }
                            }
                            Caption {
                                visible: networkRow.modelData.connected
                                text: "\u2713"; color: Theme.accent
                                Accessible.name: "Connected network"
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 2
                                Caption {
                                    text: networkRow.modelData.name
                                    font.bold: networkRow.modelData.connected
                                    Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight
                                }
                                Caption {
                                    text: Math.round(networkRow.modelData.signalStrength * 100) + "% \u00b7 " + WifiSecurityType.toString(networkRow.modelData.security)
                                    color: Theme.muted; font.pixelSize: 11
                                    Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight
                                }
                            }
                            ActionButton {
                                text: networkRow.modelData.stateChanging ? "Working..." : networkRow.modelData.connected ? "Disconnect" : "Connect"
                                enabled: Networking.wifiEnabled && !networkRow.modelData.stateChanging
                                onClicked: {
                                    root.message = "";
                                    if (networkRow.modelData.connected) networkRow.modelData.disconnect();
                                    else networkRow.modelData.connect();
                                }
                            }
                        }
                    }
                    Caption { visible: adapter.modelData.networks.values.length === 0; text: "No networks discovered yet." }
                }
            }
        }
    }
    ActionButton { text: "Enterprise / hidden network setup…"; Layout.fillWidth: true; onClicked: root.advanced() }
}
