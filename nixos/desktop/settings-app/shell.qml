// Desktop settings app: Wi-Fi, Bluetooth, Sound, Display, Power, Appearance,
// Lock screen. A standalone Quickshell config (its own process, its own
// window) rather than a panel inside the bar's shell, so a bug here can never
// take the bar or - worse - the lock screen down with it.
//
// Launch:  settings-app [page]        (see desktop/settings-app.nix)
//   page = wifi | bluetooth | sound | display | power | appearance | lockscreen
// Directly: quickshell -n -p /etc/nixos/desktop/settings-app
import QtQuick
import QtQuick.Layouts
import Quickshell

ShellRoot {
    id: app

    readonly property var pages: [
        {
            id: "wifi",
            title: "Wi-Fi",
            icon: Icons.wifi,
            group: "Network",
            src: "pages/WifiPage.qml"
        },
        {
            id: "bluetooth",
            title: "Bluetooth",
            icon: Icons.bluetooth,
            group: "",
            src: "pages/BluetoothPage.qml"
        },
        {
            id: "sound",
            title: "Sound",
            icon: Icons.volume,
            group: "Device",
            src: "pages/SoundPage.qml"
        },
        {
            id: "display",
            title: "Display",
            icon: Icons.display,
            group: "",
            src: "pages/DisplayPage.qml"
        },
        {
            id: "power",
            title: "Power",
            icon: Icons.battery,
            group: "",
            src: "pages/PowerPage.qml"
        },
        {
            id: "appearance",
            title: "Appearance",
            icon: Icons.palette,
            group: "Personalization",
            src: "pages/AppearancePage.qml"
        },
        {
            id: "lockscreen",
            title: "Lock screen",
            icon: Icons.lock,
            group: "",
            src: "pages/LockScreenPage.qml"
        }
    ]

    // SETTINGS_PAGE lets the launcher script (and a bar widget, later) open
    // straight onto a page.
    property string current: {
        const wanted = Quickshell.env("SETTINGS_PAGE") || "wifi";
        return pages.some(p => p.id === wanted) ? wanted : "wifi";
    }
    readonly property var currentPage: pages.find(p => p.id === current)

    FloatingWindow {
        id: win
        title: "Settings"
        color: Theme.background
        implicitWidth: 980
        implicitHeight: 640
        minimumSize: Qt.size(780, 520)
        onClosed: Qt.quit()

        // Ctrl+Q / Ctrl+W close the window. A Keys handler on the root item (not a
        // Shortcut) so it still fires while a text field has the focus: unhandled
        // key events bubble up to here.
        Item {
            id: frame
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Q || event.key === Qt.Key_W)) {
                    event.accepted = true;
                    Qt.quit();
                }
            }

            Rectangle {
                id: sidebar
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: 236
                color: Theme.sidebar

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Theme.border
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 10
                        Layout.leftMargin: 6
                        Glyph {
                            text: Icons.cog
                            color: Theme.brightForeground
                            Layout.preferredWidth: 26
                        }
                        Label {
                            text: "Settings"
                            color: Theme.brightForeground
                            font.pixelSize: 17
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: Theme.radiusSmall
                            color: closeMouse.containsMouse ? Theme.surfaceHover : "transparent"
                            Glyph {
                                anchors.centerIn: parent
                                text: Icons.close
                                font.pixelSize: 15
                                color: Theme.textDim
                            }
                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.quit()
                            }
                        }
                    }

                    Repeater {
                        model: app.pages
                        delegate: ColumnLayout {
                            id: navEntry
                            required property var modelData
                            readonly property bool active: app.current === modelData.id
                            Layout.fillWidth: true
                            spacing: 2

                            SectionLabel {
                                visible: navEntry.modelData.group !== ""
                                text: navEntry.modelData.group
                                Layout.topMargin: 14
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: Theme.radiusSmall
                                color: navEntry.active ? Theme.selection : (navMouse.containsMouse ? Theme.surfaceHover : "transparent")
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 90
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10
                                    Glyph {
                                        text: navEntry.modelData.icon
                                        color: navEntry.active ? Theme.selectionForeground : Theme.foreground
                                        Layout.preferredWidth: 26
                                    }
                                    Label {
                                        text: navEntry.modelData.title
                                        color: navEntry.active ? Theme.selectionForeground : Theme.brightForeground
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: navMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: app.current = navEntry.modelData.id
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            Item {
                id: contentArea
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: sidebar.right
                anchors.right: parent.right

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    source: app.currentPage ? app.currentPage.src : ""
                    onLoaded: fade.restart()
                    NumberAnimation on opacity {
                        id: fade
                        from: 0
                        to: 1
                        duration: 140
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: pageLoader.status === Loader.Error
                    text: "This page failed to load - see `quickshell log`."
                    color: Theme.danger
                }
            }
        }
    }
}
