import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var loaded: []
  property int catalog: 0
  property bool up: false

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["sh", "-c", "curl -sS --max-time 1 http://127.0.0.1:11434/api/ps; echo '---'; curl -sS --max-time 1 http://127.0.0.1:11434/api/tags"]
    stdout: StdioCollector {}
    onExited: {
      var raw = String(proc.stdout.text || "");
      var parts = raw.split("---");
      try {
        var ps = JSON.parse((parts[0] || "{}").trim() || "{}");
        var tags = JSON.parse((parts[1] || "{}").trim() || "{}");
        var rows = [];
        var models = ps.models || [];
        for (var i = 0; i < models.length && i < 4; i++) {
          var m = models[i];
          var size = m.size ? (m.size / 1073741824).toFixed(1) + "G" : "";
          rows.push((m.name || "?") + (size ? "  " + size : ""));
        }
        root.loaded = rows;
        root.catalog = (tags.models || []).length;
        root.up = true;
      } catch (e) {
        root.loaded = [];
        root.up = false;
      }
    }
  }

  Timer {
    interval: 5000
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
        icon: "brain"
        color: root.loaded.length ? Color.mTertiary : (root.up ? Color.mPrimary : Color.mError)
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "Ollama"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
      NText {
        text: root.up ? String(root.catalog) : "down"
        color: root.up ? Color.mPrimary : Color.mError
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    Repeater {
      model: root.loaded.length
      delegate: NText {
        required property int index
        text: root.loaded[index]
        color: Color.mTertiary
        pointSize: Style.fontSizeS * widgetScale
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
    }

    NText {
      visible: root.up && root.loaded.length === 0
      text: "idle — no model loaded"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
