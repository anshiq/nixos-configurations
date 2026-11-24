# ArtCraft live-control examples

Reference scripts from the dragon session (2026-11-21). They are not installed;
run them with `python3 -I <script> …`. Each talks MCP over stdio to the app's
CLI in bridge mode, so the matching `<name>-live` app must be open.

Token files are in `${XDG_STATE_HOME:-~/.local/state}/craft/` (created by the
`-live` launchers).

| Script | What it does | Run (after starting the app) |
|---|---|---|
| `photocraft-draw-dragon.py` | Draws a layered vector dragon scene step by step in PhotoCraft (`shape.create` paths with gradients, layer styles, text) | `photocraft-live` then `python3 -I photocraft-draw-dragon.py photocraft-cli 47321 ~/.local/state/craft/photocraft.token 0.5 [out-name]` |
| `photocraft-mcp-call.py` | Calls one PhotoCraft MCP tool and prints the result (saves an image result to OUT) | `python3 -I photocraft-mcp-call.py photocraft-cli 47321 TOKEN OUT.png ui_screenshot '{"max_side":1400}'` |
| `filmcraft-animate-dragon.py` | Keyframes a 3 s animation (hover, wing flaps, fire burst, title) on six clips | Assumes a 1600×1000 30 fps sequence with clips 15–20 = bg, far wing, body, front wing, fire, title on V1–V6; `FILMCRAFT_CONTROL_TOKEN=$(cat ~/.local/state/craft/filmcraft.token) python3 -I filmcraft-animate-dragon.py filmcraft-cli 47331` |
| `filmcraft-render-frames.py` | Grabs the Program monitor at given times | `FILMCRAFT_CONTROL_TOKEN=… python3 -I filmcraft-render-frames.py filmcraft-cli 47331 OUTDIR 0 1.5 2.8` |

Ports (`../apps.nix`): PhotoCraft 47321, FilmCraft 47331, GridCraft 47341, WordCraft 47351,
DeckCraft 47361, DesignCraft 47371, EffectCraft 47381, LightCraft 47391, MaterialCraft 47401,
SoundCraft 47411, TextureCraft 47421, VectorCraft 47431. AniCraft and Craft Anything have no live mode. PdfCraft uses a control file:
`pdfcraft-cli ui --control ~/.local/state/craft/pdfcraft.control <method>`.

Useful findings:
- PhotoCraft filters (e.g. Gaussian Blur) need a pixel layer: `shape.rasterize` first.
- PhotoCraft token files must be mode 600.
- FilmCraft motion params: `anchor`, `position`, `rotation`, `scale`
  (`scale_width` when `uniform_scale` is false); times are ticks, 254016000000 per second.
- In bridge mode `render_frame`/`render_preview` return a window screenshot.
