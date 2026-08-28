// Phase 7 - now the active lock, triggered via
// `quickshell ipc call lockscreen lock` (see the IpcHandler below): the
// `lock` var in desktop/home.nix (hypridle's lock_cmd), the SUPER+CTRL+L
// bind in hyprland.lua, and PowerMenu.qml's Lock action all call that IPC
// target. `security.pam.services.quickshell-lock = {}` in
// desktop/system.nix backs `pam.config` below with a real PAM stack.
//
// hyprlock is deliberately kept installed and fully configured
// (programs.hyprlock.enable, hyprlock-{day,night}.conf) as a manual
// fallback - a lock screen that fails to unlock is a real lockout risk, so
// if this ever misbehaves, run `hyprlock` directly from another TTY
// (Ctrl+Alt+F2) or an SSH session to recover, or `pidof hyprlock ||
// hyprlock` as before. Only remove hyprlock once this has been verified
// solid across several real day/night cycles.
//
// Reuses hyprlockSettings' visual spec (wallpaper+blur, password field,
// HH:MM clock, day/night palette from Colors.qml) - see
// /home/nixos/.claude/plans/stateless-wishing-willow.md.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

Scope {
    id: root

    property bool wantLock: false

    IpcHandler {
        target: "lockscreen"
        function lock(): void {
            root.wantLock = true;
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.wantLock

        surface: Component {
            WlSessionLockSurface {
                id: surface

                PamContext {
                    id: pam
                    config: "quickshell-lock"

                    // The password is staged here on submit and answered from
                    // onResponseRequiredChanged, rather than read out of the
                    // TextField at response time.
                    //
                    // Two separate races made this "work only after a few
                    // tries" before:
                    //   1. The original code responded from
                    //      TextField.onTextChanged, which only fires if the
                    //      text changes *after* PAM asks. Type-then-Enter
                    //      settles the text before pam.start() is even called,
                    //      so nothing was ever sent - unless a keystroke
                    //      happened to land inside the window (retrying with
                    //      backspace, which is exactly what made it look
                    //      intermittent).
                    //   2. Reading passwordField.text at response time is
                    //      still wrong, because onCompleted clears that field
                    //      on a failed attempt. If PAM asks a second time in
                    //      one conversation, or a retry starts while the
                    //      clear is in flight, respond() sends "" and burns
                    //      the attempt silently.
                    // Staging the value removes both: what the user typed at
                    // submit time is what PAM gets, whatever the UI does after.
                    property string pendingPassword: ""

                    function submit(password) {
                        if (active)
                            return;
                        pendingPassword = password;
                        errorText = "";
                        start();
                    }

                    property string errorText: ""

                    onResponseRequiredChanged: {
                        if (responseRequired)
                            respond(pendingPassword);
                    }

                    onCompleted: result => {
                        pendingPassword = "";
                        if (result === PamResult.Success) {
                            root.wantLock = false;
                        } else {
                            passwordField.text = "";
                            errorText = result === PamResult.Failed ? "Incorrect password" : "Authentication error";
                            // The surface keeps keyboard focus across a failed
                            // attempt, but the field itself can lose it while
                            // it is disabled during authentication - without
                            // this, the next keystrokes go nowhere and it
                            // looks like the lock screen ignored them.
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
                    source: `file://${Quickshell.env("HOME")}/.config/wallpapers/wallpaper.png`
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }

                // Approximates hyprlockSettings' blur_passes/blur_size.
                MultiEffect {
                    anchors.fill: parent
                    source: wallpaper
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
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                        verticalCenterOffset: -100
                    }
                    color: Colors.brightForeground
                    font.pointSize: 48
                    font.bold: true
                    text: {
                        // Force a dependency on clockTick so this re-evaluates
                        // every tick without a direct property binding to it.
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
                    color: Colors.background
                    border.width: 2
                    border.color: pam.errorText.length > 0 ? Colors.red : Colors.accent

                    TextField {
                        id: passwordField
                        anchors.fill: parent
                        anchors.margins: 8
                        echoMode: TextInput.Password
                        placeholderText: pam.active ? "Checking..." : "Password"
                        color: Colors.foreground
                        background: null
                        focus: true
                        // Typing into the field while PAM is mid-conversation
                        // would edit text that has already been staged, so
                        // freeze it for the (very short) duration instead.
                        enabled: !pam.active

                        // The compositor hands keyboard focus to the lock
                        // surface, but nothing inside it claims focus on its
                        // own - `focus: true` alone loses out whenever the
                        // field is re-enabled after being disabled above.
                        Component.onCompleted: forceActiveFocus()
                        // Re-enabling a disabled item does not restore focus
                        // to it, so without this the field is dead after every
                        // failed attempt - which is precisely the "had to try
                        // several times" symptom.
                        onEnabledChanged: if (enabled)
                            forceActiveFocus()

                        // TextField's own accepted signal, rather than
                        // Keys.onReturnPressed: it fires for both Return and
                        // the keypad Enter, which the old handler missed.
                        onAccepted: pam.submit(text)

                        // Clear the error as soon as the user starts a fresh
                        // attempt, so a stale "Incorrect password" can't be
                        // mistaken for the result of the attempt in progress.
                        onTextChanged: if (text.length > 0)
                            pam.errorText = ""
                    }
                }

                Text {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: passwordBox.bottom
                        topMargin: 12
                    }
                    text: pam.errorText
                    color: Colors.red
                    font.pointSize: 11
                    visible: text.length > 0
                }
            }
        }
    }
}
