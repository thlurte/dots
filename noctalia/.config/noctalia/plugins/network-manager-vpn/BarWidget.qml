import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0
    readonly property var pluginSettings: pluginApi?.pluginSettings ?? ({})
    readonly property var main: pluginApi?.mainInstance ?? ({})
    
    readonly property string screenName: screen?.name ?? ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)
    readonly property string displayMode: root.pluginSettings.displayMode ?? "onhover"
    readonly property string connectedColor: root.pluginSettings.connectedColor
    readonly property string disconnectedColor: root.pluginSettings.disconnectedColor
    readonly property var vpnList: root.main.vpnList ?? []
    readonly property real connectedCount: root.main.connectedCount ?? 0
    readonly property bool isLoading: root.main.isLoading ?? false

    implicitWidth: pill.width
    implicitHeight: pill.height
    Component.onCompleted: {
        Logger.i("NetworkManagerVPN", "Bar widget loaded");
    }

    NPopupContextMenu {
        id: contextMenu

        model: [{
            "label": pluginApi?.tr("settings.pluginSettings"),
            "action": "plugin-settings",
            "icon": "settings"
        }]
        onTriggered: (action) => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);
            if (action === "plugin-settings")
                BarService.openPluginSettings(screen, pluginApi.manifest);

        }
    }

    BarPill {
        id: pill

        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)
        autoHide: false
        text: root.connectedCount > 0 ? pluginApi?.tr("common.connected") : pluginApi?.tr("common.disconnected")
        icon: root.isLoading ? "reload" : root.connectedCount > 0 ? "shield-lock" : "shield"
        onClicked: {
            if (pluginApi)
                pluginApi.openPanel(root.screen, root);

        }
        onRightClicked: {
            if (pluginApi)
                pluginApi.closePanel(root.screen);
            PanelService.showContextMenu(contextMenu, pill, screen);
        }
        customIconColor: Color.resolveColorKeyOptional(root.connectedCount > 0 ? root.connectedColor : root.disconnectedColor)
        customTextColor: Color.resolveColorKeyOptional(root.connectedCount > 0 ? root.connectedColor : root.disconnectedColor)
        forceOpen: root.displayMode === "alwaysShow"
        forceClose: root.displayMode === "alwaysHide"
    }

}
