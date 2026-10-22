pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    required property string helpers
    property var backlight: ({device: "", maximum: 0})
    property real level: -1
    property int pending: -1
    signal failed(string message)
    function edit(amount) { pending = amount; if (!throttle.running) throttle.start(); }
    function release() { throttle.stop(); send(); }
    function send() {
        if (writer.running || pending < 0) return;
        writer.command = ["timeout", "--kill-after=1s", "3s", "bash", helpers + "quick-settings-control.sh", "brightness", String(pending)];
        pending = -1;
        writer.running = true;
    }
    Process {
        command: ["bash", root.helpers + "quick-settings-control.sh", "backlight"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { root.backlight = JSON.parse(text); } catch (e) { root.level = -1; } } }
    }
    FileView {
        id: brightnessFile
        path: root.backlight.device ? "/sys/class/backlight/" + root.backlight.device + "/brightness" : ""
        printErrors: false
        onLoaded: {
            const raw = Number(text().trim());
            root.level = Number.isFinite(raw) && root.backlight.maximum > 0 ? Math.round(raw * 100 / root.backlight.maximum) : -1;
        }
        onLoadFailed: root.level = -1
    }
    Timer { interval: 200; running: root.backlight.device !== ""; repeat: true; onTriggered: brightnessFile.reload() }
    Timer { id: throttle; interval: 100; onTriggered: root.send() }
    Process {
        id: writer
        stdout: StdioCollector {}
        stderr: StdioCollector { id: errors }
        onExited: (code, status) => {
            if (code !== 0) root.failed(errors.text.trim() || "Brightness change failed.");
            brightnessFile.reload();
            if (root.pending >= 0) throttle.restart();
        }
    }
}
