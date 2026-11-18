#!/usr/bin/env python3
# Usage: snap.py <layout> [window-address]
# layouts: fill (maximise), toggle, left, right, top, bottom, tl, tr, bl, br, center
import json, subprocess, sys

GAP = 4

def hypr(*args):
    return subprocess.run(["hyprctl", *args], capture_output=True, text=True).stdout

layout = sys.argv[1] if len(sys.argv) > 1 else "fill"
addr = sys.argv[2] if len(sys.argv) > 2 else ""
if layout == "max":
    layout = "fill"

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
target = "address:" + win["address"]

# screen size in logical pixels (1920x1200 at 1.25 = 1536x960)
mons = json.loads(hypr("monitors", "-j"))
mon = next((m for m in mons if m["id"] == win["monitor"]), mons[0])
W = round(mon["width"] / mon["scale"])
H = round(mon["height"] / mon["scale"])

# usable area: whole screen minus a small gap (the bar auto-hides, so it is ignored)
X = mon["x"] + GAP
Y = mon["y"] + GAP
AW = W - 2 * GAP
AH = H - 2 * GAP
hw = (AW - GAP) // 2
hh = (AH - GAP) // 2
rw = AW - hw - GAP
bh = AH - hh - GAP

zones = {
    "fill":   (0, 0, AW, AH),
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

# toggle: maximised -> centred window, anything else -> maximised
if layout == "toggle":
    w, h = win["size"]
    filled = win["floating"] and abs(w - AW) <= 4 and abs(h - AH) <= 4
    layout = "center" if filled else "fill"

x, y, w, h = zones.get(layout, zones["fill"])

cmds = []
if win["fullscreen"] != 0:
    cmds += [f"dispatch focuswindow {target}", "dispatch fullscreenstate 0 0"]
if not win["floating"]:
    cmds.append(f"dispatch setfloating {target}")
cmds.append(f"dispatch resizewindowpixel exact {w} {h},{target}")
cmds.append(f"dispatch movewindowpixel exact {X + x} {Y + y},{target}")
cmds.append(f"dispatch alterzorder top,{target}")

subprocess.run(["hyprctl", "--batch", " ; ".join(cmds)])
