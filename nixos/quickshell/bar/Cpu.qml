import QtQuick
import qs.components

BarItem {
    property var stats: null

    icon: "\u{F0EE0}"
    label: (stats ? Math.round(stats.cpu) : 0) + "%"
    labelChars: 4
    tooltip: "CPU"
}
