import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null

  property bool isBeforeStart: false
  property int daysUntilStart: 0
  property int currentDay: 1
  property int totalDays: 196
  property int currentWeek: 1
  property int totalWeeks: 28
  property int currentMonth: 1
  property int totalMonths: 7
  property real pctProgress: 0.5
  property string blockName: "Block I: Vector Search Engine Spine"
  property string blockTarget: "v1.2-vs-spine-complete"
  property string monthTheme: "Month 1: Scalar & SIMD Distance Kernels"
  property string activeBook: "Zen and the Art of Motorcycle Maintenance"
  property string nextPenrose: "Ch 1: The Roots of Science"
  property var nextEssay: ({})
  property var nextPaper: ({})

  readonly property real _width: Math.round(400 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["python3", "/home/ahmed/.config/noctalia/plugins/goals-progress/fetch.py"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var d = JSON.parse(String(proc.stdout.text || "{}"));
        if (d.ok) {
          root.isBeforeStart = !!d.is_before_start;
          root.daysUntilStart = d.days_until_start || 0;
          root.currentDay = d.current_day || 1;
          root.totalDays = d.total_days || 196;
          root.currentWeek = d.current_week || 1;
          root.totalWeeks = d.total_weeks || 28;
          root.currentMonth = d.current_month || 1;
          root.totalMonths = d.total_months || 7;
          root.pctProgress = d.pct_progress || 0.5;
          root.blockName = d.block_name || "";
          root.blockTarget = d.block_target || "";
          root.monthTheme = d.month_theme || "";
          root.activeBook = d.active_book || "";
          root.nextPenrose = d.next_penrose || "";
          root.nextEssay = d.next_essay || ({});
          root.nextPaper = d.next_paper || ({});
        }
      } catch (e) {
        console.warn("goals-progress parse error:", e);
      }
    }
  }

  Process {
    id: launchProc
  }

  function openFile(path) {
    if (!path) return;
    var uri = "obsidian://open?path=" + encodeURIComponent(path);
    Qt.openUrlExternally(uri);
    launchProc.command = ["xdg-open", uri];
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
        icon: "target"
        color: Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        RowLayout {
          spacing: Math.round(Style.marginXS * widgetScale)
          NText {
            text: "28-Week Specialization"
            color: Color.mOnSurface
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeM * widgetScale
          }

          Rectangle {
            visible: root.isBeforeStart
            color: Color.mTertiaryContainer
            radius: Math.round(4 * widgetScale)
            implicitWidth: Math.round(startChipText.implicitWidth + 8 * widgetScale)
            implicitHeight: Math.round(startChipText.implicitHeight + 4 * widgetScale)
            NText {
              id: startChipText
              anchors.centerIn: parent
              text: "Starts in " + root.daysUntilStart + "d"
              color: Color.mOnTertiaryContainer
              pointSize: Style.fontSizeXS * widgetScale
              font.weight: Style.fontWeightBold
            }
          }
        }

        NText {
          text: root.blockName
          color: Color.mPrimary
          font.weight: Style.fontWeightMedium
          pointSize: Style.fontSizeXS * widgetScale
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }
    }

    // Progress Bar Section
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Math.round(4 * widgetScale)

      RowLayout {
        Layout.fillWidth: true
        NText {
          text: root.isBeforeStart ? "Starts Tomorrow · Day 0 / " + root.totalDays + " (0%)" : ("Day " + root.currentDay + " / " + root.totalDays + " (" + root.pctProgress + "%)")
          color: Color.mOnSurface
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeS * widgetScale
        }
        Item { Layout.fillWidth: true }
        NText {
          text: "Week " + root.currentWeek + " / " + root.totalWeeks + " · Month " + root.currentMonth + " / " + root.totalMonths
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS * widgetScale
        }
      }

      // Progress Track
      Rectangle {
        Layout.fillWidth: true
        height: Math.round(8 * widgetScale)
        radius: Math.round(4 * widgetScale)
        color: Color.mSurfaceVariant

        Rectangle {
          height: parent.height
          width: Math.max(Math.round(8 * widgetScale), parent.width * Math.min(1.0, root.pctProgress / 100.0))
          radius: Math.round(4 * widgetScale)
          color: Color.mPrimary

          Behavior on width {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
          }
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

    // Milestones Header
    NText {
      text: "NEXT LANDINGS & READING"
      color: Color.mPrimary
      font.weight: Style.fontWeightBold
      pointSize: Style.fontSizeXS * widgetScale
    }

    // Next Technical Essay Card
    Rectangle {
      Layout.fillWidth: true
      color: Color.mSurfaceVariant
      radius: Math.round(6 * widgetScale)
      implicitHeight: essayCol.implicitHeight + Math.round(12 * widgetScale)

      ColumnLayout {
        id: essayCol
        anchors.fill: parent
        anchors.margins: Math.round(8 * widgetScale)
        spacing: Math.round(2 * widgetScale)

        RowLayout {
          Layout.fillWidth: true
          spacing: Math.round(4 * widgetScale)
          NIcon {
            icon: "edit"
            color: Color.mTertiary
            pointSize: Style.fontSizeS * widgetScale
          }
          NText {
            text: "Essay " + (root.nextEssay.week || "1") + " · " + (root.nextEssay.date_str || "Friday")
            color: Color.mTertiary
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeXS * widgetScale
          }
        }

        NText {
          text: root.nextEssay.title || "Weekly Technical Lab Note"
          color: Color.mOnSurface
          pointSize: Style.fontSizeXS * widgetScale
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }
    }

    // Next Research Paper Card
    Rectangle {
      Layout.fillWidth: true
      color: Color.mSurfaceVariant
      radius: Math.round(6 * widgetScale)
      implicitHeight: paperCol.implicitHeight + Math.round(12 * widgetScale)

      ColumnLayout {
        id: paperCol
        anchors.fill: parent
        anchors.margins: Math.round(8 * widgetScale)
        spacing: Math.round(2 * widgetScale)

        RowLayout {
          Layout.fillWidth: true
          spacing: Math.round(4 * widgetScale)
          NIcon {
            icon: "file-text"
            color: Color.mSecondary
            pointSize: Style.fontSizeS * widgetScale
          }
          NText {
            text: "Paper " + (root.nextPaper.month || "1") + " · Due " + (root.nextPaper.due_str || "End of Month")
            color: Color.mSecondary
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeXS * widgetScale
          }
          Item { Layout.fillWidth: true }
          NText {
            text: (root.nextPaper.days_left !== undefined ? root.nextPaper.days_left : "") + "d left"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS * widgetScale
          }
        }

        NText {
          text: root.nextPaper.topic || "Monthly Research Paper"
          color: Color.mOnSurface
          pointSize: Style.fontSizeXS * widgetScale
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }
    }

    // Active Evening Reading & Sunday Penrose Card
    Rectangle {
      Layout.fillWidth: true
      color: Color.mSurfaceVariant
      opacity: 0.9
      radius: Math.round(6 * widgetScale)
      implicitHeight: readCol.implicitHeight + Math.round(12 * widgetScale)

      ColumnLayout {
        id: readCol
        anchors.fill: parent
        anchors.margins: Math.round(8 * widgetScale)
        spacing: Math.round(3 * widgetScale)

        RowLayout {
          spacing: Math.round(5 * widgetScale)
          Layout.fillWidth: true
          NIcon {
            icon: "book-open"
            color: Color.mPrimary
            pointSize: Style.fontSizeS * widgetScale
          }
          NText {
            text: "Evening Reading:"
            color: Color.mPrimary
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeXS * widgetScale
          }
          NText {
            text: root.activeBook
            color: Color.mOnSurface
            pointSize: Style.fontSizeXS * widgetScale
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        RowLayout {
          spacing: Math.round(5 * widgetScale)
          Layout.fillWidth: true
          NIcon {
            icon: "globe"
            color: Color.mTertiary
            pointSize: Style.fontSizeS * widgetScale
          }
          NText {
            text: "Penrose Sunday:"
            color: Color.mTertiary
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeXS * widgetScale
          }
          NText {
            text: root.nextPenrose
            color: Color.mOnSurface
            pointSize: Style.fontSizeXS * widgetScale
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }
    }

    // Month Theme Badge
    Rectangle {
      Layout.fillWidth: true
      color: "transparent"
      border.color: Color.mOutlineVariant
      border.width: 1
      radius: Math.round(6 * widgetScale)
      implicitHeight: monthThemeText.implicitHeight + Math.round(10 * widgetScale)

      NText {
        id: monthThemeText
        anchors.fill: parent
        anchors.margins: Math.round(6 * widgetScale)
        text: "📌 " + root.monthTheme
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS * widgetScale
        elide: Text.ElideRight
      }
    }

    // Action Launchers
    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginS * widgetScale)

      Rectangle {
        Layout.fillWidth: true
        height: Math.round(28 * widgetScale)
        color: roadHover.containsMouse ? Color.mPrimary : Color.mPrimaryContainer
        radius: Math.round(6 * widgetScale)

        MouseArea {
          id: roadHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openFile("/home/ahmed/personal/goals/curriculum/roadmap.md")

          RowLayout {
            anchors.centerIn: parent
            spacing: Math.round(4 * widgetScale)
            NIcon {
              icon: "map"
              color: roadHover.containsMouse ? Color.mOnPrimary : Color.mOnPrimaryContainer
              pointSize: Style.fontSizeS * widgetScale
            }
            NText {
              text: "Roadmap"
              color: roadHover.containsMouse ? Color.mOnPrimary : Color.mOnPrimaryContainer
              font.weight: Style.fontWeightBold
              pointSize: Style.fontSizeXS * widgetScale
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: Math.round(28 * widgetScale)
        color: currHover.containsMouse ? Color.mSecondary : Color.mSecondaryContainer
        radius: Math.round(6 * widgetScale)

        MouseArea {
          id: currHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openFile("/home/ahmed/personal/goals/curriculum/README.md")

          RowLayout {
            anchors.centerIn: parent
            spacing: Math.round(4 * widgetScale)
            NIcon {
              icon: "list"
              color: currHover.containsMouse ? Color.mOnSecondary : Color.mOnSecondaryContainer
              pointSize: Style.fontSizeS * widgetScale
            }
            NText {
              text: "Curriculum"
              color: currHover.containsMouse ? Color.mOnSecondary : Color.mOnSecondaryContainer
              font.weight: Style.fontWeightBold
              pointSize: Style.fontSizeXS * widgetScale
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: Math.round(28 * widgetScale)
        color: readPlanHover.containsMouse ? Color.mTertiary : Color.mTertiaryContainer
        radius: Math.round(6 * widgetScale)

        MouseArea {
          id: readPlanHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openFile("/home/ahmed/personal/goals/curriculum/evening_reading_plan.md")

          RowLayout {
            anchors.centerIn: parent
            spacing: Math.round(4 * widgetScale)
            NIcon {
              icon: "book"
              color: readPlanHover.containsMouse ? Color.mOnTertiary : Color.mOnTertiaryContainer
              pointSize: Style.fontSizeS * widgetScale
            }
            NText {
              text: "Reading"
              color: readPlanHover.containsMouse ? Color.mOnTertiary : Color.mOnTertiaryContainer
              font.weight: Style.fontWeightBold
              pointSize: Style.fontSizeXS * widgetScale
            }
          }
        }
      }
    }
  }
}
