import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// App Config Rotator: a bar button that opens a popup for swapping between
// alternate configs (Git work/personal, Helix config.toml + languages.toml,
// SSH laptop/server, ...). The popup reads ~/.local/share/appcredrotator/
// apps.json and does every file operation itself via Quickshell.Io's
// FileView - see Panel.qml's module comment for the full read/write/apply
// design (no subprocess of any kind is involved).
//
// Bar widget is intentionally minimal: just an icon + click-to-toggle. The
// Popup lives in Panel.qml and is instantiated here (not via a Loader) so
// the IpcHandler on the Panel can register at bar-load time. With a
// Loader, the Panel was constructed only on first open, and any hotkey /
// CLI route landed before that was a no-op.

BarWidget {
  id: root
  moduleName: "user.appcredrotator"

  // -- Popup contract ------------------------------------------------------
  // Bar's popout coordinator (see quickshell/Bar.qml) uses `opened` to
  // light up the open-panel dot under the widget, and `open`/`close`/
  // `toggle` for hotkey/click routing. The loaded Panel owns the actual
  // PanelController; we just forward.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function reloadPanel() { if (panelLoader.item && typeof panelLoader.item.reload === "function") panelLoader.item.reload() }

  // -- Panel injection -----------------------------------------------------
  // Mirrors omarchy.clock/BarWidget.qml's `injectPanel`. The Panel needs
  // `bar` (for popout coordination and `bar.foreground`) and `anchorItem`
  // (for KeyboardPanel placement). `hostWidget` is `this` so Panel can
  // surface its opened/close state back up.
  Component.onCompleted: injectPanel()
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  // -- Bar visuals ----------------------------------------------------------
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // "Toggle off" glyph (U+F011). Universally present in Nerd Fonts
    // (Material Design Icons), unlike the more thematic Octicons key
    // glyph I had earlier - which exists in Nerd Fonts but not in
    // every build, and a missing glyph makes WidgetButton go invisible
    // (hasVisualContent: text !== "", and "".charCodeAt(0) is 0 for
    // a font that has no glyph for that codepoint). Keeping the
    // bar slot even when the glyph is the empty string is what
    // `keepSpace: true` is for, but a reliable glyph is simpler.
    text: "󰐥"
    // keepSpace makes the button take a slot even if the glyph is
    // missing in the user's font. Without it, an unrenderable
    // glyph collapses the slot to zero width and the button becomes
    // both invisible and unclickable.
    keepSpace: true
    labelVisible: true
    hasVisualContent: text !== ""
    tooltipText: "App Config Rotator"
    onPressed: function(b) {
      // Right-click re-reads apps.json on the fly; left-click toggles the
      // panel (matching the rest of the bar).
      if (b === Qt.RightButton) root.reloadPanel()
      else root.togglePanel()
    }
  }

  // -- IPC -----------------------------------------------------------------
  // Routes for hotkeys / CLI (`quickshell ipc call user.appcredrotator
  // toggle`) and for sibling widgets that want to summon this one. Lives
  // on the BarWidget so the registration happens at bar-load time, not
  // the first time the user clicks. All calls forward to the panel's
  // open/close/toggle.
  IpcHandler {
    target: "user.appcredrotator"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function reload(): void { root.reloadPanel() }
  }

  // -- Panel loader ---------------------------------------------------------
  // The Panel instantiates a KeyboardPanel (layer-shell, with click-out
  // dismissal + outside-bar twin windows for multi-monitor) and reads
  // apps.json on its first show. The Loader's `visible: false` only
  // suppresses painting - the item is still constructed as soon as the
  // QML engine resolves the source, so `panelLoader.item` is non-null
  // by the time the user clicks.
  //
  // Why a Loader and not a direct child: a direct child would paint the
  // Panel's KeyboardPanel as soon as `opened` flips true, which is what
  // we want; but it also means the Panel's onLoaded/Component.onCompleted
  // runs at bar-load time, and the Panel currently starts a `list`
  // Process from `open()` rather than at construction, so a direct
  // child wouldn't actually save anything. The Loader keeps the two
  // lifecycles clean: bar-load doesn't trigger a `list` call.
  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }
}
