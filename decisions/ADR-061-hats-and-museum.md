# ADR-061 — Thirteen Hats and the Hat Museum

Status: **Accepted 2026-10-18**
Milestone: `PORT-38`. Ports: SNES ADR-060 (more hats) and 061 (the Hat
Museum), from the SNES repo's `assets/source/career.json`, `src/museum.c`,
`test/test_museum.c` and `test/test_career.c`.

## What changed

- **Seven new hats**, each a career unlock, looks only (no paddle gear):
  BEANIE (win 3 matches), BUCKET (10 open play games), BACKCAP (win 25),
  WHIRLY (a 30-shot rally), VIKING (beat the GYM BROS), CHEF (a 10-win
  streak) and CROWN (3 ladder clears). That makes 13 hats, 11 to earn,
  and 16 unlocks: the whole 16-bit mask.
- **The HAT MUSEUM**, a row on the career player's card (it shows "n OF
  12"; the SNES opened it with X): twelve lit cases, four to a row, the
  player standing in each in their saved look, wearing that case's hat. A
  locked hat is a black silhouette; under the cases the picked one's name
  (WEARING if worn) or "???" and how to earn it. B (or a click on the
  picked case) wears an unlocked hat; Y goes back to the card, writing the
  save only if a hat was put on.

## How

- **Data:** `data/career.json` is the SNES file as is. Ids append after
  the bare head (0-5 unchanged, 6-12 new), so old saves keep their hats
  and unlock bits; `Career.hat_none()` is the bare head's id
  (`CAREER_HAT_NONE`), no longer the last.
- **Art:** the port draws its own HD players, so the hats are new
  procedural overlays in `art/levels/tools/players.py` (`hat_part`), in
  the SNES's colour roles: beanie, whirly, backcap and bucket in the shirt
  ramp (the whirly's blades in the shoe accent), the crown silver with
  shirt-colour jewels, the chef's toque white, the viking helmet grey with
  white horns and a shirt band. Only the new sheets and the manifest were
  taken from the rebuild: this machine's numpy and Pillow move a few
  pixels in the other sheets, which stay as they were.
- **Logic:** `meta/museum.gd` follows `museum.c` (the cases skip the bare
  head; the D-pad wraps and a short last row is handled). `Career.hats_held`
  is `career_hats_held`.
- **View:** `view/hat_museum.gd`, a full screen on the title (like Player
  Select). A silhouette is the player's palette shader at `brighten`
  0.06; the SNES also outlined it in grey for dark hair, which the port's
  black outline and lit cases don't need.

## Not done

Hair colours aren't shown (the SNES left them out too).
