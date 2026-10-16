#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "ai.h"
#include "court.h"
#include "game.h"
#include "match.h"
#include "rules.h"
#include "serve.h"

/* ADR-018 arcade doubles. */

static PlayerIntent intents[MAX_PLAYERS];

static void new_doubles(void)
{
    match_config_doubles();
    game_new_match();
}

static u8 top(u8 slot)
{
    return g_players[slot].y_fp < TO_FP(COURT_CENTERLINE_Y);
}

static void test_activation_and_ownership(void)
{
    u8 i;

    new_doubles();
    for (i = 0; i < MAX_PLAYERS; ++i) {
        assert(g_players[i].active);
        assert(g_players[i].palette == i);          /* OBJ palette 0-3 */
    }
    assert(g_input_owners[0] == INPUT_OWNER_HUMAN);
    assert(g_input_owners[1] == INPUT_OWNER_CPU);
    assert(g_input_owners[2] == INPUT_OWNER_CPU);
    assert(g_input_owners[3] == INPUT_OWNER_CPU);
    assert(match_config_palettes_unique());
    assert(match_team_palette(0) == PAL_BLUE);
    assert(match_team_palette(1) == PAL_RED);
}

static void test_server_rotation(void)
{
    new_doubles();
    /* Left team, even score: bottom-lane slot 0 serves to the top lane. */
    assert(g_serve_state.server_index == 0);
    assert(g_serve_state.receiver_index == 2);
    assert(!top(0) && top(2));
    /* Partners: server's behind the baseline, receiver's at the kitchen. */
    assert(top(1) && !top(3));
    assert(g_players[1].x_fp ==
        TO_FP(COURT_BASELINE_LEFT - SERVE_RECEIVER_GAP));
    assert(g_players[3].x_fp ==
        TO_FP(COURT_KITCHEN_RIGHT_X + SERVE_PARTNER_KITCHEN_GAP));

    /* Odd score: the partner in the top lane serves to the bottom lane. */
    g_game_state.team_score[0] = 1;
    serve_setup(0);
    assert(g_serve_state.server_index == 1);
    assert(g_serve_state.receiver_index == 3);

    /* Right team, even score: top-lane slot 2 serves to slot 0. */
    g_game_state.team_score[1] = 2;
    serve_setup(1);
    assert(g_serve_state.server_index == 2);
    assert(g_serve_state.receiver_index == 0);
    g_game_state.team_score[1] = 3;
    serve_setup(1);
    assert(g_serve_state.server_index == 3);
    assert(g_serve_state.receiver_index == 1);
}

static void test_teammate_separation(void)
{
    fx gap;

    new_doubles();
    player_place(&g_players[2], 200, 130);
    player_place(&g_players[3], 202, 131);
    gap = g_players[3].y_fp - g_players[2].y_fp;
    players_separate_teammates();
    assert(g_players[3].y_fp - g_players[2].y_fp == gap + 2 * FP_ONE);
}

/* Four AIs play complete matches; each incoming ball has one owner. */
static void test_ai_doubles_matches(void)
{
    unsigned long frames = 0;
    u8 matches = 0;
    u8 counted = 0;
    u8 i;
    u8 serial;
    unsigned hits[MAX_PLAYERS] = {0, 0, 0, 0};

    new_doubles();
    serial = g_game_state.shot_serial;
    g_ai_slots[0].late_period = 4;
    while (matches < 3) {
        memset(intents, 0, sizeof(intents));
        for (i = 0; i < MAX_PLAYERS; ++i)
            ai_update(i, &intents[i]);
        if (g_game_state.phase == GAME_PHASE_MATCH_RESULT) {
            intents[0].hit_pressed = 1;
            if (!counted) {
                counted = 1;
                ++matches;
            }
        } else {
            counted = 0;
        }
        game_update(intents);
        if (g_game_state.shot_serial != serial) {
            serial = g_game_state.shot_serial;
            if (g_ball.last_hitter < MAX_PLAYERS)
                ++hits[g_ball.last_hitter];
        }
        if (g_game_state.phase == GAME_PHASE_SERVE_SETUP && frames == 0)
            g_ai_slots[0].late_period = 4;
        /* At most one CPU per team plans to play the ball. Beside slot 0
         * (a human's), the CPU partner may also go for a middle ball it is
         * clearly nearer (a poach, ADR-036), never one deep in slot 0's
         * half. */
        assert(!(g_ai_slots[2].has_target && g_ai_slots[3].has_target));
        if (g_ai_slots[0].has_target && g_ai_slots[1].has_target)
            assert(g_ai_slots[1].target_y - COURT_CENTERLINE_Y <= 30 &&
                g_ai_slots[1].target_y - COURT_CENTERLINE_Y >= -30);
        ++frames;
        assert(frames < 60UL * 60 * 20);
    }
    printf("doubles: 3 AI matches in %.1f s each, hits by slot %u %u %u %u\n",
        frames / 3 / 60.0, hits[0], hits[1], hits[2], hits[3]);
    /* Slot 0 is human-owned (driven by an AI here): opponents spread their
     * shots across both lanes and the CPU partner leaves slot 0's lane
     * alone, so slot 0 plays a fair share of its team's balls. */
    assert(hits[0] * 2 >= hits[1]);
}

int main(void)
{
    test_activation_and_ownership();
    test_server_rotation();
    test_teammate_separation();
    test_ai_doubles_matches();
    match_config_defaults();
    puts("doubles host checks passed");
    return 0;
}
