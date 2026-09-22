pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property bool loading
    property bool available
    property string statusText: qsTr("Checking KDE Connect...")
    property string commandError
    property var devices: []

    implicitWidth: 840
    implicitHeight: layout.implicitHeight

    Component.onCompleted: refresh()

    Timer {
        id: daemonRefreshTimer

        interval: 800
        onTriggered: root.refresh()
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.large

        // Top Header
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 84
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Connect")
                        font: Tokens.font.title.large
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Manage and control your devices")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: root.loading ? "sync" : "refresh"
                    isRound: true
                    disabled: root.loading
                    onClicked: root.refresh()
                }

                // Connection Status Dropdown Badge
                StyledRect {
                    implicitHeight: 38
                    implicitWidth: statusRow.implicitWidth + Tokens.padding.medium * 2
                    radius: Tokens.rounding.full
                    color: Colours.tPalette.m3surfaceContainerHigh

                    RowLayout {
                        id: statusRow

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        StyledRect {
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: Tokens.rounding.full
                            color: root.available ? "#4CAF50" : Colours.palette.m3error
                        }

                        StyledText {
                            text: root.available ? qsTr("Connected") : qsTr("Disconnected")
                            font: Tokens.font.body.medium
                            color: Colours.palette.m3onSurface
                        }

                        MaterialIcon {
                            text: "arrow_drop_down"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            sourceComponent: root.available && root.devices.length > 0 ? devicesComponent : unavailableComponent
        }
    }

    Component {
        id: unavailableComponent

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: unavailLayout.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                id: unavailLayout

                anchors.centerIn: parent
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "cloud_off"
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.8).build()
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("KDE Connect is unavailable")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Start kdeconnectd to connect your devices")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                ButtonRow {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.small

                    IconButton {
                        type: IconButton.Tonal
                        icon: "play_arrow"
                        isRound: true
                        onClicked: root.startDaemon()
                    }

                    IconButton {
                        type: IconButton.Tonal
                        icon: "refresh"
                        isRound: true
                        onClicked: root.refresh()
                    }
                }
            }
        }
    }

    Component {
        id: devicesComponent

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.large

            Repeater {
                model: root.devices

                DeviceCard {
                    required property var modelData

                    Layout.fillWidth: true
                    deviceId: modelData.id
                    deviceName: modelData.name
                }
            }
        }
    }

    Process {
        id: listProc

        command: ["kdeconnect-cli", "--list-available", "--id-name-only"]
        stdout: StdioCollector {
            onStreamFinished: root.applyDeviceOutput(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.applyDeviceError(text.trim());
            }
        }
        onExited: exitCode => { // qmllint disable signal-handler-parameters
            root.loading = false;
            if (exitCode !== 0 && root.devices.length === 0)
                root.available = false;
        }
    }

    Process {
        id: mountProc

        property string deviceId

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (exitCode === 0) {
                mountPointProc.deviceId = deviceId;
                mountPointProc.command = ["kdeconnect-cli", "--device", deviceId, "--get-mount-point"];
                mountPointProc.running = true;
            }
        }
    }

    Process {
        id: mountPointProc

        property string deviceId

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.length > 0)
                    Quickshell.execDetached(["xdg-open", path]);
            }
        }
    }

    function refresh(): void {
        loading = true;
        statusText = qsTr("Refreshing devices...");
        commandError = "";
        devices = [];
        available = false;
        listProc.running = true;
    }

    function applyDeviceOutput(output: string): void {
        if (commandError.length > 0)
            return;

        const parsed = output.trim().split("\n").filter(line => line.trim().length > 0).map(line => {
            const parts = line.trim().split(/\s+/);
            return {
                id: parts.shift() ?? "",
                name: parts.join(" ") || qsTr("KDE Connect device")
            };
        }).filter(device => device.id.length > 0);

        devices = parsed;
        available = parsed.length > 0;
        statusText = parsed.length > 0 ? qsTr("%1 device%2 reachable").arg(parsed.length).arg(parsed.length === 1 ? "" : "s") : qsTr("No reachable paired devices");
    }

    function applyDeviceError(error: string): void {
        commandError = error;
        available = false;
        statusText = error.includes("D-Bus") ? qsTr("KDE Connect is not running") : error;
    }

    function runDeviceAction(deviceId: string, action: string): void {
        if (!deviceId)
            return;

        Quickshell.execDetached(["kdeconnect-cli", "--device", deviceId, action]);
    }

    function openDeviceSettings(deviceId: string): void {
        if (deviceId)
            Quickshell.execDetached(["kdeconnect-app", "--device", deviceId]);
        else
            Quickshell.execDetached(["kdeconnect-app"]);
    }

    function browseDevice(deviceId: string): void {
        if (!deviceId)
            return;

        mountProc.deviceId = deviceId;
        mountProc.command = ["kdeconnect-cli", "--device", deviceId, "--mount"];
        mountProc.running = true;
    }

    function startDaemon(): void {
        Quickshell.execDetached(["kdeconnectd"]);
        daemonRefreshTimer.restart();
    }

    component DeviceCard: ColumnLayout {
        id: card

        property string deviceId
        property string deviceName

        spacing: Tokens.spacing.large

        // Top Device Info Box
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: mainCardLayout.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                id: mainCardLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.large

                // Left Phone Frame
                StyledRect {
                    implicitWidth: 100
                    implicitHeight: 160
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainerHigh
                    border.width: 1
                    border.color: Colours.palette.m3outlineVariant

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "smartphone"
                            fontStyle: Tokens.font.icon.extraLarge
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Device\nImage")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Right Device Info + Actions
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    // Name + OS + Options Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                spacing: Tokens.spacing.small

                                StyledText {
                                    text: card.deviceName
                                    font: Tokens.font.title.medium
                                    color: Colours.palette.m3onSurface
                                }

                                MaterialIcon {
                                    text: "edit"
                                    fontStyle: Tokens.font.icon.small
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }

                            StyledText {
                                text: qsTr("Android 14 • OxygenOS 14")
                                font: Tokens.font.body.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }

                        IconButton {
                            type: IconButton.Tonal
                            icon: "more_vert"
                            isRound: true
                            onClicked: root.openDeviceSettings(card.deviceId)
                        }
                    }

                    // 3 Status Cards Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        StatusTile {
                            icon: "battery_charging_full"
                            title: qsTr("87%")
                            subtext: qsTr("Charging")
                        }

                        StatusTile {
                            icon: "wifi"
                            title: qsTr("Wi-Fi")
                            subtext: qsTr("192.168.0.103")
                        }

                        StatusTile {
                            icon: "phonelink_ring"
                            title: qsTr("KDE Connect")
                            subtext: qsTr("Paired")
                        }
                    }

                    // Primary Actions Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        IconTextButton {
                            Layout.fillWidth: true
                            type: IconTextButton.Tonal
                            icon: "link_off"
                            text: qsTr("Unpair")
                            onClicked: root.runDeviceAction(card.deviceId, "--unpair")
                        }

                        IconTextButton {
                            Layout.fillWidth: true
                            type: IconTextButton.Tonal
                            icon: "send"
                            text: qsTr("Send Ping")
                            onClicked: root.runDeviceAction(card.deviceId, "--ping")
                        }

                        IconTextButton {
                            Layout.fillWidth: true
                            type: IconTextButton.Tonal
                            icon: "extension"
                            text: qsTr("Plugins")
                            onClicked: root.openDeviceSettings(card.deviceId)
                        }
                    }
                }
            }
        }

        // Bottom 2-Column Section (Device Controls & Device Tools)
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.large
            Layout.alignment: Qt.AlignTop

            // Left Column: Device Controls
            StyledRect {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                implicitHeight: controlsLayout.implicitHeight + Tokens.padding.large * 2
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainer

                ColumnLayout {
                    id: controlsLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: qsTr("Device Controls")
                            font: Tokens.font.title.small
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            text: qsTr("Quick access to common actions")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    ToolRowItem {
                        icon: "play_circle"
                        title: qsTr("Media")
                        subtitle: qsTr("Control playback")
                        onClicked: root.openDeviceSettings(card.deviceId)
                    }

                    ToolRowItem {
                        icon: "keyboard_mouse"
                        title: qsTr("Input")
                        subtitle: qsTr("Keyboard & mouse")
                        onClicked: root.openDeviceSettings(card.deviceId)
                    }

                    ToolRowItem {
                        icon: "sms"
                        title: qsTr("SMS")
                        subtitle: qsTr("Send & manage messages")
                        onClicked: root.openDeviceSettings(card.deviceId)
                    }
                }
            }

            // Right Column: Device Tools
            StyledRect {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                implicitHeight: toolsLayout.implicitHeight + Tokens.padding.large * 2
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainer

                ColumnLayout {
                    id: toolsLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: qsTr("Device Tools")
                            font: Tokens.font.title.small
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            text: qsTr("Additional device features")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    ToolRowItem {
                        icon: "screencast"
                        title: qsTr("Mirror")
                        subtitle: qsTr("View and control your screen")
                        onClicked: Quickshell.execDetached(["scrcpy"])
                    }

                    ToolRowItem {
                        icon: "folder_open"
                        title: qsTr("Browse")
                        subtitle: qsTr("Access files and folders")
                        onClicked: root.browseDevice(card.deviceId)
                    }

                    ToolRowItem {
                        icon: "content_paste_go"
                        title: qsTr("Clipboard")
                        subtitle: qsTr("Sync clipboard between devices")
                        onClicked: root.runDeviceAction(card.deviceId, "--send-clipboard")
                    }

                    ToolRowItem {
                        icon: "terminal"
                        title: qsTr("Commands")
                        subtitle: qsTr("Run device commands")
                        onClicked: root.runDeviceAction(card.deviceId, "--list-commands")
                    }
                }
            }
        }
    }

    component StatusTile: StyledRect {
        id: tile

        required property string icon
        required property string title
        required property string subtext

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 56
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainerHigh

        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: tile.icon
                fontStyle: Tokens.font.icon.medium
                color: Colours.palette.m3primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: tile.title
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: tile.subtext
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }
    }

    component ToolRowItem: ButtonBase {
        id: item

        required property string icon
        required property string title
        required property string subtitle

        type: ButtonBase.Tonal
        implicitWidth: 1
        implicitHeight: 56
        Layout.fillWidth: true

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: 38
                implicitHeight: 38
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainerHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    text: item.icon
                    fontStyle: Tokens.font.icon.medium
                    color: Colours.palette.m3primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: item.title
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: item.subtitle
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            MaterialIcon {
                text: "chevron_right"
                fontStyle: Tokens.font.icon.medium
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
