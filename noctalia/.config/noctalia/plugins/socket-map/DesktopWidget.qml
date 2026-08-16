import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var points: []
  property int pending: 0

  readonly property real _mapW: Math.round(576 * widgetScale)
  readonly property real _mapH: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginM * widgetScale)
  readonly property string _mapSrc: pluginApi ? ("file://" + pluginApi.pluginDir + "/assets/world.png") : ""

  implicitWidth: Math.round(_mapW + _pad * 2)
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  function dotX(lon, size) {
    return (lon + 180) / 360 * mapImg.width - size / 2;
  }

  function dotY(lat, size) {
    return (90 - lat) / 180 * mapImg.height - size / 2;
  }

  function dotSize(n) {
    return Math.round((6 + Math.min(n, 10) * 1.4) * widgetScale);
  }

  Process {
    id: proc
    command: ["python3", "/home/ahmed/.config/noctalia/plugins/socket-map/geo.py"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var data = JSON.parse(String(proc.stdout.text || "{}"));
        root.points = data.points || [];
        root.pending = data.pending || 0;
      } catch (e) {
        root.points = [];
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
        icon: "world"
        color: Color.mPrimary
        pointSize: Style.fontSizeL * widgetScale
      }
      NText {
        text: "Remotes"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
        Layout.fillWidth: true
      }
      NText {
        text: String(root.points.length)
        color: Color.mPrimary
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    Item {
      id: mapBox
      Layout.preferredWidth: root._mapW
      Layout.preferredHeight: root._mapH

      Image {
        id: mapImg
        anchors.fill: parent
        source: root._mapSrc
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        opacity: 0.85
      }

      Repeater {
        model: root.points.length
        delegate: Item {
          required property int index
          readonly property var p: root.points[index]
          readonly property real s: root.dotSize(p.n)
          width: s
          height: s
          x: mapImg.x + root.dotX(p.lon, s)
          y: mapImg.y + root.dotY(p.lat, s)

          Rectangle {
            anchors.centerIn: parent
            width: parent.s * 2.2
            height: width
            radius: width / 2
            color: Color.mPrimary
            opacity: 0.18
          }

          Rectangle {
            anchors.centerIn: parent
            width: parent.s
            height: width
            radius: width / 2
            color: parent.p.n >= 4 ? Color.mError : Color.mPrimary
            border.color: Color.mOnSurface
            border.width: 1
            opacity: 0.95
          }
        }
      }
    }

    Flow {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginS * widgetScale)
      Repeater {
        model: Math.min(root.points.length, 6)
        delegate: NText {
          required property int index
          text: root.points[index].label + " ×" + root.points[index].n
          color: Color.mOnSurface
          pointSize: Style.fontSizeXS * widgetScale
        }
      }
    }

    NText {
      visible: root.points.length === 0
      text: root.pending ? "Resolving GeoIP…" : "No public remotes"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
