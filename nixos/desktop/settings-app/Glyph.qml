import QtQuick

// One icon from Icons.qml, centred in a fixed-width box so rows line up
// regardless of which glyph is shown.
Text {
    color: Theme.foreground
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fsIcon
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
