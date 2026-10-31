import QtQuick
import Quickshell.Hyprland
import qs

// Workspaces 1-5 always, plus any other occupied workspace up to 10.
Row {
    id: root
    spacing: 0

    readonly property var ids: {
        const ids = [1, 2, 3, 4, 5];
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0 && ws.id <= 10 && !ids.includes(ws.id))
                ids.push(ws.id);
        return ids.sort((a, b) => a - b);
    }

    function workspace(id) {
        for (const ws of Hyprland.workspaces.values)
            if (ws.id === id)
                return ws;
        return null;
    }

    Repeater {
        model: root.ids

        Item {
            id: cell
            required property int modelData
            readonly property var ws: root.workspace(modelData)
            readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
            readonly property bool occupied: ws !== null && ws.toplevels.values.length > 0

            width: 20
            height: 18

            Text {
                anchors.centerIn: parent
                text: cell.focused ? "\u{F14FB}" : (cell.modelData === 10 ? "0" : String(cell.modelData))
                color: cell.focused ? Colors.brightForeground : Colors.foreground
                opacity: cell.focused || cell.occupied ? 1 : 0.5
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
