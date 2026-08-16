import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property var valueFeeds: {
    var f = cfg.feeds ?? defaults.feeds ?? [];
    return Array.isArray(f) ? f.slice() : [];
  }
  property int valueMaxItems: cfg.maxItems ?? defaults.maxItems ?? 24
  property int valueTickerItems: cfg.tickerItems ?? defaults.tickerItems ?? 8
  property int valueRefreshSeconds: cfg.refreshSeconds ?? defaults.refreshSeconds ?? 600
  property int valueGlobeSize: cfg.globeSize ?? defaults.globeSize ?? 440
  property real valueSpin: cfg.spinDegreesPerSec ?? defaults.spinDegreesPerSec ?? 4

  function persist() {
    if (!pluginApi)
      return;
    pluginApi.pluginSettings.feeds = root.valueFeeds;
    pluginApi.pluginSettings.maxItems = root.valueMaxItems;
    pluginApi.pluginSettings.tickerItems = root.valueTickerItems;
    pluginApi.pluginSettings.refreshSeconds = root.valueRefreshSeconds;
    pluginApi.pluginSettings.globeSize = root.valueGlobeSize;
    pluginApi.pluginSettings.spinDegreesPerSec = root.valueSpin;
    pluginApi.saveSettings();
  }

  function saveSettings() {
    persist();
  }

  NHeader {
    label: "News Globe"
    description: "World RSS pins on a spinning Earth. Use the globe chips for Wind, Rain radar, and Ocean SST."
  }

  Repeater {
    model: root.valueFeeds.length

    delegate: RowLayout {
      required property int index
      Layout.fillWidth: true
      spacing: Style.marginS

      NToggle {
        checked: root.valueFeeds[index]?.enabled !== false
        onToggled: checked => {
          var arr = root.valueFeeds.slice();
          var row = Object.assign({}, arr[index]);
          row.enabled = checked;
          arr[index] = row;
          root.valueFeeds = arr;
          root.persist();
        }
      }

      NText {
        text: root.valueFeeds[index]?.name || "feed"
        color: Color.mOnSurface
        pointSize: Style.fontSizeS
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    NText {
      text: "Ticker: " + root.valueTickerItems + " · spin " + root.valueSpin + "°/s · " + Math.round(root.valueRefreshSeconds / 60) + " min"
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      Layout.fillWidth: true
    }
  }

  NSlider {
    Layout.fillWidth: true
    from: 1
    to: 12
    stepSize: 1
    value: root.valueSpin
    onMoved: root.valueSpin = Math.round(value)
    onPressedChanged: {
      if (!pressed)
        root.persist();
    }
  }
}
