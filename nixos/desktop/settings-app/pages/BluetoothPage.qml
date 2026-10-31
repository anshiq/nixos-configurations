// Bluetooth: adapter power, paired devices (connect / disconnect / forget),
// nearby devices (scan + pair), discoverability.
//
// State and actions go through Quickshell.Bluetooth (BlueZ over D-Bus, live
// updates, no polling). Pairing prompts are answered by BtAgent (see there).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import ".."

Page {
    id: page
    title: "Bluetooth"
    subtitle: !adapter ? "Bluetooth is unavailable" : (adapter.state === BluetoothAdapterState.Blocked ? "Bluetooth is blocked" : (adapter.enabled ? `Visible as “${adapter.name}”` : "Bluetooth is turned off"))

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter !== null && adapter.enabled
    readonly property var all: adapter ? adapter.devices.values : []

    function isPaired(d) {
        return d.paired || d.bonded;
    }
    // BlueZ aliases an unnamed device to its address with dashes.
    function isNamed(d) {
        return !!d.name && d.name !== d.address.replace(/:/g, "-");
    }

    readonly property var pairedDevices: all.filter(d => isPaired(d)).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearbyDevices: all.filter(d => !isPaired(d) && isNamed(d)).sort((a, b) => a.name.localeCompare(b.name))
    readonly property int unnamedCount: all.filter(d => !isPaired(d) && !isNamed(d)).length

    property var pairingDevice: null
    property string notice: ""

    function iconFor(d) {
        const i = d.icon || "";
        if (/headset|headphone/.test(i))
            return Icons.headphones;
        if (/audio|speaker/.test(i))
            return Icons.speaker;
        if (/keyboard/.test(i))
            return Icons.keyboard;
        if (/mouse|pointing/.test(i))
            return Icons.mouse;
        if (/gaming|joystick|gamepad/.test(i))
            return Icons.gamepad;
        if (/phone/.test(i))
            return Icons.phone;
        if (/computer|laptop/.test(i))
            return Icons.laptop;
        return Icons.bluetooth;
    }

    function batteryText(d) {
        if (!d.batteryAvailable)
            return "";
        const v = d.battery <= 1 ? d.battery * 100 : d.battery;
        return Math.round(v) + "% battery";
    }

    function statusText(d) {
        if (d.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (d.connected) {
            const b = batteryText(d);
            return b !== "" ? `Connected  ·  ${b}` : "Connected";
        }
        return "Not connected";
    }

    function pair(d) {
        page.notice = "";
        page.pairingDevice = d;
        pairTimeout.restart();
        d.pair();
    }

    function startScan() {
        if (adapter && adapter.enabled)
            adapter.discovering = true;
    }

    Component.onCompleted: startScan()
    Component.onDestruction: {
        if (adapter)
            adapter.discovering = false;
    }
    onPoweredChanged: if (powered)
        startScan()

    // pair() has no result callback: watch the device instead. On success make
    // it trusted (so it reconnects by itself later) and connect right away.
    Connections {
        target: page.pairingDevice
        ignoreUnknownSignals: true
        function onPairedChanged() {
            const d = page.pairingDevice;
            if (d && d.paired) {
                d.trusted = true;
                d.connect();
                page.pairingDevice = null;
                pairTimeout.stop();
                agent.clear();
            }
        }
        function onPairingChanged() {
            const d = page.pairingDevice;
            if (d && !d.pairing && !d.paired) {
                page.notice = `Could not pair with ${d.name}. Put it in pairing mode and try again.`;
                page.pairingDevice = null;
                pairTimeout.stop();
                agent.clear();
            }
        }
    }

    Timer {
        id: pairTimeout
        interval: 60000
        onTriggered: {
            if (page.pairingDevice) {
                page.notice = `Pairing with ${page.pairingDevice.name} timed out.`;
                page.pairingDevice = null;
                agent.clear();
            }
        }
    }

    BtAgent {
        id: agent
        active: page.adapter !== null
    }

    // A PIN/passkey prompt is useless until typed into: focus the field as it appears.
    Connections {
        target: agent
        function onKindChanged() {
            if (agent.kind === "pin" || agent.kind === "passkey") {
                codeField.text = "";
                codeField.focusInput();
            }
        }
    }

    headerTrailing: [
        Toggle {
            visible: page.adapter !== null
            checked: page.powered
            onToggled: page.adapter.enabled = !page.adapter.enabled
        }
    ]

    Banner {
        text: page.notice
        kind: "error"
    }
    Banner {
        text: page.adapter && page.adapter.state === BluetoothAdapterState.Blocked ? "Bluetooth is blocked by rfkill. Run `rfkill unblock bluetooth`, or use the hardware switch." : ""
        kind: "error"
    }

    Card {
        visible: page.adapter === null
        SettingRow {
            first: true
            icon: Icons.bluetoothOff
            title: "No Bluetooth adapter available"
            subtitle: "The Bluetooth service (bluez) is not running or no adapter was found. Check: systemctl status bluetooth"
            minHeight: 72
        }
    }

    // --- pairing prompt (from the agent)
    Card {
        visible: agent.kind !== ""
        SettingRow {
            first: true
            icon: Icons.bluetoothConnect
            title: agent.kind === "display" ? "Enter this code on the device" : (page.pairingDevice ? `Pair with ${page.pairingDevice.name}?` : "Pairing request")
            subtitle: agent.message
            minHeight: 72
            Label {
                visible: agent.code !== ""
                text: agent.code
                color: Theme.brightForeground
                font.pixelSize: 26
                font.bold: true
                font.letterSpacing: 4
            }
            Btn {
                visible: agent.kind === "confirm" || agent.kind === "authorize"
                text: "Cancel"
                onClicked: agent.reject()
            }
            Btn {
                visible: agent.kind === "confirm" || agent.kind === "authorize"
                text: agent.kind === "confirm" ? "Pair" : "Allow"
                kind: "primary"
                onClicked: agent.accept()
            }
        }
        RowLayout {
            visible: agent.kind === "pin" || agent.kind === "passkey"
            Layout.fillWidth: true
            Layout.leftMargin: Theme.pad
            Layout.rightMargin: Theme.pad
            Layout.bottomMargin: 14
            spacing: 8
            Field {
                id: codeField
                Layout.fillWidth: true
                placeholder: agent.kind === "pin" ? "PIN" : "Passkey"
                onAccepted: agent.submit(text)
            }
            Btn {
                text: "OK"
                kind: "primary"
                enabled: codeField.text.length > 0
                onClicked: agent.submit(codeField.text)
            }
            Btn {
                text: "Cancel"
                onClicked: agent.reject()
            }
        }
    }

    // --- paired devices
    SectionLabel {
        visible: page.adapter !== null && page.powered
        text: "My devices"
    }
    Card {
        visible: page.adapter !== null && page.powered

        SettingRow {
            visible: page.pairedDevices.length === 0
            first: true
            icon: Icons.bluetooth
            title: "No paired devices"
            subtitle: "Pair a device from the list below."
        }

        Repeater {
            model: page.pairedDevices
            delegate: SettingRow {
                id: dev
                required property var modelData
                required property int index
                property bool confirmForget: false

                first: index === 0
                icon: page.iconFor(modelData)
                iconColor: modelData.connected ? Theme.brightForeground : Theme.textDim
                title: modelData.name
                subtitle: page.statusText(modelData)

                Timer {
                    id: forgetReset
                    interval: 3000
                    onTriggered: dev.confirmForget = false
                }

                Btn {
                    text: dev.modelData.connected ? "Disconnect" : "Connect"
                    kind: dev.modelData.connected ? "neutral" : "primary"
                    busy: dev.modelData.state === BluetoothDeviceState.Connecting || dev.modelData.state === BluetoothDeviceState.Disconnecting
                    onClicked: dev.modelData.connected ? dev.modelData.disconnect() : dev.modelData.connect()
                }
                Btn {
                    text: dev.confirmForget ? "Really forget?" : "Forget"
                    kind: "danger"
                    onClicked: {
                        if (dev.confirmForget) {
                            dev.modelData.forget();
                        } else {
                            dev.confirmForget = true;
                            forgetReset.restart();
                        }
                    }
                }
            }
        }
    }

    // --- nearby devices
    RowLayout {
        visible: page.adapter !== null && page.powered
        Layout.fillWidth: true
        SectionLabel {
            text: "Nearby devices"
            Layout.fillWidth: true
        }
        Btn {
            text: page.adapter && page.adapter.discovering ? "Stop scanning" : "Scan"
            icon: Icons.refresh
            busy: page.adapter !== null && page.adapter.discovering
            onClicked: {
                if (page.adapter.discovering)
                    page.adapter.discovering = false;
                else
                    page.startScan();
            }
        }
    }
    Card {
        visible: page.adapter !== null && page.powered

        SettingRow {
            visible: page.nearbyDevices.length === 0
            first: true
            icon: Icons.bluetooth
            title: page.adapter && page.adapter.discovering ? "Searching for devices…" : "No devices found"
            subtitle: page.unnamedCount > 0 ? `${page.unnamedCount} unnamed device${page.unnamedCount === 1 ? "" : "s"} nearby are hidden. Put yours in pairing mode.` : "Put the device in pairing mode, then scan."
        }

        Repeater {
            model: page.nearbyDevices
            delegate: SettingRow {
                id: near
                required property var modelData
                required property int index
                readonly property bool pairingThis: page.pairingDevice === modelData && modelData.pairing

                first: index === 0
                clickable: page.pairingDevice === null
                icon: page.iconFor(modelData)
                iconColor: Theme.textDim
                title: modelData.name
                subtitle: pairingThis ? "Pairing…" : "Click to pair"
                onClicked: page.pair(modelData)

                Btn {
                    text: "Pair"
                    kind: "primary"
                    busy: near.pairingThis
                    enabled: page.pairingDevice === null
                    onClicked: page.pair(near.modelData)
                }
            }
        }
    }

    // --- adapter
    SectionLabel {
        visible: page.adapter !== null && page.powered
        text: "This computer"
    }
    Card {
        visible: page.adapter !== null && page.powered
        SettingRow {
            first: true
            icon: Icons.laptop
            title: "Discoverable"
            subtitle: "Let nearby devices find this computer"
            Toggle {
                checked: page.adapter !== null && page.adapter.discoverable
                onToggled: page.adapter.discoverable = !page.adapter.discoverable
            }
        }
    }
}
