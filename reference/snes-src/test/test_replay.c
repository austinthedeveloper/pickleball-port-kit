#include <assert.h>
#include <stdio.h>
#include "ball.h"
#include "court.h"
#include "game.h"
#include "player.h"
#include "replay.h"

/* ADR-041: the close-up shows for a long rally that lands just out. */

static void land(s16 x16, s16 y16)
{
    g_ball.x_fp = x16;
    g_ball.y_fp = y16;
}

static void test_close_calls(void)
{
    replay_initialize();
    assert(!g_replay.active);

    /* Two pixels past the right baseline after a long rally: about 4.7
     * inches, toward +x. */
    land(TO_FP(COURT_BASELINE_RIGHT + 2), TO_FP(COURT_CENTERLINE_Y));
    replay_check(REPLAY_MIN_SHOTS, GAME_FAULT_OUT);
    assert(g_replay.active && g_replay.vertical && g_replay.out_dir == 1);
    assert(g_replay.dist_fp == TO_FP(2) && g_replay.inches == 4);

    /* A short rally, another fault, or a wide miss: no close-up. */
    replay_check(REPLAY_MIN_SHOTS - 1, GAME_FAULT_OUT);
    assert(!g_replay.active);
    replay_check(REPLAY_MIN_SHOTS, GAME_FAULT_NET);
    assert(!g_replay.active);
    land(TO_FP(COURT_BASELINE_RIGHT + 6), TO_FP(COURT_CENTERLINE_Y));
    replay_check(REPLAY_MIN_SHOTS, GAME_FAULT_OUT);
    assert(!g_replay.active);
    land(TO_FP(COURT_BASELINE_RIGHT + 60), TO_FP(COURT_CENTERLINE_Y));
    replay_check(REPLAY_MIN_SHOTS, GAME_FAULT_OUT);
    assert(!g_replay.active);

    /* Past the top sideline by a hair: a horizontal line, toward -y. */
    land(TO_FP(100), TO_FP(COURT_SIDELINE_TOP) - 3);
    replay_check(REPLAY_MIN_SHOTS + 4, GAME_FAULT_OUT);
    assert(g_replay.active && !g_replay.vertical && g_replay.out_dir == -1);
    assert(g_replay.inches == 0);

    /* Past the left baseline and the bottom sideline: the farther one. */
    land(TO_FP(COURT_BASELINE_LEFT) - 8, TO_FP(COURT_SIDELINE_BOTTOM) + 20);
    replay_check(REPLAY_MIN_SHOTS, GAME_FAULT_OUT);
    assert(g_replay.active && !g_replay.vertical && g_replay.out_dir == 1);

    /* Landed in (an OUT for landing on the hitter's own side): no line. */
    land(TO_FP(100), TO_FP(COURT_CENTERLINE_Y));
    replay_check(REPLAY_MIN_SHOTS, GAME_FAULT_OUT);
    assert(!g_replay.active);
}

int main(void)
{
    test_close_calls();
    printf("replay host checks passed\n");
    return 0;
}
