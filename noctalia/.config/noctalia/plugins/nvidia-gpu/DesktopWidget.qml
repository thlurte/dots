import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property int util: 0
  property int vramUsed: 0
  property int vramTotal: 0
  property int temp: 0
  property real power: 0
  property string app: ""

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  function tone() {
    if (root.temp >= 80 || root.util >= 90)
      return Color.mError;
    if (root.temp >= 70 || root.util >= 50)
      return Color.mTertiary;
    return Color.mPrimary;
  }

  Process {
    id: proc
    command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits; echo ---; nvidia-smi --query-compute-apps=process_name,used_gpu_memory --format=csv,noheader,nounits"]
    stdout: StdioCollector {}
    onExited: {
      var raw = String(proc.stdout.text || "");
      var parts = raw.split("---");
      var g = (parts[0] || "").trim().split(",");
      root.util = parseInt(g[0]) || 0;
      root.vramUsed = parseInt(g[1]) || 0;
      root.vramTotal = parseInt(g[2]) || 0;
      root.temp = parseInt(g[3]) || 0;
      root.power = parseFloat(g[4]) || 0;
      var apps = (parts[1] || "").trim();
      if (!apps || apps.indexOf("No running") !== -1) {
        root.app = "";
        return;
      }
      var line = apps.split("\n")[0].split(",");
      var name = (line[0] || "").trim().split("/").pop();
      var mem = (line[1] || "").trim();
      root.app = name + (mem ? "  " + mem + " MiB" : "");
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
        icon: "device-desktop-analytics"
        color: root.tone()
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "RTX 4050"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
      NText {
        text: root.temp + "°"
        color: root.tone()
        font.family: Settings.data.ui.fontFixed
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    NText {
      text: root.util + "%  ·  " + root.vramUsed + "/" + root.vramTotal + " MiB  ·  " + root.power.toFixed(1) + " W"
      color: Color.mOnSurface
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeS * widgetScale
      Layout.fillWidth: true
    }

    NText {
      visible: root.app.length > 0
      text: root.app
      color: Color.mTertiary
      pointSize: Style.fontSizeXS * widgetScale
      Layout.fillWidth: true
      elide: Text.ElideMiddle
    }
  }
}
