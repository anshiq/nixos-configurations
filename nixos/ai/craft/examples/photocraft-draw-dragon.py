"""Draw a dragon live in a running PhotoCraft (photocraft --control PORT) via the MCP bridge.

usage: python3 -I dragon.py PHOTOCRAFT_CLI PORT TOKEN_FILE [delay_seconds]
"""

import base64
import json
import math
import subprocess
import sys
import time

CLI, PORT, TOKEN = sys.argv[1], sys.argv[2], sys.argv[3]
DELAY = float(sys.argv[4]) if len(sys.argv) > 4 else 0.7
OUT = sys.argv[5] if len(sys.argv) > 5 else None

W, H = 1600, 1000


# ---------------------------------------------------------------- MCP client
class Mcp:
    def __init__(self):
        self.p = subprocess.Popen(
            [CLI, "mcp", "--bridge", PORT, "--control-token-file", TOKEN],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1,
        )
        self.n = 0
        self.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                "clientInfo": {"name": "dragon", "version": "1"}})
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def send(self, msg):
        self.p.stdin.write(json.dumps(msg) + "\n")
        self.p.stdin.flush()

    def rpc(self, method, params):
        self.n += 1
        self.send({"jsonrpc": "2.0", "id": self.n, "method": method, "params": params})
        while True:
            line = self.p.stdout.readline()
            if not line:
                raise RuntimeError("bridge closed")
            msg = json.loads(line)
            if msg.get("id") == self.n:
                if "error" in msg:
                    raise RuntimeError(msg["error"])
                return msg["result"]

    def tool(self, _tool, **args):
        r = self.rpc("tools/call", {"name": _tool, "arguments": args})
        if r.get("isError"):
            raise RuntimeError(f"{_tool}: {r['content'][0].get('text', r)}")
        return r

    def cmd(self, cid, label=None, **params):
        print(f"  • {label or cid}", flush=True)
        r = self.tool("command_run", id=cid, params=params)
        time.sleep(DELAY)
        return r


# ---------------------------------------------------------------- geometry
def smooth(pts, closed=True, tension=0.5):
    """Catmull-Rom -> bezier knots. A point (x, y, 'c') is a sharp corner."""
    n = len(pts)
    knots = []
    for i, p in enumerate(pts):
        x, y = p[0], p[1]
        if len(p) > 2 and p[2] == "c":
            knots.append([round(x, 1), round(y, 1)])
            continue
        prev = pts[(i - 1) % n] if (closed or i > 0) else p
        nxt = pts[(i + 1) % n] if (closed or i < n - 1) else p
        dx, dy = (nxt[0] - prev[0]) * tension / 3, (nxt[1] - prev[1]) * tension / 3
        knots.append({"anchor": [round(x, 1), round(y, 1)],
                      "in": [round(x - dx, 1), round(y - dy, 1)],
                      "out": [round(x + dx, 1), round(y + dy, 1)], "smooth": True})
    return knots


def path(*subpaths, closed=True):
    return {"subpaths": [{"closed": closed, "knots": smooth(s, closed)} for s in subpaths]}


def resample(center, n):
    """Points evenly spaced along a polyline."""
    segs = [math.dist(a, b) for a, b in zip(center, center[1:])]
    total = sum(segs)
    out = []
    for k in range(n):
        d = total * k / (n - 1)
        for i, s in enumerate(segs):
            if d <= s or i == len(segs) - 1:
                t = min(d / s, 1) if s else 0
                a, b = center[i], center[i + 1]
                out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
                break
            d -= s
    return out


def frames(pts):
    """(point, tangent, normal) along a polyline; normal = left of travel."""
    res = []
    for i, p in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        l = math.hypot(tx, ty) or 1
        tx, ty = tx / l, ty / l
        res.append((p, (tx, ty), (-ty, tx)))
    return res


def band(center, widths, n=24, tip=True):
    """Closed outline of a tapered tube along `center`; widths(t) gives width at t in 0..1."""
    pts = resample(center, n)
    fr = frames(pts)
    a, b = [], []
    for k, (p, _, nrm) in enumerate(fr):
        w = widths(k / (n - 1)) / 2
        a.append((p[0] + nrm[0] * w, p[1] + nrm[1] * w))
        b.append((p[0] - nrm[0] * w, p[1] - nrm[1] * w))
    if tip:
        end = pts[-1]
        return a[:-1] + [(end[0], end[1], "c")] + b[-2::-1]
    return a + b[::-1]


def spikes(center, n, size, start=0.0, end=1.0, side=1, offset=None):
    """Triangular spikes along `center` on the left (side=1) of travel."""
    pts = resample(center, 80)
    fr = frames(pts)
    subs = []
    for k in range(n):
        t = start + (end - start) * k / max(n - 1, 1)
        p, tg, nrm = fr[int(t * (len(fr) - 1))]
        s = size(t) if callable(size) else size
        off = (offset(t) if callable(offset) else (offset or 0)) * side
        bx, by = p[0] + nrm[0] * off, p[1] + nrm[1] * off
        nx, ny = nrm[0] * side, nrm[1] * side
        subs.append([
            (bx - tg[0] * s * 0.55, by - tg[1] * s * 0.55, "c"),
            (bx + nx * s * 1.1 - tg[0] * s * 0.5, by + ny * s * 1.1 - tg[1] * s * 0.5, "c"),
            (bx + tg[0] * s * 0.55, by + tg[1] * s * 0.55, "c"),
        ])
    return subs


def grad(*stops, angle=90, style="linear"):
    n = len(stops) - 1
    return {"gradient": {"stops": [[i / n, c] for i, c in enumerate(stops)],
                         "angle": angle, "style": style}}


# ---------------------------------------------------------------- the scene
def main():
    pc = Mcp()
    shape = lambda label, **kw: pc.cmd("shape.create", label, **kw)

    print("▶ new canvas", flush=True)
    pc.tool("doc_new", width=W, height=H, name="Dragon", background="#0b0a1f")
    time.sleep(1.0)
    try:
        pc.tool("ui_set", fields={"fit": True})
    except RuntimeError as e:
        print("  (fit skipped:", e, ")")

    print("▶ sky", flush=True)
    shape("night sky", kind="rect", rect=[0, 0, W, H], name="Sky",
          fill=grad("#3b1d5e", "#1a1440", "#070818", angle=90))
    stars = []
    import random
    rnd = random.Random(7)
    for _ in range(90):
        x, y = rnd.uniform(10, W - 10), rnd.uniform(10, 620)
        r = rnd.choice([1.2, 1.6, 2.2, 3.2])
        stars.append([(x, y - r * 2, "c"), (x + r * 0.6, y - r * 0.6, "c"), (x + r * 2, y, "c"),
                      (x + r * 0.6, y + r * 0.6, "c"), (x, y + r * 2, "c"), (x - r * 0.6, y + r * 0.6, "c"),
                      (x - r * 2, y, "c"), (x - r * 0.6, y - r * 0.6, "c")])
    shape("stars", kind="path", path=path(*stars), fill="#fff6d6", name="Stars")
    pc.cmd("layer.layerStyle.outerGlow", "stars glow", color="#bcd4ff", size=6, opacity=70, spread=0)

    print("▶ moon", flush=True)
    shape("moon", kind="ellipse", rect=[1290, 70, 170, 170], name="Moon",
          fill=grad("#fffbe8", "#f3e3a8", angle=135, style="radial"))
    pc.cmd("layer.layerStyle.outerGlow", "moon glow", color="#ffe9a8", size=70, opacity=55, spread=5)
    shape("moon craters", kind="path", name="Craters", fill=[0.85, 0.78, 0.55, 0.45], path=path(
        [(1340, 120), (1362, 112), (1372, 130), (1352, 142), (1336, 134)],
        [(1400, 170), (1420, 166), (1426, 186), (1406, 194)],
        [(1325, 180), (1340, 176), (1344, 190), (1330, 194)]))

    print("▶ mountains", flush=True)
    far = [(0, 760)]
    for i, (x, y) in enumerate([(120, 640), (240, 700), (380, 590), (520, 690), (660, 610), (800, 700),
                                (960, 580), (1120, 680), (1260, 600), (1420, 690), (1600, 620)]):
        far.append((x, y, "c"))
    shape("far mountains", kind="path", name="Far mountains", fill=grad("#1a1a3e", "#2c2457", angle=90),
          path=path(far + [(W, H, "c"), (0, H, "c")]))
    near = [(0, 860, "c")]
    for x, y in [(160, 780), (300, 850), (470, 760), (640, 860), (820, 790), (1000, 870), (1180, 770),
                 (1360, 860), (1520, 800), (1600, 840)]:
        near.append((x, y, "c"))
    shape("near mountains", kind="path", name="Near mountains", fill=grad("#05060f", "#11112a", angle=90),
          path=path(near + [(W, H, "c"), (0, H, "c")]))

    # ---- dragon palette
    scale_dark, scale_mid, scale_light = "#0c3b2a", "#1f8a5b", "#58d68d"
    belly1, belly2 = "#f7dc6f", "#d4a017"
    wing_back = grad("#0a2a20", "#145a3e", angle=60)
    wing_front = grad("#0f4a33", "#22a06b", "#7ee2a8", angle=60)

    print("▶ far wing", flush=True)
    far_wing = [(870, 460, "c"), (895, 300), (935, 130, "c"), (1040, 70, "c"), (1010, 160), (1060, 210, "c"),
                (1005, 255), (1030, 330, "c"), (975, 360), (975, 430, "c"), (930, 450)]
    shape("far wing membrane", kind="path", name="Far wing", fill=wing_back, path=path(far_wing))
    shape("far wing bones", kind="path", name="Far wing bones", fill=None,
          stroke={"width": 7, "color": "#0a2219", "cap": "round", "join": "round"},
          path={"subpaths": [
              {"closed": False, "knots": smooth([(870, 460), (895, 300), (935, 130)], False)},
              {"closed": False, "knots": [[935, 130], [1040, 70]]},
              {"closed": False, "knots": [[935, 130], [1060, 210]]},
              {"closed": False, "knots": [[935, 130], [1030, 330]]},
              {"closed": False, "knots": [[935, 130], [975, 430]]}]})

    print("▶ tail", flush=True)
    tail_c = [(640, 590), (520, 640), (400, 705), (280, 735), (180, 715), (115, 660), (95, 590), (115, 540)]
    shape("tail", kind="path", name="Tail", fill=grad(scale_dark, scale_mid, angle=100),
          path=path(band(tail_c, lambda t: 95 * (1 - t) ** 1.1 + 6, n=30)))
    shape("tail spade", kind="path", name="Tail spade", fill=scale_light,
          path=path([(120, 548, "c"), (80, 530), (88, 488, "c"), (128, 500), (150, 520, "c")]))

    print("▶ back leg", flush=True)
    shape("back thigh", kind="path", name="Back leg", fill=grad(scale_dark, scale_mid, angle=120),
          path=path([(560, 560), (660, 545), (700, 610), (680, 680), (640, 720), (600, 700), (570, 640)]))
    shape("back shin", kind="path", name="Back shin", fill=scale_dark,
          path=path(band([(640, 690), (610, 750), (650, 790)], lambda t: 46 - 16 * t, n=12, tip=False)))
    shape("back claws", kind="path", name="Back claws", fill="#f4f1de", path=path(
        [(640, 785, "c"), (678, 800, "c"), (650, 802, "c")],
        [(632, 792, "c"), (662, 815, "c"), (636, 810, "c")],
        [(622, 795, "c"), (640, 822, "c"), (618, 812, "c")]))

    print("▶ body", flush=True)
    body = [(950, 430), (860, 445), (760, 470), (660, 515), (585, 560), (575, 625), (640, 660),
            (760, 655), (870, 615), (950, 560), (985, 495)]
    shape("body", kind="path", name="Body", fill=grad(scale_dark, scale_mid, scale_light, angle=100),
          path=path(body))
    pc.cmd("layer.layerStyle.innerShadow", "body shading", color="#02140d", opacity=60, size=30, distance=12, angle=120)

    print("▶ belly", flush=True)
    belly = [(975, 500), (955, 565), (880, 615), (770, 648), (660, 650), (705, 625), (805, 600),
             (880, 560), (925, 500)]
    shape("belly", kind="path", name="Belly", fill=grad(belly1, belly2, angle=0), path=path(belly))
    lines = [{"closed": False, "knots": [[x0, y0], [x1, y1]]} for (x0, y0, x1, y1) in
             [(930, 515, 965, 520), (905, 560, 950, 570), (865, 590, 905, 605),
              (815, 610, 850, 628), (760, 625, 790, 645), (710, 632, 735, 650)]]
    shape("belly scales", kind="path", name="Belly scales", fill=None,
          stroke={"width": 3, "color": "#a57a10", "cap": "round"}, path={"subpaths": lines})

    print("▶ front leg", flush=True)
    shape("front leg", kind="path", name="Front leg", fill=grad(scale_dark, scale_mid, angle=120),
          path=path(band([(905, 540), (935, 620), (900, 690), (950, 720)], lambda t: 60 - 25 * t, n=16, tip=False)))
    shape("front claws", kind="path", name="Front claws", fill="#f4f1de", path=path(
        [(955, 705, "c"), (995, 712, "c"), (965, 725, "c")],
        [(950, 718, "c"), (985, 735, "c"), (955, 738, "c")],
        [(940, 725, "c"), (965, 752, "c"), (935, 742, "c")]))

    print("▶ neck", flush=True)
    neck_c = [(905, 500), (960, 420), (1010, 350), (1060, 300)]
    shape("neck", kind="path", name="Neck", fill=grad(scale_dark, scale_mid, scale_light, angle=40),
          path=path(band(neck_c, lambda t: 115 - 45 * t, n=16, tip=False)))
    neck_belly = band([(960, 520), (990, 440), (1035, 370), (1085, 325)], lambda t: 26 - 8 * t, n=14, tip=False)
    shape("neck belly", kind="path", name="Neck belly", fill=grad(belly1, belly2, angle=45), path=path(neck_belly))

    print("▶ head", flush=True)
    head = [(1018, 285, "c"), (1050, 245), (1105, 245), (1160, 262), (1208, 282, "c"), (1200, 298, "c"),
            (1118, 310, "c"), (1186, 330, "c"), (1176, 345), (1122, 352), (1068, 340), (1035, 318)]
    shape("head", kind="path", name="Head", fill=grad(scale_mid, scale_light, angle=80), path=path(head))
    pc.cmd("layer.layerStyle.bevelEmboss", "head bevel", style="inner", technique="smooth", size=8, depth=120, soften=4)
    shape("mouth", kind="path", name="Mouth", fill="#5a0e12",
          path=path([(1198, 299, "c"), (1120, 310, "c"), (1184, 329, "c"), (1170, 316)]))
    shape("teeth", kind="path", name="Teeth", fill="#fffdf2", path=path(
        [(1185, 300, "c"), (1180, 312, "c"), (1175, 301, "c")],
        [(1165, 303, "c"), (1160, 314, "c"), (1155, 304, "c")],
        [(1145, 305, "c"), (1141, 315, "c"), (1136, 306, "c")],
        [(1176, 326, "c"), (1172, 316, "c"), (1166, 325, "c")],
        [(1158, 322, "c"), (1155, 313, "c"), (1149, 321, "c")]))

    print("▶ horns", flush=True)
    shape("horns", kind="path", name="Horns", fill=grad("#f5eedc", "#9c8b6e", angle=30), path=path(
        [(1045, 262, "c"), (1010, 228), (968, 205, "c"), (1022, 212), (1072, 248, "c")],
        [(1080, 248, "c"), (1062, 205), (1048, 168, "c"), (1090, 200), (1104, 246, "c")]))
    shape("brow ridge", kind="path", name="Brow", fill=scale_dark,
          path=path([(1088, 258, "c"), (1112, 248), (1138, 256, "c"), (1112, 254)]))

    print("▶ spine spikes", flush=True)
    spine = [(1045, 270), (1000, 320), (955, 385), (905, 440), (820, 460), (720, 490), (640, 535)]
    shape("back spikes", kind="path", name="Back spikes", fill=grad("#0a2a20", "#2bbf7e", angle=90),
          path=path(*spikes(spine, 12, lambda t: 14 + 10 * math.sin(math.pi * t)), closed=True))
    shape("tail spikes", kind="path", name="Tail spikes", fill=grad("#0a2a20", "#2bbf7e", angle=90),
          path=path(*spikes(tail_c, 10, lambda t: 18 * (1 - t) + 6, start=0.05, end=0.8,
                             offset=lambda t: (95 * (1 - t) ** 1.1 + 6) / 2 - 2)))

    print("▶ front wing", flush=True)
    wing = [(860, 470, "c"), (800, 280), (690, 120, "c"), (420, 150, "c"), (520, 235), (455, 315, "c"),
            (560, 345), (525, 430, "c"), (630, 430), (650, 500, "c"), (760, 488)]
    shape("front wing membrane", kind="path", name="Front wing", fill=wing_front, path=path(wing))
    pc.cmd("layer.layerStyle.innerShadow", "wing veins shading", color="#04261a", opacity=55, size=24, distance=6)
    pc.cmd("layer.setProps", "wing a touch translucent", opacity=0.94)
    shape("front wing bones", kind="path", name="Front wing bones", fill=None,
          stroke={"width": 9, "color": "#0c3326", "cap": "round", "join": "round"},
          path={"subpaths": [
              {"closed": False, "knots": smooth([(860, 470), (800, 280), (690, 120)], False)},
              {"closed": False, "knots": [[690, 120], [420, 150]]},
              {"closed": False, "knots": [[690, 120], [455, 315]]},
              {"closed": False, "knots": [[690, 120], [525, 430]]},
              {"closed": False, "knots": [[690, 120], [650, 500]]}]})
    shape("wing claw", kind="path", name="Wing claw", fill="#f4f1de",
          path=path([(684, 122, "c"), (700, 92, "c"), (702, 124, "c")]))

    print("▶ eye", flush=True)
    shape("eye", kind="ellipse", rect=[1098, 262, 26, 13], name="Eye", fill=grad("#fff7a1", "#ffb300", style="radial"))
    pc.cmd("layer.layerStyle.outerGlow", "eye glow", color="#ffd54a", size=14, opacity=90, spread=10)
    shape("pupil", kind="ellipse", rect=[1109, 263, 4, 11], name="Pupil", fill="#120400")
    shape("nostril", kind="ellipse", rect=[1186, 278, 10, 5], name="Nostril", fill="#08251a")

    print("▶ FIRE!", flush=True)

    def flame(scale, seed):
        r = random.Random(seed)
        center = [(1190, 312), (1300, 330), (1420, 360), (1540, 395)]
        pts = resample(center, 26)
        fr = frames(pts)
        up, down = [], []
        for k, (p, tg, nrm) in enumerate(fr):
            t = k / (len(fr) - 1)
            w = (10 + 190 * t ** 0.8) * scale
            wob = 1 + 0.18 * math.sin(t * 17 + seed) + r.uniform(-0.08, 0.08)
            up.append((p[0] + nrm[0] * w / 2 * wob, p[1] + nrm[1] * w / 2 * wob))
            down.append((p[0] - nrm[0] * w / 2 * wob, p[1] - nrm[1] * w / 2 * wob))
        end = pts[-1]
        tongues = []
        for j in range(5):
            a = -0.55 + 0.275 * j
            L = (70 + r.uniform(-15, 35)) * scale
            tongues.append((end[0] + math.cos(a) * L + 30 * scale, end[1] + math.sin(a) * L, "c"))
            if j < 4:
                b = a + 0.14
                tongues.append((end[0] + math.cos(b) * L * 0.35, end[1] + math.sin(b) * L * 0.35))
        return [(1188, 312, "c")] + up[1:] + tongues + down[:0:-1]

    shape("outer flame", kind="path", name="Fire outer", path=path(flame(1.0, 1)),
          fill=grad("#b3170b", "#ff5a1f", "#ff9a1f", angle=0))
    pc.cmd("layer.layerStyle.outerGlow", "fire glow", color="#ff6a00", size=60, opacity=80, spread=8)
    shape("middle flame", kind="path", name="Fire middle", path=path(flame(0.68, 2)),
          fill=grad("#ff7b00", "#ffb000", "#ffd84d", angle=0))
    shape("core flame", kind="path", name="Fire core", path=path(flame(0.36, 3)),
          fill=grad("#ffe27a", "#fff8d6", "#ffffff", angle=0))
    pc.cmd("layer.layerStyle.outerGlow", "core glow", color="#fff1a8", size=25, opacity=90, spread=0)

    print("▶ fire light on the dragon", flush=True)
    shape("warm light", kind="ellipse", rect=[960, 150, 520, 380], name="Fire light",
          fill=grad("#ff8a00", "#ff8a00", angle=0, style="radial"))
    pc.cmd("layer.setProps", "blend as soft light", blend="Overlay", opacity=0.35)
    pc.cmd("filter.blur.gaussianBlur", "soften light", radius=80)

    print("▶ title", flush=True)
    try:
        pc.cmd("type.create", "title", x=800, y=960, text="HERE BE DRAGONS", align="center",
               size=54, color="#f7dc6f", name="Title")
        pc.cmd("layer.layerStyle.outerGlow", "title glow", color="#ff9a1f", size=18, opacity=60, spread=0)
    except RuntimeError as e:
        print("  (title skipped:", e, ")")

    if OUT:
        pc.tool("doc_save", path=OUT + ".pcraft")
        pc.tool("doc_save", path=OUT + ".png")
        print("saved", OUT + ".png / .pcraft")

    shot = pc.tool("ui_screenshot", max_side=1600)
    for c in shot["content"]:
        if c.get("type") == "image":
            with open("dragon-shot.png", "wb") as f:
                f.write(base64.b64decode(c["data"]))
    print("done")


if __name__ == "__main__":
    main()
