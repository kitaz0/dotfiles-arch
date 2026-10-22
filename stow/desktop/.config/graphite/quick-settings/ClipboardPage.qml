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
    spacing: 10
    function restoreEntry(entryId) {
        if (copyEntry.running || entryId === undefined) return;
        root.message = "";
        copyEntry.command = ["bash", root.helpers + "clipboard.sh", "restore", String(entryId)];
        copyEntry.running = true;
    }
    function restoreCurrent() {
        const entry = history.model[history.currentIndex];
        if (entry) root.restoreEntry(entry.id);
    }
    function refresh() { if (!query.running) { message = ""; query.running = true; } }
    Component.onCompleted: root.refresh()
    RowLayout {
        TextField {
            id: search
            Keys.onDownPressed: history.forceActiveFocus()
            Layout.fillWidth: true
            placeholderText: "Search clipboard history"
            Accessible.name: "Search clipboard history"
            color: "#ebdbb2"; placeholderTextColor: "#a89984"
            selectionColor: "#b8bb26"; selectedTextColor: "#282828"
            background: Rectangle { color: "#3c3836"; radius: 7; border.color: search.activeFocus ? "#b8bb26" : "#665c54" }
        }
        ActionButton { text: "Refresh"; enabled: !query.running && !copyEntry.running; onClicked: root.refresh() }
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
            enabled: !copyEntry.running
            onClicked: root.restoreEntry(entry.modelData.id)
        }
        Keys.onReturnPressed: event => { if (!event.isAutoRepeat) root.restoreCurrent(); }
        Keys.onEnterPressed: event => { if (!event.isAutoRepeat) root.restoreCurrent(); }
    }
    Caption { visible: !query.running && history.count === 0; text: "No matching history entries."; Layout.fillWidth: true }
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
}
