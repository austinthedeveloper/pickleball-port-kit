# ADR-037 — Situational Shots

Status: **Accepted 2026-10-14**
Depends on: ADR-019 (shots), ADR-035 (net play), ADR-036 (teamwork).

## Why

CPU shot choice followed counters: a dink every Nth shot, deep and neutral
in turn, a lob only when someone stood within 44 px of the net. Against a
human who comes to the net, which net play (ADR-035) rewards, the CPUs kept
feeding them deep balls to volley.

## What

A style knob, `tactics` (0/1). It's on for PIRATES, GOTH CLUB, SURF CREW,
TWINS, CHAMPS, and `partner_style`; off for HENDERSON, SNOWBIRDS, GYM BROS
(bashers who drive everything), and the default CPU (singles and the demo
are unchanged).

When an opponent is within 64 px of the net (`AI_UP_DISTANCE`):

- **From the back:** a drop, a soft shot into their kitchen, with a lob
  every third time if the style lobs.
- **At the net too:** a dink.
- A ball high enough near the net is still put away, and a volley is
  still a block volley (ADR-035): those come first.
- **A human's CPU partner** drops only from the net. From the back, in
  doubles, its drops came back at the human's feet; a deep ball did
  better for the human's side.

Otherwise, against opponents who are back, the old choice stands.

## Measured

Three bot skills × 20 matches, bot wins of 60. A bot that plays the net
(the volleying partner style) is the human who comes in. The regular bot
(the default CPU) stays back.

| Team | Singles vs net bot, off | On | Doubles vs net bot, off | On |
|---|---:|---:|---:|---:|
| PIRATES | 51 | 38 | 43 | 41 |
| GOTH CLUB | 24 | 12 | 4 | 22 |
| SURF CREW | 35 | 24 | 55 | 35 |
| TWINS | 21 | 20 | 57 | 59 |
| CHAMPS | 24 | 7 | 20 | 12 |

- **Against the regular bot:** in singles, no change (nobody comes in to
  trigger tactics). In doubles, no team got weaker (TWINS 25 → 17, GOTH
  CLUB 3 → 0).
- **Coming to the net pays:** the net bot beats every net team far more
  often than the regular bot does (PIRATES singles: 23 → 51). Tactics are
  the counter; CHAMPS drop to 7.
- **Exceptions:** GOTH CLUB in doubles become dink machines (61% soft
  shots) and play worse. TWINS in doubles are easy for a net-playing
  human with or without tactics (a separate weakness: strict halves).
- **Separately for the partner:** the 2×2 of "drops only from the net"
  for the partner and for the opponents showed the rule helps the human's
  side (SURF CREW 39 → 56, TWINS 27 → 56 bot wins) and hurts the
  opponents, so only the partner has it.

## Frame budget

`make perf`: every run within budget (`doubles_ladder` 0, `modifiers_doubles`
12, the doubles demo 4). The golden trace is identical.

## Tests

`test_ai.c: test_tactics`: PIRATES drop (soft, short) against P1 up at the
net and play a normal shot against P1 back; the default CPU never drops.
