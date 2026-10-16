#ifndef SELECT_H
#define SELECT_H

#include "game_types.h"
#include "match.h"

/* Player Select logic (docs/decisions/ADR-020-player-select.md). Pure: the
 * screen itself is src/render_select.c. */

enum {
    SELECT_ROW_VARIANT = 0,     /* MALE / FEMALE */
    SELECT_ROW_COLOUR = 1,      /* BLUE RED GREEN GOLD */
    SELECT_ROW_PADDLE = 2,      /* WOOD BLUE RED GOLD */
    SELECT_ROWS = 3
};

/* select_input results. */
enum {
    SELECT_STAY = 0,
    SELECT_DONE = 1,            /* every human confirmed: start the match */
    SELECT_BACK = 2             /* 1P backed out: return to the title */
};

typedef struct {
    u8 mode;                    /* MATCH_SINGLES or MATCH_DOUBLES */
    u8 humans;                  /* 1, or 2 when 2P joined on the title */
    u8 current;                 /* 0 while 1P chooses, 1 for 2P */
    u8 row;                     /* SELECT_ROW_* with the cursor */
    u8 changed;                 /* nonzero after any change; the renderer
                                   clears it */
    u8 reserved;
    PlayerChoice choice[2];
} SelectState;

extern SelectState g_select;

/* Opens the screen for 1P: blue, male, standard paddle; 2P defaults to the
 * first colour 1P has not taken. */
void select_begin(u8 mode, u8 humans);
/* One frame of the current human's newly pressed buttons (PAD_* bits).
 * Up/Down rows, Left/Right values. B steps to the next row and confirms
 * on the paddle row; Start confirms at once; Y steps back. */
u8 select_input(u16 pressed);
/* Nonzero when the colour belongs to 1P while 2P is choosing. */
u8 select_colour_taken(u8 palette_id);
/* The current human's choice. */
PlayerChoice *select_current(void);
/* Writes the confirmed choices to g_match_config (match_config_select). */
void select_apply(void);

#endif
