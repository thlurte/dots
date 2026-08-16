import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var pluginApi: null
  property var widgetSettings: null

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
    if (widgetSettings) {
      var data = widgetSettings.data || {};
      data.showBackground = data.showBackground ?? false;
      data.roundedCorners = data.roundedCorners ?? true;
      widgetSettings.data = data;
      if (typeof widgetSettings.save === "function")
        widgetSettings.save();
    }
  }

  NHeader {
    label: "Feeds"
    description: "RSS/Atom sources. Lat/lon place the pin on the globe."
  }

  Repeater {
    model: root.valueFeeds.length

    delegate: ColumnLayout {
      required property int index
      Layout.fillWidth: true
      spacing: Style.marginXS

      RowLayout {
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

        NTextInput {
          Layout.preferredWidth: 90 * Style.uiScaleRatio
          label: index === 0 ? "Name" : ""
          text: root.valueFeeds[index]?.name || ""
          onEditingFinished: {
            var arr = root.valueFeeds.slice();
            var row = Object.assign({}, arr[index]);
            row.name = text.trim() || "feed";
            arr[index] = row;
            root.valueFeeds = arr;
            root.persist();
          }
        }

        NTextInput {
          Layout.fillWidth: true
          label: index === 0 ? "URL" : ""
          text: root.valueFeeds[index]?.url || ""
          onEditingFinished: {
            var arr = root.valueFeeds.slice();
            var row = Object.assign({}, arr[index]);
            row.url = text.trim();
            arr[index] = row;
            root.valueFeeds = arr;
            root.persist();
          }
        }

        NIconButton {
          icon: "trash"
          onClicked: {
            var arr = root.valueFeeds.slice();
            arr.splice(index, 1);
            root.valueFeeds = arr;
            root.persist();
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NTextInput {
          Layout.fillWidth: true
          label: index === 0 ? "Lat" : ""
          text: String(root.valueFeeds[index]?.lat ?? 0)
          onEditingFinished: {
            var arr = root.valueFeeds.slice();
            var row = Object.assign({}, arr[index]);
            row.lat = parseFloat(text) || 0;
            arr[index] = row;
            root.valueFeeds = arr;
            root.persist();
          }
        }

        NTextInput {
          Layout.fillWidth: true
          label: index === 0 ? "Lon" : ""
          text: String(root.valueFeeds[index]?.lon ?? 0)
          onEditingFinished: {
            var arr = root.valueFeeds.slice();
            var row = Object.assign({}, arr[index]);
            row.lon = parseFloat(text) || 0;
            arr[index] = row;
            root.valueFeeds = arr;
            root.persist();
          }
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NTextInput {
      id: addName
      Layout.preferredWidth: 90 * Style.uiScaleRatio
      placeholderText: "Name"
    }

    NTextInput {
      id: addUrl
      Layout.fillWidth: true
      placeholderText: "https://…/rss.xml"
    }

    NIconButton {
      icon: "plus"
      enabled: addUrl.text.trim().length > 8
      onClicked: {
        root.valueFeeds = root.valueFeeds.concat([
          {
            name: addName.text.trim() || "feed",
            url: addUrl.text.trim(),
            enabled: true,
            lat: 0,
            lon: 0
          }
        ]);
        addName.text = "";
        addUrl.text = "";
        root.persist();
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NHeader {
    label: "Globe"
    description: "Spin speed and size. Refresh ≥ 5 min."
  }

  RowLayout {
    Layout.fillWidth: true
    NText {
      text: "Globe size"
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }
    NText {
      text: String(root.valueGlobeSize)
      pointSize: Style.fontSizeS
      color: Color.mSecondary
      font.family: "monospace"
    }
  }

  NSlider {
    Layout.fillWidth: true
    from: 280
    to: 640
    stepSize: 20
    value: root.valueGlobeSize
    onMoved: root.valueGlobeSize = Math.round(value / 20) * 20
    onPressedChanged: {
      if (!pressed)
        root.persist();
    }
  }

  RowLayout {
    Layout.fillWidth: true
    NText {
      text: "Spin °/s"
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }
    NText {
      text: String(root.valueSpin)
      pointSize: Style.fontSizeS
      color: Color.mSecondary
      font.family: "monospace"
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

  RowLayout {
    Layout.fillWidth: true
    NText {
      text: "Ticker rows"
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }
    NText {
      text: String(root.valueTickerItems)
      pointSize: Style.fontSizeS
      color: Color.mSecondary
      font.family: "monospace"
    }
  }

  NSlider {
    Layout.fillWidth: true
    from: 4
    to: 16
    stepSize: 1
    value: root.valueTickerItems
    onMoved: root.valueTickerItems = Math.round(value)
    onPressedChanged: {
      if (!pressed)
        root.persist();
    }
  }

  RowLayout {
    Layout.fillWidth: true
    NText {
      text: "Refresh"
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }
    NText {
      text: Math.round(root.valueRefreshSeconds / 60) + " min"
      pointSize: Style.fontSizeS
      color: Color.mSecondary
      font.family: "monospace"
    }
  }

  NSlider {
    Layout.fillWidth: true
    from: 300
    to: 1800
    stepSize: 60
    value: root.valueRefreshSeconds
    onMoved: root.valueRefreshSeconds = Math.round(value / 60) * 60
    onPressedChanged: {
      if (!pressed)
        root.persist();
    }
  }
}
