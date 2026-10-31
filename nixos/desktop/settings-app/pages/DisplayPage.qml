// Display: backlight brightness, night light (hyprsunset), connected monitors.
//
// Night light shares its state with the bar's blue-light widget and the theme
// switcher: the saved temperature lives in ~/.cache/waybar-bluelight-temp and
// the on/off switch is the same bluelight-toggle.sh, so all three stay in
// agreement. Monitors are read-only: layout/scale/refresh live in
// hypr/hyprland.lua (Nix-deployed), so a live change here would not survive a
// reload and is better edited at the source.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Page {
    id: page
    title: "Display"
    subtitle: monitors.length > 0 ? monitors.map(m => m.name).join(", ") : ""

    readonly property string home: Quickshell.env("HOME")

    property bool hasBacklight: false
    property int brightness: 50
    property int wantBrightness: -1

    property bool nightOn: false
    property int nightTemp: 4000
    property var monitors: []

    function refresh() {
        blRead.run(["brightnessctl", "-m", "-c", "backlight"]);
        nlRead.run(["bash", "-c", `if pgrep -x hyprsunset >/dev/null; then echo on; else echo off; fi; cat "${page.home}/.cache/waybar-bluelight-temp" 2>/dev/null || echo 4000`]);
        mon.run(["hyprctl", "monitors", "-j"]);
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: page.refresh()
    }

    // ---- brightness -------------------------------------------------------

    Cmd {
        id: blRead
        onFinished: (code, out) => {
            // "device,class,current,percent%,max"
            const f = out.trim().split("\n")[0].split(",");
            page.hasBacklight = code === 0 && f.length >= 5;
            if (page.hasBacklight && page.wantBrightness < 0)
                page.brightness = parseInt(f[3], 10) || 0;
        }
    }

    // Dragging fires dozens of moves per second; coalesce them so at most one
    // brightnessctl runs at a time and the last position always wins.
    Timer {
        id: blThrottle
        interval: 60
        onTriggered: page.applyBrightness()
    }

    function applyBrightness() {
        if (page.wantBrightness < 0 || blSet.running)
            return;
        const v = page.wantBrightness;
        page.wantBrightness = -1;
        blSet.run(["brightnessctl", "-c", "backlight", "set", v + "%"]);
    }

    Cmd {
        id: blSet
        onFinished: {
            if (page.wantBrightness >= 0)
                page.applyBrightness();
            else
                blRead.run(["brightnessctl", "-m", "-c", "backlight"]);
        }
    }

    // ---- night light ------------------------------------------------------

    Cmd {
        id: nlRead
        onFinished: (code, out) => {
            const lines = out.trim().split("\n");
            page.nightOn = lines[0] === "on";
            const t = parseInt(lines[1], 10);
            if (!isNaN(t) && !nlSetTemp.running)
                page.nightTemp = t;
        }
    }

    Cmd {
        id: nlToggle
        onFinished: nlRead.run(["bash", "-c", `if pgrep -x hyprsunset >/dev/null; then echo on; else echo off; fi; cat "${page.home}/.cache/waybar-bluelight-temp" 2>/dev/null || echo 4000`])
    }

    // Same two steps as bluelight-adjust.sh: persist the temperature, and
    // apply it live if the filter is currently running.
    Cmd {
        id: nlSetTemp
    }

    Timer {
        id: nlThrottle
        interval: 120
        property int pending: -1
        onTriggered: {
            if (pending < 0 || nlSetTemp.running)
                return;
            const t = pending;
            pending = -1;
            nlSetTemp.run(["bash", "-c", `mkdir -p "${page.home}/.cache"; echo "$1" > "${page.home}/.cache/waybar-bluelight-temp"; if pgrep -x hyprsunset >/dev/null; then hyprctl hyprsunset temperature "$1" >/dev/null 2>&1; fi`, "_", String(t)]);
        }
    }

    // ---- monitors -----------------------------------------------------------

    Cmd {
        id: mon
        onFinished: (code, out) => {
            try {
                page.monitors = JSON.parse(out).map(m => ({
                            name: m.name,
                            model: [m.make, m.model].filter(x => x).join(" "),
                            width: m.width,
                            height: m.height,
                            refresh: Math.round(m.refreshRate),
                            scale: m.scale,
                            focused: m.focused
                        }));
            } catch (e) {
                page.monitors = [];
            }
        }
    }

    // ---- UI -----------------------------------------------------------------

    SectionLabel {
        text: "Brightness"
    }
    Card {
        SettingRow {
            first: true
            visible: !page.hasBacklight
            icon: Icons.brightness
            title: "No adjustable backlight"
            subtitle: "This display does not expose a brightness control to the system."
        }
        Item {
            visible: page.hasBacklight
            Layout.fillWidth: true
            implicitHeight: 68
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.pad
                anchors.rightMargin: Theme.pad
                spacing: 14
                Glyph {
                    text: Icons.brightness
                    Layout.preferredWidth: 40
                }
                Slider {
                    Layout.fillWidth: true
                    from: 1
                    to: 100
                    stepSize: 1
                    value: page.brightness
                    onMoved: v => {
                        page.brightness = v;
                        page.wantBrightness = v;
                        blThrottle.restart();
                    }
                }
                Label {
                    text: page.brightness + "%"
                    Layout.preferredWidth: 54
                    horizontalAlignment: Text.AlignRight
                    color: Theme.brightForeground
                }
            }
        }
    }

    SectionLabel {
        text: "Night light"
    }
    Card {
        SettingRow {
            first: true
            icon: Icons.nightLight
            title: "Warm the screen colors"
            subtitle: "Reduces blue light. Night themes switch it on automatically."
            Toggle {
                checked: page.nightOn
                busy: nlToggle.running
                onToggled: nlToggle.run([page.home + "/.config/waybar/scripts/bluelight-toggle.sh"])
            }
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 64
            opacity: page.nightOn ? 1 : 0.55
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.pad
                anchors.rightMargin: Theme.pad
                spacing: 14
                Label {
                    text: "Warmer"
                    color: Theme.textDim
                    font.pixelSize: Theme.fsSmall
                }
                Slider {
                    Layout.fillWidth: true
                    from: 2500
                    to: 6500
                    stepSize: 100
                    value: page.nightTemp
                    onMoved: v => {
                        page.nightTemp = v;
                        nlThrottle.pending = v;
                        nlThrottle.restart();
                    }
                }
                Label {
                    text: "Cooler"
                    color: Theme.textDim
                    font.pixelSize: Theme.fsSmall
                }
                Label {
                    text: page.nightTemp + " K"
                    Layout.preferredWidth: 64
                    horizontalAlignment: Text.AlignRight
                    color: Theme.brightForeground
                }
            }
        }
    }

    SectionLabel {
        text: "Displays"
    }
    Card {
        SettingRow {
            first: true
            visible: page.monitors.length === 0
            icon: Icons.display
            title: "No displays reported"
            subtitle: "Hyprland did not return any monitors."
        }
        Repeater {
            model: page.monitors
            delegate: SettingRow {
                required property var modelData
                required property int index
                first: index === 0
                icon: Icons.display
                title: modelData.name + (modelData.model ? `  ·  ${modelData.model}` : "")
                subtitle: `${modelData.width} × ${modelData.height}  ·  ${modelData.refresh} Hz  ·  scale ${modelData.scale}`
                Badge {
                    visible: modelData.focused
                    text: "Focused"
                }
            }
        }
        SettingRow {
            title: "Resolution, scale and layout"
            subtitle: "Set in hypr/hyprland.lua (hl.monitor) - changes there are permanent."
            minHeight: 52
        }
    }
}
