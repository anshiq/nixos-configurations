// Capture: screenshot, colour picker and screen recording, plus the keybinds
// that do the same without opening this window.
//
// All three go through the desktop's own commands (`screenshot`,
// `hyprpicker`, `screen-record`), so this page and the keybinds behave alike.
// Screenshot and colour picker hide this window first so it is not in the
// shot, and bring it back when the tool exits. Recording state is followed
// through screen-record's pidfile (inotify, no polling).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Page {
    id: page
    title: "Capture"
    subtitle: recording ? "Recording…" : "Screenshots, colours and screen recordings"

    // Set by shell.qml so the page can step out of its own screenshots.
    property var hostWindow: null

    readonly property string home: Quickshell.env("HOME")
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || `/run/user/${Quickshell.env("UID")}`
    readonly property string recordingsDir: home + "/Videos/Recordings"

    property bool recording: false
    property string recordFile: ""
    property string pickedColor: ""
    property string errorMessage: ""
    property string pendingTool: "" // "screenshot" | "picker" while the window is hidden

    function fail(what, code, err) {
        page.errorMessage = code === 127 ? `The ${err.split(":")[0].trim()} command is not installed.` : (err.trim() || `${what} failed (exit code ${code}).`);
    }

    function baseName(p) {
        return p.split("/").pop();
    }

    // Hide, give the compositor a moment to unmap the window, then run.
    function runHidden(tool) {
        if (page.pendingTool !== "")
            return;
        page.errorMessage = "";
        page.pendingTool = tool;
        if (page.hostWindow)
            page.hostWindow.visible = false;
        hideDelay.restart();
    }

    function restoreWindow() {
        page.pendingTool = "";
        if (page.hostWindow)
            page.hostWindow.visible = true;
    }

    function refreshStatus() {
        statusCmd.run(["screen-record", "status", "--json"]);
    }

    Timer {
        id: hideDelay
        interval: 300
        onTriggered: {
            if (page.pendingTool === "screenshot")
                shotCmd.run(["screenshot"]);
            else
                pickCmd.run(["hyprpicker", "-a"]);
        }
    }

    Cmd {
        id: shotCmd
        onFinished: (code, out, err) => {
            page.restoreWindow();
            if (code !== 0)
                page.fail("Screenshot", code, err);
        }
    }

    // hyprpicker -a copies the colour and prints it; empty output = cancelled.
    Cmd {
        id: pickCmd
        onFinished: (code, out, err) => {
            page.restoreWindow();
            if (code !== 0)
                page.fail("Colour picker", code, err);
            else if (out.trim() !== "")
                page.pickedColor = out.trim().split("\n").pop();
        }
    }

    Cmd {
        id: statusCmd
        onFinished: (code, out, err) => {
            if (code === 127) {
                page.recording = false;
                page.fail("screen-record", code, err);
                return;
            }
            try {
                const s = JSON.parse(out);
                page.recording = !!s.recording;
                page.recordFile = s.file || "";
            } catch (e) {
                page.recording = false;
            }
        }
    }

    // Separate start/stop commands: stopping must work even if `start`
    // has not returned yet.
    Cmd {
        id: startCmd
        onFinished: (code, out, err) => {
            if (code !== 0)
                page.fail("Screen recording", code, err);
            page.refreshStatus();
        }
    }
    Cmd {
        id: stopCmd
        onFinished: (code, out, err) => {
            if (code !== 0)
                page.fail("Stopping the recording", code, err);
            page.refreshStatus();
        }
    }

    // screen-record writes this pidfile while recording and removes it on
    // stop, so recordings started or stopped from a keybind show up here.
    // The initial load (or failure) also does the first status read.
    FileView {
        path: `${page.runtimeDir}/screen-record.pid`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: page.refreshStatus()
        onLoadFailed: page.refreshStatus()
    }

    Banner {
        text: page.errorMessage
        kind: "error"
    }

    SectionLabel {
        text: "Screenshot"
    }
    Card {
        SettingRow {
            first: true
            icon: Icons.camera
            title: "Take a screenshot"
            subtitle: "Select an area, then annotate, copy or save it. This window hides while you capture."
            Btn {
                text: "Capture"
                kind: "primary"
                busy: page.pendingTool === "screenshot"
                enabled: page.pendingTool === ""
                onClicked: page.runHidden("screenshot")
            }
        }
        SettingRow {
            icon: Icons.eyedropper
            title: "Pick a colour"
            subtitle: page.pickedColor !== "" ? `Copied ${page.pickedColor} to the clipboard` : "Click anywhere on screen to copy that colour's hex code."
            Rectangle {
                visible: page.pickedColor !== ""
                implicitWidth: 26
                implicitHeight: 26
                radius: 13
                color: page.pickedColor !== "" ? page.pickedColor : "transparent"
                border.width: 1
                border.color: Theme.border
            }
            Btn {
                text: "Pick"
                busy: page.pendingTool === "picker"
                enabled: page.pendingTool === ""
                onClicked: page.runHidden("picker")
            }
        }
    }

    SectionLabel {
        text: "Screen recording"
    }
    Card {
        SettingRow {
            first: true
            icon: page.recording ? Icons.stop : Icons.record
            iconColor: page.recording ? Theme.danger : Theme.foreground
            title: page.recording ? "Recording" : "Not recording"
            subtitle: page.recording ? (page.recordFile !== "" ? `Saving to ${page.baseName(page.recordFile)}. Keeps going if you close this window.` : "Keeps going if you close this window.") : "Full screen or a selected region, saved to ~/Videos/Recordings."
            Badge {
                visible: page.recording
                text: "REC"
                tone: "accent"
            }
            Btn {
                visible: page.recording
                text: "Stop"
                icon: Icons.stop
                kind: "danger"
                busy: stopCmd.running
                onClicked: {
                    page.errorMessage = "";
                    stopCmd.run(["screen-record", "stop"]);
                }
            }
            Btn {
                visible: !page.recording
                text: "Region"
                icon: Icons.selection
                busy: startCmd.running
                onClicked: {
                    page.errorMessage = "";
                    startCmd.run(["screen-record", "start", "--region"]);
                }
            }
            Btn {
                visible: !page.recording
                text: "Full screen"
                icon: Icons.record
                kind: "primary"
                busy: startCmd.running
                onClicked: {
                    page.errorMessage = "";
                    startCmd.run(["screen-record", "start"]);
                }
            }
        }
        SettingRow {
            icon: Icons.folder
            title: "Recordings folder"
            subtitle: "~/Videos/Recordings"
            Btn {
                text: "Open"
                onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "sh", page.recordingsDir])
            }
        }
    }

    SectionLabel {
        text: "Keyboard shortcuts"
    }
    Card {
        Repeater {
            model: [
                {
                    keys: "Print",
                    what: "Screenshot"
                },
                {
                    keys: "Super + Print",
                    what: "Pick a colour"
                },
                {
                    keys: "Super + Shift + Print",
                    what: "Start or stop a screen recording"
                }
            ]
            delegate: SettingRow {
                required property var modelData
                required property int index
                first: index === 0
                minHeight: 46
                icon: Icons.keyboard
                title: modelData.what
                Badge {
                    text: modelData.keys
                }
            }
        }
    }
}
