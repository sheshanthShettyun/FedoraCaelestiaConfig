pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property string userName: "sheshanthShettyun"
    property string displayName: userName
    property string avatarUrl: fallbackAvatarUrl()
    property int followers
    property int totalContributions
    property int pendingRequests: 3
    readonly property bool loading: pendingRequests > 0
    property string errorMessage
    property string repoMessage
    property var contributions: []
    property var repos: []

    implicitWidth: 840
    implicitHeight: layout.implicitHeight

    Component.onCompleted: reload()

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.medium

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
                    clip: true

                    Image {
                        anchors.fill: parent
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        source: root.avatarUrl
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !root.avatarUrl
                        text: "account_circle"
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
                        text: root.displayName || root.userName
                        font: Tokens.font.title.small
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.errorMessage || root.repoMessage || qsTr("@%1  •  %2 followers").arg(root.userName).arg(root.followers)
                        font: Tokens.font.body.small
                        color: root.errorMessage ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                        animate: true
                    }
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: root.loading ? "sync" : "refresh"
                    isRound: true
                    disabled: root.loading
                    onClicked: root.reload()
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: "open_in_new"
                    isRound: true
                    onClicked: root.openUrl(root.profileUrl())
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: contribLayout.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                id: contribLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: root.totalContributions > 0 ? qsTr("%1 contributions in the last year").arg(root.totalContributions) : qsTr("Contributions")
                        font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                        animate: true
                    }

                    StyledText {
                        text: qsTr("Less")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Row {
                        spacing: 4

                        Repeater {
                            model: 5

                            StyledRect {
                                required property int index

                                implicitWidth: 10
                                implicitHeight: 10
                                radius: Tokens.rounding.extraSmall
                                color: root.contributionColour(index)
                            }
                        }
                    }

                    StyledText {
                        text: qsTr("More")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                GridLayout {
                    Layout.alignment: Qt.AlignHCenter
                    columns: 53
                    rowSpacing: 3
                    columnSpacing: 3

                    Repeater {
                        model: 371

                        StyledRect {
                            required property int index

                            implicitWidth: 9
                            implicitHeight: 9
                            radius: Tokens.rounding.extraSmall
                            color: root.contributionColour(root.contributionLevelForCell(index))
                        }
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.medium

            Repeater {
                model: root.repos

                RepoCard {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    name: modelData.name
                    description: modelData.description
                    language: modelData.language
                    languageColour: modelData.colour
                    stars: modelData.stars
                    forks: modelData.forks
                    url: modelData.url
                }
            }
        }
    }

    function profileUrl(): string {
        return `https://github.com/${encodeURIComponent(userName)}`;
    }

    function openUrl(url: string): void {
        if (url)
            Quickshell.execDetached(["xdg-open", url]);
    }

    function reload(): void {
        pendingRequests = 3;
        errorMessage = "";
        repoMessage = "";
        displayName = userName;
        avatarUrl = fallbackAvatarUrl();
        followers = 0;
        totalContributions = 0;
        contributions = [];
        repos = [];
        fetchProfile();
        fetchRepos();
        fetchContributions();
    }

    function finishRequest(): void {
        pendingRequests = Math.max(0, pendingRequests - 1);
    }

    function fetchProfile(): void {
        Requests.get(`https://api.github.com/users/${encodeURIComponent(userName)}`, text => {
            try {
                const data = JSON.parse(text);
                if (data.message) {
                    displayName = userName;
                    followers = 0;
                    avatarUrl = fallbackAvatarUrl();
                    finishRequest();
                    return;
                }
                displayName = data.name || data.login || userName;
                avatarUrl = data.avatar_url || fallbackAvatarUrl();
                followers = data.followers || 0;
            } catch (error) {
                displayName = userName;
                avatarUrl = fallbackAvatarUrl();
                followers = 0;
            }
            finishRequest();
        }, error => {
            displayName = userName;
            avatarUrl = fallbackAvatarUrl();
            followers = 0;
            finishRequest();
        }, {
            "Accept": "application/vnd.github+json",
            "User-Agent": "caelestia-shell"
        });
    }

    function fallbackAvatarUrl(): string {
        return `https://github.com/${encodeURIComponent(userName)}.png?size=120`;
    }

    function fetchRepos(): void {
        Requests.get(`https://api.github.com/users/${encodeURIComponent(userName)}/repos?sort=pushed&per_page=6`, text => {
            try {
                const data = JSON.parse(text);
                if (!Array.isArray(data)) {
                    useFallbackRepos(data.message || qsTr("GitHub API unavailable"));
                    finishRequest();
                    return;
                }
                repos = data.map(repo => ({
                    name: repo.name || qsTr("Repository"),
                    description: repo.description || qsTr("No description"),
                    language: repo.language || qsTr("Other"),
                    colour: languageColour(repo.language || ""),
                    stars: repo.stargazers_count || 0,
                    forks: repo.forks_count || 0,
                    url: repo.html_url || ""
                }));
                repoMessage = "";
            } catch (error) {
                useFallbackRepos(qsTr("Couldn't parse repositories"));
            }
            finishRequest();
        }, error => {
            useFallbackRepos(qsTr("Couldn't load repositories"));
            finishRequest();
        }, {
            "Accept": "application/vnd.github+json",
            "User-Agent": "caelestia-shell"
        });
    }

    function useFallbackRepos(message: string): void {
        repoMessage = qsTr("%1. Showing saved repositories.").arg(message);
        repos = fallbackRepos();
    }

    function fallbackRepos(): var {
        return [
            {
                name: "Ai",
                description: "Personal AI experiments, app ideas, and local tooling.",
                language: "Python",
                colour: languageColour("Python"),
                stars: 2,
                forks: 0,
                url: `https://github.com/${userName}/Ai`
            },
            {
                name: "dms-usb-detect",
                description: "Device detection utilities and desktop integration helpers.",
                language: "JavaScript",
                colour: languageColour("JavaScript"),
                stars: 0,
                forks: 0,
                url: `https://github.com/${userName}/dms-usb-detect`
            },
            {
                name: "dms-plugin-registry",
                description: "Plugin metadata and registry experiments.",
                language: "JSON",
                colour: languageColour("JSON"),
                stars: 0,
                forks: 0,
                url: `https://github.com/${userName}/dms-plugin-registry`
            }
        ];
    }

    function fetchContributions(): void {
        Requests.get(`https://github-contributions-api.jogruber.de/v4/${encodeURIComponent(userName)}?y=last`, text => {
            try {
                const data = JSON.parse(text);
                const days = data.contributions ?? [];
                contributions = days.slice(Math.max(0, days.length - 371));
                totalContributions = data.total?.lastYear ?? contributions.reduce((sum, day) => sum + (day.count || 0), 0);
            } catch (error) {
                errorMessage = qsTr("Couldn't parse contributions");
            }
            finishRequest();
        }, error => {
            errorMessage = qsTr("Couldn't load contributions");
            finishRequest();
        });
    }

    function languageColour(language: string) {
        if (language === "Python")
            return Colours.palette.m3primary;
        if (language === "QML" || language === "JavaScript" || language === "TypeScript")
            return Colours.palette.m3tertiary;
        if (language === "C++" || language === "C")
            return Colours.palette.m3error;
        if (language === "HTML" || language === "CSS")
            return Colours.palette.m3secondary;
        return Colours.palette.m3outline;
    }

    function contributionColour(level: int): color {
        if (level <= 0)
            return Colours.layer(Colours.palette.m3surfaceContainerHighest, 1);
        if (level === 1)
            return Qt.alpha(Colours.palette.m3primary, 0.35);
        if (level === 2)
            return Qt.alpha(Colours.palette.m3primary, 0.55);
        if (level === 3)
            return Qt.alpha(Colours.palette.m3primary, 0.75);
        return Colours.palette.m3primary;
    }

    function contributionLevelForCell(index: int): int {
        const row = Math.floor(index / 53);
        const column = index % 53;
        const firstDay = contributions.length > 0 ? new Date(contributions[0].date).getDay() : 0;
        const contributionIndex = column * 7 + row - firstDay;
        const contribution = contributions[contributionIndex];
        return contribution?.level ?? 0;
    }

    component RepoCard: StyledRect {
        id: repoRoot

        property string name
        property string description
        property string language
        property color languageColour
        property int stars
        property int forks
        property string url

        implicitHeight: 148
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "book_2"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: repoRoot.name
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: repoRoot.description
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledRect {
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: Tokens.rounding.full
                    color: repoRoot.languageColour
                }

                StyledText {
                    Layout.fillWidth: true
                    text: repoRoot.language
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    text: "star"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    text: repoRoot.stars.toString()
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                MaterialIcon {
                    text: "call_split"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    text: repoRoot.forks.toString()
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openUrl(repoRoot.url)
        }
    }
}
