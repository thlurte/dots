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
  }

  NHeader {
    label: "Obsidian vaults"
    description: "Desktop card lists vaults from obsidian.json."
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Config path"
    text: root.valueConfigPath
    onEditingFinished: {
      root.valueConfigPath = text.trim() || "~/.config/obsidian/obsidian.json";
      root.persist();
    }
  }

  NToggle {
    label: "Show paths"
    checked: root.valueShowPath
    onToggled: checked => {
      root.valueShowPath = checked;
      root.persist();
    }
  }

  RowLayout {
    Layout.fillWidth: true
    NText {
      text: "Max vaults: " + root.valueMaxVaults
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
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
