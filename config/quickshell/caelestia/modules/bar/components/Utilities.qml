pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

RowLayout {
    id: root

    required property ScreenState screenState

    readonly property alias quickTogglesButton: quickToggles

    spacing: Tokens.spacing.small

    IconButton {
        visible: Config.utilities.enabled && Config.utilities.cards.keepAwake

        type: IconButton.Tonal
        isRound: true
        shapeMorph: true
        isToggle: true
        font: Tokens.font.icon.small
        padding: Tokens.padding.extraSmall

        icon: "coffee"
        checked: IdleInhibitor.enabled
        onClicked: IdleInhibitor.enabled = !IdleInhibitor.enabled
    }

    IconButton {
        visible: Config.utilities.enabled && Config.utilities.cards.recorder

        type: IconButton.Tonal
        isRound: true
        shapeMorph: true
        isToggle: true
        font: Tokens.font.icon.small
        padding: Tokens.padding.extraSmall

        icon: "screen_record"
        checked: Recorder.running
        activeColour: Colours.palette.m3error
        activeOnColour: Colours.palette.m3onError
        onClicked: Recorder.running ? Recorder.stop() : Recorder.start()
    }

    IconButton {
        id: quickToggles

        visible: Config.utilities.enabled && Config.utilities.cards.quickToggles

        type: IconButton.Tonal
        isRound: true
        shapeMorph: true
        isToggle: true
        font: Tokens.font.icon.small
        padding: Tokens.padding.extraSmall

        icon: "tune"
        checked: root.screenState.utilities
        onClicked: root.screenState.utilities = !root.screenState.utilities
    }
}
