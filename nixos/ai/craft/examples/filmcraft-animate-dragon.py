"""Keyframe a 3-second dragon animation live in FilmCraft (filmcraft --control PORT).

usage: FILMCRAFT_CONTROL_TOKEN=... python3 -I animate.py FILMCRAFT_CLI PORT [delay]
Clip ids: bg=15 farwing=16 body=17 frontwing=18 fire=19 title=20 (from timeline.place).
"""

import json
import math
import subprocess
import sys
import time

CLI, PORT = sys.argv[1], sys.argv[2]
DELAY = float(sys.argv[3]) if len(sys.argv) > 3 else 0.12
T = 254016000000  # ticks per second
BG, FARWING, BODY, FRONTWING, FIRE, TITLE = 15, 16, 17, 18, 19, 20
MOTION, OPACITY = 0, 1


class Mcp:
    def __init__(self):
        self.p = subprocess.Popen([CLI, "--bridge", f"127.0.0.1:{PORT}", "mcp"],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
        self.n = 0
        self.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                "clientInfo": {"name": "animate", "version": "1"}})
        self.p.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + "\n")

    def rpc(self, method, params):
        self.n += 1
        self.p.stdin.write(json.dumps({"jsonrpc": "2.0", "id": self.n, "method": method, "params": params}) + "\n")
        self.p.stdin.flush()
        while True:
            m = json.loads(self.p.stdout.readline())
            if m.get("id") == self.n:
                if "error" in m:
                    raise RuntimeError(m["error"])
                return m["result"]

    def tool(self, _tool, **args):
        r = self.rpc("tools/call", {"name": _tool, "arguments": args})
        if r.get("isError"):
            raise RuntimeError(f"{_tool}: {r['content'][0].get('text')}")
        return r

    def cmd(self, cid, **params):
        return self.tool("command_run", id=cid, params=params)


pc = Mcp()
keys_for_smoothing = []


def at(sec):
    return round(sec * T)


def key(clip, param, sec, value, effect=MOTION, smooth=True, show=True):
    if show:
        pc.cmd("playhead.set", seconds=sec)
    pc.cmd("effects.setParam", clip=clip, effect=effect, param=param, value=value, time=at(sec), keyframe=True)
    if smooth:
        keys_for_smoothing.append({"clip": clip, "effect": effect, "param": param, "time": at(sec)})
    time.sleep(DELAY)


def static(clip, param, value, effect=MOTION):
    pc.cmd("effects.setParam", clip=clip, effect=effect, param=param, value=value)


# ---- shared hover motion: bob 14 px on a 1.5 s cycle, drift 24 px forward
def hover(sec):
    return 24 * sec / 3, -14 * math.sin(2 * math.pi * sec / 1.5)


BOB_TIMES = [i * 0.375 for i in range(9)]       # quarter cycles of the bob
FLAP_TIMES = [i * 0.25 for i in range(13)]      # quarter cycles of a 1 s wing beat

print("▶ background: slow push-in + shake when the fire hits", flush=True)
key(BG, "scale", 0.0, 100.0)
key(BG, "scale", 3.0, 104.0)
for sec, (x, y) in [(0.98, (800, 500)), (1.05, (807, 496)), (1.12, (794, 504)), (1.2, (804, 498)),
                    (1.3, (798, 501)), (1.42, (800, 500))]:
    key(BG, "position", sec, [x, y], smooth=False)

print("▶ body: hover", flush=True)
for s in BOB_TIMES:
    dx, dy = hover(s)
    key(BODY, "position", s, [800 + dx, 500 + dy])


def wing(clip, shoulder, down_rot, up_rot, down_h, up_h, name):
    print(f"▶ {name}: pivot at the shoulder, flap ×3 while hovering", flush=True)
    static(clip, "anchor", list(shoulder))
    static(clip, "uniform_scale", False)
    for s in BOB_TIMES:
        dx, dy = hover(s)
        key(clip, "position", s, [shoulder[0] + dx, shoulder[1] + dy], show=False)
    phase_rot = [0, down_rot, 0, up_rot]
    phase_h = [100, down_h, 100, up_h]
    for i, s in enumerate(FLAP_TIMES):
        key(clip, "rotation", s, float(phase_rot[i % 4]))
        key(clip, "scale", s, float(phase_h[i % 4]), show=False)


# front wing reaches up-left: a downstroke turns it anticlockwise; far wing (up-right) clockwise
wing(FARWING, (870, 460), 14, -10, 80, 104, "far wing")
wing(FRONTWING, (860, 470), -18, 12, 76, 106, "front wing")

print("▶ fire: burst from the mouth at 1.0 s, then flicker", flush=True)
mouth = (1190, 312)
static(FIRE, "anchor", list(mouth))
for s in BOB_TIMES:
    dx, dy = hover(s)
    key(FIRE, "position", s, [mouth[0] + dx, mouth[1] + dy], show=False)
key(FIRE, "opacity", 0.0, 0.0, effect=OPACITY, smooth=False)
key(FIRE, "opacity", 0.98, 0.0, effect=OPACITY, smooth=False)
key(FIRE, "opacity", 1.1, 100.0, effect=OPACITY, smooth=False)
key(FIRE, "scale", 0.98, 5.0)
key(FIRE, "scale", 1.3, 108.0)
key(FIRE, "scale", 1.45, 96.0)
flick = [102, 95, 104, 97, 101, 94, 103, 96, 100, 95, 103, 98]
for i, v in enumerate(flick):
    key(FIRE, "scale", 1.6 + i * 0.12, float(v))

print("▶ title: fade + settle in at 2 s", flush=True)
static(TITLE, "anchor", [800, 936])
static(TITLE, "position", [800, 936])
key(TITLE, "opacity", 0.0, 0.0, effect=OPACITY, smooth=False)
key(TITLE, "opacity", 1.9, 0.0, effect=OPACITY, smooth=False)
key(TITLE, "opacity", 2.5, 100.0, effect=OPACITY, smooth=False)
key(TITLE, "scale", 1.9, 88.0)
key(TITLE, "scale", 2.6, 100.0)

print(f"▶ smoothing {len(keys_for_smoothing)} keyframes (continuous bezier)", flush=True)
pc.cmd("effects.setInterpolation", keyframes=keys_for_smoothing, interpolation="continuousBezier")

pc.cmd("playhead.set", seconds=0)
print("done", flush=True)
