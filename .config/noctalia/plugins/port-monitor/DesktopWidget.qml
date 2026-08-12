import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null

  readonly property var main: pluginApi?.mainInstance
  readonly property var ports: main?.sortedPorts ?? []
  readonly property int portCount: main?.portCount ?? 0
  readonly property int shownCount: Math.min(ports.length, 8)

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
        icon: "network"
        color: root.portCount > 0 ? Color.mPrimary : Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXL * widgetScale
      }

      NText {
        text: "Open ports"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }

      NText {
        text: String(root.portCount)
        color: Color.mPrimary
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    Repeater {
      model: root.shownCount

      delegate: RowLayout {
        required property int index
        Layout.fillWidth: true
        spacing: Math.round(Style.marginS * widgetScale)

        NText {
          text: String(root.ports[index]?.port ?? "")
          color: Color.mPrimary
          font.family: Settings.data.ui.fontFixed
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeS * widgetScale
          Layout.preferredWidth: Math.round(52 * widgetScale)
        }

        NText {
          text: root.ports[index]?.proto ?? ""
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS * widgetScale
          Layout.preferredWidth: Math.round(36 * widgetScale)
        }

        NText {
          text: root.ports[index]?.processName || "—"
          color: Color.mOnSurface
          pointSize: Style.fontSizeS * widgetScale
          Layout.fillWidth: true
          elide: Text.ElideRight
        }
      }
    }

    NText {
      visible: root.portCount > root.shownCount
      text: "+" + (root.portCount - root.shownCount) + " more"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS * widgetScale
    }

    NText {
      visible: root.portCount === 0
      text: "No listening ports"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
