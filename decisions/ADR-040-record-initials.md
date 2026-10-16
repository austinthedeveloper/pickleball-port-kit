# ADR-040 — Record Initials

Status: **Accepted 2026-10-14**
Milestone: `M4-SAVE-03`.
Depends on: ADR-021 (save), ADR-026 (story cards), ADR-032 (save migration).

## Why

The records page showed numbers with no names. An arcade high-score table
says who set them, and asking for initials makes a new record an event.

## What

- **Which records:** the best win streak and the longest rally, the two the
  milestone names. Other records are running totals.
- **When:** a match that beat one or both ends on an **initials card**
  before its result screen. It shows `NEW RECORD!`, the records beaten
  (`BEST STREAK 5`, `LONGEST RALLY 12`, or `STREAK 5  RALLY 12`), three big
  letters with the chosen one underlined, and `UP DOWN  @ NEXT  START OK`.
  One entry names every record beaten.
- **Who:** 1P's pad, like the rest of the result screen. Records count as
  ADR-021 says (the rally in 2P versus too), so 1P names those as well.
- **Controls:** Up and Down change the letter (A-Z, wrapping; held, they
  repeat after 16 frames, then every 4); B, A, or Right moves to the next,
  and past the third saves; Y or Left goes back; Start saves at once.
  Buttons other than Up/Down do nothing for the first 30 frames, so
  mashing B out of the last point cannot enter AAA. After 30 seconds it
  saves the letters shown.
- **Letters start** from the last initials entered this session (AAA after
  power-on).
- **The match waits** under the card as it does under the intro card
  (`g_story`, ADR-026): no simulation, and the frame that closes it keeps
  its input from the result screen. Rematch, NEXT, PARK, and the title
  menu follow as before.
- **A beaten record's initials clear** at once and show `---` until they
  are entered. A match left early (RESTART, MAIN MENU) keeps the new
  number, but asks for no initials: only a finished match does.
- **A run extends its own record** (amended 2026-10-14): once a win
  streak takes the best streak and its initials are entered, the next wins
  of that unbroken run raise the record under the same initials without
  asking again (every win of a run used to ask). A loss ends the run; the
  next record asks once more, as does the first one after a power cycle
  (which run holds it is WRAM only, so the save layout is unchanged).
- **Records page:** the initials are on the BEST STREAK and LONGEST RALLY
  rows, in yellow, before the count; `---` for nobody. Erasing the records
  erases them. The park's records board (ADR-034) is unchanged: its line
  is already full.

## Save (layout 9)

`SaveData` gains `SaveInitials` (two records × 3 bytes, after the settings;
zeros for nobody): 48 bytes, the checksum still on an even offset. Layout 8
(v0.6.0-v0.10.0) is frozen as `SaveV8` and migrates with every record and
setting; nobody holds a record until it is beaten again. Layouts 4 and 7
still migrate (ADR-032). Which records were beaten this match is WRAM only
(`g_save_new_records`), so `GameState` and the golden trace's state are
unchanged.

## Frame budget

The card draws one panel per frame (BIG, the records, the prompt), then
only the letters that changed, on idle frames; the match is frozen under
it. Zero overruns on every `make perf` run, which includes the golden run
through the card.

## Tests

- `test_save.c: test_migrate_v8`, `test_initials`: migration, a beaten
  record clears its initials, entry sets every beaten one and saves, a
  shorter rally or a loss beats nothing, erase clears them.
- `test_story.c: test_initials_card`, `test_initials_need_a_finished_match`:
  never in attract or without a record, letters wrap and repeat, the
  minimum, back and next, the timeout keeps the letters, Start saves; a
  RESTART drops the request.
- MesenCE: the golden run's first match ends on the card (frame 1308) and
  its B presses enter initials; the trace was re-recorded there.
