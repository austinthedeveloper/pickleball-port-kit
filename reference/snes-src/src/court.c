#include "court.h"
#include "player.h"

fx court_clamp_x_fp(fx x_fp, u8 team)
{
    fx min_x;
    fx max_x;

    if (team == 0) {
        min_x = TO_FP(PLAYER_CLAMP_MIN_X);
        max_x = TO_FP(PLAYER_CLAMP_MAX_X);
    } else {
        min_x = TO_FP(PLAYER_RIGHT_CLAMP_MIN_X);
        max_x = TO_FP(PLAYER_RIGHT_CLAMP_MAX_X);
    }
    if (x_fp < min_x)
        return min_x;
    if (x_fp > max_x)
        return max_x;
    return x_fp;
}

fx court_clamp_y_fp(fx y_fp)
{
    if (y_fp < TO_FP(PLAYER_CLAMP_MIN_Y))
        return TO_FP(PLAYER_CLAMP_MIN_Y);
    if (y_fp > TO_FP(PLAYER_CLAMP_MAX_Y))
        return TO_FP(PLAYER_CLAMP_MAX_Y);
    return y_fp;
}

u8 court_contains_ground_fp(fx x_fp, fx y_fp)
{
    if (x_fp < TO_FP(COURT_BASELINE_LEFT))
        return 0;
    if (x_fp > TO_FP(COURT_BASELINE_RIGHT))
        return 0;
    if (y_fp < TO_FP(COURT_SIDELINE_TOP))
        return 0;
    if (y_fp > TO_FP(COURT_SIDELINE_BOTTOM))
        return 0;
    return 1;
}

s16 court_toward_net(u8 team)
{
    return team ? -1 : 1;
}

u8 court_side_of_x(fx x_fp)
{
    return x_fp < TO_FP(COURT_NET_X) ? 0 : 1;
}

u8 court_x_on_side(fx x_fp, u8 team)
{
    if (team == 0)
        return x_fp < TO_FP(COURT_NET_X);
    return x_fp > TO_FP(COURT_NET_X);
}

s16 court_aim_depth(u8 team, s16 aim_x)
{
    /* team ? -aim_x : aim_x, not aim_x * court_toward_net(team): a
     * multiply is a library call on 816-tcc (R22). */
    s16 toward = team ? -aim_x : aim_x;
    if (toward > 0)
        return 1;
    if (toward < 0)
        return -1;
    return 0;
}

s16 court_target_x(u8 team, s16 left_hitter_x)
{
    return team ? COURT_MIRROR_X(left_hitter_x) : left_hitter_x;
}
