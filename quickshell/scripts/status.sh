#!/bin/sh
w=$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi list --rescan no 2>/dev/null | grep '^yes' | head -1)
echo "WIFI ${w#yes:}"
echo "RADIO $(nmcli radio wifi 2>/dev/null)"
echo "BT $(bluetoothctl show 2>/dev/null | grep -c 'Powered: yes')"
echo "MIN $(hyprctl workspaces 2>/dev/null | awk '/special:minimized/{f=1} f && /windows:/{print $2; exit}')"
