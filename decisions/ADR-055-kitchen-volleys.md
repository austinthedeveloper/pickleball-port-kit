# ADR-055 — No Volleys From the Kitchen

Status: **Accepted 2026-10-18**
Milestone: `PORT-26` (Godot port only). Amends: `01_GAMEPLAY_SPEC.md`
rule 9 ("non-volley-zone foot faults are not simulated"). Depends on:
ADR-033 (LAVA), ADR-035 (net play), ADR-052 (the port).

## What

Pickleball's kitchen rule, which the SNES game left out on purpose
("ARCADE RULES"): **a volley made from inside your own kitchen loses the
point**, called **KITCHEN!** (the serve's kitchen fault already had the
word). Reported as a bug by the player on 2026-10-18: you could stand at
the net and slap every ball out of the air.

- A **volley** is a rally contact before the ball has bounced
  (`Sim.contact_volley`, set in `resolve_player_hits`).
- **Inside the kitchen** is `Sim.in_kitchen`, the same test LAVA uses: the
  player's feet strictly between their kitchen line and the net, within
  the sidelines. The line itself is behind the kitchen here, a small
  arcade allowance (real rules count the line as kitchen). *Amended by
  ADR-059 (SNES ADR-052): the line counts as kitchen now, as in the ROM
  (`Sim.court_in_kitchen`).*
- **Standing in the kitchen is fine**, and so is hitting a ball that has
  bounced there. A volley from behind the line is fine.
- The **two-bounce rule comes first**: the servers' early volley is still
  VOLLEY!. The receivers may volley the third shot, but not from the
  kitchen.
- Not called: the momentum rule (carrying into the kitchen after a
  volley). Practice doesn't apply match rules, as before.

## The CPUs

They obey it. `ai._swing_connects` won't swing at an unbounced ball
where the contact would be from the kitchen, and `_plan_volley` doesn't
plan one from there; a CPU in its kitchen steps back behind the line to
volley, or lets the ball bounce. In practice they rarely meet it: the
net-rushing teams wait 44 px from the net and the kitchen is 36 px deep
(ADR-035), so 4 bot-vs-CPU doubles matches saw 64 volleys and no kitchen
fault. `test_kitchen.test_a_cpu_in_the_kitchen_waits` puts TWINS in the
kitchen with a ball coming through the air: without the check they
volley there and lose the point.

## Golden traces

Unchanged: no volley from a kitchen in any of the three traces. The stats
harness is unchanged too (10, 6, 0, 0; 8 and 0; 0 and 18).
