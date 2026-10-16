#include "court.h"
#include "events.h"
#include "fx.h"
#include "input.h"

Fx g_fx;

void fx_initialize(void)
{
    g_fx.spark_timer = 0;
    g_fx.spark_style = FX_SPARK_ALTERNATE;
    g_fx.spark_x = 0;
    g_fx.spark_y = 0;
}

void fx_on_event(u8 kind, s16 x, s16 y, u8 detail)
{
    if (kind != EVENT_HIT)
        return;
    /* detail: hitter slot (low bits; 2-3 = right team) | shot type << 4. */
    g_fx.spark_timer = FX_SPARK_FRAMES;
    g_fx.spark_x = (detail & 3) >= 2 ? x - FX_SPARK_LEAD_X :
        x + FX_SPARK_LEAD_X;
    if ((detail >> 4) == SHOT_DRIVE)
        g_fx.spark_style = FX_SPARK_BIG;
    else if ((detail >> 4) == SHOT_SOFT)
        g_fx.spark_style = FX_SPARK_SMALL;
    else
        g_fx.spark_style = FX_SPARK_ALTERNATE;
    g_fx.spark_y = y;
}

void fx_tick(void)
{
    if (g_fx.spark_timer)
        --g_fx.spark_timer;
}
