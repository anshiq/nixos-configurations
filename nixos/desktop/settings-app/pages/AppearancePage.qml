// Appearance: pick the desktop theme. Switching goes through `theme-switch`,
// the same command the keybind and the schedule use, so everything it
// retints (terminals, borders, bar, lock screen, wallpaper) follows.
//
// Themes are Nix-defined and deployed to ~/.config/desktop/themes/<name>.json;
// the day/night schedule to ~/.config/desktop/schedule.json. This page only
// chooses - the schedule is shown read-only.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Page {
    id: page
    title: "Appearance"
    subtitle: current !== "" ? `Theme: ${pretty(current)}${kind !== "" ? "  ·  " + (kind === "night" ? "Night" : "Day") : ""}` : ""

    readonly property string home: Quickshell.env("HOME")
    readonly property string themesDir: home + "/.config/desktop/themes"

    property string current: ""
    property string kind: ""
    property var themes: []
    property var schedule: []
    property int activeSlot: -1 // index into schedule of the slot in force now
    property string applying: ""
    property string errorMessage: ""

    function pretty(name) {
        return name.split("-").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
    }

    function minutes(hhmm) {
        const p = String(hhmm || "0:0").split(":");
        return (parseInt(p[0], 10) || 0) * 60 + (parseInt(p[1], 10) || 0);
    }

    function loadThemes() {
        // One "<name><TAB><json on one line>" record per theme file.
        themesCmd.run(["sh", "-c", 'for f in "$1"/*.json; do [ -r "$f" ] || continue; n=${f##*/}; printf "%s\\t%s\\n" "${n%.json}" "$(tr -d "\\n" < "$f")"; done', "sh", page.themesDir]);
    }

    function readStatus() {
        statusCmd.run(["theme-status", "--json"]);
    }

    // args: [] = follow the schedule, ["toggle"], ["next"], or [name]
    function apply(args, tag) {
        if (page.applying !== "")
            return;
        page.errorMessage = "";
        page.applying = tag;
        switchCmd.run(["theme-switch"].concat(args));
    }

    // Which slot is in force now (the last one at or before the current
    // time, wrapping to yesterday's last), and when the next change is.
    // Re-armed for the next boundary instead of ticking every minute.
    function updateSlot() {
        const n = page.schedule.length;
        if (n === 0) {
            page.activeSlot = -1;
            slotTimer.stop();
            return;
        }
        const d = new Date();
        const now = d.getHours() * 60 + d.getMinutes();
        let idx = n - 1;
        for (let i = 0; i < n; i++)
            if (page.minutes(page.schedule[i].time) <= now)
                idx = i;
        page.activeSlot = idx;
        let diff = page.minutes(page.schedule[(idx + 1) % n].time) - now;
        if (diff <= 0)
            diff += 24 * 60;
        slotTimer.interval = (diff * 60 - d.getSeconds()) * 1000 + 500;
        slotTimer.restart();
    }

    Component.onCompleted: loadThemes()

    Timer {
        id: slotTimer
        running: false
        onTriggered: page.updateSlot()
    }

    Cmd {
        id: themesCmd
        onFinished: (code, out) => {
            const list = [];
            for (const l of out.split("\n")) {
                const tab = l.indexOf("\t");
                if (tab <= 0)
                    continue;
                let c = {};
                try {
                    c = JSON.parse(l.slice(tab + 1));
                } catch (e) {}
                list.push({
                    name: l.slice(0, tab),
                    mode: c.mode || "",
                    background: c.background || "#000000",
                    foreground: c.foreground || "#ffffff",
                    accent: c.accent || "#888888",
                    selection: c.selection || "#888888",
                    muted: c.muted || "#444444",
                    red: c.red || "#888888",
                    green: c.green || "#888888"
                });
            }
            page.themes = list;
        }
    }

    Cmd {
        id: statusCmd
        onFinished: (code, out, err) => {
            try {
                const s = JSON.parse(out);
                page.current = s.theme || "";
                page.kind = s.kind || "";
            } catch (e) {
                page.current = "";
                page.kind = "";
                if (code === 127)
                    page.errorMessage = "theme-status is not installed, so the active theme is unknown.";
            }
        }
    }

    Cmd {
        id: switchCmd
        onFinished: (code, out, err) => {
            page.applying = "";
            if (code !== 0)
                page.errorMessage = code === 127 ? "theme-switch is not installed." : (err.trim() || out.trim() || "Could not switch the theme.");
            page.readStatus();
        }
    }

    // theme-switch writes the active theme name here; follow it so a switch
    // from the keybind or the schedule shows up immediately. The first load
    // (or failure) also does the first status read.
    FileView {
        path: `${page.home}/.local/state/desktop/theme`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: page.readStatus()
        onLoadFailed: page.readStatus()
    }

    FileView {
        path: `${page.home}/.config/desktop/schedule.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const j = JSON.parse(text());
                page.schedule = Array.isArray(j) ? j.filter(e => e && e.time && e.theme) : [];
            } catch (e) {
                page.schedule = [];
            }
            page.updateSlot();
        }
        onLoadFailed: {
            page.schedule = [];
            page.updateSlot();
        }
    }

    headerTrailing: [
        Btn {
            text: "Day / night"
            icon: Icons.nightLight
            busy: page.applying === "toggle"
            enabled: page.applying === ""
            onClicked: page.apply(["toggle"], "toggle")
        },
        Btn {
            text: "Next"
            icon: Icons.skipNext
            busy: page.applying === "next"
            enabled: page.applying === ""
            onClicked: page.apply(["next"], "next")
        }
    ]

    Banner {
        text: page.errorMessage
        kind: "error"
    }

    SectionLabel {
        text: "Themes"
    }
    Card {
        visible: page.themes.length === 0 && !themesCmd.running
        SettingRow {
            first: true
            icon: Icons.palette
            title: "No themes found"
            subtitle: "Themes are deployed to ~/.config/desktop/themes by the system configuration."
            minHeight: 64
        }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 12
        rowSpacing: 12

        Repeater {
            model: page.themes
            delegate: Rectangle {
                id: tile
                required property var modelData
                readonly property bool active: page.current === modelData.name
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 112
                radius: Theme.radius
                color: modelData.background
                border.width: active ? 2 : 1
                border.color: active ? modelData.accent : modelData.muted
                opacity: page.applying !== "" && page.applying !== modelData.name ? 0.55 : 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: page.pretty(tile.modelData.name)
                            color: tile.modelData.foreground
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Glyph {
                            visible: tile.active
                            text: Icons.check
                            color: tile.modelData.accent
                        }
                        Label {
                            visible: page.applying === tile.modelData.name
                            text: "Applying…"
                            color: tile.modelData.foreground
                            font.pixelSize: Theme.fsSmall
                        }
                    }
                    Label {
                        text: tile.modelData.mode === "night" ? "Night" : (tile.modelData.mode === "day" ? "Day" : "")
                        color: tile.modelData.foreground
                        opacity: 0.6
                        font.pixelSize: Theme.fsSmall
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                    Row {
                        spacing: 8
                        Repeater {
                            model: [tile.modelData.accent, tile.modelData.selection, tile.modelData.foreground, tile.modelData.red, tile.modelData.green, tile.modelData.muted]
                            delegate: Rectangle {
                                required property string modelData
                                width: 22
                                height: 22
                                radius: 11
                                color: modelData
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.18)
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: page.applying === ""
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.apply([tile.modelData.name], tile.modelData.name)
                }
            }
        }
    }

    SectionLabel {
        visible: page.schedule.length > 0
        text: "Automatic schedule"
    }
    Card {
        visible: page.schedule.length > 0
        Repeater {
            model: page.schedule
            delegate: SettingRow {
                required property var modelData
                required property int index
                readonly property bool inForce: index === page.activeSlot
                first: index === 0
                minHeight: 46
                icon: Icons.calendar
                iconColor: inForce ? Theme.accent : Theme.textDim
                title: modelData.time
                Badge {
                    visible: inForce
                    text: "Now"
                    tone: "accent"
                }
                Label {
                    text: page.pretty(modelData.theme)
                    color: inForce ? Theme.brightForeground : Theme.textDim
                }
            }
        }
        SettingRow {
            minHeight: 56
            title: "Themes change by themselves at these times"
            subtitle: "A theme you pick stays until the next scheduled change. The schedule is part of the system configuration."
            Btn {
                text: "Follow schedule"
                icon: Icons.sync
                busy: page.applying === "schedule"
                enabled: page.applying === ""
                onClicked: page.apply([], "schedule")
            }
        }
    }
}
