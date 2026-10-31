// Display: backlight brightness, night light (hyprsunset), connected monitors.
//
// Night light goes through the `bluelight` command, the same one the bar and
// the theme switcher use, so all of them stay in agreement. Monitors are
// read-only: layout/scale/refresh live in
// hypr/hyprland.lua (Nix-deployed), so a live change here would not survive a
// reload and is better edited at the source.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Page {
    id: page
    title: "Display"
    subtitle: monitors.length > 0 ? monitors.map(m => m.name).join(", ") : ""

    readonly property string home: Quickshell.env("HOME")

    property bool hasBacklight: false
    property int brightness: 50
    property int wantBrightness: -1

    property bool nightOk: true
    property bool nightOn: false
    property int nightTemp: 4000
    property var monitors: []

    function readNight() {
        nlRead.run(["bluelight", "status", "--json"]);
    }

    function refresh() {
        blRead.run(["brightnessctl", "-m", "-c", "backlight"]);
        readNight();
    }

    Component.onCompleted: {
        refresh();
        mon.run(["hyprctl", "monitors", "-j"]);
    }

    // Brightness keys and the bar can change these behind our back; re-read
    // while the page is shown (it is destroyed when another page opens).
    Timer {
        interval: 4000
        running: page.visible
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
            try {
                const j = JSON.parse(out);
                page.nightOk = true;
                page.nightOn = !!j.on;
                const t = parseInt(j.temp, 10);
                if (!isNaN(t) && !nlSetTemp.running && nlThrottle.pending < 0)
                    page.nightTemp = t;
            } catch (e) {
                page.nightOk = false;
                page.nightOn = false;
            }
        }
    }

    Cmd {
        id: nlToggle
        onFinished: page.readNight()
    }

    // `bluelight set` saves the temperature and applies it if the filter is on.
    Cmd {
        id: nlSetTemp
        onFinished: {
            if (nlThrottle.pending >= 0)
                nlThrottle.restart();
        }
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
            nlSetTemp.run(["bluelight", "set", String(t)]);
        }
    }

    // The saved temperature; a change from the bar shows up immediately.
    FileView {
        path: `${page.home}/.local/state/desktop/bluelight-temp`
        watchChanges: true
        printErrors: false
        onFileChanged: page.readNight()
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
            subtitle: page.nightOk ? "Reduces blue light. Night themes switch it on automatically." : "Unavailable: the bluelight command was not found or did not answer."
            Toggle {
                checked: page.nightOn
                busy: nlToggle.running
                enabled: page.nightOk
                onToggled: nlToggle.run(["bluelight", "toggle"])
            }
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 64
            enabled: page.nightOk
            opacity: !page.nightOk ? 0.4 : (page.nightOn ? 1 : 0.55)
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
