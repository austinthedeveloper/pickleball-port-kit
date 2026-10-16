#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "ball.h"
#include "court.h"
#include "player.h"

static void test_initial_state(void)
{
    ball_initialize();
    assert(g_ball.active == 1);
    assert(g_ball.x_fp == TO_FP(BALL_START_X));
    assert(g_ball.y_fp == TO_FP(BALL_START_Y));
    assert(g_ball.z_fp == TO_FP(BALL_START_Z));
    assert(g_ball.vz_fp == BALL_START_VZ_FP);
    assert(g_ball.last_hitter == BALL_NO_HITTER);
    assert(g_ball.bounce_count == 0);
    assert(g_ball.rally_state == BALL_RALLY_LIVE);
}

static void test_deterministic_flight(void)
{
    Ball first;
    Ball second;
    u16 frame;

    ball_initialize();
    first = g_ball;
    second = g_ball;
    first.vx_fp = 44;
    first.vy_fp = -19;
    second.vx_fp = 44;
    second.vy_fp = -19;

    for (frame = 0; frame < 240; ++frame) {
        assert(ball_simulate_step(&first) == ball_simulate_step(&second));
        assert(memcmp(&first, &second, sizeof(first)) == 0);
    }
}

static void test_position_and_gravity_order(void)
{
    Ball ball;

    memset(&ball, 0, sizeof(ball));
    ball.active = 1;
    ball.rally_state = BALL_RALLY_LIVE;
    ball.x_fp = TO_FP(10);
    ball.y_fp = TO_FP(20);
    ball.z_fp = TO_FP(3);
    ball.vx_fp = 4;
    ball.vy_fp = -2;
    ball.vz_fp = 8;

    assert(ball_simulate_step(&ball) == 0);
    assert(ball.x_fp == TO_FP(10) + 4);
    assert(ball.y_fp == TO_FP(20) - 2);
    assert(ball.z_fp == TO_FP(3) + 8);
    assert(ball.vz_fp == 8 + BALL_GRAVITY_FP);
}

static void test_single_bounce_event(void)
{
    Ball ball;

    memset(&ball, 0, sizeof(ball));
    ball.active = 1;
    ball.rally_state = BALL_RALLY_LIVE;
    ball.x_fp = TO_FP(COURT_NET_X - 16);
    ball.y_fp = TO_FP(COURT_CENTERLINE_Y);
    ball.z_fp = 2;
    ball.vx_fp = 100;
    ball.vy_fp = -100;
    ball.vz_fp = -64;

    assert(ball_simulate_step(&ball) == BALL_EVENT_BOUNCE);
    assert(ball.z_fp == 0);
    assert(ball.vx_fp == 92);
    assert(ball.vy_fp == -92);
    /* 64 * 141 / 256 = 35.25: 55% vertical retention. */
    assert(ball.vz_fp == 35);
    assert(ball.bounce_count == 1);

    assert(ball_simulate_step(&ball) == 0);
    assert(ball.bounce_count == 1);
}

static void test_swept_net_height_boundaries(void)
{
    fx height;
    fx net = TO_FP(COURT_NET_X);
    fx threshold = TO_FP(COURT_NET_HEIGHT);

    assert(ball_net_crossing_height(net - 256, threshold + 1,
        net + 256, threshold + 1, &height) == 1);
    assert(height == threshold + 1);
    assert(height >= threshold);

    assert(ball_net_crossing_height(net - 256, threshold - 1,
        net + 256, threshold - 1, &height) == 1);
    assert(height == threshold - 1);
    assert(height < threshold);

    assert(ball_net_crossing_height(net + 256, threshold + 1,
        net - 256, threshold + 1, &height) == 1);
    assert(height == threshold + 1);

    assert(ball_net_crossing_height(net - 512, threshold,
        net - 1, threshold, &height) == 0);
}

static void test_net_fault_event(void)
{
    Ball ball;

    memset(&ball, 0, sizeof(ball));
    ball.active = 1;
    ball.rally_state = BALL_RALLY_LIVE;
    ball.x_fp = TO_FP(COURT_NET_X) - 1;
    ball.z_fp = TO_FP(COURT_NET_HEIGHT) - 1;
    ball.vx_fp = 2;
    assert(ball_simulate_step(&ball) & BALL_EVENT_NET_FAULT);

    ball.x_fp = TO_FP(COURT_NET_X) - 1;
    ball.z_fp = TO_FP(COURT_NET_HEIGHT) + 1;
    ball.vx_fp = 2;
    ball.vz_fp = 0;
    assert((ball_simulate_step(&ball) & BALL_EVENT_NET_FAULT) == 0);
}

static u8 ground_event_at(fx x_fp, fx y_fp)
{
    Ball ball;

    memset(&ball, 0, sizeof(ball));
    ball.active = 1;
    ball.rally_state = BALL_RALLY_LIVE;
    ball.x_fp = x_fp;
    ball.y_fp = y_fp;
    ball.z_fp = 1;
    ball.vz_fp = -2;
    return ball_simulate_step(&ball);
}

static void test_inclusive_court_boundaries(void)
{
    fx left = TO_FP(COURT_BASELINE_LEFT);
    fx right = TO_FP(COURT_BASELINE_RIGHT);
    fx top = TO_FP(COURT_SIDELINE_TOP);
    fx bottom = TO_FP(COURT_SIDELINE_BOTTOM);
    u8 events;

    events = ground_event_at(left, top);
    assert(events & BALL_EVENT_BOUNCE);
    assert((events & BALL_EVENT_OUT) == 0);
    assert((ground_event_at(right, top) & BALL_EVENT_OUT) == 0);
    assert((ground_event_at(left, bottom) & BALL_EVENT_OUT) == 0);
    assert((ground_event_at(right, bottom) & BALL_EVENT_OUT) == 0);

    assert(ground_event_at(left - 1, top) & BALL_EVENT_OUT);
    assert(ground_event_at(right + 1, top) & BALL_EVENT_OUT);
    assert(ground_event_at(left, top - 1) & BALL_EVENT_OUT);
    assert(ground_event_at(left, bottom + 1) & BALL_EVENT_OUT);
}

static void test_pause_and_inactive(void)
{
    Ball before;

    ball_initialize();
    before = g_ball;
    assert(ball_update(1) == 0);
    assert(memcmp(&before, &g_ball, sizeof(before)) == 0);

    g_ball.active = 0;
    before = g_ball;
    assert(ball_update(0) == 0);
    assert(memcmp(&before, &g_ball, sizeof(before)) == 0);
}

static void test_opening_ball_remains_at_rest(void)
{
    u16 frame;

    ball_initialize();
    for (frame = 0; frame < 600; ++frame) {
        ball_simulate_step(&g_ball);
        assert(g_ball.z_fp >= 0);
    }
    assert(g_ball.x_fp == TO_FP(BALL_START_X));
    assert(g_ball.y_fp == TO_FP(BALL_START_Y));
    assert(g_ball.z_fp == 0);
    assert(g_ball.vx_fp == 0);
    assert(g_ball.vy_fp == 0);
    assert(g_ball.vz_fp == 0);
}

static void test_fast_ball_eventually_settles(void)
{
    Ball ball;
    u16 frame;

    memset(&ball, 0, sizeof(ball));
    ball.active = 1;
    ball.rally_state = BALL_RALLY_LIVE;
    ball.x_fp = TO_FP(64);
    ball.y_fp = TO_FP(112);
    ball.vx_fp = 44;
    ball.vz_fp = 40;
    for (frame = 0; frame < 600; ++frame) {
        ball_simulate_step(&ball);
        if (ball.z_fp == 0 && ball.vz_fp == 0)
            break;
    }

    assert(frame < 300);
    assert(ball.z_fp == 0);
    assert(ball.vx_fp == 0);
    assert(ball.vy_fp == 0);
    assert(ball.vz_fp == 0);
}

static void test_standard_shot_has_meaningful_first_flight(void)
{
    Ball ball;
    u8 events = BALL_EVENT_NONE;
    u16 frame;

    memset(&ball, 0, sizeof(ball));
    ball.active = 1;
    ball.rally_state = BALL_RALLY_LIVE;
    ball.x_fp = TO_FP(64);
    ball.y_fp = TO_FP(COURT_CENTERLINE_Y);
    ball.vx_fp = 44;
    ball.vz_fp = 40;

    for (frame = 0; frame < 60; ++frame) {
        events = ball_simulate_step(&ball);
        if (events & BALL_EVENT_BOUNCE)
            break;
    }

    assert(frame == 27);
    assert(ball.x_fp == TO_FP(64) + 44 * 28);
    assert(ball.x_fp > TO_FP(64 + 70));
    assert(ball.bounce_count == 1);
}

int main(void)
{
    test_initial_state();
    test_deterministic_flight();
    test_position_and_gravity_order();
    test_single_bounce_event();
    test_swept_net_height_boundaries();
    test_net_fault_event();
    test_inclusive_court_boundaries();
    test_pause_and_inactive();
    test_opening_ball_remains_at_rest();
    test_standard_shot_has_meaningful_first_flight();
    test_fast_ball_eventually_settles();
    puts("ball host checks passed");
    return 0;
}
