# ADR-104 — ROAD TRIP Talks: Conversations That Go Deeper

Status: **Accepted 2026-10-26** (asked for by the user: "the
conversations don't get longer, the number of them do ... instead of
hearing everything a character has said after 2 rounds, it's now 5", and
"start revealing parts of their personality as we hear more").
Milestone: `PORT-111`. Builds on ADR-087 (ROAD TRIP), ADR-092 (story
beats) and ADR-093 (bonds).

## Context

Each ROAD TRIP conversation outside the story beats had one fixed scene:
a team's scene before its match, a partner's opening in the GARAGE, the
partner's word at the motel and the diner, the ROAD HOGS' taunt. Two
trips in, you had heard all of them, and they kept repeating.

## Decision

Every one of those conversations now has **five** scenes, heard in order,
one per time it comes up. Each scene stays short (one to four pages, like
the first). The first is the scene that was always there; the four after
it show more of who the character is, from the joke they lead with to
what's under it:

- **Teams (all nine, Dawson too):** e.g. Dad jokes when he's nervous and
  keeps a scrapbook of Kiddo's matches; Marge and Walt met when she beat
  him six times in 1962; Brad writes poems and the Gym Bros were picked
  last in gym class; Pete was an accountant and gets seasick; Raven writes
  poems and admits she's having fun; Kai can't swim and Lani studies
  turtles; Mia wants to play singles; Ace practises at dawn because he's
  scared of losing, and Jade nearly quit; Dawson misses his old partner
  (a hint toward the van arc, not its answer).
- **Partners (Pepper and all eight captains), at three places:** the
  GARAGE start (Pepper's from the second trip on, after `start_again`),
  the motel and the diner. Their arcs run from the bit (Dad's jokes,
  Raven's gloom) to why they're on the road with you.
- **The ROAD HOGS:** four more taunts (they live in the RV; Buck knits),
  then four more friendly words after their arc (the horn song's story).

The data is `trip.json`'s `talks` (the four after the first, by team or
partner; Pepper is -1). `RoadTrip.talk` picks the next, counted per
conversation in the trip meta's `talks` (`"teams:3"`, `"motel:-1"`,
`"rival_again"`); after the fifth it goes round again. A story beat due
at the same place still takes the slot and doesn't use up a talk.

- **TRIP OF THE DAY** is the same for everyone, so it always hears the
  first scene and counts nothing.
- **The save:** `talks` is a new trip-meta key with a harmless default
  (`{}`), filled in for old saves; no new save version.
- **Text:** HUD-font glyphs only, at most 36 characters a line (the page
  allows 46), checked in `test_road_trip` and `test_layout`.

## Consequences

- 152 new scenes. Writing more later is data only: add to a list.
- A character's later talks assume you've met them before, never that
  you've seen a particular story beat (the beats stay the only place the
  arcs' reveals happen).
- Not covered: the yard sale and pro shop words, and the trip's end
  scenes (WON, OVER), which stay single.

## Tests

`test_road_trip.test_talks` (order, round again, per-team and per-partner
counts, Pepper's start after the first trip, the ROAD HOGS before and
after their arc, the day's trip uncounted, an old save), `test_the_data`
(four more each, glyphs and lengths), `test_layout.test_trip_scenes`
(every page of every talk, both partners, every device). Screenshots:
`tools/trip_shot.gd` takes `talk=N` and `partner=N`.
