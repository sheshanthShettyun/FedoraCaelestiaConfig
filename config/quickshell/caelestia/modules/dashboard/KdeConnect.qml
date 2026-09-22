pragma ComponentBehavior: Bound

import "performance"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Components
import Caelestia.Config
import Caelestia.Services
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
    property var notifications: []

    implicitWidth: 900
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

        // 1. Top Header Bar (mirrors GitHub tab header pattern)
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 92
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                StyledRect {
                    implicitWidth: 58
                    implicitHeight: 58
                    radius: Tokens.rounding.full
                    color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "smartphone"
                        fontStyle: Tokens.font.icon.extraLarge
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.devices.length > 0 ? root.devices[0].name : qsTr("Connect")
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

                StyledRect {
                    implicitHeight: statusRow.implicitHeight + Tokens.padding.small * 2
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
                            color: root.available ? Colours.palette.m3primary : Colours.palette.m3error
                        }

                        StyledText {
                            text: root.available ? qsTr("Connected") : qsTr("Disconnected")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurface
                        }
                    }
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

        // 2. Main Middle Section: Clean Device Hub (Left) + 2-Column Action Buttons (Right)
        Loader {
            Layout.fillWidth: true
            sourceComponent: root.available && root.devices.length > 0 ? devicesComponent : unavailableComponent
        }

        // 3. Bottom Row: Storage & Battery (Network Removed)
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            PhoneStorageCard {
                id: phoneStorage

                implicitWidth: (root.implicitWidth - Tokens.spacing.medium) * 70 / 160
                deviceName: root.devices.length > 0 ? root.devices[0].name : ""
            }

            PhoneBatteryTank {
                implicitWidth: (root.implicitWidth - Tokens.spacing.medium) * 90 / 160
                deviceId: root.devices.length > 0 ? root.devices[0].id : ""
            }
        }

        // 4. Phone Notifications
        StyledRect {
            Layout.fillWidth: true
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "notifications"
                        fontStyle: Tokens.font.icon.medium
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Notifications")
                        font: Tokens.font.title.medium
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledRect {
                        implicitHeight: notifCount.implicitHeight + Tokens.padding.small * 2
                        implicitWidth: notifCount.implicitWidth + Tokens.padding.medium * 2
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHigh

                        StyledText {
                            id: notifCount

                            anchors.centerIn: parent
                            text: `${root.notifications.length}`
                            font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurface
                        }
                    }

                    IconButton {
                        type: IconButton.Tonal
                        icon: "refresh"
                        isRound: true
                        onClicked: root.pollNotifs()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small
                    visible: root.notifications.length > 0

                    Repeater {
                        model: root.notifications

                        NotifRow {
                            required property var modelData

                            Layout.fillWidth: true
                            notif: modelData
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    Layout.bottomMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.small
                    visible: root.notifications.length === 0

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "notifications_off"
                        fontStyle: Tokens.font.icon.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No notifications")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
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
        id: notifProc

        command: ["/home/sriyaan/.local/bin/sidera-phone-notifs"]
        stdout: StdioCollector {
            onStreamFinished: root.applyNotifOutput(text)
        }
    }

    Timer {
        interval: 12000
        repeat: true
        running: true
        onTriggered: root.pollNotifs()
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
        phoneStorage.pollStorage();
        pollNotifs();
    }

    function pollNotifs(): void {
        notifProc.running = true;
    }

    function applyNotifOutput(output: string): void {
        const rows = output.trim().split("\n").filter(line => line.trim().length > 0).map(line => {
            const p = line.split("\u001F");
            return {
                pkg: p[0] ?? "",
                app: p[1] ?? "",
                title: p[2] ?? "",
                text: p[3] ?? "",
                when: parseInt(p[4] ?? "0", 10)
            };
        }).filter(n => n.pkg.length > 0);
        rows.sort((a, b) => b.when - a.when);
        notifications = rows.slice(0, 4);
    }

    function notifIcon(pkg: string): string {
        if (pkg.includes("messaging") || pkg.includes("sms") || pkg.includes("mms"))
            return "sms";
        if (pkg.includes("whatsapp"))
            return "chat";
        if (pkg.includes("telegram"))
            return "send";
        if (pkg.includes("discord"))
            return "forum";
        if (pkg.includes("gm") || pkg.includes("mail") || pkg.includes("outlook"))
            return "mail";
        if (pkg.includes("dialer") || pkg.includes("telecom") || pkg.includes("phone"))
            return "call";
        if (pkg.includes("calendar") || pkg.includes("deskclock"))
            return "event";
        if (pkg.includes("alarm") || pkg.includes("clock"))
            return "alarm";
        if (pkg.includes("camera"))
            return "photo_camera";
        if (pkg.includes("spotify") || pkg.includes("music"))
            return "music_note";
        if (pkg.includes("maps") || pkg.includes("location"))
            return "place";
        if (pkg.includes("chrome") || pkg.includes("browser") || pkg.includes("zen"))
            return "public";
        if (pkg.includes("youtube") || pkg.includes("video"))
            return "play_arrow";
        if (pkg.includes("photos") || pkg.includes("gallery"))
            return "image";
        if (pkg.includes("kdeconnect"))
            return "phonelink_ring";
        return "";
    }

    function timeAgo(when: real): string {
        if (!when || when <= 0)
            return "";
        const s = Math.max(0, Math.floor((Date.now() - when) / 1000));
        if (s < 60)
            return qsTr("now");
        const m = Math.floor(s / 60);
        if (m < 60)
            return qsTr("%1m").arg(m);
        const h = Math.floor(m / 60);
        if (h < 24)
            return qsTr("%1h").arg(h);
        return qsTr("%1d").arg(Math.floor(h / 24));
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
        property int batteryPct: -1
        property bool batteryCharging: false

        Layout.fillWidth: true
        spacing: Tokens.spacing.medium
        Layout.alignment: Qt.AlignTop

        Component.onCompleted: card.pollBattery()

        onDeviceIdChanged: card.pollBattery()

        Process {
            id: batteryProc

            stdout: StdioCollector {
                onStreamFinished: {
                    const m = text.match(/'charge':\s*<(\d+)>/);
                    if (m)
                        card.batteryPct = parseInt(m[1], 10);
                    const c = text.match(/'isCharging':\s*<(true|false)>/);
                    if (c)
                        card.batteryCharging = c[1] === "true";
                }
            }
        }

        Timer {
            id: batteryTimer

            interval: 30000
            repeat: true
            running: card.deviceId.length > 0
            onTriggered: card.pollBattery()
        }

        function pollBattery(): void {
            if (!card.deviceId)
                return;
            batteryProc.command = ["gdbus", "call", "--session", "--dest", "org.kde.kdeconnect.daemon", "--object-path", `/modules/kdeconnect/devices/${card.deviceId}/battery`, "--method", "org.freedesktop.DBus.Properties.GetAll", "org.kde.kdeconnect.device.battery"];
            batteryProc.running = true;
        }

        // Device strip: Wi-Fi tile + KDE Connect tile + labeled action icons
        StyledRect {
            implicitWidth: 180
            implicitHeight: 140
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "wifi"
                    fontStyle: Tokens.font.icon.medium
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Wi-Fi")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("192.168.0.104")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        StyledRect {
            implicitWidth: 180
            implicitHeight: 140
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "desktop_windows"
                    fontStyle: Tokens.font.icon.medium
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("KDE Connect")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.small

                    StyledRect {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        text: qsTr("Paired")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 140
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: mediaBtn.implicitHeight

                        IconButton {
                            id: mediaBtn

                            anchors.centerIn: parent
                            type: IconButton.Tonal
                            icon: "play_arrow"
                            isRound: true
                            onClicked: {
                                if (root.screenState)
                                    root.screenState.dashboardTab = 1;
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: mediaBtn.implicitHeight

                        IconButton {
                            anchors.centerIn: parent
                            type: IconButton.Tonal
                            icon: "sms"
                            isRound: true
                            onClicked: root.runDeviceAction(card.deviceId, "--ping-msg 'KDE Connect active'")
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: mediaBtn.implicitHeight

                        IconButton {
                            anchors.centerIn: parent
                            type: IconButton.Tonal
                            icon: "desktop_windows"
                            isRound: true
                            onClicked: Quickshell.execDetached(["/home/sriyaan/.local/bin/sidera-connect-scrcpy"])
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: mediaBtn.implicitHeight

                        IconButton {
                            anchors.centerIn: parent
                            type: IconButton.Tonal
                            icon: "folder"
                            isRound: true
                            onClicked: root.openDeviceSettings(card.deviceId)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: mediaBtn.implicitHeight

                        IconButton {
                            anchors.centerIn: parent
                            type: IconButton.Tonal
                            icon: "content_paste"
                            isRound: true
                            onClicked: root.runDeviceAction(card.deviceId, "--send-clipboard")
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignTop
                        text: qsTr("Media")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignTop
                        text: qsTr("Send SMS")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignTop
                        text: qsTr("Share Screen")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignTop
                        text: qsTr("Browse Files")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignTop
                        text: qsTr("Clipboard")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    component NotifRow: StyledRect {
        id: row

        required property var notif

        readonly property string iconName: root.notifIcon(notif.pkg)

        implicitHeight: notifLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerHigh

        RowLayout {
            id: notifLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.medium

            StyledRect {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 40
                implicitHeight: 40
                radius: Tokens.rounding.full
                color: Colours.palette.m3primaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: row.iconName.length > 0
                    text: row.iconName
                    fontStyle: Tokens.font.icon.medium
                    color: Colours.palette.m3onPrimaryContainer
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: row.iconName.length === 0
                    text: row.notif.app.charAt(0).toUpperCase()
                    font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: row.notif.app
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: root.timeAgo(row.notif.when)
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: row.notif.title.length > 0
                    text: row.notif.title
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: row.notif.text.length > 0
                    text: row.notif.text
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }
    }

    component PhoneStorageCard: StyledRect {
        id: storage

        property string deviceName
        property real usedKib: -1
        property real totalKib: -1
        readonly property color accent: Colours.palette.m3secondary
        readonly property real percentage: totalKib > 0 ? usedKib / totalKib : 0

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.extraExtraLarge

        implicitWidth: layout.implicitWidth + layout.anchors.margins * 2
        implicitHeight: 160

        Component.onCompleted: storage.pollStorage()

        Process {
            id: storageProc

            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.trim().split("\n");
                    if (lines.length < 2)
                        return;
                    const parts = lines[1].trim().split(/\s+/);
                    if (parts.length < 3)
                        return;
                    const total = parseFloat(parts[1]);
                    const used = parseFloat(parts[2]);
                    if (!isNaN(total) && total > 0 && !isNaN(used)) {
                        storage.totalKib = total;
                        storage.usedKib = used;
                    }
                }
            }
        }

        Timer {
            interval: 60000
            repeat: true
            running: true
            onTriggered: storage.pollStorage()
        }

        function pollStorage(): void {
            storageProc.command = ["/home/sriyaan/platform-tools/adb", "shell", "df", "-k", "/data"];
            storageProc.running = true;
        }

        ColumnLayout {
            id: layout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.small
            spacing: 0

            RowLayout {
                id: row

                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.medium

                CircularProgress {
                    fgColour: storage.accent
                    value: storage.percentage
                    implicitSize: usageColumn.implicitHeight + thickness + Tokens.padding.small * 2
                    startAngle: -225
                    sweepAngle: 270

                    Behavior on clampedVal {
                        Anim {}
                    }

                    ColumnLayout {
                        id: usageColumn

                        anchors.centerIn: parent
                        spacing: 0

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "smartphone"
                            color: storage.accent
                            fontStyle: Tokens.font.icon.medium
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: storage.totalKib > 0 ? Math.round(storage.percentage * 100) + "%" : qsTr("--")
                            font: Tokens.font.title.builders.large.width(90).build()
                            color: storage.accent
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Used")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                ColumnLayout {
                    Layout.minimumWidth: Tokens.sizes.dashboard.perfStorageTextWidth
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: qsTr("Storage")
                        font: Tokens.font.title.medium
                    }

                    StyledText {
                        text: {
                            if (storage.totalKib <= 0)
                                return qsTr("No device detected");

                            const fmt = UsageFmt.formatKib(storage.usedKib, storage.totalKib);
                            return `${+fmt.value.toFixed(1)} / ${+fmt.total.toFixed(1)} ${fmt.unit}`;
                        }
                        font: Tokens.font.body.large
                        color: storage.accent
                    }
                }
            }
        }
    }

    component PhoneBatteryTank: StyledClippingRect {
        id: tank

        property string deviceId
        property int pct: -1
        property bool charging: false
        property real animPerc: pct >= 0 ? pct / 100 : 0
        readonly property string pctText: pct >= 0 ? `${pct}%` : qsTr("--")
        readonly property string statusText: {
            if (pct < 0)
                return qsTr("...");
            if (pct >= 100)
                return qsTr("Full");
            if (charging)
                return qsTr("Charging");
            return qsTr("...");
        }

        color: Colours.palette.m3secondaryContainer
        radius: Tokens.rounding.large

        implicitHeight: Tokens.sizes.dashboard.perfBattHeight

        Component.onCompleted: tank.pollBattery()

        onDeviceIdChanged: tank.pollBattery()

        Behavior on animPerc {
            Anim {}
        }

        Process {
            id: tankBatteryProc

            stdout: StdioCollector {
                onStreamFinished: {
                    const m = text.match(/'charge':\s*<(\d+)>/);
                    if (m)
                        tank.pct = parseInt(m[1], 10);
                    const c = text.match(/'isCharging':\s*<(true|false)>/);
                    if (c)
                        tank.charging = c[1] === "true";
                }
            }
        }

        Timer {
            interval: 30000
            repeat: true
            running: tank.deviceId.length > 0
            onTriggered: tank.pollBattery()
        }

        function pollBattery(): void {
            if (!tank.deviceId)
                return;
            tankBatteryProc.command = ["gdbus", "call", "--session", "--dest", "org.kde.kdeconnect.daemon", "--object-path", `/modules/kdeconnect/devices/${tank.deviceId}/battery`, "--method", "org.freedesktop.DBus.Properties.GetAll", "org.kde.kdeconnect.device.battery"];
            tankBatteryProc.running = true;
        }

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: 0

            MaterialIcon {
                Layout.leftMargin: -Tokens.padding.extraSmall
                text: "battery_full"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.large
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Battery")
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
            }

            Item {
                Layout.fillHeight: true
            }

            StyledText {
                Layout.alignment: Qt.AlignRight
                text: tank.statusText
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                animate: true
            }

            RowLayout {
                Layout.topMargin: -Tokens.padding.extraSmall
                Layout.bottomMargin: -Tokens.padding.small
                Layout.rightMargin: -Tokens.padding.extraSmall
                Layout.alignment: Qt.AlignRight
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    text: "bolt"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.large
                    fill: 1

                    scale: tank.charging ? 1 : 0
                    opacity: tank.charging ? 1 : 0

                    Behavior on scale {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }

                StyledText {
                    text: tank.pctText
                    color: Colours.palette.m3primary
                    font: Tokens.font.headline.medium
                }
            }
        }

        StyledRect {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            implicitHeight: parent.height * tank.animPerc

            color: Colours.palette.m3secondary
            radius: Tokens.rounding.extraSmall
            clip: true

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: layout.anchors.margins
                height: layout.height
                spacing: 0

                MaterialIcon {
                    Layout.leftMargin: -Tokens.padding.extraSmall
                    text: "battery_full"
                    color: Colours.palette.m3primaryContainer
                    fontStyle: Tokens.font.icon.large
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Battery")
                    color: Colours.palette.m3onSecondary
                    font: Tokens.font.body.medium
                }

                Item {
                    Layout.fillHeight: true
                }

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: tank.statusText
                    color: Colours.palette.m3secondaryContainer
                    font: Tokens.font.body.small
                    animate: true
                }

                RowLayout {
                    Layout.topMargin: -Tokens.padding.extraSmall
                    Layout.bottomMargin: -Tokens.padding.small
                    Layout.rightMargin: -Tokens.padding.extraSmall
                    Layout.alignment: Qt.AlignRight
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        text: "bolt"
                        color: Colours.palette.m3primaryContainer
                        fontStyle: Tokens.font.icon.large
                        fill: 1

                        scale: tank.charging ? 1 : 0
                        opacity: tank.charging ? 1 : 0
                    }

                    StyledText {
                        text: tank.pctText
                        color: Colours.palette.m3primaryContainer
                        font: Tokens.font.headline.medium
                    }
                }
            }
        }
    }

}
