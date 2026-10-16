#ifndef COURT_H
#define COURT_H

#include "game_types.h"

/*
 * World coordinates (rules space) are whole ground pixels: y is the screen
 * row of the ground point and x is the column at the near sideline. Only
 * presentation projects x through the generated court_projection.h table
 * (ADR-011); physics, rules, and AI never see the projection.
 * tools/court_projection.py derives that table from the values below and
 * tools/art/prep_court_scene.py paints the court through it.
 */
enum {
    COURT_BASELINE_LEFT = 16,
    COURT_BASELINE_RIGHT = 240,
    COURT_SIDELINE_TOP = 90,
    COURT_SIDELINE_BOTTOM = 170,
    COURT_NET_X = 128,
    COURT_KITCHEN_LEFT_X = 92,
    COURT_KITCHEN_RIGHT_X = 164,
    COURT_CENTERLINE_Y = 130,
    COURT_NET_HEIGHT = 12,
    /* 8.8 horizontal scale at the far and near sidelines (0.84 .. 1.00). */
    COURT_PROJ_SCALE_TOP = 216,
    COURT_PROJ_SCALE_BOTTOM = 256,

    /* Player x/y is the ground point between the feet. */
    PLAYER_SPRITE_HALF_WIDTH = 16,
    PLAYER_SPRITE_FOOT_Y = 30,
    PLAYER_RUNOFF_BACK = 12,
    PLAYER_RUNOFF_SIDE = 10,
    PLAYER_NET_GAP = 8,

    PLAYER_SPAWN_X = 40,
    PLAYER_SPAWN_Y = 150,
    PLAYER_CLAMP_MIN_X = COURT_BASELINE_LEFT - PLAYER_RUNOFF_BACK,
    PLAYER_CLAMP_MAX_X = COURT_NET_X - PLAYER_NET_GAP,
    PLAYER_CLAMP_MIN_Y = COURT_SIDELINE_TOP - PLAYER_RUNOFF_SIDE + 4,
    PLAYER_CLAMP_MAX_Y = COURT_SIDELINE_BOTTOM + PLAYER_RUNOFF_SIDE,
    PLAYER_RIGHT_CLAMP_MIN_X = COURT_NET_X + PLAYER_NET_GAP,
    PLAYER_RIGHT_CLAMP_MAX_X = COURT_BASELINE_RIGHT + PLAYER_RUNOFF_BACK
};

/*
 * Side helpers (docs/REFACTOR_PLAN.md R6). The court is symmetric about the
 * net, so values defined for the left team mirror to the right team.
 */
#define COURT_MIRROR_X(x) (2 * COURT_NET_X - (x))

/* +1 for the left team (toward the net is +x), -1 for the right team. */
s16 court_toward_net(u8 team);
/* Team whose half contains x; the net plane itself counts as the right. */
u8 court_side_of_x(fx x_fp);
/* Nonzero when x is strictly inside that team's half. */
u8 court_x_on_side(fx x_fp, u8 team);
/* Shot depth from an aim: +1 deep (toward the opponent), -1 short, 0. */
s16 court_aim_depth(u8 team, s16 aim_x);
/* A target given for a left-team hitter (right half), mirrored for the
 * right team. */
s16 court_target_x(u8 team, s16 left_hitter_x);

/* Clamp a ground position to the legal half for the given team (0 = left). */
fx court_clamp_x_fp(fx x_fp, u8 team);
fx court_clamp_y_fp(fx y_fp);
u8 court_contains_ground_fp(fx x_fp, fx y_fp);

#endif
