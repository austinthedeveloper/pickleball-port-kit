#include <snes.h>
#include "profile.h"

#define REG_SLHV_LATCH (*(vuint8 *)0x2137)
#define REG_OPVCT_READ (*(vuint8 *)0x213D)
#define SCANLINES_PER_FRAME 262
#define VISIBLE_SCANLINES 225

u16 g_overrun_frames;
u16 g_loop_count;
u16 g_work_scanline;
u16 g_work_scanline_max;
u16 g_vblank_used_max;
u16 g_stage_scanline_max[PROFILE_STAGES];
u16 g_stage_scanline_sum[PROFILE_STAGES];

static u16 s_last_vblank;
#ifdef BUILD_PROFILE
static u16 s_stage_start;
#endif

/* Current scanline from the PPU's latched V counter (9 bits). Separate byte
 * reads: 816-tcc mishandles a combined u8 -> u16 expression here. */
u16 profile_scanline(void)
{
    u8 low;
    u8 high;
    low = REG_STAT78;           /* reset the OPVCT read flip-flop */
    low = REG_SLHV_LATCH;       /* latch H/V counters */
    low = REG_OPVCT_READ;
    high = REG_OPVCT_READ;
    return ((u16)(high & 1) << 8) | low;
}

void profile_initialize(void)
{
    u8 i;

    g_overrun_frames = 0;
    g_loop_count = 0;
    g_work_scanline = 0;
    g_work_scanline_max = 0;
    g_vblank_used_max = 0;
    for (i = 0; i < PROFILE_STAGES; ++i) {
        g_stage_scanline_max[i] = 0;
        g_stage_scanline_sum[i] = 0;
    }
    s_last_vblank = snes_vblank_count;
}

/* After a scene switch: the frames spent fading are not overruns. */
void profile_resync(void)
{
    s_last_vblank = snes_vblank_count;
}

void profile_frame_begin(void)
{
    ++g_loop_count;
#ifdef BUILD_PROFILE
    s_stage_start = profile_scanline();
#endif
}

void profile_work_done(void)
{
    g_work_scanline = profile_scanline();
    if (g_work_scanline < VISIBLE_SCANLINES &&
        g_work_scanline > g_work_scanline_max)
        g_work_scanline_max = g_work_scanline;
}

void profile_vblank_done(void)
{
    u16 line = profile_scanline();
    u16 used = line >= VISIBLE_SCANLINES ? line - VISIBLE_SCANLINES :
        line + SCANLINES_PER_FRAME - VISIBLE_SCANLINES;

    if (used > g_vblank_used_max)
        g_vblank_used_max = used;
}

void profile_frame_end(void)
{
    u16 now = snes_vblank_count;

    if ((u16)(now - s_last_vblank) > 1)
        ++g_overrun_frames;
    s_last_vblank = now;
}

#ifdef BUILD_PROFILE
/* Records the duration (in scanlines) of the stage ending here. */
void profile_mark(u8 stage)
{
    u16 line = profile_scanline();
    u16 used = line >= s_stage_start ? line - s_stage_start :
        line + SCANLINES_PER_FRAME - s_stage_start;
    if (used > g_stage_scanline_max[stage])
        g_stage_scanline_max[stage] = used;
    g_stage_scanline_sum[stage] += used;
    s_stage_start = line;
}
#endif
