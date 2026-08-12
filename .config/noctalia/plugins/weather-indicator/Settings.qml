import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property bool showTempValue: cfg.showTempValue ?? defaults.showTempValue
  property bool showConditionIcon: cfg.showConditionIcon ?? defaults.showConditionIcon
  property bool showTempUnit: cfg.showTempUnit ?? defaults.showTempUnit
  property string tooltipOption: cfg.tooltipOption ?? defaults.tooltipOption
  property string customColor: cfg.customColor ?? defaults.customColor
  spacing: Style.marginL

  Component.onCompleted: {
    Logger.i("WeatherIndicator", "Settings UI loaded");
  }

  NColorChoice {
    label: pluginApi?.tr("settings.customColor.label")
    description: pluginApi?.tr("settings.customColor.desc")
    currentKey: root.customColor
    onSelected: key => {
                  root.customColor = key;
                }
  }

  NToggle {
    id: toggleIcon
    label: pluginApi?.tr("settings.showConditionIcon.label")
    description: pluginApi?.tr("settings.showConditionIcon.desc")
    checked: root.showConditionIcon
    onToggled: checked => {
      root.showConditionIcon = checked;
      root.showTempValue = true;
    }
    defaultValue: true
  }

  NToggle {
    id: toggleTempText
    label: pluginApi?.tr("settings.showTempValue.label")
    description: pluginApi?.tr("settings.showTempValue.desc")
    checked: root.showTempValue
    onToggled: checked => {
      root.showTempValue = checked;
      root.showConditionIcon = true;
    }
    defaultValue: true
  }

  NToggle {
    id: toggleTempLetter
    label: pluginApi?.tr("settings.showTempUnit.label")
    description: pluginApi?.tr("settings.showTempUnit.desc")
    checked: root.showTempUnit
    visible: root.showTempValue
    onToggled: checked => {
      root.showTempUnit = checked;
    }
    defaultValue: true
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.tooltipOption.label")
    description: pluginApi?.tr("settings.tooltipOption.desc")
    model: [
      {
        "key": "disable",
        "name": pluginApi?.tr("settings.mode.disable")
      },
      {
        "key": "highlow",
        "name": pluginApi?.tr("settings.mode.highlow")
      },
      {
        "key": "sunrise",
        "name": pluginApi?.tr("settings.mode.sunrise")
      },
      {
        "key": "everything",
        "name": pluginApi?.tr("settings.mode.everything")
      }
    ]
    currentKey: root.tooltipOption
    onSelected: function (key) {
      root.tooltipOption = key;
    }
    defaultValue: "everything"
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("WeatherIndicator", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.showTempValue = root.showTempValue;
    pluginApi.pluginSettings.showConditionIcon = root.showConditionIcon;
    pluginApi.pluginSettings.showTempUnit = root.showTempUnit;
    pluginApi.pluginSettings.tooltipOption = root.tooltipOption;
    pluginApi.pluginSettings.customColor = root.customColor;
    pluginApi.saveSettings();

    Logger.i("WeatherIndicator", "Settings saved successfully");
    pluginApi.closePanel(root.screen);
  }
}
