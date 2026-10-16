# ADR-051 — Parallax

Status: **Accepted 2026-10-16**
Milestone: `M4-CAM-02`. Depends on: ADR-050 (the camera).

## What

With the camera (ADR-050), the court's layers pan at different speeds:

| Band | Scene rows | Pans |
|---|---|---|
| Backdrop: sky, trees, back fence, stands | 0–73 | half the camera |
| Court, from the net post's cap | 74–185 | with the camera (the sprites) |
| Near fence and bushes | 186–223 | the camera, then in 4 steps to 1.5 times it |

The far scenery trails and the near fence leads, so the court reads as
having depth. The near fence ramps instead of jumping, because its bushes
start 10 rows above its rail: a hard split at the rail would tear them,
and a split above them would slide the sand under the players' feet. The
ramp makes the near fence's posts lean a little toward the camera, like
the floors in some 16-bit fighting games. Only horizontal scroll splits;
vertical stays one value (a vertical split repeats or skips lines at the
seams). CAMERA OFF keeps every band still.

## How

- **HDMA.** Channel 6, mode 2 (two writes to BG1's horizontal scroll,
  `$210D`), from a table in work RAM: the backdrop's lines and offset, the
  court's, four steps for the near fence, the last holding to the bottom.
  The band lines follow the camera's vertical offset, so the split stays
  on the same scene row. `src/asm/camera.asm` writes the table after the
  camera's step, into the half not on screen, and only when the camera
  moved; `render_camera_commit` hands it to the channel in VBlank and
  swaps halves. A frame never mixes two tables. The screens without the
  camera (Player Select, the park, the stress scene) switch HDMA off.
- **The split rows.** The backdrop's last row before the court is 73: the
  net post starts at row 75 with its cap on 74 in every venue, so its top
  never shears from the rest of it. The asset build fails if a venue's
  post starts elsewhere (`scene.py: check_parallax_rows`). The back fence's
  posts leave a one-pixel footing in the court band, which reads as their
  base.
- **Edges.** The near fence pans up to 12 px, so the map mirrors two
  columns past each edge (was one; no new tiles).
- **Sprites.** All on the court band, as before, except the partner
  watching from the stands (ADR-042), who moves with the backdrop.

## Cost

HDMA takes a small share of every line it is active (about 4 scanlines
of CPU a frame), and the table about 2 when the camera moves (a first
version with 8 ramp steps, rebuilt every frame, cost about 5 more).
Against ADR-050's camera, the worst frames are 2–10 scanlines heavier
(doubles ladder 185 → 192, all-modifier doubles 200 → 202, golden 203 →
211 of 225), with every `make perf` budget still 0.

The tightest frame is now the tail of a scene switch: leaving a title
page restarts the attract demo (208 scanlines on its frame), and the next
frame reached 224 of 225 on `records.timeline` (213 before the parallax).
The overrun latch skips the switch; a held frame there would not show.
KNOWN_ISSUES #29.

## Rejected

- **A hard near-fence band at its rail.** Tears the bushes above it.
- **A full perspective ramp over the court.** The court's lines would lean
  with the camera, and the sprites would need an offset per row; the
  court's readability comes first (ADR-011).
- **Splitting the sky from the trees.** The tree canopies cross every row
  near the top; they would tear.

## Verification

Golden trace identical; `make perf` zero overruns; the HDMA table read
back from work RAM at both extremes of a rally (backdrop −3, court −7,
near fence −7 to −10 at the default 85%); MesenCE frames of the net at
both extremes (no shear), the near fence, and UNDERSEA's watcher.
