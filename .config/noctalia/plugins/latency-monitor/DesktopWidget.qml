import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null

  readonly property var main: pluginApi?.mainInstance
  readonly property var hosts: main?.hosts ?? []

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  function hostColor(status) {
    if (status === "good")
      return main?.colorGood || Color.mPrimary;
    if (status === "warning")
      return main?.colorWarning || Color.mTertiary;
    if (status === "critical")
      return main?.colorCritical || Color.mError;
    return Color.mOnSurfaceVariant;
  }

  function hostMs(host) {
    if (!host)
      return "—";
    if (host.timedOut)
      return "timeout";
    var avg = host.avg10m >= 0 ? host.avg10m : host.lastRtt;
    if (avg < 0)
      return "…";
    return Math.round(avg) + " ms";
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
        icon: "heart-rate-monitor"
        color: root.hostColor(main?.status)
        pointSize: Style.fontSizeXL * widgetScale
      }

      NText {
        text: "Latency"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    Repeater {
      model: root.hosts.length

      delegate: RowLayout {
        required property int index
        Layout.fillWidth: true
        spacing: Math.round(Style.marginS * widgetScale)

        Rectangle {
          width: Math.round(8 * widgetScale)
          height: Math.round(8 * widgetScale)
          radius: width / 2
          color: root.hostColor(root.hosts[index]?.status)
        }

        NText {
          text: root.hosts[index]?.name ?? ""
          color: Color.mOnSurface
          pointSize: Style.fontSizeS * widgetScale
          Layout.fillWidth: true
          elide: Text.ElideRight
        }

        NText {
          text: root.hostMs(root.hosts[index])
          color: root.hostColor(root.hosts[index]?.status)
          font.family: Settings.data.ui.fontFixed
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeS * widgetScale
        }
      }
    }

    NText {
      visible: root.hosts.length === 0
      text: "No hosts configured"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }
  }
}
