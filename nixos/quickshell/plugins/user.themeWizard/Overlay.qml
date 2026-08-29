// The theme wizard: pick any theme by its live palette, flip day/night,
// jump to the next theme, or force a resync with the wall-clock schedule -
// everything waybar/scripts/theme-switch.sh already does from a terminal,
// now with the actual colors in front of you instead of memorized names.
// Read-only about the schedule itself (that's Nix-declared, see
// ../../../themes/schedule.nix) - "Resync now" just re-runs the same
// no-arg lookup theme-switch.sh's login/timer path already uses, so this
// never drifts from what the timers would do on their own.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false
  property bool busy: false
  property var statusData: ({ themes: [], schedule: [], current: "", now: "", activeScheduleIndex: -1 })

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int cardWidth: Math.min(Style.space(520), panel.width - Style.gapsOut * 2)

  readonly property var themes: statusData.themes || []
  readonly property var schedule: statusData.schedule || []

  function open() {
    root.opened = true
    root.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { root.opened = false }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "user.themeWizard")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open()
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function scriptPath(name) {
    return `${Quickshell.env("HOME")}/.config/waybar/scripts/${name}`
  }

  // args: [] (resync to schedule), ["toggle"], ["next"], or [themeName]
  function runSwitch(args) {
    if (root.busy) return
    root.busy = true
    switchProc.command = ["bash", root.scriptPath("theme-switch.sh")].concat(args)
    switchProc.running = true
  }

  function toMinutes(hhmm) {
    const parts = String(hhmm || "00:00").split(":")
    return (parseInt(parts[0], 10) || 0) * 60 + (parseInt(parts[1], 10) || 0)
  }

  function nextEntry() {
    if (root.schedule.length === 0) return null
    const idx = root.statusData.activeScheduleIndex
    if (idx < 0) return root.schedule[0]
    return root.schedule[(idx + 1) % root.schedule.length]
  }

  function countdownText() {
    const next = root.nextEntry()
    if (!next) return ""
    let diff = root.toMinutes(next.time) - root.toMinutes(root.statusData.now)
    if (diff <= 0) diff += 24 * 60
    const h = Math.floor(diff / 60), m = diff % 60
    return (h > 0 ? h + "h " : "") + m + "m"
  }

  onOpenedChanged: if (opened) refresh()

  Process {
    id: statusProc
    command: ["bash", `${Quickshell.env("HOME")}/.config/quickshell/scripts/theme-wizard-status.sh`]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.statusData = JSON.parse(text)
        } catch (e) {
          console.warn("Theme wizard: failed to parse status: " + e)
        }
      }
    }
  }

  Process {
    id: switchProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: {
      root.busy = false
      root.refresh()
    }
  }

  // Keeps the countdown honest while the wizard sits open across a minute
  // boundary, and catches a scheduled timer firing while the wizard is up.
  Timer {
    interval: 15000
    repeat: true
    running: root.opened
    onTriggered: root.refresh()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "user-theme-wizard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: content.height + card.contentTopInset + card.contentBottomInset
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.dismiss()

        Column {
          id: content
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.spacing.panelGap

          // ---------- Header: current theme + live clock ----------
          RowLayout {
            width: parent.width
            spacing: Style.spacing.controlGap

            Text {
              text: (root.statusData.current === "" ? "Theme Wizard" : (root.statusData.current))
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              Layout.fillWidth: true
              elide: Text.ElideRight
            }

            Text {
              text: root.statusData.now || ""
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---------- Day/night schedule status ----------
          Column {
            width: parent.width
            spacing: Style.spacing.labelGap

            PanelSectionHeader {
              text: "AUTO SCHEDULE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              text: root.schedule.length === 0
                ? "No schedule configured."
                : "Next: " + (root.nextEntry() ? root.nextEntry().theme + " at " + root.nextEntry().time : "-")
                  + (root.countdownText() !== "" ? "  (in " + root.countdownText() + ")" : "")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.schedule
                delegate: Rectangle {
                  required property var modelData
                  required property int index
                  readonly property bool isActive: index === root.statusData.activeScheduleIndex
                  width: (parent.width - (root.schedule.length - 1) * Style.space(6)) / Math.max(1, root.schedule.length)
                  height: Style.space(34)
                  radius: Style.cornerRadius
                  color: isActive ? Style.selectedFillFor(root.foreground, Color.accent) : Style.normalFillFor(root.foreground, Color.accent)
                  border.width: isActive ? 1 : 0
                  border.color: Color.accent

                  Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: modelData.time
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: isActive
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: modelData.theme
                      color: isActive ? Color.accent : Qt.darker(root.foreground, 1.3)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---------- Theme gallery ----------
          Column {
            width: parent.width
            spacing: Style.spacing.labelGap

            PanelSectionHeader {
              text: "THEMES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            GridLayout {
              width: parent.width
              columns: 2
              columnSpacing: Style.space(8)
              rowSpacing: Style.space(8)

              Repeater {
                model: root.themes
                delegate: BorderSurface {
                  required property var modelData
                  Layout.fillWidth: true
                  height: Style.space(78)
                  radius: root.cornerRadius
                  color: modelData.active ? Style.selectedFillFor(root.foreground, Color.accent) : Style.normalFillFor(root.foreground, Color.accent)
                  borderSpec: Border.controlSpec(modelData.active ? "selected" : "normal", root.foreground, Color.accent)
                  padding: Style.space(8)

                  Column {
                    anchors.fill: parent
                    spacing: Style.space(6)

                    RowLayout {
                      width: parent.width
                      spacing: Style.space(4)
                      Text {
                        text: modelData.kind === "night" ? "☾" : "☀"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.subtitle
                      }
                      Text {
                        text: modelData.name
                        color: modelData.active ? Color.accent : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: modelData.active
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                    }

                    Row {
                      width: parent.width
                      height: Style.space(24)
                      spacing: 2
                      Rectangle { width: parent.width / 5 - 1.6; height: parent.height; radius: 3; color: modelData.background }
                      Rectangle { width: parent.width / 5 - 1.6; height: parent.height; radius: 3; color: modelData.foreground }
                      Rectangle { width: parent.width / 5 - 1.6; height: parent.height; radius: 3; color: modelData.accent }
                      Rectangle { width: parent.width / 5 - 1.6; height: parent.height; radius: 3; color: modelData.red }
                      Rectangle { width: parent.width / 5 - 1.6; height: parent.height; radius: 3; color: modelData.green }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.busy
                    onClicked: root.runSwitch([modelData.name])
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---------- Quick actions ----------
          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              text: "Resync now"
              tooltipText: "Re-apply whatever theme the schedule says right now"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              enabled: !root.busy
              onClicked: root.runSwitch([])
            }
            Button {
              text: "Toggle day/night"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              enabled: !root.busy
              onClicked: root.runSwitch(["toggle"])
            }
            Button {
              text: "Next theme"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              enabled: !root.busy
              onClicked: root.runSwitch(["next"])
            }
          }
        }
      }
    }
  }
}
