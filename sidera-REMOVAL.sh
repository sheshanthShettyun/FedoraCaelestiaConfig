#!/usr/bin/env bash
# Sidera/Caelestia full removal — reverses everything installed on 2026-09-10.
# NOTHING here touches DMS, old quickshell configs, or the rest of Hyprland.
# Review, then run:  bash ~/sidera-REMOVAL.sh
set -e

echo "--- 1. stop shell + clipboard watchers"
pkill -f 'quickshell/caelestia' || true
pkill -f 'wl-paste --type text --watch cliphist store' || true
pkill -f 'wl-paste --type image --watch cliphist store' || true
systemctl --user stop caelestia.service 2>/dev/null || true

echo "--- 2. remove shell files"
rm -rf ~/.config/quickshell/caelestia
rm -rf ~/.local/lib64/caelestia
rm -rf ~/.local/lib64/qt6/qml/Caelestia
rm -rf ~/.local/lib64/qt6/qml/M3Shapes
rm -f ~/.local/bin/caelestia-shell
rm -rf ~/sidera-shell

echo "--- 3. remove CLI (pip)"
python3 -m pip uninstall -y caelestia materialyoucolor 2>/dev/null || true
rm -f ~/.local/bin/caelestia

echo "--- 4. remove fonts added for Sidera"
rm -f ~/.local/share/fonts/MaterialSymbolsRounded.ttf
fc-cache -f ~/.local/share/fonts >/dev/null 2>&1 || true

echo "--- 5. remove shell state + config (keeps ~/Pictures/Wallpapers)"
rm -rf ~/.config/caelestia
rm -rf ~/.local/state/caelestia

echo "--- 6. remove Hyprland additions"
rm -f ~/.config/hypr/sidera-binds.lua ~/.local/bin/sidera-emptyws-barwatcher
rm -f /run/user/$(id -u)/sidera-emptyws-bar.lock
echo "--- 6b. remove login entries + wrappers"
rm -f ~/.local/bin/start-hyprland-dms ~/.local/bin/start-hyprland-caelestia
echo "sudo rm -f /usr/share/wayland-sessions/hyprland-dms.desktop /usr/share/wayland-sessions/hyprland-caelestia.desktop"
echo "MANUAL: delete these lines from ~/.config/hypr/hyprland.lua:"
echo '  require("sidera-binds")'
echo '  the Sidera clipboard-watchers hl.on("hyprland.start", ...) block'
echo '  the HYPR_SHELL/caelestia-shell autostart lines in hl.on("hyprland.start", ...)'

echo "--- 7. remove dnf packages pulled for Sidera (skip any you want to keep)"
echo "sudo dnf remove -y qt6-qtshadertools-devel swappy fish mako hyprpaper \\"
echo "  aubio-devel libqalculate-devel fftw-devel lm_sensors-devel pipewire-devel \\"
echo "  qt6-qtsvg-devel qt6-qtimageformats google-rubik-fonts cascadia-code-nf-fonts fuzzel"

echo "--- 8. back to DMS"
echo "systemctl --user start dms.service"
echo "Backup of pre-Sidera configs: ~/sidera-safe-backup-20260910-163139"
echo DONE
