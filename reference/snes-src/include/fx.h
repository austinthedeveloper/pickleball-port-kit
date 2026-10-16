#ifndef FX_H
#define FX_H

#include "game_types.h"

/* Presentation-only effects driven by events (docs/REFACTOR_PLAN.md R9). */
enum {
    FX_SPARK_FRAMES = 10,
    /* Effects sit behind player bodies in OAM (docs/03: bodies 2-5, effects
     * 10-13), so the spark is pushed toward the net, in front of the paddle
     * where the body sprite is transparent. */
    FX_SPARK_LEAD_X = 10
};

enum {
    FX_SPARK_ALTERNATE = 0,     /* standard: big and small frames */
    FX_SPARK_BIG = 1,           /* drive */
    FX_SPARK_SMALL = 2          /* lob / dink */
};

typedef struct {
    u8 spark_timer;
    u8 spark_style;
    s16 spark_x;
    s16 spark_y;
} Fx;

extern Fx g_fx;

void fx_initialize(void);
void fx_on_event(u8 kind, s16 x, s16 y, u8 detail);
/* Once per unpaused frame. */
void fx_tick(void);

#endif
