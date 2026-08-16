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

  property var valueSubs: {
    var f = cfg.subreddits ?? defaults.subreddits ?? [];
    return Array.isArray(f) ? f.slice() : [];
  }
  property int valueMaxItems: cfg.maxItems ?? defaults.maxItems ?? 20
  property int valuePreviewItems: cfg.previewItems ?? defaults.previewItems ?? 5
  property int valueRefreshSeconds: cfg.refreshSeconds ?? defaults.refreshSeconds ?? 600
  property string valueSort: cfg.sort ?? defaults.sort ?? "hot"

  function persist() {
    if (!pluginApi)
      return;
    pluginApi.pluginSettings.subreddits = root.valueSubs;
    pluginApi.pluginSettings.maxItems = root.valueMaxItems;
    pluginApi.pluginSettings.previewItems = root.valuePreviewItems;
    pluginApi.pluginSettings.refreshSeconds = root.valueRefreshSeconds;
    pluginApi.pluginSettings.sort = root.valueSort;
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

  function normalizeSub(text) {
    var s = (text || "").trim();
    s = s.replace(/^https?:\/\/(www\.|old\.)?reddit\.com\/r\//i, "");
    s = s.replace(/^r\//i, "");
    s = s.split("/")[0];
    return s.trim();
  }

  NHeader {
    label: "Subreddits"
    description: "Hot posts via Reddit Atom RSS. Keep refresh ≥ 5 min to avoid blocks."
  }

  Repeater {
    model: root.valueSubs.length

    delegate: RowLayout {
      required property int index
      Layout.fillWidth: true
      spacing: Style.marginS

      NToggle {
        Layout.alignment: Qt.AlignBottom
        Layout.bottomMargin: Style.marginS
        checked: root.valueSubs[index]?.enabled !== false
        onToggled: checked => {
          var arr = root.valueSubs.slice();
          var row = Object.assign({}, arr[index]);
          row.enabled = checked;
          arr[index] = row;
          root.valueSubs = arr;
          root.persist();
        }
      }

      NTextInput {
        Layout.preferredWidth: 100 * Style.uiScaleRatio
        label: index === 0 ? "Name" : ""
        text: root.valueSubs[index]?.name || ""
        placeholderText: "ML"
        onEditingFinished: {
          var arr = root.valueSubs.slice();
          var row = Object.assign({}, arr[index]);
          row.name = text.trim() || row.subreddit || "sub";
          arr[index] = row;
          root.valueSubs = arr;
          root.persist();
        }
      }

      NTextInput {
        Layout.fillWidth: true
        label: index === 0 ? "Subreddit" : ""
        text: root.valueSubs[index]?.subreddit || ""
        placeholderText: "MachineLearning"
        onEditingFinished: {
          var arr = root.valueSubs.slice();
          var row = Object.assign({}, arr[index]);
          var s = root.normalizeSub(text);
          row.subreddit = s;
          if (!row.name)
            row.name = s;
          arr[index] = row;
          root.valueSubs = arr;
          root.persist();
        }
      }

      NIconButton {
        Layout.alignment: Qt.AlignBottom
        Layout.bottomMargin: Style.marginS
        icon: "trash"
        tooltipText: "Remove subreddit"
        onClicked: {
          var arr = root.valueSubs.slice();
          arr.splice(index, 1);
          root.valueSubs = arr;
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
      id: addSub
      Layout.fillWidth: true
      placeholderText: "r/subreddit"
    }

    NIconButton {
      Layout.alignment: Qt.AlignBottom
      Layout.bottomMargin: Style.marginS
      icon: "plus"
      tooltipText: "Add subreddit"
      enabled: addSub.text.trim().length > 1
      onClicked: {
        var s = root.normalizeSub(addSub.text);
        if (!s)
          return;
        root.valueSubs = root.valueSubs.concat([
          {
            name: addName.text.trim() || s,
            subreddit: s,
            enabled: true
          }
        ]);
        addName.text = "";
        addSub.text = "";
        root.persist();
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NHeader {
    label: "Display"
    description: "Preview rows vs full expand list. Sort: hot / new / top / rising."
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: "Sort"
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
    }

    NTextInput {
      Layout.fillWidth: true
      text: root.valueSort
      placeholderText: "hot"
      onEditingFinished: {
        var s = text.trim().toLowerCase();
        if (["hot", "new", "top", "rising"].indexOf(s) < 0)
          s = "hot";
        root.valueSort = s;
        text = s;
        root.persist();
      }
    }
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
      text: "Posts"
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
