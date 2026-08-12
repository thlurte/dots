import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property real cpu: 0
  property real mem: 0
  property real io: 0

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  function tone(v) {
    if (v >= 10)
      return Color.mError;
    if (v >= 5)
      return Color.mTertiary;
    return Color.mPrimary;
  }

  Process {
    id: proc
    command: ["sh", "-c", "awk '/^some /{print $2}' /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io"]
    stdout: StdioCollector {}
    onExited: {
      var vals = String(proc.stdout.text || "").trim().split("\n");
      function parseAvg(s) {
        var m = String(s).match(/avg10=([0-9.]+)/);
        return m ? parseFloat(m[1]) : 0;
      }
      root.cpu = parseAvg(vals[0]);
      root.mem = parseAvg(vals[1]);
      root.io = parseAvg(vals[2]);
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
        icon: "activity"
        color: root.tone(Math.max(root.cpu, root.mem, root.io))
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Pressure"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    Repeater {
      model: [
        { k: "cpu", v: root.cpu },
        { k: "mem", v: root.mem },
        { k: "io", v: root.io }
      ]
      delegate: RowLayout {
        required property var modelData
        Layout.fillWidth: true
        NText {
          text: modelData.k
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS * widgetScale
          Layout.preferredWidth: Math.round(36 * widgetScale)
        }
        NText {
          text: modelData.v.toFixed(1) + "%"
          color: root.tone(modelData.v)
          font.family: Settings.data.ui.fontFixed
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeS * widgetScale
        }
      }
    }
  }
}
