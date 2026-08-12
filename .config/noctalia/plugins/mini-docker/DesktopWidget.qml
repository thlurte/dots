import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null

  property bool dockerAvailable: false
  property var containers: []

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)
  readonly property int shownCount: Math.min(containers.length, 8)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  function refresh() {
    if (listProc.running)
      return;
    checkProc.running = true;
  }

  Process {
    id: checkProc
    command: ["docker", "info"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.dockerAvailable = exitCode === 0;
      if (root.dockerAvailable)
        listProc.running = true;
      else
        root.containers = [];
    }
  }

  Process {
    id: listProc
    command: ["docker", "ps", "--format", "{{.Names}}\t{{.Image}}\t{{.Status}}"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      if (exitCode !== 0) {
        root.containers = [];
        return;
      }
      var raw = String(listProc.stdout.text || "").trim();
      if (!raw) {
        root.containers = [];
        return;
      }
      var rows = [];
      var lines = raw.split("\n");
      for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].split("\t");
        if (parts[0]) {
          rows.push({
            name: parts[0],
            image: parts[1] || "",
            status: parts[2] || ""
          });
        }
      }
      root.containers = rows;
    }
  }

  Timer {
    interval: pluginApi?.pluginSettings?.refreshInterval || 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
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
        icon: "brand-docker"
        color: root.dockerAvailable ? Color.mPrimary : Color.mError
        pointSize: Style.fontSizeXL * widgetScale
      }

      NText {
        text: "Docker"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }

      NText {
        text: String(root.containers.length)
        color: Color.mPrimary
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    Repeater {
      model: root.shownCount

      delegate: ColumnLayout {
        required property int index
        Layout.fillWidth: true
        spacing: 0

        NText {
          text: root.containers[index]?.name ?? ""
          color: Color.mOnSurface
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeS * widgetScale
          Layout.fillWidth: true
          elide: Text.ElideRight
        }

        NText {
          text: root.containers[index]?.status ?? ""
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS * widgetScale
          Layout.fillWidth: true
          elide: Text.ElideRight
        }
      }
    }

    NText {
      visible: root.dockerAvailable && root.containers.length === 0
      text: "No running containers"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }

    NText {
      visible: !root.dockerAvailable
      text: "Docker not available"
      color: Color.mError
      pointSize: Style.fontSizeS * widgetScale
    }

    NText {
      visible: root.containers.length > root.shownCount
      text: "+" + (root.containers.length - root.shownCount) + " more"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS * widgetScale
    }
  }
}
