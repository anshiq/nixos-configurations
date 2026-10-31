import Quickshell.Io

// A re-runnable one-shot command. run([...]) starts it unless a previous run
// is still going (returns whether it started); finished(code, out, err)
// fires once the process has exited AND both output streams have been fully
// read. (Reporting on exit alone races the stream readers: short outputs
// arrive in time, longer ones are silently truncated to "".)
Process {
    id: root
    signal finished(int code, string out, string err)

    property int _code: 0
    property bool _exited: false
    property bool _outDone: false
    property bool _errDone: false

    function _maybeFinish() {
        if (_exited && _outDone && _errDone)
            root.finished(_code, so.text, se.text);
    }

    function run(args) {
        if (running)
            return false;
        _exited = false;
        _outDone = false;
        _errDone = false;
        command = args;
        running = true;
        return true;
    }

    stdout: StdioCollector {
        id: so
        onStreamFinished: {
            root._outDone = true;
            root._maybeFinish();
        }
    }
    stderr: StdioCollector {
        id: se
        onStreamFinished: {
            root._errDone = true;
            root._maybeFinish();
        }
    }
    onExited: code => {
        root._code = code;
        root._exited = true;
        root._maybeFinish();
    }
}
