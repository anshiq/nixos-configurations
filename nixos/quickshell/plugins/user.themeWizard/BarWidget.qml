import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Replaces the old bare "toggle via keybind only" theme switching (see
// waybar/scripts/theme-switch.sh) with a real bar affordance: an icon that
// reflects the active theme's day/night kind, click opens the wizard
// (Overlay.qml) for picking a theme or checking the schedule.
BarWidget {
  id: root
  moduleName: "user.themeWizard"

  property string current: ""
  property string kind: "day"

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  Process {
    id: statusProc
    command: ["bash", `${Quickshell.env("HOME")}/.config/quickshell/scripts/theme-wizard-status.sh`]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          const j = JSON.parse(text)
          root.current = j.current
          const t = (j.themes || []).find(t => t.name === j.current)
          root.kind = t ? t.kind : "day"
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    bar: root.bar
    anchors.fill: parent
    text: (root.kind === "night" ? "☾ " : "☀ ") + (root.current || "theme")
    tooltipText: "Theme: " + (root.current || "unknown") + " (" + root.kind + ") - click to open the theme wizard"
    onPressed: function(b) {
      if (root.bar && root.bar.shell) root.bar.shell.toggleOverlay(root.moduleName)
    }
  }
}
