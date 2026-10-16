#include "ball.h"
#include "court.h"
#include "game.h"
#include "player.h"
#include "replay.h"

ReplayState g_replay;

void replay_initialize(void)
{
    g_replay.active = 0;
}

void replay_check(u8 shots, u8 fault)
{
    fx x = g_ball.x_fp;
    fx y = g_ball.y_fp;
    s16 past_x = 0;
    s16 past_y = 0;
    s16 dir_x = 0;
    s16 dir_y = 0;

    g_replay.active = 0;
    if (fault != GAME_FAULT_OUT || shots < REPLAY_MIN_SHOTS)
        return;
    /* How far past each line: the baselines are x, the sidelines y. */
    if (x < TO_FP(COURT_BASELINE_LEFT)) {
        past_x = TO_FP(COURT_BASELINE_LEFT) - x;
        dir_x = -1;
    } else if (x > TO_FP(COURT_BASELINE_RIGHT)) {
        past_x = x - TO_FP(COURT_BASELINE_RIGHT);
        dir_x = 1;
    }
    if (y < TO_FP(COURT_SIDELINE_TOP)) {
        past_y = TO_FP(COURT_SIDELINE_TOP) - y;
        dir_y = -1;
    } else if (y > TO_FP(COURT_SIDELINE_BOTTOM)) {
        past_y = y - TO_FP(COURT_SIDELINE_BOTTOM);
        dir_y = 1;
    }
    /* Past a corner, the farther line made it out. An out ball on its
     * hitter's own side (short of the net) is not a line call. */
    if (!dir_x && !dir_y)
        return;
    g_replay.vertical = past_x >= past_y;
    g_replay.dist_fp = g_replay.vertical ? past_x : past_y;
    g_replay.out_dir = g_replay.vertical ? dir_x : dir_y;
    if (g_replay.dist_fp > REPLAY_NEAR_FP ||
            REPLAY_INCHES(g_replay.dist_fp) > REPLAY_MAX_INCHES)
        return;
    g_replay.inches = (u8)REPLAY_INCHES(g_replay.dist_fp);
    g_replay.active = 1;
}
