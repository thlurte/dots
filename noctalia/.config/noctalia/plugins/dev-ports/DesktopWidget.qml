import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Services.UI
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var ports: []

  readonly property var watched: ({
    "3000": 1, "3001": 1, "4000": 1, "4173": 1, "5000": 1,
    "5173": 1, "5174": 1, "5432": 1, "5433": 1, "6006": 1,
    "6379": 1, "8000": 1, "8080": 1, "8081": 1, "8888": 1,
    "9000": 1, "9090": 1, "9229": 1, "11434": 1, "27017": 1,
    "3306": 1, "1883": 1, "5672": 1, "24678": 1
  })

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  function killPid(pid) {
    if (!pid)
      return;
    Quickshell.execDetached(["kill", String(pid)]);
    ToastService.showNotice("Dev ports", "kill " + pid);
    Qt.callLater(function () { proc.running = true; });
  }

  Process {
    id: proc
    command: ["ss", "-H", "-tlnp"]
    stdout: StdioCollector {}
    onExited: {
      var rows = [];
      var seen = {};
      var raw = String(proc.stdout.text || "").split("\n");
      for (var i = 0; i < raw.length; i++) {
        var line = raw[i].trim();
        if (!line)
          continue;
        var local = line.split(/\s+/)[3] || "";
        var colon = local.lastIndexOf(":");
        if (colon < 0)
          continue;
        var port = local.substring(colon + 1);
        if (!root.watched[port])
          continue;
        var procName = "—";
        var pid = "";
        var m = line.match(/users:\(\("([^"]+)",pid=(\d+)/);
        if (m) {
          procName = m[1];
          pid = m[2];
        }
        var key = port + ":" + pid;
        if (seen[key])
          continue;
        seen[key] = true;
        rows.push({ port: port, name: procName, pid: pid });
      }
      rows.sort(function (a, b) { return parseInt(a.port) - parseInt(b.port); });
      root.ports = rows;
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
      spacing: Math.round(Style.marginS * widgetScale)
      NIcon {
        icon: "bug"
        color: root.ports.length ? Color.mPrimary : Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Dev ports"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
      NText {
        text: String(root.ports.length)
        color: Color.mPrimary
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    Repeater {
      model: root.ports.length
      delegate: RowLayout {
        required property int index
        Layout.fillWidth: true
        spacing: Math.round(Style.marginS * widgetScale)

        NText {
          text: root.ports[index].port
          color: Color.mPrimary
          font.family: Settings.data.ui.fontFixed
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeS * widgetScale
          Layout.preferredWidth: Math.round(48 * widgetScale)
        }
        NText {
          text: root.ports[index].name
          color: Color.mOnSurface
          pointSize: Style.fontSizeS * widgetScale
          Layout.fillWidth: true
          elide: Text.ElideRight
        }
        NButton {
          text: "kill"
          outlined: true
          enabled: root.ports[index].pid !== ""
          fontSize: Style.fontSizeXS * widgetScale
          onClicked: root.killPid(root.ports[index].pid)
        }
      }
    }

    NText {
      visible: root.ports.length === 0
      text: "No 3000/5173/8080/5432…"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
