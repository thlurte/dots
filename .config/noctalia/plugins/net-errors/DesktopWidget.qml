import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property string iface: "wlan0"
  property int rxErr: 0
  property int txErr: 0
  property int rxDrop: 0
  property int txDrop: 0

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)
  readonly property bool dirty: rxErr + txErr + rxDrop + txDrop > 0

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["sh", "-c", "dev=$(ip -4 route show default | awk '{print $5; exit}'); echo \"$dev\"; for s in rx_errors tx_errors rx_dropped tx_dropped; do cat /sys/class/net/$dev/statistics/$s; done"]
    stdout: StdioCollector {}
    onExited: {
      var lines = String(proc.stdout.text || "").trim().split("\n");
      root.iface = lines[0] || "wlan0";
      root.rxErr = parseInt(lines[1]) || 0;
      root.txErr = parseInt(lines[2]) || 0;
      root.rxDrop = parseInt(lines[3]) || 0;
      root.txDrop = parseInt(lines[4]) || 0;
    }
  }

  Timer {
    interval: 5000
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
        icon: "alert-triangle"
        color: root.dirty ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "NIC  " + root.iface
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    NText {
      text: "err  rx " + root.rxErr + "  tx " + root.txErr
      color: (root.rxErr + root.txErr) ? Color.mError : Color.mOnSurface
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeS * widgetScale
    }

    NText {
      text: "drop rx " + root.rxDrop + "  tx " + root.txDrop
      color: (root.rxDrop + root.txDrop) ? Color.mTertiary : Color.mOnSurface
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
