import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var planes: []
  property string source: ""
  property int hovered: -1

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property real mapW: Math.round((cfg.mapWidth ?? 640) * widgetScale)
  readonly property real mapH: Math.round(mapW * 0.5)
  readonly property real _pad: Math.round(Style.marginM * widgetScale)
  readonly property int refreshSeconds: cfg.refreshSeconds ?? 15
  readonly property real homeLat: cfg.homeLat ?? 7.73
  readonly property real homeLon: cfg.homeLon ?? 81.70
  readonly property string mapSrc: pluginApi ? ("file://" + pluginApi.pluginDir + "/assets/earth.jpg") : ""

  implicitWidth: Math.round(mapW + _pad * 2)
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  function dotX(lon, size) {
    return (lon + 180) / 360 * mapImg.width - size / 2;
  }

  function dotY(lat, size) {
    return (90 - lat) / 180 * mapImg.height - size / 2;
  }

  Process {
    id: proc
    command: ["python3", "/home/ahmed/.config/noctalia/plugins/adsb-board/fetch.py"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var data = JSON.parse(String(proc.stdout.text || "{}"));
        root.planes = data.planes || [];
        root.source = data.source || "";
      } catch (e) {
        root.planes = [];
      }
    }
  }

  Timer {
    interval: Math.max(8, root.refreshSeconds) * 1000
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
        icon: "plane"
        color: Color.mPrimary
        pointSize: Style.fontSizeL * widgetScale
      }
      NText {
        text: "ADS-B"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
      NText {
        text: root.planes.length + (root.source ? (" · " + root.source) : "")
        color: Color.mOnSurfaceVariant
        font.family: Settings.data.ui.fontFixed
        pointSize: Style.fontSizeXS * widgetScale
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
    }

    Item {
      id: mapBox
      Layout.preferredWidth: root.mapW
      Layout.preferredHeight: root.mapH
      width: root.mapW
      height: root.mapH
      clip: true

      Image {
        id: mapImg
        anchors.fill: parent
        source: root.mapSrc
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: 0.92
      }

      // Home
      Rectangle {
        readonly property real s: Math.round(7 * widgetScale)
        width: s
        height: s
        radius: s / 2
        x: root.dotX(root.homeLon, s)
        y: root.dotY(root.homeLat, s)
        color: Color.mTertiary
        border.color: Color.mOnSurface
        border.width: 1
        z: 2
      }

      Repeater {
        model: root.planes.length
        delegate: Item {
          id: acItem
          required property int index
          readonly property var p: root.planes[index] || ({})
          readonly property real s: Math.round(9 * widgetScale)
          readonly property real track: Number(p.track) || 0

          width: s
          height: s
          x: root.dotX(p.lon, s)
          y: root.dotY(p.lat, s)
          z: 5
          rotation: track
          transformOrigin: Item.Center

          // Simple chevron / plane wedge
          Canvas {
            anchors.fill: parent
            onPaint: {
              var ctx = getContext("2d");
              ctx.clearRect(0, 0, width, height);
              ctx.fillStyle = acHover.containsMouse ? "#ffcc66" : "#e0a040";
              ctx.beginPath();
              ctx.moveTo(width * 0.5, 0);
              ctx.lineTo(width * 0.15, height);
              ctx.lineTo(width * 0.5, height * 0.7);
              ctx.lineTo(width * 0.85, height);
              ctx.closePath();
              ctx.fill();
            }
            Component.onCompleted: requestPaint()
          }

          MouseArea {
            id: acHover
            anchors.fill: parent
            anchors.margins: -Math.round(4 * widgetScale)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.hovered = acItem.index
            onExited: {
              if (root.hovered === acItem.index)
                root.hovered = -1;
            }
            onClicked: {
              var cs = (acItem.p.callsign || "").trim();
              if (cs)
                Qt.openUrlExternally("https://flightaware.com/live/flight/" + encodeURIComponent(cs));
            }
          }
        }
      }

      Rectangle {
        visible: root.hovered >= 0 && root.hovered < root.planes.length
        z: 20
        readonly property var p: visible ? root.planes[root.hovered] : ({})
        width: Math.round(160 * widgetScale)
        height: tipCol.implicitHeight + Math.round(10 * widgetScale)
        x: Math.max(0, Math.min(mapBox.width - width, root.dotX(p.lon, 0) - width / 2))
        y: Math.max(0, root.dotY(p.lat, 0) - height - Math.round(8 * widgetScale))
        radius: Style.radiusS
        color: Color.mSurface
        border.color: Color.mPrimary
        border.width: 1

        ColumnLayout {
          id: tipCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Math.round(6 * widgetScale)
          spacing: 1
          NText {
            text: (tipCol.parent.p.callsign || "?").trim()
            color: Color.mPrimary
            pointSize: Style.fontSizeXS * widgetScale
            Layout.fillWidth: true
          }
          NText {
            text: (tipCol.parent.p.dist_km || "?") + " km · alt " + (tipCol.parent.p.alt != null ? tipCol.parent.p.alt : "?")
            color: Color.mOnSurfaceVariant
            font.family: Settings.data.ui.fontFixed
            pointSize: Style.fontSizeXS * widgetScale
            Layout.fillWidth: true
          }
        }
      }
    }
  }
}
