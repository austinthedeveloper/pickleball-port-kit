#include "audio_events.h"
#include "ball.h"
#include "collision.h"
#include "court.h"
#include "events.h"
#include "game.h"
#include "match.h"
#include "player.h"
#include "practice.h"
#include "save.h"

PracticeState g_practice;
PracticeEdit g_practice_edit;

static const u8 s_counts[PRACTICE_ROWS] = {
    PRACTICE_SHOTS, PRACTICE_TARGETS, PRACTICE_RATES, PRACTICE_ZONES
};
/* Defaults: MIX to RANDOM targets at a NORMAL rate, returns anywhere in. */
static const u8 s_defaults[PRACTICE_ROWS] = {
    PRACTICE_SHOT_MIX, PRACTICE_TARGET_RANDOM, PRACTICE_RATE_NORMAL,
    PRACTICE_ZONE_ANY
};

const s16 g_practice_zone_rects[PRACTICE_ZONES][4] = {
    { COURT_NET_X, COURT_SIDELINE_TOP, COURT_BASELINE_RIGHT,
      COURT_SIDELINE_BOTTOM },
    { COURT_NET_X, COURT_SIDELINE_TOP, COURT_KITCHEN_RIGHT_X,
      COURT_SIDELINE_BOTTOM },
    { COURT_BASELINE_RIGHT - PRACTICE_ZONE_DEEP_DEPTH, COURT_SIDELINE_TOP,
      COURT_BASELINE_RIGHT, COURT_SIDELINE_BOTTOM },
    { COURT_NET_X, COURT_SIDELINE_TOP, COURT_BASELINE_RIGHT,
      COURT_SIDELINE_TOP + PRACTICE_ZONE_LINE_WIDTH },
    { COURT_NET_X, COURT_SIDELINE_BOTTOM - PRACTICE_ZONE_LINE_WIDTH,
      COURT_BASELINE_RIGHT, COURT_SIDELINE_BOTTOM }
};

u8 practice_shot(u8 saved)
{
    return saved < PRACTICE_SHOTS ? saved : PRACTICE_SHOT_MIX;
}

u8 practice_target(u8 saved)
{
    return saved < PRACTICE_TARGETS ? saved : PRACTICE_TARGET_RANDOM;
}

u8 practice_rate(u8 saved)
{
    return saved < PRACTICE_RATES ? saved : PRACTICE_RATE_NORMAL;
}

u8 practice_zone(u8 saved)
{
    return saved < PRACTICE_ZONES ? saved : PRACTICE_ZONE_ANY;
}

const char *practice_shot_name(u8 shot)
{
    static const char *const names[PRACTICE_SHOTS] = {
        "DRIVE", "LOB", "DINK", "MIX"
    };
    return names[practice_shot(shot)];
}

const char *practice_target_name(u8 target)
{
    static const char *const names[PRACTICE_TARGETS] = {
        "KITCHEN", "DEEP", "FOREHAND", "BACKHAND", "AT YOU", "RANDOM"
    };
    return names[practice_target(target)];
}

const char *practice_rate_name(u8 rate)
{
    static const char *const names[PRACTICE_RATES] = {
        "SLOW", "NORMAL", "FAST"
    };
    return names[practice_rate(rate)];
}

const char *practice_zone_name(u8 zone)
{
    static const char *const names[PRACTICE_ZONES] = {
        "ANY", "KITCHEN", "DEEP", "LEFT LINE", "RIGHT LINE"
    };
    return names[practice_zone(zone)];
}

u8 practice_in_zone(u8 zone, s16 x, s16 y)
{
    const s16 *rect = g_practice_zone_rects[practice_zone(zone)];

    return x >= rect[0] && y >= rect[1] && x <= rect[2] && y <= rect[3];
}

u16 practice_rate_frames(u8 rate)
{
    static const u16 frames[PRACTICE_RATES] = { 120, 75, 40 };
    return frames[practice_rate(rate)];
}

static void practice_plan(void);

static void practice_show_score(void)
{
    /* The score panels read P1 <streak> and BEST <best> (hud_scene.c). */
    g_game_state.team_score[0] = g_practice.streak;
    g_game_state.team_score[1] = g_practice.best;
}

u16 practice_saved_best(u8 zone)
{
    zone = practice_zone(zone);
    return zone == PRACTICE_ZONE_ANY ? g_save.records.practice_best :
        g_save.records.practice_zone_best[zone - 1];
}

void practice_begin(void)
{
    u8 zone = practice_zone(g_save.settings.practice[PRACTICE_ROW_ZONE]);
    u16 best = practice_saved_best(zone);

    g_practice.shot = practice_shot(g_save.settings.practice[PRACTICE_ROW_SHOT]);
    g_practice.target =
        practice_target(g_save.settings.practice[PRACTICE_ROW_TARGET]);
    g_practice.rate = practice_rate(g_save.settings.practice[PRACTICE_ROW_RATE]);
    g_practice.zone = zone;
    g_practice.zone_flash = 0;
    g_practice.state = PRACTICE_WAIT;
    g_practice.timer = PRACTICE_FIRST_FEED_FRAMES;
    g_practice.streak = 0;
    g_practice.best = best > PRACTICE_STREAK_MAX ? PRACTICE_STREAK_MAX :
        (u8)best;
    g_practice.feeds = 0;
    g_practice.rng = 0x5a;
    g_practice.last_shot = SHOT_STANDARD;
    g_practice.pose = PRACTICE_POSE_CENTER;
    g_practice.turn_timer = 0;
    g_practice.kick = 0;
    g_ball.active = 0;
    g_ball.rally_state = BALL_RALLY_INACTIVE;
    game_set_phase(GAME_PHASE_LIVE);
    practice_plan();
    practice_show_score();
}

/* 8-bit LCG: the MIX and RANDOM pattern, the same every session. */
static u8 practice_next(void)
{
    g_practice.rng = (u8)(g_practice.rng * 5 + 3);
    return g_practice.rng >> 4;
}

static s16 clamp_s16(s16 value, s16 low, s16 high)
{
    return value < low ? low : value > high ? high : value;
}

/* Flight frames for a feed, by the players' shot paces (ADR-019). */
static u8 practice_flight(u8 shot_type, u8 dink, s16 distance_px)
{
    s16 distance = TO_FP(distance_px);
    s16 frames;

    if (shot_type == SHOT_DRIVE)
        frames = clamp_s16(distance / HIT_PACE_DRIVE_FP, HIT_DRIVE_MIN_FRAMES,
            HIT_DRIVE_MAX_FRAMES);
    else if (shot_type == SHOT_SOFT && !dink)
        frames = clamp_s16(distance / HIT_PACE_LOB_FP, HIT_LOB_MIN_FRAMES,
            HIT_LOB_MAX_FRAMES);
    else
        frames = clamp_s16(distance / (dink ? HIT_PACE_DINK_FP :
            HIT_PACE_NEUTRAL_FP), HIT_FLIGHT_MIN_FRAMES, HIT_FLIGHT_MAX_FRAMES);
    return (u8)frames;
}

/* Where the planned feed lands (next_tx, next_ty), and the aim. AT YOU
 * reads where P1 stands, so it is aimed again each frame of the wait. */
static void practice_aim(void)
{
    static const s16 lanes[3] = {
        HIT_TARGET_LANE_TOP, HIT_TARGET_LANE_CENTER, HIT_TARGET_LANE_BOTTOM
    };
    const Player *p1 = &g_players[0];
    s16 tx;
    s16 ty = lanes[g_practice.feeds % 3];

    switch (g_practice.next_target) {
    case PRACTICE_TARGET_DEEP:
        tx = HIT_TARGET_DEEP_LEFT;
        break;
    case PRACTICE_TARGET_FOREHAND:     /* facing the net, right hand is +y */
        tx = HIT_TARGET_NEUTRAL_LEFT;
        ty = HIT_TARGET_LANE_BOTTOM;
        break;
    case PRACTICE_TARGET_BACKHAND:
        tx = HIT_TARGET_NEUTRAL_LEFT;
        ty = HIT_TARGET_LANE_TOP;
        break;
    case PRACTICE_TARGET_AT_YOU:
        tx = clamp_s16(FROM_FP(p1->x_fp), COURT_BASELINE_LEFT + 8,
            HIT_TARGET_DINK_LEFT);
        ty = clamp_s16(FROM_FP(p1->y_fp), HIT_TARGET_LANE_TOP,
            HIT_TARGET_LANE_BOTTOM);
        break;
    default:                            /* the kitchen */
        tx = HIT_TARGET_DINK_LEFT;
        break;
    }
    if (g_practice.next_dink)
        tx = HIT_TARGET_DINK_LEFT;      /* a dink always lands short */
    g_practice.next_tx = tx;
    g_practice.next_ty = ty;
    g_practice.aim = ty < PRACTICE_MACHINE_Y - PRACTICE_AIM_SPREAD ?
        PRACTICE_POSE_UP : ty > PRACTICE_MACHINE_Y + PRACTICE_AIM_SPREAD ?
        PRACTICE_POSE_DOWN : PRACTICE_POSE_CENTER;
}

/* Picks the next feed as the wait starts, so the machine turns toward it
 * before it leaves. MIX and RANDOM draw in the same order as before. */
static void practice_plan(void)
{
    u8 shot = g_practice.shot;
    u8 target = g_practice.target;

    if (shot == PRACTICE_SHOT_MIX)
        shot = practice_next() & 3;     /* DRIVE, LOB, DINK, or standard */
    if (target == PRACTICE_TARGET_RANDOM)
        target = practice_next() % PRACTICE_TARGET_RANDOM;
    g_practice.next_dink = shot == PRACTICE_SHOT_DINK;
    g_practice.next_shot = shot == PRACTICE_SHOT_DRIVE ? SHOT_DRIVE :
        (shot == PRACTICE_SHOT_LOB || g_practice.next_dink) ? SHOT_SOFT :
        SHOT_STANDARD;
    g_practice.next_target = target;
    practice_aim();
}

/* The nozzle turns one pose at a time (up passes the centre to go down). */
static void practice_turn(void)
{
    if (g_practice.kick)
        --g_practice.kick;
    if (g_practice.zone_flash)
        --g_practice.zone_flash;
    if (g_practice.pose == g_practice.aim) {
        g_practice.turn_timer = 0;
        return;
    }
    if (++g_practice.turn_timer < PRACTICE_TURN_FRAMES)
        return;
    g_practice.turn_timer = 0;
    if (g_practice.pose < g_practice.aim)
        ++g_practice.pose;
    else
        --g_practice.pose;
}

static void practice_feed(void)
{
    /* The muzzle of each pose (render.c), on the ground under the nozzle. */
    static const s16 muzzle_y[3] = { -4, 0, 3 };
    u8 shot_type = g_practice.next_shot;
    s16 tx = g_practice.next_tx;
    s16 y = PRACTICE_MACHINE_Y + muzzle_y[g_practice.aim];

    /* From the low nozzle a flat drive cannot clear the net and still land
     * in the kitchen: a "drive" there is a firm standard shot. */
    if (shot_type == SHOT_DRIVE && tx == HIT_TARGET_DINK_LEFT)
        shot_type = SHOT_STANDARD;

    g_ball.active = 1;
    g_ball.x_fp = TO_FP(PRACTICE_MACHINE_X);
    g_ball.y_fp = TO_FP(y);
    g_ball.z_fp = TO_FP(PRACTICE_MACHINE_Z);
    g_ball.rally_state = BALL_RALLY_LIVE;
    g_ball.last_hitter = 2;             /* the machine plays the right team */
    g_ball.bounce_count = 0;
    ball_launch(&g_ball, tx, g_practice.next_ty,
        practice_flight(shot_type, g_practice.next_dink,
            PRACTICE_MACHINE_X - tx));
    ++g_game_state.shot_serial;
    events_emit(EVENT_HIT, PRACTICE_MACHINE_X, y, 2 | (shot_type << 4));
    g_practice.last_shot = shot_type;
    g_practice.state = PRACTICE_FEED;
    g_practice.timer = 0;
    g_practice.kick = PRACTICE_KICK_FRAMES;
    ++g_practice.feeds;
}

/* A feed is over: a return that landed in (good) adds to the streak. */
static void practice_end_feed(u8 good)
{
    if (!good)
        g_practice.streak = 0;
    else if (g_practice.streak < PRACTICE_STREAK_MAX)
        ++g_practice.streak;
    if (g_practice.streak > g_practice.best)
        g_practice.best = g_practice.streak;
    /* The crowd notices every fifth return in a row (ADR-029). */
    if (good && g_practice.streak % 5 == 0)
        audio_crowd(g_practice.streak >= 20 ? 13 : 9);
    g_ball.active = 0;
    g_ball.rally_state = BALL_RALLY_INACTIVE;
    g_practice.state = PRACTICE_WAIT;
    g_practice.timer = practice_rate_frames(g_practice.rate);
    practice_plan();
    practice_show_score();
}

void practice_update(const PlayerIntent intents[MAX_PLAYERS])
{
    u8 hit;
    u8 events;
    u8 good;

    practice_turn();
    if (g_practice.state == PRACTICE_WAIT) {
        /* AT YOU follows P1 through the wait; then the machine finishes
         * turning before it feeds, so it always points where the ball goes. */
        if (g_practice.timer) {
            --g_practice.timer;
            if (g_practice.next_target == PRACTICE_TARGET_AT_YOU)
                practice_aim();
        } else if (g_practice.pose == g_practice.aim) {
            practice_feed();
        }
        return;
    }
    if (++g_practice.timer > PRACTICE_FEED_TIMEOUT_FRAMES) {
        practice_end_feed(0);
        return;
    }
    hit = collision_resolve_player_hits(&g_ball, g_players, intents,
        MAX_PLAYERS);
    if (hit) {
        game_contact(hit - 1);
        g_practice.state = PRACTICE_RETURN;
    }
    events = game_step_ball();
    if (events & BALL_EVENT_NET_FAULT) {
        practice_end_feed(0);
        return;
    }
    if (!(events & BALL_EVENT_BOUNCE))
        return;
    /* Bounces sound like a match's (ADR-029). */
    events_emit(EVENT_BOUNCE, FROM_FP(g_ball.x_fp), FROM_FP(g_ball.y_fp),
        g_ball.bounce_count);
    if (g_practice.state == PRACTICE_RETURN) {
        /* The return's first bounce: in on the machine's side, and in the
         * zone if there is one, is good; the zone's corners blink. */
        good = !(events & BALL_EVENT_OUT) &&
            court_x_on_side(g_ball.x_fp, 1) &&
            practice_in_zone(g_practice.zone, FROM_FP(g_ball.x_fp),
                FROM_FP(g_ball.y_fp));
        if (good && g_practice.zone != PRACTICE_ZONE_ANY)
            g_practice.zone_flash = PRACTICE_ZONE_FLASH_FRAMES;
        practice_end_feed(good);
    } else if (g_ball.bounce_count >= 2) {
        practice_end_feed(0);           /* the feed bounced twice: missed */
    }
}

void practice_finish(void)
{
    u8 zone = g_practice.zone;

    if (g_practice.best <= practice_saved_best(zone))
        return;
    if (zone == PRACTICE_ZONE_ANY)
        g_save.records.practice_best = g_practice.best;
    else
        g_save.records.practice_zone_best[zone - 1] = g_practice.best;
    save_write();
}

void practice_edit_begin(u8 values[PRACTICE_ROWS])
{
    u8 i;

    for (i = 0; i < PRACTICE_ROWS; ++i) {
        if (values[i] >= s_counts[i])
            values[i] = s_defaults[i];
        g_practice_edit.original[i] = values[i];
    }
    g_practice_edit.row = PRACTICE_ROW_SHOT;
}

u8 practice_edit_changed(const u8 values[PRACTICE_ROWS])
{
    u8 i;

    for (i = 0; i < PRACTICE_ROWS; ++i)
        if (values[i] != g_practice_edit.original[i])
            return 1;
    return 0;
}

u8 practice_edit_input(u8 values[PRACTICE_ROWS], u16 pressed)
{
    u8 row = g_practice_edit.row;
    u8 count = s_counts[row];
    u8 i;

    if (pressed & PAD_Y) {
        for (i = 0; i < PRACTICE_ROWS; ++i)
            values[i] = g_practice_edit.original[i];
        return PRACTICE_EDIT_CANCEL;
    }
    if (pressed & (PAD_B | PAD_START))
        return PRACTICE_EDIT_DONE;
    if (pressed & PAD_UP)
        g_practice_edit.row = row ? row - 1 : PRACTICE_ROWS - 1;
    else if (pressed & PAD_DOWN)
        g_practice_edit.row = row == PRACTICE_ROWS - 1 ? 0 : row + 1;
    else if (pressed & PAD_LEFT)
        values[row] = values[row] ? values[row] - 1 : count - 1;
    else if (pressed & PAD_RIGHT)
        values[row] = values[row] + 1 >= count ? 0 : values[row] + 1;
    return PRACTICE_EDIT_STAY;
}
