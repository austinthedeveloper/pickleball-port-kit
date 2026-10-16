#include "audio_events.h"
#include "events.h"
#include "game.h"
#include "input.h"
#include "match.h"
#include "modifiers.h"
#include "profile.h"
#include "save.h"
#include "sfx.h"

#ifndef HOST_TEST
#include "soundbank.h"
/* The soundbank spans one ROM bank per 32 KiB from bank 13 (ADR-031,
 * ADR-046); soundbank_banks.h counts smconv's banks for this build. */
#include "soundbank_banks.h"
#if SOUNDBANK_BANKS < 1 || SOUNDBANK_BANKS > 3
#error "the soundbank has 1-3 banks (13-15); move -b in the Makefile"
#endif
extern char SOUNDBANK__0;
#if SOUNDBANK_BANKS > 1
extern char SOUNDBANK__1;
#endif
#if SOUNDBANK_BANKS > 2
extern char SOUNDBANK__2;
#endif
#endif

/* Module volume for the ambience: quiet under the effects. */
#define AUDIO_AMBIENCE_VOLUME 150

u8 g_audio_ambience;
static u8 audio_setting(void);
/* The venue last asked for, so a SOUND change can restart it. */
static u8 s_ambience_venue;

u16 g_audio_event_counts[6];
AudioLast g_audio_last;
/* Shots in the current point (serve included), for the crowd. */
static u8 s_rally_shots;
/* Frames left to keep handing queued effects to the sound CPU, and frames
 * that skipped it. One spcProcess call can leave commands queued (two
 * effects on one frame: a fault's whistle and the point's applause), so it
 * keeps running for a few frames after the last effect; otherwise the
 * second effect waited for the next sound, often the next point's serve. */
static u8 s_pending;
static u8 s_skipped;
#define AUDIO_PROCESS_FRAMES 6

/* spcProcess hands queued commands over and waits for the sound CPU to
 * take each one: 60-110 scanlines. It runs only when the frame's work has
 * ended this early, or after this many frames of waiting. */
#define AUDIO_PROCESS_SCANLINE 130
#define AUDIO_PROCESS_MAX_SKIPS 3
/* Never past this, skips or not: the handover took the rest of the frame,
 * and a forced one at the end of a doubles point (several heavy frames in a
 * row) went past VBlank (KNOWN_ISSUES #22). The next frame with room hands
 * it over: doubles frames are rarely past it two frames running. */
#define AUDIO_PROCESS_HARD_SCANLINE 190

void audio_events_initialize(void)
{
    u8 i;

    for (i = 0; i < 6; ++i)
        g_audio_event_counts[i] = 0;
    g_audio_last.sfx = 0xff;
    g_audio_last.played = 0;
    s_rally_shots = 0;
    s_pending = 0;
    s_skipped = 0;
    /* Nothing loaded yet: the first court load (render_load_court) loads
     * the venue's ambience and the effects, once, keeping boot short. */
    g_audio_ambience = AUDIO_UNLOADED;
    s_ambience_venue = 0;
#ifndef HOST_TEST
    spcBoot();
    /* Banks are given last first. */
#if SOUNDBANK_BANKS > 2
    spcSetBank(&SOUNDBANK__2);
#endif
#if SOUNDBANK_BANKS > 1
    spcSetBank(&SOUNDBANK__1);
#endif
    spcSetBank(&SOUNDBANK__0);
    spcStop();
#endif
}

u8 audio_ambience_venue(void)
{
    return s_ambience_venue;
}

void audio_ambience(u8 venue)
{
    u8 want = audio_setting() == AUDIO_ALL ? venue : AUDIO_NO_AMBIENCE;
#ifndef HOST_TEST
    u8 i;
#endif

    s_ambience_venue = venue;
    if (want == g_audio_ambience)
        return;
    g_audio_ambience = want;
#ifndef HOST_TEST
    /* Loading a module replaces what the sound CPU holds: the effects are
     * loaded again after it (PVSnesLib's effects-and-music order). */
    spcStop();
    if (want != AUDIO_NO_AMBIENCE)
        spcLoad(MOD_AMBIENCE_0 + want);
    for (i = 0; i < SFX_COUNT; ++i)
        spcLoadEffect(i);
    if (want != AUDIO_NO_AMBIENCE) {
        spcPlay(0);
        spcSetModuleVolume(AUDIO_AMBIENCE_VOLUME);
    }
#endif
    /* spcPlay and the volume are queued commands: audio_update hands them
     * over in the next frames. (spcFlush hung the boot here.) */
    s_pending = AUDIO_PROCESS_FRAMES;
}

void audio_refresh(void)
{
    audio_ambience(s_ambience_venue);
}

const char *audio_setting_name(u8 setting)
{
    static const char *const names[AUDIO_SETTINGS] = {
        "ALL", "NO CROWD", "OFF"
    };
    return names[setting < AUDIO_SETTINGS ? setting : AUDIO_ALL];
}

static u8 audio_setting(void)
{
    return g_save.settings.sound < AUDIO_SETTINGS ? g_save.settings.sound :
        AUDIO_ALL;
}

static void audio_play(u8 sfx, u8 pitch, u8 volume, u8 pan)
{
    if (audio_setting() == AUDIO_OFF)
        return;
    g_audio_last.sfx = sfx;
    g_audio_last.pitch = pitch;
    g_audio_last.volume = volume;
    g_audio_last.pan = pan;
    ++g_audio_last.played;
    s_pending = AUDIO_PROCESS_FRAMES;
#ifndef HOST_TEST
    spcEffect(pitch, sfx, (u8)((volume << 4) | pan));
#endif
}

/* Court x (0-255) to pan 0-15. */
static u8 audio_pan(s16 x)
{
    if (x < 0)
        return 0;
    if (x > 255)
        return 15;
    return (u8)(x >> 4);
}

void audio_crowd(u8 volume)
{
    if (audio_setting() == AUDIO_NO_CROWD)
        return;
    audio_play(SFX_APPLAUSE, SFX_PITCH, volume, 8);
}

/* The crowd's reaction: louder for longer rallies, loudest for the point
 * that wins the match. */
static u8 audio_applause_volume(u8 winner)
{
    if (MODIFIERS_SCORE_WINS(g_game_state.team_score[winner & 1],
            g_game_state.team_score[(winner & 1) ^ 1],
            g_match_config.points_to_win, g_match_config.modifiers))
        return 15;
    if (s_rally_shots >= 10)
        return 13;
    if (s_rally_shots >= 6)
        return 10;
    if (s_rally_shots >= 3)
        return 8;
    return 6;
}

void audio_on_event(u8 kind, s16 x, u8 detail)
{
    if (kind < 6)
        ++g_audio_event_counts[kind];
    if (kind == EVENT_SERVE)
        s_rally_shots = 0;
    if (kind == EVENT_SERVE || kind == EVENT_HIT)
        ++s_rally_shots;
    /* The attract demo plays silently; the title has menu sounds only. */
    if (g_attract)
        return;
    switch (kind) {
    case EVENT_SERVE:
        audio_play(SFX_HIT, SFX_PITCH, 12, audio_pan(x));
        break;
    case EVENT_HIT:
        /* detail: hitter | ShotType << 4. Drives are sharper, soft shots
         * duller. */
        if ((detail >> 4) == SHOT_DRIVE)
            audio_play(SFX_HIT, SFX_PITCH + 1, 14, audio_pan(x));
        else if ((detail >> 4) == SHOT_SOFT)
            audio_play(SFX_HIT, SFX_PITCH - 1, 11, audio_pan(x));
        else
            audio_play(SFX_HIT, SFX_PITCH, 13, audio_pan(x));
        break;
    case EVENT_BOUNCE:
        audio_play(SFX_BOUNCE, SFX_PITCH, detail <= 1 ? 10 : 6, audio_pan(x));
        break;
    case EVENT_FAULT:
        if (detail == GAME_FAULT_NET)
            audio_play(SFX_NET, SFX_PITCH, 12, audio_pan(x));
        else
            audio_play(SFX_WHISTLE, SFX_PITCH, 10, 8);
        break;
    case EVENT_POINT:
        audio_crowd(audio_applause_volume(detail));
        break;
    default:
        break;
    }
}

void audio_ui(u8 sfx)
{
    audio_play(sfx, SFX_PITCH, 10, 8);
}

void audio_update(void)
{
    if (!s_pending)
        return;
#ifndef HOST_TEST
    if (profile_scanline() > AUDIO_PROCESS_HARD_SCANLINE)
        return;
    if (profile_scanline() > AUDIO_PROCESS_SCANLINE &&
            s_skipped < AUDIO_PROCESS_MAX_SKIPS) {
        ++s_skipped;
        return;
    }
    spcProcess();
#endif
    --s_pending;
    s_skipped = 0;
}
