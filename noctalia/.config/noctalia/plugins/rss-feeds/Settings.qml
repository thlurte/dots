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
  property int valueMaxItems: cfg.maxItems ?? defaults.maxItems ?? 20
  property int valuePreviewItems: cfg.previewItems ?? defaults.previewItems ?? 5
  property int valueRefreshSeconds: cfg.refreshSeconds ?? defaults.refreshSeconds ?? 300

  function persist() {
    if (!pluginApi)
      return;
    pluginApi.pluginSettings.feeds = root.valueFeeds;
    pluginApi.pluginSettings.maxItems = root.valueMaxItems;
    pluginApi.pluginSettings.previewItems = root.valuePreviewItems;
    pluginApi.pluginSettings.refreshSeconds = root.valueRefreshSeconds;
    pluginApi.saveSettings();
  }

  function saveSettings() {
    persist();
  }

  NHeader {
    label: "RSS feeds"
    description: "Shared list used by the desktop widget. Add more URLs anytime."
  }

  Repeater {
    model: root.valueFeeds.length

    delegate: RowLayout {
      required property int index
      Layout.fillWidth: true
      spacing: Style.marginS

      NToggle {
        Layout.alignment: Qt.AlignBottom
        Layout.bottomMargin: Style.marginS
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
        Layout.alignment: Qt.AlignBottom
        Layout.bottomMargin: Style.marginS
        icon: "trash"
        onClicked: {
          var arr = root.valueFeeds.slice();
          arr.splice(index, 1);
          root.valueFeeds = arr;
          root.persist();
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
      placeholderText: "https://…/rss"
    }

    NIconButton {
      Layout.alignment: Qt.AlignBottom
      Layout.bottomMargin: Style.marginS
      icon: "plus"
      enabled: addUrl.text.trim().length > 8
      onClicked: {
        root.valueFeeds = root.valueFeeds.concat([
          {
            name: addName.text.trim() || "feed",
            url: addUrl.text.trim(),
            enabled: true
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

  RowLayout {
    Layout.fillWidth: true
    NText {
      text: "Preview rows: " + root.valuePreviewItems
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }
  }

  NSlider {
    Layout.fillWidth: true
    from: 3
    to: 10
    stepSize: 1
    value: root.valuePreviewItems
    onMoved: root.valuePreviewItems = Math.round(value)
    onPressedChanged: {
      if (!pressed)
        root.persist();
    }
  }

  RowLayout {
    Layout.fillWidth: true
    NText {
      text: "Headlines: " + root.valueMaxItems
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }
  }

  NSlider {
    Layout.fillWidth: true
    from: 5
    to: 40
    stepSize: 1
    value: root.valueMaxItems
    onMoved: root.valueMaxItems = Math.round(value)
    onPressedChanged: {
      if (!pressed)
        root.persist();
    }
  }

  RowLayout {
    Layout.fillWidth: true
    NText {
      text: "Refresh: " + Math.round(root.valueRefreshSeconds / 60) + " min"
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }
  }

  NSlider {
    Layout.fillWidth: true
    from: 60
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
