import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true
  property real contentPreferredWidth: Math.round((pluginApi?.pluginSettings?.panelWidth ?? pluginApi?.manifest?.metadata?.defaultSettings?.panelWidth ?? 620) * Style.uiScaleRatio)
  property real contentPreferredHeight: Math.round((pluginApi?.pluginSettings?.panelHeight ?? pluginApi?.manifest?.metadata?.defaultSettings?.panelHeight ?? 680) * Style.uiScaleRatio)

  readonly property var main: pluginApi?.mainInstance ?? null

  // Close namespace dropdown when context changes
  Connections {
    target: root.main
    function onActiveContextChanged() {
      nsDropdown.visible = false;
      nsSearchInput.clearSearch();
    }
  }

  property string nsFilterText: ""
  property int nsHighlightIndex: 0
  property bool nsListHovered: false
  property var nsFilteredListCache: []

  readonly property var nsFilteredList: {
    var all = main?.namespaces ?? [];
    var q = root.nsFilterText.toLowerCase();
    return q === "" ? all : all.filter(n => n.toLowerCase().includes(q));
  }

  onNsFilteredListChanged: {
    if (!root.nsListHovered) {
      root.nsFilteredListCache = root.nsFilteredList;
    }
  }

  function nsSelectHighlighted() {
    var list = root.nsFilteredList;
    if (list.length === 0) return;
    var idx = Math.max(0, Math.min(root.nsHighlightIndex, list.length - 1));
    nsDropdown.visible = false;
    nsSearchInput.clearSearch();
    if (main) main.switchNamespace(list[idx]);
  }

  // Delete confirmation state
  property bool showDeleteConfirm: false
  property string deleteKind: ""
  property string deleteName: ""

  // Toast state
  property bool showCopiedToast: false

  // Active tab index
  property int activeTab: 0

  readonly property var tabs: [
    { key: "pods",         label: pluginApi?.tr("panel.tabs.pods"),         kind: "pod" },
    { key: "deployments",  label: pluginApi?.tr("panel.tabs.deployments"),  kind: "deployment" },
    { key: "statefulsets", label: pluginApi?.tr("panel.tabs.statefulsets"), kind: "statefulset" },
    { key: "daemonsets",   label: pluginApi?.tr("panel.tabs.daemonsets"),   kind: "daemonset" },
    { key: "services",     label: pluginApi?.tr("panel.tabs.services"),     kind: "service" },
    { key: "ingresses",    label: pluginApi?.tr("panel.tabs.ingresses"),    kind: "ingress" },
    { key: "configmaps",   label: pluginApi?.tr("panel.tabs.configmaps"),   kind: "configmap" },
    { key: "secrets",      label: pluginApi?.tr("panel.tabs.secrets"),      kind: "secret" }
  ]

  function currentResources() {
    if (!main) return [];
    switch (activeTab) {
      case 0: return main.pods ?? [];
      case 1: return main.deployments ?? [];
      case 2: return main.statefulsets ?? [];
      case 3: return main.daemonsets ?? [];
      case 4: return main.services ?? [];
      case 5: return main.ingresses ?? [];
      case 6: return main.configmaps ?? [];
      case 7: return main.secrets ?? [];
      default: return [];
    }
  }

  function handleCopy(name) {
    if (main) main.copyToClipboard(name);
    root.showCopiedToast = true;
    copiedTimer.restart();
  }

  function handleDescribe(kind, name) {
    if (main) main.openTerminal(["describe", kind, name]);
  }

  function handleLogs(name) {
    if (main) main.openTerminal(["logs", "-f", name]);
  }

  function handleDelete(kind, name) {
    root.deleteKind = kind;
    root.deleteName = name;
    root.showDeleteConfirm = true;
  }

  function handleRestart(kind, name) {
    if (main) main.restartResource(kind, name);
  }

  Timer {
    id: copiedTimer
    interval: 2000
    onTriggered: root.showCopiedToast = false
  }

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // ═══════════════════════════════════════════════════════════
      // HEADER
      // ═══════════════════════════════════════════════════════════
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(headerRow.implicitHeight + Style.marginM * 2 + 1)

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NIcon {
            icon: "topology-star-3"
            pointSize: Style.fontSizeXXL
            color: Color.mPrimary
          }

          NLabel {
            label: pluginApi?.tr("panel.title")
            Layout.fillWidth: true
          }

          // Copied toast
          NText {
            visible: root.showCopiedToast
            text: pluginApi?.tr("actions.copied")
            pointSize: Style.fontSizeS
            color: Color.mTertiary
          }

          NIconButton {
            icon: "refresh"
            tooltipText: pluginApi?.tr("panel.refresh")
            baseSize: Style.baseWidgetSize * 0.8
            enabled: !(main?.loading ?? false)
            onClicked: {
              if (main) {
                main.fetchContexts();
              }
            }
          }

          NIconButton {
            icon: "settings"
            tooltipText: pluginApi?.tr("menu.settings")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              if (pluginApi) {
                BarService.openPluginSettings(pluginApi.panelOpenScreen, pluginApi.manifest);
                pluginApi.closePanel(pluginApi.panelOpenScreen);
              }
            }
          }

          NIconButton {
            icon: "x"
            tooltipText: pluginApi?.tr("panel.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              if (pluginApi) pluginApi.closePanel(pluginApi.panelOpenScreen);
            }
          }
        }
      }

      // ═══════════════════════════════════════════════════════════
      // CONTEXT + NAMESPACE SWITCHERS
      // ═══════════════════════════════════════════════════════════
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(switchersContent.implicitHeight + Style.marginM * 2 + 1)

        ColumnLayout {
          id: switchersContent
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          // Context switcher
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NText {
              text: pluginApi?.tr("panel.context")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              Layout.minimumWidth: Math.round(70 * Style.uiScaleRatio)
            }

            NScrollView {
              id: contextScroll
              Layout.fillWidth: true
              Layout.preferredHeight: {
                var count = (main?.contexts ?? []).length;
                if (count === 0) return Math.round(32 * Style.uiScaleRatio);
                var rowH = contextList.children.length > 0
                  ? contextList.children[0].implicitHeight
                  : Math.round((Style.fontSizeM + Style.marginS * 2) * Style.uiScaleRatio + 8);
                return Math.min(count, 4) * rowH;
              }
              horizontalPolicy: ScrollBar.AlwaysOff
              verticalPolicy: (main?.contexts ?? []).length > 4 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

              ColumnLayout {
                id: contextList
                width: contextScroll.availableWidth
                spacing: 0

                Repeater {
                  model: main?.contexts ?? []
                  delegate: ContextRow {
                    required property string modelData
                    Layout.fillWidth: true
                    pluginApi: root.pluginApi
                    contextName: modelData
                    isActive: modelData === (main?.activeContext ?? "")
                    onActivated: name => {
                      if (main) main.switchContext(name);
                    }
                  }
                }

                NText {
                  visible: (main?.contexts ?? []).length === 0
                  text: pluginApi?.tr("panel.noContexts")
                  pointSize: Style.fontSizeS
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                  Layout.topMargin: Style.marginS
                  Layout.bottomMargin: Style.marginS
                }
              }
            }
          }

          NDivider { Layout.fillWidth: true }

          // Namespace switcher
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NText {
              text: pluginApi?.tr("panel.namespace")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              Layout.minimumWidth: Math.round(70 * Style.uiScaleRatio)
              Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              // Dropdown toggle button
              NButton {
                id: nsDropdownBtn
                Layout.fillWidth: true
                text: (main?.activeNamespace ?? "") !== ""
                  ? main.activeNamespace
                  : pluginApi?.tr("panel.noNamespaces")
                backgroundColor: Color.mSurfaceVariant
                textColor: Color.mOnSurface
                onClicked: {
                  nsDropdown.visible = !nsDropdown.visible;
                  if (nsDropdown.visible) {
                    root.nsFilteredListCache = root.nsFilteredList;
                    Qt.callLater(function() {
                      if (nsSearchInput.inputItem) nsSearchInput.inputItem.forceActiveFocus();
                    });
                   } else {
                    nsSearchInput.clearSearch();
                  }
                }
              }

              // Dropdown (search + list) — same structure as context switcher
              ColumnLayout {
                id: nsDropdown
                visible: false
                Layout.fillWidth: true
                spacing: Style.marginS

                NTextInput {
                  id: nsSearchInput
                  Layout.fillWidth: true
                  placeholderText: pluginApi?.tr("panel.nsSearch")
                  onTextChanged: {
                    root.nsFilterText = text;
                    root.nsHighlightIndex = 0;
                  }
                  function clearSearch() {
                    root.nsFilterText = "";
                    root.nsHighlightIndex = 0;
                    text = "";
                  }
                  Keys.onUpPressed: {
                    root.nsHighlightIndex = Math.max(0, root.nsHighlightIndex - 1);
                  }
                  Keys.onDownPressed: {
                    var max = root.nsFilteredList.length - 1;
                    root.nsHighlightIndex = Math.min(max, root.nsHighlightIndex + 1);
                  }
                  Keys.onReturnPressed: root.nsSelectHighlighted()
                  Keys.onEnterPressed: root.nsSelectHighlighted()
                  Keys.onEscapePressed: {
                    nsDropdown.visible = false;
                    nsSearchInput.clearSearch();
                  }
                }

                NScrollView {
                  id: nsListScroll
                  Layout.fillWidth: true
                  Layout.preferredHeight: {
                    var filtered = root.nsFilteredListCache;
                    var count = filtered.length;
                    if (count === 0) return Math.round(32 * Style.uiScaleRatio);
                    var rowH = nsListColumn.children.length > 0
                      ? nsListColumn.children[0].implicitHeight
                      : Math.round((Style.fontSizeM + Style.marginS * 2) * Style.uiScaleRatio + 8);
                    return Math.min(count, 4) * rowH;
                  }
                  horizontalPolicy: ScrollBar.AlwaysOff
                  verticalPolicy: root.nsFilteredListCache.length > 4 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

                  HoverHandler {
                    onHoveredChanged: root.nsListHovered = hovered
                  }

                  ColumnLayout {
                    id: nsListColumn
                    width: nsListScroll.availableWidth
                    spacing: 0

                    Repeater {
                      model: root.nsFilteredListCache
                      delegate: ContextRow {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        pluginApi: root.pluginApi
                        contextName: modelData
                        isActive: modelData === (main?.activeNamespace ?? "")
                        highlighted: index === root.nsHighlightIndex
                        onActivated: name => {
                          nsDropdown.visible = false;
                          nsSearchInput.clearSearch();
                          if (main) main.switchNamespace(name);
                        }
                      }
                    }

                    NText {
                      visible: root.nsFilteredListCache.length === 0
                      text: pluginApi?.tr("panel.noNamespaces")
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurfaceVariant
                      Layout.alignment: Qt.AlignHCenter
                      Layout.topMargin: Style.marginS
                      Layout.bottomMargin: Style.marginS
                    }
                  }
                }
              }
            }
          }

        }
      }

      // ═══════════════════════════════════════════════════════════
      // TAB BAR
      // ═══════════════════════════════════════════════════════════
      NScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: tabBar.implicitHeight + Style.marginS
        verticalPolicy: ScrollBar.AlwaysOff
        horizontalPolicy: ScrollBar.AsNeeded
        clip: true
        reserveScrollbarSpace: true

        NTabBar {
          id: tabBar
          currentIndex: root.activeTab
          onCurrentIndexChanged: root.activeTab = currentIndex

          Repeater {
            model: root.tabs
            delegate: NTabButton {
              required property var modelData
              required property int index
              tabIndex: index
              checked: root.activeTab === index
              text: modelData.label
            }
          }
        }
      }

      // ═══════════════════════════════════════════════════════════
      // RESOURCES LIST
      // ═══════════════════════════════════════════════════════════
      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // Delete confirmation overlay
        DeleteConfirm {
          anchors.fill: parent
          anchors.margins: Style.marginM
          visible: root.showDeleteConfirm
          z: 10
          pluginApi: root.pluginApi
          resourceKind: root.deleteKind
          resourceName: root.deleteName
          onConfirmed: (kind, name) => {
            root.showDeleteConfirm = false;
            if (main) main.deleteResource(kind, name);
          }
          onCancelled: root.showDeleteConfirm = false
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginS
          spacing: 0
          visible: !root.showDeleteConfirm

          // Loading indicator
          Item {
            visible: main?.loading ?? false
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(40 * Style.uiScaleRatio)

            NBusyIndicator {
              anchors.centerIn: parent
              running: main?.loading ?? false
            }
          }

          // Error state
          NText {
            visible: (main?.hasError ?? false) && !(main?.loading ?? false)
            text: pluginApi?.tr("panel.error")
            pointSize: Style.fontSizeM
            color: Color.mError
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Style.marginL
          }

          // Resource list
          NScrollView {
            id: resourceScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            horizontalPolicy: ScrollBar.AlwaysOff
            verticalPolicy: ScrollBar.AsNeeded
            visible: !(main?.loading ?? false) && !(main?.hasError ?? false)

            ColumnLayout {
              id: resourceList
              width: resourceScroll.availableWidth
              spacing: 0

              Repeater {
                model: root.currentResources()
                delegate: ResourceRow {
                  required property var modelData
                  required property int index
                  Layout.fillWidth: true
                  pluginApi: root.pluginApi
                  resourceName: modelData.name
                  ready: modelData.ready ?? ""
                  status: modelData.status ?? ""
                  resourceKind: root.tabs[root.activeTab]?.kind ?? ""
                  canLogs: root.activeTab === 0
                  canRestart: root.activeTab === 1 || root.activeTab === 2
                  rowColor: index % 2 === 1 ? Qt.alpha(Color.mOnSurface, 0.03) : "transparent"
                  onCopyRequested: name => root.handleCopy(name)
                  onDescribeRequested: (kind, name) => root.handleDescribe(kind, name)
                  onLogsRequested: name => root.handleLogs(name)
                  onDeleteRequested: (kind, name) => root.handleDelete(kind, name)
                  onRestartRequested: (kind, name) => root.handleRestart(kind, name)
                }
              }

              // Empty state
              Item {
                visible: root.currentResources().length === 0 && !(main?.loading ?? false)
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(80 * Style.uiScaleRatio)

                NText {
                  anchors.centerIn: parent
                  text: pluginApi?.tr("panel.noResources")
                  pointSize: Style.fontSizeM
                  color: Color.mOnSurfaceVariant
                }
              }
            }
          }
        }
      }
    }
  }
}
