import QtQuick
import qs.components

BarItem {
    property var stats: null

    icon: "\u{F035B}"
    label: (stats ? Math.round(stats.ram) : 0) + "%"
    labelChars: 4
    tooltip: stats ? `RAM ${(stats.ramUsedKiB / 1048576).toFixed(1)} / ${(stats.ramTotalKiB / 1048576).toFixed(1)} GiB` : ""
}
