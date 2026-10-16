#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "court_style.h"
#include "input.h"
#include "opponents.h"

/* ADR-022 court colours: composition, names, and the editor. */

static u16 painted[COURT_GROUND_COLORS];

/* Palette 2 of the generated court palette (run from the repo root). */
static void load_painted(void)
{
    FILE *f = fopen("assets/generated/court.pal", "rb");
    u8 bytes[COURT_GROUND_COLORS * 2];
    u8 i;

    assert(f);
    assert(fread(bytes, 1, sizeof(bytes), f) == sizeof(bytes));
    fclose(f);
    for (i = 0; i < COURT_GROUND_COLORS; ++i)
        painted[i] = (u16)(bytes[i * 2] | (bytes[i * 2 + 1] << 8));
}

static void test_default_is_painted(void)
{
    u16 out[COURT_GROUND_COLORS];
    /* Kitchen SAME (ADR-027): PARK's default kitchen is two-toned. */
    u8 choice[COURT_PARTS] = { 0, COURT_KITCHEN_SAME, 0, 0 };

    /* DEFAULT presets hold the painted colours of court_scene.png, so the
     * default choice (with the kitchen following the surface) changes
     * nothing. */
    load_painted();
    court_style_compose(out, painted, choice, 0);
    assert(memcmp(out, painted, sizeof(out)) == 0);
    assert(strcmp(court_style_name(COURT_PART_SURFACE, 0), "DEFAULT") == 0);
}

static void test_presets_replace_only_their_part(void)
{
    u16 out[COURT_GROUND_COLORS];
    u8 choice[COURT_PARTS] = { 1, 2, 0, 0 };    /* kitchen: BLUE */
    const u8 *entries = g_court_part_entries[COURT_PART_SURFACE];
    u8 i;
    u8 touched[COURT_GROUND_COLORS] = { 0 };

    court_style_compose(out, painted, choice, 0);
    for (i = 0; i < g_court_part_size[COURT_PART_SURFACE]; ++i) {
        touched[entries[i]] = 1;
        assert(out[entries[i]] ==
            g_court_preset_colors[g_court_part_first[COURT_PART_SURFACE] + 1][i]);
        assert(out[entries[i]] != painted[entries[i]]);
    }
    for (i = 0; i < g_court_part_size[COURT_PART_KITCHEN]; ++i)
        touched[g_court_part_entries[COURT_PART_KITCHEN][i]] = 1;
    for (i = 0; i < COURT_GROUND_COLORS; ++i)
        if (!touched[i])
            assert(out[i] == painted[i]);

    /* Entry 0 (transparent) and the net/fence entries are never parts. */
    assert(!touched[0]);

    /* Out of range (a corrupted or newer save) counts as DEFAULT. */
    choice[COURT_PART_SURFACE] = 200;
    choice[COURT_PART_KITCHEN] = COURT_KITCHEN_SAME;
    court_style_compose(out, painted, choice, 0);
    assert(memcmp(out, painted, sizeof(out)) == 0);
    assert(strcmp(court_style_name(COURT_PART_SURFACE, 200), "DEFAULT") == 0);
}

static void test_names_fit(void)
{
    u8 part;
    u8 preset;

    for (part = 0; part < COURT_PARTS; ++part) {
        assert(g_court_part_count[part] >= 2);
        for (preset = 0; preset < g_court_part_count[part]; ++preset)
            assert(strlen(court_style_name(part, preset)) <= 8);
    }
}

/* ADR-024: DEFAULT means the venue's ground; the venue follows AUTO. */
static void test_venues(void)
{
    u16 out[COURT_GROUND_COLORS];
    u16 expect[COURT_GROUND_COLORS];
    u8 choice[COURT_PARTS] = { 0, 0, 0, 0 };
    u8 venue;
    u8 o;

    for (venue = 0; venue < VENUE_COUNT; ++venue) {
        court_style_compose(out, painted, choice, venue);
        court_style_compose(expect, painted, g_venue_ground[venue], 0);
        assert(memcmp(out, expect, sizeof(out)) == 0);
    }
    /* An explicit choice wins over the venue's ground. */
    choice[COURT_PART_SURROUND] = 2;
    court_style_compose(out, painted, choice, VENUE_COUNT - 1);
    assert(out[g_court_part_entries[COURT_PART_SURROUND][0]] ==
        g_court_preset_colors[g_court_part_first[COURT_PART_SURROUND] + 2][0]);

    /* AUTO: the opponent's home, else the first venue; a saved venue wins. */
    assert(court_style_venue(COURT_VENUE_AUTO, OPPONENT_NONE) == 0);
    for (o = 0; o < OPPONENT_COUNT; ++o) {
        assert(court_style_venue(COURT_VENUE_AUTO, o) == g_opponent_venue[o]);
        assert(g_opponent_venue[o] < VENUE_COUNT);
    }
    assert(court_style_venue(VENUE_COUNT, 0) == VENUE_COUNT - 1);
    assert(court_style_venue(VENUE_COUNT + 5, OPPONENT_NONE) == 0);
    assert(strcmp(court_style_venue_name(COURT_VENUE_AUTO), "AUTO") == 0);
    assert(strcmp(court_style_venue_name(1), g_venue_names[0]) == 0);
}

/* ADR-027: SAME paints the kitchen with the surface's preset; any other
 * kitchen preset gives a two-tone court. */
static void test_kitchen(void)
{
    u16 out[COURT_GROUND_COLORS];
    u8 choice[COURT_PARTS] = { 3, COURT_KITCHEN_SAME, 0, 0 };    /* GREEN */
    u8 kitchen = g_court_part_entries[COURT_PART_KITCHEN][0];
    u8 surface = g_court_part_entries[COURT_PART_SURFACE][0];
    u8 v;

    court_style_compose(out, painted, choice, 0);
    assert(out[kitchen] == out[surface]);
    choice[COURT_PART_KITCHEN] = 2;                             /* BLUE */
    court_style_compose(out, painted, choice, 0);
    assert(out[kitchen] != out[surface]);
    assert(strcmp(court_style_name(COURT_PART_KITCHEN, 2),
        court_style_name(COURT_PART_SURFACE, 1)) == 0);
    /* Every venue's default court is two-toned. */
    choice[COURT_PART_SURFACE] = 0;
    choice[COURT_PART_KITCHEN] = 0;
    for (v = 0; v < VENUE_COUNT; ++v) {
        court_style_compose(out, painted, choice, v);
        assert(out[kitchen] != out[surface]);
    }
}

static void test_editor(void)
{
    u8 choice[COURT_PARTS] = { 0, 0, 99, 1 };   /* surround out of range */
    u8 venue = 200;                         /* out of range */
    u8 time = 9;                            /* out of range */
    u8 surfaces = g_court_part_count[COURT_PART_SURFACE];

    court_edit_begin(choice, &venue, &time);
    assert(choice[COURT_PART_SURROUND] == 0);   /* clamped on open */
    assert(venue == COURT_VENUE_AUTO);
    assert(time == COURT_TIME_DAY);
    assert(g_court_edit.row == COURT_ROW_VENUE);
    assert(!court_edit_changed(choice, venue, time));

    /* The venue row: AUTO, then each venue, wrapping; no recolour. */
    court_edit_input(choice, &venue, &time, PAD_LEFT);
    assert(venue == VENUE_COUNT);
    assert(!g_court_edit.recolor && !g_court_edit.retime);
    court_edit_input(choice, &venue, &time, PAD_RIGHT);
    assert(venue == COURT_VENUE_AUTO);
    court_edit_input(choice, &venue, &time, PAD_RIGHT);
    assert(venue == 1 && court_edit_changed(choice, venue, time));

    /* TIME (ADR-045): DAY, DUSK, NIGHT, wrapping; each change retimes. */
    court_edit_input(choice, &venue, &time, PAD_DOWN);
    assert(g_court_edit.row == COURT_ROW_TIME);
    court_edit_input(choice, &venue, &time, PAD_LEFT);
    assert(time == COURT_TIMES - 1 && g_court_edit.retime);
    g_court_edit.retime = 0;
    court_edit_input(choice, &venue, &time, PAD_RIGHT);
    assert(time == COURT_TIME_DAY && g_court_edit.retime);
    g_court_edit.retime = 0;
    court_edit_input(choice, &venue, &time, PAD_RIGHT);
    assert(time == 1);

    /* Down to SURFACE: Left wraps to the last preset and recolours. */
    court_edit_input(choice, &venue, &time, PAD_DOWN);
    assert(g_court_edit.row == COURT_PART_SURFACE + COURT_ROW_PARTS);
    assert(court_edit_input(choice, &venue, &time, PAD_LEFT) ==
        COURT_EDIT_STAY);
    assert(choice[COURT_PART_SURFACE] == surfaces - 1);
    assert(g_court_edit.recolor);
    g_court_edit.recolor = 0;
    court_edit_input(choice, &venue, &time, PAD_RIGHT);
    court_edit_input(choice, &venue, &time, PAD_RIGHT);
    assert(choice[COURT_PART_SURFACE] == 1);

    /* Rows wrap; Left/Right change only the cursor's row. */
    court_edit_input(choice, &venue, &time, PAD_UP);
    court_edit_input(choice, &venue, &time, PAD_UP);
    court_edit_input(choice, &venue, &time, PAD_UP);
    assert(g_court_edit.row == COURT_ROWS - 1);
    court_edit_input(choice, &venue, &time, PAD_RIGHT);
    assert(choice[COURT_PART_LINES] == 2);
    court_edit_input(choice, &venue, &time, PAD_DOWN);
    assert(g_court_edit.row == COURT_ROW_VENUE);

    /* Y puts everything back, the time too (and retimes). */
    g_court_edit.retime = 0;
    assert(court_edit_input(choice, &venue, &time, PAD_Y) ==
        COURT_EDIT_CANCEL);
    assert(choice[COURT_PART_SURFACE] == 0 && choice[COURT_PART_LINES] == 1);
    assert(venue == COURT_VENUE_AUTO && time == COURT_TIME_DAY);
    assert(g_court_edit.retime);
    assert(!court_edit_changed(choice, venue, time));

    /* B keeps. */
    court_edit_begin(choice, &venue, &time);
    court_edit_input(choice, &venue, &time, PAD_RIGHT);
    assert(court_edit_input(choice, &venue, &time, PAD_B) ==
        COURT_EDIT_DONE);
    assert(venue == 1 && court_edit_changed(choice, venue, time));
}

/* TIME (ADR-045): DAY changes nothing; NIGHT darkens the surround far more
 * than the floodlit court, keeps the hue order of a blue-shifted night, and
 * plays the night ambience. */
static u8 channel(u16 color, u8 shift)
{
    return (u8)((color >> shift) & 31);
}

static void test_times(void)
{
    u16 ground[COURT_GROUND_COLORS];
    u16 day[COURT_GROUND_COLORS];
    u16 white = 0x7fff;
    u16 one;
    u8 choice[COURT_PARTS] = { 0, COURT_KITCHEN_SAME, 0, 0 };
    u8 night = COURT_TIMES - 1;
    u8 i;

    load_painted();
    court_style_compose(day, painted, choice, 0);
    memcpy(ground, day, sizeof(ground));
    court_style_time_ground(ground, COURT_TIME_DAY);
    assert(memcmp(ground, day, sizeof(ground)) == 0);
    one = white;
    court_style_time(&one, 1, COURT_TIME_DAY, 0);
    assert(one == white);

    court_style_time_ground(ground, night);
    for (i = 1; i < COURT_GROUND_COLORS; ++i) {
        /* Never brighter, in any channel. */
        assert(channel(ground[i], 0) <= channel(day[i], 0));
        assert(channel(ground[i], 5) <= channel(day[i], 5));
        assert(channel(ground[i], 10) <= channel(day[i], 10));
    }
    /* White under the lights stays bright; white in the dark doesn't, and
     * the dark keeps more blue than red (a night sky, not grey). */
    one = white;
    court_style_time(&one, 1, night, 1);
    assert(channel(one, 0) >= 24 && channel(one, 10) >= 28);
    one = white;
    court_style_time(&one, 1, night, 0);
    assert(channel(one, 0) <= 8 && channel(one, 10) > channel(one, 0));
    /* The lines are lit, the surround is not. */
    assert(g_court_lit_mask & (1 << g_court_part_entries[COURT_PART_LINES][0]));
    assert(!(g_court_lit_mask &
        (1 << g_court_part_entries[COURT_PART_SURROUND][0])));

    assert(strcmp(court_style_time_name(night), "NIGHT") == 0);
    assert(strcmp(court_style_time_name(99), "DAY") == 0);
    assert(court_style_ambience(1, COURT_TIME_DAY) == 1);
    assert(court_style_ambience(1, night) != 0xff);
    assert(court_style_ambience(1, night) < VENUE_COUNT);
}

int main(void)
{
    test_default_is_painted();
    test_presets_replace_only_their_part();
    test_names_fit();
    test_venues();
    test_kitchen();
    test_editor();
    test_times();
    printf("court style host checks passed\n");
    return 0;
}
