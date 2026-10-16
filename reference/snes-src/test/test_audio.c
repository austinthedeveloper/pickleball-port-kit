#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "audio_events.h"
#include "events.h"
#include "game.h"
#include "input.h"
#include "match.h"
#include "save.h"
#include "sfx.h"

/* ADR-029 sound effects: which effect each event plays, and how. */

static void reset(u8 setting)
{
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    g_save.settings.sound = setting;
    audio_events_initialize();
    match_config_defaults();
    g_attract = 0;
    game_initialize();
}

static void test_shots_and_bounces(void)
{
    reset(AUDIO_ALL);
    events_emit(EVENT_SERVE, 40, 130, 0);
    assert(g_audio_last.sfx == SFX_HIT && g_audio_last.pitch == SFX_PITCH);
    assert(g_audio_last.pan == 40 >> 4);
    events_emit(EVENT_HIT, 220, 130, 2 | (SHOT_DRIVE << 4));
    assert(g_audio_last.sfx == SFX_HIT);
    assert(g_audio_last.pitch == SFX_PITCH + 1);    /* drives are sharper */
    assert(g_audio_last.pan == 13);                 /* right of the net */
    events_emit(EVENT_HIT, 120, 130, 0 | (SHOT_SOFT << 4));
    assert(g_audio_last.pitch == SFX_PITCH - 1);    /* soft shots duller */
    events_emit(EVENT_BOUNCE, 128, 130, 1);
    assert(g_audio_last.sfx == SFX_BOUNCE && g_audio_last.volume == 10);
    events_emit(EVENT_BOUNCE, 128, 130, 2);
    assert(g_audio_last.volume < 10);               /* later bounces quieter */
}

static void test_faults_and_crowd(void)
{
    u8 i;
    u8 short_rally;

    reset(AUDIO_ALL);
    events_emit(EVENT_FAULT, 128, 130, GAME_FAULT_NET);
    assert(g_audio_last.sfx == SFX_NET);
    events_emit(EVENT_FAULT, 30, 130, GAME_FAULT_OUT);
    assert(g_audio_last.sfx == SFX_WHISTLE);

    /* The crowd: louder after a longer rally. */
    events_emit(EVENT_SERVE, 40, 130, 0);
    g_game_state.team_score[0] = 1;
    events_emit(EVENT_POINT, 0, 0, 0);
    assert(g_audio_last.sfx == SFX_APPLAUSE);
    short_rally = g_audio_last.volume;
    events_emit(EVENT_SERVE, 40, 130, 0);
    for (i = 0; i < 11; ++i)
        events_emit(EVENT_HIT, 128, 130, 0);
    events_emit(EVENT_POINT, 0, 0, 0);
    assert(g_audio_last.volume > short_rally);
    /* The point that wins the match is the loudest. */
    g_game_state.team_score[1] = g_match_config.points_to_win;
    events_emit(EVENT_SERVE, 40, 130, 2);
    events_emit(EVENT_POINT, 0, 0, 1);
    assert(g_audio_last.volume == 15);
}

static void test_settings_and_attract(void)
{
    u16 played;

    /* NO CROWD: effects play, applause does not. */
    reset(AUDIO_NO_CROWD);
    events_emit(EVENT_SERVE, 40, 130, 0);
    events_emit(EVENT_POINT, 0, 0, 0);
    assert(g_audio_last.sfx == SFX_HIT);
    audio_crowd(10);
    assert(g_audio_last.sfx == SFX_HIT);

    /* OFF: nothing, not even the menus. */
    reset(AUDIO_OFF);
    events_emit(EVENT_HIT, 40, 130, 0);
    audio_ui(SFX_BLIP);
    assert(g_audio_last.played == 0);

    /* The attract demo is silent; its events still count (test_events). */
    reset(AUDIO_ALL);
    g_attract = 1;
    events_emit(EVENT_HIT, 40, 130, 0);
    assert(g_audio_last.played == 0);
    assert(g_audio_event_counts[EVENT_HIT] == 1);
    audio_ui(SFX_CONFIRM);              /* menus still sound on the title */
    played = g_audio_last.played;
    assert(played == 1 && g_audio_last.sfx == SFX_CONFIRM);
    g_attract = 0;
    assert(strcmp(audio_setting_name(AUDIO_NO_CROWD), "NO CROWD") == 0);
}

/* ADR-031: the venue's ambience follows the SOUND option. */
static void test_ambience(void)
{
    reset(AUDIO_ALL);
    assert(g_audio_ambience == AUDIO_UNLOADED);
    audio_ambience(1);
    assert(g_audio_ambience == 1);
    audio_ambience(2);
    assert(g_audio_ambience == 2);
    g_save.settings.sound = AUDIO_NO_CROWD;     /* the murmur is crowd */
    audio_refresh();
    assert(g_audio_ambience == AUDIO_NO_AMBIENCE);
    g_save.settings.sound = AUDIO_OFF;
    audio_ambience(0);
    assert(g_audio_ambience == AUDIO_NO_AMBIENCE);
    g_save.settings.sound = AUDIO_ALL;
    audio_refresh();
    assert(g_audio_ambience == 0);
}

int main(void)
{
    test_shots_and_bounces();
    test_faults_and_crowd();
    test_settings_and_attract();
    test_ambience();
    printf("audio host checks passed\n");
    return 0;
}
