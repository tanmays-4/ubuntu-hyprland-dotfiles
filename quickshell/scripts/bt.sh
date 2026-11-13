#!/bin/sh
connected=$(bluetoothctl devices Connected | awk '{print $2}')
paired=$(bluetoothctl devices Paired | awk '{print $2}')

bluetoothctl devices Paired | while read -r _ mac name; do
    c=0
    echo "$connected" | grep -q "$mac" && c=1
    echo "P|$mac|$c|$name"
done

bluetoothctl devices | while read -r _ mac name; do
    echo "$paired" | grep -q "$mac" || echo "N|$mac|0|$name"
done
