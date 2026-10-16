# Next Game Playbook

Lessons from Pickleball '94 (SNES, C + 65816 asm, 2026-10-11 → 10-16:
six days, 32 ADRs, 13 releases), reorganized for a different game on a
different platform. It is ordered by **what to do first**, and it calls out
the problems that cost the most rework so you can head them off.

Tags: **[ANY]** applies everywhere. **[CONSTRAINED]** applies to any
platform with a hard frame, memory, or compiler limit (retro consoles,
handhelds, web, mobile, low-end PC). SNES-only details are in §10, for the
pattern only.

---

## 1. The ten rules (if you read nothing else)

1. **Deterministic simulation + golden trace + bot harness, before features.**
   Every later change was provable ("golden trace identical") only because
   these existed. Build them in week one, not after the POC.
2. **Simulation state and presentation state never mix.** About half the
   features (replays, quips, crowd, watchers, venues, colours) shipped with
   zero simulation risk because they were display-only.
3. **Test harnesses run on the shipped schedule.** One AI tuning pass was
   invalidated because tests ran every CPU every frame while the game ran
   them every 4th (ADR-043). If the game staggers, skips, or throttles, the
   tests must too.
4. **Save migration exists before the first release.** Freeze each layout,
   bump a version, migrate, and test loading an old image. Players lost
   saves once because this came one release late.
5. **Tuning lives in data, and the build validates it.** Budgets, contrast,
   string lengths, and "defaults equal the code constants" are checked at
   build time. Wrong data fails the build, not the playtest.
6. **A per-scenario performance gate with the worst case named.** "4 AIs +
   all modifiers + point ending" was the real budget case. Measure it from
   the day it becomes possible.
7. **Measure the root cause per event before turning dials.** The doubles
   balance was fixed by logging *why* each point ended (every CPU out-ball
   came from an off-centre contact), not by nudging difficulty (ADR-038).
8. **The simple input stays safe.** Adding a skill mechanic must never make
   the default press riskier (charged serve, ADR-044).
9. **Every modal swallows its closing input.** The press that closes a card
   or menu must not also act in the game. This bug recurred four times.
10. **Record rejected designs, with the reason.** It stops you (or an AI
    assistant) from re-trying them.

---

## 2. Build order (prioritized)

The order here is the order that *would have avoided rework*, not the order
it happened in.

### Phase 0: foundations (before any gameplay)

| # | Item | Why first |
|---|---|---|
| 0.1 | Pin the toolchain/engine version; reproducible build; build ID in the binary | "Latest" broke builds; a dirty build ID matches no commit |
| 0.2 | Fixed-step deterministic sim (integer/fixed-point if floats aren't deterministic on the target) | Everything below depends on it |
| 0.3 | Frame pipeline written down: input → intent → movement → physics → collision → rules → render → present. Rendering never mutates the sim | Stops order-dependent bugs |
| 0.4 | Headless runner: boot the real build, feed a scripted input timeline, take screenshots, read memory by symbol, poke memory to set up a repro | It was promoted from a scratch script later; it should be the first tool |
| 0.5 | Golden trace: per-frame sim state over a scripted run, diffed after each change | Proves refactors and optimizations don't change play |
| 0.6 | Frame-budget gate: N named scenarios, each with an allowed-overrun count (normally 0), plus a hang check and a sound check | Frame drops were the #1 recurring problem |
| 0.7 | Host-side unit tests for the sim (same code compiled for the dev machine) | Fast feedback; but see §4.5 on toolchain bugs |
| 0.8 | Debug overlay: state, positions, overrun latch, last fault | Cheap and used constantly |
| 0.9 | Repo conventions: ADR folder, KNOWN_ISSUES table, IDEAS and GOOFY_IDEAS, milestone sheets with task IDs, CLAUDE.md (§9) | The paper trail made fast iteration safe |

### Phase 1: core loop (POC)

- One mode, one level, one opponent, a full match loop: start, play, score,
  result, rematch. Rematch must equal a fresh state (test it).
- Data model sized for the **final** maxima now (4 players, slots and teams
  stable), even if only 2 are active. Doubles was "almost free" because
  rules were team-based and slots were reserved from day one.
- Identity (colour/look) is data per entity, never derived from slot index.
- An event seam (sim emits SERVE/HIT/BOUNCE/FAULT/POINT; effects and audio
  subscribe). Sound later replaced a stub body without touching the sim.
- Authoritative geometry in one module; art is generated from or checked
  against it ("the line you see is the line that's called").

### Phase 2: core systems (decide shape before tuning numbers)

Do these **before** any balance pass:

1. All players/modes the game will have (e.g. doubles), with the worst-case
   perf scenario added to the gate the same day.
2. Full input set and shot/move types.
3. **AI capability**: positioning, teamwork, situational choices, aim. Build
   the whole capability stack first.
4. Save system with migration (§6), even if it stores one setting.
5. Options/difficulty: scale **time** (skip sim steps), not physics
   constants, so arcs and AI prediction stay valid (ADR-025, reused twice).
6. Menu structure designed up front with room to grow (§7).

### Phase 3: tune once

- Personalities/levels as data rows of AI knobs.
- A stats harness that plays bots against each opponent and prints whether
  the ladder is in order. Tune here, once. (In this project, AI depth came
  after the ladder was tuned, so the ladder was re-measured about six times.)

### Phase 4: content and polish (cheap if Phases 0–2 hold)

Venues, colours, night, story cards, portraits, replays, quips, crowd,
initials, hats, ambience. Keep each display-only where possible: then
"golden trace identical" is its whole proof of safety.

### Phase 5: meta layers last

Career/progression and hub worlds touch everything (save, select, palettes,
UI). Stage them data-first: data + tests → page → in-game → gear. That
staging worked well (ADR-047).

---

## 3. What was core vs polish (value per cost)

| Category | Items | Verdict |
|---|---|---|
| Load-bearing | team-based rules, shot types, stat budget for gear, save + migration, AI personalities as data + stats harness, time-scaled difficulty, AI depth (net play, teamwork, situational shots, aim), the event seam | Build early and well |
| Invisible infrastructure | golden trace, perf gate, stats harness, probe/poke tool, pitfall lint | Highest return in the project |
| Real player value | practice mode with targets, options, pause menu | Medium cost, keep |
| Cheap polish | colours, venues, night, cards, replay, quips, watchers, hats | Cheap *because* palette/data/display-only |
| Expensive wildcard | open-play park hub (four amendments, half-speed first build) | Fun, but budget it like a mode, not a gag |

---

## 4. Common problems: symptom, cause, prevention

### 4.1 Frame budget **[CONSTRAINED]**

*Symptom:* rare dropped frames in the busiest scenario (four AIs, the
attract demo behind a menu, the frame a point ends).
*Causes seen:* several AIs thinking on the same frame; a lookahead (predict
the ball) per AI; big UI redraws in one frame; save/checksum/audio
hand-offs landing on heavy frames.
*What fixed it, in order of cost:*
1. Dirty flags and caching: redraw only what changed; share one
   prediction per ball flight instead of one per AI.
2. Staged work: one UI panel per frame; long text in halves.
3. A deferral helper: "defer if past budget line N, at most M frames in a
   row" (it got written three times; write it once).
4. Stagger AI thinking across frames, **and mirror that schedule in tests**.
5. Tables instead of multiply/divide on slow CPUs.
6. Hand-optimized hot paths, keeping the portable version as the reference
   that host tests run, with a trace that compares the two.
*Prevention:* the perf gate from Phase 0, with the worst case named; keep
5–10% headroom, because "under budget" at one input alignment wasn't at
another. Report **headroom**, not just failures: the worst frame per
scenario, the time the per-frame uploads use (VBlank on the SNES, the GPU
upload window elsewhere), and per-stage averages from a profiler build. An
overrun count of zero hid a commit step using 32 of 37 VBlank lines, which
ruled out streaming animation frames until it was measured and cut to 22.
*Also:* an optimization can make the worst case slower while helping the
average (a lookahead filter that rarely fires on the hardest mode). Check
the worst case after every optimization, not just the typical one.

### 4.2 AI balance drift **[ANY]**

*Symptom:* every AI improvement knocks the difficulty ladder out of order.
*Prevention:*
- Build capability first, tune personalities once (Phase 3).
- A deterministic stats harness with an "is the ladder in order?" output.
- Separate knobs per context (the doubles-only second player let doubles be
  tuned without touching singles).
- Log per-point outcomes (who erred, how) before changing numbers.
- 2×2 on/off tables per feature: one feature can help one team and hurt
  another.
- Bots don't model human reaction time. They overstate the effect of speed
  changes; keep defaults until real play decides.
- Every AI upgrade exposes a counter-weakness (net players → need drops and
  dinks). Plan for pairs.

### 4.3 Save compatibility **[ANY]**

See §6. Also: append new enum values at the **end** (inserting colour
presets mid-list needed a remap migration).

### 4.4 Uninitialized state **[CONSTRAINED; ANY in spirit]**

Power-on RAM is not zero on many platforms (and pooled/reused objects
everywhere). It caused a demo freeze and a stale AI flag. Rule: initialize
every static at boot or scene entry. The golden trace over randomized
power-on RAM catches it.

### 4.5 Toolchain bugs **[ANY with niche compilers]**

The compiler miscompiled `a || !b`, breaking seven places that host tests
(a different compiler) passed. When the host and the target disagree,
suspect the toolchain, read the generated code, and then **add a lint** that
fails the build on the pattern. A fix alone isn't enough.

### 4.6 Input bleed between screens **[ANY]**

The press that closes a modal also served/swung. A standard rule: the
closing frame consumes its input; modals have a minimum display time and an
input lockout against mashing (30 frames for initials).

### 4.7 Readability **[ANY]**

- Build-time contrast checks (lines and ball against every surface, every
  time of day).
- Aesthetic choices can break gameplay (a black court hid the ball shadow,
  which is how players read height).
- Telegraph threats (the ball machine's nozzle turns to aim).

### 4.8 Fragile UI tests **[ANY]**

Scripted tests that navigate menus by counting presses broke whenever an
entry was inserted. Give tests a way to jump to a screen or state directly
(the poke tool), or navigate by label.

### 4.9 Scope creep **[ANY]**

Locked exclusions per milestone, and "deferred means don't accidentally
implement it". Ideas go to IDEAS.md, not into the current task. Goofy
ideas get their own file so they don't pollute planning.

---

## 5. Testing toolkit (build all of it)

| Tool | What it does | Catches |
|---|---|---|
| Host unit tests | Sim code compiled natively | Rules, math, menus, migrations |
| Golden trace | Per-frame sim state, scripted run, byte diff | Any unintended sim change, uninitialized state |
| Perf gate | Named scenarios with allowed overruns, hang check, sound check | Frame drops, hangs, silent audio |
| Stats harness | Bots vs every opponent, deterministic, "ladder order: yes" | Balance regressions |
| Probe/poke | Read/write memory by symbol on the real build | Fast repros without playing up to them |
| Asset validation | Budgets, palette roles, sizes, contrast, string lengths, data = code defaults | Bad data at build time |
| Pitfall lint | Grep-level checks for known compiler/engine traps | Toolchain bugs |
| Invariant soak | Long run asserting "every entity in exactly one place" | Queue/rotation bugs |

Coverage gap to avoid: soak tests that never reach the expensive scenario
(the doubles demo only started after minutes idle, so a frame drop shipped
for several versions). Make sure the gate runs the worst case.

A golden-trace caveat: if the scripted player never wins a point, those
paths have no emulator coverage. Use a bot-driven trace or several scripts.

---

## 6. Save system recipe **[ANY]**

1. Two copies, each with a magic number, a sequence counter, and a
   checksum. Write to the older copy, so a torn write loses only that write.
2. Each released layout frozen as `SaveV<n>` with a size assertion.
3. Load: validate against the layout its version names, migrate the newest
   valid copy, write both.
4. Every layout change: freeze, bump, migrate, and add a test that loads
   the old image.
5. Avoid bumps with reserved bytes where 0 means the default.
6. Write only at safe points (match end, leaving a menu); on slow hardware
   the checksum itself can cost a frame.

---

## 7. UI and menus **[ANY]**

- Design the menu tree for the final feature count up front. The title
  grew one entry at a time until one had to be replaced.
- One reusable settings-row component (label, values, wrap, restore). Three
  copies of the same editor got written.
- Name entry: an arcade keyboard beat Up/Down letter cycling.
- Previews: a posed, frozen character beat a live demo behind the editor.
- Make progress visible in the next action. "B after a win replays the same
  opponent" looked like a broken ladder.
- Text is data: validated for length and glyph set at build time.

---

## 8. Art and assets **[ANY; budgets are CONSTRAINED]**

- One body set + palette-swapped identity + small accessory parts (hats,
  ponytails) covered 16 opponents with no new body art. Escalation order:
  palette → accessory → selective alternate frames → separate body set.
- Plan the character size against the per-line sprite and memory budget
  before drawing. Bigger or more detailed characters were the hardest thing
  to add late, because sprite memory and per-line limits were already full.
  Reserve room for animation growth from day one.
- Palette roles (outline, skin ramp, shirt ramp, …) as a contract the
  build enforces, so runtime composition (skin × team × paddle) works.
- Fixed foot anchor and declared frame order (manifest, not filenames).
- Non-interactive conversion, run by the build, with a size/budget report.
- Synthesized audio from code (deterministic Python) avoided licensing and
  was fully reproducible.
- Handedness under horizontal flip was never solved (a mirrored sprite
  swaps paddle hands). Decide early whether to flip or draw both facings.

---

## 9. Process that worked (copy it)

- **CLAUDE.md** with: build/test commands, the "before calling it done"
  list (check, perf, golden, stats, screenshot), the rules of the code
  (compiler traps, duplicated hot paths that must change together, memory
  not cleared), and how to run the build headless.
- **ADRs**: one per feature, numbered; decision, why, details, rejected
  options, verification; amendments appended with dates instead of
  rewrites.
- **KNOWN_ISSUES**: a numbered table; fixed rows stay, marked Resolved with
  the branch and the test.
- **Milestone sheets**: task IDs (`M4-SAVE-03`), each with *Accept* and
  *Verified* lines; the checkbox flips in the same commit as the code.
- **Branches** per feature off main; the human reviews and merges.
- **Refactor pass** (behavior-preserving, golden-trace-proven) right after
  the POC and before features. It paid for itself.
- Releases: tag + attached build + checksum + generated notes; refuse to
  publish from a dirty tree.

### Starter templates

ADR:

```markdown
# ADR-0NN: <title>
Status: Accepted (YYYY-MM-DD)
## Decision
## Why
## Details
## Rejected (and why)
## Verification   (tests, perf gate, golden, stats)
## Amendments     (dated)
```

Milestone task:

```markdown
- [ ] `M2-AI-03` <one line>
  - Accept: <observable, binary criteria>
  - Verified: <ADR, tests, timelines, numbers>
```

Known issue row:

```markdown
| # | Severity | Issue | Reproduction | Status / reason |
```

---

## 10. Platform-specific lessons, generalized

| SNES specific | General form for the next platform |
|---|---|
| 816-tcc: multiply is a library call, pointer derefs and 32-bit math slow | Learn your compiler/runtime's cost model in week one; write the "rules of the code" list before hot code exists |
| `a \|\| !b` miscompile | Toolchain bugs exist; lint for known ones |
| 34 sprite slivers per scanline; OBJ VRAM full | Find the hard per-frame and per-line render limits; budget the worst row/draw call in docs and a stress scene |
| 8 OBJ palettes, all used in doubles | Count shared global resources (palettes, texture slots, audio voices) per mode, not per scene |
| VBlank-only VRAM writes; staged HUD | Know what can be uploaded per frame; stage big updates |
| Sound CPU hand-off costs 60–110 scanlines | Async subsystems still have a sync cost; defer it to light frames |
| FastROM needs 120 ns cart | Hardware variants matter; record the test hardware in a log |
| Headless emulator can't press port 2 | Know your harness's blind spots; list them in KNOWN_ISSUES |
| WRAM random at power-on | Never trust initial memory or pooled-object state |
