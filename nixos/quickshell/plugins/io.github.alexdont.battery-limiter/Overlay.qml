import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// The control card: current charge and limit, preset buttons and a slider
// for the limit, and battery health (design vs actual capacity, cycles).
// Every applied change goes through one polkit prompt — the card says so.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false

  // Slider position while the user drags; -1 = follow the live limit.
  property int pending: -1
  readonly property int shownLimit: pending >= 0 ? pending
    : (service ? service.limit : 100)

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int cardWidth: Math.min(Style.space(420), panel.width - Style.gapsOut * 2)

  function open(payloadJson) {
    root.opened = true
    root.pending = -1
    if (root.service) root.service.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { root.opened = false }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.alexdont.battery-limiter")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function apply(pct) {
    if (root.service) root.service.setLimit(pct)
    root.pending = -1
  }

  function fmtCap(micro) {
    return (micro / 1000000).toFixed(1)
  }

  readonly property var hist: service ? service.healthHistory : []

  function trendLabel() {
    if (root.hist.length === 0) return ""
    if (root.hist.length === 1) return "Tracking daily · first entry " + root.hist[0].date
    var a = root.hist[0], b = root.hist[root.hist.length - 1]
    var days = Math.max(1, Math.round((Date.parse(b.date) - Date.parse(a.date)) / 86400000))
    var span = days < 60 ? days + " days" : Math.round(days / 30.44) + " months"
    var dh = b.health - a.health
    var s = (dh >= 0 ? "+" : "") + dh.toFixed(1) + "% health over " + span
    if (a.cycles >= 0 && b.cycles >= a.cycles) s += " · +" + (b.cycles - a.cycles) + " cycles"
    return s
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "io-github-alexdont-battery-limiter"
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
        // Muscle-memory shortcuts for the classic modes.
        Keys.onPressed: function(event) {
          if (!root.service || !root.service.supported) return
          if (event.key === Qt.Key_6) { root.apply(60); event.accepted = true }
          else if (event.key === Qt.Key_8) { root.apply(80); event.accepted = true }
          else if (event.key === Qt.Key_0) { root.apply(100); event.accepted = true }
        }

        Column {
          id: content
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: card.contentTopInset
          anchors.leftMargin: card.contentLeftInset
          anchors.rightMargin: card.contentRightInset
          spacing: Style.spacing.md

          // ---- Header: title + live charge state ----
          Item {
            width: parent.width
            height: headerTitle.implicitHeight

            Text {
              id: headerTitle
              anchors.left: parent.left
              text: "Battery"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.service && root.service.capacity >= 0
                ? root.service.capacity + "% · " + root.service.status : ""
              textFormat: Text.PlainText
              color: root.foreground
              opacity: 0.65
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
          }

          Text {
            visible: !root.service || !root.service.present
            width: parent.width
            text: "No battery found."
            color: root.foreground
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          // ---- Charge limit ----
          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: !!root.service && root.service.present

            Text {
              text: "Charge limit"
              color: root.selectedText
              opacity: 0.85
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Text {
              visible: !!root.service && !root.service.supported
              width: parent.width
              text: "This laptop doesn't expose a charge-limit control, so the limiter is read-only here — health stats below still work."
              color: root.foreground
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Row {
              visible: !!root.service && root.service.supported
              spacing: Style.space(6)

              Repeater {
                model: [
                  { pct: 60, label: "60% · longevity" },
                  { pct: 80, label: "80% · balanced" },
                  { pct: 100, label: "100% · travel" }
                ]

                Rectangle {
                  required property var modelData
                  readonly property bool active: root.service && root.service.limit === modelData.pct
                  width: presetText.implicitWidth + Style.spacing.md * 2
                  height: Style.space(28)
                  radius: root.cornerRadius / 2
                  color: (presetHover.containsMouse || active) ? root.selectedBackground : "transparent"
                  border.width: 1
                  border.color: root.border
                  opacity: active ? 1 : 0.65

                  Text {
                    id: presetText
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    color: root.selectedText
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  MouseArea {
                    id: presetHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.apply(parent.modelData.pct)
                  }
                }
              }
            }

            // Custom value: drag, release, then confirm with Apply so a
            // stray drag never fires a polkit prompt on its own.
            Row {
              visible: !!root.service && root.service.supported
              width: parent.width
              spacing: Style.spacing.md

              Rectangle {
                id: track
                width: parent.width - limitLabel.width - applyBtn.width - Style.spacing.md * 2
                height: Style.space(16)
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.selectedBackground
                opacity: 0.5

                Rectangle {
                  width: Math.max(height, (root.shownLimit - 50) / 50 * track.width)
                  height: parent.height
                  radius: height / 2
                  color: root.selectedText
                  opacity: 0.55
                }

                MouseArea {
                  anchors.fill: parent
                  function at(mouse) {
                    var pct = 50 + Math.round((mouse.x / track.width) * 50 / 5) * 5
                    root.pending = Math.max(50, Math.min(100, pct))
                  }
                  onPressed: function(mouse) { at(mouse) }
                  onPositionChanged: function(mouse) { if (pressed) at(mouse) }
                }
              }

              Text {
                id: limitLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.shownLimit + "%"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Rectangle {
                id: applyBtn
                readonly property bool armed: root.pending >= 0 && root.service
                  && root.pending !== root.service.limit && !root.service.applying
                width: applyText.implicitWidth + Style.spacing.md * 2
                height: Style.space(28)
                radius: root.cornerRadius / 2
                anchors.verticalCenter: parent.verticalCenter
                color: armed && applyHover.containsMouse ? root.selectedBackground : "transparent"
                border.width: 1
                border.color: root.border
                opacity: armed ? 1 : 0.35

                Text {
                  id: applyText
                  anchors.centerIn: parent
                  text: root.service && root.service.applying ? "Waiting…" : "Apply"
                  color: root.selectedText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
                MouseArea {
                  id: applyHover
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: parent.armed ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: if (parent.armed) root.apply(root.pending)
                }
              }
            }
          }

          // ---- Health ----
          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: !!root.service && root.service.present && root.service.healthPct > 0

            Text {
              text: "Health"
              color: root.selectedText
              opacity: 0.85
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Repeater {
              model: root.service ? [
                { k: "Capacity vs new", v: root.service.healthPct.toFixed(0) + "%  ("
                    + root.fmtCap(root.service.full) + " of " + root.fmtCap(root.service.fullDesign)
                    + " " + root.service.capacityUnit + ")" },
                { k: "Charge cycles", v: root.service.cycleCount >= 0 ? String(root.service.cycleCount) : "—" }
              ] : []

              Row {
                required property var modelData
                spacing: Style.spacing.md

                Text {
                  width: Style.space(150)
                  text: modelData.k
                  color: root.foreground
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                Text {
                  text: modelData.v
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
              }
            }
          }

          // ---- History: the daily health log, drawn over real time ----
          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.hist.length > 0

            Text {
              text: "History"
              color: root.selectedText
              opacity: 0.85
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Text {
              width: parent.width
              text: root.trendLabel()
              textFormat: Text.PlainText
              color: root.foreground
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            // X is scaled by date, not sample index, so gaps (laptop off for
            // a week) read as gaps instead of compressing time.
            Canvas {
              width: parent.width
              height: Style.space(36)
              visible: root.hist.length >= 2
              property var pts: root.hist
              property color lineColor: root.selectedText
              onPtsChanged: requestPaint()
              onLineColorChanged: requestPaint()
              onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var h = pts
                if (h.length < 2) return
                var lo = h[0].health, hi = h[0].health
                for (var j = 1; j < h.length; j++) {
                  if (h[j].health < lo) lo = h[j].health
                  if (h[j].health > hi) hi = h[j].health
                }
                lo -= 0.5; hi += 0.5
                var t0 = Date.parse(h[0].date)
                var t1 = Date.parse(h[h.length - 1].date)
                var dt = Math.max(1, t1 - t0)
                ctx.strokeStyle = String(lineColor)
                ctx.lineWidth = 2
                ctx.lineJoin = "round"
                ctx.beginPath()
                for (var k = 0; k < h.length; k++) {
                  var x = (Date.parse(h[k].date) - t0) / dt * (width - 4) + 2
                  var y = height - 3 - (h[k].health - lo) / (hi - lo) * (height - 6)
                  if (k === 0) ctx.moveTo(x, y)
                  else ctx.lineTo(x, y)
                }
                ctx.stroke()
              }
            }
          }

          Text {
            width: parent.width
            text: (root.service && root.service.supported
              ? "Changes ask for your password once each (polkit) and persist across reboots via /etc/tmpfiles.d/battery-limiter.conf. Keys: 6 = 60 · 8 = 80 · 0 = 100 · "
              : "") + "Esc close"
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
