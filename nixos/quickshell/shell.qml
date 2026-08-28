//@ pragma UseQApplication
// Kept for QApplication-mode icon/theme lookup (tray icons resolve through
// QIcon). It is NOT what makes tray menus work - that was the old theory
// behind SystemTrayItem.display(), which never actually rendered nm-applet's
// menu. Menus are drawn by QsMenuAnchor now; see plugins/user.tray/Tray.qml.
// Phases 2-6: bar parity, theme unification, launcher, power menu,
// notifications - see /home/nixos/.claude/plans/stateless-wishing-willow.md
// for the full migration plan and phase order. Waybar/wofi keep running
// alongside this until the user verifies each piece live. mako is fully
// replaced as of Phase 6 - see Notifications.qml.
import Quickshell

ShellRoot {
    Bar {}
    Launcher {}
    PowerMenu {}
    Notifications {}
    NetworkPanel {}
    LockScreen {}
}
