#ifndef BALL_H
#define BALL_H

#include "game_types.h"

enum {
    /* 12.4 units: -0.1875 px/frame^2. */
    BALL_GRAVITY_FP = -3,
    /* Bounce retention as n/256: 141 = 55%, 236 = 92%. */
    BALL_BOUNCE_VERTICAL_256 = 141,
    BALL_BOUNCE_PLANAR_256 = 236,
    BALL_MIN_BOUNCE_VZ_FP = 4,
    BALL_START_X = 104,
    BALL_START_Y = 112,
    BALL_START_Z = 0,
    BALL_START_VZ_FP = 0,
    BALL_NO_HITTER = 0xff
};

typedef enum {
    BALL_RALLY_INACTIVE = 0,
    BALL_RALLY_LIVE = 1
} BallRallyState;

typedef enum {
    BALL_EVENT_NONE = 0,
    BALL_EVENT_BOUNCE = 1,
    BALL_EVENT_NET_FAULT = 2,
    BALL_EVENT_OUT = 4
} BallEvent;

typedef struct {
    u8 active;
    fx x_fp;
    fx y_fp;
    fx z_fp;
    s16 vx_fp;
    s16 vy_fp;
    s16 vz_fp;
    u8 last_hitter;
    u8 bounce_count;
    u8 rally_state;
} Ball;

extern Ball g_ball;

void ball_initialize(void);
u8 ball_net_crossing_height(fx previous_x_fp, fx previous_z_fp,
    fx current_x_fp, fx current_z_fp, fx *height_fp);
s16 ball_retain(s16 value, s16 fraction_256);
/* Sets velocity so the ball lands on (target_x, target_y) after `frames`. */
void ball_launch(Ball *ball, s16 target_x, s16 target_y, u8 frames);
u8 ball_simulate_step(Ball *ball);
u8 ball_update(u8 paused);

#endif
