// Phase 4: replaces wofi for the two use sites in hyprland.lua - drun app
// launcher (SUPER+SPACE) and the cliphist dmenu picker (SUPER+V). Quickshell
// is a single long-lived process, so external triggers go through its IPC
// mechanism (`quickshell ipc call launcher <function> ...`) rather than
// spawning a new process per invocation like wofi did. Dmenu mode's
// stdin/stdout contract (`cliphist list | wofi --dmenu | cliphist decode`)
// can't be replicated directly over IPC (arguments only, no stdin/stdout
// passthrough to a running process), so scripts/dmenu.sh bridges it: it
// writes stdin to a temp file, calls openDmenu with the temp paths, and
// polls for a completion marker this window writes after the user picks
// (or cancels).
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-launcher"

    property string mode: "drun" // "drun" | "dmenu"
    property string dmenuOutputPath: ""
    property var dmenuOptions: []
    property var filteredEntries: []

    function updateFilter() {
        const q = searchField.text.toLowerCase();
        if (root.mode === "drun") {
            const apps = [];
            const values = DesktopEntries.applications.values;
            for (let i = 0; i < values.length; i++) {
                const e = values[i];
                if (!e.noDisplay && e.name.toLowerCase().includes(q)) apps.push(e);
            }
            root.filteredEntries = apps;
        } else {
            root.filteredEntries = root.dmenuOptions.filter(o => o.toLowerCase().includes(q));
        }
        list.currentIndex = root.filteredEntries.length > 0 ? 0 : -1;
    }
    onDmenuOptionsChanged: updateFilter()

    function openDrun() {
        root.mode = "drun";
        searchField.text = "";
        updateFilter();
        root.visible = true;
    }

    function openDmenu(inputPath, outputPath) {
        root.mode = "dmenu";
        root.dmenuOutputPath = outputPath;
        searchField.text = "";
        dmenuReader.path = inputPath;
        dmenuReader.reload();
        root.visible = true;
    }

    function closeLauncher() {
        root.visible = false;
    }

    function activate(index) {
        if (index < 0 || index >= root.filteredEntries.length) return;
        if (root.mode === "drun") {
            root.filteredEntries[index].execute();
            root.closeLauncher();
        } else {
            writeDmenuResult(root.filteredEntries[index]);
        }
    }

    function cancelDmenu() {
        if (root.mode === "dmenu") writeDmenuResult("");
        else root.closeLauncher();
    }

    function writeDmenuResult(value) {
        dmenuWriter.path = root.dmenuOutputPath;
        dmenuWriter.setText(value);
        root.closeLauncher();
    }

    FileView {
        id: dmenuReader
        onLoaded: root.dmenuOptions = text().split("\n").filter(l => l.length > 0)
    }

    FileView {
        id: dmenuWriter
        onSaved: doneMarkerProc.running = true
    }

    Process {
        id: doneMarkerProc
        command: ["touch", `${root.dmenuOutputPath}.done`]
    }

    IpcHandler {
        target: "launcher"
        function openDrun(): void {
            root.openDrun();
        }
        function openDmenu(inputPath: string, outputPath: string): void {
            root.openDmenu(inputPath, outputPath);
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.cancelDmenu()
    }

    Rectangle {
        anchors.centerIn: parent
        width: 560
        height: 420
        radius: 6
        color: Colors.background
        border.color: Colors.muted
        border.width: 1

        MouseArea {
            // Swallows clicks so they don't fall through to the backdrop
            // MouseArea above and close the launcher.
            anchors.fill: parent
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            TextField {
                id: searchField
                width: parent.width
                placeholderText: "Search"
                focus: true
                color: Colors.foreground
                onTextChanged: root.updateFilter()
                Keys.onEscapePressed: root.cancelDmenu()
                Keys.onReturnPressed: root.activate(list.currentIndex)
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - searchField.height - 8
                clip: true
                model: root.filteredEntries.length
                currentIndex: 0
                delegate: Rectangle {
                    id: delegateRoot
                    required property int index
                    width: ListView.view.width
                    height: 32
                    color: delegateRoot.index === ListView.view.currentIndex ? Colors.selection : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        color: Colors.foreground
                        text: root.mode === "drun" ? root.filteredEntries[delegateRoot.index].name : root.filteredEntries[delegateRoot.index]
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.activate(delegateRoot.index)
                    }
                }
            }
        }
    }
}
