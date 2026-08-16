import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var items: []
  property int feedCount: 0
  property int totalCount: 0
  property string status: ""
  property var errors: []
  property bool expanded: false

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property int refreshSeconds: cfg.refreshSeconds ?? 300
  readonly property int previewItems: cfg.previewItems ?? 5
  readonly property real _width: Math.round((expanded ? 460 : 360) * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)
  readonly property real _listMax: Math.round((expanded ? 520 : 220) * widgetScale)
  readonly property int shownCount: expanded ? root.items.length : Math.min(root.items.length, root.previewItems)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  function openLink(link) {
    if (link)
      Qt.openUrlExternally(link);
  }

  Process {
    id: proc
    command: ["python3", "/home/ahmed/.config/noctalia/plugins/rss-feeds/fetch.py"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var data = JSON.parse(String(proc.stdout.text || "{}"));
        root.items = data.items || [];
        root.feedCount = data.feeds || 0;
        root.totalCount = data.count || root.items.length;
        root.errors = data.errors || [];
        root.status = root.errors.length ? "partial" : "ok";
      } catch (e) {
        root.status = "error";
        root.errors = ["parse failed"];
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: Math.max(60, root.refreshSeconds) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: proc.running = true
  }

  ColumnLayout {
    id: contentCol
    anchors.fill: parent
    anchors.margins: root._pad
    spacing: Math.round(Style.marginXS * widgetScale)

    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginS * widgetScale)

      MouseArea {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded

        RowLayout {
          id: headerRow
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Math.round(Style.marginS * widgetScale)

          NIcon {
            icon: "rss"
            color: root.status === "error" ? Color.mError : Color.mPrimary
            pointSize: Style.fontSizeXL * widgetScale
          }

          NText {
            text: "RSS"
            color: Color.mOnSurface
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL * widgetScale
            Layout.fillWidth: true
          }

          NText {
            text: root.shownCount + "/" + root.items.length
            color: Color.mPrimary
            font.family: Settings.data.ui.fontFixed
            pointSize: Style.fontSizeS * widgetScale
          }
        }
      }

      NIconButton {
        icon: root.expanded ? "chevron-up" : "chevron-down"
        tooltipText: root.expanded ? "Collapse" : "Show all articles"
        baseSize: Style.baseWidgetSize * 0.7 * widgetScale
        onClicked: root.expanded = !root.expanded
      }

      NIconButton {
        icon: "refresh"
        tooltipText: "Refresh feeds"
        baseSize: Style.baseWidgetSize * 0.7 * widgetScale
        onClicked: proc.running = true
      }
    }

    Flickable {
      id: listFlick
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(listCol.implicitHeight, root._listMax)
      contentWidth: width
      contentHeight: listCol.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: listCol.implicitHeight > height

      ColumnLayout {
        id: listCol
        width: listFlick.width
        spacing: Math.round((root.expanded ? Style.marginS : Style.marginXS) * widgetScale)

        Repeater {
          model: root.shownCount

          delegate: MouseArea {
            id: itemArea
            required property int index
            Layout.fillWidth: true
            implicitHeight: row.implicitHeight
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: root.openLink(root.items[index]?.link || "")

            Rectangle {
              anchors.fill: parent
              anchors.margins: root.expanded ? -Math.round(4 * widgetScale) : 0
              radius: Style.radiusS
              color: itemArea.containsMouse ? Color.mSurfaceVariant : Color.transparent
              opacity: 0.55
              visible: root.expanded
            }

            ColumnLayout {
              id: row
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: Math.round(2 * widgetScale)

              RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(Style.marginS * widgetScale)

                NText {
                  text: root.items[index]?.feed || ""
                  color: Color.mPrimary
                  pointSize: Style.fontSizeXS * widgetScale
                  Layout.preferredWidth: Math.round(72 * widgetScale)
                  elide: Text.ElideRight
                }

                NText {
                  visible: !root.expanded
                  text: root.items[index]?.title || ""
                  color: itemArea.containsMouse ? Color.mPrimary : Color.mOnSurface
                  pointSize: Style.fontSizeS * widgetScale
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                  wrapMode: Text.NoWrap
                }

                NText {
                  text: root.items[index]?.age || ""
                  color: Color.mOnSurfaceVariant
                  font.family: Settings.data.ui.fontFixed
                  pointSize: Style.fontSizeXS * widgetScale
                }
              }

              NText {
                visible: root.expanded
                text: root.items[index]?.title || ""
                color: itemArea.containsMouse ? Color.mPrimary : Color.mOnSurface
                pointSize: Style.fontSizeS * widgetScale
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      visible: !root.expanded && root.items.length > root.previewItems

      NText {
        text: "+" + (root.items.length - root.previewItems) + " more — click to expand"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS * widgetScale
        Layout.fillWidth: true

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.expanded = true
        }
      }
    }

    NText {
      visible: root.expanded
      text: "Click a title to open · click RSS to collapse"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS * widgetScale
      Layout.fillWidth: true
    }

    NText {
      visible: root.items.length === 0
      text: root.errors.length ? root.errors[0] : "No headlines"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }
  }
}
