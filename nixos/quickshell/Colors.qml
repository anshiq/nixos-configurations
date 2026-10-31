// Shell palette. Reads ~/.local/state/desktop/theme.json (written by
// theme-switch) and follows it live; the values below are the fallback.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property color background: "#1a1b26"
    property color foreground: "#a9b1d6"
    property color brightForeground: "#c0caf5"
    property color muted: "#414868"
    property color selection: "#292e42"
    property color selectionForeground: "#c0caf5"
    property color red: "#f7768e"
    property color green: "#9ece6a"
    property color yellow: "#e0af68"
    property color blue: "#7aa2f7"
    property color magenta: "#bb9af7"
    property color cyan: "#7dcfff"
    property color accent: "#7aa2f7"

    readonly property string font: "JetBrainsMono Nerd Font"

    readonly property var fields: ["background", "foreground", "brightForeground", "muted", "selection", "selectionForeground", "red", "green", "yellow", "blue", "magenta", "cyan", "accent"]

    function apply(json) {
        let t;
        try {
            t = JSON.parse(json);
        } catch (e) {
            // Torn read while theme-switch rewrites the file; retry once
            // shortly in case no further change event arrives.
            retry.restart();
            return;
        }
        retry.stop();
        for (const f of root.fields)
            if (typeof t[f] === "string" && t[f] !== "")
                root[f] = t[f];
    }

    Timer {
        id: retry
        interval: 250
        onTriggered: themeFile.reload()
    }

    FileView {
        id: themeFile
        path: `${Quickshell.env("HOME")}/.local/state/desktop/theme.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.apply(text())
    }
}
