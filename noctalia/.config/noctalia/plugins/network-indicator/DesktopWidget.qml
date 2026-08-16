import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Services.System
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null

  readonly property int byteThreshold: pluginApi?.pluginSettings?.byteThresholdActive
      ?? pluginApi?.manifest?.metadata?.defaultSettings?.byteThresholdActive
      ?? 5000

  readonly property string txSpeed: SystemStatService.formatSpeed(SystemStatService.txSpeed).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2") + "/s"
  readonly property string rxSpeed: SystemStatService.formatSpeed(SystemStatService.rxSpeed).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2") + "/s"
  readonly property bool txActive: SystemStatService.txSpeed >= byteThreshold
  readonly property bool rxActive: SystemStatService.rxSpeed >= byteThreshold

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
    spacing: Math.round(Style.marginS * widgetScale)

    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginS * widgetScale)

      NIcon {
        icon: "activity"
        color: (root.txActive || root.rxActive) ? Color.mPrimary : Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXL * widgetScale
      }

      NText {
        text: "Network"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginS * widgetScale)

      NIcon {
        icon: "caret-down"
        color: root.rxActive ? Color.mPrimary : Color.mOnSurfaceVariant
        pointSize: Style.fontSizeL * widgetScale
      }

      NText {
        text: "↓ " + root.rxSpeed
        color: root.rxActive ? Color.mPrimary : Color.mOnSurface
        font.family: Settings.data.ui.fontFixed
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
        Layout.fillWidth: true
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginS * widgetScale)

      NIcon {
        icon: "caret-up"
        color: root.txActive ? Color.mSecondary : Color.mOnSurfaceVariant
        pointSize: Style.fontSizeL * widgetScale
      }

      NText {
        text: "↑ " + root.txSpeed
        color: root.txActive ? Color.mSecondary : Color.mOnSurface
        font.family: Settings.data.ui.fontFixed
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
        Layout.fillWidth: true
      }
    }
  }
}
