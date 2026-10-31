// Desktop shell: bar, launcher, clipboard history, power menu,
// notifications, share/record indicator and lock screen. Runs as the `quickshell` user service.
//
// IPC (`quickshell ipc call <target> <function>`):
//   launcher openDrun | lockscreen lock | powermenu toggle | clipboard toggle
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Bar {}
    Launcher {}
    ClipboardPanel {}
    PowerMenu {}
    Notifications {}
    ShareIndicator {}
    LockScreen {}

    IpcHandler {
        target: "launcher"
        function openDrun(): void {
            Session.open("launcher");
        }
    }

    IpcHandler {
        target: "lockscreen"
        function lock(): void {
            Session.lock();
        }
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void {
            Session.toggle("powermenu");
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            Session.toggle("clipboard");
        }
    }
}
