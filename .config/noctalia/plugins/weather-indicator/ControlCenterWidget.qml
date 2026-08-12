import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Location
import qs.Widgets
import qs.Services.UI
import "WeatherUtils.js" as Utils

NIconButtonHot {
    id: root
    property ShellScreen screen
    property var pluginApi: null
    readonly property bool weatherReady: Settings.data.location.weatherEnabled && !!LocationService.data.weather
    readonly property var s: pluginApi?.pluginSettings || pluginApi?.manifest?.metadata?.defaultSettings || {}

    icon: weatherReady ? LocationService.weatherSymbolFromCode(LocationService.data.weather.current_weather.weathercode, LocationService.data.weather.current_weather.is_day) : "weather-cloud-off"

    implicitWidth: Math.round(Style.baseWidgetSize * Style.uiScaleRatio)
    implicitHeight: implicitWidth

    tooltipText: Utils.getTooltipRows(LocationService.data.weather, s.tooltipOption || "everything", Settings.data.location.useFahrenheit, Settings.data.location.use12hourFormat, (s) => pluginApi?.tr(s), LocationService, I18n)

    onClicked: pluginApi?.togglePanel(screen, this)
}
