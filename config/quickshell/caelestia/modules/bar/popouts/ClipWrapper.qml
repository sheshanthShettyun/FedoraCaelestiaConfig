pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen
    required property real borderThickness

    readonly property alias content: content
    property real offsetScale: content.hasCurrent ? 0 : 1

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight * (1 - offsetScale)

    y: content.isDetached ? (parent.height - content.nonAnimHeight) / 2 : parent.height - implicitHeight
    x: {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;

        const off = content.currentCenter - borderThickness - content.nonAnimWidth / 2;
        const diff = parent.width - Math.floor(off + content.nonAnimWidth);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    Behavior on offsetScale {
        // Opening from the bar must be immediate. Animating the clipped height
        // makes the popout look stuck beneath the button before it rises.
        enabled: !content.hasCurrent

        Anim {}
    }

    Behavior on x {
        enabled: !content.hasCurrent

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        // Do not animate the first frame of a hover reveal; only animate the
        // retract when the popout is dismissed.
        enabled: !content.hasCurrent && root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }
}
