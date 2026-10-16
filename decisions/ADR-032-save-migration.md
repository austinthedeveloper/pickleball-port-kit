# ADR-032 — Save Migration

Status: **Accepted 2026-10-13**
Amends ADR-021: "a layout change bumps `SAVE_VERSION`, which resets saves
made with the old layout."

## Why

Until v0.4.0 nothing had shipped, so a layout change could reset saves.
Players now hold saves from released builds:

| Release | Layout | Size |
|---|---|---:|
| v0.4.0 | 4 | 32 bytes |
| v0.5.0 | 7 | 40 bytes |
| v0.6.0 to v0.12.0 | 8 | 42 bytes (ADR-033) |
| v0.13.0 | 9 | 48 bytes: record initials (ADR-040) |
| next | 10 | 52 bytes: practice return zones (ADR-028); 4, 7, 8, and 9 migrate |

From now on a layout change keeps their records and settings.

## How

- **Frozen layouts:** every released layout older than `SaveData` is kept
  as a struct in `save.h` (`SaveV4`). The build checks each layout's size
  (`sizeof` assertions in `save.c`).
- **Loading** (`save_initialize`):
  - Both copies are read as raw bytes, at the largest known size.
  - A copy is valid when the magic matches, its version is a known layout,
    and the checksum over that layout's bytes (the same Fletcher sum)
    matches.
  - The newer valid copy wins, as before. Byte 5 is the sequence in every
    layout.
  - If the winner is current, it is used as is. If it is an older layout,
    it is migrated into `SaveData`: fields that exist carry over, new
    fields take their defaults. It is then **written to both copies**, so
    the migration happens once.
  - An unknown version (garbage, or a save from a newer build) or a bad
    checksum resets to defaults, as before.
- **v4 → v7 (v0.4.0 → v0.5.0+):**
  - Carried over: all eight records; court colours (surface, surround,
    lines); ladder rung; venue; points; difficulty.
  - New fields at defaults: kitchen colour (DEFAULT, the venue's), ladder
    clears and the practice best (0), practice settings (MIX / RANDOM /
    NORMAL), and SOUND (ALL).

## Rule for the next layout change

1. Copy the current `SaveData` into `save.h` as `SaveV<current version>`,
   with a size assertion.
2. Change `SaveData`, bump `SAVE_VERSION`, and update `SAVE_RAW_BYTES` if
   the new layout is larger.
3. Add the version to `save_layout_size` and a migration step. Older
   layouts may migrate step by step (4 → 7 → 8) or directly; keep every
   released layout loadable.
4. Add a test that loads a saved image of the old layout
   (`test/test_save.c: test_migrate_v4` is the pattern).

## Verified

- `test/test_save.c: test_migrate_v8` and, in MesenCE, the debug ROM booted
  from a hand-built v8 `.srm` (copy 1 blank): both copies were rewritten as
  version 9 with the records and practice settings carried over and RETURN
  TO at ANY, and the practice page showed them.

- `test/test_save.c: test_migrate_v4`:
  - a v4 image keeps every carried field, with defaults for new ones
  - both copies are current afterwards
  - a torn v4 falls back to defaults
  - a current copy that is newer beats an old v4 copy
  - an unknown version resets
- **MesenCE:** booting the release ROM from a hand-built v4 `.srm` gave
  version 7 in RAM with the records and settings carried over, and both
  SRAM copies rewritten as version 7.
