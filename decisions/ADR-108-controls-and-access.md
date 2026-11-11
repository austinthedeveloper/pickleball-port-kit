# ADR-108 — Controls and Access: COLOURS, CAPTIONS, ASSIST, the Cup's Pads

Status: **Accepted 2026-11-11** (asked for by the user: "work on the
Controls and Access, skip the one that needs my input", the phase 6
milestone 2027-02). Milestone: `PORT-123` to `PORT-127` (GitHub issues
#13 to #17). PORT-78 (the keyboard presets, #12) waits on the lead's
layout. Builds on ADR-066 (the rings), ADR-076 (the announcer), PORT-12
(ACCESSIBILITY), PORT-29 (the couch cup).

## Decision

Three rows join OPTIONS > ACCESSIBILITY (the page moves up, the logo
hidden behind it, as CONTROLS does), all saved keys with harmless
defaults (no save version):

**COLOURS (PORT-123):** STANDARD, DEUTAN, PROTAN, TRITAN, HIGH CONTRAST:
the four players' colours for the rings at their feet, the P1..P4 tags
over their heads and the lobby's numbers (`Access.TINTS`). The
colour-blind sets are from the Okabe-Ito palette (DEUTAN and PROTAN share
one: it works for both); `test_access` simulates each deficiency
(Machado et al. 2009, full severity) and checks the four stay apart,
and that STANDARD's don't for a deutan. HIGH CONTRAST is pure bright
colours with a dark edge round each ring, so a ring stands out on every
court surface and surround (3:1 at least, the fill or the edge), and the
ball gets a white rim. **Every set, every ring carries its player's
shape** at the front: P1 a dot, P2 a bar, P3 a triangle, P4 a square, so
colour is never the only difference. Display only.

**CAPTIONS (PORT-124):** what the announcer says, in a bar under the
court (one line, or two for the longest), for as long as the line plays;
and the sounds with no picture of their own (THE NET, WHISTLE, APPLAUSE)
as a short gold caption that never covers a line being said. The text
is `data/captions.json`, made from the voice script's CSVs by
`tools/make_captions.py` in the bitmap fonts' letters; a test fails if a
clip has no caption. The Web build has no announcer, so it has the cues
only. Display only.

**ASSIST (PORT-125):** OFF, SWING (KID's auto-swing for every human, at
any difficulty), SERVE (a human server's charged-serve meter moves at
half speed). A sim change, so it's `MatchConfig.assist` and goes through
the sim like any rule (online, the host's travels with its config). OFF
is the ROM's play: the golden traces and the conformance run are
unchanged. **An assisted match counts for nothing**: no records, career,
ladder or achievements (a bracket still moves on), and the result line
says ASSIST SWING: NOT RECORDED.

**The couch cup's pads (PORT-126, KNOWN_ISSUES #52):** a saved cup opened
from the title asks, on PLAY, each player in turn to press Start on their
pad ("P2: PRESS START"); the pad that does is theirs, whatever its id
now. Back from a match it doesn't ask (the pads are known). B or Y backs
out, and the next PLAY asks again.

**Cleanup round 8 (PORT-127):** KNOWN_ISSUES #52 resolved; the READMEs and
the ADR index current.

## Consequences

- The colour sets are checked by simulation, not by colour-blind
  players; the lead may want them tried (For you).
- Captions show the announcer's words, not the crowd's or the music's.
- Tests: `test_access.gd`, `test_menus` (unchanged), `test_layout`
  (ACCESSIBILITY's rows, the caption bar over a match and the title, the
  cup asking for pads). Screenshots: `tools/screenshot.gd colours=N caption`.
