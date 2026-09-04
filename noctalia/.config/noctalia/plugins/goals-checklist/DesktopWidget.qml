import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null

  property int dayNum: 1
  property string dayTitle: "Day 001"
  property int weekNum: 1
  property int monthNum: 1
  property string weekTheme: "Vector Search & AI Systems"
  property bool isBeforeStart: false
  property int daysUntilStart: 0
  property string filePath: ""
  property string weekFile: ""
  property string readingFile: ""
  property bool isWeekend: false
  property var tasks: []
  property var slots: []
  property string mathTopic: ""
  property string readingTopic: ""
  property string codeTopic: ""

  readonly property real _width: Math.round(400 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["python3", "/home/ahmed/.config/noctalia/plugins/goals-checklist/fetch.py"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var d = JSON.parse(String(proc.stdout.text || "{}"));
        if (d.ok) {
          root.dayNum = d.day_num || 1;
          root.dayTitle = d.day_title || "Day 001";
          root.weekNum = d.week_num || 1;
          root.monthNum = d.month_num || 1;
          root.weekTheme = d.week_theme || "";
          root.isBeforeStart = !!d.is_before_start;
          root.daysUntilStart = d.days_until_start || 0;
          root.filePath = d.file_path || "";
          root.weekFile = d.week_file || "";
          root.readingFile = d.reading_file || "";
          root.isWeekend = !!d.is_weekend;
          root.tasks = d.tasks || [];
          root.slots = d.slots || [];
          root.mathTopic = d.math_topic || "";
          root.readingTopic = d.reading_topic || "";
          root.codeTopic = d.code_topic || "";
        }
      } catch (e) {
        console.warn("goals-checklist parse error:", e);
      }
    }
  }

  Process {
    id: toggleProc
    stdout: StdioCollector {}
    onExited: {
      proc.running = true;
    }
  }

  Process {
    id: launchProc
  }

  function toggleTask(taskText) {
    if (!root.weekFile) return;
    toggleProc.command = ["python3", "/home/ahmed/.config/noctalia/plugins/goals-checklist/fetch.py", "--toggle", root.weekFile, taskText];
    toggleProc.running = true;
  }

  function openFile(path) {
    if (!path) return;
    var uri = "obsidian://open?path=" + encodeURIComponent(path);
    Qt.openUrlExternally(uri);
    launchProc.command = ["xdg-open", uri];
    launchProc.running = true;
  }

  function openTerminal(dir) {
    launchProc.command = ["kitty", "--directory", dir || "/home/ahmed/personal/goals"];
    launchProc.running = true;
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: proc.running = true
  }

  ColumnLayout {
    id: contentCol
    anchors.fill: parent
    anchors.margins: root._pad
    spacing: Math.round(Style.marginS * widgetScale)

    // Header
    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginS * widgetScale)

      NIcon {
        icon: "checklist"
        color: Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        RowLayout {
          spacing: Math.round(Style.marginXS * widgetScale)
          NText {
            text: root.dayTitle
            color: Color.mOnSurface
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeM * widgetScale
          }

          Rectangle {
            visible: root.isBeforeStart
            color: Color.mSecondaryContainer
            radius: Math.round(4 * widgetScale)
            implicitWidth: Math.round(startText.implicitWidth + 8 * widgetScale)
            implicitHeight: Math.round(startText.implicitHeight + 4 * widgetScale)
            NText {
              id: startText
              anchors.centerIn: parent
              text: "Starts in " + root.daysUntilStart + "d"
              color: Color.mOnSecondaryContainer
              pointSize: Style.fontSizeXS * widgetScale
              font.weight: Style.fontWeightBold
            }
          }
        }

        NText {
          text: root.weekTheme
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS * widgetScale
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }
    }

    // Divider
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: Color.mOutlineVariant
      opacity: 0.4
    }

    // Daily Operational Cadence Card
    Rectangle {
      Layout.fillWidth: true
      color: Color.mSurfaceVariant
      opacity: 0.8
      radius: Math.round(6 * widgetScale)
      implicitHeight: pillarCol.implicitHeight + Math.round(14 * widgetScale)

      ColumnLayout {
        id: pillarCol
        anchors.fill: parent
        anchors.margins: Math.round(8 * widgetScale)
        spacing: Math.round(4 * widgetScale)

        Repeater {
          model: root.slots
          delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: Math.round(6 * widgetScale)

            Rectangle {
              color: Color.mSurface
              radius: Math.round(3 * widgetScale)
              implicitWidth: Math.round(timeTxt.implicitWidth + 8 * widgetScale)
              implicitHeight: Math.round(timeTxt.implicitHeight + 3 * widgetScale)
              NText {
                id: timeTxt
                anchors.centerIn: parent
                text: modelData.time
                color: Color.mPrimary
                font.weight: Style.fontWeightBold
                pointSize: Style.fontSizeXS * 0.9 * widgetScale
              }
            }

            NText {
              text: modelData.label + ":"
              color: Color.mOnSurface
              pointSize: Style.fontSizeXS * widgetScale
              font.weight: Style.fontWeightBold
            }

            NText {
              text: modelData.desc
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS * widgetScale
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }
        }
      }
    }

    // Tasks Header
    NText {
      text: "TODAY'S DELIVERABLES"
      color: Color.mPrimary
      font.weight: Style.fontWeightBold
      pointSize: Style.fontSizeXS * widgetScale
    }

    // Tasks list
    Repeater {
      model: root.tasks
      delegate: Rectangle {
        required property var modelData
        required property int index

        Layout.fillWidth: true
        color: modelData.checked ? Color.mSurfaceVariant : "transparent"
        radius: Math.round(6 * widgetScale)
        border.color: modelData.checked ? Color.mPrimary : Color.mOutlineVariant
        border.width: 1
        implicitHeight: taskCol.implicitHeight + Math.round(12 * widgetScale)

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggleTask(modelData.text)

          RowLayout {
            id: taskCol
            anchors.fill: parent
            anchors.margins: Math.round(6 * widgetScale)
            spacing: Math.round(Style.marginS * widgetScale)

            NIcon {
              icon: modelData.checked ? "checkbox" : "square"
              color: modelData.checked ? Color.mPrimary : Color.mOnSurfaceVariant
              pointSize: Style.fontSizeM * widgetScale
            }

            Rectangle {
              color: modelData.type === "core" ? Color.mPrimaryContainer : Color.mTertiaryContainer
              radius: Math.round(4 * widgetScale)
              implicitWidth: Math.round(tagText.implicitWidth + 8 * widgetScale)
              implicitHeight: Math.round(tagText.implicitHeight + 4 * widgetScale)
              NText {
                id: tagText
                anchors.centerIn: parent
                text: modelData.label || "Core"
                color: modelData.type === "core" ? Color.mOnPrimaryContainer : Color.mOnTertiaryContainer
                font.weight: Style.fontWeightBold
                pointSize: Style.fontSizeXS * widgetScale
              }
            }

            NText {
              Layout.fillWidth: true
              text: modelData.text
              color: modelData.checked ? Color.mOnSurfaceVariant : Color.mOnSurface
              pointSize: Style.fontSizeS * widgetScale
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }

    // Action Launchers
    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginS * widgetScale)

      Rectangle {
        Layout.fillWidth: true
        height: Math.round(28 * widgetScale)
        color: openHover.containsMouse ? Color.mPrimary : Color.mPrimaryContainer
        radius: Math.round(6 * widgetScale)

        MouseArea {
          id: openHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openFile(root.filePath || root.weekFile)

          RowLayout {
            anchors.centerIn: parent
            spacing: Math.round(4 * widgetScale)
            NIcon {
              icon: "file-text"
              color: openHover.containsMouse ? Color.mOnPrimary : Color.mOnPrimaryContainer
              pointSize: Style.fontSizeS * widgetScale
            }
            NText {
              text: "Runbook"
              color: openHover.containsMouse ? Color.mOnPrimary : Color.mOnPrimaryContainer
              font.weight: Style.fontWeightBold
              pointSize: Style.fontSizeXS * widgetScale
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: Math.round(28 * widgetScale)
        color: readHover.containsMouse ? Color.mTertiary : Color.mTertiaryContainer
        radius: Math.round(6 * widgetScale)

        MouseArea {
          id: readHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openFile(root.readingFile)

          RowLayout {
            anchors.centerIn: parent
            spacing: Math.round(4 * widgetScale)
            NIcon {
              icon: "book"
              color: readHover.containsMouse ? Color.mOnTertiary : Color.mOnTertiaryContainer
              pointSize: Style.fontSizeS * widgetScale
            }
            NText {
              text: "Reading"
              color: readHover.containsMouse ? Color.mOnTertiary : Color.mOnTertiaryContainer
              font.weight: Style.fontWeightBold
              pointSize: Style.fontSizeXS * widgetScale
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: Math.round(28 * widgetScale)
        color: labHover.containsMouse ? Color.mSecondary : Color.mSecondaryContainer
        radius: Math.round(6 * widgetScale)

        MouseArea {
          id: labHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openTerminal("/home/ahmed/personal/secan")

          RowLayout {
            anchors.centerIn: parent
            spacing: Math.round(4 * widgetScale)
            NIcon {
              icon: "cpu"
              color: labHover.containsMouse ? Color.mOnSecondary : Color.mOnSecondaryContainer
              pointSize: Style.fontSizeS * widgetScale
            }
            NText {
              text: "secan"
              color: labHover.containsMouse ? Color.mOnSecondary : Color.mOnSecondaryContainer
              font.weight: Style.fontWeightBold
              pointSize: Style.fontSizeXS * widgetScale
            }
          }
        }
      }
    }
  }
}
