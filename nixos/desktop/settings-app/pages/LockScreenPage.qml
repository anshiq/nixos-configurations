// Lock screen: choose the wallpaper behind the Quickshell lock screen.
//
// The choice is a one-key JSON file, ~/.local/state/desktop/lockscreen.json
// ({"wallpaper": "/abs/path"}; empty or missing = the stock wallpaper), which
// quickshell/LockScreen.qml watches. Candidates come from the repo's
// desktop/wallpapers/ and from ~/Pictures/Wallpapers (drop your own images
// there). The choice is also published for the boot login screen via
// greeter-sync (desktop/greeter-sync.nix). This does not touch the desktop
// background (rendered per theme by render-wallpaper) or hyprlock, the
// manual fallback.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import ".."

Page {
    id: page
    title: "Lock screen"
    subtitle: "Behind the password prompt and at boot"

    readonly property string home: Quickshell.env("HOME")
    readonly property string defaultPath: home + "/.local/state/desktop/wallpaper.png"

    property string selected: ""
    property var images: []
    property string errorMessage: ""

    // Percent-encode what QUrl would otherwise misread (# and ? in names).
    function fileUrl(p) {
        return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    function baseName(p) {
        const f = p.split("/").pop();
        const i = f.lastIndexOf(".");
        return i > 0 ? f.slice(0, i) : f;
    }

    function load() {
        loader.run(["bash", Quickshell.shellDir + "/scripts/wallpapers.sh"]);
    }

    function choose(path) {
        page.errorMessage = "";
        page.selected = path;
        // Save the choice, then publish it for the login greeter as well
        // (greeter-sync copies the wallpaper where the greeter can read it).
        save.run(["bash", "-c", `f="$HOME/.local/state/desktop/lockscreen.json"; mkdir -p "$(dirname "$f")" && printf '%s\\n' "$1" > "$f.tmp" && mv "$f.tmp" "$f" || exit 1; if command -v greeter-sync >/dev/null 2>&1; then greeter-sync >/dev/null 2>&1 || true; fi`, "_", JSON.stringify({
                "wallpaper": path
            })]);
    }

    Component.onCompleted: load()

    Cmd {
        id: loader
        onFinished: (code, out) => {
            const imgs = [];
            let sel = "";
            for (const l of out.split("\n")) {
                if (l.startsWith("state ")) {
                    try {
                        sel = JSON.parse(l.slice(6)).wallpaper || "";
                    } catch (e) {}
                } else if (l.startsWith("img ")) {
                    imgs.push(l.slice(4));
                }
            }
            page.images = imgs;
            page.selected = sel;
        }
    }

    Cmd {
        id: save
        onFinished: (code, out, err) => {
            if (code !== 0)
                page.errorMessage = "Could not save the choice: " + (err.trim() || "unknown error");
        }
    }

    headerTrailing: [
        Btn {
            text: "Open folder"
            icon: Icons.folder
            onClicked: Quickshell.execDetached(["xdg-open", page.home + "/Pictures/Wallpapers"])
        },
        Btn {
            text: "Refresh"
            icon: Icons.refresh
            busy: loader.running
            onClicked: page.load()
        }
    ]

    Banner {
        text: page.errorMessage
        kind: "error"
    }

    // --- preview: same recipe as LockScreen.qml (blurred wallpaper, dimmed)
    Rectangle {
        id: preview
        Layout.fillWidth: true
        Layout.preferredHeight: 250
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border
        clip: true

        Image {
            id: previewImg
            anchors.fill: parent
            anchors.margins: 1
            source: page.fileUrl(page.selected !== "" ? page.selected : page.defaultPath)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 1000
            visible: false
        }
        MultiEffect {
            anchors.fill: previewImg
            source: previewImg
            blurEnabled: true
            blur: 0.6
            blurMax: 32
        }
        Rectangle {
            anchors.fill: previewImg
            color: Theme.background
            opacity: 0.35
        }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 14
            Label {
                text: "12:34"
                color: Theme.brightForeground
                font.pixelSize: 52
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 220
                Layout.preferredHeight: 36
                radius: 18
                color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.7)
                border.width: 1
                border.color: Theme.border
                Label {
                    anchors.centerIn: parent
                    text: "Password"
                    color: Theme.textDim
                }
            }
        }
    }

    SectionLabel {
        text: "Choose a wallpaper"
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 12
        rowSpacing: 12

        // First tile: the stock wallpaper (empty selection).
        Repeater {
            model: [""].concat(page.images)
            delegate: Rectangle {
                id: tile
                required property string modelData
                readonly property bool active: page.selected === modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 150
                radius: Theme.radius
                color: Theme.surface
                border.width: active ? 2 : 1
                border.color: active ? Theme.accent : Theme.border
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: page.fileUrl(tile.modelData !== "" ? tile.modelData : page.defaultPath)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 420
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 30
                    color: Qt.rgba(0, 0, 0, 0.55)
                    Label {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 34
                        text: tile.modelData === "" ? "Default" : page.baseName(tile.modelData)
                        color: "#ffffff"
                        font.pixelSize: Theme.fsSmall
                    }
                    Glyph {
                        visible: tile.active
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.check
                        font.pixelSize: 16
                        color: Theme.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.choose(tile.modelData)
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 4
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        color: Theme.textDim
        font.pixelSize: Theme.fsSmall
        text: "Add your own images by putting them in ~/Pictures/Wallpapers (PNG or JPG), then press Refresh. The lock screen applies the choice the next time it locks, and the login screen at the next boot. Pictures you choose are copied where the login screen can read them, so they are visible to every local user."
    }
}
