#!/usr/bin/env bash
# Fonts Fedora doesn't package for this setup: Material Symbols Rounded.
# (Rubik + Cascadia Code NF come from dnf: google-rubik-fonts,
#  cascadia-code-nf-fonts. GoogleSansFlex ships inside the shell repo.)
set -e
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -fL -o "MaterialSymbolsRounded.ttf" \
  "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
fc-cache -f ~/.local/share/fonts
fc-match "Material Symbols Rounded"
