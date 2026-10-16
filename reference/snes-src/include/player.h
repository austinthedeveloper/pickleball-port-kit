#ifndef PLAYER_H
#define PLAYER_H

#include "game_types.h"
#include "input.h"

#define FP_SHIFT 4
#define FP_ONE (1 << FP_SHIFT)
#define TO_FP(value) ((fx)((value) << FP_SHIFT))
#define FROM_FP(value) ((s16)((value) >> FP_SHIFT))

typedef enum {
    PLAYER_STATE_IDLE = 0,
    PLAYER_STATE_MOVE = 1,
    PLAYER_STATE_WINDUP = 2,
    PLAYER_STATE_ACTIVE = 3,
    PLAYER_STATE_RECOVERY = 4
} PlayerState;

/* Presentation-only overrides chosen by the match flow. */
typedef enum {
    PLAYER_POSE_NONE = 0,
    PLAYER_POSE_TOSS = 1,
    PLAYER_POSE_CHEER = 2
} PlayerPose;

enum {
    PLAYER_WINDUP_FRAMES = 4,
    PLAYER_ACTIVE_FRAMES = 3,
    /* Standard paddle; paddle SPEED moves these two (ADR-020). */
    PLAYER_RECOVERY_FRAMES = 7,

    /* 12.4 units: 0.25, 0.1875, 1.5, 0.375 and 0.75 px/frame. */
    PLAYER_ACCEL_FP = 4,
    PLAYER_DIAGONAL_ACCEL_FP = 3,
    PLAYER_MAX_SPEED_FP = 24,
    PLAYER_FRICTION_FP = 6,
    /* Diagonal limits use the 181/256 normalization from the spec. */
    PLAYER_SWING_MAX_SPEED_FP = 12,
    /* CPU runs at 80% of human top speed. */
    PLAYER_CPU_MAX_SPEED_FP = 19,

    PLAYER_SEPARATION_X = 16,
    PLAYER_SEPARATION_Y = 12,

    PLAYER_VARIANT_MALE = 0,
    PLAYER_VARIANT_FEMALE = 1,

    PLAYER_IDLE_CEL_FRAMES = 20,
    PLAYER_RUN_CEL_FRAMES = 6
};

typedef struct {
    u8 active;
    u8 team;
    u8 logical_input_slot;
    u8 cpu_controlled;
    fx x_fp;
    fx y_fp;
    s16 vx_fp;
    s16 vy_fp;
    s16 max_speed_fp;
    u8 facing_left;
    u8 animation_frame;
    u8 animation_timer;
    u8 state;
    u8 state_frames_remaining;
    u8 contact_consumed;
    u8 frozen;
    u8 pose;
    u8 palette;
    u8 flash_timer;
    u8 shot_type;       /* ShotType latched when the swing starts */
    u8 variant;         /* PLAYER_VARIANT_*: ponytail accessory (ADR-014) */
    u8 paddle;          /* PADDLE_* stats (ADR-020) */
    u8 reserved;        /* keeps the size even on host and SNES */
} Player;

extern Player g_players[MAX_PLAYERS];

void players_initialize(void);
void players_update(const PlayerIntent intents[MAX_PLAYERS], u8 paused);
/* Doubles (ADR-018): nudge crowded teammates 1 px apart in y. */
void players_separate_teammates(void);
void player_place(Player *player, s16 x, s16 y);
u8 player_is_swinging(const Player *player);
s16 player_diagonal_limit(s16 limit);

#endif
