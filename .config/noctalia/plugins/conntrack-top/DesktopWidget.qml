import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var remotes: []
  property int tracked: 0

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: countProc
    command: ["cat", "/proc/sys/net/netfilter/nf_conntrack_count"]
    stdout: StdioCollector {}
    onExited: root.tracked = parseInt(String(countProc.stdout.text || "0").trim()) || 0
  }

  Process {
    id: proc
    command: ["ss", "-H", "-tn", "state", "established"]
    stdout: StdioCollector {}
    onExited: {
      var counts = {};
      var raw = String(proc.stdout.text || "").split("\n");
      for (var i = 0; i < raw.length; i++) {
        var cols = raw[i].trim().split(/\s+/);
        if (cols.length < 4)
          continue;
        var peer = cols[3];
        var cut = peer.lastIndexOf(":");
        var ip = cut > 0 ? peer.substring(0, cut) : peer;
        if (!ip || ip === "127.0.0.1" || ip === "[::1]")
          continue;
        counts[ip] = (counts[ip] || 0) + 1;
      }
      var rows = [];
      for (var ip in counts)
        rows.push({ ip: ip, n: counts[ip] });
      rows.sort(function (a, b) { return b.n - a.n; });
      root.remotes = rows.slice(0, 6);
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      proc.running = true;
      countProc.running = true;
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
        icon: "arrows-exchange"
        color: Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Sockets"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
      NText {
        text: String(root.tracked)
        color: Color.mPrimary
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    Repeater {
      model: root.remotes.length
      delegate: RowLayout {
        required property int index
        Layout.fillWidth: true
        NText {
          text: root.remotes[index].ip
          color: Color.mOnSurface
          font.family: Settings.data.ui.fontFixed
          pointSize: Style.fontSizeXS * widgetScale
          Layout.fillWidth: true
          elide: Text.ElideRight
        }
        NText {
          text: "×" + root.remotes[index].n
          color: Color.mPrimary
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeXS * widgetScale
        }
      }
    }

    NText {
      visible: root.remotes.length === 0
      text: "No established TCP"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
