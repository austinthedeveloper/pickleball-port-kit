# ADR-023 — CPU Personalities and the Ladder

Status: **Accepted 2026-10-13**
Starts the story-mode opponents idea in [IDEAS.md](../IDEAS.md). It has no
story screens yet: opponents come in ladder order.
Depends on: ADR-013 (palette parts), ADR-014 (female variant), ADR-019
(shots), ADR-020 (paddles), ADR-021 (save).

## Roster

`assets/source/opponents.json`, in ladder order. Each entry is a team: a
**captain**, whom you face in singles, and a **partner**, who joins in
doubles.

| # | Team | Captain / partner | Plays like |
|---|---|---|---|
| 1 | HENDERSON | DAD / KIDDO | Dad is slow and late to react; he never lobs and rarely dinks. Kiddo is fast but sloppy. |
| 2 | SNOWBIRDS | MARGE / WALT | Slow retirees who lob anyone near the net and hit deep. |
| 3 | GYM BROS | BRAD / CHAD | Drive almost everything at your body. They spray a lot and are slow to react. |
| 4 | PIRATES | PETE / BILGE | Bangers who aim at you and hit deep. |
| 5 | GOTH CLUB | RAVEN / VLAD | The soft game: dink every other shot, never lob, almost never speed up, and stand close to the kitchen. |
| 6 | SURF CREW | KAI / LANI | Quick, stand deep, and mix their aim. |
| 7 | TWINS | MAX / MIA | Rush the net, put away high balls, and mix their aim. |
| 8 | CHAMPS | ACE / JADE | Few mistakes, fast, and use every shot. |

## Looks

Each player has the following (no new art):

- a skin ramp, chosen from four named tones;
- hair, shirt/cap (3 colours), shorts (2), and a shoe accent, in the
  ADR-013 palette roles;
- a body variant (male, or female with the ponytail);
- a paddle (colours and stats).

The generator composes each player's full 16-colour OBJ palette. A team also
has two BG3 label colours, so its HUD name is drawn in the team colour.

## Play style

`AiStyle` (generated in `opponents.h`) replaces the CPU constants in
`src/ai.c`. It has one row per player:

| Knob | Default CPU | Use |
|---|---:|---|
| `late_period` | 7 | Deliberately late (a sprayed shot) every Nth return; 0 never. The main difficulty dial. |
| `reaction` | 0 | Frames an incoming ball is ignored. |
| `dink_period` | 4 | A dink every Nth shot; 0 never. |
| `lob_distance` | 44 | Lob when an opponent is this close to the net; 0 never. |
| `putaway_z`, `putaway_distance` | 14, 48 | Drive a ball at least this high, from within this distance of the net. |
| `aim` | away | Singles aim: away from the opponent, at them (`body`), or a fixed mixed pattern. Doubles keeps ADR-018's lane pattern. |
| `depth` | alternate | Standard shots alternate deep and neutral, or are always deep. |
| `recover` | 80 | Home x distance behind the net. |
| `speed` | 19 | Max speed (12.4). |

- The default style is the shipped CPU. The asset build fails if
  `default_style` in the JSON differs from the constants in `ai.h`,
  `court.h`, and `player.h`.
- Styles are copied per slot into `g_ai_styles` when a match starts. They are
  kept outside `AiState`, so golden traces keep their layout.
- The default CPU's balance numbers are unchanged (`test_match_flow.c`: 13
  of 20 rematches, and 0 / 16 at mistakes every 2nd / 10th shot).
- The build checks each knob's range (for example, speed 12–24), names (≤ 9
  capitals, the space beside "VS" on the HUD), and paddles.

### Tuning

`make stats OPPONENT=n` runs the bot against an opponent. The table measured
wins out of 180: 30 matches at each bot mistake period from 3 to 8.

| Opponent | DAD | MARGE | BRAD | PETE | RAVEN | KAI | MAX | ACE |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Bot wins / 180 | 160 | 123 | 80 | 84 | 74 | 52 | 31 | 15 |

- The simulation is deterministic but sensitive, so single 30-match runs
  swing widely. Tune against the aggregate.
- BRAD's matches are mostly balls hit out, so the result stays near a coin
  flip whatever his settings. He sits third, and his rung is about equal to
  PETE's.
- *Amended 2026-10-14 (M4-OPP-03).* BRAD was deliberately late every 2nd
  shot, so his points were balls hit out whatever the bot did: P1 won 17,
  12, 11, 13, 12, 12 of 30 at bot periods 3 to 8, flat. Now he is late every
  4th shot but slow to react (16 frames, was 10) and on his feet (speed 13,
  was 15): fewer gifts, and a better player beats him more (11, 16, 17, 19,
  13, 20). Bot wins of 180, same method: MARGE 123, **BRAD 96 (was 80)**,
  PETE 79, so his rung sits between theirs. In doubles CHAD went to late
  every 7th (ADR-038 amendment) to keep GYM BROS between SNOWBIRDS and
  PIRATES.
- *Amended 2026-10-14 (singles pass).* The later rungs had moved since
  this table (ADR-035 to ADR-039): RAVEN 21, KAI 31, MAX 0, ACE 0, so RAVEN
  was harder than KAI and the last two rungs were walls. RAVEN is now late
  every 6th (was 7th), MAX every 7th (was 10th), ACE every 8th (was 16th).
  Bot wins of 180 by rung: **160, 123, 96, 79, 42, 31, 15, 4**, each
  harder than the one before. The doubles partners keep the doubles ladder
  in order (ADR-038 amendment).
- Doubles partners copy their captain's tuned values except where the
  character differs (Kiddo). They were not measured; the balance tool is
  singles only.

## Ladder

- `SaveSettings.ladder` (the former reserved byte, so the layout is
  unchanged) is the next opponent.
- **Player Select** with one human sets `g_match_config.opponent` to that
  rung. With 2P versus, there is no opponent. In doubles, the opponent pair
  fills slots 2–3, and 1P's partner (slot 1) is the default CPU.
- **Winning** a match against the opponent advances the ladder; after CHAMPS
  it goes back to HENDERSON. A loss keeps the rung.
- *Amended 2026-10-13:* after a win, **B goes on to the next opponent**
  (`@ NEXT` on the result banner). The game sets `g_next_opponent`, and
  `main.c` sets up the next rung, shows its intro card, and reloads the
  court (their home court on AUTO). After a loss, B is a rematch. Before
  this, B after a win replayed the same opponent, which looked like the
  ladder never moved.
- The attract demo and the default config never set an opponent.

## HUD

- **Singles**: the centre panel reads `VS <captain>` (for example `VS DAD`)
  instead of `ARCADE RULES`, with the name in the team colour.
- **Doubles**: the sub-panel reads `VS <team>`. The opponents' label is
  `CPU` in the team colour, and their points read `CPU POINT`.
- **Records page**: a new last row reads `LADDER n/8` and the next team.

## Emulator runs

MesenCE keeps the `.srm` per ROM file name, and the saved ladder now picks
the CPU. So `tools/mesen_probe.py` and `make smoke` delete the ROM's `.srm`
before each run. `make smoke KEEP_SAVE=1` keeps it, to check persistence
across boots.

The golden timeline now plays DAD. Traces from before this ADR diverge from
the match start (frame 238) and were re-recorded.

## Tests

- `test/test_opponents.c` (host):
  - the default style equals the constants
  - config, looks, slot styles, and HUD colours
  - Player Select takes the saved rung; 2P gets no opponent
  - ladder: advance, stay on a loss, wrap, saved, never in attract or
    without an opponent
  - the first rung is beaten clearly more often than the last (bot at
    mistakes every 5th shot, 20 matches each)
- Smoke (`select`, `doubles` timelines): `VS DAD` and the Hendersons' look
  in both modes.
- Zero frame overruns in the doubles timeline and a full match.
