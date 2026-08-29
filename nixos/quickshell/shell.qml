//@ pragma UseQApplication
// Kept for QApplication-mode icon/theme lookup (tray icons resolve through
// QIcon). It is NOT what makes tray menus work - that was the old theory
// behind SystemTrayItem.display(), which never actually rendered nm-applet's
// menu. Menus are drawn by QsMenuAnchor now; see plugins/user.tray/Tray.qml.
// Phases 2-6: bar parity, theme unification, launcher, power menu,
// notifications - see /home/nixos/.claude/plans/stateless-wishing-willow.md
// for the full migration plan and phase order. Waybar/wofi keep running
// alongside this until the user verifies each piece live. mako is fully
// replaced as of Phase 6 - see Notifications.qml.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import QtQml.Models

ShellRoot {
    id: shellRoot

    // Minimal analog of real Omarchy's shell.qml _services/serviceFor(),
    // scaled to this shell's single-process model (no first/third-party
    // split, no separate PluginRegistry/BarWidgetRegistry objects - the
    // generated plugin-registry.json + plugin-layout.json already cover
    // that here). Lets a "service"-kind plugin (declares "service" in its
    // manifest's `kinds`, with an `entryPoints.service`/`kind: "service"` +
    // `entryPoint`) run once, independent of its bar widget's own
    // lifecycle, and be reached from the widget via `bar.shell.serviceFor(id)`
    // - see quickshell/Ui/BarWidget.qml and Bar.qml's `shell` property.
    //
    // "overlay"-kind plugins get the same treatment (see _overlays below):
    // real Omarchy hosts these through its own `omarchy-shell` process and a
    // generic panel host, neither of which exists here, so an overlay plugin
    // (e.g. battery-limiter) would load its bar widget/service fine and then
    // silently do nothing on click - toggleOverlay() shelled out to a binary
    // that was never there. Each overlay plugin's own entry point is already
    // a self-contained PanelWindow (see Overlay.qml files), so hosting one
    // is just: load it, hand it `shell`/`manifest`/`service`, and let the
    // shell's toggleOverlay()/hide() reach it directly instead of over IPC
    // to a nonexistent CLI.
    readonly property string pluginsDir: `${Quickshell.env("HOME")}/.config/quickshell/plugins`
    property var layout: ({
            "left": [],
            "center": [],
            "right": []
        })
    property var _services: ({})
    property var _overlays: ({})

    function serviceFor(pluginId) {
        return shellRoot._services[pluginId] || null;
    }

    function overlayFor(pluginId) {
        return shellRoot._overlays[pluginId] || null;
    }

    // Called by a plugin's Service/BarWidget instead of shelling out to
    // Omarchy's `omarchy-shell shell toggle <id> <json>`.
    function toggleOverlay(pluginId) {
        const o = shellRoot.overlayFor(pluginId);
        if (o && typeof o.toggle === "function")
            o.toggle();
    }

    // Called by an overlay's own dismiss() (see Overlay.qml: `root.shell.hide(id)`).
    function hide(pluginId) {
        const o = shellRoot.overlayFor(pluginId);
        if (o && typeof o.close === "function")
            o.close();
    }

    readonly property var enabledIds: [].concat(layout.left || [], layout.center || [], layout.right || [])

    FileView {
        id: layoutFile
        path: `${Quickshell.env("HOME")}/.config/quickshell/plugin-layout.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                shellRoot.layout = JSON.parse(text());
            } catch (e) {
                console.warn("shell: failed to load plugin-layout.json: " + e);
            }
        }
    }

    Instantiator {
        model: shellRoot.enabledIds
        delegate: Item {
            id: serviceCandidate
            required property string modelData
            readonly property string pluginId: modelData
            property var manifestData: null

            FileView {
                id: manifestFile
                path: `${shellRoot.pluginsDir}/${serviceCandidate.pluginId}/manifest.json`
                onLoaded: {
                    try {
                        const m = JSON.parse(text());
                        serviceCandidate.manifestData = m;
                        const kinds = m.kinds || (m.kind ? [m.kind] : []);

                        const serviceEntry = (m.entryPoints && m.entryPoints.service) || (m.kind === "service" ? m.entryPoint : undefined);
                        if (kinds.indexOf("service") !== -1 && serviceEntry)
                            serviceLoader.source = `${shellRoot.pluginsDir}/${serviceCandidate.pluginId}/${serviceEntry}`;

                        const overlayEntry = (m.entryPoints && m.entryPoints.overlay) || (m.kind === "overlay" ? m.entryPoint : undefined);
                        if (kinds.indexOf("overlay") !== -1 && overlayEntry)
                            overlayLoader.source = `${shellRoot.pluginsDir}/${serviceCandidate.pluginId}/${overlayEntry}`;
                    } catch (e) {
                        console.warn("shell: failed to check plugin kinds for " + serviceCandidate.pluginId + ": " + e);
                    }
                }
            }

            Loader {
                id: serviceLoader
                onLoaded: {
                    if (item && "shell" in item)
                        item.shell = shellRoot;
                    // Reassigning (not mutating in place) `_services` fires
                    // its change notification, so a widget's `readonly
                    // property var service: bar.shell.serviceFor(id)`
                    // binding - evaluated once at widget creation, same as
                    // real Omarchy - re-evaluates if the service finishes
                    // loading after the widget already bound to `null`.
                    var next = {};
                    for (var k in shellRoot._services)
                        next[k] = shellRoot._services[k];
                    next[serviceCandidate.pluginId] = item;
                    shellRoot._services = next;
                    // The overlay may have finished loading first (Loader
                    // completion order isn't guaranteed) and bound `service`
                    // to null - hand it the service now that it exists.
                    var ov = shellRoot._overlays[serviceCandidate.pluginId];
                    if (ov && "service" in ov)
                        ov.service = item;
                }
            }

            Loader {
                id: overlayLoader
                onLoaded: {
                    if (item && "shell" in item)
                        item.shell = shellRoot;
                    if (item && "manifest" in item)
                        item.manifest = serviceCandidate.manifestData;
                    if (item && "service" in item)
                        item.service = shellRoot._services[serviceCandidate.pluginId] || null;
                    var next = {};
                    for (var k in shellRoot._overlays)
                        next[k] = shellRoot._overlays[k];
                    next[serviceCandidate.pluginId] = item;
                    shellRoot._overlays = next;
                }
            }
        }
    }

    Bar {
        shell: shellRoot
    }
    Launcher {}
    PowerMenu {}
    Notifications {}
    NetworkPanel {}
    LockScreen {}
}
