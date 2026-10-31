import QtQuick
import Quickshell
import qs.components

BarItem {
    icon: "\u{F0493}"
    tooltip: "Settings"

    onClicked: Quickshell.execDetached(["settings-app"])
}
