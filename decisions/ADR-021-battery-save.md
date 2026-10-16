# ADR-021 — Battery Save and Records

Status: **Accepted 2026-10-13**
Amends ADR-017 ("no SRAM"). Starts the battery-save idea in
[IDEAS.md](../IDEAS.md); court colours and story progress will add fields to
the same save block.

## Cartridge

- Header: cartridge type `$02` (ROM + RAM + battery) and SRAM size `$01`
  (2 KiB). Both are Makefile variables (`CARTRIDGETYPE`, `SRAMSIZE`) that
  PVSnesLib writes into the generated `hdr.asm`.
- LoROM SRAM sits at `$70:0000`. The game uses PVSnesLib's
  `consoleLoadSramWithOffset` / `consoleCopySramWithOffset`.
- Emulators and flash carts keep the save in an `.srm` file. A physical cart
  needs a board with an SRAM chip and a battery.
- **Without SRAM** the game still runs: reads return open bus, which fails
  validation, so every power-on starts from defaults and records last until
  power-off.

## Save block

`SaveData` (`include/save.h`), 24 bytes in version 1. Version 2 (ADR-022)
adds a 4-byte settings block before the checksum.

| Field | Bytes | Notes |
|---|---:|---|
| magic | 4 | `PB94` |
| version | 1 | `SAVE_VERSION` (1). Any other value resets to defaults. |
| sequence | 1 | Wrapping counter; the copy ahead by 1–127 is newer. |
| records | 16 | Eight `u16` counters, below. |
| checksum | 2 | Fletcher-style sums (two running byte sums, mod 256) over every byte before it. |

- **Two copies**, at SRAM offsets 0 and 1024. Each write goes to the older
  copy, so a power cut mid-write loses only that write.
- **Boot**: load both copies and keep the newer valid one. If neither is
  valid (blank cart, corruption, different version), write defaults to both.
- A layout change bumps `SAVE_VERSION`, which resets saves made with the old
  layout. Nothing has shipped, so there is no migration code. *Superseded by
  [ADR-032](ADR-032-save-migration.md): released layouts are migrated.*

## Records

| Record | Counts |
|---|---|
| Singles / doubles W and L | Matches against the CPU (no 2P on the other team). |
| Win streak, best streak | Consecutive wins against the CPU, either mode. A loss resets the streak. |
| Shutouts | Wins against the CPU where the CPU scored 0. |
| Longest rally | Most shots in one point (the serve counts), in any human match including 2P versus. |

Counters saturate at 9999 (four digits on screen).

**When it writes**: once per match, on entering the match result. The rally
length is recorded at the start of each point result in WRAM and written
with the match. The attract demo never records. Rally length is
`shot_serial` at the point's end minus its value at the serve. It is kept
outside `g_game_state`, which golden traces compare byte for byte.

## Title screen

- The menu has three entries: **SINGLES**, **DOUBLES**, **RECORDS**. Up/Down
  wrap. Start or B on RECORDS opens the records page, and the prompt changes
  to `@ BACK`.
- Start, B, or Y closes the page.
- **Erase**: on the records page, hold L + R and press X. Both copies are
  reset at once. There is no confirmation; the three-button combo is the
  guard.
- The page is a 24 × 9 box of dark font cells over the court, filled with the
  assembly HUD fill.

### Frame budget

The attract demo plays behind the title and leaves little frame time.
Drawing the menu and the 2P line together with the prompt (the previous
behaviour) already dropped a frame on each menu move. The title area (menu or
records) is now drawn by its own state machine on idle HUD frames:

1. Clear the area.
2. Draw one part per frame. For the menu, the parts are the items, then the
   2P line. For records, they are the box, then one line each.

It is separate from the staged scene steps, so the prompt blink no longer
interrupts it. The records timeline and a full match both run with zero
overruns (`g_overrun_frames`).

Boot runs about a frame longer because of the SRAM load. That shifts the
attract demo behind the title, so golden traces recorded before this change
differ until the first match starts and are identical from then on. Traces
were re-recorded.

## Also fixed

HUD scene keys for the title used `0x40`–`0x4F`, which overlaps the
phase key of a P1 point on a CPU kitchen fault (`0x44`). That point would have
redrawn the title instead of `KITCHEN!`. Title keys now use bit 8 (keys are
`u16`).

## Tests

- `test/test_save.c` (host):
  - blank SRAM formats both copies
  - round trip, and the newer copy wins
  - a torn newer copy falls back to the older one
  - a version mismatch resets
  - the sequence counter wraps
  - record rules (streaks, shutouts, 2P versus, saturation)
  - the game hooks record once per human match and never in attract
- `test/smoke/records.timeline`: menu, records page, close, erase, and back.
  Run with `make smoke SMOKE=records SMOKE_FRAMES=320`.
