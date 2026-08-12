import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var units: []

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["sh", "-c", "systemctl --failed --no-legend --plain --no-pager; echo '---'; systemctl --user --failed --no-legend --plain --no-pager"]
    stdout: StdioCollector {}
    onExited: {
      var rows = [];
      var raw = String(proc.stdout.text || "").split("\n");
      for (var i = 0; i < raw.length; i++) {
        var line = raw[i].trim();
        if (!line || line === "---")
          continue;
        var name = line.split(/\s+/)[0];
        if (name.indexOf(".service") !== -1 || name.indexOf(".socket") !== -1 || name.indexOf(".timer") !== -1)
          rows.push(name);
      }
      root.units = rows;
    }
  }

  Timer {
    interval: 10000
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
        icon: root.units.length ? "alert-triangle" : "circle-check"
        color: root.units.length ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Failed units"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
      NText {
        text: String(root.units.length)
        color: root.units.length ? Color.mError : Color.mPrimary
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    Repeater {
      model: Math.min(root.units.length, 6)
      delegate: NText {
        required property int index
        text: root.units[index]
        color: Color.mError
        pointSize: Style.fontSizeXS * widgetScale
        Layout.fillWidth: true
        elide: Text.ElideMiddle
      }
    }

    NText {
      visible: root.units.length === 0
      text: "All units OK"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
