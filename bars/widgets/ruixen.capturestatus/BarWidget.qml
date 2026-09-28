import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Fixed-width screen recording control. It can live in Plugin Pins without
// forcing the bar to relayout when recording starts/stops.
BarWidget {
  id: root
  moduleName: "ruixen.capturestatus"

  property bool recording: false
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function refresh() {
    if (!recordingProbe.running) recordingProbe.running = true
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: recordingProbe
    command: ["pgrep", "--quiet", "-f", "^gpu-screen-recorder"]
    onExited: function(exitCode) { root.recording = exitCode === 0 }
  }

  implicitWidth: chip.implicitWidth
  implicitHeight: chip.implicitHeight

  BarIconButton {
    id: chip
    anchors.fill: parent
    bar: root.bar
    text: "󰻂"
    foreground: root.recording ? (root.bar ? root.bar.semanticBad : Color.urgent) : (root.bar ? root.bar.iconForeground : "#ffffff")
    tooltipText: root.recording ? "Stop screen recording" : "Start screen recording"
    onPressed: function() {
      if (root.bar) root.bar.run(root.recording ? "omarchy-capture-screenrecording --stop-recording" : "omarchy-menu toggle trigger.capture.screenrecord")
    }
  }
}
