# Deterministic Scenario Results

Maps every scenario in `design/snes/05_TEST_PLAN.md` to the compile-time fixture that
automates it. All of them run in `make check` (host build of the same C
sources the ROM uses).

| ID | Fixture | Result |
|---|---|---|
| PHY-01 | `test_ball.c: test_swept_net_height_boundaries`, `test_net_fault_event` (one unit above) | PASS |
| PHY-02 | same (one unit below → `NET`) | PASS |
| PHY-03 | `test_ball.c: test_inclusive_court_boundaries` (lines are in) | PASS |
| PHY-04 | same (one unit outside → out) | PASS |
| PHY-05 | `test_ball.c: test_single_bounce_event`, `test_fast_ball_eventually_settles` | PASS |
| HIT-01 | `test_collision.c: test_active_overlap_contacts_once` | PASS |
| HIT-02 | `test_collision.c: test_windup_cannot_contact` | PASS |
| RUL-01 | `test_rules.c: test_legal_required_bounce_sequence` | PASS |
| RUL-02 | `test_rules.c: test_return_volley_before_bounce_loses_point` | PASS |
| RUL-03 | `test_rules.c: test_second_bounce_penalizes_court_team` | PASS |
| SCR-01 | `test_match_flow.c: test_first_to_five` | PASS |
| RST-01 | `test_match_flow.c: test_rematch_matches_fresh_state` (20 rematches) | PASS |
| PROJ-01..03 | `test_projection.c` and `tools/court_projection.py` | PASS |
| PROJ-04 | `tools/generate_assets.py` line check, plus a failing fixture in `tools/test_asset_validation.py` | PASS |
| PROJ-05 | Emulator visual check: the ball shadow lands on painted lines | PASS (MesenCE smoke) |
| SAV-01 | `test_save.c`: blank SRAM formats, newer copy wins, torn copy falls back, version resets, sequence wraps (ADR-021) | PASS |
| SAV-02 | `test_save.c: test_records`, `test_game_hooks`: record rules, once per human match, never in attract | PASS |
| CRT-01 | `test_court_style.c`: DEFAULT equals the painted palette, presets touch only their part, editor wrap/cancel/keep (ADR-022) | PASS |
| CRT-02 | Asset build: line and ball contrast on every surface (`tools/assetgen/court_colors.py`) | PASS |
| CRT-03 | `test/smoke/court.timeline`: live preview, keep, cancel; persists into the next boot (`KEEP_SAVE=1`) and a match | PASS (MesenCE smoke) |
| OPP-01 | `test_opponents.c`: default style = shipped constants, config/looks/styles, Player Select takes the rung (ADR-023) | PASS |
| OPP-02 | `test_opponents.c: test_ladder`: advance on a win, stay on a loss, wrap, saved, never in attract | PASS |
| OPP-03 | `test_opponents.c: test_difficulty_order`: the first rung is beaten clearly more than the last | PASS |
| VEN-01 | `test_court_style.c: test_venues`, `test_editor`: DEFAULT = venue ground, AUTO = opponent home, VENUE row (ADR-024) | PASS |
| VEN-02 | Asset build: shared ground palette and tiles, per-venue budget, names, ground presets | PASS |
| REP-01 | `test_replay.c`: the close call shows for a long rally just out (each line, a hair, a corner), never for short rallies, other faults, or wide misses; MesenCE with dropped thresholds shows the close-up; zero overruns with it on every out (ADR-041) | PASS |
| VEN-03 | `test/smoke/venue.timeline`, `lake.timeline`: SUNSET and LAKESIDE chosen on the title, a match at SUNSET | PASS (MesenCE smoke) |
| VEN-04 | `test/smoke/venue_preview.timeline`: a rested VENUE previews behind the COURT page, one scrolled past doesn't, Y restores; zero overruns (M4-VENUE-02) | PASS (MesenCE smoke) |
| OPT-01 | `test_options.c`: values, difficulty styles, slow-ball pattern, editor, first to 11 (ADR-025) | PASS |
| OPT-02 | `test_options.c: test_difficulty_and_kid`: bot wins ordered KID >= EASY > MEDIUM > HARD; KID assist alone returns and wins | PASS |
| OPT-03 | `test/smoke/options.timeline`: OPTIONS page, a KID match to 7, zero overruns | PASS (MesenCE smoke) |
| STY-01 | `test_story.c`: intro card shows, can't be skipped instantly, ends by itself; ladder clears recorded; lines fit (ADR-026) | PASS |
| STY-02 | `test/smoke/story.timeline`: DAD's intro card with his bust (M4-STORY-03), B dismisses it and the bust without serving; golden run with cards has zero overruns | PASS (MesenCE smoke) |
| KIT-01 | `test_court_style.c: test_kitchen`: SAME follows the surface, other presets two-tone, every venue default two-toned (ADR-027) | PASS |
| PRA-01 | `test_practice.c: test_feeds_land`: every shot x target lands in on P1's side where asked; unreturned feeds reset the streak (ADR-028) | PASS |
| PRA-02 | `test_practice.c`: streaks build (bot, KID assist), best saved on leaving, Start exits | PASS |
| PRA-03 | `test/smoke/practice.timeline`: page, Player Select, session, exit | PASS (MesenCE smoke) |
| AUD-01 | `test_audio.c`: event to effect, pitch by shot, pan, crowd by rally, NO CROWD / OFF, attract silent (ADR-029) | PASS |
| AUD-02 | MesenCE SPC700 voice probe: voices sound for menus, practice, and the golden match | PASS (MesenCE) |
| PAU-01 | `test_pause_menu.c`: choices, actions, Start toggling, practice pausing (ADR-030) | PASS |
| PAU-02 | `test/smoke/pause.timeline`: pause, MAIN MENU, back to the title | PASS (MesenCE smoke) |
| AMB-01 | `test_audio.c: test_ambience` and the MesenCE voice probe: the venue's loop at boot and after a venue change; stops with NO CROWD / OFF (ADR-031) | PASS |
| SAV-04 | `test_save.c: test_migrate_v4` + MesenCE `.srm` boot: v0.4.0 saves migrate to the current layout (ADR-032) | PASS |
| MOD-01 | `test_modifiers.c`: editor, Player Select copies, fast steps and arc, big reach, WIN BY 2 through deuce, LAVA faults and colours, no CPU in the lava across the ladder (ADR-033) | PASS |
| MOD-02 | `test/smoke/modifiers.timeline`: all four on, the lava preview, a big-ball singles match, LAVA! when P1 walks into the kitchen | PASS (MesenCE smoke) |
| SAV-05 | `test_save.c: test_migrate_v7` + MesenCE `.srm` boot: v0.5.0 saves migrate to layout 8 (ADR-033) | PASS |
| SAV-06 | `test_save.c: test_migrate_v8`, `test_initials`; `test_story.c: test_initials_card`, `test_initials_need_a_finished_match`; the golden run's first match ends on the initials card (ADR-040) | PASS |
| OPN-01 | `test_open_play.c`: start, fences and sliding, stack / take back / move / full, your call and return, a 20-minute soak with every team in exactly one place (ADR-034) | PASS |
| OPN-02 | `test/smoke/open_play.timeline`: the park, stacking at court 2, the call, the match at the park | PASS (MesenCE smoke) |
| SAV-03 | `test/smoke/records.timeline`: records page, erase; persistence across MesenCE runs with `KEEP_SAVE=1` (`.srm`) | PASS (MesenCE smoke) |
| PRF-01 | `make perf` (`test/perf.json`): 19 timelines with no dropped frames, the doubles ladder match included (the doubles demo, fast menu scrolling over it, and the doubles modifiers match within their `M4-UI-03` / `M4-UI-04` budgets), the main loop running, and effects and ambience voices sounding | PASS (MesenCE) |

## Candidate

- Build: `0.3.0-release` on branch `feature/cld-milestone-3`
- Host compiler: Apple clang (`cc -std=c99 -Wall -Wextra -Werror`)
- Recorded 2026-10-12. Re-run with `make check`; any failure fails the build.
