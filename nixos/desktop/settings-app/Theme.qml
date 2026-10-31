// Palette + metrics for the settings app.
//
// The palette is read from the SAME file the bar uses
// (~/.local/state/quickshell/theme.json, overwritten by theme-switch.sh -
// see quickshell/Colors.qml), so this window re-skins live when the theme
// changes. This app is its own Quickshell process and deliberately does not
// import the shell's Colors singleton: a relative import across config
// roots breaks when ~/.config/settings-app is a symlink, and a standalone
// app should keep working even if the shell is mid-edit.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // Same defaults as quickshell/Colors.qml - only visible for the instant
    // before theme.json is read, or if it is missing.
    property color background: "#1a1b26"
    property color foreground: "#a9b1d6"
    property color brightForeground: "#c0caf5"
    property color muted: "#414868"
    property color selection: "#292e42"
    property color selectionForeground: "#000000"
    property color accent: "#7aa2f7"
    property color red: "#f7768e"
    property color green: "#9ece6a"
    property color yellow: "#e0af68"

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    // Surfaces are derived from background/foreground rather than read from
    // the theme, so every theme (including pure black-white) gets the same
    // layered depth: window < sidebar < card < hovered card.
    readonly property color sidebar: mix(background, foreground, 0.035)
    readonly property color surface: mix(background, foreground, 0.075)
    readonly property color surfaceHover: mix(background, foreground, 0.13)
    readonly property color border: mix(background, foreground, 0.17)
    readonly property color textDim: mix(background, foreground, 0.62)
    // Status colors double as text on mono themes, where red/green/yellow are
    // all the same grey - every status in the UI also has a text label.
    readonly property color danger: red
    readonly property color ok: green

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int radius: 12
    readonly property int radiusSmall: 8
    readonly property int fsBody: 13
    readonly property int fsSmall: 11
    readonly property int fsTitle: 24
    readonly property int fsSection: 11
    readonly property int fsIcon: 18
    readonly property int rowHeight: 58
    readonly property int pad: 16

    function applyTheme(json) {
        try {
            const t = JSON.parse(json);
            if (t.background) root.background = t.background;
            if (t.foreground) root.foreground = t.foreground;
            if (t.brightForeground) root.brightForeground = t.brightForeground;
            if (t.muted) root.muted = t.muted;
            if (t.selection) root.selection = t.selection;
            if (t.selectionForeground) root.selectionForeground = t.selectionForeground;
            if (t.accent) root.accent = t.accent;
            if (t.red) root.red = t.red;
            if (t.green) root.green = t.green;
            if (t.yellow) root.yellow = t.yellow;
            retry.stop();
        } catch (e) {
            // Torn read while theme-switch.sh is mid-write: keep the last good
            // palette and come back for it (same recovery as Colors.qml).
            retry.restart();
        }
    }

    Timer {
        id: retry
        interval: 150
        repeat: true
        property int attempts: 0
        onTriggered: {
            if (++attempts > 20) {
                stop();
                attempts = 0;
                return;
            }
            themeFile.reload();
        }
        onRunningChanged: if (running)
            attempts = 0
    }

    FileView {
        id: themeFile
        path: `${Quickshell.env("HOME")}/.local/state/quickshell/theme.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyTheme(text())
    }
}
