import QtQuick
import Quickshell.Io

// CPU / RAM / GPU sampler for the bar. Reads kernel files directly every
// 2 s on AC, 5 s on battery, and only while `active`.
Item {
    id: root

    property bool active: false

    property real cpu: 0
    property real ramUsedKiB: 0
    property real ramTotalKiB: 0
    readonly property real ram: ramTotalKiB > 0 ? 100 * ramUsedKiB / ramTotalKiB : 0
    property real gpu: 0
    // -1 until the amdgpu busy file is found; stays -1 without one.
    property int gpuCard: -1
    property bool onBattery: false

    property real _lastIdle: -1
    property real _lastTotal: -1

    function sampleCpu() {
        statFile.reload();
        // "cpu  user nice system idle iowait irq softirq steal ..."
        const parts = statFile.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        if (parts.length < 5 || parts.some(isNaN))
            return;
        const idle = parts[3] + parts[4];
        const total = parts.reduce((a, b) => a + b, 0);
        if (root._lastTotal >= 0 && total > root._lastTotal)
            root.cpu = 100 * (1 - (idle - root._lastIdle) / (total - root._lastTotal));
        root._lastIdle = idle;
        root._lastTotal = total;
    }

    function sampleRam() {
        memFile.reload();
        const text = memFile.text();
        const total = /MemTotal:\s+(\d+)/.exec(text);
        const avail = /MemAvailable:\s+(\d+)/.exec(text);
        if (!total || !avail)
            return;
        root.ramTotalKiB = Number(total[1]);
        root.ramUsedKiB = root.ramTotalKiB - Number(avail[1]);
    }

    function sampleGpu() {
        if (root.gpuCard < 0)
            return;
        gpuFile.reload();
        const v = parseInt(gpuFile.text());
        if (!isNaN(v))
            root.gpu = v;
    }

    function sampleAc() {
        acFile.reload();
        const t = acFile.text().trim();
        root.onBattery = t === "0";
    }

    function findGpu() {
        for (let i = 0; i < 8; i++) {
            gpuFile.path = `/sys/class/drm/card${i}/device/gpu_busy_percent`;
            if (gpuFile.text().trim() !== "") {
                root.gpuCard = i;
                return;
            }
        }
        gpuFile.path = "";
    }

    Component.onCompleted: findGpu()

    FileView {
        id: statFile
        path: "/proc/stat"
        blockLoading: true
    }
    FileView {
        id: memFile
        path: "/proc/meminfo"
        blockLoading: true
    }
    FileView {
        id: gpuFile
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: acFile
        path: "/sys/class/power_supply/ACAD/online"
        blockLoading: true
        printErrors: false
    }

    Timer {
        interval: root.onBattery ? 5000 : 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.sampleAc();
            root.sampleCpu();
            root.sampleRam();
            root.sampleGpu();
        }
    }
}
