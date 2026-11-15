pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: root
    required property string helpers
    property var entries: []
    property string message: ""
    property bool confirmingClear: false
    spacing: 10
    function restoreEntry(entryId) {
        if (query.running || copyEntry.running || clearHistory.running || entryId === undefined) return;
        root.message = "";
        copyEntry.command = ["bash", root.helpers + "clipboard.sh", "restore", String(entryId)];
        copyEntry.running = true;
    }
    function restoreCurrent() {
        const entry = history.model[history.currentIndex];
        if (entry) root.restoreEntry(entry.id);
    }
    function refresh() {
        if (!query.running && !copyEntry.running && !clearHistory.running) {
            confirmingClear = false;
            message = "";
            query.running = true;
        }
    }
    Component.onCompleted: root.refresh()
    RowLayout {
        TextField {
            id: search
            Keys.onDownPressed: history.forceActiveFocus()
            Layout.fillWidth: true
            placeholderText: "Search clipboard history"
            Accessible.name: "Search clipboard history"
            color: "#ebdbb2"; placeholderTextColor: "#a89984"
            selectionColor: "#fe8019"; selectedTextColor: "#282828"
            background: Rectangle { color: "#3c3836"; radius: 7; border.color: search.activeFocus ? "#fe8019" : "#665c54" }
        }
        ActionButton { text: "Refresh"; enabled: !query.running && !copyEntry.running && !clearHistory.running; onClicked: root.refresh() }
    }
    Caption { text: root.message; visible: text !== ""; color: "#fb4934"; Layout.fillWidth: true }
    ListView {
        id: history
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; spacing: 6
        model: root.entries.filter(entry => entry.preview.toLowerCase().includes(search.text.toLowerCase()))
        ScrollBar.vertical: ScrollBar {}
        keyNavigationEnabled: true
        delegate: ActionButton {
            id: entry
            required property var modelData
            required property int index
            width: history.width
            text: entry.modelData.preview
            Accessible.name: "Copy " + entry.modelData.preview
            selected: history.currentIndex === entry.index
            enabled: !query.running && !copyEntry.running && !clearHistory.running
            onClicked: root.restoreEntry(entry.modelData.id)
        }
        Keys.onReturnPressed: event => { if (!event.isAutoRepeat) root.restoreCurrent(); }
        Keys.onEnterPressed: event => { if (!event.isAutoRepeat) root.restoreCurrent(); }
    }
    Caption { visible: !query.running && !clearHistory.running && history.count === 0; text: "No matching history entries."; Layout.fillWidth: true }
    RowLayout {
        ActionButton {
            text: root.confirmingClear ? "Confirm clear" : "Clear history"
            enabled: root.entries.length > 0 && !query.running && !copyEntry.running && !clearHistory.running
            onClicked: {
                if (root.confirmingClear) {
                    root.message = "";
                    clearHistory.running = true;
                } else {
                    root.confirmingClear = true;
                }
            }
        }
        ActionButton { text: "Cancel"; visible: root.confirmingClear; enabled: !clearHistory.running; onClicked: root.confirmingClear = false }
    }
    Caption { visible: root.confirmingClear; text: "Delete all saved history? Your current clipboard is kept."; color: "#a89984"; Layout.fillWidth: true }
    Caption { text: "Select to copy, then paste normally. Images are listed by their cliphist description."; color: "#a89984"; Layout.fillWidth: true }
    Process {
        id: query
        command: ["timeout", "3s", "bash", root.helpers + "clipboard.sh", "list-json"]
        stdout: StdioCollector { onStreamFinished: { try { root.entries = JSON.parse(text); } catch (e) { root.entries = []; root.message = "Cannot read clipboard history."; } } }
        onExited: (code, status) => { if (code !== 0) root.message = "Cannot read clipboard history; check cliphist and its database."; }
    }
    Process {
        id: copyEntry
        stderr: StdioCollector { id: copyError }
        onExited: (code, status) => { if (code === 0) Qt.quit(); else root.message = copyError.text.trim() || "Copy failed."; }
    }
    Process {
        id: clearHistory
        command: ["timeout", "3s", "bash", root.helpers + "clipboard.sh", "clear"]
        stderr: StdioCollector { id: clearError }
        onExited: (code, status) => {
            root.confirmingClear = false;
            if (code === 0) {
                root.entries = [];
                search.text = "";
                Qt.callLater(root.refresh);
            } else {
                root.message = clearError.text.trim() || "Cannot clear clipboard history.";
            }
        }
    }
}
