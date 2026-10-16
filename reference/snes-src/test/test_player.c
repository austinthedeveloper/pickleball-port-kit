#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "court.h"
#include "game.h"
#include "paddle_stats.h"
#include "player.h"

static PlayerIntent intents[MAX_PLAYERS];

static void reset_test(void)
{
    memset(intents, 0, sizeof(intents));
    players_initialize();
}

static void test_initialization(void)
{
    u8 i;
    reset_test();
    assert(g_players[0].active == 1);
    assert(g_players[0].contact_consumed == 1);
    assert(g_players[2].active == 0);
    assert(g_players[2].cpu_controlled == 1);
    for (i = 1; i < MAX_PLAYERS; ++i)
        assert(g_players[i].active == 0);
}

static void test_zero_input_and_pause(void)
{
    s32 x;
    reset_test();
    x = g_players[0].x_fp;
    players_update(intents, 0);
    assert(g_players[0].x_fp == x);
    intents[0].move_x = 1;
    players_update(intents, 1);
    assert(g_players[0].x_fp == x);
}

static void test_diagonal_normalization(void)
{
    reset_test();
    intents[0].move_x = 1;
    intents[0].move_y = 1;
    players_update(intents, 0);
    assert(g_players[0].vx_fp == PLAYER_DIAGONAL_ACCEL_FP);
    assert(g_players[0].vy_fp == PLAYER_DIAGONAL_ACCEL_FP);
}

static void test_sign_change_and_friction(void)
{
    reset_test();
    intents[0].move_x = 1;
    players_update(intents, 0);
    assert(g_players[0].vx_fp > 0);
    intents[0].move_x = 0;
    players_update(intents, 0);
    assert(g_players[0].vx_fp >= 0);
    intents[0].move_x = -1;
    players_update(intents, 0);
    players_update(intents, 0);
    assert(g_players[0].vx_fp < 0);
}

static void test_all_clamps(void)
{
    reset_test();
    g_players[0].x_fp = TO_FP(PLAYER_CLAMP_MIN_X) - 100;
    g_players[0].y_fp = TO_FP(PLAYER_CLAMP_MIN_Y) - 100;
    players_update(intents, 0);
    assert(g_players[0].x_fp == TO_FP(PLAYER_CLAMP_MIN_X));
    assert(g_players[0].y_fp == TO_FP(PLAYER_CLAMP_MIN_Y));

    g_players[0].x_fp = TO_FP(PLAYER_CLAMP_MAX_X) + 100;
    g_players[0].y_fp = TO_FP(PLAYER_CLAMP_MAX_Y) + 100;
    players_update(intents, 0);
    assert(g_players[0].x_fp == TO_FP(PLAYER_CLAMP_MAX_X));
    assert(g_players[0].y_fp == TO_FP(PLAYER_CLAMP_MAX_Y));
}

static void test_anchor_bounds_match_court(void)
{
    /* Left half: behind the baseline runoff up to the net gap. */
    assert(PLAYER_CLAMP_MIN_X == COURT_BASELINE_LEFT - PLAYER_RUNOFF_BACK);
    assert(PLAYER_CLAMP_MIN_X >= 0);
    assert(PLAYER_CLAMP_MAX_X + PLAYER_NET_GAP == COURT_NET_X);
    /* Right half mirrors the left around the net. */
    assert(PLAYER_RIGHT_CLAMP_MIN_X - COURT_NET_X ==
        COURT_NET_X - PLAYER_CLAMP_MAX_X);
    assert(PLAYER_RIGHT_CLAMP_MAX_X - COURT_BASELINE_RIGHT ==
        COURT_BASELINE_LEFT - PLAYER_CLAMP_MIN_X);
    assert(PLAYER_RIGHT_CLAMP_MAX_X <= 255);
    /* Feet may step just outside the sidelines but never off the sand. */
    assert(PLAYER_CLAMP_MIN_Y < COURT_SIDELINE_TOP);
    assert(PLAYER_CLAMP_MAX_Y > COURT_SIDELINE_BOTTOM);
    assert(PLAYER_CLAMP_MAX_Y - PLAYER_SPRITE_FOOT_Y > 0);
}

static void test_input_edges(void)
{
    PadSnapshot snapshot = {0, 0, 0};
    input_update_snapshot(&snapshot, 0x8000);
    assert(snapshot.held == 0x8000);
    assert(snapshot.pressed == 0x8000);
    assert(snapshot.released == 0);

    input_update_snapshot(&snapshot, 0x8000);
    assert(snapshot.pressed == 0);
    assert(snapshot.released == 0);

    input_update_snapshot(&snapshot, 0x1000);
    assert(snapshot.held == 0x1000);
    assert(snapshot.pressed == 0x1000);
    assert(snapshot.released == 0x8000);
}

static void test_twenty_pause_toggles(void)
{
    u8 i;
    reset_test();
    game_initialize();
    for (i = 0; i < 20; ++i) {
        intents[0].pause_pressed = 1;
        game_update(intents);
        assert(g_game_state.paused == ((i + 1) & 1));
    }
    assert(g_game_state.paused == 0);
}

static void assert_state_for_frames(u8 state, u8 frames)
{
    u8 i;
    for (i = 0; i < frames; ++i) {
        assert(g_players[0].state == state);
        intents[0].hit_pressed = 0;
        if (i + 1 < frames)
            players_update(intents, 0);
    }
}

static void test_swing_state_durations(void)
{
    reset_test();
    intents[0].hit_pressed = 1;
    players_update(intents, 0);
    assert_state_for_frames(PLAYER_STATE_WINDUP, PLAYER_WINDUP_FRAMES);

    players_update(intents, 0);
    assert_state_for_frames(PLAYER_STATE_ACTIVE, PLAYER_ACTIVE_FRAMES);

    players_update(intents, 0);
    assert_state_for_frames(PLAYER_STATE_RECOVERY, PLAYER_RECOVERY_FRAMES);

    players_update(intents, 0);
    assert(g_players[0].state == PLAYER_STATE_IDLE);
    assert(g_players[0].state_frames_remaining == 0);
}

static void test_swing_movement_penalty(void)
{
    reset_test();
    g_players[0].vx_fp = PLAYER_MAX_SPEED_FP;
    intents[0].move_x = 1;
    intents[0].hit_pressed = 1;
    players_update(intents, 0);
    assert(g_players[0].state == PLAYER_STATE_WINDUP);
    assert(g_players[0].vx_fp == PLAYER_SWING_MAX_SPEED_FP);

    reset_test();
    g_players[0].vx_fp = player_diagonal_limit(PLAYER_MAX_SPEED_FP);
    g_players[0].vy_fp = player_diagonal_limit(PLAYER_MAX_SPEED_FP);
    intents[0].move_x = 1;
    intents[0].move_y = 1;
    intents[0].hit_pressed = 1;
    players_update(intents, 0);
    assert(g_players[0].vx_fp ==
        player_diagonal_limit(PLAYER_SWING_MAX_SPEED_FP));
    assert(g_players[0].vy_fp ==
        player_diagonal_limit(PLAYER_SWING_MAX_SPEED_FP));
}

/* ADR-020 SPEED: the gold paddle recovers a frame sooner and moves faster
 * while swinging; windup and active frames never change. */
static void test_paddle_speed(void)
{
    reset_test();
    g_players[0].paddle = PADDLE_GOLD;
    g_players[0].vx_fp = PLAYER_MAX_SPEED_FP;
    intents[0].move_x = 1;
    intents[0].hit_pressed = 1;
    players_update(intents, 0);
    assert(g_players[0].vx_fp == g_paddle_swing_limit[PADDLE_GOLD]);
    assert(g_paddle_swing_limit[PADDLE_GOLD] > PLAYER_SWING_MAX_SPEED_FP);
    intents[0].move_x = 0;
    assert_state_for_frames(PLAYER_STATE_WINDUP, PLAYER_WINDUP_FRAMES);
    players_update(intents, 0);
    assert_state_for_frames(PLAYER_STATE_ACTIVE, PLAYER_ACTIVE_FRAMES);
    players_update(intents, 0);
    assert_state_for_frames(PLAYER_STATE_RECOVERY, PLAYER_RECOVERY_FRAMES - 1);
}

static void test_no_swing_retrigger(void)
{
    u8 frame;
    reset_test();
    intents[0].hit_pressed = 1;
    players_update(intents, 0);

    for (frame = 1;
         frame <= PLAYER_WINDUP_FRAMES + PLAYER_ACTIVE_FRAMES +
             PLAYER_RECOVERY_FRAMES;
         ++frame) {
        intents[0].hit_pressed = 1;
        players_update(intents, 0);
    }
    assert(g_players[0].state == PLAYER_STATE_IDLE);

    intents[0].hit_pressed = 1;
    players_update(intents, 0);
    assert(g_players[0].state == PLAYER_STATE_WINDUP);
    assert(g_players[0].state_frames_remaining == PLAYER_WINDUP_FRAMES);
}

static void test_swing_freezes_while_paused(void)
{
    reset_test();
    intents[0].hit_pressed = 1;
    players_update(intents, 0);
    players_update(intents, 1);
    assert(g_players[0].state == PLAYER_STATE_WINDUP);
    assert(g_players[0].state_frames_remaining == PLAYER_WINDUP_FRAMES);
}

int main(void)
{
    test_initialization();
    test_zero_input_and_pause();
    test_diagonal_normalization();
    test_sign_change_and_friction();
    test_all_clamps();
    test_anchor_bounds_match_court();
    test_input_edges();
    test_twenty_pause_toggles();
    test_swing_state_durations();
    test_swing_movement_penalty();
    test_paddle_speed();
    test_no_swing_retrigger();
    test_swing_freezes_while_paused();
    puts("player host checks passed");
    return 0;
}

