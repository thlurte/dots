import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string editTerminalCommand: cfg.terminalCommand ?? defaults.terminalCommand ?? ""
  property int editPollInterval: cfg.pollInterval ?? defaults.pollInterval ?? 10
  property bool editShowInactiveHosts: cfg.showInactiveHosts ?? defaults.showInactiveHosts ?? true

  spacing: Style.marginM

  // --- Terminal ---
  readonly property string detectedTerminal: pluginApi?.mainInstance?.detectedTerminal ?? ""

  NLabel {
    label: pluginApi?.tr("settings.terminal")
  }

  NText {
    Layout.fillWidth: true
    text: root.detectedTerminal !== "" ? pluginApi?.tr("settings.terminalDetected", { terminal: root.detectedTerminal }) : pluginApi?.tr("settings.terminalNone")
    color: root.detectedTerminal !== "" ? Color.mPrimary : Color.mError
    pointSize: Style.fontSizeS
    wrapMode: Text.Wrap
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.terminalOverride")
    description: pluginApi?.tr("settings.terminalOverrideDesc")
    placeholderText: root.detectedTerminal
    text: root.editTerminalCommand
    onTextChanged: root.editTerminalCommand = text
  }

  // --- Poll Interval ---
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.pollInterval")
      description: pluginApi?.tr("settings.pollIntervalDesc") + root.editPollInterval
    }

    NSlider {
      Layout.fillWidth: true
      from: 5
      to: 30
      stepSize: 1
      value: root.editPollInterval
      onValueChanged: root.editPollInterval = value
    }
  }

  // --- Display ---
  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: inactiveToggle.implicitHeight
    NToggle {
      id: inactiveToggle
      anchors.fill: parent
      label: pluginApi?.tr("settings.showInactiveHosts")
      description: pluginApi?.tr("settings.showInactiveHostsDesc")
      checked: root.editShowInactiveHosts
      onToggled: checked => root.editShowInactiveHosts = checked
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("SSH Sessions", "Cannot save: pluginApi is null")
      return
    }

    pluginApi.pluginSettings.terminalCommand = root.editTerminalCommand
    pluginApi.pluginSettings.pollInterval = root.editPollInterval
    pluginApi.pluginSettings.showInactiveHosts = root.editShowInactiveHosts

    pluginApi.saveSettings()
    Logger.i("SSH Sessions", "Settings saved")
  }
}
