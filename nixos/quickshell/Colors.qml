// Phase 3: theme unification. Palette now comes from
// ~/.config/quickshell/theme.json instead of a hardcoded day palette - that
// file is a plain copy of one of the theme-<name>.json files (one per theme
// under nixos/themes/, rendered by desktop/home.nix's toQuickshellTheme -
// see themes/generators.nix - and written into this checkout by the
// quickshellThemes activation script), overwritten in place by
// waybar/scripts/theme-switch.sh on every switch. watchChanges + reload()
// below picks up that overwrite live, no bar restart needed.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property color background: "#1a1b26"
    property color foreground: "#a9b1d6"
    property color brightForeground: "#c0caf5"
    property color muted: "#414868"
    property color selection: "#292e42"
    property color red: "#f7768e"
    property color green: "#9ece6a"
    property color yellow: "#e0af68"
    property color blue: "#7aa2f7"
    property color magenta: "#bb9af7"
    property color cyan: "#7dcfff"
    // Matches mako's border-color exactly (day/night), which didn't line up
    // with any of the palette fields above - see Notifications.qml.
    property color accent: "#7aa2f7"

    function applyTheme(json) {
        try {
            const t = JSON.parse(json);
            if (t.background) root.background = t.background;
            if (t.foreground) root.foreground = t.foreground;
            if (t.brightForeground) root.brightForeground = t.brightForeground;
            if (t.muted) root.muted = t.muted;
            if (t.selection) root.selection = t.selection;
            if (t.red) root.red = t.red;
            if (t.green) root.green = t.green;
            if (t.yellow) root.yellow = t.yellow;
            if (t.blue) root.blue = t.blue;
            if (t.magenta) root.magenta = t.magenta;
            if (t.cyan) root.cyan = t.cyan;
            if (t.accent) root.accent = t.accent;
            retry.stop();
        } catch (e) {
            // Leave the last-known-good palette in place on a malformed or
            // torn read (e.g. theme-switch.sh caught mid-write), but come back
            // for it: the watcher coalesces events, so a read that lands
            // between install(1)'s truncate and its write can otherwise be the
            // *only* notification for that switch, leaving the bar on the old
            // palette until the next one hours later.
            retry.restart();
        }
    }

    Timer {
        id: retry
        interval: 150
        repeat: true
        triggeredOnStart: false
        property int attempts: 0
        onTriggered: {
            if (++attempts > 20) {
                stop();
                attempts = 0;
                console.warn("Colors: gave up re-reading theme.json after a torn read");
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
        onFileChanged: reload()
        onLoaded: root.applyTheme(text())
        onTextChanged: root.applyTheme(text())
    }
}
