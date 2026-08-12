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

  property var valueAccounts: {
    var f = cfg.accounts ?? defaults.accounts ?? [];
    return Array.isArray(f) ? f.slice() : [];
  }
  property int valueMaxItems: cfg.maxItems ?? defaults.maxItems ?? 20
  property int valuePreviewItems: cfg.previewItems ?? defaults.previewItems ?? 5
  property int valueRefreshSeconds: cfg.refreshSeconds ?? defaults.refreshSeconds ?? 300

  function persist() {
    if (!pluginApi)
      return;
    pluginApi.pluginSettings.accounts = root.valueAccounts;
    pluginApi.pluginSettings.maxItems = root.valueMaxItems;
    pluginApi.pluginSettings.previewItems = root.valuePreviewItems;
    pluginApi.pluginSettings.refreshSeconds = root.valueRefreshSeconds;
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
    label: "Accounts"
    description: "Add @handles. Uses bird with your Chrome X cookies."
  }

  Repeater {
    model: root.valueAccounts.length

    delegate: RowLayout {
      required property int index
      Layout.fillWidth: true
      spacing: Style.marginS

      NToggle {
        Layout.alignment: Qt.AlignBottom
        Layout.bottomMargin: Style.marginS
        checked: root.valueAccounts[index]?.enabled !== false
        onToggled: checked => {
          var arr = root.valueAccounts.slice();
          var row = Object.assign({}, arr[index]);
          row.enabled = checked;
          arr[index] = row;
          root.valueAccounts = arr;
          root.persist();
        }
      }

      NTextInput {
        Layout.preferredWidth: 100 * Style.uiScaleRatio
        label: index === 0 ? "Name" : ""
        text: root.valueAccounts[index]?.name || ""
        placeholderText: "Karpathy"
        onEditingFinished: {
          var arr = root.valueAccounts.slice();
          var row = Object.assign({}, arr[index]);
          row.name = text.trim() || row.handle || "user";
          arr[index] = row;
          root.valueAccounts = arr;
          root.persist();
        }
      }

      NTextInput {
        Layout.fillWidth: true
        label: index === 0 ? "Handle" : ""
        text: root.valueAccounts[index]?.handle || ""
        placeholderText: "@handle"
        onEditingFinished: {
          var arr = root.valueAccounts.slice();
          var row = Object.assign({}, arr[index]);
          var h = text.trim();
          if (h.startsWith("@"))
            h = h.slice(1);
          row.handle = h;
          if (!row.name)
            row.name = h;
          arr[index] = row;
          root.valueAccounts = arr;
          root.persist();
        }
      }

      NIconButton {
        Layout.alignment: Qt.AlignBottom
        Layout.bottomMargin: Style.marginS
        icon: "trash"
        tooltipText: "Remove account"
        onClicked: {
          var arr = root.valueAccounts.slice();
          arr.splice(index, 1);
          root.valueAccounts = arr;
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
      Layout.preferredWidth: 100 * Style.uiScaleRatio
      placeholderText: "Name"
    }

    NTextInput {
      id: addHandle
      Layout.fillWidth: true
      placeholderText: "@handle"
    }

    NIconButton {
      Layout.alignment: Qt.AlignBottom
      Layout.bottomMargin: Style.marginS
      icon: "plus"
      tooltipText: "Add account"
      enabled: addHandle.text.trim().length > 1
      onClicked: {
        var h = addHandle.text.trim();
        if (h.startsWith("@"))
          h = h.slice(1);
        root.valueAccounts = root.valueAccounts.concat([
          {
            name: addName.text.trim() || h,
            handle: h,
            enabled: true
          }
        ]);
        addName.text = "";
        addHandle.text = "";
        root.persist();
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NHeader {
    label: "Display"
    description: "Preview rows vs full expand list. Keep refresh ≥ 2 min to avoid rate limits."
  }

  RowLayout {
    Layout.fillWidth: true
    NText {
      text: "Preview rows"
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }
    NText {
      text: String(root.valuePreviewItems)
      pointSize: Style.fontSizeS
      color: Color.mSecondary
      font.family: "monospace"
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
      text: "Tweets"
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      Layout.fillWidth: true
    }
    NText {
      text: String(root.valueMaxItems)
      pointSize: Style.fontSizeS
      color: Color.mSecondary
      font.family: "monospace"
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
