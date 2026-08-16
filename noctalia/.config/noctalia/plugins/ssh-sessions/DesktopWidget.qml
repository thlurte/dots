import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null

  readonly property var main: pluginApi?.mainInstance
  readonly property var sessions: main?.activeSessions ?? []
  readonly property var hosts: main?.sortedHosts ?? []
  readonly property int activeCount: main?.activeCount ?? 0
  readonly property int shownHosts: Math.min(hosts.length, 8)

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  ColumnLayout {
    id: contentCol
    anchors.fill: parent
    anchors.margins: root._pad
    spacing: Math.round(Style.marginXS * widgetScale)

    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginS * widgetScale)

      NIcon {
        icon: "terminal-2"
        color: root.activeCount > 0 ? Color.mPrimary : Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXL * widgetScale
      }

      NText {
        text: "SSH"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }

      NText {
        text: String(root.activeCount)
        color: Color.mPrimary
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    Repeater {
      model: root.shownHosts

      delegate: RowLayout {
        required property int index
        Layout.fillWidth: true
        spacing: Math.round(Style.marginS * widgetScale)

        Rectangle {
          width: Math.round(8 * widgetScale)
          height: Math.round(8 * widgetScale)
          radius: width / 2
          color: root.hosts[index]?.isActive ? Color.mPrimary : Color.mOnSurfaceVariant
        }

        NText {
          text: root.hosts[index]?.host?.name ?? ""
          color: root.hosts[index]?.isActive ? Color.mOnSurface : Color.mOnSurfaceVariant
          font.weight: root.hosts[index]?.isActive ? Style.fontWeightBold : Style.fontWeightMedium
          pointSize: Style.fontSizeS * widgetScale
          Layout.fillWidth: true
          elide: Text.ElideRight

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var name = root.hosts[index]?.host?.name;
              if (name)
                root.main?.connectToHost(name);
            }
          }
        }
      }
    }

    NText {
      visible: root.hosts.length === 0
      text: "No SSH hosts"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
