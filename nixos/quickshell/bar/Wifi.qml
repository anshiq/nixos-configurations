import QtQuick
import Quickshell
import Quickshell.Networking
import qs
import qs.components

// Network state from NetworkManager over DBus (no polling). The IP address
// is looked up once per hover.
BarItem {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var network: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property int strength: network ? Math.round(network.signalStrength * 100) : 0
    readonly property var activeDevice: network ? wifiDevice : wiredDevice
    property string ip: ""

    icon: {
        if (network)
            return ["\u{F092F}", "\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"][Math.min(4, Math.floor(strength / 20))];
        if (wiredDevice)
            return "\u{F0200}";
        return Networking.wifiEnabled ? "\u{F092B}" : "\u{F092E}";
    }
    iconColor: network || wiredDevice ? Colors.foreground : Colors.muted
    tooltip: {
        let lines;
        if (network)
            lines = [`${network.name}  ${strength}%`];
        else if (wiredDevice)
            lines = [`Wired (${wiredDevice.name})`];
        else
            lines = [Networking.wifiEnabled ? "Disconnected" : "Wi-Fi off"];
        if (activeDevice && ip !== "")
            lines.push(ip);
        return lines.join("\n");
    }

    onHoveredChanged: {
        if (hovered && activeDevice)
            ipCmd.run(["nmcli", "-g", "IP4.ADDRESS", "device", "show", activeDevice.name]);
        else if (!hovered)
            ip = "";
    }

    onClicked: Quickshell.execDetached(["settings-app", "wifi"])

    Cmd {
        id: ipCmd
        onFinished: (code, out) => root.ip = code === 0 ? out.split("\n").filter(l => l !== "").join(", ") : ""
    }
}
