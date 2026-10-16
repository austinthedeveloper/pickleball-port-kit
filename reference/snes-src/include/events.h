#ifndef EVENTS_H
#define EVENTS_H

#include "game_types.h"

/*
 * Simulation -> presentation event seam (docs/01 "Feedback priority",
 * docs/02 audio_events). The simulation emits; FX and audio consume. Nothing
 * here may change simulation state.
 */
typedef enum {
    EVENT_NONE = 0,
    EVENT_SERVE = 1,    /* serve contact; detail = server slot */
    EVENT_HIT = 2,      /* rally contact; detail = slot | ShotType << 4 */
    EVENT_BOUNCE = 3,   /* ground contact; detail = bounce count */
    EVENT_FAULT = 4,    /* net/out/kitchen/box/volley; detail = GameFault */
    EVENT_POINT = 5     /* point awarded; detail = winning team */
} GameEventKind;

/* x/y are whole world pixels (ground point). */
void events_emit(u8 kind, s16 x, s16 y, u8 detail);

#endif
