import QtQuick
import QtQuick.Layouts

// A rounded surface holding SettingRows (or any Layout-friendly content).
Rectangle {
    id: root
    default property alias content: col.data

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight
    radius: Theme.radius
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 1
        spacing: 0
    }
}
