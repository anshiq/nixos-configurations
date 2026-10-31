// Boot-time login screen: a greetd greeter that looks like the Quickshell lock
// screen (quickshell/LockScreen.qml) - blurred wallpaper, dim, clock, pill
// password field - so the first screen after boot matches the one after lock.
//
// Run by greetd inside `cage` (a one-window kiosk compositor, so the window
// below simply fills the screen); see desktop/greeter.nix. Configuration comes
// in through the environment that module sets:
//   GREETER_USER                login name to authenticate (editable on screen)
//   GREETER_SESSION_CMD         command that starts the desktop session
//   GREETER_SHARED_DIR          where greeter-sync publishes theme.json + wallpaper
//   GREETER_FALLBACK_WALLPAPER  wallpaper used when nothing has been published yet
//
// The greeter runs as the unprivileged `greeter` user before anyone logs in,
// so it cannot read ~/.local/state: palette and wallpaper reach it through
// GREETER_SHARED_DIR, copied there by `greeter-sync` (called from
// theme-switch.sh and the Settings app's Lock screen page).
//
// Run it in a normal session to preview the look (no greetd -> "preview"):
//   quickshell -p /etc/nixos/desktop/greeter
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

ShellRoot {
    id: root

    readonly property string sharedDir: Quickshell.env("GREETER_SHARED_DIR") || "/var/lib/quickshell-greeter"
    readonly property string fallbackWallpaper: Quickshell.env("GREETER_FALLBACK_WALLPAPER") || ""
    readonly property var sessionCommand: (Quickshell.env("GREETER_SESSION_CMD") || "uwsm start hyprland-uwsm.desktop").split(" ").filter(s => s.length > 0)

    property string user: Quickshell.env("GREETER_USER") || ""
    property bool editingUser: user === ""
    property string pendingPassword: ""
    property string errorText: ""
    property bool useFallbackWallpaper: false
    // "poweroff" / "reboot" after the first click; a second click confirms.
    property string confirming: ""

    readonly property bool busy: Greetd.state !== GreetdState.Inactive

    // Same defaults as quickshell/Colors.qml; replaced by theme.json below.
    property color background: "#1a1b26"
    property color foreground: "#a9b1d6"
    property color brightForeground: "#c0caf5"
    property color red: "#f7768e"
    property color accent: "#7aa2f7"

    function applyTheme(json) {
        try {
            const t = JSON.parse(json);
            if (t.background)
                root.background = t.background;
            if (t.foreground)
                root.foreground = t.foreground;
            if (t.brightForeground)
                root.brightForeground = t.brightForeground;
            if (t.red)
                root.red = t.red;
            if (t.accent)
                root.accent = t.accent;
        } catch (e) {
            // Torn or missing file: keep the defaults above.
        }
    }

    FileView {
        path: `${root.sharedDir}/theme.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyTheme(text())
    }

    function submit(password) {
        if (!Greetd.available) {
            root.errorText = "Preview only - not running under greetd.";
            return;
        }
        if (root.busy || root.user === "")
            return;
        root.errorText = "";
        // Staged here and answered when PAM asks, rather than read out of the
        // field at that moment (same reasoning as LockScreen.qml's pam.submit).
        root.pendingPassword = password;
        Greetd.createSession(root.user);
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.pendingPassword);
                root.pendingPassword = "";
            } else if (error) {
                root.errorText = message;
            }
        }

        function onAuthFailure(message) {
            root.pendingPassword = "";
            root.errorText = "Incorrect password";
            passwordField.text = "";
            // A failed attempt leaves the greetd session open; close it so
            // the next Enter starts a clean one.
            Greetd.cancelSession();
        }

        function onReadyToLaunch() {
            // quit=true: the greeter exits, which is the signal for greetd to
            // start the session it was just handed.
            Greetd.launch(root.sessionCommand, [], true);
        }
    }

    Process {
        id: power
    }

    Timer {
        id: confirmReset
        interval: 3000
        onTriggered: root.confirming = ""
    }

    function powerAction(kind) {
        if (root.confirming === kind) {
            root.confirming = "";
            power.command = ["systemctl", kind];
            power.running = true;
        } else {
            root.confirming = kind;
            confirmReset.restart();
        }
    }

    FloatingWindow {
        id: window
        title: "Login"
        color: root.background

        Item {
            anchors.fill: parent

            Image {
                id: wallpaper
                anchors.fill: parent
                source: root.useFallbackWallpaper ? "file://" + root.fallbackWallpaper : `file://${root.sharedDir}/wallpaper`
                fillMode: Image.PreserveAspectCrop
                visible: false
                // Nothing published yet (or an undecodable file): use the
                // wallpaper baked in at build time instead of a blank screen.
                onStatusChanged: if (status === Image.Error && root.fallbackWallpaper !== "")
                    root.useFallbackWallpaper = true
            }

            // Same blur and dim as LockScreen.qml.
            MultiEffect {
                anchors.fill: parent
                source: wallpaper
                blurEnabled: true
                blur: 0.6
                blurMax: 48
            }

            Rectangle {
                anchors.fill: parent
                color: root.background
                opacity: 0.35
            }

            Text {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: -100
                }
                color: root.brightForeground
                font.pointSize: 48
                font.bold: true
                text: {
                    clockTick.triggered;
                    return Qt.formatDateTime(new Date(), "HH:mm");
                }

                Timer {
                    id: clockTick
                    interval: 1000
                    running: true
                    repeat: true
                }
            }

            // Who is logging in. Click to change it (only matters on a
            // machine with more than one account).
            Item {
                id: userRow
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: -28
                }
                width: 300
                height: 28

                Text {
                    anchors.centerIn: parent
                    visible: !root.editingUser
                    text: root.user
                    color: root.foreground
                    font.pointSize: 14

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.busy
                        onClicked: {
                            root.editingUser = true;
                            userField.forceActiveFocus();
                        }
                    }
                }

                TextInput {
                    id: userField
                    anchors.fill: parent
                    visible: root.editingUser
                    horizontalAlignment: TextInput.AlignHCenter
                    color: root.brightForeground
                    font.pointSize: 14
                    text: root.user
                    selectByMouse: true
                    onAccepted: {
                        root.user = text.trim();
                        root.editingUser = root.user === "";
                        passwordField.forceActiveFocus();
                    }
                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        visible: userField.text === ""
                        text: "Username"
                        color: root.foreground
                        opacity: 0.6
                        font.pointSize: 14
                    }
                }
            }

            Rectangle {
                id: passwordBox
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: 40
                }
                width: 300
                height: 52
                radius: 26
                color: root.background
                border.width: 2
                border.color: root.errorText.length > 0 ? root.red : root.accent

                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: root.foreground
                    font.pointSize: 12
                    clip: true
                    focus: true
                    // Frozen while greetd is mid-conversation, like the lock screen.
                    enabled: !root.busy

                    Component.onCompleted: forceActiveFocus()
                    // Re-enabling does not restore focus on its own; without
                    // this the field is dead after every failed attempt.
                    onEnabledChanged: if (enabled)
                        forceActiveFocus()
                    onAccepted: root.submit(text)
                    onTextChanged: if (text.length > 0)
                        root.errorText = ""

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: passwordField.text === ""
                        text: root.busy ? "Checking..." : "Password"
                        color: root.foreground
                        opacity: 0.6
                        font.pointSize: 12
                    }
                }
            }

            Text {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: passwordBox.bottom
                    topMargin: 12
                }
                text: root.errorText
                color: root.red
                font.pointSize: 11
                visible: text.length > 0
            }

            // Power controls (an SDDM-style login screen had them; without
            // them a screen with no session yet cannot be shut down).
            Row {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    margins: 24
                }
                spacing: 12

                Repeater {
                    model: [
                        {
                            kind: "reboot",
                            glyph: String.fromCodePoint(0xF0709),
                            label: "Restart"
                        },
                        {
                            kind: "poweroff",
                            glyph: String.fromCodePoint(0xF0425),
                            label: "Shut down"
                        }
                    ]
                    delegate: Rectangle {
                        id: powerButton
                        required property var modelData
                        readonly property bool armed: root.confirming === modelData.kind
                        width: armed ? 150 : 44
                        height: 44
                        radius: 22
                        color: root.background
                        border.width: 2
                        border.color: armed ? root.red : root.accent
                        opacity: 0.9
                        Behavior on width {
                            NumberAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: powerButton.armed ? powerButton.modelData.label + "?" : powerButton.modelData.glyph
                            color: powerButton.armed ? root.red : root.brightForeground
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: powerButton.armed ? 15 : 20
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.powerAction(powerButton.modelData.kind)
                        }
                    }
                }
            }

            Text {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    margins: 24
                }
                visible: !Greetd.available
                text: "preview - not connected to greetd"
                color: root.foreground
                opacity: 0.6
                font.pointSize: 10
            }
        }
    }
}
