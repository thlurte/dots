import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property string policy: "unknown"
  property var drops: []

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["sh", "-c", "awk '/chain input/,/^  }/ { if ($1==\"policy\") print $2 }' /etc/nftables.conf | head -1; echo '---'; journalctl -k -b -n 250 --no-pager -o cat | grep -E '\\[UFW BLOCK\\]| DROP ' | tail -5"]
    stdout: StdioCollector {}
    onExited: {
      var raw = String(proc.stdout.text || "");
      var parts = raw.split("---");
      var pol = (parts[0] || "").trim();
      root.policy = pol || "unknown";
      var rows = [];
      var lines = (parts[1] || "").trim().split("\n");
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line)
          continue;
        var src = (line.match(/SRC=(\S+)/) || [])[1] || "";
        var dst = (line.match(/DPT=(\S+)/) || [])[1] || "";
        var iface = (line.match(/IN=(\S+)/) || [])[1] || "";
        rows.push((iface ? iface + " " : "") + src + (dst ? " :" + dst : ""));
      }
      root.drops = rows;
    }
  }

  Timer {
    interval: 8000
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
        icon: "shield"
        color: root.policy === "drop" ? Color.mPrimary : Color.mTertiary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Firewall"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    NText {
      text: "input policy " + root.policy
      color: root.policy === "drop" ? Color.mPrimary : Color.mTertiary
      font.weight: Style.fontWeightBold
      pointSize: Style.fontSizeS * widgetScale
    }

    Repeater {
      model: root.drops.length
      delegate: NText {
        required property int index
        text: root.drops[index]
        color: Color.mError
        font.family: Settings.data.ui.fontFixed
        pointSize: Style.fontSizeXS * widgetScale
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
    }

    NText {
      visible: root.drops.length === 0
      text: "No recent UFW/nft drops"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
