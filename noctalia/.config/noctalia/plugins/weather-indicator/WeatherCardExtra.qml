import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Location
import qs.Widgets
import "WeatherUtils.js" as Utils

NBox {
  id: root
  property int forecastDays: 7
  property bool showLocation: true
  property bool showEffects: Settings.data.location.weatherShowEffects
  readonly property bool weatherReady: Settings.data.location.weatherEnabled && !!LocationService.data.weather

  readonly property int code: weatherReady ? LocationService.data.weather.current_weather.weathercode : 0
  readonly property bool isDay: weatherReady ? LocationService.data.weather.current_weather.is_day : true
  readonly property bool isRaining: (code >= 51 && code <= 67) || (code >= 80 && code <= 82)
  readonly property bool isSnowing: (code >= 71 && code <= 77) || (code >= 85 && code <= 86)
  readonly property bool isCloudy: code === 3
  readonly property bool isFoggy: code >= 40 && code <= 49
  readonly property bool isClearDay: code === 0 && isDay
  readonly property bool isClearNight: code === 0 && !isDay

  visible: Settings.data.location.weatherEnabled
  implicitHeight: Math.max(100 * Style.uiScaleRatio, content.implicitHeight + (Style.marginL * 2))

  Loader {
    anchors.fill: parent
    active: root.showEffects && (isRaining || isSnowing || isCloudy || isFoggy || isClearDay || isClearNight)
    sourceComponent: ShaderEffect {
      property real time: 0
      NumberAnimation on time { from: 0; to: 1000; duration: 100000; loops: Animation.Infinite }
      anchors.fill: parent
      anchors.margins: isRaining ? Style.marginXL : root.border.width
      property var source: ShaderEffectSource { sourceItem: content; hideSource: root.isRaining }
      property real itemWidth: width; property real itemHeight: height
      property color bgColor: root.color
      property real cornerRadius: isRaining ? 0 : (root.radius - root.border.width)
      property real alternative: isFoggy
      fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/" + (isSnowing ? "weather_snow" : isRaining ? "weather_rain" : (isCloudy || isFoggy) ? "weather_cloud" : isClearDay ? "weather_sun" : "weather_stars") + ".frag.qsb")
    }
  }

  ColumnLayout {
    id: content
    anchors.fill: parent; anchors.margins: Style.marginL; spacing: Style.marginM; clip: true

    RowLayout {
      Layout.fillWidth: true; spacing: Style.marginS
      Item { Layout.preferredWidth: Style.marginXXS }
      RowLayout {
        spacing: Style.marginL; Layout.fillWidth: true
        NIcon {
          icon: weatherReady ? LocationService.weatherSymbolFromCode(code, isDay) : "weather-cloud-off"
          pointSize: Style.fontSizeXXXL * 1.75; color: Color.mPrimary
        }
        ColumnLayout {
          spacing: Style.marginXXS
          NText {
            text: Settings.data.location.name.split(",")[0]
            pointSize: Style.fontSizeL; font.weight: Style.fontWeightBold
            visible: showLocation && !Settings.data.location.hideWeatherCityName
          }
          RowLayout {
            NText {
              visible: weatherReady
              text: weatherReady ? Utils.formatTemp(LocationService.data.weather.current_weather.temperature, Settings.data.location.useFahrenheit, true, LocationService) : ""
              pointSize: showLocation ? Style.fontSizeXL : Style.fontSizeXL * 1.6; font.weight: Style.fontWeightBold
            }
            NText {
              text: weatherReady ? `(${LocationService.data.weather.timezone_abbreviation})` : ""
              pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant
              visible: weatherReady && showLocation && !Settings.data.location.hideWeatherTimezone
            }
          }
        }
      }
    }

    NDivider { visible: weatherReady; Layout.fillWidth: true }

    RowLayout {
      visible: weatherReady; Layout.fillWidth: true; spacing: Style.marginM
      Repeater {
        model: weatherReady ? Math.min(root.forecastDays, LocationService.data.weather.daily.time.length) : 0
        delegate: ColumnLayout {
          Layout.fillWidth: true; spacing: Style.marginXS
          Item { Layout.fillWidth: true }
          NText {
            Layout.alignment: Qt.AlignCenter
            text: I18n.locale.toString(new Date(LocationService.data.weather.daily.time[index].replace(/-/g, "/")), "ddd")
            color: Color.mOnSurface
          }
          NIcon {
            Layout.alignment: Qt.AlignCenter
            icon: LocationService.weatherSymbolFromCode(LocationService.data.weather.daily.weathercode[index])
            pointSize: Style.fontSizeXXL * 1.6; color: Color.mPrimary
          }
          NText {
            Layout.alignment: Qt.AlignCenter
            text: `${Utils.formatTemp(LocationService.data.weather.daily.temperature_2m_max[index], Settings.data.location.useFahrenheit, false, LocationService)}°/${Utils.formatTemp(LocationService.data.weather.daily.temperature_2m_min[index], Settings.data.location.useFahrenheit, false, LocationService)}°`
            pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant
          }
          Repeater {
            model: ["sunrise", "sunset"]
            delegate: NText {
              Layout.alignment: Qt.AlignCenter
              text: I18n.locale.toString(new Date(LocationService.data.weather.daily[modelData][index]), Settings.data.location.use12hourFormat ? "hh:mm AP" : "HH:mm")
              pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant
            }
          }
        }
      }
    }
    Loader { active: !weatherReady; Layout.alignment: Qt.AlignCenter; sourceComponent: NBusyIndicator {} }
  }
}
