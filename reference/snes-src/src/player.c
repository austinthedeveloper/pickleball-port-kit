#include <string.h>
#include "ram_copy.h"
#include "asset_frames.h"
#include "court.h"
#include "paddle_stats.h"
#include "player.h"

Player g_players[MAX_PLAYERS];

/* limit * 181 / 256 for every limit the game uses (12.4 units, <= 31):
 * a table, because 816-tcc's multiply is a library call. Also read by
 * src/asm/player_step.asm. */
const u8 g_player_diagonal_limit[32] = {
    0, 0, 1, 2, 2, 3, 4, 4, 5, 6, 7, 7, 8, 9, 9, 10,
    11, 12, 12, 13, 14, 14, 15, 16, 16, 17, 18, 19, 19, 20, 21, 21
};

s16 player_diagonal_limit(s16 limit)
{
    if (limit >= 0 && limit < 32)
        return g_player_diagonal_limit[limit];
    return (s16)((limit * 181) >> 8);
}

u8 player_is_swinging(const Player *player)
{
    return player->state == PLAYER_STATE_WINDUP ||
        player->state == PLAYER_STATE_ACTIVE ||
        player->state == PLAYER_STATE_RECOVERY;
}

void player_place(Player *player, s16 x, s16 y)
{
    player->x_fp = TO_FP(x);
    player->y_fp = TO_FP(y);
    player->vx_fp = 0;
    player->vy_fp = 0;
    player->state = PLAYER_STATE_IDLE;
    player->state_frames_remaining = 0;
    player->contact_consumed = 1;
    player->animation_frame = 0;
    player->animation_timer = 0;
}

void players_initialize(void)
{
    u8 i;
    Player *player;

    for (i = 0; i < MAX_PLAYERS; ++i) {
        player = &g_players[i];
        player->active = 0;
        player->team = (i < 2) ? 0 : 1;
        player->logical_input_slot = i;
        player->cpu_controlled = (i == 2);
        player->max_speed_fp = player->cpu_controlled ?
            PLAYER_CPU_MAX_SPEED_FP : PLAYER_MAX_SPEED_FP;
        player->facing_left = player->team;
        player->frozen = 0;
        player->pose = PLAYER_POSE_NONE;
        player->palette = player->team;
        player->flash_timer = 0;
        player->shot_type = SHOT_STANDARD;
        player->variant = PLAYER_VARIANT_MALE;
        player->paddle = PADDLE_STANDARD;
        player->reserved = 0;
        player_place(player, 0, 0);
    }

    g_players[0].active = 1;
    player_place(&g_players[0], PLAYER_SPAWN_X, PLAYER_SPAWN_Y);
}

#ifdef HOST_TEST
/* The host tests run this C player_step; the SNES runs the same step in
 * src/asm/player_step.asm (the doubles frame budget, M4-UI-03/04). A change
 * here goes in both; the golden trace compares them. */

/* Static scratch copy: one long access per field instead of pointer
 * dereferences, which 816-tcc compiles very expensively. */
static Player s_p;

#define APPROACH_ZERO(v) \
    ((v) > PLAYER_FRICTION_FP ? (v) - PLAYER_FRICTION_FP : \
     (v) < -PLAYER_FRICTION_FP ? (v) + PLAYER_FRICTION_FP : 0)

static void player_step(const PlayerIntent *intent)
{
    s16 accel;
    s16 limit;
    s16 move_x;
    s16 move_y;
    u8 hit;
    u8 was_moving;
    u8 moving;
    u8 cel_frames;
    fx next;

    if (s_p.flash_timer)
        --s_p.flash_timer;

    move_x = intent->move_x;
    move_y = intent->move_y;
    hit = intent->hit_pressed;
    if (s_p.frozen) {
        move_x = 0;
        move_y = 0;
        hit = 0;
    }
    was_moving = s_p.state == PLAYER_STATE_MOVE;

    if (s_p.state >= PLAYER_STATE_WINDUP) {
        if (--s_p.state_frames_remaining == 0) {
            if (s_p.state == PLAYER_STATE_WINDUP) {
                s_p.state = PLAYER_STATE_ACTIVE;
                s_p.state_frames_remaining = PLAYER_ACTIVE_FRAMES;
            } else if (s_p.state == PLAYER_STATE_ACTIVE) {
                s_p.state = PLAYER_STATE_RECOVERY;
                s_p.state_frames_remaining = g_paddle_recovery[s_p.paddle];
            } else {
                s_p.state = PLAYER_STATE_IDLE;
            }
        }
    } else if (hit) {
        s_p.state = PLAYER_STATE_WINDUP;
        s_p.state_frames_remaining = PLAYER_WINDUP_FRAMES;
        s_p.contact_consumed = 0;
        s_p.shot_type = intent->shot;
    } else {
        s_p.state = (move_x || move_y) ? PLAYER_STATE_MOVE : PLAYER_STATE_IDLE;
    }

    limit = s_p.state >= PLAYER_STATE_WINDUP ?
        g_paddle_swing_limit[s_p.paddle] : s_p.max_speed_fp;
    accel = PLAYER_ACCEL_FP;
    if (move_x && move_y) {
        accel = PLAYER_DIAGONAL_ACCEL_FP;
        limit = g_player_diagonal_limit[limit & 31];
    }

    if (move_x > 0)
        s_p.vx_fp += accel;
    else if (move_x < 0)
        s_p.vx_fp -= accel;
    else
        s_p.vx_fp = APPROACH_ZERO(s_p.vx_fp);
    if (move_y > 0)
        s_p.vy_fp += accel;
    else if (move_y < 0)
        s_p.vy_fp -= accel;
    else
        s_p.vy_fp = APPROACH_ZERO(s_p.vy_fp);

    if (s_p.vx_fp > limit)
        s_p.vx_fp = limit;
    else if (s_p.vx_fp < -limit)
        s_p.vx_fp = -limit;
    if (s_p.vy_fp > limit)
        s_p.vy_fp = limit;
    else if (s_p.vy_fp < -limit)
        s_p.vy_fp = -limit;

    /* court_clamp_x_fp/court_clamp_y_fp, inlined (hot path). */
    next = s_p.x_fp + s_p.vx_fp;
    if (s_p.team == 0) {
        if (next < TO_FP(PLAYER_CLAMP_MIN_X)) {
            next = TO_FP(PLAYER_CLAMP_MIN_X);
            s_p.vx_fp = 0;
        } else if (next > TO_FP(PLAYER_CLAMP_MAX_X)) {
            next = TO_FP(PLAYER_CLAMP_MAX_X);
            s_p.vx_fp = 0;
        }
    } else {
        if (next < TO_FP(PLAYER_RIGHT_CLAMP_MIN_X)) {
            next = TO_FP(PLAYER_RIGHT_CLAMP_MIN_X);
            s_p.vx_fp = 0;
        } else if (next > TO_FP(PLAYER_RIGHT_CLAMP_MAX_X)) {
            next = TO_FP(PLAYER_RIGHT_CLAMP_MAX_X);
            s_p.vx_fp = 0;
        }
    }
    s_p.x_fp = next;
    next = s_p.y_fp + s_p.vy_fp;
    if (next < TO_FP(PLAYER_CLAMP_MIN_Y)) {
        next = TO_FP(PLAYER_CLAMP_MIN_Y);
        s_p.vy_fp = 0;
    } else if (next > TO_FP(PLAYER_CLAMP_MAX_Y)) {
        next = TO_FP(PLAYER_CLAMP_MAX_Y);
        s_p.vy_fp = 0;
    }
    s_p.y_fp = next;

    /* Players always square up to the net; flips come from OAM. */
    s_p.facing_left = s_p.team;

    moving = s_p.state == PLAYER_STATE_MOVE;
    if (moving != was_moving) {
        s_p.animation_frame = 0;
        s_p.animation_timer = 0;
    }
    cel_frames = moving ? PLAYER_RUN_CEL_FRAMES : PLAYER_IDLE_CEL_FRAMES;
    if (++s_p.animation_timer >= cel_frames) {
        s_p.animation_timer = 0;
        if (++s_p.animation_frame >=
                (moving ? ANIM_RUN_CELS : ANIM_IDLE_CELS))
            s_p.animation_frame = 0;
    }
}

void players_update(const PlayerIntent intents[MAX_PLAYERS], u8 paused)
{
    u8 i;
    Player *player;
    const PlayerIntent *intent;

    if (paused)
        return;

    player = g_players;
    intent = intents;
    for (i = 0; i < MAX_PLAYERS; ++i, ++player, ++intent) {
        if (!player->active)
            continue;
        RAM_COPY(&s_p, player, sizeof(Player));
        /* Walk the intent pointer (816-tcc multiplies for intents[n]);
         * index only if a slot was remapped to another input. */
        player_step(s_p.logical_input_slot == i ? intent :
            &intents[s_p.logical_input_slot]);
        RAM_COPY(player, &s_p, sizeof(Player));
    }
}
#else
/* Inputs and working variables of src/asm/player_step.asm (all words). */
u16 ps_player;
u16 ps_intent;
s16 ps_mx;
s16 ps_my;
u16 ps_hit;
u16 ps_state;
u16 ps_was;
s16 ps_limit;
s16 ps_accel;
s16 ps_v;
extern void player_step(void);

/* Constant slots: 816-tcc reads g_players[n] fields with one long access
 * each; a remapped input (another slot's intent) is indexed. */
#define STEP_SLOT(slot) \
    do { \
        if (g_players[slot].active) { \
            ps_player = (u16)&g_players[slot]; \
            ps_intent = (u16)(g_players[slot].logical_input_slot == (slot) ? \
                &intents[slot] : \
                &intents[g_players[slot].logical_input_slot]); \
            player_step(); \
        } \
    } while (0)

void players_update(const PlayerIntent intents[MAX_PLAYERS], u8 paused)
{
    if (paused)
        return;
    STEP_SLOT(0);
    STEP_SLOT(1);
    STEP_SLOT(2);
    STEP_SLOT(3);
}
#endif

/* Pushes slots a and b (a < b) apart in y by 1 px each when they overlap;
 * the upper one moves up (a, on a tie). Clamps keep both on court.
 * Constant slots, as in STEP_SLOT: no pointer dereferences. */
#define SEPARATE_PAIR(a, b) \
    do { \
        if (g_players[a].active && g_players[b].active) { \
            dx = g_players[a].x_fp - g_players[b].x_fp; \
            if (dx < 0) \
                dx = -dx; \
            dy = g_players[a].y_fp - g_players[b].y_fp; \
            if (dx < TO_FP(PLAYER_SEPARATION_X) && \
                    dy < TO_FP(PLAYER_SEPARATION_Y) && \
                    dy > -TO_FP(PLAYER_SEPARATION_Y)) { \
                step = dy <= 0 ? -FP_ONE : FP_ONE; \
                g_players[a].y_fp = \
                    court_clamp_y_fp(g_players[a].y_fp + step); \
                g_players[b].y_fp = \
                    court_clamp_y_fp(g_players[b].y_fp - step); \
            } \
        } \
    } while (0)

void players_separate_teammates(void)
{
    fx dx;
    fx dy;
    fx step;

    SEPARATE_PAIR(0, 1);
    SEPARATE_PAIR(2, 3);
}
