// Dev services: rootless Docker containers (start/stop/restart/logs) and TCP
// listeners on this machine (port, address, process, open in browser).
//
// No polling: re-read when shown, after each action and on Refresh; one
// follow-up read while a container is restarting.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "DevServicesModel.js" as Model

Page {
    id: page
    title: "Dev services"
    subtitle: (dockerError !== "" ? "Docker unavailable" : `${runningCount} of ${containers.length} containers running`) + `  ·  ${listeners.length} listening ports`

    property var containers: []
    property var listeners: []
    property bool dockerLoaded: false
    property string dockerError: ""
    property string errorMessage: ""
    property string statusMessage: ""
    property string busyName: ""
    property string busyVerb: ""
    property string logName: ""
    property string logText: ""

    readonly property int runningCount: containers.filter(c => c.state === "running").length
    readonly property var portOwners: Model.publishedPorts(containers)
    // Rootless docker sets DOCKER_HOST in login shells; a session started
    // without it would otherwise look for the root daemon's socket.
    readonly property var dockerEnv: Quickshell.env("DOCKER_HOST") ? ({}) : ({
            DOCKER_HOST: `unix://${Quickshell.env("XDG_RUNTIME_DIR")}/docker.sock`
        })

    function refresh() {
        ps.run(["timeout", "10", "docker", "ps", "-a", "--format", Model.PS_FORMAT]);
        ss.run(["timeout", "10", "ss", "-ltnpH"]);
    }

    function act(verb, name) {
        if (busyName !== "")
            return;
        page.errorMessage = "";
        page.statusMessage = "";
        page.busyName = name;
        page.busyVerb = verb;
        action.run(["timeout", "60", "docker", verb, "--", name]);
    }

    function toggleLogs(name) {
        if (logName === name) {
            logName = "";
            logs.running = false;
            return;
        }
        logName = name;
        logText = "";
        loadLogs();
    }

    function loadLogs() {
        if (logName !== "")
            logs.run(["timeout", "10", "sh", "-c", 'docker logs --tail 50 -- "$1" 2>&1', "sh", logName]);
    }

    function stopAll() {
        settle.stop();
        clearStatus.stop();
        for (const c of [ps, ss, action, logs])
            c.running = false;
    }

    Component.onCompleted: refresh()
    Component.onDestruction: stopAll()
    onVisibleChanged: visible ? refresh() : stopAll()

    // ---- plumbing ---------------------------------------------------------

    Cmd {
        id: ps
        environment: page.dockerEnv
        onFinished: (code, out, err) => {
            page.dockerLoaded = true;
            if (code !== 0) {
                page.dockerError = Model.friendlyDockerError(code, err);
                page.containers = [];
                return;
            }
            page.dockerError = "";
            page.containers = Model.parseContainers(out);
            if (page.containers.some(c => c.state === "restarting" || c.state === "removing"))
                settle.restart();
        }
    }

    Cmd {
        id: ss
        onFinished: (code, out, err) => {
            if (code !== 0)
                page.errorMessage = Model.clip(err || "ss failed.", 300);
            else
                page.listeners = Model.parseListeners(out);
        }
    }

    Cmd {
        id: action
        environment: page.dockerEnv
        onFinished: (code, out, err) => {
            if (code === 0) {
                page.statusMessage = `${page.busyVerb === "stop" ? "Stopped" : (page.busyVerb === "start" ? "Started" : "Restarted")} ${page.busyName}`;
                clearStatus.restart();
            } else {
                page.errorMessage = code === 124 ? `Timed out trying to ${page.busyVerb} ${page.busyName}.` : Model.clip(err || `Could not ${page.busyVerb} ${page.busyName}.`, 300);
            }
            const name = page.busyName;
            page.busyName = "";
            page.busyVerb = "";
            page.refresh();
            if (page.logName === name)
                page.loadLogs();
        }
    }

    Cmd {
        id: logs
        environment: page.dockerEnv
        onFinished: (code, out) => page.logText = out.trim() || "No log output."
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
            busy: ps.running || ss.running
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

    SectionLabel {
        text: "Containers"
    }
    Card {
        SettingRow {
            visible: page.dockerLoaded && page.dockerError !== ""
            first: true
            icon: Icons.close
            iconColor: Theme.textDim
            title: "Docker is unavailable"
            subtitle: page.dockerError
        }
        SettingRow {
            visible: page.dockerLoaded && page.dockerError === "" && page.containers.length === 0
            first: true
            icon: Icons.rocket
            title: "No containers"
            subtitle: "Containers created with docker or docker compose show up here."
        }
        SettingRow {
            visible: !page.dockerLoaded
            first: true
            title: "Loading…"
        }

        Repeater {
            model: page.containers
            delegate: ColumnLayout {
                id: row
                required property var modelData
                required property int index
                readonly property var c: modelData
                readonly property bool running: c.state === "running" || c.state === "restarting"
                readonly property bool busy: page.busyName === c.name
                readonly property bool logsOpen: page.logName === c.name
                Layout.fillWidth: true
                spacing: 0

                SettingRow {
                    first: row.index === 0
                    title: row.c.name
                    subtitle: [row.c.image, row.c.status, Model.portSummary(row.c.ports)].filter(s => s !== "").join("  ·  ")

                    Badge {
                        text: row.busy ? page.busyVerb + "…" : (row.c.state === "exited" || row.c.state === "created" ? "Stopped" : row.c.state.charAt(0).toUpperCase() + row.c.state.slice(1))
                        tone: row.c.state === "running" ? "accent" : "neutral"
                    }
                    Btn {
                        text: row.running ? "Stop" : "Start"
                        kind: row.running ? "danger" : "neutral"
                        enabled: page.busyName === "" && row.c.state !== "paused"
                        busy: row.busy && page.busyVerb !== "restart"
                        onClicked: page.act(row.running ? "stop" : "start", row.c.name)
                    }
                    Btn {
                        text: "Restart"
                        visible: row.running
                        enabled: page.busyName === ""
                        busy: row.busy && page.busyVerb === "restart"
                        onClicked: page.act("restart", row.c.name)
                    }
                    Btn {
                        text: "Logs"
                        kind: row.logsOpen ? "primary" : "neutral"
                        onClicked: page.toggleLogs(row.c.name)
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

    SectionLabel {
        text: "Listening ports"
    }
    Card {
        SettingRow {
            visible: page.listeners.length === 0
            first: true
            icon: Icons.plug
            title: "Nothing is listening"
            subtitle: "TCP servers started on this machine show up here."
        }

        Repeater {
            model: page.listeners
            delegate: SettingRow {
                id: lrow
                required property var modelData
                required property int index
                readonly property string owner: page.portOwners[modelData.port] || ""
                first: index === 0
                minHeight: 50
                title: ":" + modelData.port
                // Processes owned by other users have no name in ss output.
                subtitle: [Model.scopeLabel(modelData.scope) + " (" + modelData.hosts.join(", ") + ")", owner !== "" ? "container " + owner : (modelData.process !== "" ? modelData.process + " [" + modelData.pid + "]" : "")].filter(s => s !== "").join("  ·  ")

                Btn {
                    text: "Open"
                    onClicked: Quickshell.execDetached(["xdg-open", "http://localhost:" + lrow.modelData.port])
                }
            }
        }
    }
}
