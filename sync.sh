#!/usr/bin/env bash
# Copies the current configs into this repo. Run before every commit.
set -e
cd "$(dirname "$0")"

rm -rf hypr quickshell grub applications wallpapers
mkdir -p hypr quickshell grub applications wallpapers

cp ~/.config/hypr/*.conf hypr/
cp -r ~/.config/quickshell/. quickshell/
cp -r /boot/grub/themes/mono grub/ 2>/dev/null || echo "skipped grub theme"
cp ~/.local/share/applications/apple-music.desktop applications/ 2>/dev/null || true

WALL=$(find ~ -name flower.jpg -not -path "*/dotfiles/*" 2>/dev/null | head -1)
[ -n "$WALL" ] && cp "$WALL" wallpapers/flower.jpg

echo "synced:"; ls
