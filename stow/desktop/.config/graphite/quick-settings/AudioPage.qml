pragma ComponentBehavior: Bound
import "Theme.js" as Theme
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire

ScrollView {
    id: root
    property bool streams: false
    signal openMixer()
    contentWidth: availableWidth
    clip: true
    ColumnLayout {
        width: root.availableWidth; spacing: 12
        ActionButton { visible: !root.streams; text: "Application mixer"; Layout.fillWidth: true; onClicked: root.openMixer() }
        Repeater {
            model: Pipewire.nodes
            delegate: ColumnLayout {
                id: row
                required property var modelData
                visible: row.modelData.audio !== null && row.modelData.isStream === root.streams
                Layout.fillWidth: true
                Caption {
                    text: (row.modelData.isStream ? (row.modelData.isSink ? "Recording · " : "Playback · ") : (row.modelData.isSink ? "Output · " : "Input · ")) + (row.modelData.description || row.modelData.name)
                    Layout.fillWidth: true
                    font.bold: !row.modelData.isStream
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    ActionButton {
                        text: {
                            const audio = row.modelData.audio;
                            if (audio && audio.muted) return "\udb81\udf5f";
                            // Match Waybar's three equal volume ranges (0–32, 33–65, 66+).
                            const volume = audio ? Math.round(audio.volume * 100) : 0;
                            return volume < 33 ? "\udb81\udd7f" : volume < 66 ? "\udb81\udd80" : "\udb81\udd7e";
                        }
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 20
                        implicitWidth: 44; implicitHeight: 44; padding: 4
                        Accessible.name: row.modelData.audio && row.modelData.audio.muted ? "Unmute" : "Mute"
                        ToolTip.visible: hovered; ToolTip.text: row.modelData.audio && row.modelData.audio.muted ? "Unmute" : "Mute"
                        selected: row.modelData.audio !== null && row.modelData.audio.muted
                        enabled: row.modelData.ready && row.modelData.audio !== null
                        onClicked: row.modelData.audio.muted = !row.modelData.audio.muted
                    }
                    LevelSlider {
                        label: ""; Layout.fillWidth: true
                        level: row.modelData.ready && row.modelData.audio ? Math.round(row.modelData.audio.volume * 100) : -1
                        onEdited: amount => { if (row.modelData.ready && row.modelData.audio) row.modelData.audio.volume = amount / 100; }
                        Accessible.name: (row.modelData.description || row.modelData.name) + " volume"
                    }
                }
                RowLayout {
                    ActionButton {
                        visible: !row.modelData.isStream
                        text: selected ? "Default device" : "Use by default"
                        selected: row.modelData === (row.modelData.isSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource)
                        enabled: row.modelData.ready && !selected
                        Layout.fillWidth: true
                        onClicked: {
                            if (row.modelData.isSink) Pipewire.preferredDefaultAudioSink = row.modelData;
                            else Pipewire.preferredDefaultAudioSource = row.modelData;
                        }
                    }
                }
                Caption { text: row.modelData.name; color: Theme.muted; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideMiddle; maximumLineCount: 1 }
                Rectangle { color: Theme.border; implicitHeight: 1; Layout.fillWidth: true }
            }
        }
        // Quickshell 0.3.2 runtime API; incomplete generated qmltypes.
        // qmllint disable missing-property
        Caption { visible: root.streams && Pipewire.ready && !Pipewire.nodes.values.some(n => n.audio !== null && n.isStream); text: "No active application audio streams."; Layout.fillWidth: true }
        // qmllint enable missing-property
        Caption { visible: !Pipewire.ready; text: "PipeWire is unavailable or connecting." }
        Caption { visible: !root.streams; text: "Default-device changes affect routing according to your audio session manager. Hardware profiles and custom routing remain available through pavucontrol."; Layout.fillWidth: true; color: Theme.muted }
    }
}
