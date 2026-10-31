// Shell-wide state shared by the bar, its panels and the IPC handlers.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // True while the lock screen is up; widgets pause their timers.
    property bool locked: false

    // The one open overlay: "", "launcher", "clipboard" or "powermenu".
    property string overlay: ""

    // Handled by LockScreen.
    signal lockRequested

    function lock() {
        root.lockRequested();
    }

    function toggle(name) {
        root.overlay = root.overlay === name ? "" : name;
    }

    function open(name) {
        root.overlay = name;
    }

    function close(name) {
        if (root.overlay === name)
            root.overlay = "";
    }

    onLockedChanged: if (locked)
        overlay = ""
}
