import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var quakes: []
  property int hovered: -1

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property real mapW: Math.round((cfg.mapWidth ?? 640) * widgetScale)
  readonly property real mapH: Math.round(mapW * 0.5)
  readonly property real _pad: Math.round(Style.marginM * widgetScale)
  readonly property int refreshSeconds: cfg.refreshSeconds ?? 300
  readonly property string mapSrc: pluginApi ? ("file://" + pluginApi.pluginDir + "/assets/earth.jpg") : ""

  implicitWidth: Math.round(mapW + _pad * 2)
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  function openUrl(url) {
    if (url)
      Qt.openUrlExternally(url);
  }

  function dotX(lon, size) {
    return (lon + 180) / 360 * mapImg.width - size / 2;
  }

  function dotY(lat, size) {
    return (90 - lat) / 180 * mapImg.height - size / 2;
  }

  Process {
    id: proc
    command: ["python3", "/home/ahmed/.config/noctalia/plugins/quake-map/fetch.py"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var data = JSON.parse(String(proc.stdout.text || "{}"));
        root.quakes = data.quakes || [];
      } catch (e) {
        root.quakes = [];
      }
    }
  }

  Timer {
    interval: Math.max(60, root.refreshSeconds) * 1000
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
        icon: "ripple"
        color: Color.mPrimary
        pointSize: Style.fontSizeL * widgetScale
      }
      NText {
        text: "Quakes"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
        Layout.fillWidth: true
      }
      NText {
        text: String(root.quakes.length)
        color: Color.mPrimary
        font.family: Settings.data.ui.fontFixed
        pointSize: Style.fontSizeS * widgetScale
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

      Repeater {
        model: root.quakes.length

        delegate: Item {
          id: qItem
          required property int index
          readonly property var q: root.quakes[index] || ({})
          readonly property real mag: Number(q.mag) || 0
          readonly property real core: Math.round((4 + mag * 2.2) * widgetScale)
          readonly property real cx: root.dotX(q.lon, core) + core / 2
          readonly property real cy: root.dotY(q.lat, core) + core / 2

          x: cx - width / 2
          y: cy - height / 2
          width: core * 8
          height: core * 8
          z: Math.round(mag * 10)

          // Blooming rings
          Repeater {
            model: 2
            delegate: Rectangle {
              required property int index
              anchors.centerIn: parent
              width: qItem.core * (1.5 + ringAnim.phase * (3 + index * 2) + mag * 0.35)
              height: width
              radius: width / 2
              color: "transparent"
              border.color: qItem.mag >= 5 ? Color.mError : Color.mPrimary
              border.width: Math.max(1, Math.round(widgetScale))
              opacity: (1.0 - ringAnim.phase) * (index === 0 ? 0.55 : 0.35)
            }
          }

          SequentialAnimation {
            id: ringAnim
            property real phase: 0
            running: true
            loops: Animation.Infinite
            PauseAnimation {
              duration: (qItem.index % 7) * 180
            }
            NumberAnimation {
              target: ringAnim
              property: "phase"
              from: 0
              to: 1
              duration: 2200 + qItem.mag * 200
              easing.type: Easing.OutQuad
            }
            PauseAnimation {
              duration: 500
            }
          }

          Rectangle {
            anchors.centerIn: parent
            width: qItem.core
            height: width
            radius: width / 2
            color: qItem.mag >= 5 ? Color.mError : Color.mPrimary
            border.color: Color.mOnSurface
            border.width: 1
            opacity: mapHover.containsMouse ? 1 : 0.9
          }

          MouseArea {
            id: mapHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.hovered = qItem.index
            onExited: {
              if (root.hovered === qItem.index)
                root.hovered = -1;
            }
            onClicked: root.openUrl(qItem.q.url || "")
          }
        }
      }

      Rectangle {
        id: tip
        visible: root.hovered >= 0 && root.hovered < root.quakes.length
        z: 50
        readonly property var q: visible ? root.quakes[root.hovered] : ({})
        width: Math.round(220 * widgetScale)
        height: tipCol.implicitHeight + Math.round(12 * widgetScale)
        x: Math.max(0, Math.min(mapBox.width - width, root.dotX(q.lon, 0) - width / 2))
        y: Math.max(0, root.dotY(q.lat, 0) - height - Math.round(10 * widgetScale))
        radius: Style.radiusS
        color: Color.mSurface
        border.color: Color.mPrimary
        border.width: 1
        opacity: 0.96

        ColumnLayout {
          id: tipCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Math.round(6 * widgetScale)
          spacing: 1
          NText {
            text: "M" + (tip.q.mag || "") + " · " + (tip.q.age || "")
            color: Color.mPrimary
            pointSize: Style.fontSizeXS * widgetScale
            Layout.fillWidth: true
          }
          NText {
            text: tip.q.place || ""
            color: Color.mOnSurface
            pointSize: Style.fontSizeXS * widgetScale
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            maximumLineCount: 3
          }
        }
      }
    }
  }
}
