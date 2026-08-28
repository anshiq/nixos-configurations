// Phase 5: native replacement for waybar/scripts/power-menu.sh's
// wofi-based UI. Same underlying commands, just a QML menu instead of two
// sequential `wofi --dmenu` calls. Triggered via IPC (see PowerButton.qml
// and hyprland.lua's SUPER+CTRL+L-adjacent lock keybind) rather than a
// direct QML reference, since Quickshell components live as siblings under
// ShellRoot (shell.qml), not in a shared parent/child tree.
//
// "Idle Settings" opens a small panel to change the lock/screen-off/suspend
// idle timeouts at runtime - see quickshell/scripts/idle-settings.sh, which
// is the only thing that writes ~/.config/hypr/hypridle.conf (home-manager
// no longer manages it - see desktop/home.nix) from
// ~/.local/state/quickshell/idle-settings.json.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-powermenu"

    readonly property var options: ["Lock", "Logout", "Suspend", "Reboot", "Shutdown", "Idle Settings"]
    readonly property var optionIcons: ({
            "Lock": "", // nf-fa-lock
            "Logout": "", // nf-fa-sign_out
            "Suspend": "", // nf-fa-moon_o
            "Reboot": "", // nf-fa-refresh
            "Shutdown": "", // nf-fa-power_off
            "Idle Settings": "" // nf-fa-cog
        })
    property string confirmAction: "" // "" | "Reboot" | "Shutdown"
    property int currentIndex: 0
    property bool settingsOpen: false

    // Mirrors the defaults in idle-settings.sh - shown until the state file
    // loads (or if it doesn't exist yet).
    property int lockMinutes: 30
    property int screenOffMinutes: 32
    property int suspendMinutes: 35

    function open() {
        root.confirmAction = "";
        root.settingsOpen = false;
        root.currentIndex = 0;
        root.visible = true;
    }

    function closeMenu() {
        root.visible = false;
    }

    function runCommand(cmd) {
        execProc.command = ["bash", "-c", cmd];
        execProc.running = true;
    }

    function activate(choice) {
        switch (choice) {
        case "Lock":
            // Phase 7: LockScreen.qml is the active lock now - fallback is
            // still `pidof hyprlock || hyprlock` if it ever misbehaves.
            root.runCommand("quickshell ipc call lockscreen lock");
            root.closeMenu();
            break;
        case "Logout":
            // UWSM-managed session (desktop/system.nix, withUWSM = true) -
            // must go through `uwsm stop`, not a raw compositor exit, or
            // control never returns cleanly to SDDM.
            root.runCommand("uwsm stop");
            root.closeMenu();
            break;
        case "Suspend":
            root.runCommand("systemctl suspend");
            root.closeMenu();
            break;
        case "Reboot":
        case "Shutdown":
            root.confirmAction = choice;
            root.currentIndex = 0;
            break;
        case "Idle Settings":
            root.settingsOpen = true;
            break;
        }
    }

    function confirmYes() {
        root.runCommand(root.confirmAction === "Reboot" ? "systemctl reboot" : "systemctl poweroff");
        root.closeMenu();
    }

    function applyIdleSettings(json) {
        try {
            const s = JSON.parse(json);
            if (s.lockMinutes)
                root.lockMinutes = s.lockMinutes;
            if (s.screenOffMinutes)
                root.screenOffMinutes = s.screenOffMinutes;
            if (s.suspendMinutes)
                root.suspendMinutes = s.suspendMinutes;
        } catch (e) {
            // idle-settings.json doesn't exist yet (before hypridle's first
            // start has run idle-settings.sh generate) - keep the defaults
            // above, which match the script's own fallback values.
        }
    }

    function saveIdleSettings() {
        root.runCommand(`$HOME/.config/quickshell/scripts/idle-settings.sh set ${root.lockMinutes} ${root.screenOffMinutes} ${root.suspendMinutes}`);
        root.settingsOpen = false;
    }

    Process {
        id: execProc
    }

    FileView {
        id: idleSettingsFile
        path: `${Quickshell.env("HOME")}/.local/state/quickshell/idle-settings.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyIdleSettings(text())
        onTextChanged: root.applyIdleSettings(text())
    }

    IpcHandler {
        target: "powerMenu"
        function open(): void {
            root.open();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.settingsOpen)
                root.settingsOpen = false;
            else if (root.confirmAction !== "")
                root.confirmAction = "";
            else
                root.closeMenu();
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.settingsOpen ? 340 : 320
        height: root.settingsOpen ? 260 : (root.confirmAction === "" ? 300 : 160)
        radius: 6
        color: Colors.background
        border.color: Colors.muted
        border.width: 1

        MouseArea {
            // Swallows clicks so they don't fall through to the backdrop
            // MouseArea above.
            anchors.fill: parent
        }

        Column {
            visible: !root.settingsOpen
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            Text {
                text: root.confirmAction === "" ? "Power" : (root.confirmAction === "Reboot" ? "Reboot now?" : "Power off now?")
                color: Colors.brightForeground
                font.bold: true
            }

            Repeater {
                model: root.confirmAction === "" ? root.options : ["No", "Yes"]
                delegate: Rectangle {
                    id: delegateRoot
                    required property int index
                    required property string modelData
                    property bool hovered: false
                    width: 296
                    height: 32
                    radius: 4
                    color: delegateRoot.index === root.currentIndex ? Colors.selection : (delegateRoot.hovered ? Colors.muted : "transparent")

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        spacing: 10

                        Text {
                            width: 16
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                            font.family: "JetBrainsMono Nerd Font"
                            color: delegateRoot.index === root.currentIndex ? Colors.accent : Colors.foreground
                            text: root.optionIcons[delegateRoot.modelData] ?? ""
                            visible: text !== ""
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Colors.foreground
                            text: delegateRoot.modelData
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: delegateRoot.hovered = true
                        onExited: delegateRoot.hovered = false
                        onClicked: {
                            root.currentIndex = delegateRoot.index;
                            if (root.confirmAction === "")
                                root.activate(delegateRoot.modelData);
                            else if (delegateRoot.modelData === "Yes")
                                root.confirmYes();
                            else
                                root.closeMenu();
                        }
                    }
                }
            }
        }

        Column {
            visible: root.settingsOpen
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Text {
                text: "Idle Settings (minutes)"
                color: Colors.brightForeground
                font.bold: true
            }

            Repeater {
                model: [
                    {
                        label: "Lock",
                        get: () => root.lockMinutes,
                        set: v => root.lockMinutes = v
                    },
                    {
                        label: "Screen off",
                        get: () => root.screenOffMinutes,
                        set: v => root.screenOffMinutes = v
                    },
                    {
                        label: "Suspend",
                        get: () => root.suspendMinutes,
                        set: v => root.suspendMinutes = v
                    }
                ]

                delegate: Row {
                    id: settingRow
                    required property var modelData
                    width: 316
                    height: 32
                    spacing: 8

                    Text {
                        width: 90
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.foreground
                        text: settingRow.modelData.label
                    }

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 4
                        color: Colors.selection
                        Text {
                            anchors.centerIn: parent
                            color: Colors.brightForeground
                            text: "-"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: settingRow.modelData.set(Math.max(5, settingRow.modelData.get() - 5))
                        }
                    }

                    Text {
                        width: 40
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.brightForeground
                        text: settingRow.modelData.get()
                    }

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 4
                        color: Colors.selection
                        Text {
                            anchors.centerIn: parent
                            color: Colors.brightForeground
                            text: "+"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: settingRow.modelData.set(Math.min(180, settingRow.modelData.get() + 5))
                        }
                    }
                }
            }

            Row {
                spacing: 8
                anchors.right: parent.right

                Rectangle {
                    width: 80
                    height: 32
                    radius: 4
                    color: Colors.selection
                    Text {
                        anchors.centerIn: parent
                        color: Colors.foreground
                        text: "Back"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.settingsOpen = false
                    }
                }

                Rectangle {
                    width: 80
                    height: 32
                    radius: 4
                    color: Colors.accent
                    Text {
                        anchors.centerIn: parent
                        color: Colors.background
                        text: "Save"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.saveIdleSettings()
                    }
                }
            }
        }
    }

    Item {
        focus: root.visible

        Keys.onEscapePressed: {
            if (root.settingsOpen)
                root.settingsOpen = false;
            else if (root.confirmAction !== "")
                root.confirmAction = "";
            else
                root.closeMenu();
        }
        Keys.onDownPressed: {
            if (root.settingsOpen)
                return;
            const n = root.confirmAction === "" ? root.options.length : 2;
            root.currentIndex = (root.currentIndex + 1) % n;
        }
        Keys.onUpPressed: {
            if (root.settingsOpen)
                return;
            const n = root.confirmAction === "" ? root.options.length : 2;
            root.currentIndex = (root.currentIndex - 1 + n) % n;
        }
        Keys.onReturnPressed: {
            if (root.settingsOpen)
                return;
            if (root.confirmAction === "")
                root.activate(root.options[root.currentIndex]);
            else if (root.currentIndex === 1)
                root.confirmYes();
            else
                root.closeMenu();
        }
    }
}
