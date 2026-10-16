# ADR-047 — Career Players

Status: **Accepted 2026-10-15** (stages 1-4: the data, the page, play,
gear)
Milestone: `M4-CAREER-01` to `-04`. From [IDEAS.md](../IDEAS.md), "Career
mode". Depends on: ADR-021/032 (save and migration), ADR-013/014 (palette
parts, hats), ADR-020 (Player Select), ADR-023 (the ladder), ADR-040
(initials entry).

## The idea

Create a player, name them, and play as them: they keep lifetime stats,
and playing unlocks cosmetics (hats, hair colours). Gear that changes
stats comes later (stage 4), with its own balance pass.

## Decisions

- **Three save slots** (a family or friends sharing the cart). One is the
  active player, who is 1P.
- **The title's RECORDS entry becomes CAREER**: the active player's card
  (name, look, record, stats, unlocks), switching or creating players, and
  the old records table as a section. The title menu is full, so no new
  entry.
- **Unlocks are cosmetic** for now; skin tones are never locked.
- Stats count **matches against the CPU** (no 2P on the other team),
  outside the attract demo and practice, like the records (ADR-021).

## Stages

1. **Data** (this branch): the player record, save layout 12, stats from
   points and matches, unlock rules, tests. No screens yet.
2. **The CAREER page** (`M4-CAREER-02`): slot picker, player card, and the
   editor (name with the initials entry of ADR-040 widened to 8 letters;
   body, skin, hair, shirt, hat, paddle; locked items shown locked).
3. **Into matches** (`M4-CAREER-03`): 1P's look and paddle from the active
   player (Player Select starts on them), the name on the HUD, and
   "UNLOCKED!" on the result screen (`g_career_new_unlocks`).
4. **Gear stats** (`M4-CAREER-04`): small trade-offs like the paddles'.

## The CAREER page (stage 2)

The title's RECORDS entry reads CAREER and opens a page with four views
(`src/career_page.c`, pure input logic like the court and options
editors; `hud_scene.c` draws, `main.c` writes the save and previews):

- **SLOTS**: the three players (name, yellow for the active one, and
  total wins) or NEW PLAYER, then RECORDS. B opens a player, which makes
  them active (a save write), or creates one and opens EDIT on the name.
- **CARD**: SINGLES and DOUBLES W/L, aces, shutouts, best streak, longest
  rally, UNLOCKS n/9, and the next unlock with its hint (`how` in
  career.json, 18 cells), or ALL UNLOCKED!. B edits; L+R+X deletes (the
  records erase's guard); Y back.
- **EDIT**: NAME, BODY, SKIN, HAIR, SHIRT, HAT, PADDLE, in a box right of
  the court's left baseline. Left/Right change a look; locked hair and
  hats are skipped. B on NAME types it; B elsewhere keeps (a save write; a
  nameless player goes back to typing); Y restores the look, or drops a
  player just created.
- **Typing a name** is an arcade keyboard in the same box: the name with
  an empty box per place left (the next one yellow; the font has no
  visible underscore), then A-Z, space (a box), and `-` in rows of ten,
  and DEL and END. The D-pad picks a key, B types it, DEL or Y erases the
  last letter, END or Start finishes (not with no letters); Y with
  nothing left to erase backs out (a new player is dropped, an old one
  keeps their name), and the prompt then reads `@ TYPE  Y BACK`. Eight letters
  put the cursor on END. A new player starts here with a blank name and
  goes on to BODY. *(Amended 2026-10-15: at first Up/Down cycled the
  letter in place, with no sign of the blank places or of being done.)*
- **RECORDS**: the old table; L+R+X erases.

Each view has its own prompt: title keys carry a 4-bit prompt id (was the
3-bit page), ids 8-12 for the CAREER views. The views draw a part (one or
two rows) per frame and then redraw only changed rows, like the others.

**The preview:** while EDIT is open, the title demo stops (`main.c` skips
its `game_update`), the ball is hidden, and its P1 stands at the left
baseline in the player's look, beside the editor: `MatchConfig.career_p1`
makes slot 0's palette (`career_compose_palette`: the career skin ramp and
hair, the shirt's team colours, the paddle) and hat come from the active
player, and `render_apply_p1_look` recomposes slot 0 alone. Leaving EDIT
starts a fresh demo. *(Amended: at first the demo kept playing with P1
recoloured, mostly hidden behind the menu.)* Stage 3 uses the same flag in
matches.

## Playing as the player (stage 3)

- **Who:** the active player is 1P. **NO PLAYER** on the slots view (the
  row after the slots; the page opens there when nobody is active) makes
  nobody active: matches are exactly as before and nothing is recorded.
- **Player Select** starts 1P on the player's body, shirt, and paddle;
  changes there are for that match. 1P's portrait and thumbnails take the
  player's skin and hair (`career_compose_with`); the thumbnails wear the
  hat too (the portrait is fixed art, without one). `select_apply` sets `career_p1`.
- **In the match**, slot 0 wears the player's skin, hair, and hat with the
  match's shirt and paddle (`match_compose_palette`, `match_slot_hat`).
  The score panel's 1P label is the name's first four letters (the panel
  fits four, as BLUE/RED do).
- **Open play and the park's ball machine** have no Player Select:
  `match_config_career_p1` puts slot 0 in the saved body, shirt, and
  paddle, and a slot that had that shirt colour takes slot 0's old one
  (ADR-010). The park's walk-around sprite wears the player's
  palette too (KNOWN_ISSUES #27).
- **UNLOCKED!**: after the initials card (if any), the match result shows
  a story card (`STORY_CARD_UNLOCK`) with the unlocks just earned
  ("VISOR, PINK HAIR", "+n" past 24 cells) and `@ OK`; B, A, or Start
  closes it after 30 frames, or it goes after 5 s. Closing clears
  `g_career_new_unlocks`; a new match clears it too.

### Cost

A match-end save write (212 bytes) on a heavy doubles frame overran when
the match ended inside `modifiers_doubles.timeline` (2 runs of 6: random
power-on RAM decides how the rallies go). The SRAM copy is now
`src/asm/sram_copy.asm` (MVN into bank $70, about 7 cycles a byte, was the
library's copy); six forced match ends there: zero overruns, worst
scanline 199.

## Gear (stage 4)

A career player's hat moves one paddle stat point to another (`gear` in
career.json), so the 9-point paddle budget holds and every pairing stays
inside ADR-015's 15%:

| Hat | Gear |
|---|---|
| CAP, NONE | nothing |
| VISOR | CONTROL +1, POWER -1 |
| HEADBAND | SPEED +1, CONTROL -1 |
| TRICORN | POWER +1, CONTROL -1 |
| BANDANA | POWER +1, SPEED -1 |

- **No room:** a stat can't pass 5. On a paddle that already maxes the
  stat a hat raises (WOOD's control, RED's power, GOLD's speed), that hat
  changes nothing, so no cost comes without the gain. (GOLD + HEADBAND
  would put the swing limit past 15% once rounded.)
- **Tables:** `paddle_stats.h` holds every paddle with every hat, row
  `PADDLE_PROFILE(paddle, hat)` = hat x PADDLE_COUNT + paddle; rows 0-3
  are the plain paddles. Slot 0's `Player.paddle` is the career player's
  row (`game_activate_players`); every other player, and play without a
  career player, use the plain rows, so the golden trace and the balance
  tables are unchanged. The C and the assembly (`player_step`) index the
  tables as before.
- **Shown:** Player Select's bars for 1P include the hat; the editor has a
  line under the look, `PWR 2  CTL 4  SPD 3`.
- CPUs' hats are looks only.

Tests: `test_career.c: test_gear` (every row on budget and in range, the
cap and bare hair plain, VISOR on BLUE and on WOOD, slot 0 alone in a
match); MesenCE: the editor's line and Player Select's bars with a visor.

## The player record

`CareerPlayer` (`save.h`), 52 bytes: fourteen u16 counters first, then the
bytes, an even size, so the layout is the same on the host and the SNES
(816-tcc does not pad):

- wins and losses by mode, points won and lost, aces, shutouts, the
  current and best win streak, longest rally, ladder clears, open play
  games, and the unlocked mask (u16);
- used, the name (8 letters, space-padded), variant, skin, hair, shirt
  (a PAL_* team colour: 1P's palette must stay unique, ADR-010), hat,
  paddle, and wins over each ladder team (u8 each, saturating).

An **ace** is a point 1P's team won on 1P's serve with one shot in the
rally. A **ladder clear** is a win over the last ladder team on the
ladder (not at the park).

## Unlocks

`assets/source/career.json` lists the skins (opponents.json's four, in
order), the hair colours, the hats (in HAT id order), and the unlocks
(bit n of the mask) with a rule and a value: WINS, RALLY, ACES, SHUTOUTS,
STREAK, BEAT (a ladder team, by name), CLEARS, OPEN. A hair colour or hat
names the unlock that frees it. The asset build checks names, rules,
teams, hat order, and that the first hair colour and the cap are free,
and writes `career_data.h`.

| Unlock | Rule |
|---|---|
| VISOR | win a match |
| HEADBAND | win 10 |
| BANDANA | a 20-shot rally |
| TRICORN | beat the PIRATES |
| BLUE HAIR | 5 aces |
| PINK HAIR | a shutout |
| GREEN HAIR | 5 open play games |
| PURPLE HAIR | a 5-win streak |
| GOLD HAIR | clear the ladder |

Unlocks are checked after every finished match;
`g_career_new_unlocks` (WRAM) holds the ones just earned.

## Save (layout 12)

`SaveData` gains `career[3]` and `career_active` (CAREER_NONE: nobody)
after the initials: 212 bytes. Layout 11 (v0.15.0) is frozen as `SaveV11`
and migrates whole with no players (its kitchen colours are already
current, so the layout-10 remap skips it). The match hooks record into
`g_save` and `save_record_match`'s write keeps both, one write a match.

### Cost

Every save write sums the block, which grew four times. The 816-tcc sum
loop made save writes (leaving a page, a match end) overrun a frame in
eight `make perf` runs; the sum is now `src/asm/save_sum.asm` (host
builds keep the C). Boot reads the bigger block, which shifts the title
demo slightly: heavy demo frames then met COURT page recolours (and a
LAVA one), so a recolour now waits for scanline 96 (was 110), up to 6
frames (was 3). Zero overruns in every run.

## Tests

`test/test_career.c`: slots (create, name cut and padding, taken and
missing slots, delete, select, a save round trip); points and matches
(aces, rallies, streaks, shutouts, team wins, ladder clears on the ladder
only, nothing without a player); unlocks (free items, first win, earned
once, several at once, a loss earns nothing); layout 11 migrating with
no players. MesenCE: a save written and read back across a reboot
(layout 12, the court choices kept).
