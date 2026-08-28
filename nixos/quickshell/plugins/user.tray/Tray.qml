// Mirrors waybar's `tray` module (StatusNotifierItem host) - this is what
// OBS's --minimize-to-tray docks into.
//
// Menus are opened with QsMenuAnchor rather than SystemTrayItem.display().
// display() hands the item's DBusMenu to Qt's *platform menu* backend, which
// only exists in QApplication mode and, even with `//@ pragma
// UseQApplication` set in shell.qml, silently fails to produce a window for
// plenty of real tray apps. QsMenuAnchor instead walks the DBusMenu and draws
// it with Quickshell's own renderer, so it works regardless of what toolkit
// exported the menu and it picks up the palette from Colors.qml.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../" // shell root qmldir - exposes the Colors singleton

RowLayout {
    id: root
    spacing: 6

    Repeater {
        model: SystemTray.items

        delegate: IconImage {
            id: iconDelegate
            required property var modelData
            // nm-applet stays running (NetworkManager wants a secret/polkit
            // agent around) but its icon is hidden: the bar's own network
            // widget now owns picking a network, via the native
            // NetworkPanel.qml, so a second network icon here would just be a
            // visually mismatched duplicate.
            visible: modelData.id !== "nm-applet"
            implicitWidth: visible ? 16 : 0
            implicitHeight: 16
            source: modelData.icon

            QsMenuAnchor {
                id: menuAnchor
                menu: iconDelegate.modelData.menu
                anchor {
                    item: iconDelegate
                    edges: Edges.Bottom
                    gravity: Edges.Bottom
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        // Right click is the conventional "show me the menu"
                        // gesture, and every SNI that has a menu should honour
                        // it here.
                        if (iconDelegate.modelData.hasMenu)
                            menuAnchor.open();
                        else
                            iconDelegate.modelData.secondaryActivate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        iconDelegate.modelData.secondaryActivate();
                    } else if (iconDelegate.modelData.onlyMenu) {
                        // Spec: these items have no activate() action at all,
                        // so a left click has to fall through to the menu or
                        // it does nothing at all.
                        menuAnchor.open();
                    } else {
                        iconDelegate.modelData.activate();
                    }
                }
            }
        }
    }
}
