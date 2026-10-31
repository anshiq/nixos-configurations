// Nerd Font (Material Design Icons block) glyphs used by the app.
//
// Built with fromCodePoint rather than literal characters: these live above
// U+FFFF, where a "\uXXXX" escape cannot express them, and a literal pasted
// into source is invisible in review. Same reason quickshell/NetworkPanel.qml
// builds its wifi glyphs this way (the lookalike U+F11xx range is an unrelated
// icon set that renders as gibberish in JetBrainsMono Nerd Font).
pragma Singleton
import QtQuick

QtObject {
    function cp(c) {
        return String.fromCodePoint(c);
    }

    // navigation
    readonly property string wifi: cp(0xF05A9)
    readonly property string wifiOff: cp(0xF05AA)
    readonly property string bluetooth: cp(0xF00AF)
    readonly property string bluetoothConnect: cp(0xF00B1)
    readonly property string bluetoothOff: cp(0xF00B2)
    readonly property string volume: cp(0xF057E)
    readonly property string volumeMute: cp(0xF075F)
    readonly property string microphone: cp(0xF036C)
    readonly property string microphoneOff: cp(0xF036D)
    readonly property string display: cp(0xF0379)
    readonly property string brightness: cp(0xF00E0)
    readonly property string battery: cp(0xF0079)
    readonly property string batteryCharging: cp(0xF0084)
    readonly property string palette: cp(0xF03D8)
    readonly property string lock: cp(0xF033E)
    readonly property string image: cp(0xF02E9)
    readonly property string camera: cp(0xF0100)
    readonly property string server: cp(0xF048B)
    readonly property string terminal: cp(0xF018D)
    readonly property string key: cp(0xF0306)

    // actions / states
    readonly property string refresh: cp(0xF0450)
    readonly property string check: cp(0xF012C)
    readonly property string close: cp(0xF0156)
    readonly property string plus: cp(0xF0415)
    readonly property string eye: cp(0xF06D0)
    readonly property string eyeOff: cp(0xF06D1)
    readonly property string folder: cp(0xF024B)
    readonly property string cog: cp(0xF0493)
    readonly property string nightLight: cp(0xF0594)
    readonly property string sun: cp(0xF05A8)
    readonly property string ethernet: cp(0xF0200)
    readonly property string plug: cp(0xF06A5)
    readonly property string leaf: cp(0xF032A)
    readonly property string balance: cp(0xF05D1)
    readonly property string rocket: cp(0xF14DE)
    readonly property string eyedropper: cp(0xF020A)
    readonly property string record: cp(0xF044A)
    readonly property string stop: cp(0xF04DB)
    readonly property string selection: cp(0xF0489)
    readonly property string timer: cp(0xF051B)
    readonly property string calendar: cp(0xF00ED)
    readonly property string skipNext: cp(0xF04AD)
    readonly property string sync: cp(0xF04E6)
    readonly property string puzzle: cp(0xF0431)

    // bluetooth device kinds
    readonly property string headphones: cp(0xF02CB)
    readonly property string speaker: cp(0xF04C3)
    readonly property string keyboard: cp(0xF030C)
    readonly property string mouse: cp(0xF037D)
    readonly property string phone: cp(0xF011C)
    readonly property string gamepad: cp(0xF0297)
    readonly property string laptop: cp(0xF0322)
}
