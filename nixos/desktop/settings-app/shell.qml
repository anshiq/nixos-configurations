// Desktop settings app: Wi-Fi, Bluetooth, Sound, Display, Power, Capture,
// Appearance, Lock screen, Services, Dev servers, Credentials. A standalone
// Quickshell config (its own process, its own window) rather than a panel
// inside the bar's shell, so a bug here can never take the bar or - worse -
// the lock screen down with it.
//
// Launch:  settings-app [page]        (see desktop/settings-app.nix)
//   page = wifi | bluetooth | sound | display | power | capture | appearance
//        | lockscreen | services | devservers | credentials
// Directly: quickshell -n -p /etc/nixos/desktop/settings-app
// Switch page in a running window:
//   quickshell ipc -p ~/.config/settings-app call settings open <page>
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

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
            id: "capture",
            title: "Capture",
            icon: Icons.camera,
            group: "",
            src: "pages/CapturePage.qml"
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
        },
        {
            id: "services",
            title: "Services",
            icon: Icons.server,
            group: "System",
            src: "pages/ServicesPage.qml"
        },
        {
            id: "devservers",
            title: "Dev servers",
            icon: Icons.terminal,
            group: "",
            src: "pages/DevServicesPage.qml"
        },
        {
            id: "credentials",
            title: "Credentials",
            icon: Icons.key,
            group: "",
            src: "pages/CredentialsPage.qml"
        }
    ]

    // SETTINGS_PAGE lets the launcher script open straight onto a page.
    property string current: {
        const wanted = Quickshell.env("SETTINGS_PAGE") || "wifi";
        return pages.some(p => p.id === wanted) ? wanted : "wifi";
    }
    readonly property var currentPage: pages.find(p => p.id === current)

    // `settings-app <page>` on an already open window lands here.
    IpcHandler {
        target: "settings"
        function open(page: string): void {
            if (app.pages.some(p => p.id === page))
                app.current = page;
        }
    }

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

                    // Scrolls when the window is shorter than the page list.
                    Flickable {
                        id: navFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: navColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick

                        ColumnLayout {
                            id: navColumn
                            width: navFlick.width
                            spacing: 2

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
                                        Layout.topMargin: 12
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
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
                        }
                    }
                }
            }

            Item {
                id: contentArea
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: sidebar.right
                anchors.right: parent.right

                // Check the page file exists before loading it: pages are
                // added by different modules, and a missing one should show a
                // placeholder rather than a load error.
                FileView {
                    id: pageFile
                    path: app.currentPage ? `${Quickshell.shellDir}/${app.currentPage.src}` : ""
                    printErrors: false
                    blockLoading: true
                    property string okPath: ""
                    readonly property bool present: path !== "" && okPath === path
                    onLoaded: okPath = path
                    onLoadFailed: okPath = ""
                }

                // Only the current page exists; switching pages destroys the
                // old one along with its timers and processes.
                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    source: pageFile.present ? app.currentPage.src : ""
                    onLoaded: {
                        if (item && item.hostWindow !== undefined)
                            item.hostWindow = win;
                        fade.restart();
                    }
                    NumberAnimation on opacity {
                        id: fade
                        from: 0
                        to: 1
                        duration: 140
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 72, 420)
                    visible: !pageFile.present || pageLoader.status === Loader.Error
                    spacing: 10
                    Glyph {
                        text: Icons.puzzle
                        font.pixelSize: 34
                        color: Theme.textDim
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: !pageFile.present ? `${app.currentPage ? app.currentPage.title : "This page"} is not available yet` : "This page failed to load"
                        color: pageFile.present ? Theme.danger : Theme.brightForeground
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: !pageFile.present ? "Its page file is not installed in this build." : "See `quickshell log` for the error."
                        color: Theme.textDim
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
