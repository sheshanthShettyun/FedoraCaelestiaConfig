-- Sidera (Caelestia) shell keybinds — important ones only.
-- Separate file so DMS binds stay untouched. Toggle by commenting the
-- require("sidera-binds") line in hyprland.lua.
-- NOTE: keys already owned by dms/binds.lua are avoided on purpose.

-- Guard: older hl Lua API may lack dsp.global (Hyprland global shortcuts).
local has_global = hl.dsp ~= nil and hl.dsp.global ~= nil
local function shell_global(name)
    if has_global then
        return hl.dsp.global(name)
    end
    return hl.dsp.exec_cmd("notify-send 'Sidera' 'needs Hyprland global shortcuts: " .. name .. "'")
end

local locked = { locked = true }
local locked_repeating = { locked = true, repeating = true }

-- === Shell: launcher / session / sidebar / lock ===
-- Tap SUPER alone for launcher (release, so holding SUPER still works as modifier)
hl.bind("SUPER + SUPER_L", shell_global("caelestia:launcher"), { release = true })
-- Powermenu (CTRL+ALT+Delete also fires the dead DMS bind, which fails silently while DMS is stopped)
hl.bind("CTRL + ALT + Delete", shell_global("caelestia:session"))
-- Sidebar / notifications panel
hl.bind("SUPER + N", shell_global("caelestia:sidebar"))
-- Quick toggles panel (decoupled from sidebar)
hl.bind("SUPER + G", shell_global("caelestia:utilities"))
-- Lock (SUPER+L is focus-right in DMS binds, so use SUPER+ALT+L like DMS did)
hl.bind("SUPER + ALT + L", shell_global("caelestia:lock"))
-- Clear notifications
hl.bind("CTRL + ALT + C", shell_global("caelestia:clearNotifs"), locked)

-- === Shell: screenshots (in-shell picker, no CLI needed) ===
hl.bind("SUPER + SHIFT + S", shell_global("caelestia:screenshotFreeze"))
hl.bind("SUPER + SHIFT + ALT + S", shell_global("caelestia:screenshot"))

-- === Media keys (shell handles OSD) ===
hl.bind("XF86AudioPlay", shell_global("caelestia:mediaToggle"), locked)
hl.bind("XF86AudioPause", shell_global("caelestia:mediaToggle"), locked)
hl.bind("XF86AudioNext", shell_global("caelestia:mediaNext"), locked)
hl.bind("XF86AudioPrev", shell_global("caelestia:mediaPrev"), locked)
hl.bind("XF86AudioStop", shell_global("caelestia:mediaStop"), locked)

-- === Volume via wpctl (DMS audio binds are dead while DMS is stopped) ===
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), locked)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), locked)
hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"),
    locked_repeating
)
hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    locked_repeating
)

-- === Brightness: NOT bound here — hyprland.lua already has working
-- brightnessctl binds. Adding shell globals on top would double-step.

-- === DMS-matched keys: same muscle memory, Sidera actions ===
-- (each also fires its dead DMS `dms ipc` bind, which fails silently
-- while DMS is stopped)
-- Launcher on DMS spotlight key
hl.bind("SUPER + space", shell_global("caelestia:launcher"))
-- Powermenu on DMS powermenu key
hl.bind("SUPER + X", shell_global("caelestia:session"))
-- Settings on DMS settings key
hl.bind("SUPER + comma", hl.dsp.exec_cmd("caelestia shell nexus open"))
-- Dashboard on DMS processlist key (closest match: performance + media)
hl.bind("SUPER + M", shell_global("caelestia:dashboard"))
-- Clipboard history + emoji via CLI + fuzzel (toggle pattern)
hl.bind("SUPER + V", hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard"))
hl.bind("SUPER + ALT + V", hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard -d"))
hl.bind("SUPER + Period", hl.dsp.exec_cmd("pkill fuzzel || caelestia emoji -p"))

-- === Restart Sidera shell (handy after config/font changes) ===
hl.bind(
    "CTRL + SUPER + ALT + R",
    hl.dsp.exec_cmd("sh -c 'notify-send -t 2000 Sidera restarting; pkill -f quickshell/caelestia; sleep 0.5; /home/sriyaan/.local/bin/caelestia-shell -d; notify-send -t 2000 Sidera started'")
)
