import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property int online: 0
  property string relay: ""
  property string exitNode: "none"
  property var names: []

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["tailscale", "status", "--json"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var data = JSON.parse(String(proc.stdout.text || "{}"));
        var peers = data.Peer || {};
        var on = 0;
        var list = [];
        for (var k in peers) {
          var p = peers[k];
          var tags = p.Tags || [];
          var mullvad = false;
          for (var i = 0; i < tags.length; i++) {
            if (tags[i] === "tag:mullvad-exit-node")
              mullvad = true;
          }
          if (mullvad)
            continue;
          if (p.Online) {
            on += 1;
            if (list.length < 4)
              list.push(p.HostName || p.DNSName || "?");
          }
        }
        root.online = on;
        root.names = list;
        root.relay = (data.Self && data.Self.Relay) || "";
        var ens = data.ExitNodeStatus;
        root.exitNode = (ens && ens.ID) ? "on" : "none";
      } catch (e) {
        root.online = 0;
      }
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
      NIcon {
        icon: "affiliate"
        color: Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Mesh"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
      NText {
        text: String(root.online)
        color: Color.mPrimary
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    NText {
      text: "relay  " + (root.relay || "—") + "  ·  exit  " + root.exitNode
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS * widgetScale
      Layout.fillWidth: true
      elide: Text.ElideRight
    }

    Repeater {
      model: root.names.length
      delegate: NText {
        required property int index
        text: root.names[index]
        color: Color.mOnSurface
        pointSize: Style.fontSizeS * widgetScale
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
    }
  }
}
