import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property string wlanDns: ""
  property string tailDns: ""
  property string mode: "unknown"
  property string rtt: "…"

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: dnsProc
    command: ["resolvectl", "dns"]
    stdout: StdioCollector {}
    onExited: {
      var wlan = "";
      var tail = "";
      var raw = String(dnsProc.stdout.text || "").split("\n");
      for (var i = 0; i < raw.length; i++) {
        if (raw[i].indexOf("(wlan0):") !== -1)
          wlan = raw[i].replace(/^.*:\s*/, "").trim();
        if (raw[i].indexOf("(tailscale0):") !== -1)
          tail = raw[i].replace(/^.*:\s*/, "").trim();
      }
      root.wlanDns = wlan;
      root.tailDns = tail;
      var magic = tail.indexOf("100.100.100.100") !== -1;
      var split = wlan.length > 0;
      if (magic && split)
        root.mode = "split + MagicDNS";
      else if (magic)
        root.mode = "MagicDNS";
      else if (split)
        root.mode = "split / LAN";
      else
        root.mode = "unknown";
    }
  }

  Process {
    id: rttProc
    command: ["resolvectl", "query", "--cache=no", "one.one.one.one"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: {
      var text = String(rttProc.stdout.text || "") + String(rttProc.stderr.text || "");
      var m = text.match(/in ([0-9.]+)ms/);
      root.rtt = m ? m[1] + " ms" : "timeout";
    }
  }

  Timer {
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      dnsProc.running = true;
      rttProc.running = true;
    }
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
        icon: "server"
        color: Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "DNS"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
      NText {
        text: root.rtt
        color: Color.mPrimary
        font.family: Settings.data.ui.fontFixed
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeS * widgetScale
      }
    }

    NText {
      text: root.mode
      color: Color.mTertiary
      font.weight: Style.fontWeightBold
      pointSize: Style.fontSizeS * widgetScale
    }

    NText {
      visible: root.wlanDns !== ""
      text: "wlan  " + root.wlanDns
      color: Color.mOnSurface
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeXS * widgetScale
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      visible: root.tailDns !== ""
      text: "tail  " + root.tailDns
      color: Color.mOnSurface
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeXS * widgetScale
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }
  }
}
