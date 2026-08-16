import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var sick: []

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["sh", "-c", "{ docker ps --filter health=unhealthy --format '{{.Names}}\\t{{.Status}}'; docker ps --filter status=restarting --format '{{.Names}}\\t{{.Status}}'; }"]
    stdout: StdioCollector {}
    onExited: {
      var rows = [];
      var raw = String(proc.stdout.text || "").trim();
      if (!raw) {
        root.sick = [];
        return;
      }
      var lines = raw.split("\n");
      var seen = {};
      for (var i = 0; i < lines.length; i++) {
        var p = lines[i].split("\t");
        if (!p[0] || seen[p[0]])
          continue;
        seen[p[0]] = true;
        rows.push({ name: p[0], status: p[1] || "unhealthy" });
      }
      root.sick = rows.slice(0, 6);
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
        icon: "heart-rate-monitor"
        color: root.sick.length ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Unhealthy"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
      NText {
        text: String(root.sick.length)
        color: root.sick.length ? Color.mError : Color.mPrimary
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    Repeater {
      model: root.sick.length
      delegate: NText {
        required property int index
        text: root.sick[index].name
        color: Color.mError
        pointSize: Style.fontSizeXS * widgetScale
        Layout.fillWidth: true
        elide: Text.ElideMiddle
      }
    }

    NText {
      visible: root.sick.length === 0
      text: "All healthchecks OK"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
