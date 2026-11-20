// Capture: screenshot, colour picker, text/QR extraction (OCR), pinning and
// screen recording, plus the keybinds that do the same without opening this
// window.
//
// All of them go through the desktop's own commands (`screenshot`,
// `hyprpicker`, `ocr`, `pin`, `screen-record`), so this page and the keybinds
// behave alike. Screenshot, colour picker and the OCR tools hide this window
// first so it is not in the shot, and bring it back when the tool exits. Recording state is followed
// through screen-record's pidfile and countdown file (inotify, no polling).
// The recording options (audio, monitor, countdown) are screen-record's own
// settings (`screen-record settings get --json | set KEY VALUE`, stored in
// ~/.local/state/desktop/screen-record.json), so the bar button and the
// keybinds record the same way as the buttons here.
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
    property bool countdown: false
    // screen-record settings; settingsOk = false while unknown or unavailable.
    property bool settingsOk: false
    property string audioMode: "mic"
    property string outputMode: "focused"
    property int delaySec: 0
    property var monitors: [] // connected monitor names, from hyprctl
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

    function refreshSettings() {
        settingsGet.run(["screen-record", "settings", "get", "--json"]);
    }

    function setSetting(key, value) {
        page.errorMessage = "";
        settingsSet.run(["screen-record", "settings", "set", key, String(value)]);
    }

    readonly property var audioOptions: [
        {
            value: "none",
            label: "None"
        },
        {
            value: "mic",
            label: "Mic"
        },
        {
            value: "system",
            label: "System"
        },
        {
            value: "both",
            label: "Mic + System"
        }
    ]
    readonly property var delayOptions: [
        {
            value: "0",
            label: "Off"
        },
        {
            value: "3",
            label: "3 s"
        },
        {
            value: "5",
            label: "5 s"
        },
        {
            value: "10",
            label: "10 s"
        }
    ]
    // "Focused" plus every connected monitor; a saved monitor that is not
    // connected stays listed so the choice is visible.
    readonly property var outputOptions: {
        const names = page.monitors.slice();
        if (page.outputMode !== "focused" && names.indexOf(page.outputMode) < 0)
            names.push(page.outputMode);
        return [
            {
                value: "focused",
                label: "Focused"
            }
        ].concat(names.map(n => ({
                    value: n,
                    label: n
                })));
    }
    readonly property string audioSummary: ({
            none: "off",
            mic: "microphone",
            system: "system sound",
            both: "mic + system"
        })[page.audioMode] || ""

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
                page.countdown = !!s.countdown;
                page.recordFile = s.file || "";
            } catch (e) {
                page.recording = false;
                page.countdown = false;
            }
        }
    }

    Cmd {
        id: settingsGet
        onFinished: (code, out, err) => {
            if (code !== 0) {
                page.settingsOk = false;
                return;
            }
            try {
                const s = JSON.parse(out);
                page.audioMode = s.audio || "mic";
                page.outputMode = s.output || "focused";
                page.delaySec = s.delay || 0;
                page.settingsOk = true;
            } catch (e) {
                page.settingsOk = false;
            }
        }
    }
    Cmd {
        id: settingsSet
        onFinished: (code, out, err) => {
            if (code !== 0)
                page.fail("Saving the recording settings", code, err);
            page.refreshSettings();
        }
    }

    // Connected monitors, read once when the page opens.
    Cmd {
        id: monitorsCmd
        onFinished: (code, out, err) => {
            try {
                page.monitors = code === 0 ? JSON.parse(out).map(m => m.name) : [];
            } catch (e) {
                page.monitors = [];
            }
        }
    }
    Component.onCompleted: monitorsCmd.run(["hyprctl", "monitors", "-j"])

    // Separate start/stop commands: stopping must work even if `start`
    // has not returned yet.
    Cmd {
        id: startCmd
        onFinished: (code, out, err) => {
            // 143 = SIGTERM: the countdown was cancelled (screen-record stop).
            if (code !== 0 && code !== 143)
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
    // Present only while a countdown is running.
    FileView {
        path: `${page.runtimeDir}/screen-record.countdown`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: page.refreshStatus()
        onLoadFailed: page.refreshStatus()
    }
    // The settings file; also changed by `screen-record settings set` elsewhere.
    FileView {
        path: `${page.home}/.local/state/desktop/screen-record.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: page.refreshSettings()
        onLoadFailed: page.refreshSettings()
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
            title: page.recording ? "Recording" : (page.countdown ? "Starting…" : "Not recording")
            subtitle: {
                if (page.recording)
                    return page.recordFile !== "" ? `Saving to ${page.baseName(page.recordFile)}. Keeps going if you close this window.` : "Keeps going if you close this window.";
                if (page.countdown)
                    return "The countdown is running. Cancel stops it before anything is recorded.";
                return `Audio: ${page.audioSummary}. Saved to ~/Videos/Recordings; GIFs are silent and get copied.`;
            }
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
                visible: page.countdown && !page.recording
                text: "Cancel"
                icon: Icons.close
                kind: "danger"
                busy: stopCmd.running
                onClicked: {
                    page.errorMessage = "";
                    stopCmd.run(["screen-record", "stop"]);
                }
            }
            Btn {
                visible: !page.recording && !page.countdown
                text: "Region"
                icon: Icons.selection
                busy: startCmd.running
                onClicked: {
                    page.errorMessage = "";
                    startCmd.run(["screen-record", "start", "--region"]);
                }
            }
            Btn {
                visible: !page.recording && !page.countdown
                text: "GIF"
                icon: Icons.selection
                busy: startCmd.running
                onClicked: {
                    page.errorMessage = "";
                    startCmd.run(["screen-record", "start", "--region", "--gif"]);
                }
            }
            Btn {
                visible: !page.recording && !page.countdown
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
            visible: page.settingsOk
            icon: page.audioMode === "none" ? Icons.microphoneOff : Icons.microphone
            title: "Audio"
            subtitle: {
                if (page.audioMode === "both")
                    return "Microphone and speaker sound in one track.";
                if (page.audioMode === "system")
                    return "What your speakers or headphones play.";
                if (page.audioMode === "mic")
                    return "Default microphone (set on the Sound page).";
                return "Recordings are silent.";
            }
            Segmented {
                options: page.audioOptions
                current: page.audioMode
                busy: settingsSet.running
                onPicked: value => page.setSetting("audio", value)
            }
        }
        SettingRow {
            visible: page.settingsOk
            icon: Icons.display
            title: "Monitor"
            subtitle: page.outputMode === "focused" ? "Full screen records the monitor you are on." : (page.monitors.indexOf(page.outputMode) >= 0 ? `Full screen always records ${page.outputMode}.` : `${page.outputMode} is not connected; the focused monitor is recorded instead.`)
            Segmented {
                options: page.outputOptions
                current: page.outputMode
                busy: settingsSet.running
                onPicked: value => page.setSetting("output", value)
            }
        }
        SettingRow {
            visible: page.settingsOk
            icon: Icons.timer
            title: "Countdown"
            subtitle: page.delaySec > 0 ? `Waits ${page.delaySec} s after you start or pick a region.` : "Recording starts right away."
            Segmented {
                options: page.delayOptions
                current: String(page.delaySec)
                busy: settingsSet.running
                onPicked: value => page.setSetting("delay", value)
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
