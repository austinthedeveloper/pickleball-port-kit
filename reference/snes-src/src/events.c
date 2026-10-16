#include "audio_events.h"
#include "events.h"
#include "fx.h"

void events_emit(u8 kind, s16 x, s16 y, u8 detail)
{
    fx_on_event(kind, x, y, detail);
    audio_on_event(kind, x, detail);
}
