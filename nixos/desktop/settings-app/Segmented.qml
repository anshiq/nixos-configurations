import QtQuick
import QtQuick.Layouts

// A row of mutually exclusive choices drawn as buttons; the current one is
// filled ("primary"). options: [{ value, label }]. picked(value) fires on a
// click on any choice other than the current one.
RowLayout {
    id: root
    property var options: []
    property string current: ""
    property bool busy: false
    signal picked(string value)

    spacing: 6

    Repeater {
        model: root.options
        delegate: Btn {
            required property var modelData
            text: modelData.label
            kind: modelData.value === root.current ? "primary" : "neutral"
            enabled: !root.busy
            onClicked: if (modelData.value !== root.current)
                root.picked(modelData.value)
        }
    }
}
