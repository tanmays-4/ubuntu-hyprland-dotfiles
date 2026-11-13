#!/bin/sh
head -1 /proc/stat | sed 's/^cpu/CPU/'
awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print "MEM", t, a}' /proc/meminfo
echo "TEMP $(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)"
awk -F: '/^cpu MHz/{s+=$2; n++} END{if (n) printf "FREQ %d\n", s/n}' /proc/cpuinfo
echo "THREADS $(nproc)"
df -B1 / | awk 'NR==2{print "DISK", $3, $2}'
awk 'NR>2 && $1 !~ /^lo:/ {gsub(":", " "); rx+=$2; tx+=$10} END{print "NET", rx, tx}' /proc/net/dev
awk '{print "UP", int($1)}' /proc/uptime
