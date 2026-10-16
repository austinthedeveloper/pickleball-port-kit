#ifndef COLLISION_H
#define COLLISION_H

#include "ball.h"
#include "court.h"
#include "player.h"

enum {
    HIT_REACH_X = 22,
    HIT_REACH_Y = 16,
    HIT_REACH_Z = 24,
    /* Contacts inside the sweet box go where aimed; stretched contacts at
     * the edge of reach spray wide and long by HIT_STRETCH_* pixels. */
    HIT_SWEET_X = 14,
    HIT_SWEET_Y = 10,
    HIT_STRETCH_WIDE = 20,
    HIT_STRETCH_LONG = 16,
    HIT_TARGET_LANE_TOP = COURT_SIDELINE_TOP + 14,
    HIT_TARGET_LANE_CENTER = COURT_CENTERLINE_Y,
    HIT_TARGET_LANE_BOTTOM = COURT_SIDELINE_BOTTOM - 14,
    /* Targets for a left-team hitter; the right team mirrors them. */
    HIT_TARGET_SHORT_RIGHT = COURT_KITCHEN_RIGHT_X + 12,
    HIT_TARGET_NEUTRAL_RIGHT = COURT_KITCHEN_RIGHT_X + 40,
    HIT_TARGET_DEEP_RIGHT = COURT_BASELINE_RIGHT - 12,
    HIT_TARGET_SHORT_LEFT = COURT_MIRROR_X(HIT_TARGET_SHORT_RIGHT),
    HIT_TARGET_NEUTRAL_LEFT = COURT_MIRROR_X(HIT_TARGET_NEUTRAL_RIGHT),
    HIT_TARGET_DEEP_LEFT = COURT_MIRROR_X(HIT_TARGET_DEEP_RIGHT),
    /* Horizontal pace in 12.4 units: 3.0 / 2.75 / 2.5 px per frame. Flight
     * time is distance / pace, clamped so lobs stay below the HUD (apex
     * ~50 px) and inside the AI's 60-step prediction horizon. */
    HIT_PACE_DEEP_FP = 48,
    HIT_PACE_NEUTRAL_FP = 44,
    HIT_PACE_SHORT_FP = 40,
    HIT_FLIGHT_MIN_FRAMES = 24,
    HIT_FLIGHT_MAX_FRAMES = 46,

    /* Shot types (ADR-019), in 12.4 pace and flight frames. */
    HIT_PACE_DRIVE_FP = 60,                 /* 3.75 px/frame */
    HIT_DRIVE_MIN_FRAMES = 16,
    HIT_DRIVE_MAX_FRAMES = 30,
    HIT_DRIVE_STRETCH_WIDE = 26,
    HIT_DRIVE_STRETCH_LONG = 22,
    HIT_PACE_LOB_FP = 28,                   /* 1.75 px/frame, high arc */
    HIT_LOB_MIN_FRAMES = 44,
    HIT_LOB_MAX_FRAMES = 50,                /* apex ~58 px; < AI horizon */
    HIT_PACE_DINK_FP = 24,                  /* 1.5 px/frame */
    /* A dink lands inside the opponent's kitchen. */
    HIT_TARGET_DINK_RIGHT = COURT_NET_X + 18,
    HIT_TARGET_DINK_LEFT = COURT_MIRROR_X(HIT_TARGET_DINK_RIGHT)
};

/* The hit box for this match, in 12.4 units: HIT_REACH_* and HIT_SWEET_*,
 * each MODIFIER_BIG_REACH larger for BIG BALL (ADR-033). The spans are
 * twice the half-widths: -r <= d <= r is one unsigned test,
 * (u16)(d + r) <= span, which the swing lookahead runs dozens of times a
 * frame. */
typedef struct {
    fx reach_x;
    fx reach_y;
    fx reach_z;
    fx sweet_x;
    fx sweet_y;
    u16 reach_x_span;
    u16 reach_y_span;
    u16 sweet_x_span;
    u16 sweet_y_span;
    u8 big;                     /* configured for BIG BALL */
} HitBox;

/* Nonzero when -half <= d <= half, given span = 2 * half. */
#define HIT_WITHIN(d, half, span) ((u16)((d) + (half)) <= (span))

extern HitBox g_hit_box;

/* Sets g_hit_box for a normal (0) or big (1) ball; main() configures the
 * normal one at boot. */
void collision_configure(u8 big_ball);
u8 collision_ball_in_player_reach(const Player *player, const Ball *ball);
u8 collision_ball_in_sweet_spot(const Player *player, const Ball *ball);
/* Returns the contacting player index plus one, or zero for no contact. */
u8 collision_resolve_player_hits(Ball *ball, Player players[MAX_PLAYERS],
    const PlayerIntent intents[MAX_PLAYERS], u8 player_count);

#endif
