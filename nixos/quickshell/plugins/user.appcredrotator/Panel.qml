import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// App Config Rotator panel: a popup attached to the bar widget that shows
// every app in apps.json with its destinations and a dropdown of sources
// to switch each one to.
//
// Everything here is plain QML + JS - no subprocess, no Python. An earlier
// version shelled out to a small Python helper for YAML parsing and file
// I/O, but Quickshell's `FileView` (Quickshell.Io) covers all of that
// natively:
//   - `blockLoading` / `blockWrites` make reads and writes synchronous,
//     so `refresh()`/`applyDestination()` read top-to-bottom like normal
//     functions instead of a callback chain waiting on a subprocess.
//   - `atomicWrites` (on by default) writes to a temp file and renames it
//     over the target, so a failed write never corrupts the existing file
//     - the same guarantee the old code hand-rolled around symlinks.
//   - `loaded` / `loadFailed` tell us whether a file exists without
//     needing a `test -f` or a try/except.
// Config is JSON (apps.json, not apps.yaml) specifically so reading it is
// `JSON.parse(file.text())` - QML has no YAML parser, and hand-rolling one
// in JS just to keep YAML would be exactly the kind of custom-language
// implementation this rewrite is trying to avoid.
//
// Why copy instead of symlink
// ---------------------------
// destination files are plain copies of the selected source, not symlinks.
// QML/Quickshell has no symlink or realpath primitive (see FileView above -
// it's read/write text, nothing lower-level), and reintroducing that would
// mean shelling out to `ln`/`readlink` for the one thing FileView can't do,
// defeating the point of dropping the subprocess. Instead, `state.json`
// (next to apps.json, paths only, no secrets) records which source each
// destination was last set to, which gives us the same two things the
// symlink scheme provided:
//   - Ground truth for "what's current" (`current` below), instead of a
//     remembered UI guess.
//   - No lost updates: many apps rewrite their own config/token file after
//     login or a token refresh. Every `applyDestination`/`applyAll` call
//     flushes the destination's current content back into the source it's
//     recorded as belonging to *before* switching to a different one, so
//     that profile's file always reflects its latest state.
//
// State model
// -----------
// - `apps` is the validated, filesystem-enriched app list (see `refresh()`).
//   Each destination carries `current` - the source index state.json says
//   it's actually set to right now - so the panel shows ground truth
//   instead of a remembered guess.
// - `expandedIndex` is which app is currently showing its destinations.
//   The collapsed summary is one row per app; the expanded form is the
//   destinations + per-destination dropdowns. Clicking the row toggles.
// - `selectedSource` is a map of "appIdx:destIdx" -> sourceIdx, for a
//   *pending* choice the user is browsing before clicking Apply. It
//   defaults to `current` (not always 0) so opening the panel shows the
//   active source pre-selected. Cleared on `reload()`.
// - `status` is the bottom-of-panel message: "Applied config -> config
//   (work)" / errors.
//
// This panel deliberately does not read apps.json on bar load - it does so
// the first time `open()` is called (and again on right-click reload), so
// a bar slot that's never opened does zero I/O.

Panel {
  id: root
  moduleName: "user.appcredrotator"
  ipcTarget: "user.appcredrotator"
  // Don't manage IPC here - the BarWidget is the one users actually
  // click, and a hotkey/CLI caller would address the panel via
  // `quickshell ipc call user.appcredrotator toggle` (so the handler
  // must live on something that's instantiated at startup, not on
  // the lazily-loaded Panel). BarWidget.qml registers an IpcHandler
  // that forwards to the loaded Panel's toggle/open/close.
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // -- Data -----------------------------------------------------------------
  property var apps: []
  property int expandedIndex: -1
  // "appIdx:destIdx" -> sourceIdx. The keys are strings, the value is
  // an int. Reset on reload; survives open/close within a session.
  property var selectedSource: ({})
  // The result of the last list/apply: a one-line message for the
  // bottom strip. null = no message. Clears on next open.
  property string status: ""
  property bool statusError: false

  // Config and state live under $XDG_DATA_HOME/appcredrotator/ (see
  // desktop/home.nix:xdg.dataFile for apps.json's declarative deploy).
  // state.json is runtime-only - never Nix-managed, never committed -
  // this panel creates it the first time anything is applied.
  // Model.js is a `.pragma library` script and can't see the
  // `Quickshell` singleton itself (see Model.js's own header comment),
  // so every path it needs $HOME for is resolved here and passed in.
  readonly property string homeDir: Quickshell.env("HOME") || ""
  readonly property string appsPath: root.homeDir + "/.local/share/appcredrotator/apps.json"
  readonly property string statePath: root.homeDir + "/.local/share/appcredrotator/state.json"

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  // -- Panel sizing ---------------------------------------------------------
  readonly property int rowHeight: Style.spacing.controlHeight
  readonly property int destRowHeight: Style.spacing.controlHeight
  readonly property int popupRowHeight: Style.spacing.popupRowHeight
  readonly property int dropdownWidth: Style.space(220)
  readonly property int panelGap: Style.spacing.panelGap
  readonly property int labelGap: Style.spacing.labelGap
  readonly property int panelPadding: Style.spacing.popupPadding

  // Computed once on the apps list: worst-case height is every app
  // expanded with its destinations visible. Capped to available screen
  // height by KeyboardPanel.fittedContentHeight.
  //
  // When there are no apps yet (none configured, or the last read
  // failed), this must still reserve room for the empty-state
  // placeholder (see the Item with height Style.space(120) below) -
  // otherwise the panel shrinks to fit just the status strip and an
  // error looks like "nothing happened" instead of a visible message.
  readonly property int expandedRowsTotal: {
    if (apps.length === 0) return Style.space(120)
    var total = 0
    for (var i = 0; i < apps.length; i++) {
      total += rowHeight + labelGap // app row
      if (i === expandedIndex) {
        var app = apps[i]
        for (var j = 0; j < app.destinations.length; j++) {
          // destination row + its always-visible current-status line
          total += destRowHeight + labelGap + Style.space(16) + labelGap
        }
        total += rowHeight + labelGap // "Apply all" row
      }
    }
    return total
  }

  // -- Lifecycle ------------------------------------------------------------
  function open() {
    refresh()
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }
  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }
  function toggle() { root.opened ? root.close() : root.open() }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // Reload from disk. Right-clicking the bar widget also calls this so
  // an apps.json edit shows up without restarting the shell.
  function reload() { refresh(true) }

  // One-time per-open fetch. Skipped if apps is already populated,
  // since config changes are rare and re-reading + re-probing every
  // source's existence on every popup is needless work. `force = true`
  // to bypass (used by reload()).
  function refresh(force) {
    if (!force && apps.length > 0) return

    var appsFile = root.readFile(root.appsPath)
    if (!appsFile.exists) {
      root.status = "apps.json not found: " + root.appsPath
      root.statusError = true
      return
    }

    var parsed
    try {
      parsed = JSON.parse(appsFile.text)
    } catch (e) {
      root.status = "apps.json is invalid JSON: " + e.message
      root.statusError = true
      return
    }

    var validated
    try {
      validated = Model.validateApps(parsed, root.homeDir)
    } catch (e) {
      root.status = "Failed to read apps.json: " + e.message
      root.statusError = true
      return
    }

    var state = root.readStateJson()
    var enriched = validated.map(function (app) {
      return {
        name: app.name,
        icon: app.icon,
        destinations: app.destinations.map(function (dest) {
          var sources = dest.sources.map(function (sourcePath) {
            return { path: sourcePath, exists: root.readFile(sourcePath).exists }
          })
          var recorded = state[dest.path]
          var current = null
          if (recorded) {
            for (var i = 0; i < sources.length; i++) {
              if (sources[i].path === recorded) { current = i; break }
            }
          }
          return { label: dest.label, path: dest.path, current: current, sources: sources }
        })
      }
    })

    root.apps = Model.decorateApps(enriched, root.homeDir)
    root.selectedSource = ({})
    root.status = ""
    root.statusError = false
  }

  // -- Per-destination helpers ---------------------------------------------
  function destKey(appIdx, destIdx) { return appIdx + ":" + destIdx }

  // The dropdown's *pending* value: an explicit user pick this
  // session, or (by default) whatever is actually active right now
  // per state.json - not a hard-coded 0 - so opening the panel shows
  // the truth instead of always suggesting the first source.
  function currentSourceIndex(appIdx, destIdx) {
    var k = destKey(appIdx, destIdx)
    var v = selectedSource[k]
    if (v !== undefined) return v
    var app = apps[appIdx]
    var dest = app && app.destinations[destIdx]
    var cur = dest ? dest.current : null
    return (cur === null || cur === undefined) ? 0 : cur
  }

  // Applies `fn` to a copy of `apps[appIdx].destinations[destIdx]` and
  // stores the result back, without mutating anything in place (QML's
  // change detection needs a new `apps` reference to notice).
  function updateDestination(appIdx, destIdx, fn) {
    var nextApps = apps.slice()
    var app = nextApps[appIdx]
    if (!app) return
    var destinations = app.destinations.slice()
    var dest = destinations[destIdx]
    if (!dest) return
    destinations[destIdx] = fn(dest)
    nextApps[appIdx] = {
      name: app.name,
      icon: app.icon,
      destinations: destinations
    }
    apps = nextApps
  }

  function setSourceIndex(appIdx, destIdx, sourceIdx) {
    var next = {}
    for (var k in selectedSource) next[k] = selectedSource[k]
    next[destKey(appIdx, destIdx)] = sourceIdx
    selectedSource = next
  }

  // -- Apply ----------------------------------------------------------------
  function applyDestination(appIdx, destIdx) {
    var app = apps[appIdx]
    if (!app) return
    var dest = app.destinations[destIdx]
    if (!dest) return
    var srcIdx = currentSourceIndex(appIdx, destIdx)
    var src = dest.sources[srcIdx]
    if (!src) return

    var result = root.performApply(dest.path, dest.sources, srcIdx)
    if (result.ok) {
      status = "Applied " + src.pathDisplay + " -> " + dest.pathDisplay
      statusError = false
      root.updateDestination(appIdx, destIdx, function (d) {
        return { label: d.label, path: d.path, pathDisplay: d.pathDisplay, current: srcIdx, sources: d.sources }
      })
    } else {
      status = result.error
      statusError = true
    }
  }

  function applyAll(appIdx) {
    var app = apps[appIdx]
    if (!app) return
    var failedError = ""
    for (var j = 0; j < app.destinations.length; j++) {
      var dest = app.destinations[j]
      var srcIdx = currentSourceIndex(appIdx, j)
      var result = root.performApply(dest.path, dest.sources, srcIdx)
      if (result.ok) {
        root.updateDestination(appIdx, j, (function (appliedIdx) {
          return function (d) {
            return { label: d.label, path: d.path, pathDisplay: d.pathDisplay, current: appliedIdx, sources: d.sources }
          }
        })(srcIdx))
      } else {
        failedError = result.error
      }
    }
    if (failedError) {
      status = failedError
      statusError = true
    } else {
      status = "Applied all of " + app.name + " (" + app.destinations.length + " files)"
      statusError = false
    }
  }

  // Switches `destPath` to `sources[srcIdx].path`. Flushes whatever
  // `destPath` currently holds back into the source state.json says it
  // was last linked to (so an app's own updates - a refreshed auth
  // token, for instance - aren't lost the next time that profile is
  // selected), then copies the new source in and records the switch.
  // Pure FileView I/O - see the module comment for why this replaced
  // both the Python helper and the symlink scheme it used.
  function performApply(destPath, sources, srcIdx) {
    var source = sources[srcIdx]
    var srcFile = root.readFile(source.path)
    if (!srcFile.exists) {
      return { ok: false, error: "source not found: " + source.path }
    }

    var state = root.readStateJson()
    var destFile = root.readFile(destPath)
    if (destFile.exists) {
      var recorded = state[destPath]
      if (recorded && recorded !== source.path) {
        if (!root.writeFile(recorded, destFile.text)) {
          return { ok: false, error: "failed to save changes back to " + recorded }
        }
      } else if (!recorded) {
        // First time this destination is managed and it's already a
        // real file: keep exactly one safety snapshot before we
        // overwrite it - not a whole backup chain, just a single
        // capture of "however it looked before this tool touched it".
        var snapshotPath = destPath + ".appcredrotator-original"
        if (!root.readFile(snapshotPath).exists) {
          root.writeFile(snapshotPath, destFile.text)
        }
      }
    }

    if (!root.writeFile(destPath, srcFile.text)) {
      return { ok: false, error: "failed to write " + destPath }
    }
    state[destPath] = source.path
    root.writeStateJson(state)
    return { ok: true }
  }

  // -- File I/O ---------------------------------------------------------
  // Every read/write here is synchronous (blockLoading/blockWrites) and
  // uses a throwaway FileView created from this Component, rather than
  // one long-lived, reused FileView - each call is independent and gets
  // its own object so there's no shared-buffer state to reason about
  // between calls (the same lesson learned the hard way from the old
  // Process/StdioCollector plumbing this replaced).
  Component {
    id: fileViewComponent
    FileView {
      printErrors: false
      blockLoading: true
      blockWrites: true
    }
  }

  // Synchronous read. Never throws - a missing/unreadable file just
  // comes back as { exists: false, text: "" }.
  function readFile(path) {
    var fv = fileViewComponent.createObject(root, { path: path })
    var failed = false
    function onFail() { failed = true }
    fv.loadFailed.connect(onFail)
    var text = fv.text() // forces the blocking load per blockLoading
    fv.loadFailed.disconnect(onFail)
    var exists = !failed && !!fv.loaded
    fv.destroy()
    return { exists: exists, text: exists ? text : "" }
  }

  // Synchronous, best-effort write. atomicWrites defaults to true on
  // FileView, so a failed write never touches the existing file.
  // Returns false (rather than throwing) on failure so callers can
  // fold it into their own error message.
  function writeFile(path, text) {
    var fv = fileViewComponent.createObject(root, { path: path })
    var ok = true
    function onFail() { ok = false }
    fv.saveFailed.connect(onFail)
    fv.setText(text)
    fv.saveFailed.disconnect(onFail)
    fv.destroy()
    return ok
  }

  function readStateJson() {
    var f = root.readFile(root.statePath)
    if (!f.exists) return {}
    try {
      var parsed = JSON.parse(f.text)
      return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : {}
    } catch (e) {
      return {}
    }
  }

  function writeStateJson(stateObj) {
    root.writeFile(root.statePath, JSON.stringify(stateObj, null, 2) + "\n")
  }

  // -- View -----------------------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(root.expandedRowsTotal + (root.status !== "" ? Style.space(28) : 0) + root.panelPadding * 2)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.open()
      onCloseRequested: root.close()

      Flickable {
        id: appScroll
        anchors.fill: parent
        contentWidth: appColumn.width
        contentHeight: appColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: appColumn
          width: appScroll.width
          spacing: root.labelGap

          // ---- Empty state ----
          Item {
            visible: root.apps.length === 0
            width: parent.width
            height: visible ? Style.space(120) : 0
            Text {
              anchors.centerIn: parent
              text: "No apps found in apps.json"
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }
          }

          // ---- App rows ----
          Repeater {
            model: root.apps

            Column {
              id: appRow
              required property int index
              required property var modelData

              spacing: root.labelGap
              width: appColumn.width

              // -- Collapsed app row (always shown) --
              BorderSurface {
                width: parent.width
                height: root.rowHeight
                radius: Style.cornerRadius
                color: appRowMouse.containsMouse
                  ? Style.hoverFillFor(root.contentForeground, Color.accent)
                  : (appRow.index === root.expandedIndex
                      ? Style.selectedFillFor(root.contentForeground, Color.accent)
                      : "transparent")
                borderSpec: Border.flat(
                  appRow.index === root.expandedIndex ? Color.accent : Qt.darker(root.contentForeground, 2.0),
                  Style.spacing.hairline
                )

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: root.panelPadding
                  anchors.rightMargin: root.panelPadding
                  spacing: root.labelGap

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: appRow.index === root.expandedIndex ? "󰅀" : "󰅂"
                    color: appRow.index === root.expandedIndex ? Color.accent : Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: appRow.modelData.name
                    color: appRow.index === root.expandedIndex
                      ? Color.accent
                      : root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: appRow.modelData.destinations.length + " file"
                      + (appRow.modelData.destinations.length === 1 ? "" : "s")
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                  }
                }

                MouseArea {
                  id: appRowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.expandedIndex = root.expandedIndex === appRow.index ? -1 : appRow.index
                  }
                }
              }

              // -- Expanded destination rows --
              Repeater {
                model: appRow.index === root.expandedIndex ? appRow.modelData.destinations : []

                Column {
                  id: destCol
                  required property int index
                  required property var modelData

                  // The destination's parent app index is captured here
                  // for the callback closures. A bit clunky but avoids
                  // introducing a one-off Repeater parent traversal.
                  readonly property int appIndex: appRow.index
                  spacing: root.labelGap
                  width: appColumn.width
                  leftPadding: Style.space(20)
                  rightPadding: 0

                  BorderSurface {
                    width: parent.width
                    height: root.destRowHeight
                    radius: Style.cornerRadius
                    color: "transparent"
                    borderSpec: Border.flat(Qt.darker(root.contentForeground, 2.2), Style.spacing.hairline)

                    Row {
                      anchors.fill: parent
                      anchors.leftMargin: root.labelGap
                      anchors.rightMargin: root.labelGap
                      spacing: root.labelGap

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: destCol.modelData.label
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.body
                        width: Style.space(120)
                        elide: Text.ElideRight
                      }

                      Dropdown {
                        id: srcDropdown
                        width: root.dropdownWidth
                        height: root.rowHeight
                        foreground: root.contentForeground
                        accent: Color.accent
                        fontFamily: root.contentFontFamily
                        // Build {label, value} pairs from this
                        // destination's sources. We send a string
                        // label and the index (since sources can
                        // repeat paths and we want to preserve
                        // order in the dropdown). The active source
                        // (per state.json, not a guess) is marked so
                        // it's visible without touching Apply.
                        options: destCol.modelData.sources.map(function (s, i) {
                          var label = s.pathDisplay
                          if (!s.exists) label += " (missing)"
                          if (i === destCol.modelData.current) label += " - current"
                          return { value: String(i), label: label }
                        })
                        value: String(root.currentSourceIndex(destCol.appIndex, destCol.index))
                        showLabel: false
                        onChanged: function (v) {
                          root.setSourceIndex(destCol.appIndex, destCol.index, Number(v))
                        }
                      }

                      Item { width: Style.space(4); height: 1 } // spacer

                      Button {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Apply"
                        foreground: root.contentForeground
                        accent: Color.accent
                        fontFamily: root.contentFontFamily
                        bordered: true
                        onClicked: root.applyDestination(destCol.appIndex, destCol.index)
                      }
                    }
                  }

                  // Current-source status, always visible: this is
                  // the panel's answer to "which one is actually
                  // active right now", from state.json rather than
                  // remembered UI state.
                  Text {
                    width: parent.width
                    text: Model.currentStatus(destCol.modelData)
                    color: destCol.modelData.current === null
                      ? Qt.darker(root.contentForeground, 1.7)
                      : Color.accent
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 0.5
                    wrapMode: Text.Wrap
                  }

                  // Path display below the row so users see exactly
                  // where the destination is even if the dropdown
                  // is collapsed.
                  Text {
                    visible: destCol.index === appRow.modelData.destinations.length - 1
                    width: parent.width
                    text: destCol.modelData.path
                    color: Qt.darker(root.contentForeground, 1.7)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 0.5
                    wrapMode: Text.Wrap
                  }
                }
              }

              // -- Apply all (one-click for the common case where
              //    every destination moves in lockstep) --
              Item {
                visible: appRow.index === root.expandedIndex && appRow.modelData.destinations.length > 1
                width: parent.width
                height: visible ? root.rowHeight : 0

                Button {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Apply all (" + appRow.modelData.destinations.length + ")"
                  foreground: root.contentForeground
                  accent: Color.accent
                  fontFamily: root.contentFontFamily
                  bordered: true
                  onClicked: root.applyAll(appRow.index)
                }
              }
            }
          }

          // ---- Status strip (last action / error) ----
          Item {
            visible: root.status !== ""
            width: parent.width
            height: visible ? Style.space(28) : 0

            Text {
              anchors.fill: parent
              anchors.leftMargin: root.panelPadding
              anchors.rightMargin: root.panelPadding
              verticalAlignment: Text.AlignVCenter
              text: root.status
              color: root.statusError ? Color.urgent : Qt.darker(root.contentForeground, 1.2)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }
      }
    }
  }
}
