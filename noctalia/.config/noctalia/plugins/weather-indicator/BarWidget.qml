import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Location
import qs.Widgets
import qs.Services.UI
import "WeatherUtils.js" as Utils

Item {
  id: root
  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property bool weatherReady: Settings.data.location.weatherEnabled && !!LocationService.data.weather
  readonly property var s: pluginApi?.pluginSettings || pluginApi?.manifest?.metadata?.defaultSettings || {}
  readonly property string screenName: screen?.name || ""
  readonly property bool isVertical: ["left", "right"].includes(Settings.getBarPositionForScreen(screenName))

  implicitWidth: isVertical ? Style.getBarHeightForScreen(screenName) - Style.marginL : layout.implicitWidth + Style.marginM * 2
  implicitHeight: isVertical ? layout.implicitHeight + Style.marginS * 2 : Style.getCapsuleHeightForScreen(screenName)
  visible: weatherReady
  opacity: weatherReady ? 1.0 : 0.0

  Rectangle {
    anchors.centerIn: parent
    width: parent.implicitWidth; height: parent.implicitHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL
    border { color: Style.capsuleBorderColor; width: Style.capsuleBorderWidth }

    GridLayout {
      id: layout
      anchors.centerIn: parent
      columns: root.isVertical ? 1 : 2
      rowSpacing: Style.marginS; columnSpacing: Style.marginS

      NIcon {
        visible: !!root.s.showConditionIcon
        Layout.alignment: Qt.AlignCenter
        icon: weatherReady ? LocationService.weatherSymbolFromCode(LocationService.data.weather.current_weather.weathercode, LocationService.data.weather.current_weather.is_day) : "weather-cloud-off"
        color: mouseArea.containsMouse ? Color.mOnHover : Color.resolveColorKey(root.s.customColor || "none")
      }

      NText {
        visible: !!root.s.showTempValue
        text: weatherReady ? Utils.formatTemp(LocationService.data.weather.current_weather.temperature, Settings.data.location.useFahrenheit, !root.isVertical && !!root.s.showTempUnit, LocationService) : ""
        color: mouseArea.containsMouse ? Color.mOnHover : Color.resolveColorKey(root.s.customColor || "none")
        pointSize: Style.getBarFontSizeForScreen(screenName)
        Layout.alignment: Qt.AlignCenter
        features: ({"tnum": 1})
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onEntered: if (root.s.tooltipOption !== "disable") TooltipService.show(root, Utils.getTooltipRows(LocationService.data.weather, root.s.tooltipOption, Settings.data.location.useFahrenheit, Settings.data.location.use12hourFormat, (s) => pluginApi?.tr(s), LocationService, I18n), BarService.getTooltipDirection(screenName))
    onExited: TooltipService.hide()
    onClicked: (mouse) => mouse.button === Qt.LeftButton ? pluginApi?.openPanel(screen, root) : PanelService.showContextMenu(contextMenu, root, screen)
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      { label: pluginApi?.tr("menu.openPanel"), action: "open", icon: "calendar" },
      { label: pluginApi?.tr("menu.settings"), action: "settings", icon: "settings" }
    ]
    onTriggered: (action) => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "open") pluginApi.openPanel(screen, root);
      else BarService.openPluginSettings(screen, pluginApi.manifest);
    }
  }
}
