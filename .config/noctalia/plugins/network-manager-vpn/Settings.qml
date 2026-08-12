import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    readonly property var pluginSettings: pluginApi?.pluginSettings ?? pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

    readonly property var main: pluginApi?.mainInstance ?? null
    readonly property var vpnList: main ? main.vpnList : []
    // Local state
    property string editDisplayMode: root.pluginSettings.displayMode ?? ""
    property string editConnectedColor: root.pluginSettings.connectedColor ?? ""
    property string editDisconnectedColor: root.pluginSettings.disconnectedColor ?? ""
    property bool disableToastNotifications: root.pluginSettings?.disableToastNotifications ?? false

    property string pendingDeleteUuid: ""
    property string pendingDeleteName: ""

    readonly property var displayModeModel: [{
        "key": "onhover",
        "name": I18n.tr("display-modes.on-hover")
    }, {
        "key": "alwaysShow",
        "name": I18n.tr("display-modes.always-show")
    }, {
        "key": "alwaysHide",
        "name": I18n.tr("display-modes.always-hide")
    }]

    function saveSettings() {
        pluginApi.pluginSettings.displayMode = root.editDisplayMode;
        pluginApi.pluginSettings.connectedColor = root.editConnectedColor;
        pluginApi.pluginSettings.disconnectedColor = root.editDisconnectedColor;
        pluginApi.pluginSettings.disableToastNotifications = root.disableToastNotifications;
        pluginApi.saveSettings();

        Logger.i("NetworkManagerVpn", "Settings saved successfully");
    }

    NComboBox {
        label: I18n.tr("common.display-mode")
        description: I18n.tr("bar.volume.display-mode-description")
        minimumWidth: 200
        model: root.displayModeModel
        currentKey: root.editDisplayMode
        onSelected: (key) => {
            root.editDisplayMode = key;
        }
    }

    NColorChoice {
        label: pluginApi?.tr("settings.connectedColor")
        description: pluginApi?.tr("settings.connectedColorDescription")
        currentKey: root.editConnectedColor
        onSelected: (key) => {
            root.editConnectedColor = key;
        }
    }

    NColorChoice {
        label: pluginApi?.tr("settings.disconnectedColor")
        description: pluginApi?.tr("settings.disconnectedColorDescription")
        currentKey: root.editDisconnectedColor
        onSelected: (key) => {
            root.editDisconnectedColor = key;
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.disableToastNotifications")
        description: pluginApi?.tr("settings.disableToastNotificationsDescription")
        checked: root.disableToastNotifications
        onToggled: checked => {
            root.disableToastNotifications = checked;
        }
    }

    NBox {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        Layout.preferredHeight: Math.round(vpnSection.implicitHeight + Style.marginL * 2)

        ColumnLayout {
            id: vpnSection

            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NLabel {
                label: pluginApi?.tr("settings.vpnConnections")
                Layout.fillWidth: true
            }

            NText {
                visible: root.vpnList.length === 0
                text: pluginApi?.tr("settings.noVpnConnections")
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                Layout.leftMargin: Style.marginXS
            }

            Repeater {
                model: root.vpnList

                NBox {
                    id: vpnRow

                    readonly property bool confirmingDelete: root.pendingDeleteUuid === modelData.uuid

                    Layout.fillWidth: true
                    Layout.leftMargin: Style.marginXS
                    Layout.rightMargin: Style.marginXS
                    implicitHeight: Math.round(rowContent.implicitHeight + Style.marginL)
                    color: vpnRow.confirmingDelete ? Qt.alpha(Color.mError, 0.12) : Color.mSurface

                    ColumnLayout {
                        id: rowContent

                        anchors.fill: parent
                        anchors.leftMargin: Style.marginM
                        anchors.rightMargin: Style.marginM
                        anchors.topMargin: Style.marginS
                        anchors.bottomMargin: Style.marginS
                        spacing: Style.marginS

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginS

                            NIcon {
                                icon: "router"
                                pointSize: Style.fontSizeXXL
                                color: modelData.connected ? Color.mPrimary : Color.mOnSurfaceVariant
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                NText {
                                    text: modelData.name
                                    pointSize: Style.fontSizeM
                                    font.weight: Style.fontWeightMedium
                                    color: Color.mOnSurface
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                NText {
                                    text: modelData.type || "vpn"
                                    pointSize: Style.fontSizeXXS
                                    color: Color.mOnSurfaceVariant
                                }

                            }

                            NIconButton {
                                visible: !vpnRow.confirmingDelete
                                icon: "edit"
                                tooltipText: pluginApi?.tr("common.edit")
                                baseSize: Style.baseWidgetSize * 0.75
                                onClicked: {
                                    main.editConnection(modelData.uuid);
                                    close();
                                }
                            }

                            NIconButton {
                                visible: !vpnRow.confirmingDelete
                                icon: "trash-x"
                                tooltipText: pluginApi?.tr("common.delete")
                                baseSize: Style.baseWidgetSize * 0.75
                                onClicked: {
                                    root.pendingDeleteUuid = modelData.uuid;
                                    root.pendingDeleteName = modelData.name;
                                }
                            }

                            NButton {
                                visible: vpnRow.confirmingDelete
                                text: pluginApi?.tr("common.delete")
                                fontSize: Style.fontSizeXS
                                backgroundColor: Color.mError
                                outlined: false
                                onClicked: {
                                    main.removeConnection(root.pendingDeleteUuid);
                                    root.pendingDeleteUuid = "";
                                    root.pendingDeleteName = "";
                                }
                            }

                            NButton {
                                visible: vpnRow.confirmingDelete
                                text: pluginApi?.tr("common.cancel")
                                fontSize: Style.fontSizeXS
                                outlined: true
                                onClicked: {
                                    root.pendingDeleteUuid = "";
                                    root.pendingDeleteName = "";
                                }
                            }

                        }

                    }

                }

            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Style.marginXS
                spacing: Style.marginS

                Item {
                    Layout.fillWidth: true
                }

                NButton {
                    text: pluginApi?.tr("settings.addVpn")
                    icon: "add"
                    fontSize: Style.fontSizeS
                    outlined: true
                    onClicked: {
                        main.addConnection("vpn");
                        close();
                    }
                }

                NButton {
                    text: pluginApi?.tr("settings.addWireguard")
                    icon: "add"
                    fontSize: Style.fontSizeS
                    outlined: true
                    onClicked: {
                        main.addConnection("wireguard");
                        close();
                    }
                }

            }

        }

    }

}
