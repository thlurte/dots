import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property int estab: 0
  property int timewait: 0
  property int orphaned: 0
  property real retran: 0

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["sh", "-c", "ss -s; echo ---; awk 'f{print; exit} /^Tcp:/{f=1}' /proc/net/snmp"]
    stdout: StdioCollector {}
    onExited: {
      var raw = String(proc.stdout.text || "");
      var parts = raw.split("---");
      var summary = parts[0] || "";
      var em = summary.match(/estab (\d+)/);
      var tm = summary.match(/timewait (\d+)/);
      var om = summary.match(/orphaned (\d+)/);
      root.estab = em ? parseInt(em[1]) : 0;
      root.timewait = tm ? parseInt(tm[1]) : 0;
      root.orphaned = om ? parseInt(om[1]) : 0;
      var fields = (parts[1] || "").trim().split(/\s+/);
      var outSegs = parseFloat(fields[10]) || 0;
      var retr = parseFloat(fields[11]) || 0;
      root.retran = outSegs > 0 ? (retr / outSegs) * 100 : 0;
    }
  }

  Timer {
    interval: 4000
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
        icon: "arrows-exchange"
        color: root.retran >= 3 || root.timewait > 50 ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "TCP"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    NText {
      text: root.estab + " estab  ·  " + root.timewait + " tw  ·  " + root.orphaned + " orphan"
      color: Color.mOnSurface
      pointSize: Style.fontSizeS * widgetScale
      Layout.fillWidth: true
    }

    NText {
      text: "retrans  " + root.retran.toFixed(2) + "%"
      color: root.retran >= 3 ? Color.mError : Color.mPrimary
      font.family: Settings.data.ui.fontFixed
      font.weight: Style.fontWeightBold
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
