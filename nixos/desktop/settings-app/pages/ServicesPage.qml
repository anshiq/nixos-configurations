// User services: `systemctl --user` services with state, memory, start/stop/
// restart and the last 50 journal lines.
//
// No polling: everything is re-read when the page is shown, after each
// action and on Refresh. While a unit is mid-transition (activating...) one
// follow-up read is scheduled until it settles.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "ServicesModel.js" as Model

Page {
    id: page
    title: "Services"
    subtitle: !loaded ? "Loading…" : `${runningCount} running` + (failedCount > 0 ? `  ·  ${failedCount} failed` : "")

    property var units: []
    property var memory: ({})
    property bool loaded: false
    property string query: ""
    property bool showInactive: false
    property string errorMessage: ""
    property string statusMessage: ""
    property string busyUnit: ""
    property string busyVerb: ""
    property string logUnit: ""
    property string logText: ""
    property string _filesText: "[]"

    readonly property var shown: Model.filterUnits(units, query, showInactive)
    readonly property int runningCount: units.filter(u => Model.isRunning(u)).length
    readonly property int failedCount: units.filter(u => u.active === "failed").length

    function refresh() {
        files.run(["timeout", "10", "systemctl", "--user", "list-unit-files", "--type=service", "--output=json", "--no-pager"]);
        mem.run(["timeout", "10", "systemctl", "--user", "show", "-p", "Id,MemoryCurrent", "--no-pager", "--", "*.service"]);
    }

    function act(verb, unit) {
        if (busyUnit !== "")
            return;
        page.errorMessage = "";
        page.statusMessage = "";
        page.busyUnit = unit;
        page.busyVerb = verb;
        action.run(["timeout", "30", "systemctl", "--user", verb, "--", unit]);
    }

    function toggleLogs(unit) {
        if (logUnit === unit) {
            logUnit = "";
            logs.running = false;
            return;
        }
        logUnit = unit;
        logText = "";
        loadLogs();
    }

    function loadLogs() {
        if (logUnit !== "")
            logs.run(["timeout", "10", "journalctl", "--user", "-u", logUnit, "-n", "50", "--no-pager", "-o", "short"]);
    }

    function stopAll() {
        settle.stop();
        clearStatus.stop();
        for (const c of [files, list, mem, action, logs])
            c.running = false;
    }

    Component.onCompleted: refresh()
    Component.onDestruction: stopAll()
    onVisibleChanged: visible ? refresh() : stopAll()

    // ---- systemctl plumbing ----------------------------------------------

    // Unit files first (best effort), then the loaded units merged on top.
    Cmd {
        id: files
        onFinished: (code, out) => {
            page._filesText = code === 0 ? out : "[]";
            list.run(["timeout", "10", "systemctl", "--user", "list-units", "--type=service", "--all", "--output=json", "--no-pager"]);
        }
    }

    Cmd {
        id: list
        onFinished: (code, out, err) => {
            const parsed = code === 0 ? Model.parseUnits(out) : null;
            if (parsed === null) {
                page.errorMessage = code === 124 ? "systemctl --user timed out." : Model.clip(err || "Could not list user services.", 300);
                return;
            }
            page.units = Model.withInstalled(parsed, page._filesText);
            page.loaded = true;
            if (page.units.some(u => Model.isTransitioning(u)))
                settle.restart();
        }
    }

    Cmd {
        id: mem
        onFinished: (code, out) => page.memory = code === 0 ? Model.parseMemory(out) : ({})
    }

    Cmd {
        id: action
        onFinished: (code, out, err) => {
            const name = Model.displayName(page.busyUnit);
            if (code === 0) {
                page.statusMessage = `${page.busyVerb === "stop" ? "Stopped" : (page.busyVerb === "start" ? "Started" : "Restarted")} ${name}`;
                clearStatus.restart();
            } else {
                page.errorMessage = code === 124 ? `Timed out trying to ${page.busyVerb} ${name}.` : Model.clip(err || `Could not ${page.busyVerb} ${name}.`, 300);
            }
            const unit = page.busyUnit;
            page.busyUnit = "";
            page.busyVerb = "";
            page.refresh();
            if (page.logUnit === unit)
                page.loadLogs();
        }
    }

    Cmd {
        id: logs
        onFinished: (code, out, err) => page.logText = (out || err || "").trim() || "No journal entries."
    }

    Timer {
        id: settle
        interval: 3000
        onTriggered: page.refresh()
    }

    Timer {
        id: clearStatus
        interval: 4000
        onTriggered: page.statusMessage = ""
    }

    // ---- UI ---------------------------------------------------------------

    headerTrailing: [
        Btn {
            text: "Refresh"
            icon: Icons.refresh
            busy: list.running || files.running
            onClicked: page.refresh()
        }
    ]

    Banner {
        text: page.statusMessage
        kind: "info"
    }
    Banner {
        text: page.errorMessage
        kind: "error"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Field {
            id: filter
            Layout.fillWidth: true
            placeholder: "Filter services"
            onTextChanged: page.query = text
        }
        Label {
            text: "Show stopped"
            color: Theme.textDim
        }
        Toggle {
            checked: page.showInactive
            onToggled: page.showInactive = !page.showInactive
        }
    }

    Card {
        SettingRow {
            visible: page.loaded && page.shown.length === 0
            first: true
            icon: Icons.cog
            title: page.query !== "" ? "No matching services" : "No running services"
            subtitle: page.showInactive ? "" : "Turn on \"Show stopped\" to see every installed service."
        }

        Repeater {
            model: page.shown
            delegate: ColumnLayout {
                id: row
                required property var modelData
                required property int index
                readonly property var u: modelData
                readonly property bool running: Model.isRunning(u)
                readonly property bool busy: page.busyUnit === u.unit
                readonly property bool logsOpen: page.logUnit === u.unit
                Layout.fillWidth: true
                spacing: 0

                SettingRow {
                    first: row.index === 0
                    title: Model.displayName(row.u.unit)
                    titleColor: row.u.active === "failed" ? Theme.danger : Theme.brightForeground
                    subtitle: [row.u.description, Model.extraSub(row.u), Model.formatBytes(page.memory[row.u.unit])].filter(s => s && s !== "").join("  ·  ")

                    Badge {
                        text: row.busy ? page.busyVerb + "…" : Model.stateLabel(row.u)
                        tone: row.running ? "accent" : "neutral"
                    }
                    Btn {
                        text: row.running ? "Stop" : "Start"
                        kind: row.running ? "danger" : "neutral"
                        enabled: page.busyUnit === ""
                        busy: row.busy && page.busyVerb !== "restart"
                        onClicked: page.act(row.running ? "stop" : "start", row.u.unit)
                    }
                    Btn {
                        text: "Restart"
                        visible: row.running
                        enabled: page.busyUnit === ""
                        busy: row.busy && page.busyVerb === "restart"
                        onClicked: page.act("restart", row.u.unit)
                    }
                    Btn {
                        text: "Logs"
                        kind: row.logsOpen ? "primary" : "neutral"
                        onClicked: page.toggleLogs(row.u.unit)
                    }
                }

                Rectangle {
                    visible: row.logsOpen
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pad
                    Layout.rightMargin: Theme.pad
                    Layout.bottomMargin: 12
                    Layout.preferredHeight: Math.min(logView.contentHeight + 20, 320)
                    radius: Theme.radiusSmall
                    color: Theme.background
                    border.width: 1
                    border.color: Theme.border

                    Flickable {
                        id: logView
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true
                        contentWidth: width
                        contentHeight: logEdit.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        // Newest lines are at the bottom.
                        onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                        TextEdit {
                            id: logEdit
                            width: logView.width
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            text: logs.running && page.logText === "" ? "Loading…" : page.logText
                            color: Theme.foreground
                            selectionColor: Theme.selection
                            selectedTextColor: Theme.selectionForeground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsSmall
                        }
                    }
                }
            }
        }
    }
}
