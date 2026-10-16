#ifndef SELECT_LAYOUT_H
#define SELECT_LAYOUT_H

/*
 * Player Select screen layout in screen pixels (ADR-020). Shared with
 * tools/art/prep_select_scene.py, which paints the BG1 art around these
 * boxes, and with src/select.c, which places the OBJ thumbnails, cursors,
 * and BG3 bars on them. Keep every value a plain decimal #define.
 */

/* MALE / FEMALE toggle (baked text, OBJ cursor). */
#define SEL_TOGGLE_Y0 47
#define SEL_TOGGLE_Y1 59
#define SEL_MALE_X0 33
#define SEL_MALE_X1 69
#define SEL_FEMALE_X0 71
#define SEL_FEMALE_X1 119

/* Portrait backdrop inside the left panel; BG2 portrait cell. */
#define SEL_BACKDROP_X0 10
#define SEL_BACKDROP_X1 142
#define SEL_BACKDROP_Y0 44
#define SEL_BACKDROP_Y1 134
#define SEL_PORTRAIT_COL 4
#define SEL_PORTRAIT_ROW 5
#define SEL_PORTRAIT_SCROLL_X 4

/* Colour thumbnails: four 31-px boxes, 32x32 OBJ inside, label below. */
#define SEL_THUMB_X0 11
#define SEL_THUMB_PITCH 33
#define SEL_THUMB_W 31
#define SEL_THUMB_Y0 137
#define SEL_THUMB_Y1 170
#define SEL_LABEL_Y0 172
#define SEL_LABEL_Y1 182

/* Paddle boxes in the right panel. */
#define SEL_PADDLE_X0 152
#define SEL_PADDLE_PITCH 24
#define SEL_PADDLE_W 21
#define SEL_PADDLE_Y0 70
#define SEL_PADDLE_Y1 117

/* Stat rows: baked label pills; BG3 bars from column SEL_BAR_COL on rows
 * SEL_BAR_ROW, +2, +4 (POWER, CONTROL, SPEED). */
#define SEL_STAT_X0 152
#define SEL_STAT_X1 244
#define SEL_BAR_COL 25
#define SEL_BAR_ROW 16
#define SEL_NAME_ROW 22
#define SEL_NAME_COL 20

/* BG3 player tag ("1P"/"2P") left of the toggle. */
#define SEL_TAG_COL 2
#define SEL_TAG_ROW 6

#endif
