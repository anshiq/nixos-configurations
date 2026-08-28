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
    spacing: 6

    readonly property string pluginsDir: `${Quickshell.env("HOME")}/.config/quickshell/plugins`

    Repeater {
        model: root.ids

        delegate: Loader {
            id: pluginLoader
            required property string modelData
            readonly property string pluginId: modelData
            property string tooltipText: ""

            FileView {
                id: manifestFile
                path: `${root.pluginsDir}/${pluginLoader.pluginId}/manifest.json`
                onLoaded: {
                    try {
                        const m = JSON.parse(text());
                        pluginLoader.source = `${root.pluginsDir}/${pluginLoader.pluginId}/${m.entryPoint}`;
                        pluginLoader.tooltipText = m.tooltip || "";
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
