# Product Brief

Status: **Approved baseline**  
Scope owner: project lead  
Change rule: update this page before accepting work that expands the POC.

## Experience goals

1. **Readable in one glance.** The ball, its shadow, the net, legal court, and both players must remain distinct on a CRT.
2. **Physical and punchy.** Movement has acceleration and braking; swings commit for several frames; clean contact produces a short freeze, strong sound cue later, and a decisive ball response.
3. **Arcade first.** A complete match lasts roughly two to four minutes. Inputs are simple enough to learn during the first serve.
4. **Authentically constrained.** The ROM is designed around SNES object, palette, VRAM, CPU, and VBlank limits from day one.
5. **Built for doubles.** The POC renders two players, but entity, input, spawn, collision, and palette systems support four without redesign.

## Camera and court

The entire court is visible at once. Court length runs left-to-right; the net is a vertical divider at screen center. The view is a shallow top-down/three-quarter presentation, not a scrolling side view. Players move freely inside their own half. Ball height is shown by separating the ball from a ground shadow. The court is drawn in fixed perspective; rules are evaluated in rectangular world space ([ADR-011](10_MOCKUP_DECISIONS.md#adr-011--perspective-court-with-world-to-screen-projection)).

The court must show:

- two baselines;
- two sidelines;
- the net;
- both non-volley-zone (“kitchen”) lines;
- one centerline in each service area.

The court geometry in game units is authoritative; the background art must be generated or checked against it so visual lines and collision never disagree.

## Tone reference

“Super Dodge Ball feel” means broad animation poses, readable anticipation, modest knockback/recoil, fast recovery, expressive impact, and compact matches. It does **not** mean copying characters, art, code, stages, audio, move names, or exact mechanics from an existing game.

## Audience

- Primary: retro players who can understand D-pad + one action button immediately.
- Secondary: homebrew players using original hardware, FPGA systems, or accurate emulators.
- Development audience: a small team that needs tasks with binary acceptance criteria.

## Design pillars translated into tests

| Pillar | Observable test |
|---|---|
| Readable | A tester can call “in/out,” identify the controlled player, and track the ball on a consumer CRT from normal distance. |
| Punchy | Contact has visible pose change and a deterministic response within one frame of the collision decision. |
| Simple | A first-time player completes a legal serve with only the D-pad and B prompt. |
| Hardware honest | The same ROM completes the smoke suite in two accuracy-focused emulators and on real hardware. |
| Reusable | All player color variants use one tile set; no duplicate player frame graphics are exported. |

## Release ladder

| Stage | Players | Rules | Content |
|---|---:|---|---|
| POC | 1 human + 1 CPU | Simplified rally scoring | 1 court, 1 shared body, 4 palettes |
| Vertical slice | 1–4 humans/CPU | Doubles rotation and fuller pickleball rules | 1 polished court, audio, presentation |
| Game | 1–4 humans/CPU | Final rules and modes | Multiple characters/courts/modes |

## Guardrails

- Never tie simulation to animation completion.
- Never use a distinct graphics sheet solely to recolor a player.
- Never add a sprite effect without checking the worst shared scanline.
- Never hide an invalid state behind an animation; display debug state in debug builds.
- Never call the POC hardware-ready based only on a permissive emulator.
