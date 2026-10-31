// Application launcher over the desktop entries Quickshell indexes.
// Keys: type to filter, Up/Down, Enter launches, Esc closes.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs
import qs.components

Overlay {
    id: root

    name: "launcher"
    cardWidth: 560
    cardHeight: 420
    visible: Session.overlay === "launcher"

    property var filtered: []

    function updateFilter() {
        const q = search.text.toLowerCase();
        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay && (q === "" || e.name.toLowerCase().includes(q) || (e.genericName || "").toLowerCase().includes(q)));
        // Prefix matches first, then alphabetical.
        apps.sort((a, b) => {
            const pa = a.name.toLowerCase().startsWith(q) ? 0 : 1;
            const pb = b.name.toLowerCase().startsWith(q) ? 0 : 1;
            return pa - pb || a.name.localeCompare(b.name);
        });
        root.filtered = apps;
        list.currentIndex = apps.length > 0 ? 0 : -1;
    }

    function launch(index) {
        const entry = root.filtered[index];
        if (!entry)
            return;
        entry.execute();
        Session.close("launcher");
    }

    onVisibleChanged: {
        search.text = "";
        if (visible) {
            root.updateFilter();
            search.input.forceActiveFocus();
        } else {
            root.filtered = [];
        }
    }

    onDismissed: Session.close("launcher")

    // The desktop entry index loads asynchronously and can change later.
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            if (root.visible)
                root.updateFilter();
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12

        SearchField {
            id: search
            width: parent.width
            placeholder: "Search applications"
            onTextChanged: if (root.visible)
                root.updateFilter()

            onKeyPressed: event => {
                if (event.key === Qt.Key_Escape)
                    Session.close("launcher");
                else if (event.key === Qt.Key_Down)
                    list.incrementCurrentIndex();
                else if (event.key === Qt.Key_Up)
                    list.decrementCurrentIndex();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.launch(list.currentIndex);
                else
                    return;
                event.accepted = true;
            }
        }

        ListView {
            id: list
            anchors.top: search.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            width: parent.width
            clip: true
            spacing: 2
            model: root.filtered
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            delegate: ListRow {
                required property var modelData
                required property int index
                width: ListView.view.width
                text: modelData.name
                hint: modelData.genericName || ""
                current: index === ListView.view.currentIndex
                onActivated: root.launch(index)
                onHoveredRow: list.currentIndex = index
            }
        }

        Text {
            anchors.centerIn: list
            visible: root.filtered.length === 0
            text: "No matches"
            color: Qt.alpha(Colors.foreground, 0.5)
            font.family: Colors.font
            font.pixelSize: 13
        }
    }
}
