#include <assert.h>
#include <stdio.h>
#include "input.h"
#include "player.h"
#include "select.h"

/* ADR-020 Player Select: rows, values, 2P colour exclusion, confirm/back. */
int main(void)
{
    select_begin(MATCH_SINGLES, 1);
    assert(g_select.row == SELECT_ROW_VARIANT);
    assert(g_select.choice[0].palette_id == PAL_BLUE);

    /* B steps down the rows; Y steps back up. */
    assert(select_input(PAD_B) == SELECT_STAY);
    assert(g_select.row == SELECT_ROW_COLOUR);
    assert(select_input(PAD_B) == SELECT_STAY);
    assert(g_select.row == SELECT_ROW_PADDLE);
    assert(select_input(PAD_Y) == SELECT_STAY);
    assert(g_select.row == SELECT_ROW_COLOUR);
    assert(g_select.choice[0].paddle_id == PADDLE_STANDARD);

    /* Colour wraps both ways. */
    assert(select_input(PAD_LEFT) == SELECT_STAY);
    assert(g_select.choice[0].palette_id == PAL_GOLD);
    select_input(PAD_RIGHT);
    select_input(PAD_RIGHT);
    assert(g_select.choice[0].palette_id == PAL_RED);

    /* Rows clamp; the variant row toggles with Left/Right. */
    select_input(PAD_UP);
    select_input(PAD_UP);
    assert(g_select.row == SELECT_ROW_VARIANT);
    select_input(PAD_RIGHT);
    assert(g_select.choice[0].variant == PLAYER_VARIANT_FEMALE);
    select_input(PAD_RIGHT);
    assert(g_select.choice[0].variant == PLAYER_VARIANT_FEMALE);
    select_input(PAD_LEFT);
    assert(g_select.choice[0].variant == PLAYER_VARIANT_MALE);
    select_input(PAD_RIGHT);

    /* Paddles wrap. */
    select_input(PAD_DOWN);
    select_input(PAD_DOWN);
    select_input(PAD_DOWN);
    assert(g_select.row == SELECT_ROW_PADDLE);
    select_input(PAD_RIGHT);
    assert(g_select.choice[0].paddle_id == PADDLE_RED);
    select_input(PAD_RIGHT);
    select_input(PAD_RIGHT);
    assert(g_select.choice[0].paddle_id == PADDLE_WOOD);

    /* No buttons: nothing changes. */
    g_select.changed = 0;
    assert(select_input(0) == SELECT_STAY && !g_select.changed);

    /* One human: B on the paddle row confirms; the config follows. */
    assert(g_select.row == SELECT_ROW_PADDLE);
    assert(select_input(PAD_B) == SELECT_DONE);
    select_apply();
    assert(g_match_config.palette_id[0] == PAL_RED);
    assert(g_match_config.variant[0] == PLAYER_VARIANT_FEMALE);
    assert(g_match_config.paddle_id[0] == PADDLE_WOOD);
    assert(g_match_config.palette_id[2] == PAL_BLUE);
    assert(!g_match_config.human[2]);

    /* Y on 1P's top row backs out to the title; Start confirms anywhere. */
    select_begin(MATCH_SINGLES, 1);
    assert(select_input(PAD_Y) == SELECT_BACK);
    select_begin(MATCH_SINGLES, 1);
    assert(select_input(PAD_START) == SELECT_DONE);

    /* Two humans: 2P cannot take 1P's colour and skips it. */
    select_begin(MATCH_DOUBLES, 2);
    select_input(PAD_DOWN);
    select_input(PAD_RIGHT);                 /* 1P red */
    assert(select_input(PAD_START) == SELECT_STAY);
    assert(g_select.current == 1);
    assert(g_select.row == SELECT_ROW_VARIANT);
    select_input(PAD_DOWN);
    assert(g_select.choice[1].palette_id != PAL_RED);
    assert(select_colour_taken(PAL_RED));
    assert(g_select.choice[1].palette_id == PAL_GREEN);
    select_input(PAD_LEFT);                  /* skips red */
    assert(g_select.choice[1].palette_id == PAL_BLUE);
    /* Y climbs 2P's rows, then returns to 1P without leaving the screen. */
    assert(select_input(PAD_Y) == SELECT_STAY && g_select.current == 1);
    assert(select_input(PAD_Y) == SELECT_STAY && g_select.current == 0);
    assert(g_select.row == SELECT_ROW_PADDLE);
    assert(!select_colour_taken(PAL_RED));
    select_input(PAD_B);                     /* 1P done: 2P from the top */
    assert(g_select.current == 1);
    select_input(PAD_B);
    select_input(PAD_B);
    assert(select_input(PAD_B) == SELECT_DONE);
    select_apply();
    assert(g_match_config.mode == MATCH_DOUBLES);
    assert(g_match_config.palette_id[0] == PAL_RED);
    assert(g_match_config.palette_id[2] == PAL_BLUE);
    assert(g_match_config.human[2]);
    assert(g_match_config.palette_id[1] == PAL_GREEN);
    assert(g_match_config.palette_id[3] == PAL_GOLD);
    assert(match_config_palettes_unique());
    puts("select host checks passed");
    return 0;
}
