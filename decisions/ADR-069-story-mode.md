# ADR-069 — Story Mode: Save the Park

Status: **Accepted 2026-10-19**
Milestone: `PORT-44` (the user's ask: the SNES story's theme, "in a much
higher style").

## Decision

STORY is the title's first row. It tells the canon plot (bible §5.2,
SNES ADR-077) in eight chapters, one per ladder team in ladder order:
Mr. Grimsby of Grimsby Parking Co. means to pave Riverdale Park; you and
your partner PEPPER play each team for its signature on the petition.

- **The scenes are a visual novel over the venue**: the chapter's venue
  layers as a still, tinted for its time of day, drifting; you and Pepper
  on the left, the team's two players on the right, walking on, idling,
  the speaker lit and bobbing and the rest dimmed. A dialog panel with a
  name tag types the lines (2 characters a frame): the hit button
  finishes the typing, then turns the page; START skips the scene; a
  click works like hit.
- **Grimsby is never a sprite** (canon): he speaks through the park's
  loudspeaker (drawn on its pole, its waves pulsing) or in letters on
  Grimsby Parking Co. letterhead.
- **A chapter card** opens each chapter: CHAPTER n OF 8, its title, the
  venue, time and team, the twist, the petition's count. A win ends on
  the petition, the teams that signed checked off.
- **The match** is doubles, you and Pepper against the chapter's team at
  its venue and time, at MATCH SETUP's difficulty and points, as the
  active career player if there is one, with the chapter's twist (one of
  the modifiers, e.g. WIND on the lake, MOON under the sea, WIN BY 2
  against the Champs). Pepper is a CPU partner, appended to the
  opponents after Dawson (`Opponents.PEPPER`), so the ladder stays eight.
- **A loss** shows Pepper's word and plays the match again; MENU on the
  result goes back to the title. The chapter is kept either way (SNES
  ADR-077); there is no penalty.
- **The ending** after chapter 8: the park saved, THE END, and an
  epilogue that sends you to Dale Dawson. Clearing the story also
  unlocks Dawson (as a ladder clear does), counts in `story.cleared` and
  starts it over; the STORY row then reads PARK SAVED!.
- Display and flow only: the matches are ordinary sims, the golden and
  conformance traces unchanged.

## How

`data/story.json` holds the script (8 chapters of team, title, venue,
time, twist, scene, win, lose; the ending and epilogue; Pepper's look).
`meta/story_mode.gd` (`StoryMode`) reads it, builds a chapter's
`MatchConfig`, and keeps the progress in `save.data["story"]` (a new key
with a default: the save stays v6). `view/story_scene.gd` (`StoryScene`)
plays a scene and signals `done(skipped)`. `scenes/main.gd` runs the
chain: intro → match → win (→ next intro, or the ending) or lose →
match. Player Select is skipped: you are the career player, or MATCH
SETUP's look.

## Tests

`test_story_mode`: the script (eight chapters in ladder order, venues,
times and twists the game has, lines that fit and that the font can
draw, every win ending on the petition, Grimsby a voice and a letter);
a chapter's config (doubles, Pepper, the twist, the team); the progress
(each win advances, the last saves the park and starts over, kept in the
save, an old save starting at chapter 1); the scene's paging; the title's
STORY row reaching the chapter's scene and its match. `test_layout`
checks every page of every scene with keyboard and pad prompts.
