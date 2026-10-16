#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "ai.h"
#include "court.h"
#include "game.h"
#include "match.h"
#include "options.h"
#include "rules.h"
#include "save.h"
#include "select.h"
#include "serve.h"
#include "test_support.h"

/* ADR-023 CPU personalities: config, looks, styles, ladder, difficulty. */

static void test_default_style_is_shipped_cpu(void)
{
    assert(g_ai_default_style.late_period == AI_LATE_SHOT_PERIOD);
    assert(g_ai_default_style.lob_distance == AI_LOB_NET_DISTANCE);
    assert(g_ai_default_style.putaway_z == AI_PUTAWAY_Z);
    assert(g_ai_default_style.putaway_distance == AI_PUTAWAY_NET_DISTANCE);
    assert(COURT_NET_X + g_ai_default_style.recover == AI_RECOVER_X);
    assert(g_ai_default_style.speed == PLAYER_CPU_MAX_SPEED_FP);
}

static void test_config(void)
{
    u16 pal[16];
    u8 o = OPPONENT_COUNT - 1;

    match_config_doubles();
    assert(g_match_config.opponent == OPPONENT_NONE);
    assert(match_slot_style(2) == &g_ai_default_style);

    match_config_opponent(o);
    assert(g_match_config.opponent == o);
    assert(g_match_config.variant[2] == g_opponent_variant[o][0]);
    assert(g_match_config.variant[3] == g_opponent_variant[o][1]);
    assert(g_match_config.paddle_id[3] == g_opponent_paddle[o][1]);
    assert(match_slot_style(0) == &g_ai_default_style);
    /* P1's CPU partner plays the partner style (ADR-035). */
    assert(match_slot_style(1) == &g_ai_partner_style);
    assert(match_slot_style(2) == &g_opponent_styles[o][0]);
    assert(match_slot_style(3) == &g_opponent_styles[o][1]);
    /* Hats (M4-OPP-04): the opponents wear theirs; humans and the default
     * CPU partner keep the cap. */
    assert(match_slot_hat(2) == g_opponent_hat[o][0]);
    assert(match_slot_hat(3) == g_opponent_hat[o][1]);
    assert(match_slot_hat(0) == 0 && match_slot_hat(1) == 0);
    match_compose_palette(3, pal);
    assert(memcmp(pal, g_opponent_palettes[o][1], sizeof(pal)) == 0);
    assert(match_team_hud_colors(1) == g_opponent_hud[o]);

    /* The CPU slots take the style when the match starts. */
    game_new_match();
    assert(g_players[2].max_speed_fp == g_opponent_styles[o][0].speed);
    assert(g_ai_slots[3].late_period == g_opponent_styles[o][1].late_period);
    assert(g_ai_slots[2].reaction_frames == g_opponent_styles[o][0].reaction);
    assert(g_ai_styles[1].late_period == g_ai_default_style.late_period);

    /* No personality on a team with a human, or past the roster. */
    g_match_config.human[2] = 1;
    match_config_opponent(0);
    assert(g_match_config.opponent == OPPONENT_NONE);
    g_match_config.human[2] = 0;
    match_config_opponent(OPPONENT_COUNT);
    assert(g_match_config.opponent == OPPONENT_NONE);
}

static void test_select_uses_ladder(void)
{
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    g_save.settings.ladder = 3;
    select_begin(MATCH_SINGLES, 1);
    select_apply();
    assert(g_match_config.opponent == 3);
    select_begin(MATCH_SINGLES, 2);
    select_apply();
    assert(g_match_config.opponent == OPPONENT_NONE);
}

/* Plays out a match the way test_save.c does: P1 or the CPU wins every
 * point. */
static void play_match(u8 p1_wins)
{
    PlayerIntent intents[MAX_PLAYERS];
    u8 point;
    u16 n;

    memset(intents, 0, sizeof(intents));
    game_new_match();
    for (point = 0; point < GAME_POINTS_TO_WIN; ++point) {
        g_game_state.phase = GAME_PHASE_LIVE;
        g_ball.rally_state = BALL_RALLY_LIVE;
        rules_resolve_point(p1_wins ? 1 : 0, GAME_FAULT_OUT);
        for (n = 0; n < 400 && g_game_state.phase == GAME_PHASE_POINT_RESULT;
                ++n)
            game_update(intents);
    }
    assert(g_game_state.phase == GAME_PHASE_MATCH_RESULT);
}

static void test_ladder(void)
{
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    g_attract = 0;
    match_config_defaults();
    match_config_opponent(g_save.settings.ladder);

    play_match(0);
    assert(g_save.settings.ladder == 0);        /* a loss stays */
    play_match(1);
    assert(g_save.settings.ladder == 1);        /* a win moves up */
    save_initialize();
    assert(g_save.settings.ladder == 1);        /* and is saved */

    /* After the last opponent, the first again. */
    g_save.settings.ladder = OPPONENT_COUNT - 1;
    play_match(1);
    assert(g_save.settings.ladder == 0);

    /* The default CPU (no opponent) and the attract demo never move it. */
    match_config_defaults();
    play_match(1);
    assert(g_save.settings.ladder == 0);
    match_config_opponent(0);
    g_attract = 1;
    play_match(1);
    assert(g_save.settings.ladder == 0);
    g_attract = 0;
}

/* Bot-vs-CPU wins against an opponent (tools/match_stats.c, smaller). */
static int bot_wins(u8 opponent, u8 late, u8 matches)
{
    PlayerIntent intents[MAX_PLAYERS];
    unsigned long frames = 0;
    u8 match = 0;
    u8 counted = 0;
    int wins = 0;

    match_config_defaults();
    match_config_opponent(opponent);
    game_new_match();
    while (match < matches && frames < 60UL * 60 * 60) {
        test_bot_skill(late, match);
        memset(intents, 0, sizeof(intents));
        ai_update(0, &intents[0]);
        if (g_game_state.phase == GAME_PHASE_SERVE_SETUP &&
            g_serve_state.server_index == 0 && (frames & 31) == 0)
            intents[0].hit_pressed = 1;
        if (g_game_state.phase == GAME_PHASE_MATCH_RESULT) {
            intents[0].hit_pressed = 1;
            if (!counted) {
                counted = 1;
                ++match;
                wins += g_game_state.match_winner == 0;
            }
        } else {
            counted = 0;
        }
        test_step(intents);
        /* Measuring one opponent: a win's B rematches them here. */
        if (g_next_opponent)
            game_new_match();
        ++frames;
    }
    return wins;
}

/* The ladder gets harder: the first rung is beaten more than the last. */
static void test_difficulty_order(void)
{
    int first;
    int last;

    first = bot_wins(0, 5, 20);
    last = bot_wins(OPPONENT_COUNT - 1, 5, 20);
    printf("opponents: bot (late 5) beat %s %d/20, %s %d/20\n",
        g_opponent_captain[0], first, g_opponent_captain[OPPONENT_COUNT - 1],
        last);
    assert(first > last + 8);
}

/* B on the result: after a ladder win, the next opponent is asked for
 * (main.c sets it up); after a loss, a rematch. */
static void test_result_buttons(void)
{
    PlayerIntent intents[MAX_PLAYERS];
    u16 f;

    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    g_attract = 0;
    match_config_defaults();
    match_config_opponent(0);
    play_match(1);
    assert(g_save.settings.ladder == 1);
    memset(intents, 0, sizeof(intents));
    for (f = 0; f < GAME_POINT_RESULT_MIN_FRAMES + 2; ++f)
        game_update(intents);
    intents[0].hit_pressed = 1;
    game_update(intents);
    assert(g_next_opponent);
    assert(g_game_state.phase == GAME_PHASE_MATCH_RESULT);
    /* What main.c does with it. */
    match_config_opponent(g_save.settings.ladder);
    game_new_match();
    assert(!g_next_opponent && g_match_config.opponent == 1);

    play_match(0);                      /* a loss: B is a rematch */
    memset(intents, 0, sizeof(intents));
    for (f = 0; f < GAME_POINT_RESULT_MIN_FRAMES + 2; ++f)
        game_update(intents);
    intents[0].hit_pressed = 1;
    game_update(intents);
    assert(!g_next_opponent);
    assert(g_game_state.phase == GAME_PHASE_SERVE_SETUP);
    assert(g_match_config.opponent == 1);
}

/* Open play's partner (ADR-034): slot 1 is a team's captain, in look,
 * variant, paddle, and style; difficulty never changes your partner. */
static void test_partner(void)
{
    u16 pal[16];

    match_config_doubles();
    match_config_opponent(6);
    match_config_partner(7);
    g_match_config.difficulty = DIFFICULTY_HARD;
    assert(g_match_config.partner == 7);
    assert(match_slot_style(1) == &g_opponent_styles[7][0]);
    assert(match_slot_style(0) == &g_ai_default_style);
    assert(match_slot_style(2) == &g_opponent_styles[6][0]);
    assert(g_match_config.variant[1] == g_opponent_variant[7][0]);
    assert(g_match_config.paddle_id[1] == g_opponent_paddle[7][0]);
    assert(match_slot_hat(1) == g_opponent_hat[7][0]);
    match_compose_palette(1, pal);
    assert(memcmp(pal, g_opponent_palettes[7][0], sizeof(pal)) == 0);
    game_new_match();
    assert(memcmp(&g_ai_styles[1], &g_opponent_styles[7][0],
        sizeof(AiStyle)) == 0);
    /* No partner from the stack: the smarter partner style (ADR-035). */
    match_config_partner(OPPONENT_NONE);
    assert(match_slot_style(1) == &g_ai_partner_style);
    match_config_defaults();
    assert(g_match_config.partner == OPPONENT_NONE);
}

int main(void)
{
    test_partner();
    test_default_style_is_shipped_cpu();
    test_config();
    test_select_uses_ladder();
    test_ladder();
    test_result_buttons();
    test_difficulty_order();
    match_config_defaults();
    printf("opponents host checks passed\n");
    return 0;
}
