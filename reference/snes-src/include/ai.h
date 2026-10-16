#ifndef AI_H
#define AI_H

#include "ball.h"
#include "input.h"
#include "opponents.h"
#include "player.h"

/*
 * The default CPU. Recover x, the late period, and the shot thresholds are
 * also the default AiStyle (ADR-023); tools/assetgen/opponents.py fails the
 * build if opponents.json's default_style drifts from them.
 */
enum {
    AI_PREDICT_MAX_STEPS = 60,
    AI_RECOVER_X = 208,           /* right team; mirrored for the left */
    AI_RECOVER_Y = 130,
    /* Doubles lane homes (ADR-018): top and bottom of the half. */
    AI_RECOVER_Y_TOP = 110,
    AI_RECOVER_Y_BOTTOM = 150,
    /* Stand this far behind the predicted contact point (difficulty knob). */
    AI_CONTACT_OFFSET_X = 10,
    AI_DEAD_ZONE = 3,
    AI_SERVE_DELAY_FRAMES = 50,
    /* KID (ADR-025): a human's serve goes by itself after this long, which
     * leaves time to aim with the D-pad. */
    AI_ASSIST_SERVE_FRAMES = 90,
    /* Difficulty: every Nth return the CPU is deliberately late and takes a
     * stretched last-chance contact, which sprays the ball (no randomness). */
    AI_LATE_SHOT_PERIOD = 7,
    /* Shot choice (ADR-019): put-away drive on a ball at least this high
     * within this distance of the net; lob when an opponent is this close to
     * the net. */
    AI_PUTAWAY_Z = 14,
    AI_PUTAWAY_NET_DISTANCE = 48,
    AI_LOB_NET_DISTANCE = 44,
    /* Look ahead windup + first active frame when deciding to swing. */
    AI_SWING_LOOKAHEAD = PLAYER_WINDUP_FRAMES + 1
};

typedef struct {
    u8 has_target;
    s16 target_x;
    s16 target_y;
    s16 predicted_land_x;
    s16 predicted_land_y;
    u8 predicted_frames;  /* until the landing: its ball steps, fewer with
                             FAST BALL (ADR-033) */
    u8 plan_age;          /* frames since predicted_frames was computed */
    u8 shot_counter;
    u8 plan_key;
    /* Difficulty: frames an incoming ball is ignored before reacting. */
    u8 reaction_frames;
    u8 incoming_frames;
    u8 late_period;      /* 0 = never deliberately late */
    u8 returns;
    u8 late_this_ball;
    u8 seen_shot;
    u8 planned_shot;      /* ShotType chosen at the swing press (ADR-019) */
    s16 planned_depth;    /* +1 deep, 0 neutral, -1 short */
} AiState;

/* Working copy for the controller being updated (and the debug marker);
 * each slot's state persists in g_ai_slots between frames. */
extern AiState g_ai;
extern AiState g_ai_slots[MAX_PLAYERS];
/* Play style per slot (ADR-023), set when a match starts; outside AiState,
 * which golden traces compare byte for byte. */
extern AiStyle g_ai_styles[MAX_PLAYERS];

/* Swing lookahead probe (exposed for test_ai.c's equivalence check). */
typedef struct {
    fx x;
    fx y;
    fx z;
    s16 vx;
    s16 vy;
    s16 vz;
    u8 bounces;
} AiProbe;

extern AiProbe g_probe;
void ai_probe_load(const Ball *ball);
/* One probe step, exactly as ball_simulate_step moves the ball. */
void ai_probe_step(void);

void ai_initialize(void);
/* Predicts the next ground contact; returns steps simulated (<= cap). */
u8 ai_predict_landing(const Ball *ball, s16 *land_x, s16 *land_y);
/* Writes the CPU player's PlayerIntent for this frame. */
void ai_update(u8 player_index, PlayerIntent *intent);
/* KID difficulty (ADR-025): nonzero when a human's swing pressed now
 * would meet the ball, or when their serve has waited long enough. */
u8 ai_assist_swing(u8 player_index);
/* Repeats the previous ai_update movement without a new swing press. */
void ai_hold_intent(u8 player_index, PlayerIntent *intent);

#endif
