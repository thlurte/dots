import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property string resourceName: ""
  property string ready: ""
  property string status: ""
  property string resourceKind: ""
  property bool canLogs: false
  property bool canRestart: false
  property color rowColor: "transparent"

  signal copyRequested(string name)
  signal describeRequested(string kind, string name)
  signal logsRequested(string name)
  signal deleteRequested(string kind, string name)
  signal restartRequested(string kind, string name)

  property bool expanded: false

  implicitHeight: mainRow.implicitHeight + (expanded ? actionsBar.implicitHeight + Style.marginS : 0)

  Rectangle {
    anchors.fill: parent
    color: root.rowColor
  }

  readonly property color statusColor: {
    var s = root.status.toLowerCase();
    if (s === "running" || s === "active" || s === "bound") return Color.mTertiary;
    if (s === "pending" || s === "containercreating") return Color.mWarning;
    if (s === "error" || s === "crashloopbackoff" || s === "oomkilled" ||
        s === "failed" || s === "imagepullbackoff" || s === "errimagepull") return Color.mError;
    if (s === "completed" || s === "succeeded") return Color.mOnSurfaceVariant;
    return Color.mOnSurfaceVariant;
  }

  readonly property string statusIcon: {
    var s = root.status.toLowerCase();
    if (s === "running" || s === "active" || s === "bound") return "circle-check";
    if (s === "pending" || s === "containercreating") return "clock";
    if (s === "error" || s === "crashloopbackoff" || s === "oomkilled" ||
        s === "failed" || s === "imagepullbackoff" || s === "errimagepull") return "alert-circle";
    if (s === "completed" || s === "succeeded") return "circle-check-filled";
    return "circle-dashed";
  }

  // Main row — click to expand
  RowLayout {
    id: mainRow
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      leftMargin: Style.marginM
      rightMargin: Style.marginS
    }
    spacing: Style.marginS

    NIcon {
      visible: root.status !== ""
      icon: root.statusIcon
      pointSize: Style.fontSizeL
      color: root.statusColor
      Layout.alignment: Qt.AlignVCenter
    }

    NText {
      text: root.resourceName
      pointSize: Style.fontSizeL
      color: root.expanded ? Color.mPrimary : Color.mOnSurface
      elide: Text.ElideRight
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
    }

    NText {
      visible: root.ready !== ""
      text: root.ready
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      Layout.alignment: Qt.AlignVCenter
    }

    NIcon {
      icon: root.expanded ? "chevron-up" : "chevron-down"
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      Layout.alignment: Qt.AlignVCenter
    }
  }

  // Expanded actions bar
  RowLayout {
    id: actionsBar
    visible: root.expanded
    anchors {
      left: parent.left
      right: parent.right
      top: mainRow.bottom
      topMargin: Style.marginS
      leftMargin: Style.marginS
      rightMargin: Style.marginS
    }
    spacing: Style.marginS

    NButton {
      icon: "copy"
      text: pluginApi?.tr("actions.copyName")
      fontSize: Style.fontSizeS
      iconSize: Style.fontSizeS
      Layout.fillWidth: true
      onClicked: {
        root.expanded = false;
        root.copyRequested(root.resourceName);
      }
    }

    NButton {
      icon: "info-circle"
      text: pluginApi?.tr("actions.describe")
      fontSize: Style.fontSizeS
      iconSize: Style.fontSizeS
      Layout.fillWidth: true
      onClicked: {
        root.expanded = false;
        root.describeRequested(root.resourceKind, root.resourceName);
      }
    }

    NButton {
      visible: root.canLogs
      icon: "terminal-2"
      text: pluginApi?.tr("actions.logs")
      fontSize: Style.fontSizeS
      iconSize: Style.fontSizeS
      Layout.fillWidth: true
      onClicked: {
        root.expanded = false;
        root.logsRequested(root.resourceName);
      }
    }

    NButton {
      visible: root.canRestart
      icon: "refresh"
      text: pluginApi?.tr("actions.restart")
      fontSize: Style.fontSizeS
      iconSize: Style.fontSizeS
      Layout.fillWidth: true
      onClicked: {
        root.expanded = false;
        root.restartRequested(root.resourceKind, root.resourceName);
      }
    }

    NButton {
      icon: "trash"
      text: pluginApi?.tr("actions.delete")
      fontSize: Style.fontSizeS
      iconSize: Style.fontSizeS
      Layout.fillWidth: true
      backgroundColor: Qt.alpha(Color.mError, 0.15)
      textColor: Color.mError
      onClicked: {
        root.expanded = false;
        root.deleteRequested(root.resourceKind, root.resourceName);
      }
    }
  }

  MouseArea {
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      bottom: root.expanded ? actionsBar.top : parent.bottom
    }
    cursorShape: Qt.PointingHandCursor
    onClicked: root.expanded = !root.expanded
  }
}
