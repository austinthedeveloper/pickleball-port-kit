#include <string.h>
#include "opponents.h"
#include "options.h"
#include "practice.h"
#include "save.h"

SaveData g_save;
u8 g_save_new_records;
/* The best streak was claimed during the current, unbroken run (ADR-040):
 * the next wins extend it under the same initials, without asking again.
 * WRAM only: after a power cycle the next record asks once more. */
static u8 s_streak_held;
/* Copy that holds g_save; the next write goes to the other one. */
static u8 s_current;

static const u8 s_magic[4] = { 'P', 'B', '9', '4' };

/* Sizes the build checks: a layout change must not slip through. */
typedef char save_v4_is_32_bytes[sizeof(SaveV4) == 32 ? 1 : -1];
typedef char save_v7_is_40_bytes[sizeof(SaveV7) == 40 ? 1 : -1];
typedef char save_v8_is_42_bytes[sizeof(SaveV8) == 42 ? 1 : -1];
typedef char save_v9_is_48_bytes[sizeof(SaveV9) == 48 ? 1 : -1];
typedef char save_v10_is_52_bytes[sizeof(SaveV10) == 52 ? 1 : -1];
typedef char save_v11_is_54_bytes[sizeof(SaveV11) == 54 ? 1 : -1];
typedef char career_player_is_52_bytes[sizeof(CareerPlayer) == 52 ? 1 : -1];
typedef char save_v12_is_212_bytes[sizeof(SaveData) == 212 ? 1 : -1];

/* The largest known layout: each copy is read whole, whatever it holds. */
#define SAVE_RAW_BYTES 212

#ifdef HOST_TEST
u8 g_host_sram[SAVE_SRAM_BYTES];

static void sram_read(u8 *dest, u16 offset)
{
    memcpy(dest, g_host_sram + offset, SAVE_RAW_BYTES);
}

static void sram_write(const SaveData *source, u16 offset)
{
    memcpy(g_host_sram + offset, source, sizeof(SaveData));
}
#else
static void sram_read(u8 *dest, u16 offset)
{
    consoleLoadSramWithOffset(dest, SAVE_RAW_BYTES, offset);
}

/* src/asm/sram_copy.asm: MVN into SRAM, several times faster than
 * consoleCopySramWithOffset (ADR-047: the save is 212 bytes). */
u16 sram_copy_src;
u16 sram_copy_dst;
u16 sram_copy_len;
extern void sram_copy(void);

static void sram_write(const SaveData *source, u16 offset)
{
    sram_copy_src = (u16)source;
    sram_copy_dst = offset;
    sram_copy_len = sizeof(SaveData);
    sram_copy();
}
#endif

/* Fletcher-style: two running byte sums, so swapped bytes also change it.
 * The same for every layout. */
#ifdef HOST_TEST
u16 save_checksum_bytes(const u8 *byte, u16 count)
{
    u8 a = 0;
    u8 b = 0;

    while (count--) {
        a += *byte++;
        b += a;
    }
    return ((u16)b << 8) | a;
}
#else
/* src/asm/save_sum.asm: the same sums, several times faster. A save write
 * (match end, leaving a page) sums the whole 212-byte block. */
u16 save_sum_src;
u16 save_sum_len;
u16 save_sum_result;
u8 save_sum_b;
extern void save_sum(void);

u16 save_checksum_bytes(const u8 *byte, u16 count)
{
    save_sum_src = (u16)byte;
    save_sum_len = count;
    save_sum();
    return save_sum_result;
}
#endif

u16 save_checksum(const SaveData *data)
{
    /* The checksum is the last field. */
    return save_checksum_bytes((const u8 *)data,
        sizeof(SaveData) - sizeof(u16));
}

u8 save_valid(const SaveData *data)
{
    return memcmp(data->magic, s_magic, 4) == 0 &&
        data->version == SAVE_VERSION &&
        data->checksum == save_checksum(data);
}

static void save_defaults(void)
{
    memset(&g_save, 0, sizeof(g_save));
    memcpy(g_save.magic, s_magic, 4);
    g_save.version = SAVE_VERSION;
    g_save.settings.points = OPTIONS_POINTS_DEFAULT;
    g_save.settings.difficulty = DIFFICULTY_MEDIUM;
    /* Practice: MIX to RANDOM targets at a NORMAL rate, returns anywhere
     * in (ADR-028). */
    g_save.settings.practice[PRACTICE_ROW_SHOT] = PRACTICE_SHOT_MIX;
    g_save.settings.practice[PRACTICE_ROW_TARGET] = PRACTICE_TARGET_RANDOM;
    g_save.settings.practice[PRACTICE_ROW_RATE] = PRACTICE_RATE_NORMAL;
    g_save.settings.practice[PRACTICE_ROW_ZONE] = PRACTICE_ZONE_ANY;
    g_save.career_active = CAREER_NONE;
}

void save_write(void)
{
    s_current ^= 1;
    ++g_save.sequence;
    g_save.checksum = save_checksum(&g_save);
    sram_write(&g_save, s_current ? SAVE_COPY_STRIDE : 0);
}

void save_clear(void)
{
    save_defaults();
    save_write();
    save_write();
}

static void save_bump(u16 *counter)
{
    if (*counter < SAVE_COUNTER_MAX)
        ++*counter;
}

void save_clear_records(void)
{
    memset(&g_save.records, 0, sizeof(g_save.records));
    memset(&g_save.initials, 0, sizeof(g_save.initials));
    g_save_new_records = 0;
    s_streak_held = 0;
    save_write();
}

void save_set_initials(const u8 *letters)
{
    if (g_save_new_records & SAVE_NEW_STREAK)
        memcpy(g_save.initials.best_streak, letters, SAVE_INITIALS);
    if (g_save_new_records & SAVE_NEW_RALLY)
        memcpy(g_save.initials.longest_rally, letters, SAVE_INITIALS);
    g_save_new_records = 0;
    save_write();
}

/* Block size of a known layout, or 0 for an unknown version. */
static u16 save_layout_size(u8 version)
{
    if (version == SAVE_VERSION)
        return sizeof(SaveData);
    if (version == SAVE_V11)
        return sizeof(SaveV11);
    if (version == SAVE_V10)
        return sizeof(SaveV10);
    if (version == SAVE_V9)
        return sizeof(SaveV9);
    if (version == SAVE_V8)
        return sizeof(SaveV8);
    if (version == SAVE_V7)
        return sizeof(SaveV7);
    if (version == SAVE_V4)
        return sizeof(SaveV4);
    return 0;
}

/* A copy in any known layout with a correct checksum. */
static u8 save_raw_valid(const u8 *raw)
{
    u16 size = save_layout_size(raw[4]);

    if (memcmp(raw, s_magic, 4) != 0 || size == 0)
        return 0;
    return (u16)(raw[size - 2] | (raw[size - 1] << 8)) ==
        save_checksum_bytes(raw, size - 2);
}

/* v0.4.0 to now: everything carries over; ladder clears, the practice best
 * and settings, the kitchen colour (DEFAULT), and SOUND (ALL) start fresh. */
static void save_migrate_v4(const u8 *raw)
{
    static SaveV4 old;

    memcpy(&old, raw, sizeof(old));
    save_defaults();
    g_save.sequence = old.sequence;
    g_save.records.wins[0] = old.wins[0];
    g_save.records.wins[1] = old.wins[1];
    g_save.records.losses[0] = old.losses[0];
    g_save.records.losses[1] = old.losses[1];
    g_save.records.streak = old.streak;
    g_save.records.best_streak = old.best_streak;
    g_save.records.shutouts = old.shutouts;
    g_save.records.longest_rally = old.longest_rally;
    g_save.settings.court[COURT_PART_SURFACE] = old.court[0];
    g_save.settings.court[COURT_PART_SURROUND] = old.court[1];
    g_save.settings.court[COURT_PART_LINES] = old.court[2];
    g_save.settings.ladder = old.ladder;
    g_save.settings.venue = old.venue;
    g_save.settings.points = old.points;
    g_save.settings.difficulty = old.difficulty;
}

/* The records of v0.5.0 to v0.9.0; the return zone bests start at 0. */
static void save_copy_records_v8(const SaveRecordsV8 *old)
{
    g_save.records.wins[0] = old->wins[0];
    g_save.records.wins[1] = old->wins[1];
    g_save.records.losses[0] = old->losses[0];
    g_save.records.losses[1] = old->losses[1];
    g_save.records.streak = old->streak;
    g_save.records.best_streak = old->best_streak;
    g_save.records.shutouts = old->shutouts;
    g_save.records.longest_rally = old->longest_rally;
    g_save.records.ladder_clears = old->ladder_clears;
    g_save.records.practice_best = old->practice_best;
}

/* The settings of v0.6.0 to v0.13.0; the return zone is ANY. */
static void save_copy_settings_v8(const SaveSettingsV8 *old)
{
    memcpy(g_save.settings.court, old->court, COURT_PARTS);
    g_save.settings.ladder = old->ladder;
    g_save.settings.venue = old->venue;
    g_save.settings.points = old->points;
    g_save.settings.difficulty = old->difficulty;
    memcpy(g_save.settings.practice, old->practice, 3);
    g_save.settings.sound = old->sound;
    g_save.settings.modifiers = old->modifiers;
}

/* v0.5.0 to now: everything carries over; the modifiers start off. */
static void save_migrate_v7(const u8 *raw)
{
    static SaveV7 old;

    memcpy(&old, raw, sizeof(old));
    save_defaults();
    g_save.sequence = old.sequence;
    save_copy_records_v8(&old.records);
    memcpy(g_save.settings.court, old.settings.court, COURT_PARTS);
    g_save.settings.ladder = old.settings.ladder;
    g_save.settings.venue = old.settings.venue;
    g_save.settings.points = old.settings.points;
    g_save.settings.difficulty = old.settings.difficulty;
    memcpy(g_save.settings.practice, old.settings.practice, 3);
    g_save.settings.sound = old.settings.sound;
}

/* v0.6.0 to v0.12.0: everything carries over; the return zone is ANY,
 * and nobody holds a record yet. */
static void save_migrate_v8(const u8 *raw)
{
    static SaveV8 old;

    memcpy(&old, raw, sizeof(old));
    save_defaults();
    g_save.sequence = old.sequence;
    save_copy_records_v8(&old.records);
    save_copy_settings_v8(&old.settings);
}

/* v0.13.0: everything carries over, the initials too; the return zone is
 * ANY. */
static void save_migrate_v9(const u8 *raw)
{
    static SaveV9 old;

    memcpy(&old, raw, sizeof(old));
    save_defaults();
    g_save.sequence = old.sequence;
    save_copy_records_v8(&old.records);
    save_copy_settings_v8(&old.settings);
    g_save.initials = old.initials;
}

/* v0.14.0: everything carries over; the court's time is DAY. */
static void save_migrate_v10(const u8 *raw)
{
    static SaveV10 old;

    memcpy(&old, raw, sizeof(old));
    save_defaults();
    g_save.sequence = old.sequence;
    g_save.records = old.records;
    memcpy(&g_save.settings, &old.settings, sizeof(old.settings));
    g_save.initials = old.initials;
}

/* v0.15.0: everything carries over; no career players yet (ADR-047). */
static void save_migrate_v11(const u8 *raw)
{
    static SaveV11 old;

    memcpy(&old, raw, sizeof(old));
    save_defaults();
    g_save.sequence = old.sequence;
    g_save.records = old.records;
    g_save.settings = old.settings;
    g_save.initials = old.initials;
}

/* Layouts before 11 knew 7 surface colours, so the kitchen's own presets
 * (LIME, TEAL) came at 9 and 10; the surface colours added with layout 11
 * (mirrored in the kitchen, ADR-027) moved them up. */
#define SAVE_V10_KITCHEN_EXTRAS 9
static void save_remap_kitchen_v10(void)
{
    u8 *kitchen = &g_save.settings.court[COURT_PART_KITCHEN];

    if (*kitchen >= SAVE_V10_KITCHEN_EXTRAS)
        *kitchen = (u8)(*kitchen - SAVE_V10_KITCHEN_EXTRAS +
            COURT_KITCHEN_SAME + g_court_part_count[COURT_PART_SURFACE]);
}

void save_initialize(void)
{
    static u8 raw[2][SAVE_RAW_BYTES];
    u8 valid0;
    u8 valid1;
    u8 ahead;
    u8 pick;

    g_save_new_records = 0;
    s_streak_held = 0;
    sram_read(raw[0], 0);
    sram_read(raw[1], SAVE_COPY_STRIDE);
    valid0 = save_raw_valid(raw[0]);
    valid1 = save_raw_valid(raw[1]);
    if (!valid0 && !valid1) {
        save_clear();
        return;
    }
    /* The newer valid copy (byte 5 is the sequence in every layout). */
    ahead = (u8)(raw[1][5] - raw[0][5]);
    pick = (valid1 && (!valid0 || (ahead != 0 && ahead < 0x80))) ? 1 : 0;
    s_current = pick;
    if (raw[pick][4] == SAVE_VERSION) {
        memcpy(&g_save, raw[pick], sizeof(g_save));
        return;
    }
    /* An older layout (ADR-032): migrate, then store it as current in both
     * copies so the old one is never read again. */
    if (raw[pick][4] == SAVE_V11)
        save_migrate_v11(raw[pick]);
    else if (raw[pick][4] == SAVE_V10)
        save_migrate_v10(raw[pick]);
    else if (raw[pick][4] == SAVE_V9)
        save_migrate_v9(raw[pick]);
    else if (raw[pick][4] == SAVE_V8)
        save_migrate_v8(raw[pick]);
    else if (raw[pick][4] == SAVE_V7)
        save_migrate_v7(raw[pick]);
    else
        save_migrate_v4(raw[pick]);
    if (raw[pick][4] != SAVE_V11)
        save_remap_kitchen_v10();
    save_write();
    save_write();
}

void save_advance_ladder(void)
{
    u8 next = g_save.settings.ladder + 1;

    if (next >= OPPONENT_COUNT) {
        next = 0;
        save_bump(&g_save.records.ladder_clears);
    }
    g_save.settings.ladder = next;
}

void save_record_rally(u8 shots)
{
    if (shots > g_save.records.longest_rally) {
        g_save.records.longest_rally = shots;
        memset(g_save.initials.longest_rally, 0, SAVE_INITIALS);
        g_save_new_records |= SAVE_NEW_RALLY;
    }
}

void save_record_match(u8 mode, u8 vs_cpu, u8 won, u8 points_against)
{
    SaveRecords *records = &g_save.records;

    if (vs_cpu) {
        if (won) {
            save_bump(&records->wins[mode]);
            save_bump(&records->streak);
            if (records->streak > records->best_streak) {
                records->best_streak = records->streak;
                /* Extending one's own record keeps its initials. */
                if (s_streak_held == 0 ||
                        g_save.initials.best_streak[0] == 0) {
                    memset(g_save.initials.best_streak, 0, SAVE_INITIALS);
                    g_save_new_records |= SAVE_NEW_STREAK;
                    s_streak_held = 1;
                }
            }
            if (points_against == 0)
                save_bump(&records->shutouts);
        } else {
            save_bump(&records->losses[mode]);
            records->streak = 0;
            s_streak_held = 0;
        }
    }
    save_write();
}
