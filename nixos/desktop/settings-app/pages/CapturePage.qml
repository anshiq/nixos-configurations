// Capture: screenshot, colour picker, text/QR extraction (OCR), pinning and
// screen recording, plus the keybinds that do the same without opening this
// window.
//
// All of them go through the desktop's own commands (`screenshot`,
// `hyprpicker`, `ocr`, `pin`, `screen-record`), so this page and the keybinds
// behave alike. Screenshot, colour picker and the OCR tools hide this window
// first so it is not in the shot, and bring it back when the tool exits. Recording state is followed
// through screen-record's pidfile (inotify, no polling).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Page {
    id: page
    title: "Capture"
    subtitle: recording ? "Recording…" : "Screenshots, text from screen, colours and screen recordings"

    // Set by shell.qml so the page can step out of its own screenshots.
    property var hostWindow: null

    readonly property string home: Quickshell.env("HOME")
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || `/run/user/${Quickshell.env("UID")}`
    readonly property string recordingsDir: home + "/Videos/Recordings"

    property bool recording: false
    property string recordFile: ""
    property string pickedColor: ""
    property string errorMessage: ""
    property string pendingTool: "" // "screenshot" | "picker" | "ocr" | "qr" | "translate" while the window is hidden

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

    // Region tools that read the screen: command per pendingTool.
    readonly property var ocrCommands: ({
            ocr: ["ocr"],
            qr: ["ocr", "--qr"],
            translate: ["ocr", "--text", "--translate", "en"]
        })

    function refreshStatus() {
        statusCmd.run(["screen-record", "status", "--json"]);
    }

    Timer {
        id: hideDelay
        interval: 300
        onTriggered: {
            if (page.pendingTool === "screenshot")
                shotCmd.run(["screenshot"]);
            else if (page.pendingTool === "picker")
                pickCmd.run(["hyprpicker", "-a"]);
            else
                ocrCmd.run(page.ocrCommands[page.pendingTool]);
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

    // ocr copies the recognised text itself and reports it in a notification.
    Cmd {
        id: ocrCmd
        onFinished: (code, out, err) => {
            page.restoreWindow();
            if (code !== 0)
                page.fail("Reading text from the screen", code, err);
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
        text: "Text and codes"
    }
    Card {
        SettingRow {
            first: true
            icon: Icons.selection
            title: "Copy text from the screen"
            subtitle: "Select an area; the text in it (English and Hindi) is copied to the clipboard. QR codes are decoded too."
            Btn {
                text: "Select"
                kind: "primary"
                busy: page.pendingTool === "ocr"
                enabled: page.pendingTool === ""
                onClicked: page.runHidden("ocr")
            }
        }
        SettingRow {
            icon: Icons.selection
            title: "Scan a QR code"
            subtitle: "Select an area with a QR code or barcode and copy what it holds."
            Btn {
                text: "Scan"
                busy: page.pendingTool === "qr"
                enabled: page.pendingTool === ""
                onClicked: page.runHidden("qr")
            }
        }
        SettingRow {
            icon: Icons.selection
            title: "Translate text on screen"
            subtitle: "Reads the text in an area and copies it translated to English. This sends the text to Google Translate."
            Btn {
                text: "Translate"
                busy: page.pendingTool === "translate"
                enabled: page.pendingTool === ""
                onClicked: page.runHidden("translate")
            }
        }
        SettingRow {
            icon: Icons.image
            title: "Pin the clipboard image"
            subtitle: "Keep the image on the clipboard on top of everything as a floating window. Close it with Super + Q."
            Btn {
                text: "Pin"
                onClicked: Quickshell.execDetached(["pin", "--clipboard"])
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
            subtitle: page.recording ? (page.recordFile !== "" ? `Saving to ${page.baseName(page.recordFile)}. Keeps going if you close this window.` : "Keeps going if you close this window.") : "Full screen or a selected region, saved to ~/Videos/Recordings. GIF records a region and copies the GIF when you stop."
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
                text: "GIF"
                icon: Icons.selection
                busy: startCmd.running
                onClicked: {
                    page.errorMessage = "";
                    startCmd.run(["screen-record", "start", "--region", "--gif"]);
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
                },
                {
                    keys: "Super + Alt + Print",
                    what: "Start or stop a region recording as a GIF"
                },
                {
                    keys: "Super + Shift + O",
                    what: "Copy text (or a QR code) from an area of the screen"
                },
                {
                    keys: "Super + Alt + O",
                    what: "Scan a QR code or barcode"
                },
                {
                    keys: "Super + Ctrl + O",
                    what: "Copy text from the screen, translated to English"
                },
                {
                    keys: "Super + Shift + P",
                    what: "Pin an area of the screen on top of everything"
                },
                {
                    keys: "Super + Ctrl + P",
                    what: "Pin the clipboard image"
                },
                {
                    keys: "Super + N",
                    what: "Do not disturb (silence notification popups)"
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
