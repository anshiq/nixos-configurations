import QtQuick
import Quickshell.Io

// BlueZ pairing agent, run as a child `bluetoothctl --agent`.
//
// Why this exists: BlueZ only completes Pair() when a default agent answers
// its prompts (numeric-comparison passkey, PIN entry, authorisation).
// Quickshell.Bluetooth can start a pairing but registers no agent, so without
// this most devices (phones, keyboards) fail to pair and only "just works"
// gadgets succeed. The agent only runs while `active` - i.e. while the
// Bluetooth page is open - so nothing auto-answers pairing requests in the
// background.
//
// bluetoothctl's prompts have no trailing newline and arrive in arbitrary
// chunks, so output is buffered and matched against known prompts.
//
// kind: "" (idle) | "confirm" | "authorize" | "pin" | "passkey" | "display"
//   confirm/authorize  -> accept() / reject()
//   pin/passkey        -> submit(text) / reject()
//   display            -> code is shown for the user to type on the device
Item {
    id: root

    property bool active: false
    // Overridable so the prompt parsing can be exercised against a fake.
    property var command: ["bluetoothctl", "--agent", "KeyboardDisplay"]

    property string kind: ""
    property string code: ""
    property string message: ""
    property string _buf: ""

    readonly property bool needsAnswer: kind === "confirm" || kind === "authorize" || kind === "pin" || kind === "passkey"

    readonly property var rules: [
        {
            re: /Confirm passkey (\d+) \(yes\/no\):/,
            apply: m => root._set("confirm", m[1], "Check that this code is also shown on the device.")
        },
        {
            re: /Authorize service ([0-9a-fA-F-]+) \(yes\/no\):/,
            apply: m => root._set("authorize", "", "A device wants to use a service on this computer.")
        },
        {
            re: /(?:Accept pairing|Request authorization|Authorize pairing)[^\n]*\(yes\/no\):/,
            apply: m => root._set("confirm", "", "A device wants to pair with this computer.")
        },
        {
            re: /Enter PIN code:/,
            apply: m => root._set("pin", "", "Enter the PIN for this device.")
        },
        {
            re: /Enter passkey \(number in 0-999999\):/,
            apply: m => root._set("passkey", "", "Enter the passkey for this device.")
        },
        {
            re: /(?:Passkey|PIN code): (\d+)/,
            apply: m => root._set("display", m[1], "Type this code on the device you are pairing.")
        },
        {
            re: /Request canceled|Cancelled/,
            apply: m => root.clear()
        }
    ]

    function _set(k, c, msg) {
        root.kind = k;
        root.code = c;
        root.message = msg;
    }

    function clear() {
        root.kind = "";
        root.code = "";
        root.message = "";
    }

    function strip(s) {
        return s.replace(/[\u0001\u0002\r]|\u001b\[[0-9;?]*[A-Za-z]/g, "");
    }

    // Consume every complete prompt in the buffer, earliest first.
    function feed(chunk) {
        root._buf += strip(chunk);
        if (root._buf.length > 4000)
            root._buf = root._buf.slice(-2000);
        for (;;) {
            let best = null;
            for (const r of root.rules) {
                const m = r.re.exec(root._buf);
                if (m && (best === null || m.index < best.m.index))
                    best = {
                        r: r,
                        m: m
                    };
            }
            if (best === null)
                return;
            root._buf = root._buf.slice(best.m.index + best.m[0].length);
            best.r.apply(best.m);
        }
    }

    function _send(text) {
        proc.write(text + "\n");
    }

    function accept() {
        _send("yes");
        clear();
    }

    function reject() {
        // pin/passkey prompts have no "no": an empty answer makes BlueZ cancel.
        _send(kind === "pin" || kind === "passkey" ? "" : "no");
        clear();
    }

    function submit(text) {
        _send(text);
        clear();
    }

    Process {
        id: proc
        running: root.active
        command: root.command
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root.feed(data)
        }
        onRunningChanged: if (!running)
            root.clear()
    }
}
