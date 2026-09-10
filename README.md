# FedoraCaelestiaConfig

My personal Fedora + Hyprland + Sidera (Caelestia fork) setup. Everything needed
to replicate my desktop on a fresh Fedora 44 machine.

> Shell code itself lives upstream:
> - Shell: https://github.com/tarbai771/sidera-shell (Fedora fork of Caelestia)
> - CLI: https://github.com/caelestia-dots/cli
>
> This repo holds **my configs, keybinds, login entries, helper scripts, fonts**.

## Contents

| Path | Installs to | What |
|---|---|---|
| `config/caelestia/shell.json` | `~/.config/caelestia/` | Shell settings (nord scheme, nautilus/ghostty apps, border 8/6) |
| `config/hypr/hyprland.lua` | `~/.config/hypr/` | Hyprland Lua config (needs `dms/` modules OR edit out those requires) |
| `config/hypr/sidera-binds.lua` | `~/.config/hypr/` | Sidera keybinds, required from `hyprland.lua` |
| `local/bin/caelestia-shell` | `~/.local/bin/` | Shell launcher (sets lib/QML paths) |
| `local/bin/sidera-emptyws-barwatcher` | `~/.local/bin/` | Bar visible on empty workspaces (event-driven) |
| `local/bin/start-hyprland-*` | `~/.local/bin/` | Login-entry wrappers (DMS vs Caelestia) |
| `sessions/*.desktop` | `/usr/share/wayland-sessions/` | "Hyprland (DMS)" + "Hyprland (Caelestia)" login entries |
| `fonts/install-fonts.sh` | — | Downloads Material Symbols Rounded (the one Fedora lacks) |
| `packages-fedora.txt` | — | All dnf packages this setup needs |
| `sidera-REMOVAL.sh` | — | One-shot uninstaller |

## Fresh-install steps (Fedora 44)

```bash
# 1. Hyprland COPR + system packages
sudo dnf install dnf-plugins-core
sudo dnf copr enable -y ashbuk/Hyprland-Fedora
sudo dnf install -y $(grep -v '^#' packages-fedora.txt | tr '\n' ' ')

# 2. Shell (Sidera fork)
git clone https://github.com/tarbai771/sidera-shell.git ~/sidera-shell
cd ~/sidera-shell
cmake -S . -B build-fedora -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$HOME/.local" \
  -DINSTALL_LIBDIR="$HOME/.local/lib64/caelestia" \
  -DINSTALL_QMLDIR="$HOME/.local/lib64/qt6/qml" \
  -DINSTALL_QSCONFDIR="$HOME/.config/quickshell/caelestia" \
  -DDISTRIBUTOR="fedora"
cmake --build build-fedora
cmake --install build-fedora

# 3. CLI (needed for Settings button, wallpaper, clipboard...)
python3 -m pip install --user "git+https://github.com/caelestia-dots/cli.git"
sudo dnf install -y fuzzel cliphist  # clipboard/emoji pickers

# 4. This repo's configs (replace sriyaan with your username where needed)
git clone <this-repo> ~/FedoraCaelestiaConfig
cd ~/FedoraCaelestiaConfig
grep -rl sriyaan . | xargs sed -i "s|/home/sriyaan|/home/$USER|g"
cp config/caelestia/shell.json ~/.config/caelestia/
cp config/hypr/hyprland.lua config/hypr/sidera-binds.lua ~/.config/hypr/
cp local/bin/* ~/.local/bin/ && chmod +x ~/.local/bin/*
sudo cp sessions/*.desktop /usr/share/wayland-sessions/
bash fonts/install-fonts.sh

# 5. Log out -> pick "Hyprland (Caelestia)"
```

## Keybinds (Sidera)

| Keys | Action |
|---|---|
| Tap SUPER / SUPER+space | Launcher (Settings lives at `>Settings`) |
| CTRL+ALT+Delete / SUPER+X | Powermenu |
| SUPER+N | Sidebar (notifications) |
| SUPER+G | Quick toggles |
| SUPER+comma | Settings directly |
| SUPER+M | Dashboard |
| SUPER+ALT+L | Lock |
| SUPER+SHIFT+S | Screenshot picker |
| Media/volume keys | Shell OSD + wpctl |
| CTRL+SUPER+ALT+R | Restart shell |

## Notes

- `hyprland.lua` sources `dms.*` modules (my DMS setup). Without DMS installed,
  comment those `require` lines out.
- Wallpaper dir: `~/Pictures/Wallpapers`. Scheme: `caelestia scheme set -n <name>`.
- `lua` package is required or HyprMod/GUI tools can't parse `hyprland.lua`.
- Screen recording (`caelestia record`) needs `gpu-screen-recorder`, which has
  no Fedora package.
