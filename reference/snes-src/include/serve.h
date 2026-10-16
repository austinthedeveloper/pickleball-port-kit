#ifndef SERVE_H
#define SERVE_H

#include "ball.h"
#include "court.h"
#include "game.h"
#include "input.h"
#include "player.h"

enum {
    SERVE_TOSS_FRAMES = 18,
    SERVE_TOSS_POSE_FRAMES = 10,
    SERVE_TOSS_VZ_FP = 32,
    SERVE_HAND_OFFSET_X = 10,
    SERVE_HAND_Z = 14,
    SERVE_STANCE_OFFSET_Y = 22,
    /* Feet behind the baseline: the server as far back as the runoff
     * allows, the receiver and the server's partner a little less. A
     * player's body reaches toward the net past their feet, so less looks
     * like standing in the court. */
    SERVE_BASELINE_GAP = PLAYER_RUNOFF_BACK,
    SERVE_RECEIVER_GAP = 8,
    SERVE_PARTNER_KITCHEN_GAP = 8,
    SERVE_TARGET_LANE_SHIFT = 12,
    /* Targets for a left-team server; the right team mirrors them. */
    SERVE_TARGET_SHORT_RIGHT = COURT_KITCHEN_RIGHT_X + 14,
    SERVE_TARGET_NEUTRAL_RIGHT = COURT_KITCHEN_RIGHT_X + 36,
    SERVE_TARGET_DEEP_RIGHT = COURT_BASELINE_RIGHT - 16,
    SERVE_TARGET_SHORT_LEFT = COURT_MIRROR_X(SERVE_TARGET_SHORT_RIGHT),
    SERVE_TARGET_NEUTRAL_LEFT = COURT_MIRROR_X(SERVE_TARGET_NEUTRAL_RIGHT),
    SERVE_TARGET_DEEP_LEFT = COURT_MIRROR_X(SERVE_TARGET_DEEP_RIGHT),
    SERVE_FLIGHT_FRAMES = 40,

    /* The charged serve (ADR-044): holding a swing button runs a meter
     * from 0 up to SERVE_CHARGE_MAX and back down, a frame a step; the
     * release serves at that level. A tap (let go before the meter reaches
     * SERVE_CHARGE_DUD) is the classic serve. Once it has, a release below
     * SERVE_CHARGE_DUD is a dud into the net; from there up the flight
     * shortens a frame for every two levels, SERVE_FLIGHT_FRAMES down to
     * 27. */
    SERVE_CHARGE_MAX = 30,
    SERVE_CHARGE_DUD = 4,
    /* The serve without a meter (CPUs, KID): today's 40-frame flight. */
    SERVE_CHARGE_CLASSIC = SERVE_CHARGE_DUD,
    /* A dud lands just past the net, low and slow: it meets the net. */
    SERVE_DUD_PAST_NET = 6,
    SERVE_DUD_FRAMES = 30
};

typedef struct {
    u8 server_index;
    u8 receiver_index;
    u8 landing_pending;
    u8 requested;
    s16 aim_x;
    s16 aim_y;
    fx server_y_fp;
} ServeState;

extern ServeState g_serve_state;

/* The charged serve's meter (ADR-044); apart from ServeState, which the
 * golden trace captures at a fixed size. */
typedef struct {
    u8 charging;        /* the meter is running (the button is held) */
    u8 level;           /* 0 .. SERVE_CHARGE_MAX */
    u8 rising;
    u8 armed;           /* reached SERVE_CHARGE_DUD: no longer a tap */
    u8 power;           /* the level the serve goes at */
} ServeCharge;

extern ServeCharge g_serve_charge;

/* Nonzero when the current server serves with the meter: a human, not on
 * KID, outside the attract demo. */
u8 serve_charged(void);
/* Flight frames of a serve at a charge level (SERVE_CHARGE_DUD or more). */
u8 serve_flight_frames(u8 power);

void serve_initialize(void);
/* Places server/receiver for the serving team's current score parity. */
void serve_setup(u8 serving_team);
void serve_update(const PlayerIntent intents[MAX_PLAYERS], u8 paused);
u8 serve_validate_landing(fx x_fp, fx y_fp, u8 server_team,
    fx server_y_fp);
void serve_process_ball_events(u8 events);

#endif
