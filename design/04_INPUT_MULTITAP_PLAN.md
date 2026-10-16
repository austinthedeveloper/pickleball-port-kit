# Input and Multitap Plan

Status: **POC API required; four-human activation planned as `M4-MP-01`**

## Physical topology

- Controller port 1: Player 1 standard pad.
- Controller port 2 without accessory: Player 2 standard pad.
- Controller port 2 with Super Multitap: logical pads 2–5 are available to the library; the game uses the first three of those for Players 2–4 and leaves the fifth physical slot unused.

For the POC, slot 0 is human and slot 2 is CPU. This deliberately tests non-adjacent team slots.

## Logical player mapping

| Game player | Team | Default POC owner | Future physical source |
|---|---:|---|---|
| P1 | Left | Pad 1 | Port 1 pad |
| P2 | Left | Inactive | Multitap pad 3 |
| P3 | Right | CPU | Port 2 pad / Multitap pad 2 |
| P4 | Right | Inactive | Multitap pad 4 |

The join screen in the future may remap these, but gameplay code receives only `PlayerIntent[4]`; it never reads pad registers directly.

## Input abstraction

Each frame stores:

```text
held[5]
pressed[5] = held & ~previous
released[5] = previous & ~held
```

Then the ownership layer creates one `PlayerIntent` per game player:

```text
move_x: -1, 0, +1
move_y: -1, 0, +1
hit_pressed: bool
pause_pressed: bool
source: NONE, PAD, CPU
```

Only the input module calls `padsCurrent`, `padsDown`, or Multitap detection. CPU code emits the same intent structure as a pad.

## Detection policy

1. Detect the PVSnesLib-supported MultiPlayer5/Super Multitap during boot before the first match.
2. Store accessory presence as configuration, not a per-frame gameplay branch.
3. Display `MULTITAP: YES/NO` on the hardware-test screen.
4. Never write to the port-2 I/O control register from game code while Multitap support is active; use the library path.
5. If no Multitap is present, preserve ordinary port-2 controller behavior.
6. Hot-plugging is unsupported. Re-detect only when returning to a future title screen.

## POC requirements that prevent a future rewrite

- Arrays are sized for four game players and five reported pad positions.
- Player ownership is data, not hard-coded `if player == 0` logic.
- Team is separate from pad number.
- Pause is arbitrated centrally: any active human may pause later, but only P1 does in the POC.
- Disconnected/inactive sources emit neutral intent.
- Input state is captured once per frame and reused by all systems.

## Four-player activation checklist for the later vertical slice

- [ ] Connect an original or verified compatible Super Multitap to port 2.
- [ ] Confirm detection on cold boot and reset.
- [ ] Show four join indicators and reject a fifth player.
- [ ] Test every D-pad direction and face button independently on all four game slots.
- [ ] Confirm simultaneous held directions and simultaneous hit edges are preserved.
- [ ] Activate player slots 1 and 3 without changing entity IDs.
- [ ] Add teammate position separation and serve rotation.
- [ ] Run the object scanline stress scene with all four players aligned.
- [ ] Run a 15-minute four-pad real-hardware soak test.

## Known risk

Emulators differ in how a Multitap is configured. Automated POC tests should exercise the logical input layer directly; accessory integration requires both a configured accuracy-focused emulator and physical hardware before it can be certified.
