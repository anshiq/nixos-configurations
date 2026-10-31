// Power: battery status (read from sysfs - no extra daemon needed) and the
// power profile (power-profiles-daemon via powerprofilesctl).
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Page {
    id: page
    title: "Power"
    subtitle: hasBattery ? `${pct}%  ·  ${statusText}` : "No battery detected"

    property var bat: ({})
    property bool hasBattery: false
    property bool acOnline: false

    property bool profilesOk: false
    property var profiles: []
    property string activeProfile: ""
    property string profileError: ""

    readonly property var profileInfo: ({
            "power-saver": {
                title: "Power saver",
                sub: "Longer battery life",
                icon: Icons.leaf
            },
            "balanced": {
                title: "Balanced",
                sub: "Everyday use",
                icon: Icons.balance
            },
            "performance": {
                title: "Performance",
                sub: "Maximum speed",
                icon: Icons.rocket
            }
        })

    // sysfs reports either energy (µWh / µW) or charge (µAh / µA) depending on
    // the battery driver; the ratios are the same either way.
    function num(k) {
        const v = parseFloat(bat[k]);
        return isNaN(v) ? 0 : v;
    }
    readonly property int pct: Math.round(num("capacity"))
    readonly property string statusText: bat.status || "Unknown"
    readonly property bool charging: statusText === "Charging"
    readonly property bool discharging: statusText === "Discharging"
    readonly property real nowAmount: num("energy_now") || num("charge_now")
    readonly property real fullAmount: num("energy_full") || num("charge_full")
    readonly property real designAmount: num("energy_full_design") || num("charge_full_design")
    readonly property real rate: num("power_now") || num("current_now")
    readonly property real watts: num("power_now") > 0 ? num("power_now") / 1e6 : (num("current_now") * num("voltage_now")) / 1e12
    readonly property int health: designAmount > 0 ? Math.round(fullAmount / designAmount * 100) : 0
    readonly property real hoursLeft: rate <= 0 ? 0 : (discharging ? nowAmount / rate : (charging ? Math.max(0, fullAmount - nowAmount) / rate : 0))

    function fmtDuration(h) {
        if (h <= 0)
            return "";
        const mins = Math.round(h * 60);
        const hh = Math.floor(mins / 60);
        const mm = mins % 60;
        return hh > 0 ? `${hh} h ${mm} min` : `${mm} min`;
    }

    function refresh() {
        batCmd.run(["bash", Quickshell.shellDir + "/scripts/battery.sh"]);
        ppdList.run(["powerprofilesctl", "list"]);
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: page.refresh()
    }

    Cmd {
        id: batCmd
        onFinished: (code, out) => {
            const d = {};
            for (const l of out.split("\n")) {
                const i = l.indexOf("=");
                if (i > 0)
                    d[l.slice(0, i)] = l.slice(i + 1);
            }
            page.hasBattery = d.capacity !== undefined;
            page.bat = d;
            page.acOnline = d.ac === "1";
        }
    }

    // `powerprofilesctl list` prints blocks like
    //   * balanced:        <- active one is starred
    //       CpuDriver: ...
    //     power-saver:
    Cmd {
        id: ppdList
        onFinished: (code, out) => {
            const names = [];
            let active = "";
            for (const l of out.split("\n")) {
                const m = l.match(/^([ *]) ([a-z-]+):\s*$/);
                if (m) {
                    names.push(m[2]);
                    if (m[1] === "*")
                        active = m[2];
                }
            }
            page.profilesOk = code === 0 && names.length > 0;
            page.profiles = names.filter(n => page.profileInfo[n] !== undefined);
            page.activeProfile = active;
        }
    }

    Cmd {
        id: ppdSet
        onFinished: (code, out, err) => {
            page.profileError = code === 0 ? "" : (err.trim() || "Could not change the power profile.");
            page.refresh();
        }
    }

    // --- battery
    SectionLabel {
        visible: page.hasBattery
        text: "Battery"
    }
    Card {
        visible: page.hasBattery

        Item {
            Layout.fillWidth: true
            implicitHeight: 104
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.pad + 4
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: page.pct + "%"
                        font.pixelSize: 34
                        font.bold: true
                        color: Theme.brightForeground
                    }
                    Label {
                        text: page.statusText + (page.hoursLeft > 0 ? `  ·  ${page.fmtDuration(page.hoursLeft)} ${page.charging ? "until full" : "left"}` : "")
                        color: Theme.textDim
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 5
                    }
                    Glyph {
                        text: page.charging ? Icons.batteryCharging : Icons.battery
                        font.pixelSize: 26
                        color: Theme.textDim
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10
                    radius: 5
                    color: Theme.border
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, page.pct)) / 100
                        height: parent.height
                        radius: 5
                        color: page.pct <= 15 && !page.charging ? Theme.danger : Theme.accent
                        Behavior on width {
                            NumberAnimation {
                                duration: 250
                            }
                        }
                    }
                }
            }
        }

        SettingRow {
            minHeight: 46
            title: "Power source"
            Label {
                text: page.acOnline ? "AC adapter connected" : "Running on battery"
                color: Theme.textDim
            }
        }
        SettingRow {
            visible: page.watts > 0.05
            minHeight: 46
            title: page.charging ? "Charging at" : "Power draw"
            Label {
                text: page.watts.toFixed(1) + " W"
                color: Theme.textDim
            }
        }
        SettingRow {
            visible: page.health > 0
            minHeight: 46
            title: "Battery health"
            subtitle: "Full-charge capacity compared with when it was new"
            Label {
                text: page.health + "%"
                color: page.health < 60 ? Theme.danger : Theme.textDim
            }
        }
        SettingRow {
            visible: num("cycle_count") > 0
            minHeight: 46
            title: "Charge cycles"
            Label {
                text: String(page.num("cycle_count"))
                color: Theme.textDim
            }
        }
    }

    // --- power profile
    SectionLabel {
        text: "Power profile"
    }
    Banner {
        text: page.profileError
        kind: "error"
    }
    Card {
        visible: !page.profilesOk
        SettingRow {
            first: true
            icon: Icons.balance
            title: "Power profiles are not available"
            subtitle: "The power-profiles-daemon service is not running. Once it is enabled, you can choose between power saver, balanced and performance here."
            minHeight: 72
        }
    }
    RowLayout {
        visible: page.profilesOk
        Layout.fillWidth: true
        spacing: 10

        Repeater {
            model: page.profiles
            delegate: Rectangle {
                id: prof
                required property string modelData
                readonly property bool active: page.activeProfile === modelData
                readonly property var info: page.profileInfo[modelData]
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 112
                radius: Theme.radius
                color: active ? Theme.selection : (profMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                border.width: 1
                border.color: active ? Theme.selection : Theme.border
                Behavior on color {
                    ColorAnimation {
                        duration: 90
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Glyph {
                        text: prof.info.icon
                        font.pixelSize: 28
                        color: prof.active ? Theme.selectionForeground : Theme.brightForeground
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: prof.info.title
                        color: prof.active ? Theme.selectionForeground : Theme.brightForeground
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: prof.info.sub
                        font.pixelSize: Theme.fsSmall
                        color: prof.active ? Theme.selectionForeground : Theme.textDim
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    id: profMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        page.profileError = "";
                        ppdSet.run(["powerprofilesctl", "set", prof.modelData]);
                    }
                }
            }
        }
    }
}
