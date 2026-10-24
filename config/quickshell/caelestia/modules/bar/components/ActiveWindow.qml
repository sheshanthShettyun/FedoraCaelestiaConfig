pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

StyledRect {
    id: root

    required property var bar
    required property Brightness.Monitor monitor
    property color colour: Colours.palette.m3onSurfaceVariant

    // Font used for the preview title
    readonly property string previewFontFamily: "Pangea Afrikan"
    // Fixed footprint: a long title elides instead of widening the entry and shoving the
    // other bar buttons around.
    readonly property int preferredWidth: 340

    readonly property string windowTitle: {
        const title = Hypr.activeToplevel?.title;
        if (!title)
            return qsTr("Desktop");
        if (Config.bar.activeWindow.compact) {
            // " - " (standard hyphen), " — " (em dash), " – " (en dash)
            const parts = title.split(/\s+[\-\u2013\u2014]\s+/);
            if (parts.length > 1)
                return parts[parts.length - 1].trim();
        }
        return title;
    }

    readonly property int maxWidth: {
        const otherModules = bar.children.filter(c => c.entryId && c.item !== this && c.entryId !== "spacer");
        const otherWidth = otherModules.reduce((acc, curr) => acc + (curr.item.nonAnimWidth ?? curr.implicitWidth ?? curr.width), 0);
        // Length - 2 cause repeater counts as a child
        return bar.width - otherWidth - bar.spacing * (bar.children.length - 1) - bar.hPadding * 2;
    }
    readonly property int padding: Tokens.padding.medium
    readonly property int availableTextWidth: Math.max(0, Math.min(preferredWidth, maxWidth) - padding * 2 - icon.implicitWidth - Tokens.spacing.small)

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.medium
    clip: true
    // Hug the text: the pill grows/shrinks with the font instead of a fixed bar height.
    implicitHeight: text.implicitHeight + padding * 2
    implicitWidth: Math.min(Math.min(preferredWidth, maxWidth), content.implicitWidth + padding * 2)

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: !Config.bar.activeWindow.showOnHover

        sourceComponent: MouseArea {
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onPositionChanged: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent && popouts.currentName !== "activewindow")
                    popouts.hasCurrent = false;
            }
            onClicked: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent) {
                    popouts.hasCurrent = false;
                } else {
                    popouts.currentName = "activewindow";
                    popouts.currentCenter = root.mapToItem(root.bar, root.implicitWidth / 2, 0).x;
                    popouts.hasCurrent = true;
                }
            }
        }
    }

    RowLayout {
        id: content

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            id: icon

            Layout.alignment: Qt.AlignVCenter

            animate: true
            text: Icons.getAppCategoryIcon(Hypr.activeToplevel?.lastIpcObject.class, "desktop_windows")
            color: root.colour
        }

        StyledText {
            id: text

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.min(implicitWidth, root.availableTextWidth)

            font: metrics.font
            color: root.colour
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            text: root.windowTitle
        }
    }

    TextMetrics {
        id: metrics

        text: root.windowTitle
        font: root.Tokens.font.body.builders.small.family(root.previewFontFamily).letterSpacing(1.4).build()
    }

    Behavior on implicitWidth {
        Anim {}
    }
}
