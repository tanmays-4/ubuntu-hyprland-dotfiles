#!/bin/sh
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y%m%d-%H%M%S).png"

if [ "$1" = "area" ]; then
    region=$(slurp) || exit 0
    grim -g "$region" "$file"
else
    grim "$file"
fi

wl-copy < "$file"
notify-send "Screenshot saved" "Copied to clipboard"
