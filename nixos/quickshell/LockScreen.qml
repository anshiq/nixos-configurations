// Session lock (ext-session-lock) authenticated through the
// `quickshell-lock` PAM service. Wallpaper comes from
// ~/.local/state/desktop/lockscreen.json ({"wallpaper": "/abs/path"}),
// falling back to the current desktop wallpaper.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs

Scope {
    id: root

    readonly property string stateDir: `${Quickshell.env("HOME")}/.local/state/desktop`
    readonly property string defaultWallpaper: `${stateDir}/wallpaper.png`
    property string customWallpaper: ""

    function lock() {
        sessionLock.locked = true;
    }

    function fileUrl(path) {
        // encodeURI leaves # and ? alone, which a file URL cannot carry raw.
        return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    Connections {
        target: Session
        function onLockRequested() {
            root.lock();
        }
    }

    FileView {
        path: `${root.stateDir}/lockscreen.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.customWallpaper = JSON.parse(text()).wallpaper || "";
            } catch (e) {
                root.customWallpaper = "";
            }
        }
        onLoadFailed: root.customWallpaper = ""
    }

    WlSessionLock {
        id: sessionLock
        onLockedChanged: Session.locked = locked

        surface: Component {
            WlSessionLockSurface {
                id: surface

                PamContext {
                    id: pam
                    config: "quickshell-lock"

                    // The password typed at submit time, answered whenever PAM
                    // asks. Reading the field at that moment instead races
                    // with clearing it after a failed attempt.
                    property string pendingPassword: ""
                    property string errorText: ""

                    function submit(password) {
                        if (active)
                            return;
                        pendingPassword = password;
                        errorText = "";
                        start();
                    }

                    onResponseRequiredChanged: if (responseRequired)
                        respond(pendingPassword)

                    onCompleted: result => {
                        pendingPassword = "";
                        if (result === PamResult.Success) {
                            sessionLock.locked = false;
                        } else {
                            passwordField.text = "";
                            errorText = result === PamResult.Failed ? "Incorrect password" : "Authentication error";
                            passwordField.forceActiveFocus();
                        }
                    }

                    onError: err => {
                        pendingPassword = "";
                        errorText = "PAM error: " + err;
                    }
                }

                Image {
                    id: wallpaper
                    anchors.fill: parent
                    source: root.fileUrl(root.customWallpaper !== "" ? root.customWallpaper : root.defaultWallpaper)
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    onStatusChanged: if (status === Image.Error && root.customWallpaper !== "")
                        root.customWallpaper = ""
                }

                Rectangle {
                    anchors.fill: parent
                    color: Colors.background
                }

                MultiEffect {
                    anchors.fill: parent
                    source: wallpaper
                    visible: wallpaper.status === Image.Ready
                    blurEnabled: true
                    blur: 0.6
                    blurMax: 48
                }

                Rectangle {
                    anchors.fill: parent
                    color: Colors.background
                    opacity: 0.35
                }

                Text {
                    id: clock
                    property date now: new Date()
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -100
                    color: Colors.brightForeground
                    font.family: Colors.font
                    font.pointSize: 48
                    font.bold: true
                    text: Qt.formatDateTime(now, "HH:mm")

                    // Minute-aligned.
                    Timer {
                        running: true
                        repeat: true
                        interval: 60000 - (clock.now.getTime() % 60000) + 50
                        onTriggered: clock.now = new Date()
                    }
                }

                Rectangle {
                    id: passwordBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 40
                    width: 300
                    height: 52
                    radius: 26
                    color: Colors.background
                    border.width: 2
                    border.color: pam.errorText !== "" ? Colors.red : Colors.accent

                    TextField {
                        id: passwordField
                        anchors.fill: parent
                        anchors.margins: 8
                        echoMode: TextInput.Password
                        placeholderText: pam.active ? "Checking..." : "Password"
                        placeholderTextColor: Qt.alpha(Colors.foreground, 0.5)
                        color: Colors.foreground
                        font.family: Colors.font
                        background: null
                        focus: true
                        // Frozen while PAM holds the staged password.
                        enabled: !pam.active

                        Component.onCompleted: forceActiveFocus()
                        // Re-enabling does not restore focus on its own.
                        onEnabledChanged: if (enabled)
                            forceActiveFocus()
                        onAccepted: pam.submit(text)
                        onTextChanged: if (text !== "")
                            pam.errorText = ""
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: passwordBox.bottom
                    anchors.topMargin: 12
                    text: pam.errorText
                    color: Colors.red
                    font.family: Colors.font
                    font.pointSize: 11
                    visible: text !== ""
                }
            }
        }
    }
}
