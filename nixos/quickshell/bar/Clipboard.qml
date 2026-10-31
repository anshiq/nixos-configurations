import QtQuick
import qs
import qs.components

BarItem {
    icon: "\u{F014D}"
    iconColor: Session.overlay === "clipboard" ? Colors.accent : Colors.foreground
    tooltip: "Clipboard history"

    onClicked: Session.toggle("clipboard")
}
