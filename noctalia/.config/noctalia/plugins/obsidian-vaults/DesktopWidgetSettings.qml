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

  property string valueConfigPath: cfg.obsidianConfigPath ?? defaults.obsidianConfigPath ?? "~/.config/obsidian/obsidian.json"
  property bool valueShowPath: cfg.showPath ?? defaults.showPath ?? true
  property int valueMaxVaults: cfg.maxVaults ?? defaults.maxVaults ?? 12

  function persist() {
    if (!pluginApi)
      return;
    pluginApi.pluginSettings.obsidianConfigPath = root.valueConfigPath;
    pluginApi.pluginSettings.showPath = root.valueShowPath;
    pluginApi.pluginSettings.maxVaults = root.valueMaxVaults;
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
    label: "Obsidian vaults"
    description: "Reads vaults from obsidian.json. Click a row to open it."
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Config path"
    text: root.valueConfigPath
    placeholderText: "~/.config/obsidian/obsidian.json"
    onEditingFinished: {
      root.valueConfigPath = text.trim() || "~/.config/obsidian/obsidian.json";
      root.persist();
    }
  }

  NToggle {
    label: "Show paths"
    description: "Show full vault folder under each name"
    checked: root.valueShowPath
    onToggled: checked => {
      root.valueShowPath = checked;
      root.persist();
    }
  }

  RowLayout {
    Layout.fillWidth: true
    NText {
      text: "Max vaults"
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }
    NText {
      text: String(root.valueMaxVaults)
      pointSize: Style.fontSizeS
      color: Color.mSecondary
      font.family: "monospace"
    }
  }

  NSlider {
    Layout.fillWidth: true
    from: 3
    to: 20
    stepSize: 1
    value: root.valueMaxVaults
    onMoved: root.valueMaxVaults = Math.round(value)
    onPressedChanged: {
      if (!pressed)
        root.persist();
    }
  }
}
