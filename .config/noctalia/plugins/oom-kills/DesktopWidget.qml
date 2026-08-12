import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var kills: []

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["journalctl", "-k", "-b", "--no-pager", "-n", "40", "-o", "short-iso", "-g", "Out of memory|Killed process"]
    stdout: StdioCollector {}
    onExited: {
      var rows = [];
      var raw = String(proc.stdout.text || "").trim();
      if (!raw || raw.indexOf("-- No entries") === 0) {
        root.kills = [];
        return;
      }
      var lines = raw.split("\n");
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line)
          continue;
        rows.push(line.replace(/^\S+\s+\S+\s+/, ""));
      }
      root.kills = rows.slice(-4);
    }
  }

  Timer {
    interval: 15000
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
        icon: "skull"
        color: root.kills.length ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "OOM"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    Repeater {
      model: root.kills.length
      delegate: NText {
        required property int index
        text: root.kills[index]
        color: Color.mError
        pointSize: Style.fontSizeXS * widgetScale
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }
    }

    NText {
      visible: root.kills.length === 0
      text: "No kills this boot"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
