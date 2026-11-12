import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

// Workspaces grouped by monitor, left to right as the monitors are laid out.
// Hyprland pins 1-5 to the laptop panel and 6-10 to an external monitor
// (hypr/hyprland.lua), so a workspace that doesn't exist yet is listed under
// the monitor it will open on. With more than one monitor each group gets a
// laptop/monitor icon and groups are separated by a bar.
//
// Lists 1-5 always, 6-10 too while an external monitor is connected, plus
// any other existing workspace up to 10. Marks the workspace shown on this
// bar's monitor: bright when that monitor has focus, dimmer when it doesn't.
Row {
    id: root
    spacing: 0

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool monitorFocused: monitor !== null && Hyprland.focusedMonitor === monitor
    readonly property int shownId: monitor !== null && monitor.activeWorkspace !== null ? monitor.activeWorkspace.id : -1

    readonly property var monitors: Hyprland.monitors.values.slice().sort((a, b) => a.x - b.x)
    readonly property bool multi: monitors.length > 1

    function isLaptop(name) {
        return name.startsWith("eDP") || name.startsWith("LVDS") || name.startsWith("DSI");
    }

    function workspace(id) {
        for (const ws of Hyprland.workspaces.values)
            if (ws.id === id)
                return ws;
        return null;
    }

    // Monitor a workspace lives on, or will open on if it doesn't exist yet.
    function home(id) {
        const ws = workspace(id);
        if (ws !== null && ws.monitor !== null)
            return ws.monitor.name;
        const laptop = monitors.find(m => isLaptop(m.name));
        const external = monitors.find(m => !isLaptop(m.name));
        if (id > 5 && external !== undefined)
            return external.name;
        if (laptop !== undefined)
            return laptop.name;
        return monitors.length > 0 ? monitors[0].name : "";
    }

    // [{ name, ids }] in monitor order, empty groups dropped.
    readonly property var groups: {
        const ids = [1, 2, 3, 4, 5];
        if (monitors.some(m => !isLaptop(m.name)))
            ids.push(6, 7, 8, 9, 10);
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0 && ws.id <= 10 && !ids.includes(ws.id))
                ids.push(ws.id);
        ids.sort((a, b) => a - b);

        const groups = monitors.map(m => ({
                    name: m.name,
                    ids: []
                }));
        for (const id of ids) {
            const g = groups.find(g => g.name === home(id)) ?? groups[0];
            if (g !== undefined)
                g.ids.push(id);
        }
        return groups.filter(g => g.ids.length > 0);
    }

    Repeater {
        model: root.groups

        Row {
            id: group
            required property var modelData
            required property int index
            readonly property bool own: root.monitor !== null && modelData.name === root.monitor.name

            height: 18
            spacing: 0

            Text {
                visible: root.multi && group.index > 0
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 4
                rightPadding: 4
                text: "│"
                color: Colors.foreground
                opacity: 0.7
                font.family: Colors.font
                font.pixelSize: 12
            }

            // Laptop or monitor icon; brighter on the group of this bar's own monitor.
            Text {
                visible: root.multi
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: 2
                text: root.isLaptop(group.modelData.name) ? "\u{F0322}" : "\u{F0379}"
                color: group.own ? Colors.brightForeground : Colors.foreground
                opacity: group.own ? 1 : 0.6
                font.family: Colors.font
                font.pixelSize: 13
            }

            Repeater {
                model: group.modelData.ids

                Item {
                    id: cell
                    required property int modelData
                    readonly property var ws: root.workspace(modelData)
                    readonly property bool shown: root.shownId === modelData
                    readonly property bool focused: shown && root.monitorFocused
                    readonly property bool occupied: ws !== null && ws.toplevels.values.length > 0

                    width: 20
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: cell.shown ? "\u{F14FB}" : (cell.modelData === 10 ? "0" : String(cell.modelData))
                        color: cell.focused ? Colors.brightForeground : Colors.foreground
                        opacity: cell.focused ? 1 : cell.shown ? 0.6 : cell.occupied ? 1 : 0.5
                        font.family: Colors.font
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = "${cell.modelData}" })`)
                    }
                }
            }
        }
    }
}
