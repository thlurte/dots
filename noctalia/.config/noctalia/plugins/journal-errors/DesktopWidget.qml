import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var lines: []

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["journalctl", "-b", "-p", "3", "-n", "5", "--no-pager", "-o", "short-iso"]
    stdout: StdioCollector {}
    onExited: {
      var rows = [];
      var raw = String(proc.stdout.text || "").trim();
      if (!raw)
        return root.lines = [];
      var parts = raw.split("\n");
      for (var i = 0; i < parts.length; i++) {
        var line = parts[i].trim();
        if (line)
          rows.push(line.replace(/^\S+\s+\S+\s+/, ""));
      }
      root.lines = rows.slice(-5);
    }
  }

  Timer {
    interval: 12000
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
        icon: "notes"
        color: root.lines.length ? Color.mError : Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Journal ≤3"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    Repeater {
      model: root.lines.length
      delegate: NText {
        required property int index
        text: root.lines[index]
        color: Color.mError
        pointSize: Style.fontSizeXS * widgetScale
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }
    }

    NText {
      visible: root.lines.length === 0
      text: "No err/crit this boot"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
