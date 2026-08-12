import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property int valueIntervalSeconds: cfg.intervalSeconds ?? defaults.intervalSeconds
  property int valueThresholdGood: cfg.thresholdGood ?? defaults.thresholdGood
  property int valueThresholdWarning: cfg.thresholdWarning ?? defaults.thresholdWarning
  property bool valueShowHostName: cfg.showHostName ?? defaults.showHostName
  property string valueBarHost: cfg.barHost ?? defaults.barHost
  property string valueColorGood: cfg.colorGood ?? defaults.colorGood
  property string valueColorWarning: cfg.colorWarning ?? defaults.colorWarning
  property string valueColorCritical: cfg.colorCritical ?? defaults.colorCritical
  property var valueHosts: cfg.hosts ?? defaults.hosts
  property bool valueAnimations: cfg.animations ?? defaults.animations

  spacing: Style.marginL

  NHeader {
    label: pluginApi?.tr("settings.hosts.header")
    description: pluginApi?.tr("settings.hosts.desc")
  }

  Repeater {
    model: valueHosts

    delegate: RowLayout {
      required property var modelData
      required property int index
      Layout.fillWidth: true
      spacing: Style.marginS

      NTextInput {
        Layout.preferredWidth: 120 * Style.uiScaleRatio
        label: index === 0 ? pluginApi?.tr("settings.hosts.name") : ""
        placeholderText: "Name"
        text: modelData.name
        onEditingFinished: {
          const arr = root.valueHosts.slice();
          arr[index] = {
            name: text,
            address: arr[index].address
          };
          root.valueHosts = arr;
        }
      }

      NTextInput {
        Layout.fillWidth: true
        label: index === 0 ? pluginApi?.tr("settings.hosts.address") : ""
        placeholderText: "IP / hostname"
        text: modelData.address
        onEditingFinished: {
          const arr = root.valueHosts.slice();
          arr[index] = {
            name: arr[index].name,
            address: text
          };
          root.valueHosts = arr;
        }
      }

      NIconButton {
        Layout.alignment: Qt.AlignBottom
        Layout.bottomMargin: Style.marginS
        icon: "trash"
        tooltipText: pluginApi?.tr("settings.hosts.remove")
        enabled: root.valueHosts.length > 1
        onClicked: {
          const arr = root.valueHosts.slice();
          arr.splice(index, 1);
          root.valueHosts = arr;
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NTextInput {
      id: addNameField
      Layout.preferredWidth: 120 * Style.uiScaleRatio
      placeholderText: pluginApi?.tr("settings.hosts.namePlaceholder")
    }

    NTextInput {
      id: addAddrField
      Layout.fillWidth: true
      placeholderText: pluginApi?.tr("settings.hosts.addressPlaceholder")
    }

    NIconButton {
      Layout.alignment: Qt.AlignBottom
      Layout.bottomMargin: Style.marginS
      icon: "plus"
      tooltipText: pluginApi?.tr("settings.hosts.add")
      enabled: addNameField.text.trim() !== "" && addAddrField.text.trim() !== ""
      onClicked: {
        root.valueHosts = root.valueHosts.concat([
          {
            name: addNameField.text.trim(),
            address: addAddrField.text.trim()
          }
        ]);
        addNameField.text = "";
        addAddrField.text = "";
      }
    }
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.barHost.label")
    description: pluginApi?.tr("settings.barHost.desc")
    currentKey: root.valueBarHost
    model: {
      const base = [
        {
          key: "worst",
          name: pluginApi?.tr("settings.barHost.worst")
        }
      ];
      for (const h of root.valueHosts)
        base.push({
          key: h.name,
          name: h.name
        });
      return base;
    }
    onSelected: key => root.valueBarHost = key
  }

  NDivider {
    Layout.fillWidth: true
  }

  NHeader {
    label: pluginApi?.tr("settings.interval.header")
    description: pluginApi?.tr("settings.interval.desc")
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NText {
      text: pluginApi?.tr("settings.interval.label")
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }

    NText {
      text: root.valueIntervalSeconds + " s"
      pointSize: Style.fontSizeS
      color: Color.mSecondary
      font.family: "monospace"
    }
  }

  NSlider {
    Layout.fillWidth: true
    from: 1
    to: 30
    stepSize: 1
    value: root.valueIntervalSeconds
    onMoved: root.valueIntervalSeconds = Math.round(value)
  }

  NDivider {
    Layout.fillWidth: true
  }

  NHeader {
    label: pluginApi?.tr("settings.thresholds.header")
    description: pluginApi?.tr("settings.thresholds.desc")
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM
    NText {
      text: pluginApi?.tr("settings.thresholds.good")
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }
    NText {
      text: root.valueThresholdGood + " ms"
      pointSize: Style.fontSizeS
      color: root.valueColorGood
      font.family: "monospace"
    }
  }
  NSlider {
    Layout.fillWidth: true
    from: 5
    to: 100
    stepSize: 5
    value: root.valueThresholdGood
    onMoved: root.valueThresholdGood = Math.round(value)
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM
    NText {
      text: pluginApi?.tr("settings.thresholds.warning")
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }
    NText {
      text: root.valueThresholdWarning + " ms"
      pointSize: Style.fontSizeS
      color: root.valueColorWarning
      font.family: "monospace"
    }
  }
  NSlider {
    Layout.fillWidth: true
    from: root.valueThresholdGood + 5   // can't go below good threshold
    to: 500
    stepSize: 5
    value: root.valueThresholdWarning
    onMoved: root.valueThresholdWarning = Math.round(value)
  }

  NDivider {
    Layout.fillWidth: true
  }

  NHeader {
    label: pluginApi?.tr("settings.display.header")
    Layout.bottomMargin: -Style.marginM
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showHostName.label")
    description: pluginApi?.tr("settings.showHostName.desc")
    checked: root.valueShowHostName
    onToggled: checked => root.valueShowHostName = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.animations.label")
    description: pluginApi?.tr("settings.animations.desc")
    checked: root.valueAnimations
    onToggled: checked => root.valueAnimations = checked
  }

  RowLayout {
    NLabel {
      label: pluginApi?.tr("settings.colorGood.label")
      Layout.alignment: Qt.AlignCenter
    }

    NColorPicker {
      selectedColor: root.valueColorGood
      onColorSelected: key => root.valueColorGood = key
    }
  }

  RowLayout {
    NLabel {
      label: pluginApi?.tr("settings.colorWarning.label")
      Layout.alignment: Qt.AlignCenter
    }

    NColorPicker {
      selectedColor: root.valueColorWarning
      onColorSelected: key => root.valueColorWarning = key
    }
  }

  RowLayout {
    NLabel {
      label: pluginApi?.tr("settings.colorCritical.label")
      Layout.alignment: Qt.AlignCenter
    }

    NColorPicker {
      selectedColor: root.valueColorCritical
      onColorSelected: key => root.valueColorCritical = key
    }
  }

  function saveSettings() {
    if (!pluginApi)
      return;
    pluginApi.pluginSettings.hosts = root.valueHosts;
    pluginApi.pluginSettings.intervalSeconds = root.valueIntervalSeconds;
    pluginApi.pluginSettings.thresholdGood = root.valueThresholdGood;
    pluginApi.pluginSettings.thresholdWarning = root.valueThresholdWarning;
    pluginApi.pluginSettings.showHostName = root.valueShowHostName;
    pluginApi.pluginSettings.barHost = root.valueBarHost;
    pluginApi.pluginSettings.colorGood = root.valueColorGood;
    pluginApi.pluginSettings.colorWarning = root.valueColorWarning;
    pluginApi.pluginSettings.colorCritical = root.valueColorCritical;
    pluginApi.pluginSettings.animations = root.valueAnimations;
    pluginApi.saveSettings();
    Logger.d("LatencyMonitor", "Settings saved");
  }
}
