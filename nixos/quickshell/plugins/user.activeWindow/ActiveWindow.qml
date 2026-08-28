// Mirrors waybar's hyprland/window module (max-length ~60, truncated).
import QtQuick
import Quickshell.Wayland
import "../../" // shell root qmldir - exposes the Colors singleton

Text {
    readonly property var toplevel: ToplevelManager.activeToplevel
    readonly property string rawTitle: toplevel ? toplevel.title : ""
    text: rawTitle.length > 60 ? rawTitle.substring(0, 57) + "..." : rawTitle
    color: Colors.foreground
    elide: Text.ElideRight
}
