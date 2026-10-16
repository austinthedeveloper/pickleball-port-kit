#ifndef GAME_H
#define GAME_H

#include "game_types.h"
#include "input.h"
#include "options.h"

typedef enum {
    GAME_PHASE_SERVE_SETUP = 0,
    GAME_PHASE_SERVE_TOSS = 1,
    GAME_PHASE_LIVE = 2,
    GAME_PHASE_SERVE_FAULT = 3,
    GAME_PHASE_POINT_RESULT = 4,
    GAME_PHASE_MATCH_RESULT = 5
} GamePhase;

typedef enum {
    GAME_FAULT_NONE = 0,
    GAME_FAULT_NET = 1,
    GAME_FAULT_KITCHEN = 2,
    GAME_FAULT_WRONG_BOX = 3,
    GAME_FAULT_OUT = 4,
    GAME_FAULT_SECOND_BOUNCE = 5,
    GAME_FAULT_EARLY_VOLLEY = 6,
    GAME_FAULT_LAVA = 7         /* ADR-033: stepped into the kitchen */
} GameFault;

typedef enum {
    GAME_REQUIRED_BOUNCE_NONE = 0,
    GAME_REQUIRED_BOUNCE_SERVE = 1,
    GAME_REQUIRED_BOUNCE_RETURN = 2
} GameRequiredBounce;

enum {
    GAME_POINTS_TO_WIN = 5,         /* the default; g_match_config decides */
    GAME_SERVE_READY_FRAMES = 20,
    GAME_POINT_RESULT_MIN_FRAMES = 20,
    GAME_POINT_RESULT_FRAMES = 90,
    GAME_HIT_STOP_FRAMES = 2,
    GAME_HIT_FLASH_FRAMES = 2,
    GAME_NO_TEAM = 0xff
};

typedef struct {
    u8 paused;
    u8 phase;
    u16 phase_timer;
    u8 last_fault;
    u8 point_winner;
    u8 team_score[2];
    u8 required_bounce;
    u8 serving_team;
    u8 match_winner;
    u8 hit_stop;
    /* Increments on every serve and contact; lets controllers see a new shot. */
    u8 shot_serial;
    u16 frame_count;
} GameState;

extern GameState g_game_state;
/* Nonzero while the attract demo (CPU vs CPU behind the title) runs. */
extern u8 g_attract;
/* Set when a match start changed g_match_config; the frame loop re-applies
 * presentation (palettes, colour math) and clears it. */
extern u8 g_match_config_changed;
extern u8 g_demo_mode;
/* Set when B on the result of a ladder win asks for the next opponent
 * (ADR-023): main.c sets them up, reloads the court, and clears it. */
extern u8 g_next_opponent;
/* Set when B on an open play game's result asks for the park (ADR-034):
 * main.c goes back and clears it. */
extern u8 g_back_to_park;

enum {
    GAME_ATTRACT_RESULT_FRAMES = 150,
    GAME_ATTRACT_LATE_PERIOD = 5
};

void game_initialize(void);
void game_new_match(void);
/* ATTRACT_READY: demo match with slot 0 driven by the AI. */
void game_start_attract(void);
/* Leaves attract and starts a human match in the given mode. */
void game_start_match(void);
void game_set_phase(u8 phase);
void game_update(const PlayerIntent intents[MAX_PLAYERS]);
/* Nonzero when the ball's pace varies by frame: a slow ball (ADR-025),
 * BALL SPEED off 100% (ADR-049), or FAST BALL (ADR-033). Otherwise it
 * steps once every frame. */
extern u8 g_ball_paced;
/* When paced: the ball's steps (0, 1, or 2) on each tick of two cycles,
 * and this frame's tick (0..OPTIONS_BALL_CYCLE-1). A table, not a call:
 * the CPUs' swing lookahead reads it up to ten times a frame each. */
/* A cycle and the CPUs' lookahead past its end (a swing's 8 frames). */
enum { GAME_BALL_PACE_TICKS = OPTIONS_BALL_CYCLE + 12 };
extern u8 g_ball_pace[GAME_BALL_PACE_TICKS];
extern u8 g_ball_tick;
/* Ball steps `frames` frames from now (0 = during this frame's update;
 * at most OPTIONS_BALL_CYCLE): 0, 1, or 2. Only when g_ball_paced. */
#define GAME_BALL_STEPS_AHEAD(frames) g_ball_pace[g_ball_tick + (frames)]
/* Ball physics steps taken this match: the CPUs' landing cache (ai.c)
 * counts the steps a cached flight has already flown. */
extern u16 g_ball_steps;
/* This frame's ball steps at the match's pace; BallEvent bits. */
u8 game_step_ball(void);
/* Nonzero when the team has won the match (POINTS, and WIN BY 2). */
u8 game_team_won(u8 team);
/* Nonzero when one more point wins the match for the team. */
u8 game_match_point(u8 team);
/* A player's paddle met the ball: flash, hit stop, and the HIT event. */
void game_contact(u8 player_index);

#endif
