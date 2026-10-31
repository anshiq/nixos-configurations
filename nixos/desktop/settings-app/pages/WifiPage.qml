// Wi-Fi: radio switch, current connection (+details), nearby networks with
// inline password entry, hidden networks, wired status.
//
// Drives NetworkManager through nmcli, like quickshell/NetworkPanel.qml (the
// bar dropdown): it is proven on this machine, reports human-readable
// failures on stderr, and covers hidden SSIDs and forgetting profiles, which
// Quickshell.Networking's WifiNetwork API does not expose.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Page {
    id: page
    title: "Wi-Fi"
    subtitle: !hasWifi ? "No Wi-Fi adapter found" : (!wifiEnabled ? "Wi-Fi is turned off" : (active ? "Connected to " + active.ssid : (connecting ? "Connecting…" : "Not connected")))

    property bool wifiEnabled: true
    property string wifiDevice: ""
    property string wifiState: ""
    property string ethDevice: ""
    property string ethState: ""
    property var networks: []
    property var savedSsids: []
    property var detail: ({})
    property string errorMessage: ""
    property string busyMessage: ""
    property string passwordFor: ""
    property bool hiddenOpen: false
    // Set while a connect attempt is in flight: whether the profile existed
    // before the attempt, so a failed *first* attempt can clean up after itself.
    property string attemptSsid: ""
    property bool attemptWasNew: false

    readonly property bool hasWifi: wifiDevice !== ""
    readonly property bool connecting: wifiState.indexOf("connecting") === 0
    readonly property var active: networks.find(n => n.inUse) || null
    readonly property var others: networks.filter(n => !n.inUse)
    readonly property bool working: act.running || cleanup.running

    // nmcli -t escapes ':' inside a field as '\:' and '\' as '\\'; a plain
    // split(":") would corrupt any SSID containing a colon.
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

    function friendlyError(raw) {
        const t = (raw || "").trim();
        if (/secrets were required|\(7\)|password|authenticat/i.test(t))
            return "Wrong password, or the network refused the login.";
        if (/no network with ssid|not found/i.test(t))
            return "That network is no longer in range.";
        if (/timeout|timed out/i.test(t))
            return "Timed out while connecting.";
        return t !== "" ? t : "Connection failed.";
    }

    function refresh() {
        radio.run(["nmcli", "-t", "radio", "wifi"]);
        devs.run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"]);
        saved.run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]);
        list.run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,RATE,CHAN", "device", "wifi", "list"]);
        if (wifiDevice !== "")
            info.run(["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "device", "show", wifiDevice]);
    }

    function rescan() {
        scan.run(["nmcli", "device", "wifi", "rescan"]);
    }

    function connectTo(ssid, password, known, hidden) {
        page.errorMessage = "";
        page.busyMessage = `Connecting to ${ssid}…`;
        page.passwordFor = "";
        page.attemptSsid = ssid;
        page.attemptWasNew = !known;
        let args;
        if (password && password.length > 0) {
            // Creates the profile on first use and reuses it afterwards.
            args = ["nmcli", "device", "wifi", "connect", ssid, "password", password];
            if (hidden)
                args = args.concat(["hidden", "yes"]);
        } else if (known) {
            args = ["nmcli", "connection", "up", "id", ssid];
        } else {
            args = ["nmcli", "device", "wifi", "connect", ssid];
        }
        act.run(args);
    }

    function activate(net) {
        if (page.working)
            return;
        // A secured network with no saved profile is the only case that needs
        // a password typed; everything else NetworkManager can do on its own.
        if (net.secured && !net.known)
            page.passwordFor = page.passwordFor === net.ssid ? "" : net.ssid;
        else
            connectTo(net.ssid, "", net.known, false);
    }

    function forget(ssid) {
        page.errorMessage = "";
        page.busyMessage = `Forgetting ${ssid}…`;
        act.run(["nmcli", "connection", "delete", "id", ssid]);
        page.attemptSsid = "";
    }

    Component.onCompleted: {
        refresh();
        rescan();
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: page.refresh()
    }

    // The scan itself takes a couple of seconds to land in `device wifi list`.
    Timer {
        id: afterScan
        interval: 2500
        onTriggered: page.refresh()
    }

    // ---- nmcli plumbing -------------------------------------------------

    Cmd {
        id: radio
        onFinished: (code, out) => page.wifiEnabled = out.trim() === "enabled"
    }

    Cmd {
        id: devs
        onFinished: (code, out) => {
            let wifi = "", wifiState = "", eth = "", ethState = "";
            for (const l of out.split("\n")) {
                const f = page.splitTerse(l);
                if (f[1] === "wifi" && wifi === "") {
                    wifi = f[0];
                    wifiState = f[2] || "";
                } else if (f[1] === "ethernet" && eth === "") {
                    eth = f[0];
                    ethState = f[2] || "";
                }
            }
            page.wifiDevice = wifi;
            page.wifiState = wifiState;
            page.ethDevice = eth;
            page.ethState = ethState;
        }
    }

    Cmd {
        id: saved
        onFinished: (code, out) => {
            const names = [];
            for (const l of out.split("\n")) {
                const f = page.splitTerse(l);
                if (f[0] && f[1] && f[1].indexOf("wireless") !== -1)
                    names.push(f[0]);
            }
            page.savedSsids = names;
        }
    }

    Cmd {
        id: list
        onFinished: (code, out) => {
            const seen = {};
            const nets = [];
            for (const l of out.split("\n")) {
                if (!l)
                    continue;
                const f = page.splitTerse(l);
                const ssid = f[1] || "";
                // Hidden networks have an empty SSID and cannot be joined by
                // name from a list; "Hidden network…" below covers them.
                if (!ssid)
                    continue;
                const signal = parseInt(f[2] || "0", 10) || 0;
                const inUse = (f[0] || "").trim() === "*";
                // One SSID shows up once per AP/band: keep the strongest, but
                // never lose the in-use flag.
                if (seen[ssid] !== undefined) {
                    const prev = nets[seen[ssid]];
                    if (signal > prev.signal) {
                        prev.signal = signal;
                        prev.rate = f[4] || prev.rate;
                        prev.chan = parseInt(f[5] || "0", 10) || prev.chan;
                    }
                    prev.inUse = prev.inUse || inUse;
                    continue;
                }
                const security = (f[3] || "").trim();
                seen[ssid] = nets.length;
                nets.push({
                    ssid: ssid,
                    signal: signal,
                    security: security === "--" ? "" : security,
                    secured: security.length > 0 && security !== "--",
                    inUse: inUse,
                    rate: f[4] || "",
                    chan: parseInt(f[5] || "0", 10) || 0
                });
            }
            nets.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal));
            page.networks = nets;
        }
    }

    Cmd {
        id: info
        onFinished: (code, out) => {
            const d = {
                ip: [],
                gateway: "",
                dns: []
            };
            for (const l of out.split("\n")) {
                const m = l.match(/^([A-Z0-9.]+)(?:\[\d+\])?:(.*)$/);
                if (!m)
                    continue;
                if (m[1] === "IP4.ADDRESS")
                    d.ip.push(m[2]);
                else if (m[1] === "IP4.GATEWAY")
                    d.gateway = m[2];
                else if (m[1] === "IP4.DNS")
                    d.dns.push(m[2]);
            }
            page.detail = d;
        }
    }

    Cmd {
        id: scan
        // "Scanning not allowed immediately following previous scan" is
        // normal and harmless - the list refresh below still picks up NM's own
        // fresher results, so the exit code is deliberately ignored.
        onFinished: afterScan.restart()
    }

    Cmd {
        id: act
        onFinished: (code, out, err) => {
            page.busyMessage = "";
            if (code === 0) {
                page.errorMessage = "";
            } else {
                page.errorMessage = page.friendlyError(err || out);
                // A failed first attempt leaves a half-made profile behind
                // (saved with the wrong password); remove it so the network
                // is offered a fresh password prompt next time.
                if (page.attemptWasNew && page.attemptSsid !== "")
                    cleanup.run(["nmcli", "connection", "delete", "id", page.attemptSsid]);
            }
            page.attemptSsid = "";
            page.refresh();
        }
    }

    Cmd {
        id: cleanup
        onFinished: page.refresh()
    }

    // ---- UI -------------------------------------------------------------

    headerTrailing: [
        Toggle {
            visible: page.hasWifi
            checked: page.wifiEnabled
            busy: radioSwitch.running
            onToggled: {
                page.errorMessage = "";
                radioSwitch.run(["nmcli", "radio", "wifi", page.wifiEnabled ? "off" : "on"]);
            }
            Cmd {
                id: radioSwitch
                onFinished: {
                    page.refresh();
                    afterScan.restart();
                }
            }
        }
    ]

    Banner {
        text: page.busyMessage
        kind: "info"
    }
    Banner {
        text: page.errorMessage
        kind: "error"
    }

    Card {
        visible: !page.hasWifi
        SettingRow {
            first: true
            icon: Icons.wifiOff
            title: "No Wi-Fi adapter"
            subtitle: "NetworkManager did not report a wireless device."
        }
    }

    Card {
        visible: page.hasWifi && !page.wifiEnabled
        SettingRow {
            first: true
            icon: Icons.wifiOff
            title: "Wi-Fi is off"
            subtitle: "Turn it on to see and join nearby networks."
        }
    }

    // --- current connection
    SectionLabel {
        visible: page.hasWifi && page.wifiEnabled && page.active !== null
        text: "Connected"
    }
    Card {
        visible: page.hasWifi && page.wifiEnabled && page.active !== null

        SettingRow {
            first: true
            title: page.active ? page.active.ssid : ""
            subtitle: page.active ? [page.active.security || "Open", page.active.chan >= 36 ? "5 GHz" : "2.4 GHz", page.active.signal + "% signal"].join("  ·  ") : ""
            leading: [
                SignalBars {
                    strength: page.active ? page.active.signal : 0
                    Layout.rightMargin: 12
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 20
                }
            ]
            Badge {
                text: "Connected"
                tone: "accent"
            }
            Btn {
                text: "Disconnect"
                enabled: !page.working
                onClicked: {
                    page.errorMessage = "";
                    page.busyMessage = "Disconnecting…";
                    act.run(["nmcli", "device", "disconnect", page.wifiDevice]);
                    page.attemptWasNew = false;
                }
            }
            Btn {
                text: "Forget"
                kind: "danger"
                enabled: !page.working && page.active !== null && page.savedSsids.indexOf(page.active.ssid) !== -1
                onClicked: page.forget(page.active.ssid)
            }
        }

        SettingRow {
            visible: !!(page.detail.ip && page.detail.ip.length > 0)
            minHeight: 44
            title: "IP address"
            Label {
                text: page.detail.ip ? page.detail.ip.join(", ") : ""
                color: Theme.textDim
            }
        }
        SettingRow {
            visible: !!page.detail.gateway
            minHeight: 44
            title: "Gateway"
            Label {
                text: page.detail.gateway || ""
                color: Theme.textDim
            }
        }
        SettingRow {
            visible: !!(page.detail.dns && page.detail.dns.length > 0)
            minHeight: 44
            title: "DNS"
            Label {
                text: page.detail.dns ? page.detail.dns.join(", ") : ""
                color: Theme.textDim
            }
        }
        SettingRow {
            visible: !!(page.active && page.active.rate !== "")
            minHeight: 44
            title: "Link speed"
            Label {
                text: page.active ? page.active.rate : ""
                color: Theme.textDim
            }
        }
    }

    // --- nearby networks
    RowLayout {
        visible: page.hasWifi && page.wifiEnabled
        Layout.fillWidth: true
        SectionLabel {
            text: page.active ? "Other networks" : "Available networks"
            Layout.fillWidth: true
        }
        Btn {
            text: "Rescan"
            icon: Icons.refresh
            busy: scan.running || afterScan.running
            onClicked: page.rescan()
        }
    }

    Card {
        visible: page.hasWifi && page.wifiEnabled

        SettingRow {
            visible: page.others.length === 0
            first: true
            icon: Icons.wifiOff
            title: "No networks found"
            subtitle: "Move closer to an access point, or press Rescan."
        }

        Repeater {
            model: page.others
            delegate: ColumnLayout {
                id: net
                required property var modelData
                required property int index
                readonly property bool known: page.savedSsids.indexOf(modelData.ssid) !== -1
                readonly property bool asking: page.passwordFor === modelData.ssid
                Layout.fillWidth: true
                spacing: 0

                SettingRow {
                    first: net.index === 0
                    clickable: !page.working
                    title: net.modelData.ssid
                    subtitle: net.modelData.security || "Open"
                    leading: [
                        SignalBars {
                            strength: net.modelData.signal
                            Layout.rightMargin: 12
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 20
                        }
                    ]
                    onClicked: page.activate(net.modelData)

                    Glyph {
                        visible: net.modelData.secured
                        text: Icons.lock
                        color: Theme.textDim
                        font.pixelSize: 15
                    }
                    Badge {
                        visible: net.known
                        text: "Saved"
                    }
                    Btn {
                        visible: net.known
                        text: "Forget"
                        enabled: !page.working
                        onClicked: page.forget(net.modelData.ssid)
                    }
                }

                RowLayout {
                    visible: net.asking
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pad + 34
                    Layout.rightMargin: Theme.pad
                    Layout.bottomMargin: 14
                    spacing: 8
                    Field {
                        id: pw
                        Layout.fillWidth: true
                        password: true
                        placeholder: `Password for ${net.modelData.ssid}`
                        onAccepted: if (text.length > 0)
                            page.connectTo(net.modelData.ssid, text, false, false)
                    }
                    Btn {
                        text: "Connect"
                        kind: "primary"
                        enabled: pw.text.length > 0 && !page.working
                        onClicked: page.connectTo(net.modelData.ssid, pw.text, false, false)
                    }
                    Btn {
                        text: "Cancel"
                        onClicked: page.passwordFor = ""
                    }
                    onVisibleChanged: if (visible) {
                        pw.text = "";
                        pw.focusInput();
                    }
                }
            }
        }
    }

    // --- everything else
    SectionLabel {
        text: "More"
    }
    Card {
        SettingRow {
            visible: page.hasWifi && page.wifiEnabled
            first: true
            icon: Icons.plus
            title: "Connect to a hidden network"
            subtitle: "For networks that do not broadcast their name"
            clickable: true
            onClicked: page.hiddenOpen = !page.hiddenOpen
        }

        ColumnLayout {
            visible: page.hiddenOpen && page.hasWifi && page.wifiEnabled
            Layout.fillWidth: true
            Layout.leftMargin: Theme.pad
            Layout.rightMargin: Theme.pad
            Layout.bottomMargin: 14
            spacing: 8
            Field {
                id: hiddenSsid
                Layout.fillWidth: true
                placeholder: "Network name (SSID)"
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Field {
                    id: hiddenPw
                    Layout.fillWidth: true
                    password: true
                    placeholder: "Password (leave empty if open)"
                    onAccepted: hiddenGo.clicked()
                }
                Btn {
                    id: hiddenGo
                    text: "Connect"
                    kind: "primary"
                    enabled: hiddenSsid.text.length > 0 && !page.working
                    onClicked: {
                        page.connectTo(hiddenSsid.text, hiddenPw.text, false, true);
                        page.hiddenOpen = false;
                        hiddenSsid.text = "";
                        hiddenPw.text = "";
                    }
                }
            }
        }

        SettingRow {
            first: !(page.hasWifi && page.wifiEnabled)
            visible: page.ethDevice !== ""
            icon: Icons.ethernet
            title: "Ethernet"
            subtitle: page.ethDevice
            Badge {
                text: page.ethState === "connected" ? "Connected" : (page.ethState === "unavailable" ? "No cable" : (page.ethState || "Unknown"))
                tone: page.ethState === "connected" ? "accent" : "neutral"
            }
        }

        SettingRow {
            icon: Icons.cog
            title: "Advanced network settings"
            subtitle: "VPN, static IP, DNS and saved profiles"
            clickable: true
            onClicked: Quickshell.execDetached(["nm-connection-editor"])
        }
    }
}
