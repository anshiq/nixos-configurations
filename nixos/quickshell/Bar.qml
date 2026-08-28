// Mirrors nixos/waybar/config's layer=top/position=top/height=22 panel
// and its modules-left/modules-center/modules-right layout. Section
// contents come from plugin-layout.json + plugins/<id>/manifest.json
// (see PluginRow.qml) instead of being hardcoded here, so widgets can be
// added/reordered/removed by editing those JSON files.
import QtQuick
import Quickshell
import Quickshell.Io

PanelWindow {
    id: root
    anchors {
        left: true
        right: true
        top: true
    }
    implicitHeight: 18
    exclusiveZone: 18
    color: Colors.background

    // Injected from shell.qml (`Bar { shell: shellRoot }`) - lets a widget
    // reach `bar.shell.serviceFor(id)`, mirroring real Omarchy's Bar.qml/
    // shell.qml contract. See qs.Ui's BarWidget.qml for the base type that
    // reads `bar`/`vertical`/`barSize`/`moduleWidgets()`.
    property var shell: null
    readonly property bool vertical: false
    readonly property int barSize: root.implicitHeight

    // Every live widget instance across all three sections, keyed by
    // moduleId - a widget id appears once (each id can only be enabled in
    // one section/spot per plugin-layout.json), so broadcast() only ever
    // needs to notify one instance here (unlike Omarchy's multi-monitor
    // case, where the same widget id runs once per bar/screen).
    property var moduleWidgetsMap: ({})

    function moduleWidgets(moduleId) {
        var item = moduleWidgetsMap[moduleId];
        return item ? [item] : [];
    }

    property var layout: ({
            "left": [],
            "center": [],
            "right": []
        })

    function applyLayout(json) {
        try {
            root.layout = JSON.parse(json);
        } catch (e) {
            console.warn("Bar: failed to load plugin-layout.json: " + e);
        }
    }

    FileView {
        id: layoutFile
        path: `${Quickshell.env("HOME")}/.config/quickshell/plugin-layout.json`
        // Live-reloads so quickshell/scripts/plugin.sh enable/disable takes
        // effect immediately, same as Colors.qml watching theme.json -
        // no bar restart needed to pick up a plugin change.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyLayout(text())
        onTextChanged: root.applyLayout(text())
    }

    PluginRow {
        ids: root.layout.left
        bar: root
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: 6
        }
    }

    PluginRow {
        ids: root.layout.center
        bar: root
        anchors.centerIn: parent
    }

    PluginRow {
        ids: root.layout.right
        bar: root
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            rightMargin: 6
        }
    }
}
