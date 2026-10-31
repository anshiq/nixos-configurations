import QtQuick
import qs
import qs.components

BarItem {
    icon: "\u{F0425}"
    iconColor: Session.overlay === "powermenu" ? Colors.accent : Colors.foreground
    tooltip: "Power"

    onClicked: Session.toggle("powermenu")
}
