# ADR-075 — PLAY OF THE MATCH

Status: **Accepted 2026-10-20**
Milestone: `PORT-51` (dealer's choice: the user asked for something not
on the backlog).

## Decision

When a match ends, before its result, the game replays its **longest
rally** (6 shots or more; a tie goes to the later one) as television
would: a REPLAY bug with a blinking dot, the PLAY OF THE MATCH card with
the rally's length, the rally from its serve with its last 40 frames at
half speed, then how it was won ("POINT BLUE: NO ONE GOT TO IT") and the
point's result. HIT or START skips it. The result, its records and its
sting follow.

It is the real rally, not a recording of the screen: the sim is exact,
so the view records the match's inputs (and its two calls into the sim:
RESTART/rematch, and the tuning panel's retune) and runs a second sim
through them. The replay catches up to the rally's serve behind the
card, 600 frames a drawn frame (a ten-minute match takes about a
second). Its state at the serve is checked against the live match's;
if it ever differs, nothing is shown.

Not in the demo, online, lessons, practice or MULTI BALL.

## How

`view/highlight.gd` (`Highlight`): the recording (two ints per slot per
frame), the longest rally and the live snapshots at its serve and its
end, and the playback. While it plays, the view draws the replay's sim
in the live one's place (`MatchView.sim`), with its own glide, and
handles its events for sound and show only (`on_replay_event`: no stats,
score animation, quips or records). The live sim is never stepped or
written by it.

## Tests

`test_highlight`: where it is (a match; not the demo, MULTI BALL or
practice); a bot match to its end: the replay's state where the rally
ended equals the live one's, the live sim never moved, the result
follows; exact through a RESTART and a retune; skipping; none without a
long rally; the caption. `test_layout`: the card with the longest
caption, every ending, keyboard and pad. The tests that run a match past
its end for other reasons (flair, music, the tournament) switch it off.

## Since: the players move (2026-10-20, `PORT-53`)

The replayed players were drawn in the live match's end reaction (a
celebration or slump held by flair, which waits while the replay plays),
so they slid around frozen in it (KNOWN_ISSUES #67). While the replay
plays, no flair reaction or emote is drawn, and the HUD's RALLY sign
(under the caption card) hides; the live ones resume after it.
