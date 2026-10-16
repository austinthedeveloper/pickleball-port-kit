#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "audio_events.h"
#include "events.h"
#include "fx.h"
#include "serve.h"
#include "test_support.h"

/* The event seam fires for every serve, contact, bounce, fault, and point
 * of a played match, and FX reacts to contacts only. */
int main(void)
{
    PlayerIntent intents[MAX_PLAYERS];
    unsigned long frames = 0;
    u8 points;

    audio_events_initialize();
    game_new_match();
    test_bot_skill(4, 3);
    while (g_game_state.phase != GAME_PHASE_MATCH_RESULT) {
        memset(intents, 0, sizeof(intents));
        ai_update(0, &intents[0]);
        if (g_game_state.phase == GAME_PHASE_SERVE_SETUP &&
            g_serve_state.server_index == 0 && (frames & 31) == 0)
            intents[0].hit_pressed = 1;
        if (intents[0].hit_pressed == 0 && g_fx.spark_timer == FX_SPARK_FRAMES)
            assert(g_game_state.hit_stop > 0);   /* spark comes with a hit */
        test_step(intents);
        ++frames;
        assert(frames < 60UL * 60 * 10);
    }
    points = g_game_state.team_score[0] + g_game_state.team_score[1];
    printf("events: serve %d hit %d bounce %d fault %d point %d\n",
        g_audio_event_counts[EVENT_SERVE], g_audio_event_counts[EVENT_HIT],
        g_audio_event_counts[EVENT_BOUNCE], g_audio_event_counts[EVENT_FAULT],
        g_audio_event_counts[EVENT_POINT]);
    assert(g_audio_event_counts[EVENT_POINT] == points);
    assert(g_audio_event_counts[EVENT_SERVE] == points);
    assert(g_audio_event_counts[EVENT_HIT] > 0);
    assert(g_audio_event_counts[EVENT_BOUNCE] >= g_audio_event_counts[EVENT_HIT]);
    assert(g_audio_event_counts[EVENT_FAULT] <= points);

    /* FX: only contacts start a spark; it runs down one frame at a time. */
    fx_initialize();
    events_emit(EVENT_BOUNCE, 10, 20, 1);
    assert(g_fx.spark_timer == 0);
    events_emit(EVENT_HIT, 100, 120, 0);
    assert(g_fx.spark_timer == FX_SPARK_FRAMES);
    assert(g_fx.spark_x == 100 + FX_SPARK_LEAD_X && g_fx.spark_y == 120);
    events_emit(EVENT_HIT, 200, 120, 2);
    assert(g_fx.spark_x == 200 - FX_SPARK_LEAD_X);
    fx_tick();
    assert(g_fx.spark_timer == FX_SPARK_FRAMES - 1);
    puts("events host checks passed");
    return 0;
}
