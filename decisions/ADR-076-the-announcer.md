# ADR-076 — The Announcer

Status: **Accepted 2026-10-20**
Milestone: `PORT-52` (the user's ask: a voiced announcer, no text on
screen; the user recorded the script with an AI voiceover).

## Decision

A 1994 TV sports announcer talks over matches. **Voice only**: nothing
is added to the screen (captions would clutter it). Remaster-only: the
canon bible has no announcer; this one is unnamed.

- **What it says** (`view/commentary.gd`, from the events and phases the
  view already sees): the introduction (the venue, or the CPU team by
  its two players, then the first modifier or the format); a **score
  call** at each serve, built from recorded numbers (the server's score
  rising, the other side's falling; a tie is "five all"; side-out
  doubles adds the server number); an ace; calls at 10, 15, 20, 25 and
  30 shots; how each point ended, by its fault; streaks of 3 and 5, a
  comeback, match point (and a saved one), sudden death, win by 2, side
  out; now and then a shot ("Smash!", only lines short enough to land
  between shots, never two within 1.6 s) or a pickle pun; the close
  call; PLAY OF THE MATCH; the result (a shutout, a close one, a loss,
  the ladder cleared, a story chapter or the park saved); a rematch; the
  pause. The title says "Pickleball Ninety-Four!" once a session.
- **One line at a time** (`view/announcer.gd`): by priority (a pun <
  a point's end < match point < the match's start and end); a higher one
  cuts a lower one off; a line kept waiting goes stale and is dropped; a
  family's variant is never the one just said. The music ducks and the
  crowd's bed dips while it talks.
- **OPTIONS:** ANNOUNCER (its volume, or OFF; 80% by default) and
  COMMENTARY: LIGHT (the big moments), NORMAL (with the score and the
  points; the default), LOTS (more of the rally). SOUND OFF silences it.
  Not in the title's demo. OPTIONS moved up over the logo to fit.

## The clips

The recordings are `audio/announcer/raw/` (253 WAVs, 48 kHz mono, and
the voiceover tool's manifest). `audio/announcer/prep.py` trims them,
sets one loudness (the voiced part at -20 dB RMS, a soft limiter, peaks
under -1 dBFS) and resamples to 24 kHz into `out/`, which
`sync_assets.sh` copies to `game/assets/audio/announcer/` (imported
compressed); it writes `game/data/announcer.json`, each clip's length,
which the voice times its lines by. About a third of the recordings run
past the script's most-seconds (the voice is slower than written): the
lengths are honoured rather than sped up, and only the short ones are
used mid-rally.

## Tests

`test_announcer`: every clip present and every line the commentary asks
for recorded; the voice's priorities, waiting and going stale, variants,
a score call's pieces in order, OFF and SOUND OFF; score calls (server
first, "all", side-out's three numbers); a bot match at NORMAL (the team
introduced, scores called, the result) and LIGHT (no score calls), the
match playing as a bare sim does; the settings saved and the OPTIONS
rows.

## Since: trimmed, and a switch (2026-10-20, `PORT-53`)

After playing 0.19.0 (the user: "it's kind of hilarious"):

- **No team intros.** They took too long. A match opens with the venue
  (a story chapter: its stakes), then the first modifier or the format.
- **A list of lines to take out**, `design/announcer/removed.txt` (ids
  or patterns, with why): `prep.py` leaves them out of the game, so the
  commentary can't ask for them; the recordings stay in `raw/`. The nine
  `team_*` lines are its first entry: 244 clips in the game.
- **ANNOUNCER is a switch** (ON or OFF), and **VOICE VOLUME** its own row
  (10% to 100%: the switch is the way to silence it). A 0.19.0 save with
  the slider at OFF loads as the switch OFF.
