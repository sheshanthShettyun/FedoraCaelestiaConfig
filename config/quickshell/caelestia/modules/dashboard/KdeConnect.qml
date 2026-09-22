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
        spacing: Tokens.spacing.medium

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 92
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "phonelink_ring"
                    fontStyle: Tokens.font.icon.extraLarge
                    color: Colours.palette.m3primary
                    fill: root.available ? 1 : 0
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Connect")
                        font: Tokens.font.title.small
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.statusText
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                        animate: true
                    }
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: "screen_share"
                    isRound: true
                    onClicked: Quickshell.execDetached(["scrcpy"])
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: root.loading ? "sync" : "refresh"
                    isRound: true
                    disabled: root.loading
                    onClicked: root.refresh()
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

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.medium

            Repeater {
                model: root.devices

                DeviceCard {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
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

    function runDeviceArgs(deviceId: string, args: list<string>): void {
        if (!deviceId)
            return;

        Quickshell.execDetached(["kdeconnect-cli", "--device", deviceId, ...args]);
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

    component DeviceCard: StyledRect {
        id: card

        property string deviceId
        property string deviceName

        implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            id: cardLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledRect {
                    implicitWidth: 46
                    implicitHeight: 46
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "smartphone"
                        fontStyle: Tokens.font.icon.large
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: card.deviceName
                        font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Reachable")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                ActionButton {
                    icon: "link_off"
                    text: qsTr("Unpair")
                    onClicked: root.runDeviceAction(card.deviceId, "--unpair")
                }

                ActionButton {
                    icon: "outgoing_mail"
                    text: qsTr("Send Ping")
                    onClicked: root.runDeviceAction(card.deviceId, "--ping")
                }

                ActionButton {
                    icon: "tune"
                    text: qsTr("Plugins")
                    onClicked: root.openDeviceSettings(card.deviceId)
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colours.palette.m3outlineVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Controls")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small

                ActionButton {
                    icon: "slideshow"
                    text: qsTr("Media")
                    onClicked: root.openDeviceSettings(card.deviceId)
                }

                ActionButton {
                    icon: "keyboard_mouse"
                    text: qsTr("Input")
                    onClicked: root.openDeviceSettings(card.deviceId)
                }

                ActionButton {
                    icon: "sms"
                    text: qsTr("SMS")
                    onClicked: root.openDeviceSettings(card.deviceId)
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Actions")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small

                ActionButton {
                    icon: "screencast"
                    text: qsTr("Mirror")
                    onClicked: Quickshell.execDetached(["scrcpy"])
                }

                ActionButton {
                    icon: "mobile_screen_share"
                    text: qsTr("Screen Off")
                    onClicked: Quickshell.execDetached(["scrcpy", "--turn-screen-off"])
                }

                ActionButton {
                    icon: "fullscreen"
                    text: qsTr("Fullscreen")
                    onClicked: Quickshell.execDetached(["scrcpy", "--fullscreen"])
                }

                ActionButton {
                    icon: "search"
                    text: qsTr("Find")
                    onClicked: root.runDeviceAction(card.deviceId, "--ring")
                }

                ActionButton {
                    icon: "content_paste_go"
                    text: qsTr("Clipboard")
                    onClicked: root.runDeviceAction(card.deviceId, "--send-clipboard")
                }

                ActionButton {
                    icon: "folder_open"
                    text: qsTr("Browse")
                    onClicked: root.browseDevice(card.deviceId)
                }

                ActionButton {
                    icon: "lock"
                    text: qsTr("Lock")
                    onClicked: root.runDeviceAction(card.deviceId, "--lock")
                }

                ActionButton {
                    icon: "lock_open"
                    text: qsTr("Unlock")
                    onClicked: root.runDeviceAction(card.deviceId, "--unlock")
                }

                ActionButton {
                    icon: "terminal"
                    text: qsTr("Commands")
                    onClicked: root.runDeviceAction(card.deviceId, "--list-commands")
                }
            }
        }
    }

    component ActionButton: IconTextButton {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        type: IconTextButton.Tonal
        font: Tokens.font.body.small
        horizontalPadding: Tokens.padding.small
        verticalPadding: Tokens.padding.small
    }
}
