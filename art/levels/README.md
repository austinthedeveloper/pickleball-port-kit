# Levels at 960×540 (modern port)

Everything in the three level mocks (`art/concept/level-01..03`), built
engine-agnostic: PNG layers and sheets plus `out/manifest.json`, which
describes every file, position, anchor, animation and layer order.

- **Resolution:** 960×540, 16:9. Scale by a whole number with nearest
  filtering (×2 for 1080p, ×4 for 4K). For 1440p, letterbox or use a
  pixel-perfect fractional scaler.
- **Density:** 2× the mocks' art pixels, so the court, props and 96 px
  players keep the mocks' proportions. The extra width extends the scenery
  at the sides.
- **Venues:** `park` (level-01, Riverdale Park, day), `lakeside`
  (level-02), `sunset` (level-03, doubles), and ADR-046's `dinosaur`,
  `space` and `undersea` (no level mocks: drawn from the SNES mocks'
  themes, `art/concept/court_top_*.png`), ADR-078's indoor `gym`, and
  ADR-085's `ruins`, `glacier`, `lab` and `station` (drawn from the
  dinosaur game's level concepts, `../dinosaur/assets/levels`), and
  ADR-088's painted `western`, `rooftop`, `pirate`, `motel`, `fair`,
  `drivein` and `mall`: not drawn, but cut from generated paintings
  (`art/venues-r1`) by `tools/painted.py`, with a crowd sheet of their
  own (`venues/<venue>/crowd.png`, the manifest's `crowd`) and the
  backdrop as `far.webp`.

`out/previews/<venue>_vs_mock.png` shows each level rebuilt from these
assets (HUD, players, crowd, ball) beside its mock.

## What's in `out/`

| Path | Contents |
|---|---|
| `manifest.json` | The index: court geometry, layers, seats, sprites, animations, fonts, 9-slices, HUD layout |
| `venues/<venue>/{sky,far,trees,ground,fence,stands,net,front}.png` | Parallax layers, 1056×588 each (48 px / 24 px overscan for the camera) |
| `venues/<venue>/court_mask.png` | 8-bit role ids (surround, surface, kitchen, net shadow, lines) for recolouring the court |
| `sprites/players/player_<male\|female>_<team>.png` | 21 frames, 128×128, per team (blue, red, green, gold): the 15 play frames and ADR-062's celebrations, slump, dive and scramble |
| `sprites/players/player_<variant>_<team>_cap.png` | Cap overlay, same frames; draw after the body, or leave it off |
| `sprites/players/roles/*.png` + `palettes.json` | Indexed role sheets for palette-swap shaders (any team, 4 skins, 4 hairs, 5 paddles): the body and a sheet per hat (13 with the cap, ADR-061); port ADR-099's headless bodies (`nohead`, `nohead_<pattern>`) and a sheet per generated head (`head_<id>`), composed in the game |
| `sprites/crowd.png` | 16 spectators (12 sitting, 4 standing) × idle and cheer, 32×64 |
| `sprites/{ball,ball_shadow,player_shadow,spark,dust,net_post_near}.png` | Ball (4 roll frames), shadows (alpha), contact spark (4), dust puff (4), near net post |
| `ui/font_{big,big_gold,small}.png/.json` | Bitmap fonts: caps, digits, `!?.,:-'/%+` with per-glyph advance. `big` and `small` are white, for tinting |
| `ui/panel_*.png` | 9-slice panels (12 px margins): blue, red, green, gold, title, doubles, sub |
| `ui/button_*.png`, `ui/icon_ball.png` | A/B/X/Y glyphs (SFC colours, plus the mocks' red B) and the pickleball icon |

## Drawing a level

1. Draw the layers by `z`, each at `origin − camera × parallax`:
   sky 0.2, far 0.4, trees 0.6, then ground, fence, stands and net at 1.0.
2. After `stands`: the crowd sprites at each seat (`seats[].person` is a
   row of `crowd.png`).
3. After `net`: the game sprites, y-sorted (shadows first): players, ball,
   ball shadow, `net_post_near` at its position.
4. Last: `front` (near fence and bushes) at parallax 1.3. The camera
   (ADR-050) drifts up to about 30×15 px here. The overscan covers that, and
   the build checks every corner for gaps.

## Court

`manifest.court.projection` maps the court's flat coordinates to the screen
(the ADR-011 split: rules stay flat, only the picture is projected). The
coordinates are u along the court (0 is the left baseline, 0.5 the net) and
v across it (0 is the far sideline).

```
y    = top_y + v * (bottom_y - top_y)          # 222 .. 427
half = top_half + v * (bottom_half - top_half) # 266 .. 315
x    = 480 + (u - 0.5) * 2 * half
```

The kitchen sits at u = 0.5 ± 7/44, the real proportions. Court colours are
user presets (ADR-022/027): recolour by `court_mask.png` role, using the
presets in `data/court_colors.json`. Each venue's `ground.png` is its
default colouring.

## Players

The players are a 2× rebuild of the 48 px rig: the same poses and shading,
plus the four new SNES poses (overhead_windup, overhead_contact, reach,
scoop). The anchor is the feet at (56, 116), facing right; when flipped,
mirror it to 127 − x.

Animations, with frame times, are in the manifest: idle, run, swing, toss,
cheer, overhead, reach, scoop.

## Rebuilding

```sh
python3 -m venv .venv && .venv/bin/pip install -r art/levels/tools/requirements.txt
.venv/bin/python art/levels/tools/build.py
```

| Script | What it builds |
|---|---|
| `tools/build.py` | Everything, plus the previews |
| `tools/pix.py` | The drawing kit: aliased shapes, ramps, foliage, chain-link, outlines |
| `tools/scenery.py` | The props |
| `tools/venues.py` | The venues, positioned from the mocks via `M()` |
| `tools/painted.py` | ADR-088's painted venues, cut from `art/venues-r1` |
| `tools/critters.py` | The fun venues' onlookers: dinosaurs, aliens, astronauts, sea creatures |
| `tools/court.py` | Geometry, court mask and net |
| `tools/players.py` | The players |
| `tools/heads.json` | ADR-099's generated heads, as role rows (written by `art/faces-r1/export_heads.py`) |
| `tools/crowd.py` | The spectators |
| `tools/ui.py` | Fonts, panels, glyphs and effects |

## Not done yet

- **Polish:** the art is generated and hasn't had a hand pass. Hands, the
  crowd and the foliage would benefit from one in Aseprite. Leave the
  player faces as they are: the long-chinned "so ugly they're awesome" look
  is approved and part of the style.
- **Night:** ADR-045's night times aren't baked. The backdrop layers are
  separate, so an engine tint (dark for the backdrop, lit for the court)
  covers it.
- **Font:** uppercase only, like the SNES HUD font.
