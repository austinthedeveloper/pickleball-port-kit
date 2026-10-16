#ifndef REPLAY_H
#define REPLAY_H

#include "game_types.h"

/*
 * Close call replay (docs/GOOFY_IDEAS.md, ADR-041). A long rally that ends
 * with the ball landing just out shows a close-up of the line during the
 * point result: the ball dropping just past it, and by how much. Display
 * only: GameState and the golden trace are untouched. Pure.
 */

#ifndef REPLAY_MIN_SHOTS
#define REPLAY_MIN_SHOTS 8          /* a long rally, serve included */
#endif
#ifndef REPLAY_MAX_INCHES
#define REPLAY_MAX_INCHES 6         /* out by this much or less */
#endif

/* Court scale: 224 px is 44 ft, so a 12.4 pixel is 528 / 3584 inch, about
 * 151 / 1024 (court.h). 16-bit: only for distances up to REPLAY_NEAR_FP. */
#define REPLAY_NEAR_FP 256
#define REPLAY_INCHES(dist_fp) ((u16)((u16)(dist_fp) * 151u) >> 10)

/* The close-up (BG2, rows 15-21, columns 10-21 inside a HUD frame): the
 * line is column 15 (a baseline) or row 18 (a sideline). Zoomed 4x: the
 * ball's edge sits 4 px per pixel out past the line's edge.
 * tools/assetgen/select.py reads these. */
#define REPLAY_ROW 15
#define REPLAY_ROWS 7
#define REPLAY_COL 10
#define REPLAY_COLS 12
#define REPLAY_LINE_COL 15
#define REPLAY_LINE_ROW 18

typedef struct {
    u8 active;          /* this point result shows the close-up */
    u8 vertical;        /* the line is a baseline (vertical on screen) */
    s16 out_dir;        /* +1 or -1: from the line toward out, on screen */
    s16 dist_fp;        /* how far past the line (12.4) */
    u8 inches;
} ReplayState;

extern ReplayState g_replay;

void replay_initialize(void);
/* The point just ended: a close-up if the rally had at least
 * REPLAY_MIN_SHOTS shots and the ball landed out (at the ball's position)
 * by REPLAY_MAX_INCHES or less. Sets or clears g_replay.active. */
void replay_check(u8 shots, u8 fault);

#endif
