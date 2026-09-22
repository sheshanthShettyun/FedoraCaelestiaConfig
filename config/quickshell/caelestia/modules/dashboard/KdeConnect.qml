pragma ComponentBehavior: Bound

import "performance"
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

    property ScreenState screenState
    property bool loading
    property bool available
    property string statusText: qsTr("Checking KDE Connect...")
    property string commandError
    property var devices: []

    implicitWidth: Tokens.sizes.dashboard.mediaTabWidth
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

        // 1. Top Header Bar
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

        // 2. Main Middle Section: Orbit Device Hub (Left) + 2-Column Action Buttons (Right)
        Loader {
            Layout.fillWidth: true
            sourceComponent: root.available && root.devices.length > 0 ? devicesComponent : unavailableComponent
        }

        // 3. Bottom Row: Storage & Battery (Network Removed)
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StorageCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
            }

            BatteryTank {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
            }
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

    component DeviceCard: RowLayout {
        id: card

        property string deviceId
        property string deviceName

        Layout.fillWidth: true
        spacing: Tokens.spacing.large
        Layout.alignment: Qt.AlignTop

        // Left Circular Orbit Hub Panel (Wider, no phone bezel frame)
        StyledRect {
            id: hubRect

            Layout.fillWidth: true
            Layout.preferredWidth: 1.1
            implicitHeight: 320
            radius: Tokens.rounding.extraExtraLarge
            color: Colours.tPalette.m3surfaceContainer

            // Orbit Ring Canvas
            Canvas {
                id: orbitCanvas

                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.lineWidth = 2.5;
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12);

                    const cx = width / 2;
                    const cy = height / 2 - 10;
                    const rx = width * 0.38;
                    const ry = height * 0.38;

                    ctx.beginPath();
                    ctx.ellipse(cx - rx, cy - ry, rx * 2, ry * 2);
                    ctx.stroke();
                }
            }

            // Top Orbit Node: Battery (No "Charging" text)
            StyledRect {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 20
                implicitHeight: 36
                implicitWidth: battRow.implicitWidth + 20
                radius: Tokens.rounding.full
                color: Colours.tPalette.m3surfaceContainerHigh

                RowLayout {
                    id: battRow

                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        text: "battery_full"
                        fontStyle: Tokens.font.icon.medium
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        text: qsTr("87%")
                        font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                        color: Colours.palette.m3onSurface
                    }
                }
            }

            // Middle Row: Wi-Fi (Left) + Center Icon + KDE Connect (Right)
            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -10
                spacing: 12

                // Left Node: Wi-Fi
                StyledRect {
                    implicitHeight: 52
                    implicitWidth: wifiColumn.implicitWidth + 20
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainerHigh

                    ColumnLayout {
                        id: wifiColumn

                        anchors.centerIn: parent
                        spacing: 2

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "wifi"
                            fontStyle: Tokens.font.icon.medium
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Wi-Fi")
                            font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("192.168.0.104")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // Center Icon Node (Generic Device Circle)
                StyledRect {
                    implicitWidth: 72
                    implicitHeight: 72
                    radius: 36
                    color: Colours.tPalette.m3surfaceContainerHigh
                    border.width: 2
                    border.color: Colours.palette.m3outlineVariant

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "smartphone"
                        fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.5).build()
                        color: Colours.palette.m3primary
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // Right Node: KDE Connect
                StyledRect {
                    implicitHeight: 52
                    implicitWidth: kdeColumn.implicitWidth + 20
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainerHigh

                    ColumnLayout {
                        id: kdeColumn

                        anchors.centerIn: parent
                        spacing: 2

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "desktop_windows"
                            fontStyle: Tokens.font.icon.medium
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("KDE Connect")
                            font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurface
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4

                            StyledRect {
                                implicitWidth: 6
                                implicitHeight: 6
                                radius: 3
                                color: "#4CAF50"
                            }

                            StyledText {
                                text: qsTr("Paired")
                                font: Tokens.font.body.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }

            // Bottom Device Name + OS
            ColumnLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                spacing: 2

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

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
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Android 14 • OxygenOS 14")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // Right Column: Action Buttons in a Wide 2-Column Grid
        GridLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1.2
            columns: 2
            rowSpacing: 10
            columnSpacing: 10

            ActionPillItem {
                icon: "play_arrow"
                title: qsTr("Media")
                subtitle: qsTr("Control playback")
                onClicked: {
                    if (root.screenState)
                        root.screenState.dashboardTab = 1;
                }
            }

            ActionPillItem {
                icon: "keyboard"
                title: qsTr("Input")
                subtitle: qsTr("Keyboard & mouse")
                onClicked: root.runDeviceAction(card.deviceId, "--send-clipboard")
            }

            ActionPillItem {
                icon: "sms"
                title: qsTr("SMS")
                subtitle: qsTr("Send & manage messages")
                onClicked: root.runDeviceAction(card.deviceId, "--ping-msg 'KDE Connect active'")
            }

            ActionPillItem {
                icon: "desktop_windows"
                title: qsTr("Mirror")
                subtitle: qsTr("Screen control")
                onClicked: Quickshell.execDetached(["/home/sriyaan/.local/bin/sidera-connect-scrcpy"])
            }

            ActionPillItem {
                icon: "folder"
                title: qsTr("Browse")
                subtitle: qsTr("Files & folders")
                onClicked: root.browseDevice(card.deviceId)
            }

            ActionPillItem {
                icon: "content_paste"
                title: qsTr("Clipboard")
                subtitle: qsTr("Sync clipboard")
                onClicked: root.runDeviceAction(card.deviceId, "--send-clipboard")
            }

            ActionPillItem {
                icon: "code"
                title: qsTr("Commands")
                subtitle: qsTr("Remote commands")
                onClicked: root.runDeviceAction(card.deviceId, "--list-commands")
            }
        }
    }

    component ActionPillItem: ButtonBase {
        id: item

        required property string icon
        required property string title
        required property string subtitle

        type: ButtonBase.Text
        implicitWidth: 1
        implicitHeight: 58
        Layout.fillWidth: true
        radius: Tokens.rounding.large

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 12
                spacing: Tokens.spacing.small

                // Organic Fluid Icon Container
                StyledRect {
                    implicitWidth: 42
                    implicitHeight: 42
                    radius: 21
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
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: item.subtitle
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
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
}
