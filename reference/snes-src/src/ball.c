#include <string.h>
#include "ram_copy.h"
#include "ball.h"
#include "court.h"
#include "player.h"

Ball g_ball;

/* Scales toward zero symmetrically so +v and -v lose the same speed. */
s16 ball_retain(s16 value, s16 fraction_256)
{
    if (value < 0)
        return (s16)-((-value * fraction_256) >> 8);
    return (s16)((value * fraction_256) >> 8);
}

void ball_initialize(void)
{
    /* Zero padding bytes too: the struct is copied whole every step. */
    memset(&g_ball, 0, sizeof(g_ball));
    g_ball.active = 1;
    g_ball.x_fp = TO_FP(BALL_START_X);
    g_ball.y_fp = TO_FP(BALL_START_Y);
    g_ball.z_fp = TO_FP(BALL_START_Z);
    g_ball.vx_fp = 0;
    g_ball.vy_fp = 0;
    g_ball.vz_fp = BALL_START_VZ_FP;
    g_ball.last_hitter = BALL_NO_HITTER;
    g_ball.bounce_count = 0;
    g_ball.rally_state = BALL_RALLY_LIVE;
}

void ball_launch(Ball *ball, s16 target_x, s16 target_y, u8 frames)
{
    s16 half = frames >> 1;
    s16 dx = TO_FP(target_x) - ball->x_fp;
    s16 dy = TO_FP(target_y) - ball->y_fp;
    /* z(T) = z0 + vz*T + g*T*(T-1)/2 = 0. */
    s16 rise = -ball->z_fp - BALL_GRAVITY_FP * (s16)frames * (frames - 1) / 2;

    ball->vx_fp = (dx >= 0 ? dx + half : dx - half) / (s16)frames;
    ball->vy_fp = (dy >= 0 ? dy + half : dy - half) / (s16)frames;
    /* Floor, so z reaches the ground on exactly the T-th step. */
    ball->vz_fp = (rise >= 0 ? rise : rise - (s16)frames + 1) / (s16)frames;
}

u8 ball_net_crossing_height(fx previous_x_fp, fx previous_z_fp,
    fx current_x_fp, fx current_z_fp, fx *height_fp)
{
    fx net_x_fp = TO_FP(COURT_NET_X);
    s16 x_distance;
    s16 distance_to_net;
    s16 z_distance;

    if (previous_x_fp < net_x_fp) {
        if (current_x_fp < net_x_fp)
            return 0;
    } else if (previous_x_fp > net_x_fp) {
        if (current_x_fp > net_x_fp)
            return 0;
    } else {
        return 0;
    }

    x_distance = current_x_fp - previous_x_fp;
    distance_to_net = net_x_fp - previous_x_fp;
    z_distance = current_z_fp - previous_z_fp;
    *height_fp = previous_z_fp +
        (fx)((z_distance * distance_to_net) / x_distance);
    return 1;
}

/* Static scratch copy: 816-tcc reaches static fields with one long access,
 * where each pointer dereference costs several stack loads. The AI calls
 * this up to seven times a frame. */
static Ball s_b;

u8 ball_simulate_step(Ball *ball)
{
    u8 events = BALL_EVENT_NONE;
    fx previous_x;
    fx previous_z;
    fx crossing_height;
    s16 impact_vz;

    if (!ball->active || ball->rally_state != BALL_RALLY_LIVE)
        return BALL_EVENT_NONE;
    RAM_COPY(&s_b, ball, sizeof(Ball));

    if (s_b.z_fp == 0 && s_b.vz_fp <= 0) {
        s_b.vx_fp = 0;
        s_b.vy_fp = 0;
        s_b.vz_fp = 0;
        RAM_COPY(ball, &s_b, sizeof(Ball));
        return BALL_EVENT_NONE;
    }

    previous_x = s_b.x_fp;
    previous_z = s_b.z_fp;
    s_b.x_fp += s_b.vx_fp;
    s_b.y_fp += s_b.vy_fp;
    s_b.z_fp += s_b.vz_fp;
    s_b.vz_fp += BALL_GRAVITY_FP;

    /* Only frames that cross the net plane pay for the swept test. */
    if ((previous_x < TO_FP(COURT_NET_X)) != (s_b.x_fp < TO_FP(COURT_NET_X)) &&
        ball_net_crossing_height(previous_x, previous_z,
            s_b.x_fp, s_b.z_fp, &crossing_height)) {
        if (crossing_height < TO_FP(COURT_NET_HEIGHT))
            events |= BALL_EVENT_NET_FAULT;
    }

    if (previous_z > 0 && s_b.z_fp <= 0) {
        impact_vz = s_b.vz_fp - BALL_GRAVITY_FP;
        s_b.z_fp = 0;
        s_b.vx_fp = ball_retain(s_b.vx_fp, BALL_BOUNCE_PLANAR_256);
        s_b.vy_fp = ball_retain(s_b.vy_fp, BALL_BOUNCE_PLANAR_256);
        s_b.vz_fp = -ball_retain(impact_vz, BALL_BOUNCE_VERTICAL_256);
        ++s_b.bounce_count;
        events |= BALL_EVENT_BOUNCE;
        if (!court_contains_ground_fp(s_b.x_fp, s_b.y_fp))
            events |= BALL_EVENT_OUT;
        if (s_b.vz_fp <= BALL_MIN_BOUNCE_VZ_FP) {
            s_b.vx_fp = 0;
            s_b.vy_fp = 0;
            s_b.vz_fp = 0;
        }
    }

    RAM_COPY(ball, &s_b, sizeof(Ball));
    return events;
}

u8 ball_update(u8 paused)
{
    if (paused)
        return 0;
    return ball_simulate_step(&g_ball);
}
