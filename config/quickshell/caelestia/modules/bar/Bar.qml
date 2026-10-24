pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

RowLayout {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int hPadding: Tokens.padding.large
    readonly property int paddingLeft: Tokens.padding.extraLarge
    readonly property int paddingRight: Tokens.padding.small

    readonly property Item utilitiesToggles: {
        for (let i = 0; i < repeater.count; i++) {
            const wrapper = repeater.itemAt(i);
            if (wrapper?.entryId !== "utilities")
                continue;
            return (wrapper.item as Utilities)?.quickTogglesButton ?? null;
        }
        return null;
    }

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const tray = (repeater.itemAt(i) as EntryWrapper).item as Tray;
            if (tray)
                tray.expanded = false;
        }
    }

    // Item the popout centre is currently bound to (avoids rebuilding the binding every pointer move)
    property Item _centerItem: null

    readonly property int activeWindowIndex: {
        for (let i = 0; i < repeater.count; i++) {
            if (repeater.itemAt(i)?.entryId === "activeWindow")
                return i;
        }
        return -1;
    }

    readonly property int firstSpacerIndex: {
        for (let i = 0; i < repeater.count; i++) {
            if (repeater.itemAt(i)?.entryId === "spacer")
                return i;
        }
        return -1;
    }

    // The active window entry is the visual centre of the bar, so give the first spacer the width needed to put its centre on the bar's centre
    readonly property bool centeringActiveWindow: activeWindowIndex >= 0 && firstSpacerIndex >= 0 && firstSpacerIndex < activeWindowIndex

    readonly property real centerBias: {
        if (!centeringActiveWindow)
            return 0;

        let left = 0;
        for (let i = 0; i < activeWindowIndex; i++) {
            if (i !== firstSpacerIndex)
                left += repeater.itemAt(i)?.implicitWidth ?? 0;
        }

        const aw = repeater.itemAt(activeWindowIndex)?.implicitWidth ?? 0;
        return Math.max(0, width / 2 - paddingLeft - spacing * activeWindowIndex - aw / 2 - left);
    }

    // Opens a popout, keeping the centre binding alive instead of recreating it on every mouse move
    function setPopout(name: string, item: Item, centerExpr: var): void {
        if (popouts.currentName !== name)
            popouts.currentName = name;
        if (_centerItem !== item) {
            _centerItem = item;
            popouts.currentCenter = Qt.binding(centerExpr);
        }
        if (!popouts.hasCurrent)
            popouts.hasCurrent = true;
    }

    // Closes the current popout. currentCenter is deliberately left alone so the popout
    // retracts straight down behind the bar instead of also sliding sideways on its way out.
    function closePopout(): void {
        closeTray();
        if (popouts.hasCurrent)
            popouts.hasCurrent = false;
    }

    function checkPopout(x: real): void {
        const ch = childAt(x, height / 2) as EntryWrapper;

        if (ch?.entryId !== "tray")
            closeTray();

        // Pointer in one of the bar's spacing gaps: leave the open popout alone instead of
        // flickering it away (leaving the bar is what closes it).
        if (!ch)
            return;

        const id = ch.entryId;
        const left = ch.x;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as StatusIcons).items;
            const localX = mapToItem(items, x, 0).x;
            const icon = items.childAt(localX, items.height / 2);
            // Landing in a gap leaves the open popout open. Closing here makes it dive
            // under the bar and pop back up every time the pointer crosses one.
            if (icon)
                setPopout(icon.name, icon, () => ch.x + items.x + icon.x + icon.width / 2);
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as Tray;
            if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(mapToItem(tray.expandIcon, x, tray.implicitHeight / 2)))) {
                const index = Math.floor(((x - left - tray.padding * 2 + tray.spacing) / tray.layout.implicitWidth) * tray.items.count);
                const trayItem = tray.items.itemAt(index);
                if (trayItem)
                    setPopout(`traymenu${index}`, trayItem, () => ch.x + tray.layout.x + trayItem.x + trayItem.width / 2);
                else
                    closePopout();
            } else {
                closePopout();
                tray.expanded = true;
            }
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            const item = ch.item as Item;
            setPopout(id.toLowerCase(), item, () => ch.x + item.width / 2);
        }
        // Entries without a popout (logo, workspaces, clock, utilities, power) stay a no-op;
        // leaving the bar is what closes the popout (Interactions.qml).
    }

    function handleWheel(x: real, angleDelta: point): void {
        const ch = childAt(x, height / 2) as EntryWrapper;
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            const mon = (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (x < width / 2 && Config.bar.scrollActions.volume) {
            // Volume scroll on left half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on right half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    spacing: Tokens.spacing.medium

    Repeater {
        id: repeater

        model: ScriptModel {
            values: root.Config.bar.entries.values.filter(e => e.enabled)
        }

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: EntryWrapper {
                    // The first spacer absorbs the imbalance caused by the unequal widths of the left and right clusters,
                    // so the active window entry lands exactly on the bar's centre. The rest just fill.
                    readonly property bool biased: root.centeringActiveWindow && index === root.firstSpacerIndex

                    Layout.fillWidth: !biased
                    Layout.preferredWidth: biased ? root.centerBias : 0
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: EntryWrapper {
                    OsIcon {
                        objectName: "taskbarLogo"
                    }
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: EntryWrapper {
                    Workspaces {
                        objectName: "taskbarWorkspaces"
                        screen: root.screen
                        fullscreen: root.fullscreen
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: EntryWrapper {
                    ActiveWindow {
                        objectName: "taskbarActiveWindow"
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: EntryWrapper {
                    Tray {
                        objectName: "taskbarTray"
                    }
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: EntryWrapper {
                    Clock {
                        objectName: "taskbarClock"
                    }
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: EntryWrapper {
                    StatusIcons {
                        objectName: "taskbarStatusIcons"
                    }
                }
            }
            DelegateChoice {
                roleValue: "utilities"
                delegate: EntryWrapper {
                    Utilities {
                        objectName: "taskbarUtilities"
                        screenState: root.screenState
                    }
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: EntryWrapper {
                    Power {
                        objectName: "taskbarPowerButton"
                        screenState: root.screenState
                    }
                }
            }
        }
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData.id

        Layout.leftMargin: index === 0 ? root.paddingLeft : 0
        Layout.rightMargin: index === repeater.count - 1 ? root.paddingRight : 0
        Layout.alignment: Qt.AlignVCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        children: item
    }
}
