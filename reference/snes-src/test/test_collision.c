#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "collision.h"
#include "paddle_stats.h"

static Player players[MAX_PLAYERS];
static Ball ball;
static PlayerIntent intents[MAX_PLAYERS];

static fx absolute_fp(fx value)
{
    return value < 0 ? -value : value;
}

static void assert_lands_near(s16 expected_x, s16 expected_y);

static void reset_fixture(void)
{
    memset(players, 0, sizeof(players));
    memset(&ball, 0, sizeof(ball));
    memset(intents, 0, sizeof(intents));
    players[0].paddle = PADDLE_STANDARD;
    players[0].active = 1;
    players[0].x_fp = TO_FP(64);
    players[0].y_fp = TO_FP(112);
    ball.active = 1;
    ball.rally_state = BALL_RALLY_LIVE;
    ball.x_fp = players[0].x_fp;
    ball.y_fp = players[0].y_fp;
    ball.z_fp = TO_FP(10);
    ball.last_hitter = BALL_NO_HITTER;
}

static void test_reach_boundaries_are_inclusive(void)
{
    reset_fixture();
    ball.x_fp += TO_FP(HIT_REACH_X);
    ball.y_fp -= TO_FP(HIT_REACH_Y);
    ball.z_fp = TO_FP(HIT_REACH_Z);
    assert(collision_ball_in_player_reach(&players[0], &ball) == 1);

    ball.x_fp += 1;
    assert(collision_ball_in_player_reach(&players[0], &ball) == 0);
    ball.x_fp -= 1;
    ball.y_fp -= 1;
    assert(collision_ball_in_player_reach(&players[0], &ball) == 0);
    ball.y_fp += 1;
    ball.z_fp += 1;
    assert(collision_ball_in_player_reach(&players[0], &ball) == 0);
}

static void test_windup_cannot_contact(void)
{
    reset_fixture();
    players[0].state = PLAYER_STATE_WINDUP;
    players[0].state_frames_remaining = PLAYER_WINDUP_FRAMES;
    assert(collision_resolve_player_hits(&ball, players, intents,
        MAX_PLAYERS) == 0);
    assert(players[0].contact_consumed == 0);
    assert(ball.last_hitter == BALL_NO_HITTER);
}

static void test_active_overlap_contacts_once(void)
{
    u8 frame;
    u8 contacts = 0;

    reset_fixture();
    players[0].state = PLAYER_STATE_ACTIVE;
    players[0].state_frames_remaining = PLAYER_ACTIVE_FRAMES;
    for (frame = 0; frame < PLAYER_ACTIVE_FRAMES; ++frame)
        contacts += collision_resolve_player_hits(&ball, players, intents,
            MAX_PLAYERS);

    assert(contacts == 1);
    assert(players[0].contact_consumed == 1);
    assert(ball.last_hitter == 0);
    assert(ball.bounce_count == 0);
    assert(ball.vx_fp > 0);
    assert(ball.vz_fp > 0);
    assert_lands_near(HIT_TARGET_NEUTRAL_RIGHT, HIT_TARGET_LANE_CENTER);
}

static void test_team_direction_and_live_ball_requirement(void)
{
    reset_fixture();
    players[0].team = 1;
    players[0].state = PLAYER_STATE_ACTIVE;
    assert(collision_resolve_player_hits(&ball, players, intents,
        MAX_PLAYERS) == 1);
    assert(ball.vx_fp < 0);

    reset_fixture();
    players[0].state = PLAYER_STATE_ACTIVE;
    ball.rally_state = BALL_RALLY_INACTIVE;
    assert(collision_resolve_player_hits(&ball, players, intents,
        MAX_PLAYERS) == 0);
}

/* KNOWN_ISSUES #19: a teammate's active swing can't re-hit the team's
 * shot; an opponent's can. */
static void test_team_hits_once(void)
{
    reset_fixture();
    players[1] = players[0];
    players[1].state = PLAYER_STATE_ACTIVE;
    players[1].contact_consumed = 0;
    ball.last_hitter = 0;
    assert(collision_resolve_player_hits(&ball, players, intents,
        MAX_PLAYERS) == 0);
    assert(players[1].contact_consumed == 0);

    players[2] = players[1];
    players[2].team = 1;
    players[1].active = 0;
    players[1].state = PLAYER_STATE_IDLE;
    assert(collision_resolve_player_hits(&ball, players, intents,
        MAX_PLAYERS) == 3);
    assert(ball.last_hitter == 2);
}

static void assert_lands_near(s16 expected_x, s16 expected_y)
{
    u8 events = BALL_EVENT_NONE;
    u8 frame;

    for (frame = 0; frame < 60; ++frame) {
        events = ball_simulate_step(&ball);
        if (events & BALL_EVENT_BOUNCE)
            break;
    }
    assert(events & BALL_EVENT_BOUNCE);
    /* Integer velocity truncation leaves at most ~2 px of landing error. */
    assert(absolute_fp(ball.x_fp - TO_FP(expected_x)) < TO_FP(3));
    assert(absolute_fp(ball.y_fp - TO_FP(expected_y)) < TO_FP(3));
    assert((events & BALL_EVENT_OUT) == 0);
}

static void test_directional_target_lanes(void)
{
    reset_fixture();
    players[0].state = PLAYER_STATE_ACTIVE;
    assert(collision_resolve_player_hits(&ball, players, intents,
        MAX_PLAYERS) == 1);
    assert_lands_near(HIT_TARGET_NEUTRAL_RIGHT, HIT_TARGET_LANE_CENTER);

    reset_fixture();
    players[0].state = PLAYER_STATE_ACTIVE;
    intents[0].aim_y = -1;
    collision_resolve_player_hits(&ball, players, intents, MAX_PLAYERS);
    assert_lands_near(HIT_TARGET_NEUTRAL_RIGHT, HIT_TARGET_LANE_TOP);

    reset_fixture();
    players[0].state = PLAYER_STATE_ACTIVE;
    intents[0].aim_y = 1;
    collision_resolve_player_hits(&ball, players, intents, MAX_PLAYERS);
    assert_lands_near(HIT_TARGET_NEUTRAL_RIGHT, HIT_TARGET_LANE_BOTTOM);

    reset_fixture();
    players[0].state = PLAYER_STATE_ACTIVE;
    intents[0].aim_x = 1;
    collision_resolve_player_hits(&ball, players, intents, MAX_PLAYERS);
    assert_lands_near(HIT_TARGET_DEEP_RIGHT, HIT_TARGET_LANE_CENTER);

    reset_fixture();
    players[0].state = PLAYER_STATE_ACTIVE;
    intents[0].aim_x = -1;
    collision_resolve_player_hits(&ball, players, intents, MAX_PLAYERS);
    assert_lands_near(HIT_TARGET_SHORT_RIGHT, HIT_TARGET_LANE_CENTER);
}

/* Hits the fixture ball with a shot type and aim; returns flight frames to
 * the first bounce and the highest z reached. */
static u8 s_paddle = PADDLE_STANDARD;
static s16 s_offset_y;

static u8 fly_shot(u8 team, u8 shot, s16 aim_x, fx *apex)
{
    u8 frames = 0;

    reset_fixture();
    players[0].paddle = s_paddle;
    ball.y_fp = players[0].y_fp + TO_FP(s_offset_y);
    /* Mid-court, where lobs and drives differ most from a standard shot. */
    players[0].x_fp = TO_FP(team ? 146 : 110);
    ball.x_fp = players[0].x_fp;
    players[0].team = team;
    players[0].shot_type = shot;
    players[0].state = PLAYER_STATE_ACTIVE;
    intents[0].aim_x = aim_x;
    assert(collision_resolve_player_hits(&ball, players, intents,
        MAX_PLAYERS) == 1);
    *apex = 0;
    while (!(ball_simulate_step(&ball) & BALL_EVENT_BOUNCE)) {
        if (ball.z_fp > *apex)
            *apex = ball.z_fp;
        ++frames;
        assert(frames < 80);
    }
    return frames;
}

/* ADR-019 shot types from a sweet-spot contact. */
static void test_shot_types(void)
{
    fx standard_apex;
    fx apex;
    u8 standard;
    u8 frames;

    standard = fly_shot(0, SHOT_STANDARD, 1, &standard_apex);
    assert(standard + 1 < HIT_FLIGHT_MAX_FRAMES);
    assert(absolute_fp(ball.x_fp - TO_FP(HIT_TARGET_DEEP_RIGHT)) < TO_FP(3));

    /* Drive: same deep target, sooner and flatter. */
    frames = fly_shot(0, SHOT_DRIVE, 1, &apex);
    assert(frames < standard && apex < standard_apex);
    assert(absolute_fp(ball.x_fp - TO_FP(HIT_TARGET_DEEP_RIGHT)) < TO_FP(3));

    /* Lob: deep and well above the standard arc. */
    frames = fly_shot(0, SHOT_SOFT, 1, &apex);
    assert(frames + 1 >= HIT_LOB_MIN_FRAMES);
    assert(apex > standard_apex + TO_FP(10));
    assert(absolute_fp(ball.x_fp - TO_FP(HIT_TARGET_DEEP_RIGHT)) < TO_FP(3));

    /* Dink: aimed away from the net, lands inside the opponent's kitchen. */
    fly_shot(0, SHOT_SOFT, -1, &apex);
    assert(ball.x_fp > TO_FP(COURT_NET_X));
    assert(ball.x_fp < TO_FP(COURT_KITCHEN_RIGHT_X));

    /* The right team mirrors: a dink lands in the left kitchen. */
    fly_shot(1, SHOT_SOFT, 1, &apex);
    assert(ball.x_fp < TO_FP(COURT_NET_X));
    assert(ball.x_fp > TO_FP(COURT_KITCHEN_LEFT_X));
}

/* ADR-020: POWER shortens flights, CONTROL narrows the stretch spray, and
 * the standard paddle is exactly the ADR-019 tunables. */
static void test_paddle_stats(void)
{
    fx apex;
    u8 standard;
    u8 frames;
    fx standard_y;

    assert(g_paddle_power_mul[PADDLE_STANDARD] == 64);
    assert(g_paddle_control_mul[PADDLE_STANDARD] == 64);
    assert(g_paddle_swing_limit[PADDLE_STANDARD] ==
        PLAYER_SWING_MAX_SPEED_FP);
    assert(g_paddle_recovery[PADDLE_STANDARD] == PLAYER_RECOVERY_FRAMES);

    standard = fly_shot(0, SHOT_STANDARD, 1, &apex);
    s_paddle = PADDLE_RED;
    frames = fly_shot(0, SHOT_STANDARD, 1, &apex);
    assert(frames < standard);
    assert(absolute_fp(ball.x_fp - TO_FP(HIT_TARGET_DEEP_RIGHT)) < TO_FP(3));
    s_paddle = PADDLE_WOOD;
    frames = fly_shot(0, SHOT_STANDARD, 1, &apex);
    assert(frames > standard);

    /* Stretched drive below the player sprays toward the bottom. */
    s_offset_y = HIT_SWEET_Y + 4;
    s_paddle = PADDLE_STANDARD;
    fly_shot(0, SHOT_DRIVE, 0, &apex);
    standard_y = ball.y_fp;
    s_paddle = PADDLE_WOOD;
    fly_shot(0, SHOT_DRIVE, 0, &apex);
    assert(ball.y_fp < standard_y);
    s_paddle = PADDLE_RED;
    fly_shot(0, SHOT_DRIVE, 0, &apex);
    assert(ball.y_fp > standard_y);
    s_offset_y = 0;
    s_paddle = PADDLE_STANDARD;
}

static void test_new_swing_restores_contact(void)
{
    PlayerIntent intents[MAX_PLAYERS];

    memset(intents, 0, sizeof(intents));
    players_initialize();
    g_players[0].contact_consumed = 1;
    intents[0].hit_pressed = 1;
    players_update(intents, 0);
    assert(g_players[0].state == PLAYER_STATE_WINDUP);
    assert(g_players[0].contact_consumed == 0);
}

int main(void)
{
    test_reach_boundaries_are_inclusive();
    test_windup_cannot_contact();
    test_active_overlap_contacts_once();
    test_team_direction_and_live_ball_requirement();
    test_team_hits_once();
    test_directional_target_lanes();
    test_shot_types();
    test_paddle_stats();
    test_new_swing_restores_contact();
    puts("collision host checks passed");
    return 0;
}
