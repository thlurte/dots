import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property int cpu: 0
  property int nvme: 0
  property int dimm: 0

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  function tone(v, warn, bad) {
    if (v >= bad)
      return Color.mError;
    if (v >= warn)
      return Color.mTertiary;
    return Color.mOnSurface;
  }

  Process {
    id: proc
    command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do n=$(cat \"$d/name\" 2>/dev/null); t=$(cat \"$d/temp1_input\" 2>/dev/null); case \"$n\" in k10temp) echo cpu=$t;; nvme) echo nvme=$t;; spd5118) echo dimm=$t;; esac; done"]
    stdout: StdioCollector {}
    onExited: {
      var t = String(proc.stdout.text || "");
      function deg(k) {
        var m = t.match(new RegExp(k + "=(\\d+)"));
        return m ? Math.round(parseInt(m[1]) / 1000) : 0;
      }
      root.cpu = deg("cpu");
      root.nvme = deg("nvme");
      root.dimm = deg("dimm");
    }
  }

  Timer {
    interval: 3000
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
        icon: "temperature"
        color: root.cpu >= 85 || root.nvme >= 70 ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Thermals"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    Repeater {
      model: [
        { k: "cpu", v: root.cpu, w: 75, b: 90 },
        { k: "nvme", v: root.nvme, w: 60, b: 70 },
        { k: "dimm", v: root.dimm, w: 55, b: 70 }
      ]
      delegate: RowLayout {
        required property var modelData
        Layout.fillWidth: true
        NText {
          text: modelData.k
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS * widgetScale
          Layout.preferredWidth: Math.round(44 * widgetScale)
        }
        NText {
          text: modelData.v + "°C"
          color: root.tone(modelData.v, modelData.w, modelData.b)
          font.family: Settings.data.ui.fontFixed
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeS * widgetScale
        }
      }
    }
  }
}
