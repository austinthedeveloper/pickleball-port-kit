# ADR-050 — Camera

Status: **Accepted 2026-10-16**
Milestone: `M4-CAM-01`. Amends: ADR-002 (static court). Depends on:
ADR-011 (projection), R17–R20 (design/snes/REFACTOR_PLAN.md: OBJ writes, VBlank).

## What

The court leans a little toward the ball, the way some older consoles'
sports games drift their camera with play. A **CAMERA** row on the OPTIONS
page sets how much: **OFF**, then 50% to 100% in 5% steps. The default is
**85%**: the first build moved at 100%, and on playing it the user asked
for 10–20% less.

At 100% the camera's target is a sixteenth of the ball's distance from the
net across the screen (up to 8 px) and an eighth of its distance from the
centre line (up to 4 px), or the centre with no ball in play. It eases an
eighth of the way there a frame, in 1/16 px, at least 1/16 px and at most
half a pixel a frame, so it drifts and never jumps. The setting scales the
target; OFF keeps it still.

Presentation only. The camera reads the ball and changes nothing in the
match: the golden trace is identical. The rules stay in world space
(ADR-011); the camera only moves the picture.

## How

- **Background.** BG1 scrolls by the camera's whole pixels, written in
  VBlank (`render_commit`) when it changes. The court's map is now 64x32 (two
  screens): the 32x28 scene, with its edge column or row mirrored once
  beyond each edge through the map's flip bits (`tools/assetgen/scene.py:
  camera_map`): no new tiles, 4 KiB of map per venue (was 1,792 bytes).
  A pan past an edge shows the mirror of the edge tile: trees, fence,
  sand, and bushes read as more of the same.
- **VRAM.** The 64x32 map takes words `0x0000-0x07ff`, so the BG3 HUD map
  moves from `0x0400` to `0x5C00`, past the HUD font (the BG3 tile budget
  goes from 512 to 384; 280 used). docs/09 has the map.
- **Sprites.** `oam_write` takes the camera off every object it places,
  so sprites stay on the court. The one screen-fixed object on the court is
  the close-call replay's ball (on BG2's close-up, which doesn't pan): it
  adds the camera back. Player Select, the park (its own camera), and the
  stress scene reset the camera to 0.
- **Cost.** The step is `src/asm/camera.asm`, about 1–2 scanlines with
  the hardware multiplier. In 816-tcc C it took about 8 a frame (signed
  shifts, calls, ternaries), which a measurement caught before commit. With
  the per-object subtraction, frames are about 5 scanlines heavier
  (doubles ladder's worst 180 → 185 of 225); every `make perf` budget is
  still 0.
- **Save.** The setting is the save's reserved byte (`SaveData.camera`,
  was `career_reserved`): choice + 1, so 0, in every older save, is the
  default. No layout change.

## Amendment 2026-10-16: OFF by default

The user wasn't sure they liked the camera yet and kept it as an option:
CAMERA now defaults to **OFF** (saved 0, so every save, old or new, starts
OFF until it is changed). With CAMERA OFF and the court at rest, the
parallax's HDMA (ADR-051) switches off after showing its all-zero table
once, so the default game doesn't pay its per-line cost; the camera's
step and `oam_write`'s subtraction (about a scanline) remain.

## Rejected

- **A 32-wide map with wrap.** A pan left shows the right edge's column on
  the left; the seam shows.
- **Masking the screen edges with windows.** Black bars at the sides.
- *(Parallax was left for later here; it is [ADR-051](ADR-051-parallax.md).)*

## Verification

`test_options.c: test_camera, test_editor` (the table, the row, Y puts
back), `test_layout.c` (the ball's offsets and the court's centre for the
assembly); golden trace identical; `make perf` zero overruns; MesenCE
frames at both extremes of a rally (no seam at the edges, sprites on the
court) and the OPTIONS page's CAMERA row.
