import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property string kind: "down"
  property string ssid: ""
  property string signal: ""
  property string rate: ""
  property string gateway: ""
  property string device: ""

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status; echo '---'; iw dev wlan0 link 2>/dev/null; echo '---'; ip -4 route show default"]
    stdout: StdioCollector {}
    onExited: {
      var raw = String(proc.stdout.text || "");
      var chunks = raw.split("---");
      var kind = "down";
      var device = "";
      var ssid = "";
      var devLines = (chunks[0] || "").split("\n");
      for (var i = 0; i < devLines.length; i++) {
        var p = devLines[i].trim().split(":");
        if (p.length < 4)
          continue;
        if (p[1] === "wifi" && p[2].indexOf("connected") === 0) {
          kind = "wifi";
          device = p[0];
          ssid = p[3];
          break;
        }
        if (p[1] === "ethernet" && p[2].indexOf("connected") === 0 && kind === "down") {
          kind = "ethernet";
          device = p[0];
          ssid = p[3] || p[0];
        }
      }
      var sig = "";
      var rate = "";
      var link = chunks[1] || "";
      var sm = link.match(/signal:\s+(-?\d+)\s+dBm/);
      var rm = link.match(/rx bitrate:\s+([0-9.]+)\s+MBit/);
      var tm = link.match(/tx bitrate:\s+([0-9.]+)\s+MBit/);
      if (sm)
        sig = sm[1] + " dBm";
      if (rm || tm)
        rate = (tm ? tm[1] : rm[1]) + " Mb/s";
      var gw = "";
      var gm = (chunks[2] || "").match(/default via (\S+) dev (\S+)/);
      if (gm) {
        gw = gm[1];
        if (!device)
          device = gm[2];
      }
      root.kind = kind;
      root.device = device;
      root.ssid = ssid;
      root.signal = sig;
      root.rate = rate;
      root.gateway = gw;
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
      spacing: Math.round(Style.marginS * widgetScale)
      NIcon {
        icon: root.kind === "wifi" ? "wifi" : (root.kind === "ethernet" ? "network" : "wifi-off")
        color: root.kind === "down" ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: root.kind === "down" ? "Link down" : root.ssid
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
    }

    NText {
      visible: root.signal !== ""
      text: root.signal + (root.rate ? "  ·  " + root.rate : "")
      color: Color.mPrimary
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeS * widgetScale
    }

    NText {
      visible: root.gateway !== ""
      text: root.device + "  →  " + root.gateway
      color: Color.mOnSurfaceVariant
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
