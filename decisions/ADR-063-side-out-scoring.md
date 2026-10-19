# ADR-063 — Side-Out Scoring

Status: **Accepted 2026-10-18**
Milestone: `PORT-40` (the *Pickleball '95* promises, bible §5.8: "the ROM is
rally scoring only"). Remaster-only: the ROM must never have it.

## Decision

**SIDE-OUT**, a toggle on the new **RULES** page (MODIFIERS > RULES, with
WIN BY 2 and LAVA), plays traditional scoring:

- Only the serving side scores. A rally the receivers win scores nothing:
  the serve passes (**SIDE OUT** under the fault word).
- **Doubles:** both partners serve before a side out. A lost rally by the
  first server passes the serve to their partner (**SECOND SERVER**); the
  second server's lost rally sides out. A game opens on the second server
  ("0-0-2"): the opener's first lost rally sides out.
- MATCH POINT shows only for the serving side, the only one that can
  score. POINTS and WIN BY 2 work as before.

## How

- `K.MOD_SIDE_OUT` (512) in `MatchConfig.modifiers`, so it saves, reaches
  online matches and the park, and is off in the ROM's conformance runs.
  The golden traces are unchanged: the side-out state (`server_number`,
  `first_server`, `point_scored`, `opening`) joins the snapshot only when
  it's on.
- **Who serves:** this game's players keep their sides (rally scoring
  names the server by the score's parity, whoever stands there). Under
  SIDE-OUT the server is a person: at a side out, the first server is the
  player on the side the score's parity names, the second their partner,
  each serving from their own side. In real pickleball the server also
  switches sides after each point they win; here they don't (no one does
  in this game), so a server keeps serving to the same receiver.
- `Sim.next_server_team` decides the next serve; `serve_setup` places it.

## The page

MODIFIERS outgrew the screen with GLOW and INVERSE and the '95 rules to
come, so the scoring and fault rules moved to their own RULES page,
reached from a RULES row on MODIFIERS (its value: the rules on). Y on
RULES goes back to MODIFIERS. The bits and the save are unchanged.

## Tests

`test_side_out`: singles (the server scores and keeps the serve, a lost
rally sides out, no match point for the receivers), the doubles rotation
(0-0-2, server 1 then 2, the partner serving on after scoring), the
SECOND SERVER line, bot matches in singles and doubles that finish with
every point the server's side's, and rally scoring unchanged.
`test_menus`: RULES from MODIFIERS and back.
