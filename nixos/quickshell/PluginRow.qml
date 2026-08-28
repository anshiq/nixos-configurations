// Renders one bar section (left/center/right) by reading manifest.json for
// each plugin id in `ids` (an ordered array from plugin-layout.json - see
// Bar.qml) and Loader-ing its entryPoint by absolute file path. Loading by
// path (not by bare QML type name) deliberately avoids qmldir entirely for
// plugin files: a qmldir file disables Quickshell's implicit per-file type
// synthesis for a directory, so only names explicitly listed in it become
// usable bare types (bit us once already - see qmldir's own comment).
// Plugin files never need a qmldir entry as a result.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "./" // shell root qmldir - exposes the Colors singleton

RowLayout {
    id: root
    required property var ids // ordered array of plugin id strings
    required property var bar // the owning Bar.qml instance - see Bar.qml
    spacing: 6

    readonly property string pluginsDir: `${Quickshell.env("HOME")}/.config/quickshell/plugins`

    Repeater {
        model: root.ids

        delegate: Loader {
            id: pluginLoader
            required property string modelData
            readonly property string pluginId: modelData
            property string tooltipText: ""

            // Matches real Omarchy's Bar.qml ModuleSlot.injectProps(): a
            // plugin widget extending qs.Ui's BarWidget (or declaring these
            // properties itself) gets `bar`/`moduleName`/`settings` set
            // once its component loads. `settings` is always {} here - this
            // shell has no per-widget inline-settings storage in
            // plugin-layout.json yet, so `setting(key, fallback)` always
            // returns `fallback`.
            onLoaded: {
                if (!item)
                    return;
                if ("bar" in item)
                    item.bar = root.bar;
                if ("moduleName" in item)
                    item.moduleName = pluginId;
                if ("settings" in item)
                    item.settings = ({});
                if (root.bar) {
                    var next = {};
                    for (var k in root.bar.moduleWidgetsMap)
                        next[k] = root.bar.moduleWidgetsMap[k];
                    next[pluginId] = item;
                    root.bar.moduleWidgetsMap = next;
                }
            }

            FileView {
                id: manifestFile
                path: `${root.pluginsDir}/${pluginLoader.pluginId}/manifest.json`
                onLoaded: {
                    try {
                        const m = JSON.parse(text());
                        // Accepts both our own flat manifest shape
                        // (entryPoint/tooltip at the top level - see
                        // plugins/user.*/manifest.json) and real Omarchy's
                        // schemaVersion-1 shape (entryPoints.barWidget,
                        // barWidget.description/.displayName) - see
                        // quickshell/scripts/plugin.sh's `add`, which can
                        // pull either kind of plugin in. Only the manifest
                        // shape is normalized here; `qs.Commons`/`qs.Ui`
                        // (Omarchy's design-system modules) are vendored
                        // under quickshell/Commons/ and quickshell/Ui/, and
                        // `bar`/`moduleName`/`settings` are injected below
                        // once the widget loads, matching real Omarchy's
                        // Bar.qml/BarWidget.qml contract.
                        const entryPoint = m.entryPoint || (m.entryPoints && m.entryPoints.barWidget);
                        const tooltip = m.tooltip || (m.barWidget && (m.barWidget.description || m.barWidget.displayName)) || m.name || "";
                        pluginLoader.source = `${root.pluginsDir}/${pluginLoader.pluginId}/${entryPoint}`;
                        pluginLoader.tooltipText = tooltip;
                        if (m.layoutMaximumWidth)
                            pluginLoader.Layout.maximumWidth = m.layoutMaximumWidth;
                    } catch (e) {
                        console.warn("PluginRow: failed to load manifest for " + pluginLoader.pluginId + ": " + e);
                    }
                }
            }

            // Hover-only handler so it never steals clicks from the widget's
            // own MouseArea underneath (HoverHandler doesn't grab input).
            HoverHandler {
                id: hoverHandler
            }

            PopupWindow {
                id: tooltipWindow
                visible: hoverHandler.hovered && pluginLoader.tooltipText.length > 0
                implicitWidth: tooltipLabel.implicitWidth + 12
                implicitHeight: tooltipLabel.implicitHeight + 8
                color: Colors.selection

                anchor {
                    item: pluginLoader
                    edges: Edges.Bottom
                    gravity: Edges.Bottom
                    margins.top: 4
                }

                Text {
                    id: tooltipLabel
                    anchors.centerIn: parent
                    text: pluginLoader.tooltipText
                    color: Colors.brightForeground
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }
            }
        }
    }
}
