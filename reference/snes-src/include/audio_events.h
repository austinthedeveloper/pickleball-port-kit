#ifndef AUDIO_EVENTS_H
#define AUDIO_EVENTS_H

#include "game_types.h"

/*
 * Sound effects (docs/decisions/ADR-029-sound-effects.md). The simulation
 * emits events; this module turns them into SNESMOD effects (hits pitched
 * by shot type and panned by the ball, bounces, the net, the whistle for a
 * fault, and the crowd for a point). Host tests see the counts and the
 * last effect instead of the sound CPU.
 */
extern u16 g_audio_event_counts[6];

/* Sound option (SaveSettings.sound): everything, no crowd, or nothing. */
enum { AUDIO_ALL = 0, AUDIO_NO_CROWD = 1, AUDIO_OFF = 2, AUDIO_SETTINGS = 3 };

/* The last effect asked for (host tests; on the SNES too, for probes). */
typedef struct {
    u8 sfx;             /* SFX_* or 0xff for none yet */
    u8 pitch;
    u8 volume;          /* 0..15 */
    u8 pan;             /* 0 left .. 15 right */
    u16 played;         /* effects started since boot */
} AudioLast;

extern AudioLast g_audio_last;

/* Boots the sound CPU and loads the effects (a few frames; boot only). */
void audio_events_initialize(void);
/* A simulation event at court x (events.h kinds). */
void audio_on_event(u8 kind, s16 x, u8 detail);
/* Menus: SFX_BLIP, SFX_CONFIRM, or SFX_BACK, centred. */
void audio_ui(u8 sfx);
/* The crowd at a volume (practice streaks), unless the crowd is off. */
void audio_crowd(u8 volume);
/* Once a frame, after the frame's work: hands queued effects to the sound
 * CPU when the frame has time left (or after a few frames). */
void audio_update(void);
/* The venue's ambience loop (ADR-031): starts it (or keeps it) for this
 * venue, or stops it when the SOUND option leaves out the crowd. Loading a
 * module blocks for a moment: call it while the court loads. */
void audio_ambience(u8 venue);
/* The venue last asked for (its ambience, unless SOUND mutes it). */
u8 audio_ambience_venue(void);
/* Re-applies the SOUND option to the ambience (after OPTIONS changes). */
void audio_refresh(void);
/* Venue whose ambience is playing, or AUDIO_NO_AMBIENCE (host tests). */
extern u8 g_audio_ambience;
enum { AUDIO_NO_AMBIENCE = 0xff, AUDIO_UNLOADED = 0xfe };
/* Display name of a sound setting. */
const char *audio_setting_name(u8 setting);

#endif
