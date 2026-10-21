# ADR-077 — Achievements

Status: **Accepted 2026-10-21**
Milestone: `PORT-54` (the user's ask: "Achievements: let's get this one
started. An obvious one would be PICKLED: beat an opponent without
letting them score").

## Decision

Thirteen to start (`meta/achievements.gd`, `LIST`), each unlocked once and
saved with the day:

| Achievement | How |
|---|---|
| PICKLED | Win without letting them score. |
| FIRST DINK | Win a match. |
| ACE! | Win a point with a serve they can't touch. |
| MARATHON | Play a 20-shot rally. |
| ON FIRE | Play a 30-shot rally. |
| COMEBACK KID | Win after trailing by 5. |
| MAD SCIENTIST | Win with 3 modifiers on. |
| GLOBETROTTER | Win at all six venues. |
| TOP OF THE LADDER | Beat all eight teams in a row. |
| THE COVER MAN | Beat Dale Dawson. |
| CHAMPION | Win a tournament. |
| PARK SAVED | Finish STORY. |
| SCHOLAR | Finish every PICKLEBALL 101 lesson. |

- They count for P1's side, in the matches the records count (not the
  demo, online, practice, or a match between friends). The rally ones
  and ACE! count in a loss too.
- An unlock shows as a toast ("ACHIEVEMENT: PICKLED", several in turn)
  with its own chime (`8_achievement`, a rising C major arpeggio, from
  `audio/hd-sfx/make_sfx.py`).
- **RECORDS > ACHIEVEMENTS** lists them, DONE on the unlocked; how to
  earn the selected one (and its day, once done) shows under the panel.

## How

`Achievements.check_match` at a match's end (`MatchEnd`), from the sim's
score, `MatchStats` (aces, the longest rally, and `behind`, the most
each side trailed by, from the score after each point) and the config;
GLOBETROTTER keeps the venues won at in `save.data["achievement_venues"]`.
The bracket (a tournament won), STORY's last chapter and PICKLEBALL 101's
last lesson unlock theirs. `save.data["achievements"]` is a new key with
a default: the save stays v6.

## Tests

`test_achievements`: the list in the font; each check, once, announced,
with its day, saved, an old save; the comeback tracking; a real match's
end; SCHOLAR; the RECORDS row and the page. `test_layout`: the page with
each row selected, done and not.
