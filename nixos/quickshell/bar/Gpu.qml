import QtQuick
import Quickshell.Io
import qs.components

// GPU busy %, hidden without an amdgpu busy file. VRAM is read on hover.
BarItem {
    id: root

    property var stats: null
    readonly property string deviceDir: stats && stats.gpuCard >= 0 ? `/sys/class/drm/card${stats.gpuCard}/device` : ""
    property string vram: ""

    visible: deviceDir !== ""
    icon: "\u{F08AE}"
    label: (stats ? Math.round(stats.gpu) : 0) + "%"
    labelChars: 4
    tooltip: "GPU" + (vram !== "" ? `\nVRAM ${vram}` : "")

    onHoveredChanged: {
        if (!hovered || deviceDir === "")
            return;
        usedFile.reload();
        totalFile.reload();
        const used = Number(usedFile.text());
        const total = Number(totalFile.text());
        vram = total > 0 ? `${(used / 1073741824).toFixed(2)} / ${(total / 1073741824).toFixed(2)} GiB` : "";
    }

    FileView {
        id: usedFile
        path: root.deviceDir !== "" ? root.deviceDir + "/mem_info_vram_used" : ""
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: totalFile
        path: root.deviceDir !== "" ? root.deviceDir + "/mem_info_vram_total" : ""
        blockLoading: true
        printErrors: false
    }
}
