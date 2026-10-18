# Gameplay Spec

Status: **POC rules locked**

## World coordinates (rules space)

Simulation uses signed 16-bit 12.4 fixed-point values (1/16 px; see ADR-006). Whole-pixel court anchors, defined once in `include/court.h`:

| Element | Value |
|---|---:|
| Visible screen | 256×224 |
| Court left/right baseline | x = 16 / 240 |
| Net plane | x = 128 |
| Left/right kitchen line | x = 92 / 164 |
| Top (far) / bottom (near) sideline | y = 90 / 170 |
| Service centerline | y = 130 |
| Left player legal ground point | x = 4..120, y = 84..180 |
| Right player legal ground point | x = 136..252, y = 84..180 |
| Net height | z = 12 px at crossing |

A player's position is the ground point between the feet; the ball's x/y is its ground position.

These are initial tuning values. Constants belong in one court-definition module; background construction, player clamps, serve boxes, line calls, and AI must read from the same definitions.

## Screen projection

Gameplay never leaves the rectangular world coordinates above; only presentation projects them into a trapezoidal screen court ([ADR-011](10_MOCKUP_DECISIONS.md#adr-011--perspective-court-with-world-to-screen-projection)).

```text
s(y)      = per-row horizontal scale, 8.8 fixed point, from a ROM lookup table
screen_x  = 128 + (((world_x - 128) * s(world_y)) >> 8)    // 32-bit intermediate
screen_y  = world_y                                         // no vertical foreshortening in POC
ball draw = (screen_x, screen_y - z)                        // z unscaled in POC
shadow    = (screen_x, screen_y)
```

- `s` is linear in `y`: 0.84 (216/256) at the far sideline y=90 and 1.00 (256/256) at the near sideline y=170. Rows outside the court extrapolate linearly and clamp to s 0.75..1.10 over y 0..223.
- The net plane x = 128 maps to screen x = 128 on every row, so the net stays a vertical divider.
- The asset generator emits the table as `assets/generated/court_projection.h` and rasterizes the court lines through it; the game includes the same header. Both round half up after the shift.
- Input stays in world space: Up moves along world −y even though that path slants slightly on screen.
- Players and ball do not scale with depth; hit reach is identical in world space.

## Controls

| Input | POC behavior | Future-compatible behavior |
|---|---|---|
| D-pad | Move on the court plane; diagonals normalized approximately | Same |
| B | Context hit; serve when holding the ball | Standard hit |
| Y | Soft shot: lob, or dink when aimed away from the net (ADR-019) | Same |
| A | Drive: faster, flatter shot (ADR-019) | Same; paddle POWER scales it (ADR-015) |
| Start | Pause/unpause | Same |
| Select | Toggles diagnostics in debug builds only | Same |

One button is intentional. Pressing B opens a short swing window; direction at contact influences the outgoing target. Holding B is not required.

## Player movement

- Update at one simulation step per displayed frame on NTSC.
- Acceleration: 0.25 px/frame² per axis.
- Maximum cardinal speed: 1.50 px/frame.
- Diagonal input uses a 181/256 multiplier per axis to approximate normalization.
- Friction with no input: subtract 0.375 px/frame toward zero.
- A swing reduces maximum speed to 0.75 px/frame until recovery.
- Clamp the player collision center to its legal half for the POC.
- Players do not collide with each other in M1–M3. Add teammate separation before doubles.

Values are tunables, not scattered literals.

## Player state machine

`IDLE → MOVE → WINDUP → ACTIVE → RECOVERY → IDLE`

- `IDLE` and `MOVE` may enter `WINDUP` on B.
- `WINDUP`: 4 frames; no contact.
- `ACTIVE`: 3 frames; at most one ball contact.
- `RECOVERY`: 7 frames; movement remains reduced.
- A new swing cannot begin during windup, active, or recovery.
- Animation reads this state; animation does not own it.

## Ball model

The ball is a deterministic entity with `x`, `y`, `z`, `vx`, `vy`, `vz`, `last_hitter`, `bounce_count`, and `rally_state`, all integers/fixed point.

Per frame:

1. Apply `x += vx`, `y += vy`, `z += vz`.
2. Apply gravity to `vz`.
3. If `z <= 0`, set `z = 0`, resolve a court bounce, and increment the side’s bounce count.
4. When the x segment crosses the net plane, fault if interpolated z is below net height.
5. When the ground position leaves the court, call out at the first ground contact, not while airborne.
6. Project `(x, y)` to screen space; draw the shadow at the projected `(screen_x, screen_y)` and the ball at `(screen_x, screen_y - z)`.

Suggested starting tunables:

| Parameter | Value |
|---|---:|
| Gravity | -0.1875 px/frame² |
| Standard hit horizontal speed | 2.5–3.0 px/frame |
| Standard hit initial vertical speed | 2.5 px/frame |
| Bounce vertical retention | 0.55 |
| Bounce planar retention | 0.92 |
| Hit reach from player ground point | 22 px x / 16 px y / 24 px z |

Use swept crossing tests for net and ground boundaries. Do not rely on exact coordinate equality.

## Aiming

On contact, the hitter’s opponent-side target is selected from current D-pad input:

- no vertical input: center lane;
- Up/Down: shift target toward the corresponding sideline;
- toward opponent: deeper target and slightly more pace;
- away from opponent: shorter target and slightly more arc.

The physics module derives velocity from start, target, and flight duration. Flight duration is horizontal distance divided by pace: 3.0 px/frame deep, 2.75 neutral, 2.5 short. It is clamped to 24–46 frames, which keeps lobs below the HUD (apex about 50 px) and inside the AI's 60-step prediction. Randomness is excluded from POC shot physics.

**Contact timing.** A swing contacts the ball on the first active frame with the ball inside the reach volume. If that contact is inside the sweet box (|dx| ≤ 14 px, |dy| ≤ 10 px from the player's ground point), the shot goes where it was aimed. Otherwise it is *stretched*: the target moves 20 px toward its sideline and 16 px deeper, which usually lands out. Swinging too early or too late therefore costs the point. That is the skill the one-button control asks for.

The shot direction is the intent's aim (`aim_x/aim_y`). For a human it is the D-pad at contact, the same input that moves the player. The CPU can aim without moving.

## Simplified POC rules

The POC favors a complete match loop over tournament fidelity.

1. Match is first to 5 points; win by 1.
2. Rally scoring: every rally awards a point.
3. Server begins in a simplified baseline service stance and serves diagonally into the opposite service box. Exact foot-position faults are deferred with the kitchen foot-fault rule.
4. Serve contact is automatic from a short toss after B; the player still controls aim lane.
5. Serve faults: net, outside the diagonal box, or kitchen contact.
6. The two-bounce rule is enforced: the serve and return must each bounce once before volleys are legal.
7. After those two required bounces, one bounce is allowed on each side.
8. A second bounce, net contact, or out ball loses the rally for the last hitter’s side.
9. Non-volley-zone foot faults are **not** simulated in the POC. The kitchen lines and short-ball behavior remain visible. (The Godot port calls a volley from inside your own kitchen: ADR-055.)
10. The point winner serves next. Press B after the result banner to begin.

UI must label this mode “ARCADE RULES” so the simplifications are explicit.

## CPU opponent

The CPU is intentionally legible, not optimal.

1. Predict the next ground intersection using the same ball constants, capped at 60 simulated steps. Balls predicted to land out are left alone.
2. Aim to meet the ball near the top of its first bounce, standing 10 px behind the contact point. The CPU always lets the ball bounce once.
3. Move toward the target with 80% of player maximum speed.
4. Swing when a swing pressed now would make its first contact inside the sweet box during the active frames, or as a last chance before the ball leaves reach. Once committed, plant the feet.
5. Difficulty is a fixed offset, not random jitter. On every 7th incoming shot (`AI_LATE_SHOT_PERIOD`) the CPU is deliberately late and takes a stretched last-chance contact.
6. Aim away from the opponent's half of the court. Shot choice follows ADR-019: a put-away drive on a high ball near the net, a lob over a net player, a dink every 4th shot, otherwise standard shots alternating deep and neutral.
7. After a hit, recover toward `(208, 130)`.

Measured with host simulations (`test/test_match_flow.c`): a stand-in player that mistimes every 2nd shot wins 1 of 20 matches, and one that mistimes every 10th shot wins 19 of 20. Simulated matches last 45–85 s. Human novice matches still decide the final tuning.

In debug builds, show predicted landing as one background marker. The CPU must not read future player input or alter ball physics.

## Rally state machine

`BOOT → ATTRACT_READY → SERVE_SETUP → SERVE_TOSS → LIVE → POINT_RESULT → MATCH_RESULT`

- Only `LIVE` accepts ordinary ball contacts.
- All state transitions use frame counters.
- `POINT_RESULT` lasts at least 60 frames and may advance early with B after 20 frames.
- `MATCH_RESULT` requires B for rematch; Start remains pause everywhere except boot.

## Feedback priority for POC

1. Ball/shadow separation.
2. Swing anticipation and contact pose.
3. Two-frame hit stop for a clean non-serve contact; the UI and pause detector continue safely.
4. One-frame palette flash on hitter or ball.
5. Text banner: `NET`, `OUT`, `TWO BOUNCES`, `POINT`.

Audio is not required by M3, but event hooks must exist for future serve, hit, bounce, fault, and point sounds.
