import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var events: []

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["journalctl", "-u", "sshd", "-u", "ssh", "-u", "fail2ban", "--no-pager", "-n", "80", "-o", "short-iso", "-g", "Failed|Invalid user|authentication failure|Disconnected from authenticating|Ban "]
    stdout: StdioCollector {}
    onExited: {
      var rows = [];
      var raw = String(proc.stdout.text || "").trim();
      if (!raw) {
        root.events = [];
        return;
      }
      var lines = raw.split("\n");
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line || line.indexOf("-- No entries") === 0)
          continue;
        rows.push(line.replace(/^\S+\s+\S+\s+/, "").replace(/^sshd\[\d+\]:\s*/, ""));
      }
      root.events = rows.slice(-5);
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
        icon: root.events.length ? "lock-exclamation" : "lock"
        color: root.events.length ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Auth"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
      NText {
        text: String(root.events.length)
        color: root.events.length ? Color.mError : Color.mPrimary
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    Repeater {
      model: root.events.length
      delegate: NText {
        required property int index
        text: root.events[index]
        color: Color.mError
        pointSize: Style.fontSizeXS * widgetScale
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }
    }

    NText {
      visible: root.events.length === 0
      text: "No sshd / fail2ban hits"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
