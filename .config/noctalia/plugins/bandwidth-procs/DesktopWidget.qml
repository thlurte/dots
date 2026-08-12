import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var procs: []

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["ss", "-H", "-tnp", "state", "established"]
    stdout: StdioCollector {}
    onExited: {
      var map = {};
      var raw = String(proc.stdout.text || "").split("\n");
      for (var i = 0; i < raw.length; i++) {
        var line = raw[i].trim();
        if (!line)
          continue;
        var cols = line.split(/\s+/);
        var sendq = parseInt(cols[1]) || 0;
        var name = "other";
        var m = line.match(/users:\(\("([^"]+)"/);
        if (m)
          name = m[1];
        if (!map[name])
          map[name] = { name: name, n: 0, q: 0 };
        map[name].n += 1;
        map[name].q += sendq;
      }
      var rows = [];
      for (var k in map)
        rows.push(map[k]);
      rows.sort(function (a, b) {
        if (b.q !== a.q)
          return b.q - a.q;
        return b.n - a.n;
      });
      root.procs = rows.slice(0, 7);
    }
  }

  Timer {
    interval: 3000
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
        icon: "chart-bar"
        color: Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Uplink"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    NText {
      text: "sockets · queued bytes"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS * widgetScale
    }

    Repeater {
      model: root.procs.length
      delegate: RowLayout {
        required property int index
        Layout.fillWidth: true
        NText {
          text: root.procs[index].name
          color: Color.mOnSurface
          pointSize: Style.fontSizeS * widgetScale
          Layout.fillWidth: true
          elide: Text.ElideRight
        }
        NText {
          text: root.procs[index].n + "  " + root.procs[index].q
          color: Color.mPrimary
          font.family: Settings.data.ui.fontFixed
          pointSize: Style.fontSizeXS * widgetScale
        }
      }
    }

    NText {
      visible: root.procs.length === 0
      text: "No process sockets"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
