import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property string gov: ""
  property int mhz: 0
  property int mhzMax: 0
  property real l1: 0
  property real l5: 0
  property real l15: 0
  property int cpus: 12

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["sh", "-c", "echo gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor); echo max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq); awk '/cpu MHz/{s+=$4;n++} END{printf \"mhz=%.0f\\n\", n?s/n:0}' /proc/cpuinfo; awk '{print \"load\",$1,$2,$3}' /proc/loadavg; nproc"]
    stdout: StdioCollector {}
    onExited: {
      var t = String(proc.stdout.text || "");
      var gm = t.match(/gov=(\S+)/);
      var mm = t.match(/mhz=(\d+)/);
      var xm = t.match(/max=(\d+)/);
      var lm = t.match(/load ([0-9.]+) ([0-9.]+) ([0-9.]+)/);
      var last = t.trim().split("\n").pop();
      root.gov = gm ? gm[1] : "";
      root.mhz = mm ? parseInt(mm[1]) : 0;
      root.mhzMax = xm ? Math.round(parseInt(xm[1]) / 1000) : 0;
      if (lm) {
        root.l1 = parseFloat(lm[1]);
        root.l5 = parseFloat(lm[2]);
        root.l15 = parseFloat(lm[3]);
      }
      root.cpus = parseInt(last) || 12;
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: proc.running = true
  }

  ColumnLayout {
    id: contentCol
    anchors.fill: parent
    anchors.margins: root._pad
    spacing: Math.round(Style.marginXS * widgetScale)

    RowLayout {
      Layout.fillWidth: true
      NIcon {
        icon: "gauge"
        color: root.l1 >= root.cpus ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "8645HS"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    NText {
      text: root.gov + "  ·  " + root.mhz + " / " + root.mhzMax + " MHz"
      color: Color.mOnSurface
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeS * widgetScale
      Layout.fillWidth: true
    }

    NText {
      text: "load  " + root.l1.toFixed(2) + "  " + root.l5.toFixed(2) + "  " + root.l15.toFixed(2)
      color: root.l1 >= root.cpus ? Color.mError : Color.mOnSurface
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
