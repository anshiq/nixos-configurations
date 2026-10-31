// Credentials: switch an app's config/credential file between profiles.
//
// Same data and behaviour as the appcredrotator bar plugin it replaces:
//   ~/.local/share/appcredrotator/apps.json   which files, which profiles
//   ~/.local/share/appcredrotator/state.json  destination -> active source
// Applying a profile first saves the destination's current content back into
// the profile it was recorded as (apps rewrite tokens on refresh), snapshots
// a never-managed destination once to <path>.appcredrotator-original, then
// copies the chosen profile in and records it. Only paths are ever shown -
// file contents never leave the FileViews below.
//
// No processes: synchronous FileView reads/writes, on show and on Reload.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "CredentialsModel.js" as Model

Page {
    id: page
    title: "Credentials"
    subtitle: "Switch apps between alternate config and credential files"

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dataDir: home + "/.local/share/appcredrotator"
    readonly property string appsPath: dataDir + "/apps.json"
    readonly property string statePath: dataDir + "/state.json"

    property var apps: []
    // "appIdx:destIdx" -> source index picked but not applied yet.
    property var picked: ({})
    property string errorMessage: ""
    property string statusMessage: ""

    function reload() {
        page.picked = ({});
        page.statusMessage = "";
        const f = readFile(appsPath);
        if (!f.exists) {
            page.apps = [];
            page.errorMessage = "apps.json not found: " + Model.tildify(appsPath, home);
            return;
        }
        let validated;
        try {
            validated = Model.validateApps(JSON.parse(f.text), home);
        } catch (e) {
            page.apps = [];
            page.errorMessage = "apps.json: " + e.message;
            return;
        }
        const state = readState();
        page.apps = validated.map(a => ({
                    name: a.name,
                    icon: a.icon,
                    destinations: a.destinations.map(d => ({
                                label: d.label,
                                path: d.path,
                                current: d.sources.indexOf(state[d.path] || ""),
                                sources: d.sources.map(s => ({
                                            path: s,
                                            exists: readFile(s).exists
                                        }))
                            }))
                }));
        page.errorMessage = "";
    }

    function selectedIndex(ai, di) {
        const v = picked[ai + ":" + di];
        if (v !== undefined)
            return v;
        const cur = apps[ai].destinations[di].current;
        return cur < 0 ? 0 : cur;
    }

    function pick(ai, di, si) {
        const next = Object.assign({}, picked);
        next[ai + ":" + di] = si;
        page.picked = next;
    }

    // Re-applying the active profile would copy the (possibly stale) profile
    // over the app's newer file, so only a different profile can be applied.
    function canApply(ai, di) {
        const d = apps[ai].destinations[di];
        const si = selectedIndex(ai, di);
        return si !== d.current && d.sources[si].exists;
    }

    function applyOne(ai, di) {
        const d = apps[ai].destinations[di];
        const si = selectedIndex(ai, di);
        const err = switchFile(d.path, d.sources[si].path);
        if (err !== "")
            return err;
        const next = apps.slice();
        const app = Object.assign({}, next[ai]);
        app.destinations = app.destinations.slice();
        app.destinations[di] = Object.assign({}, d, {
            current: si
        });
        next[ai] = app;
        page.apps = next;
        return "";
    }

    function apply(ai, di) {
        page.errorMessage = "";
        const d = apps[ai].destinations[di];
        const src = d.sources[selectedIndex(ai, di)].path;
        const err = applyOne(ai, di);
        if (err !== "")
            page.errorMessage = err;
        else
            page.statusMessage = `Applied ${Model.tildify(src, home)} → ${Model.tildify(d.path, home)}`;
    }

    function applyAll(ai) {
        page.errorMessage = "";
        let n = 0;
        for (let di = 0; di < apps[ai].destinations.length; di++) {
            if (!canApply(ai, di))
                continue;
            const err = applyOne(ai, di);
            if (err !== "") {
                page.errorMessage = err;
                return;
            }
            n++;
        }
        page.statusMessage = n > 0 ? `Applied ${n} file${n === 1 ? "" : "s"} for ${apps[ai].name}` : `${apps[ai].name} is already set to the selected profiles`;
    }

    // Returns "" on success or an error message.
    function switchFile(destPath, srcPath) {
        const src = readFile(srcPath);
        if (!src.exists)
            return "Profile not found: " + Model.tildify(srcPath, home);
        const state = readState();
        const recorded = state[destPath] || "";
        const dest = readFile(destPath);
        if (dest.exists) {
            if (recorded !== "" && recorded !== srcPath) {
                if (!writeFile(recorded, dest.text))
                    return "Could not save the current file back to " + Model.tildify(recorded, home);
            } else if (recorded === "") {
                const snap = destPath + ".appcredrotator-original";
                if (!readFile(snap).exists)
                    writeFile(snap, dest.text);
            }
        }
        if (!writeFile(destPath, src.text))
            return "Could not write " + Model.tildify(destPath, home);
        state[destPath] = srcPath;
        if (!writeFile(statePath, JSON.stringify(state, null, 2) + "\n"))
            return "Switched, but could not record it in state.json";
        return "";
    }

    // ---- file I/O (synchronous, one throwaway FileView per call) ----------

    Component {
        id: fileComp
        FileView {
            printErrors: false
            blockLoading: true
            blockWrites: true
            // atomicWrites (default on): a failed write leaves the old file.
        }
    }

    function readFile(path) {
        const fv = fileComp.createObject(page, {
            path: path
        });
        let failed = false;
        const onFail = () => failed = true;
        fv.loadFailed.connect(onFail);
        const text = fv.text();
        const exists = !failed && fv.loaded;
        fv.destroy();
        return {
            exists: exists,
            text: exists ? text : ""
        };
    }

    function writeFile(path, text) {
        const fv = fileComp.createObject(page, {
            path: path
        });
        let ok = true;
        const onFail = () => ok = false;
        fv.saveFailed.connect(onFail);
        fv.setText(text);
        fv.destroy();
        return ok;
    }

    function readState() {
        const f = readFile(statePath);
        if (!f.exists)
            return {};
        try {
            const s = JSON.parse(f.text);
            return Model.isObject(s) ? s : {};
        } catch (e) {
            return {};
        }
    }

    Component.onCompleted: reload()
    onVisibleChanged: if (visible)
        reload()

    // ---- UI ---------------------------------------------------------------

    headerTrailing: [
        Btn {
            text: "Reload"
            icon: Icons.refresh
            onClicked: page.reload()
        }
    ]

    Banner {
        text: page.statusMessage
        kind: "info"
    }
    Banner {
        text: page.errorMessage
        kind: "error"
    }

    Card {
        visible: page.apps.length === 0 && page.errorMessage === ""
        SettingRow {
            first: true
            icon: Icons.lock
            title: "No apps configured"
            subtitle: "Add apps to appcredrotator/apps.json in the NixOS config."
        }
    }

    Repeater {
        model: page.apps
        delegate: ColumnLayout {
            id: appCol
            required property var modelData
            required property int index
            readonly property int ai: index
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                SectionLabel {
                    text: (appCol.modelData.icon !== "" ? appCol.modelData.icon + "  " : "") + appCol.modelData.name
                    Layout.fillWidth: true
                }
                Btn {
                    visible: appCol.modelData.destinations.length > 1
                    text: "Apply all"
                    kind: "primary"
                    enabled: appCol.modelData.destinations.some((d, di) => page.canApply(appCol.ai, di))
                    onClicked: page.applyAll(appCol.ai)
                }
            }

            Card {
                Repeater {
                    model: appCol.modelData.destinations
                    delegate: ColumnLayout {
                        id: destCol
                        required property var modelData
                        required property int index
                        readonly property int di: index
                        readonly property int sel: page.selectedIndex(appCol.ai, di)
                        Layout.fillWidth: true
                        spacing: 0

                        SettingRow {
                            first: destCol.di === 0
                            icon: Icons.lock
                            title: destCol.modelData.label
                            subtitle: Model.tildify(destCol.modelData.path, page.home) + "  ·  " + (destCol.modelData.current < 0 ? "not yet managed (plain file)" : "current: " + Model.basename(destCol.modelData.sources[destCol.modelData.current].path))
                            Btn {
                                text: "Apply"
                                kind: "primary"
                                enabled: page.canApply(appCol.ai, destCol.di)
                                onClicked: page.apply(appCol.ai, destCol.di)
                            }
                        }

                        Repeater {
                            model: destCol.modelData.sources
                            delegate: SettingRow {
                                id: srcRow
                                required property var modelData
                                required property int index
                                readonly property bool selected: destCol.sel === index
                                minHeight: 42
                                clickable: true
                                title: Model.tildify(modelData.path, page.home)
                                titleColor: selected ? Theme.brightForeground : Theme.textDim
                                icon: selected ? Icons.check : " "
                                iconColor: Theme.accent
                                onClicked: page.pick(appCol.ai, destCol.di, index)
                                Badge {
                                    visible: srcRow.index === destCol.modelData.current
                                    text: "Current"
                                    tone: "accent"
                                }
                                Badge {
                                    visible: !srcRow.modelData.exists
                                    text: "Missing"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
