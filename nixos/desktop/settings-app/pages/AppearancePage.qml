// Appearance: pick the desktop theme. Switching goes through the same
// theme-switch.sh the keybind and the systemd schedule use, so everything it
// retints (terminals, borders, bar, lock screen, wallpaper) follows. The
// themes themselves are Nix-defined (themes/*.nix); this page only chooses.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Page {
    id: page
    title: "Appearance"
    subtitle: current !== "" ? `Theme: ${pretty(current)}` : ""

    readonly property string home: Quickshell.env("HOME")
    readonly property string switcher: home + "/.config/waybar/scripts/theme-switch.sh"

    property string current: ""
    property var themes: []
    property var schedule: []
    property string applying: ""
    property string errorMessage: ""

    function pretty(name) {
        return name.split("-").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
    }

    function load() {
        loader.run(["bash", Quickshell.shellDir + "/scripts/themes.sh"]);
    }

    function apply(name) {
        if (page.applying !== "")
            return;
        page.errorMessage = "";
        page.applying = name;
        switchCmd.run([page.switcher, name]);
    }

    Component.onCompleted: load()

    Cmd {
        id: loader
        onFinished: (code, out) => {
            const themes = [];
            const schedule = [];
            let current = "";
            for (const l of out.split("\n")) {
                if (l.startsWith("current ")) {
                    current = l.slice(8).trim();
                } else if (l.startsWith("theme ")) {
                    const rest = l.slice(6);
                    const sp = rest.indexOf(" ");
                    const name = rest.slice(0, sp);
                    let c = {};
                    try {
                        c = JSON.parse(rest.slice(sp + 1));
                    } catch (e) {}
                    themes.push({
                        name: name,
                        mode: c.mode || "",
                        background: c.background || "#000000",
                        foreground: c.foreground || "#ffffff",
                        accent: c.accent || "#888888",
                        selection: c.selection || "#888888",
                        muted: c.muted || "#444444"
                    });
                } else if (l.startsWith("schedule ")) {
                    const p = l.split(" ");
                    schedule.push({
                        time: p[1],
                        theme: p[2]
                    });
                }
            }
            page.current = current;
            page.themes = themes;
            page.schedule = schedule;
        }
    }

    Cmd {
        id: switchCmd
        onFinished: (code, out, err) => {
            page.applying = "";
            page.errorMessage = code === 0 ? "" : (err.trim() || out.trim() || "Could not switch the theme.");
            page.load();
        }
    }

    headerTrailing: [
        Btn {
            text: "Toggle day / night"
            icon: Icons.nightLight
            busy: page.applying === "toggle"
            enabled: page.applying === ""
            onClicked: {
                page.errorMessage = "";
                page.applying = "toggle";
                switchCmd.run([page.switcher, "toggle"]);
            }
        }
    ]

    Banner {
        text: page.errorMessage
        kind: "error"
    }

    SectionLabel {
        text: "Themes"
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
                            model: [tile.modelData.accent, tile.modelData.selection, tile.modelData.foreground, tile.modelData.muted]
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
                    onClicked: page.apply(tile.modelData.name)
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
                first: index === 0
                minHeight: 46
                title: modelData.time
                Label {
                    text: page.pretty(modelData.theme)
                    color: Theme.textDim
                }
            }
        }
        SettingRow {
            minHeight: 52
            title: "Themes change by themselves at these times"
            subtitle: "A theme you pick here stays until the next scheduled change. The schedule is defined in themes/schedule.nix."
        }
    }
}
