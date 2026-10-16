#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "career.h"
#include "game.h"
#include "input.h"
#include "match.h"
#include "opponents.h"
#include "rules.h"
#include "save.h"
#include "story.h"

/* ADR-026 story cards: the intro card and the ladder clear record. */

static void test_intro_card(void)
{
    u16 f;

    g_attract = 0;
    match_config_defaults();
    story_begin_intro();
    assert(g_story.card == STORY_CARD_NONE);    /* the default CPU: none */

    match_config_opponent(2);
    story_begin_intro();
    assert(g_story.card == STORY_CARD_INTRO);
    /* A held button cannot skip it at once... */
    assert(story_update(PAD_B, 0));
    /* ...but B ends it after the minimum. */
    for (f = 1; f < STORY_INTRO_MIN_FRAMES; ++f)
        assert(story_update(0, 0));
    assert(!story_update(PAD_B, 0));
    assert(g_story.card == STORY_CARD_NONE);

    /* Untouched, it goes by itself. */
    story_begin_intro();
    for (f = 1; f < STORY_INTRO_FRAMES; ++f)
        assert(story_update(0, 0));
    assert(!story_update(0, 0));

    /* Never in the attract demo. */
    g_attract = 1;
    story_begin_intro();
    assert(g_story.card == STORY_CARD_NONE);
    g_attract = 0;
    match_config_defaults();
}

static void test_ladder_clear_record(void)
{
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    g_save.settings.ladder = OPPONENT_COUNT - 2;
    save_advance_ladder();
    assert(g_save.records.ladder_clears == 0);
    save_advance_ladder();                      /* beat the last one */
    assert(g_save.settings.ladder == 0);
    assert(g_save.records.ladder_clears == 1);
    save_write();
    save_initialize();
    assert(g_save.records.ladder_clears == 1);
}

/* Every opponent has all three lines, in the HUD's limits. */
static void test_lines(void)
{
    u8 o;
    u8 k;

    for (o = 0; o < OPPONENT_COUNT; ++o)
        for (k = 0; k < 3; ++k) {
            assert(strlen(g_opponent_lines[o][k]) >= 1);
            assert(strlen(g_opponent_lines[o][k]) <= 28);
            assert(!strchr(g_opponent_lines[o][k], '@'));
        }
}

/* ADR-040: the initials card opens only after a beaten record, outside
 * the attract demo; letters wrap and repeat; it saves on the third B. */
static void test_initials_card(void)
{
    u16 f;

    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    story_initialize();
    g_attract = 0;
    story_begin_initials();
    assert(g_story.card == STORY_CARD_NONE);    /* nothing beaten */

    save_record_rally(7);
    g_attract = 1;
    story_begin_initials();
    assert(g_story.card == STORY_CARD_NONE);
    g_attract = 0;
    story_begin_initials();
    assert(g_story.card == STORY_CARD_INITIALS);
    assert(memcmp(g_story.letters, "AAA", 3) == 0 && g_story.cursor == 0);

    /* Down wraps to Z; B is ignored before the minimum. */
    assert(story_update(PAD_DOWN, PAD_DOWN));
    assert(g_story.letters[0] == 'Z');
    assert(story_update(PAD_B, 0));
    assert(g_story.cursor == 0);
    for (f = 2; f < STORY_INITIALS_MIN_FRAMES; ++f)
        assert(story_update(0, 0));
    /* Up held: one step, then repeats after the delay. */
    assert(story_update(PAD_UP, PAD_UP));       /* Z -> A */
    for (f = 1; f < STORY_REPEAT_DELAY; ++f)
        assert(story_update(0, PAD_UP));
    assert(g_story.letters[0] == 'A');
    assert(story_update(0, PAD_UP));            /* the first repeat */
    assert(g_story.letters[0] == 'B');
    for (f = 0; f < STORY_REPEAT_FRAMES; ++f)
        assert(story_update(0, PAD_UP));
    assert(g_story.letters[0] == 'C');

    /* B moves on, Y goes back, the third B saves. */
    assert(story_update(PAD_B, 0) && g_story.cursor == 1);
    assert(story_update(PAD_Y, 0) && g_story.cursor == 0);
    assert(story_update(PAD_B, 0));
    assert(story_update(PAD_UP, PAD_UP));       /* A -> B */
    assert(story_update(PAD_B, 0) && g_story.cursor == 2);
    assert(!story_update(PAD_B, 0));
    assert(g_story.card == STORY_CARD_NONE);
    assert(memcmp(g_save.initials.longest_rally, "CBA", 3) == 0);
    assert(g_save_new_records == 0);
    story_begin_initials();
    assert(g_story.card == STORY_CARD_NONE);

    /* The next card starts from them; untouched, it keeps them. */
    save_record_rally(8);
    story_begin_initials();
    assert(memcmp(g_story.letters, "CBA", 3) == 0);
    for (f = 1; f < STORY_INITIALS_FRAMES; ++f)
        assert(story_update(0, 0));
    assert(!story_update(0, 0));
    assert(memcmp(g_save.initials.longest_rally, "CBA", 3) == 0);

    /* Start saves at once. */
    save_record_rally(9);
    story_begin_initials();
    for (f = 1; f < STORY_INITIALS_MIN_FRAMES; ++f)
        assert(story_update(0, 0));
    assert(!story_update(PAD_START, 0));
}

/* ADR-040: a record beaten in a match left early asks for nothing. */
static void test_initials_need_a_finished_match(void)
{
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    story_initialize();
    match_config_defaults();
    g_attract = 0;
    game_new_match();
    save_record_rally(5);
    game_new_match();                           /* RESTART */
    story_begin_initials();
    assert(g_story.card == STORY_CARD_NONE);
    assert(g_save.records.longest_rally == 5);
    assert(g_save.initials.longest_rally[0] == 0);
}

/* ADR-047: the unlock card shows what a career player just earned, never
 * in the attract demo, and clears it when it closes. */
static void test_unlock_card(void)
{
    u16 f;

    story_initialize();
    g_attract = 1;
    g_career_new_unlocks = 1;
    story_begin_unlock();
    assert(g_story.card == STORY_CARD_NONE);
    g_attract = 0;
    g_career_new_unlocks = 0;
    story_begin_unlock();
    assert(g_story.card == STORY_CARD_NONE);
    g_career_new_unlocks = 3;
    story_begin_unlock();
    assert(g_story.card == STORY_CARD_UNLOCK);
    /* B can't skip it at once; after the minimum it closes. */
    assert(story_update(PAD_B, PAD_B));
    for (f = 1; f < STORY_UNLOCK_MIN_FRAMES; ++f)
        story_update(0, 0);
    assert(!story_update(PAD_B, PAD_B));
    assert(g_story.card == STORY_CARD_NONE && g_career_new_unlocks == 0);
    /* Untouched, it goes by itself. */
    g_career_new_unlocks = 1;
    story_begin_unlock();
    for (f = 0; f < STORY_UNLOCK_FRAMES; ++f)
        story_update(0, 0);
    assert(g_story.card == STORY_CARD_NONE && g_career_new_unlocks == 0);
}

/* Quips: about one point in three, from the side that lost it, never the
 * same line twice in a row. */
static void test_quips(void)
{
    const char *last = 0;
    const char *q;
    u16 roll;
    u16 said = 0;
    u8 i;
    u8 found;

    story_initialize();
    match_config_defaults();
    for (roll = 0; roll < 300; ++roll) {
        q = story_quip(1, roll);
        if (roll % 3 != 0) {
            assert(q == 0);
            continue;
        }
        ++said;
        assert(q != last);
        found = 0;
        for (i = 0; i < OPPONENT_QUIPS; ++i)
            found |= q == g_side_quips[QUIPS_CPU][i];
        assert(found);                          /* the default CPU's */
        last = q;
    }
    assert(said == 100);
    /* A ladder team speaks its own; the human side the player's. */
    match_config_opponent(3);
    q = story_quip(1, 0);
    found = 0;
    for (i = 0; i < OPPONENT_QUIPS; ++i)
        found |= q == g_opponent_quips[3][i];
    assert(found);
    q = story_quip(0, 3);
    found = 0;
    for (i = 0; i < OPPONENT_QUIPS; ++i)
        found |= q == g_side_quips[QUIPS_PLAYER][i];
    assert(found);
}

int main(void)
{
    test_intro_card();
    test_ladder_clear_record();
    test_lines();
    test_initials_card();
    test_initials_need_a_finished_match();
    test_unlock_card();
    test_quips();
    printf("story host checks passed\n");
    return 0;
}
