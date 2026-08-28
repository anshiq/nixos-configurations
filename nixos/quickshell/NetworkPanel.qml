// Native NetworkManager panel - the replacement for the old "click the bar
// and hope nm-applet's menu appears" approach.
//
// WHY THIS EXISTS AT ALL:
// The previous NetworkWidget.qml looked up nm-applet in SystemTray.items and
// called SystemTrayItem.display(). That renders a *native platform menu* out
// of nm-applet's DBusMenu export, which needs `//@ pragma UseQApplication`
// AND a tray app whose menu survives the round trip. nm-applet's does not:
// its wifi list is a GTK menu built on the fly with submenus and custom
// widgets, and driving it through Qt's platform-menu bridge is a known dead
// end (unresolved upstream, see the Hyprland forum thread "Unable to get
// nm-applet menu working on QuickShell"). Adding the pragma silenced the
// error in the log but never made a menu appear, which is why this looked
// "fixed" and wasn't.
//
// So this talks to NetworkManager directly via nmcli and draws the list
// itself - the same approach every mature Quickshell config takes (caelestia,
// DankMaterialShell, noctalia all drive nmcli/NM rather than proxying an
// applet). No nm-applet dependency, no DBusMenu, nothing to render but our
// own QML.
//
// Lives as a sibling under ShellRoot (shell.qml) and is opened over IPC by
// plugins/user.network/NetworkWidget.qml - the same pattern PowerMenu.qml
// uses, since bar plugins can't hold a direct reference to a sibling window.
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
    WlrLayershell.namespace: "quickshell-network"

    property bool wifiEnabled: true
    property var networks: []          // [{ ssid, signal, security, inUse, known }]
    property var knownSsids: []
    property string busyMessage: ""
    property string errorMessage: ""
    // SSID currently showing an inline password prompt ("" = none).
    property string passwordFor: ""

    IpcHandler {
        target: "network"

        function open(): void {
            root.openPanel();
        }
        function close(): void {
            root.visible = false;
        }
        function toggle(): void {
            if (root.visible)
                root.visible = false;
            else
                root.openPanel();
        }
    }

    function openPanel() {
        root.passwordFor = "";
        root.errorMessage = "";
        root.visible = true;
        refresh();
    }

    function refresh() {
        radioProc.running = true;
        knownProc.running = true;
        listProc.running = true;
    }

    // nmcli -t escapes a literal ':' inside a field as '\:' (and a literal
    // '\' as '\\'), so a plain String.split(":") corrupts any SSID containing
    // a colon and silently shifts every field after it. Split on unescaped
    // separators only.
    function splitTerse(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                cur += line[++i];
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    // nf-md-wifi_strength_1..4, as codepoints rather than literals: these
    // live in the U+F09xx Material Design block that NetworkWidget.qml's
    // wifi/wifi-off glyphs also come from. The visually similar U+F11xx
    // glyphs are an unrelated icon set and render as gibberish in
    // JetBrainsMono Nerd Font (which is exactly what they did here first
    // time round). A \\u escape can't express them - it only takes four hex
    // digits - so build them with fromCodePoint.
    function iconFor(signal) {
        if (signal >= 75)
            return String.fromCodePoint(0xF0928); // strength 4
        if (signal >= 50)
            return String.fromCodePoint(0xF0925); // strength 3
        if (signal >= 25)
            return String.fromCodePoint(0xF0922); // strength 2
        return String.fromCodePoint(0xF091F); // strength 1
    }

    function connect(net, password) {
        root.errorMessage = "";
        root.busyMessage = `Connecting to ${net.ssid}...`;
        root.passwordFor = "";
        if (password && password.length > 0) {
            // `nmcli device wifi connect` creates the profile on first use and
            // reuses it afterwards, so this one call covers both cases.
            connectProc.command = ["nmcli", "device", "wifi", "connect", net.ssid, "password", password];
        } else if (net.known) {
            connectProc.command = ["nmcli", "connection", "up", "id", net.ssid];
        } else {
            connectProc.command = ["nmcli", "device", "wifi", "connect", net.ssid];
        }
        connectProc.running = true;
    }

    function activate(net) {
        // A secured network we have no saved profile for is the only case
        // that needs a password typed - everything else NM can do on its own.
        if (net.secured && !net.known)
            root.passwordFor = net.ssid;
        else
            connect(net, "");
    }

    function disconnect(ssid) {
        root.busyMessage = "Disconnecting...";
        connectProc.command = ["nmcli", "connection", "down", "id", ssid];
        connectProc.running = true;
    }

    // ---- nmcli plumbing -----------------------------------------------

    property var radioLines: []
    Process {
        id: radioProc
        command: ["nmcli", "-t", "radio", "wifi"]
        stdout: SplitParser {
            onRead: line => root.radioLines.push(line)
        }
        onExited: {
            root.wifiEnabled = root.radioLines.some(l => l.trim() === "enabled");
            root.radioLines = [];
        }
    }

    property var knownLines: []
    Process {
        id: knownProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: SplitParser {
            onRead: line => root.knownLines.push(line)
        }
        onExited: {
            const known = [];
            for (const l of root.knownLines) {
                if (!l)
                    continue;
                const f = root.splitTerse(l);
                if (f[1] && f[1].indexOf("wireless") !== -1)
                    known.push(f[0]);
            }
            root.knownLines = [];
            root.knownSsids = known;
        }
    }

    property var listLines: []
    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        stdout: SplitParser {
            onRead: line => root.listLines.push(line)
        }
        onExited: {
            const seen = {};
            const nets = [];
            for (const l of root.listLines) {
                if (!l)
                    continue;
                const f = root.splitTerse(l);
                const ssid = f[1] || "";
                // Hidden networks come back with an empty SSID and can't be
                // joined by name, so there is nothing useful to show for them.
                if (!ssid)
                    continue;
                // The same SSID shows up once per AP/band; keep the strongest.
                const signal = parseInt(f[2] || "0", 10) || 0;
                if (seen[ssid] !== undefined) {
                    if (signal > nets[seen[ssid]].signal)
                        nets[seen[ssid]].signal = signal;
                    continue;
                }
                const security = (f[3] || "").trim();
                seen[ssid] = nets.length;
                nets.push({
                    ssid: ssid,
                    signal: signal,
                    security: security,
                    secured: security.length > 0 && security !== "--",
                    inUse: (f[0] || "").trim() === "*",
                    known: root.knownSsids.indexOf(ssid) !== -1
                });
            }
            root.listLines = [];
            nets.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal));
            root.networks = nets;
            root.busyMessage = "";
        }
    }

    property var connectErr: []
    Process {
        id: connectProc
        stdout: SplitParser {
            onRead: line => root.connectErr.push(line)
        }
        stderr: SplitParser {
            onRead: line => root.connectErr.push(line)
        }
        onExited: exitCode => {
            const out = root.connectErr.join(" ").trim();
            root.connectErr = [];
            root.busyMessage = "";
            // nmcli prints the reason on stderr and exits non-zero - surface
            // it instead of leaving the panel looking like nothing happened,
            // which is what made the old menu so hard to debug.
            root.errorMessage = exitCode === 0 ? "" : (out || "Connection failed");
            refresh();
        }
    }

    Process {
        id: radioToggleProc
        onExited: root.refresh()
    }

    Process {
        id: rescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        // A rescan in progress makes nmcli exit non-zero; the list below is
        // still worth refreshing either way.
        onExited: root.refresh()
    }

    // Re-poll while open so signal strength and connection state stay honest.
    Timer {
        interval: 10000
        running: root.visible
        repeat: true
        onTriggered: root.refresh()
    }

    // ---- UI -----------------------------------------------------------

    // Click-outside-to-close. Sits under the panel so it only catches clicks
    // that miss it.
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.visible = false
    }

    Rectangle {
        id: panel
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 22 // clears the bar (Bar.qml implicitHeight 18 + gap)
            rightMargin: 6
        }
        width: 320
        height: Math.min(460, header.height + listView.contentHeight + footer.height + 24)
        radius: 8
        color: Colors.background
        border.width: 1
        border.color: Colors.muted

        // Swallow clicks so they don't reach the close-on-click layer above.
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: header
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 10
            }
            height: 22

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Wi-Fi"
                color: Colors.brightForeground
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true
            }

            Row {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 10

                Text {
                    text: "" // nf-fa-refresh
                    color: rescanArea.containsMouse ? Colors.accent : Colors.foreground
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    MouseArea {
                        id: rescanArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: {
                            root.busyMessage = "Scanning...";
                            rescanProc.running = true;
                        }
                    }
                }

                Text {
                    text: String.fromCodePoint(root.wifiEnabled ? 0xF05A9 : 0xF05AA)
                    color: root.wifiEnabled ? Colors.green : Colors.red
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: {
                            radioToggleProc.command = ["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"];
                            radioToggleProc.running = true;
                        }
                    }
                }
            }
        }

        ListView {
            id: listView
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                bottom: footer.top
                topMargin: 6
                leftMargin: 4
                rightMargin: 4
            }
            clip: true
            model: root.networks
            spacing: 1

            delegate: Item {
                id: row
                required property var modelData
                width: ListView.view.width
                height: row.modelData.ssid === root.passwordFor ? 58 : 28

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 4
                    color: rowArea.containsMouse || row.modelData.inUse ? Colors.selection : "transparent"
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (row.modelData.inUse)
                            root.disconnect(row.modelData.ssid);
                        else
                            root.activate(row.modelData);
                    }
                }

                Row {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        leftMargin: 8
                        rightMargin: 8
                    }
                    height: 28
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.iconFor(row.modelData.signal)
                        color: row.modelData.inUse ? Colors.green : Colors.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 60
                        elide: Text.ElideRight
                        text: row.modelData.ssid
                        color: row.modelData.inUse ? Colors.brightForeground : Colors.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.bold: row.modelData.inUse
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.secured ? "" : "" // nf-fa-lock
                        color: Colors.muted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                    }
                }

                // Inline password entry, shown only for a secured network we
                // have no saved profile for.
                Rectangle {
                    visible: row.modelData.ssid === root.passwordFor
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        leftMargin: 8
                        rightMargin: 8
                        bottomMargin: 4
                    }
                    height: 24
                    radius: 4
                    color: Colors.background
                    border.width: 1
                    border.color: Colors.accent

                    TextField {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        echoMode: TextInput.Password
                        placeholderText: "Password, then Enter"
                        color: Colors.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        background: null
                        // Grab focus the moment the field appears, so the user
                        // can just type.
                        onVisibleChanged: if (visible)
                            forceActiveFocus()
                        onAccepted: root.connect(row.modelData, text)
                        Keys.onEscapePressed: root.passwordFor = ""
                    }
                }
            }
        }

        Text {
            id: footer
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 8
            }
            height: text.length > 0 ? implicitHeight : 0
            wrapMode: Text.Wrap
            text: root.errorMessage || root.busyMessage || (root.wifiEnabled ? "" : "Wi-Fi is off")
            color: root.errorMessage ? Colors.red : Colors.muted
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
        }
    }
}
