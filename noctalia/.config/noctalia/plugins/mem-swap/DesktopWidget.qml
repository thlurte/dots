import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property real avail: 0
  property real total: 0
  property real swapUsed: 0
  property real swapTotal: 0
  property real dirty: 0

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)
  readonly property real usedPct: root.total > 0 ? (1 - root.avail / root.total) * 100 : 0
  readonly property real swapPct: root.swapTotal > 0 ? (root.swapUsed / root.swapTotal) * 100 : 0

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  function gib(kib) {
    return (kib / 1048576).toFixed(1);
  }

  Process {
    id: proc
    command: ["awk", "/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} /^SwapTotal:/{st=$2} /^SwapFree:/{sf=$2} /^Dirty:/{d=$2} END{print a,t,st-sf,st,d}", "/proc/meminfo"]
    stdout: StdioCollector {}
    onExited: {
      var p = String(proc.stdout.text || "").trim().split(/\s+/);
      root.avail = parseFloat(p[0]) || 0;
      root.total = parseFloat(p[1]) || 0;
      root.swapUsed = parseFloat(p[2]) || 0;
      root.swapTotal = parseFloat(p[3]) || 0;
      root.dirty = parseFloat(p[4]) || 0;
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
        icon: "database"
        color: root.usedPct >= 90 || root.swapPct >= 40 ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Memory"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    NText {
      text: "avail  " + root.gib(root.avail) + " / " + root.gib(root.total) + " GiB  (" + root.usedPct.toFixed(0) + "%)"
      color: root.usedPct >= 90 ? Color.mError : Color.mOnSurface
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeS * widgetScale
      Layout.fillWidth: true
    }

    NText {
      text: "swap   " + root.gib(root.swapUsed) + " / " + root.gib(root.swapTotal) + " GiB  (" + root.swapPct.toFixed(0) + "%)"
      color: root.swapPct >= 40 ? Color.mError : Color.mOnSurface
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeS * widgetScale
      Layout.fillWidth: true
    }

    NText {
      text: "dirty  " + (root.dirty / 1024).toFixed(1) + " MiB"
      color: Color.mOnSurfaceVariant
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeXS * widgetScale
    }
  }
}
