import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string valueKubeconfigPath: cfg.kubeconfigPath ?? defaults.kubeconfigPath ?? ""
  property int valuePollInterval: cfg.pollInterval ?? defaults.pollInterval ?? 60
  property bool valueShowErrorBadge: cfg.showErrorBadge ?? defaults.showErrorBadge ?? true
  property string valueTerminal: cfg.terminal ?? defaults.terminal ?? ""
  property string valueIconColor: cfg.iconColor ?? defaults.iconColor ?? "none"
  property int valuePanelWidth: cfg.panelWidth ?? defaults.panelWidth ?? 620
  property int valuePanelHeight: cfg.panelHeight ?? defaults.panelHeight ?? 680

  spacing: Style.marginL

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.kubeconfigPath.label")
      description: pluginApi?.tr("settings.kubeconfigPath.desc")
      placeholderText: pluginApi?.tr("settings.kubeconfigPath.placeholder")
      text: root.valueKubeconfigPath
      onTextChanged: root.valueKubeconfigPath = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.terminal.label")
      description: pluginApi?.tr("settings.terminal.desc")
      placeholderText: pluginApi?.tr("settings.terminal.placeholder")
      text: root.valueTerminal
      onTextChanged: root.valueTerminal = text
    }

    NValueSlider {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.pollInterval.label")
      description: pluginApi?.tr("settings.pollInterval.desc")
      from: 10
      to: 120
      stepSize: 10
      value: root.valuePollInterval
      text: root.valuePollInterval + " s"
      onMoved: value => root.valuePollInterval = value
    }

    NToggle {
      label: pluginApi?.tr("settings.showErrorBadge.label")
      description: pluginApi?.tr("settings.showErrorBadge.desc")
      checked: root.valueShowErrorBadge
      onToggled: checked => root.valueShowErrorBadge = checked
    }

    NComboBox {
      label: pluginApi?.tr("settings.iconColor.label")
      description: pluginApi?.tr("settings.iconColor.desc")
      model: Color.colorKeyModel
      currentKey: root.valueIconColor
      onSelected: key => root.valueIconColor = key
    }

    NValueSlider {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.panelWidth.label")
      description: pluginApi?.tr("settings.panelWidth.desc")
      from: 400
      to: 1200
      stepSize: 20
      value: root.valuePanelWidth
      defaultValue: defaults.panelWidth ?? 620
      showReset: true
      text: root.valuePanelWidth + " px"
      onMoved: value => root.valuePanelWidth = value
    }

    NValueSlider {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.panelHeight.label")
      description: pluginApi?.tr("settings.panelHeight.desc")
      from: 400
      to: 1200
      stepSize: 20
      value: root.valuePanelHeight
      defaultValue: defaults.panelHeight ?? 680
      showReset: true
      text: root.valuePanelHeight + " px"
      onMoved: value => root.valuePanelHeight = value
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("KubectlCtx", "Cannot save settings: pluginApi is null");
      return;
    }
    pluginApi.pluginSettings.kubeconfigPath = root.valueKubeconfigPath;
    pluginApi.pluginSettings.terminal = root.valueTerminal;
    pluginApi.pluginSettings.pollInterval = root.valuePollInterval;
    pluginApi.pluginSettings.showErrorBadge = root.valueShowErrorBadge;
    pluginApi.pluginSettings.iconColor = root.valueIconColor;
    pluginApi.pluginSettings.panelWidth = root.valuePanelWidth;
    pluginApi.pluginSettings.panelHeight = root.valuePanelHeight;
    pluginApi.saveSettings();
    Logger.i("KubectlCtx", "Settings saved");
  }
}
