#ifndef PROFILE_H
#define PROFILE_H

#include "game_types.h"

/*
 * Frame timing (src/profile.c). The overrun latch and work-scanline record
 * are always on; per-stage marks compile away unless BUILD_PROFILE is set
 * (make release PROFILE=1).
 */
enum { PROFILE_STAGES = 16 };

/* Main-loop iterations that missed their VBlank (frame-overrun latch). */
extern u16 g_overrun_frames;
/* Main-loop iterations since boot (diagnostics and smoke probes). */
extern u16 g_loop_count;
/* Scanline reached when the frame's CPU work finished; worst case kept. */
extern u16 g_work_scanline;
extern u16 g_work_scanline_max;
/* Scanlines of VBlank (37 on NTSC, from line 225) used when the frame's
 * uploads ended: the NMI's OAM DMA and joypad read, then the commit's
 * palettes and HUD rows. Worst case kept; past 37 the uploads ran into
 * the display. */
extern u16 g_vblank_used_max;
/* Per-stage worst and wrapping-sum scanline costs. */
extern u16 g_stage_scanline_max[PROFILE_STAGES];
extern u16 g_stage_scanline_sum[PROFILE_STAGES];

void profile_initialize(void);
/* The PPU's current scanline (0-261; VBlank from 225). */
u16 profile_scanline(void);
/* Top of the main loop. */
void profile_frame_begin(void);
void profile_resync(void);
/* After all CPU work, before WaitForVBlank. */
void profile_work_done(void);
/* After the VBlank uploads (render_commit and the scene commits). */
void profile_vblank_done(void);
/* After WaitForVBlank: latches a missed frame. */
void profile_frame_end(void);

#ifdef BUILD_PROFILE
void profile_mark(u8 stage);
#define PROFILE_MARK(stage) profile_mark(stage)
#else
#define PROFILE_MARK(stage)
#endif

#endif
