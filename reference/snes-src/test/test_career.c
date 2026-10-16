#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "career.h"
#include "match.h"
#include "opponents.h"
#include "paddle_stats.h"
#include "game.h"
#include "test_support.h"

/* ADR-047: career players, their stats, and unlocks. */

static void fresh(void)
{
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
}

static u8 unlock_bit(const char *name)
{
    u8 i;

    for (i = 0; i < CAREER_UNLOCKS; ++i)
        if (strcmp(g_career_unlock_names[i], name) == 0)
            return i;
    assert(0);
    return 0;
}

static void test_slots(void)
{
    fresh();
    assert(g_save.career_active == CAREER_NONE && career_active() == 0);
    assert(career_create(1, "ACE"));
    assert(g_save.career_active == 1 && career_active() == &g_save.career[1]);
    assert(memcmp(g_save.career[1].name, "ACE     ", CAREER_NAME) == 0);
    assert(!career_create(1, "BOB"));                       /* taken */
    assert(career_create(0, "BOBBYJOEX"));                  /* cut to 8 */
    assert(memcmp(g_save.career[0].name, "BOBBYJOE", CAREER_NAME) == 0);
    career_select(2);                                       /* empty */
    assert(career_active() == 0);
    career_select(1);
    career_delete(1);
    assert(career_active() == 0 && g_save.career[1].used == 0);
    assert(!career_create(3, "X"));                         /* no slot 3 */

    /* Players survive a save round trip. */
    career_select(0);
    save_write();
    memset(&g_save, 0, sizeof(g_save));
    save_initialize();
    assert(career_active() == &g_save.career[0]);
}

static void test_points_and_matches(void)
{
    CareerPlayer *p;

    fresh();
    /* No player: nothing records. */
    career_record_point(1, 1, 1);
    career_record_match(MATCH_SINGLES, 1, 0, 0, 0);
    assert(g_career_new_unlocks == 0);

    career_create(0, "ACE");
    p = career_active();
    career_record_point(1, 1, 1);           /* an ace */
    career_record_point(1, 1, 0);           /* their serve went out */
    career_record_point(7, 0, 1);
    assert(p->points_won == 2 && p->points_lost == 1);
    assert(p->aces == 1 && p->longest_rally == 7);

    career_record_match(MATCH_DOUBLES, 1, 0, 3, 0);     /* PIRATES, 5-0 */
    assert(p->wins[MATCH_DOUBLES] == 1 && p->shutouts == 1);
    assert(p->streak == 1 && p->best_streak == 1 && p->beaten[3] == 1);
    career_record_match(MATCH_SINGLES, 0, 5, OPPONENT_NONE, 1);
    assert(p->losses[MATCH_SINGLES] == 1 && p->streak == 0);
    assert(p->best_streak == 1 && p->open_play == 1);
    /* Beating the last ladder team clears the ladder; at the park, not. */
    career_record_match(MATCH_SINGLES, 1, 2, OPPONENT_COUNT - 1, 1);
    assert(p->ladder_clears == 0);
    career_record_match(MATCH_SINGLES, 1, 2, OPPONENT_COUNT - 1, 0);
    assert(p->ladder_clears == 1);
}

static void test_unlocks(void)
{
    CareerPlayer *p;
    u16 visor = 1 << unlock_bit("VISOR");
    u16 tricorn = 1 << unlock_bit("TRICORN");
    u16 pink = 1 << unlock_bit("PINK HAIR");
    u16 gold = 1 << unlock_bit("GOLD HAIR");
    u8 i;

    fresh();
    career_create(2, "MAX");
    p = career_active();
    /* Free from the start: the cap, bare hair, the first hair colours. */
    assert(career_hat_unlocked(p, 0) && career_hat_unlocked(p, CAREER_HATS - 1));
    assert(career_hair_unlocked(p, 0));
    for (i = 0; i < CAREER_HATS; ++i)
        assert(career_hat_unlocked(p, i) ==
            (g_career_hat_unlock[i] == CAREER_FREE));

    /* A first win (the default CPU, 5-3): the visor, nothing else. */
    career_record_match(MATCH_SINGLES, 1, 3, OPPONENT_NONE, 0);
    assert(g_career_new_unlocks == visor && (p->unlocked & visor));
    assert(career_hat_unlocked(p, 1));
    /* Earned once: the next win earns nothing new. */
    career_record_match(MATCH_SINGLES, 1, 3, OPPONENT_NONE, 0);
    assert(g_career_new_unlocks == 0);
    /* A shutout of the PIRATES: their hat and the pink hair together. */
    career_record_match(MATCH_SINGLES, 1, 0, 3, 0);
    assert(g_career_new_unlocks == (tricorn | pink));
    /* A ladder clear: the gold hair; a loss earns nothing. */
    career_record_match(MATCH_SINGLES, 0, 5, 1, 0);
    assert(g_career_new_unlocks == 0);
    career_record_match(MATCH_SINGLES, 1, 4, OPPONENT_COUNT - 1, 0);
    assert(g_career_new_unlocks & gold);
    assert(career_hair_unlocked(p, CAREER_HAIRS - 1));      /* GOLD */
    assert(!career_hair_unlocked(p, CAREER_HAIRS));
}

/* A v0.15.0 save (layout 11) carries over with no career players. */
static void test_migrate_v11(void)
{
    SaveV11 old;

    memset(g_host_sram, 0xff, sizeof(g_host_sram));
    memset(&old, 0, sizeof(old));
    memcpy(old.magic, "PB94", 4);
    old.version = SAVE_V11;
    old.sequence = 2;
    old.records.wins[MATCH_SINGLES] = 17;
    old.settings.time = 2;
    old.settings.court[COURT_PART_KITCHEN] = 13;            /* LIME, as is */
    memcpy(old.initials.best_streak, "JOE", 3);
    old.checksum = save_checksum_bytes((const u8 *)&old,
        sizeof(old) - sizeof(u16));
    memcpy(g_host_sram, &old, sizeof(old));
    save_initialize();
    assert(g_save.version == SAVE_VERSION);
    assert(g_save.records.wins[MATCH_SINGLES] == 17);
    assert(g_save.settings.time == 2);
    assert(g_save.settings.court[COURT_PART_KITCHEN] == 13);
    assert(memcmp(g_save.initials.best_streak, "JOE", 3) == 0);
    assert(g_save.career_active == CAREER_NONE);
    assert(g_save.career[0].used == 0 && g_save.career[2].used == 0);
}

/* Stage 4: hats shift paddle stats. Every pairing keeps the budget; a
 * stat a paddle maxes leaves that hat with nothing to do on it; the
 * career player's match uses the pairing, everyone else the paddle. */
static void test_gear(void)
{
    u8 profile;
    u8 hat;
    u8 paddle;
    const u8 *stats;

    for (profile = 0; profile < PADDLE_PROFILES; ++profile) {
        stats = g_paddle_stats[profile];
        assert(stats[0] + stats[1] + stats[2] == 9);
        assert(stats[0] <= PADDLE_STAT_MAX && stats[1] <= PADDLE_STAT_MAX &&
            stats[2] <= PADDLE_STAT_MAX);
    }
    /* The cap and bare hair are the plain paddles. */
    for (paddle = 0; paddle < PADDLE_COUNT; ++paddle) {
        assert(memcmp(g_paddle_stats[PADDLE_PROFILE(paddle, 0)],
            g_paddle_stats[paddle], 3) == 0);
        assert(memcmp(g_paddle_stats[PADDLE_PROFILE(paddle,
            CAREER_HATS - 1)], g_paddle_stats[paddle], 3) == 0);
    }
    /* VISOR on BLUE: control up, power down; on WOOD (control 5): none. */
    hat = 1;
    stats = g_paddle_stats[PADDLE_PROFILE(PADDLE_BLUE, hat)];
    assert(stats[0] == 2 && stats[1] == 4 && stats[2] == 3);
    assert(memcmp(g_paddle_stats[PADDLE_PROFILE(PADDLE_WOOD, hat)],
        g_paddle_stats[PADDLE_WOOD], 3) == 0);

    /* In a match: the career player's pairing on slot 0 only. */
    fresh();
    career_create(0, "ACE");
    career_active()->hat = hat;
    match_config_defaults();
    g_match_config.career_p1 = 1;
    g_match_config.paddle_id[0] = PADDLE_BLUE;
    game_new_match();
    assert(g_players[0].paddle == PADDLE_PROFILE(PADDLE_BLUE, hat));
    assert(g_players[2].paddle == PADDLE_STANDARD);
    /* Without a career player: the plain paddle. */
    g_match_config.career_p1 = 0;
    game_new_match();
    assert(g_players[0].paddle == PADDLE_BLUE);
}

int main(void)
{
    test_slots();
    test_points_and_matches();
    test_unlocks();
    test_migrate_v11();
    test_gear();
    puts("career host checks passed");
    return 0;
}
