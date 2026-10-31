import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.components

// Battery from UPower (event-driven). Hidden without UPower or a battery.
BarItem {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev.ready && dev.isLaptopBattery && dev.isPresent
    // UPower reports 0-1 here; tolerate 0-100 too.
    readonly property int pct: present ? Math.round(dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 0
    readonly property bool charging: present && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: present && dev.state === UPowerDeviceState.FullyCharged
    readonly property bool low: present && !charging && !full && pct <= 15

    function duration(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    visible: present
    icon: {
        if (charging)
            return "\u{F0084}";
        if (pct >= 95)
            return "\u{F0079}";
        // nf-md-battery_10 .. battery_90 are consecutive code points.
        return String.fromCodePoint(0xF007A + Math.max(0, Math.min(8, Math.floor(pct / 10) - 1)));
    }
    iconColor: low ? Colors.red : charging ? Colors.green : Colors.foreground
    label: pct + "%"
    labelChars: 4
    labelColor: low ? Colors.red : Colors.foreground
    tooltip: {
        if (!present)
            return "";
        if (full)
            return "Fully charged";
        if (charging)
            return "Charging" + (dev.timeToFull > 0 ? `, full in ${duration(dev.timeToFull)}` : "");
        return "On battery" + (dev.timeToEmpty > 0 ? `, ${duration(dev.timeToEmpty)} left` : "");
    }

    onClicked: Quickshell.execDetached(["settings-app", "power"])
}
