// Mirrors nixos/waybar/config's layer=top/position=top/height=22 panel
// and its modules-left/modules-center/modules-right layout. Section
// contents come from plugin-layout.json + plugins/<id>/manifest.json
// (see PluginRow.qml) instead of being hardcoded here, so widgets can be
// added/reordered/removed by editing those JSON files.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

PanelWindow {
    id: root
    anchors {
        left: true
        right: true
        top: true
    }
    implicitHeight: 18
    exclusiveZone: 18
    color: Colors.background

    // Injected from shell.qml (`Bar { shell: shellRoot }`) - lets a widget
    // reach `bar.shell.serviceFor(id)`, mirroring real Omarchy's Bar.qml/
    // shell.qml contract. See qs.Ui's BarWidget.qml for the base type that
    // reads `bar`/`vertical`/`barSize`/`moduleWidgets()`.
    property var shell: null
    readonly property bool vertical: false
    readonly property int barSize: root.implicitHeight
    // Always top - matches the PanelWindow anchors above (left+right+top).
    // Vendored qs.Ui widgets (e.g. PopupCard) branch on this for popup
    // placement; real Omarchy supports all four edges, this shell only ever
    // renders the top bar.
    readonly property string position: "top"

    // The rest of real Omarchy's "bar chrome" contract - qs.Ui's
    // WidgetButton/Panel/BarIconButton (see quickshell/Ui/) call these
    // directly on `bar` with NO existence guard (unlike e.g.
    // `switchPanelFrom`, which every caller checks with `typeof` first).
    // Missing any of these throws inside a signal handler at the point of
    // the call - e.g. WidgetButton.triggerPress() calls
    // `bar.hideTooltip()` *before* emitting its own `pressed` signal, so a
    // missing hideTooltip silently eats every click before it reaches the
    // widget. Add a new bar-chrome property here only after confirming
    // some vendored qs.Ui file actually calls it unconditionally - matching
    // the contract, not padding it speculatively.
    readonly property color foreground: Colors.foreground
    readonly property color background: Colors.background
    readonly property color urgent: Colors.red
    readonly property color barForeground: foreground
    // "monospace" generic family, resolved through fontconfig - so
    // `omarchy font set` (nixos/scripts/omarchy) can repoint the bar via a
    // fontconfig alias without a rebuild. Restart quickshell to pick up a
    // changed alias (the omarchy command does this for you).
    readonly property string fontFamily: "monospace"
    readonly property bool foregroundAnimationEnabled: true

    // Singleton-popup coordination (real Omarchy's requestPopout/
    // releasePopout): a panel that opens asks the bar to close whatever
    // other panel is currently open first, so only one is ever visible.
    property var activePopout: null
    function requestPopout(owner) {
        if (root.activePopout === owner)
            return;
        if (root.activePopout) {
            if (typeof root.activePopout.closeForPopoutSwitch === "function")
                root.activePopout.closeForPopoutSwitch();
            else if (typeof root.activePopout.close === "function")
                root.activePopout.close();
        }
        root.activePopout = owner;
    }
    function releasePopout(owner) {
        if (root.activePopout === owner)
            root.activePopout = null;
    }

    // Shared hover tooltip - one popup for the whole bar, matching
    // Omarchy's model (WidgetButton.onEntered/onExited call these
    // unconditionally). Same PopupWindow shape PluginRow.qml already uses
    // for manifest-declared tooltips, just bar-owned instead of per-plugin.
    // tooltipTarget is deliberately never reset to null after its first
    // assignment (see hideTooltip below) - Quickshell 0.3.0's
    // PopupAnchor::setItem() segfaults (QQuickItem::window() on a stale
    // pointer inside PopupAnchor::onItemWindowChanged()) when a PopupWindow's
    // `anchor.item` binding writes null over a previously-real item. Confirmed
    // from ~/.cache/quickshell/crashes/*/report.txt: 8 of the last 9 crashes
    // on this machine are exactly this stack, triggered by any widget click
    // that fires hideTooltip while hovered (screentime hits it hardest since
    // its tooltip text - and therefore this binding - churns every few
    // seconds). `visible` below now depends only on tooltipText, so the
    // popup still hides correctly; `anchor.item` just keeps pointing at the
    // last real item instead of ever going through null.
    property var tooltipTarget: null
    property string tooltipText: ""
    function showTooltip(item, text) {
        root.tooltipTarget = item;
        root.tooltipText = text || "";
    }
    function hideTooltip(item) {
        if (root.tooltipTarget === item) {
            root.tooltipText = "";
        }
    }

    // Outside-click / arrow-key panel switching hooks some qs.Ui widgets
    // call - always through a `typeof` guard, so a safe no-op is enough
    // (no dismiss-on-outside-click or arrow-switch behavior yet, just
    // never throws).
    property var clickTargets: []
    function registerClickTarget(item) {
        if (root.clickTargets.indexOf(item) === -1)
            root.clickTargets = root.clickTargets.concat([item]);
    }
    function unregisterClickTarget(item) {
        var idx = root.clickTargets.indexOf(item);
        if (idx !== -1) {
            var next = root.clickTargets.slice();
            next.splice(idx, 1);
            root.clickTargets = next;
        }
    }
    function switchPanelFrom(panel, direction) {
        return false;
    }

    // Real Omarchy's Bar.run() - vendored widgets (e.g. qs.Ui Workspaces)
    // call `bar.run(shellCommand)` to dispatch hyprctl/etc without each
    // widget needing its own Process item.
    function run(command) {
        if (!command) return;
        Util.execDetached(command);
    }

    // Every live widget instance across all three sections, keyed by
    // moduleId - a widget id appears once (each id can only be enabled in
    // one section/spot per plugin-layout.json), so broadcast() only ever
    // needs to notify one instance here (unlike Omarchy's multi-monitor
    // case, where the same widget id runs once per bar/screen).
    property var moduleWidgetsMap: ({})

    function moduleWidgets(moduleId) {
        var item = moduleWidgetsMap[moduleId];
        return item ? [item] : [];
    }

    property var layout: ({
            "left": [],
            "center": [],
            "right": []
        })

    function applyLayout(json) {
        try {
            root.layout = JSON.parse(json);
        } catch (e) {
            console.warn("Bar: failed to load plugin-layout.json: " + e);
        }
    }

    FileView {
        id: layoutFile
        path: `${Quickshell.env("HOME")}/.config/quickshell/plugin-layout.json`
        // Live-reloads so quickshell/scripts/plugin.sh enable/disable takes
        // effect immediately, same as Colors.qml watching theme.json -
        // no bar restart needed to pick up a plugin change.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyLayout(text())
        onTextChanged: root.applyLayout(text())
    }

    PluginRow {
        ids: root.layout.left
        bar: root
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: 6
        }
    }

    PluginRow {
        ids: root.layout.center
        bar: root
        anchors.centerIn: parent
    }

    PluginRow {
        ids: root.layout.right
        bar: root
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            rightMargin: 6
        }
    }

    // Renders whatever showTooltip()/hideTooltip() (above) last set - the
    // shared bar-level tooltip real Omarchy's WidgetButton/BarIconButton
    // expect, distinct from PluginRow's own per-plugin manifest-tooltip
    // popup (that one's driven by static manifest text; this one's driven
    // live by widget hover state).
    PopupWindow {
        id: sharedTooltip
        visible: root.tooltipText.length > 0
        implicitWidth: sharedTooltipLabel.implicitWidth + 12
        implicitHeight: sharedTooltipLabel.implicitHeight + 8
        color: Colors.selection

        anchor {
            item: root.tooltipTarget
            edges: Edges.Bottom
            gravity: Edges.Bottom
            margins.top: 4
        }

        Text {
            id: sharedTooltipLabel
            anchors.centerIn: parent
            text: root.tooltipText
            color: Colors.brightForeground
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
        }
    }
}
