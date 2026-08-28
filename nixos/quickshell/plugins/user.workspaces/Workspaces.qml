// Mirrors waybar's hyprland/workspaces module (all-outputs, disable-scroll).
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../" // shell root qmldir - exposes the Colors singleton

RowLayout {
    spacing: 6

    Repeater {
        model: Hyprland.workspaces

        delegate: Text {
            id: delegateRoot
            required property var modelData
            text: "●" // filled circle, same glyph waybar used for all states
            font.pixelSize: 10
            color: modelData.active ? Colors.brightForeground : Colors.muted

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                onClicked: Hyprland.dispatch("workspace " + delegateRoot.modelData.id)
            }
        }
    }
}
