import QtQuick
import Quickshell
import qs.components

BarItem {
    icon: "\u{F0100}"
    tooltip: "Screenshot\nRight click: capture settings"

    onClicked: button => Quickshell.execDetached(button === Qt.RightButton ? ["settings-app", "capture"] : ["screenshot"])
}
