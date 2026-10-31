// Sound: output/input volume + mute, and choosing the default device.
// Uses Quickshell's PipeWire module (same as the bar's volume widget), so
// changes made with the volume keys or the bar show up here live.
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import ".."

Page {
    id: page
    title: "Sound"
    subtitle: !Pipewire.ready ? "Connecting to PipeWire…" : ""

    // Without a tracker a node's `audio` (volume/mute) stays null.
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    // Devices only: streams (apps playing/recording) are per-application.
    readonly property var devices: Pipewire.nodes.values.filter(n => !n.isStream && n.audio)
    readonly property var sinks: devices.filter(n => n.isSink)
    readonly property var sources: devices.filter(n => !n.isSink)

    function label(n) {
        return n.description || n.nickname || n.name;
    }

    // --- output
    SectionLabel {
        text: "Output"
    }
    Card {
        VolumeRow {
            node: Pipewire.defaultAudioSink
            iconOn: Icons.volume
            iconOff: Icons.volumeMute
        }
        SettingRow {
            visible: page.sinks.length === 0
            icon: Icons.volumeMute
            title: "No output devices"
            subtitle: "No speakers or headphones were found."
        }
        Repeater {
            model: page.sinks
            delegate: SettingRow {
                id: sink
                required property var modelData
                readonly property bool isDefault: Pipewire.defaultAudioSink === modelData
                clickable: !isDefault
                title: page.label(modelData)
                subtitle: isDefault ? "Default output" : ""
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
                Glyph {
                    visible: sink.isDefault
                    text: Icons.check
                    color: Theme.accent
                }
            }
        }
    }

    // --- input
    SectionLabel {
        text: "Input"
    }
    Card {
        VolumeRow {
            node: Pipewire.defaultAudioSource
            iconOn: Icons.microphone
            iconOff: Icons.microphoneOff
        }
        SettingRow {
            visible: page.sources.length === 0
            icon: Icons.microphoneOff
            title: "No input devices"
            subtitle: "No microphones were found."
        }
        Repeater {
            model: page.sources
            delegate: SettingRow {
                id: source
                required property var modelData
                readonly property bool isDefault: Pipewire.defaultAudioSource === modelData
                clickable: !isDefault
                title: page.label(modelData)
                subtitle: isDefault ? "Default input" : ""
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
                Glyph {
                    visible: source.isDefault
                    text: Icons.check
                    color: Theme.accent
                }
            }
        }
    }
}
