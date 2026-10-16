#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "game.h"
#include "match.h"
#include "rules.h"
#include "save.h"

/* ADR-021 battery save: validation, copy selection, records, game hooks. */

static SaveData copy_at(u16 offset)
{
    SaveData data;

    memcpy(&data, g_host_sram + offset, sizeof(data));
    return data;
}

static void test_blank_sram_formats(void)
{
    SaveData a;
    SaveData b;

    memset(g_host_sram, 0xff, sizeof(g_host_sram));
    save_initialize();
    assert(save_valid(&g_save));
    assert(g_save.records.wins[MATCH_SINGLES] == 0);
    a = copy_at(0);
    b = copy_at(SAVE_COPY_STRIDE);
    assert(save_valid(&a) && save_valid(&b));
    assert(a.sequence != b.sequence);
}

static void test_round_trip_and_newer_copy(void)
{
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    g_save.records.wins[MATCH_DOUBLES] = 7;
    save_write();
    g_save.records.wins[MATCH_DOUBLES] = 8;
    save_write();
    memset(&g_save, 0, sizeof(g_save));
    save_initialize();
    assert(g_save.records.wins[MATCH_DOUBLES] == 8);

    /* Writes alternate: the next one lands on the older copy. */
    g_save.records.wins[MATCH_DOUBLES] = 9;
    save_write();
    save_initialize();
    assert(g_save.records.wins[MATCH_DOUBLES] == 9);
}

static void test_corrupt_copy_falls_back(void)
{
    SaveData a;
    u16 newer;

    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    g_save.records.shutouts = 3;
    save_write();
    g_save.records.shutouts = 4;
    save_write();
    a = copy_at(0);
    newer = a.records.shutouts == 4 ? 0 : SAVE_COPY_STRIDE;

    /* A power cut mid-write: the newer copy is torn, the older one stays. */
    g_host_sram[newer + 8] ^= 0x5a;
    save_initialize();
    assert(g_save.records.shutouts == 3);

    /* Both torn: back to defaults. */
    g_host_sram[(newer ^ SAVE_COPY_STRIDE) + 8] ^= 0x5a;
    save_initialize();
    assert(g_save.records.shutouts == 0);
}

static void test_version_mismatch_resets(void)
{
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    g_save.records.best_streak = 5;
    g_save.version = SAVE_VERSION + 1;
    save_write();
    save_write();
    save_initialize();
    assert(g_save.version == SAVE_VERSION);
    assert(g_save.records.best_streak == 0);
}

static void test_sequence_wraps(void)
{
    u16 i;

    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    for (i = 0; i < 300; ++i) {
        g_save.records.longest_rally = i;
        save_write();
    }
    save_initialize();
    assert(g_save.records.longest_rally == 299);
}

static void test_records(void)
{
    u16 i;

    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    save_record_match(MATCH_SINGLES, 1, 1, 0);
    save_record_match(MATCH_SINGLES, 1, 1, 3);
    assert(g_save.records.wins[MATCH_SINGLES] == 2);
    assert(g_save.records.shutouts == 1);
    assert(g_save.records.streak == 2 && g_save.records.best_streak == 2);
    save_record_match(MATCH_DOUBLES, 1, 0, 2);
    assert(g_save.records.losses[MATCH_DOUBLES] == 1);
    assert(g_save.records.streak == 0 && g_save.records.best_streak == 2);

    /* 2P versus matches leave the CPU records alone. */
    save_record_match(MATCH_SINGLES, 0, 1, 0);
    assert(g_save.records.wins[MATCH_SINGLES] == 2);
    assert(g_save.records.shutouts == 1);

    save_record_rally(12);
    save_record_rally(9);
    assert(g_save.records.longest_rally == 12);

    /* Written with the match, and loaded back. */
    save_record_match(MATCH_SINGLES, 1, 1, 1);
    memset(&g_save, 0, sizeof(g_save));
    save_initialize();
    assert(g_save.records.longest_rally == 12);
    assert(g_save.records.wins[MATCH_SINGLES] == 3);

    /* Counters saturate at four digits. */
    g_save.records.wins[MATCH_SINGLES] = SAVE_COUNTER_MAX;
    for (i = 0; i < 3; ++i)
        save_record_match(MATCH_SINGLES, 1, 1, 1);
    assert(g_save.records.wins[MATCH_SINGLES] == SAVE_COUNTER_MAX);

    /* Erasing records keeps the settings (ADR-022). */
    g_save.settings.court[0] = 3;
    save_clear_records();
    assert(g_save.records.wins[MATCH_SINGLES] == 0);
    assert(g_save.settings.court[0] == 3);
    save_initialize();
    assert(g_save.records.longest_rally == 0);
    assert(g_save.settings.court[0] == 3);

    save_clear();
    assert(g_save.records.wins[MATCH_SINGLES] == 0);
    assert(g_save.settings.court[0] == 0);
    save_initialize();
    assert(g_save.records.longest_rally == 0);
}

/* Drives the result phases until the next serve or the match result. */
static void finish_point(PlayerIntent intents[MAX_PLAYERS])
{
    u16 n;

    for (n = 0; n < 400 && g_game_state.phase == GAME_PHASE_POINT_RESULT;
            ++n)
        game_update(intents);
}

/* A human match vs the CPU records once; the attract demo never does. */
static void test_game_hooks(void)
{
    PlayerIntent intents[MAX_PLAYERS];
    u8 point;

    memset(intents, 0, sizeof(intents));
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();

    match_config_defaults();
    g_attract = 0;
    game_new_match();
    for (point = 0; point < GAME_POINTS_TO_WIN; ++point) {
        g_game_state.phase = GAME_PHASE_LIVE;
        g_game_state.shot_serial += 6;       /* a serve and five returns */
        g_ball.rally_state = BALL_RALLY_LIVE;
        rules_resolve_point(1, GAME_FAULT_OUT);     /* the CPU loses it */
        finish_point(intents);
    }
    assert(g_game_state.phase == GAME_PHASE_MATCH_RESULT);
    assert(g_save.records.wins[MATCH_SINGLES] == 1);
    assert(g_save.records.shutouts == 1);
    assert(g_save.records.longest_rally == 6);

    /* The match result does not record twice. */
    for (point = 0; point < 50; ++point)
        game_update(intents);
    assert(g_save.records.wins[MATCH_SINGLES] == 1);

    g_attract = 1;
    game_new_match();
    for (point = 0; point < GAME_POINTS_TO_WIN; ++point) {
        g_game_state.phase = GAME_PHASE_LIVE;
        g_game_state.shot_serial += 40;
        g_ball.rally_state = BALL_RALLY_LIVE;
        rules_resolve_point(0, GAME_FAULT_OUT);
        finish_point(intents);
    }
    assert(g_save.records.losses[MATCH_SINGLES] == 0);
    assert(g_save.records.longest_rally == 6);
    g_attract = 0;
}

/* The SRAM copy that does not hold the latest write. */
static u16 s_copy_other(void)
{
    SaveData a;

    memcpy(&a, g_host_sram, sizeof(a));
    return a.records.wins[MATCH_SINGLES] == 40 ? SAVE_COPY_STRIDE : 0;
}

/* A v0.4.0 save block (layout 4) at an SRAM offset. */
static void put_v4(u16 offset, u8 sequence, u8 corrupt)
{
    SaveV4 old;

    memset(&old, 0, sizeof(old));
    memcpy(old.magic, "PB94", 4);
    old.version = SAVE_V4;
    old.sequence = sequence;
    old.wins[MATCH_SINGLES] = 12;
    old.losses[MATCH_DOUBLES] = 3;
    old.streak = 2;
    old.best_streak = 5;
    old.shutouts = 1;
    old.longest_rally = 17;
    old.court[0] = 1;           /* surface BLUE */
    old.court[1] = 2;           /* surround CONCRETE */
    old.court[2] = 1;           /* lines WHITE */
    old.ladder = 3;
    old.venue = 2;
    old.points = 11;
    old.difficulty = 3;
    old.checksum = save_checksum_bytes((const u8 *)&old,
        sizeof(old) - sizeof(u16));
    if (corrupt)
        old.shutouts ^= 0x40;
    memcpy(g_host_sram + offset, &old, sizeof(old));
}

/* ADR-032: saves from released versions carry over. */
static void test_migrate_v4(void)
{
    SaveData a;
    SaveData b;

    memset(g_host_sram, 0xff, sizeof(g_host_sram));
    put_v4(0, 9, 0);
    save_initialize();
    assert(g_save.version == SAVE_VERSION);
    assert(g_save.records.wins[MATCH_SINGLES] == 12);
    assert(g_save.records.losses[MATCH_DOUBLES] == 3);
    assert(g_save.records.best_streak == 5 && g_save.records.streak == 2);
    assert(g_save.records.shutouts == 1 && g_save.records.longest_rally == 17);
    assert(g_save.settings.court[COURT_PART_SURFACE] == 1);
    assert(g_save.settings.court[COURT_PART_KITCHEN] == 0);    /* new */
    assert(g_save.settings.court[COURT_PART_SURROUND] == 2);
    assert(g_save.settings.court[COURT_PART_LINES] == 1);
    assert(g_save.settings.ladder == 3 && g_save.settings.venue == 2);
    assert(g_save.settings.points == 11 && g_save.settings.difficulty == 3);
    /* Fields that did not exist start fresh. */
    assert(g_save.records.ladder_clears == 0);
    assert(g_save.records.practice_best == 0);
    assert(g_save.settings.sound == 0);
    /* Both copies are now the current layout, so it migrates only once. */
    memcpy(&a, g_host_sram, sizeof(a));
    memcpy(&b, g_host_sram + SAVE_COPY_STRIDE, sizeof(b));
    assert(save_valid(&a) && save_valid(&b));
    memset(&g_save, 0, sizeof(g_save));
    save_initialize();
    assert(g_save.records.wins[MATCH_SINGLES] == 12);

    /* A torn v4 copy falls back to defaults, not garbage. */
    memset(g_host_sram, 0xff, sizeof(g_host_sram));
    put_v4(0, 9, 1);
    save_initialize();
    assert(g_save.records.wins[MATCH_SINGLES] == 0);

    /* An old copy next to a newer current one: the newer wins. */
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    g_save.records.wins[MATCH_SINGLES] = 40;
    save_write();                       /* current layout, sequence 3 */
    put_v4(s_copy_other(), 1, 0);
    save_initialize();
    assert(g_save.records.wins[MATCH_SINGLES] == 40);

    /* An unknown version (a future save, or garbage) resets. */
    memset(g_host_sram, 0, sizeof(g_host_sram));
    put_v4(0, 9, 0);
    g_host_sram[4] = 99;
    save_initialize();
    assert(g_save.records.wins[MATCH_SINGLES] == 0);
}

/* A v0.5.0 save (layout 7) migrates with every field; modifiers start off
 * (ADR-033). */
static void test_migrate_v7(void)
{
    SaveV7 old;
    SaveData a;

    memset(g_host_sram, 0xff, sizeof(g_host_sram));
    memset(&old, 0, sizeof(old));
    memcpy(old.magic, "PB94", 4);
    old.version = SAVE_V7;
    old.sequence = 4;
    old.records.wins[MATCH_DOUBLES] = 21;
    old.records.best_streak = 6;
    old.records.ladder_clears = 2;
    old.records.practice_best = 33;
    old.settings.court[COURT_PART_KITCHEN] = 5;
    old.settings.ladder = 7;
    old.settings.venue = 3;
    old.settings.points = 9;
    old.settings.difficulty = 0;
    old.settings.practice[2] = 2;
    old.settings.sound = 1;
    old.checksum = save_checksum_bytes((const u8 *)&old,
        sizeof(old) - sizeof(u16));
    memcpy(g_host_sram + SAVE_COPY_STRIDE, &old, sizeof(old));
    save_initialize();
    assert(g_save.version == SAVE_VERSION);
    assert(g_save.records.wins[MATCH_DOUBLES] == 21);
    assert(g_save.records.best_streak == 6);
    assert(g_save.records.ladder_clears == 2);
    assert(g_save.records.practice_best == 33);
    assert(g_save.settings.court[COURT_PART_KITCHEN] == 5);
    assert(g_save.settings.ladder == 7 && g_save.settings.venue == 3);
    assert(g_save.settings.points == 9 && g_save.settings.difficulty == 0);
    assert(g_save.settings.practice[2] == 2 && g_save.settings.sound == 1);
    assert(g_save.settings.modifiers == 0);                 /* new */
    memcpy(&a, g_host_sram, sizeof(a));
    assert(save_valid(&a) && a.settings.modifiers == 0);

    /* The modifiers round-trip in the current layout. */
    g_save.settings.modifiers = 9;
    save_write();
    memset(&g_save, 0, sizeof(g_save));
    save_initialize();
    assert(g_save.settings.modifiers == 9);
}

/* A v0.6.0-v0.12.0 save (layout 8) carries over; the return zone is ANY
 * and its bests start at 0 (M4-PRACTICE-03), and nobody holds a record yet
 * (ADR-040). */
static void test_migrate_v8(void)
{
    SaveV8 old;
    SaveData a;

    memset(g_host_sram, 0xff, sizeof(g_host_sram));
    memset(&old, 0, sizeof(old));
    memcpy(old.magic, "PB94", 4);
    old.version = SAVE_V8;
    old.sequence = 9;
    old.records.losses[MATCH_SINGLES] = 12;
    old.records.longest_rally = 40;
    old.records.practice_best = 27;
    old.settings.venue = 2;
    old.settings.practice[0] = 1;
    old.settings.practice[1] = 4;
    old.settings.practice[2] = 2;
    old.settings.sound = 2;
    old.settings.modifiers = 5;
    old.settings.reserved = 0x77;
    old.checksum = save_checksum_bytes((const u8 *)&old,
        sizeof(old) - sizeof(u16));
    memcpy(g_host_sram, &old, sizeof(old));
    save_initialize();
    assert(g_save.version == SAVE_VERSION);
    assert(g_save.records.losses[MATCH_SINGLES] == 12);
    assert(g_save.records.longest_rally == 40);
    assert(g_save.records.practice_best == 27);
    assert(g_save.records.practice_zone_best[0] == 0 &&
        g_save.records.practice_zone_best[3] == 0);
    assert(g_save.settings.venue == 2);
    assert(g_save.settings.practice[0] == 1 && g_save.settings.practice[1] == 4 &&
        g_save.settings.practice[2] == 2);
    assert(g_save.settings.practice[3] == 0);              /* new: ANY */
    assert(g_save.settings.sound == 2 && g_save.settings.modifiers == 5);
    memcpy(&a, g_host_sram + SAVE_COPY_STRIDE, sizeof(a));
    assert(save_valid(&a) && a.version == SAVE_VERSION);

    /* The zone and its bests round-trip in the current layout. */
    g_save.settings.practice[3] = 2;
    g_save.records.practice_zone_best[1] = 14;
    save_write();
    memset(&g_save, 0, sizeof(g_save));
    save_initialize();
    assert(g_save.settings.practice[3] == 2);
    assert(g_save.records.practice_zone_best[1] == 14);
    assert(g_save.initials.best_streak[0] == 0);            /* new */
    assert(g_save.initials.longest_rally[0] == 0);
    assert(g_save_new_records == 0);
}

/* A v0.13.0 save (layout 9) carries over with its initials; the return
 * zone is ANY (M4-PRACTICE-03). */
static void test_migrate_v9(void)
{
    SaveV9 old;
    SaveData a;

    memset(g_host_sram, 0xff, sizeof(g_host_sram));
    memset(&old, 0, sizeof(old));
    memcpy(old.magic, "PB94", 4);
    old.version = SAVE_V9;
    old.sequence = 3;
    old.records.best_streak = 6;
    old.records.longest_rally = 21;
    old.records.practice_best = 9;
    old.settings.ladder = 5;
    old.settings.practice[2] = 1;
    old.settings.modifiers = 3;
    memcpy(old.initials.best_streak, "ACE", 3);
    memcpy(old.initials.longest_rally, "BOB", 3);
    old.checksum = save_checksum_bytes((const u8 *)&old,
        sizeof(old) - sizeof(u16));
    memcpy(g_host_sram + SAVE_COPY_STRIDE, &old, sizeof(old));
    save_initialize();
    assert(g_save.version == SAVE_VERSION);
    assert(g_save.records.best_streak == 6 && g_save.records.longest_rally == 21);
    assert(g_save.records.practice_best == 9);
    assert(g_save.records.practice_zone_best[0] == 0);
    assert(g_save.settings.ladder == 5 && g_save.settings.practice[2] == 1);
    assert(g_save.settings.practice[3] == 0);              /* new: ANY */
    assert(g_save.settings.modifiers == 3);
    assert(memcmp(g_save.initials.best_streak, "ACE", 3) == 0);
    assert(memcmp(g_save.initials.longest_rally, "BOB", 3) == 0);
    memcpy(&a, g_host_sram, sizeof(a));
    assert(save_valid(&a) && a.version == SAVE_VERSION);
}

/* A v0.14.0 save (layout 10) carries over whole; the court's time is DAY
 * (ADR-045), and the time round-trips in the current layout. */
static void test_migrate_v10(void)
{
    SaveV10 old;
    SaveData a;

    memset(g_host_sram, 0xff, sizeof(g_host_sram));
    memset(&old, 0, sizeof(old));
    memcpy(old.magic, "PB94", 4);
    old.version = SAVE_V10;
    old.sequence = 7;
    old.records.wins[MATCH_DOUBLES] = 31;
    old.records.practice_zone_best[2] = 11;
    old.settings.court[COURT_PART_LINES] = 1;
    old.settings.court[COURT_PART_KITCHEN] = 9;             /* LIME */
    old.settings.venue = 3;
    old.settings.practice[3] = 2;
    old.settings.sound = 1;
    old.settings.modifiers = 6;
    memcpy(old.initials.longest_rally, "SUE", 3);
    old.checksum = save_checksum_bytes((const u8 *)&old,
        sizeof(old) - sizeof(u16));
    memcpy(g_host_sram, &old, sizeof(old));
    save_initialize();
    assert(g_save.version == SAVE_VERSION);
    assert(g_save.records.wins[MATCH_DOUBLES] == 31);
    assert(g_save.records.practice_zone_best[2] == 11);
    assert(g_save.settings.court[COURT_PART_LINES] == 1);
    /* The kitchen's own presets moved past the new surface colours. */
    assert(strcmp(g_court_preset_names[g_court_part_first[COURT_PART_KITCHEN] +
        g_save.settings.court[COURT_PART_KITCHEN]], "LIME") == 0);
    assert(g_save.settings.venue == 3 && g_save.settings.practice[3] == 2);
    assert(g_save.settings.sound == 1 && g_save.settings.modifiers == 6);
    assert(g_save.settings.time == COURT_TIME_DAY);         /* new */
    assert(memcmp(g_save.initials.longest_rally, "SUE", 3) == 0);
    memcpy(&a, g_host_sram + SAVE_COPY_STRIDE, sizeof(a));
    assert(save_valid(&a) && a.version == SAVE_VERSION);

    g_save.settings.time = 2;
    save_write();
    memset(&g_save, 0, sizeof(g_save));
    save_initialize();
    assert(g_save.settings.time == 2);
}

/* ADR-040: beating a record clears its initials until they are entered;
 * entering sets them for every record beaten, saves, and clears the
 * flags. Erasing the records erases the initials. */
static void test_initials(void)
{
    static const u8 abc[3] = { 'A', 'B', 'C' };
    static const u8 xyz[3] = { 'X', 'Y', 'Z' };

    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    save_record_rally(5);
    assert(g_save_new_records == SAVE_NEW_RALLY);
    save_record_match(MATCH_SINGLES, 1, 1, 3);
    assert(g_save_new_records == (SAVE_NEW_RALLY | SAVE_NEW_STREAK));
    save_set_initials(abc);
    assert(g_save_new_records == 0);
    assert(memcmp(g_save.initials.best_streak, abc, 3) == 0);
    assert(memcmp(g_save.initials.longest_rally, abc, 3) == 0);

    /* A shorter rally and a loss beat nothing. */
    save_record_rally(4);
    save_record_match(MATCH_SINGLES, 1, 0, 3);
    assert(g_save_new_records == 0);
    /* A longer rally: only its initials change hands. */
    save_record_rally(6);
    assert(g_save_new_records == SAVE_NEW_RALLY);
    assert(g_save.initials.longest_rally[0] == 0);
    save_set_initials(xyz);
    assert(memcmp(g_save.initials.longest_rally, xyz, 3) == 0);
    assert(memcmp(g_save.initials.best_streak, abc, 3) == 0);

    /* They persist. */
    memset(&g_save, 0, sizeof(g_save));
    save_initialize();
    assert(memcmp(g_save.initials.longest_rally, xyz, 3) == 0);
    assert(memcmp(g_save.initials.best_streak, abc, 3) == 0);

    /* A run that holds the best streak extends it under the same initials,
     * without asking again; a loss ends the run, and the next record asks
     * once more. */
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    save_record_match(MATCH_SINGLES, 1, 1, 3);
    assert(g_save_new_records == SAVE_NEW_STREAK);
    save_set_initials(abc);
    save_record_match(MATCH_SINGLES, 1, 1, 3);
    save_record_match(MATCH_SINGLES, 1, 1, 3);
    assert(g_save_new_records == 0 && g_save.records.best_streak == 3);
    assert(memcmp(g_save.initials.best_streak, abc, 3) == 0);
    save_record_match(MATCH_SINGLES, 1, 0, 3);              /* the run ends */
    save_record_match(MATCH_SINGLES, 1, 1, 3);
    save_record_match(MATCH_SINGLES, 1, 1, 3);
    save_record_match(MATCH_SINGLES, 1, 1, 3);
    assert(g_save_new_records == 0);                        /* a tie: 3 */
    save_record_match(MATCH_SINGLES, 1, 1, 3);              /* 4: a record */
    assert(g_save_new_records == SAVE_NEW_STREAK);
    assert(g_save.initials.best_streak[0] == 0);
    save_set_initials(xyz);
    save_record_match(MATCH_SINGLES, 1, 1, 3);
    assert(g_save_new_records == 0);
    assert(memcmp(g_save.initials.best_streak, xyz, 3) == 0);

    save_record_rally(9);
    save_clear_records();
    assert(g_save_new_records == 0);
    assert(g_save.initials.best_streak[0] == 0);
    assert(g_save.initials.longest_rally[0] == 0);
}

int main(void)
{
    test_blank_sram_formats();
    test_round_trip_and_newer_copy();
    test_corrupt_copy_falls_back();
    test_version_mismatch_resets();
    test_sequence_wraps();
    test_records();
    test_migrate_v4();
    test_migrate_v7();
    test_migrate_v8();
    test_migrate_v9();
    test_migrate_v10();
    test_initials();
    test_game_hooks();
    printf("save host checks passed\n");
    return 0;
}
