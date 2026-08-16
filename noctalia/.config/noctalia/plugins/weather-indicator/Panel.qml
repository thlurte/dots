import QtQuick
import qs.Commons
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  readonly property var geometryPlaceholder: root
  property real contentPreferredWidth: 670 * Style.uiScaleRatio
  property real contentPreferredHeight: 270 * Style.uiScaleRatio
  readonly property bool allowAttach: true
  anchors.fill: parent

  WeatherCardExtra {
    anchors { fill: parent; margins: Style.marginL }
    visible: Settings.data.location.weatherEnabled
    showLocation: false
  }
}
