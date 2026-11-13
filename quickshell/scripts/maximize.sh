#!/bin/sh
info=$(hyprctl activewindow -j)
fs=$(echo "$info" | grep -o '"fullscreen": [0-9]' | grep -o '[0-9]$')
fl=$(echo "$info" | grep -o '"floating": [a-z]*' | grep -o '[a-z]*$')

if [ "$fs" != "0" ]; then
    hyprctl --batch "dispatch fullscreen 1 ; dispatch setfloating ; dispatch resizeactive exact 70% 75% ; dispatch centerwindow"
elif [ "$fl" = "true" ]; then
    hyprctl --batch "dispatch settiled ; dispatch fullscreen 1"
else
    hyprctl dispatch fullscreen 1
fi
