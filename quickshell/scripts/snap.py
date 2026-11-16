#!/usr/bin/env python3
# Usage: snap.py <layout> [window-address]
# layouts: left right top bottom tl tr bl br center max
import json, subprocess, sys

GAP = 4

def hypr(*args):
    return subprocess.run(["hyprctl", *args], capture_output=True, text=True).stdout

layout = sys.argv[1] if len(sys.argv) > 1 else "left"
addr = sys.argv[2] if len(sys.argv) > 2 else ""

# find the window
win = None
try:
    if addr:
        win = next((c for c in json.loads(hypr("clients", "-j")) if c["address"] == addr), None)
    else:
        win = json.loads(hypr("activewindow", "-j"))
except Exception:
    pass
if not win or not win.get("address") or win["workspace"]["id"] < 0:
    sys.exit(0)
addr = win["address"]
target = "address:" + addr

# screen size in logical pixels (after 1.25 scaling)
mons = json.loads(hypr("monitors", "-j"))
mon = next((m for m in mons if m["id"] == win["monitor"]), mons[0])
W = round(mon["width"] / mon["scale"])
H = round(mon["height"] / mon["scale"])
rl, rt, rr, rb = mon.get("reserved", [0, 0, 0, 0])

X = mon["x"] + rl + GAP
Y = mon["y"] + rt + GAP
AW = W - rl - rr - 2 * GAP
AH = H - rt - rb - 2 * GAP
hw = (AW - GAP) // 2
hh = (AH - GAP) // 2
rw = AW - hw - GAP
bh = AH - hh - GAP

zones = {
    "left":   (0, 0, hw, AH),
    "right":  (hw + GAP, 0, rw, AH),
    "top":    (0, 0, AW, hh),
    "bottom": (0, hh + GAP, AW, bh),
    "tl":     (0, 0, hw, hh),
    "tr":     (hw + GAP, 0, rw, hh),
    "bl":     (0, hh + GAP, hw, bh),
    "br":     (hw + GAP, hh + GAP, rw, bh),
    "center": (int(AW * 0.15), int(AH * 0.125), int(AW * 0.7), int(AH * 0.75)),
}

cmds = [f"dispatch focuswindow {target}"]

if layout == "max":
    if win["floating"]:
        cmds.append(f"dispatch settiled {target}")
    if win["fullscreen"] == 0:
        cmds.append("dispatch fullscreen 1")
else:
    x, y, w, h = zones.get(layout, zones["left"])
    if win["fullscreen"] != 0:
        cmds.append("dispatch fullscreenstate 0 0")
    if not win["floating"]:
        cmds.append(f"dispatch setfloating {target}")
    cmds.append(f"dispatch resizewindowpixel exact {w} {h},{target}")
    cmds.append(f"dispatch movewindowpixel exact {X + x} {Y + y},{target}")

subprocess.run(["hyprctl", "--batch", " ; ".join(cmds)])
