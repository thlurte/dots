import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property real issLat: 0
  property real issLon: 0
  property real distKm: 0
  property real bearing: 0
  property bool visibleNow: false
  property var etaMin: null
  property var trail: []
  property string visibility: ""
  property string statusLine: ""

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property real mapW: Math.round((cfg.mapWidth ?? 640) * widgetScale)
  readonly property real mapH: Math.round(mapW * 0.5)
  readonly property real _pad: Math.round(Style.marginM * widgetScale)
  readonly property int refreshSeconds: cfg.refreshSeconds ?? 20
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
    command: ["python3", "/home/ahmed/.config/noctalia/plugins/iss-track/fetch.py"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var data = JSON.parse(String(proc.stdout.text || "{}"));
        root.issLat = data.lat || 0;
        root.issLon = data.lon || 0;
        root.distKm = data.dist_km || 0;
        root.bearing = data.bearing || 0;
        root.visibleNow = !!data.visible_now;
        root.etaMin = data.eta_min;
        root.trail = data.trail || [];
        root.visibility = data.visibility || "";
        if (root.visibleNow)
          root.statusLine = "Visible now · " + root.distKm + " km";
        else if (root.etaMin !== null && root.etaMin !== undefined)
          root.statusLine = "Pass ~" + root.etaMin + "m · " + root.distKm + " km";
        else
          root.statusLine = root.distKm + " km · " + Math.round(root.bearing) + "°";
      } catch (e) {
        root.statusLine = "fetch error";
      }
    }
  }

  Timer {
    interval: Math.max(10, root.refreshSeconds) * 1000
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
        icon: "satellite"
        color: root.visibleNow ? Color.mTertiary : Color.mPrimary
        pointSize: Style.fontSizeL * widgetScale
      }
      NText {
        text: "ISS"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
      NText {
        text: root.statusLine
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

      // Trail
      Repeater {
        model: root.trail.length
        delegate: Rectangle {
          required property int index
          readonly property var pt: root.trail[index] || ({})
          readonly property real s: Math.round(3 * widgetScale)
          width: s
          height: s
          radius: s / 2
          x: root.dotX(pt.lon, s)
          y: root.dotY(pt.lat, s)
          color: Color.mPrimary
          opacity: 0.15 + 0.7 * (index / Math.max(1, root.trail.length - 1))
        }
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
      }

      // ISS
      Item {
        id: issMark
        readonly property real s: Math.round(12 * widgetScale)
        width: s * 3
        height: s * 3
        x: root.dotX(root.issLon, s) + s / 2 - width / 2
        y: root.dotY(root.issLat, s) + s / 2 - height / 2

        Rectangle {
          anchors.centerIn: parent
          width: parent.s * (1.2 + pulse.phase * 2.2)
          height: width
          radius: width / 2
          color: "transparent"
          border.color: Color.mPrimary
          border.width: 1
          opacity: (1 - pulse.phase) * 0.6
        }

        SequentialAnimation {
          id: pulse
          property real phase: 0
          running: true
          loops: Animation.Infinite
          NumberAnimation {
            target: pulse
            property: "phase"
            from: 0
            to: 1
            duration: 1800
            easing.type: Easing.OutQuad
          }
          PauseAnimation {
            duration: 200
          }
        }

        Rectangle {
          anchors.centerIn: parent
          width: parent.s
          height: width
          radius: width / 2
          color: root.visibleNow ? Color.mTertiary : Color.mPrimary
          border.color: Color.mOnSurface
          border.width: 1
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: Qt.openUrlExternally("https://spotthestation.nasa.gov/")
        }
      }
    }

    NText {
      text: root.visibleNow ? "Click ISS · Spot The Station" : "Home · Batticaloa area · click ISS for passes"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS * widgetScale
      Layout.fillWidth: true
      elide: Text.ElideRight
    }
  }
}
