#include "input.h"
#include "player.h"
#include "modifiers.h"
#include "options.h"
#include "save.h"
#include "career.h"
#include "select.h"

SelectState g_select;

PlayerChoice *select_current(void)
{
    return g_select.current ? &g_select.choice[1] : &g_select.choice[0];
}

u8 select_colour_taken(u8 palette_id)
{
    return g_select.current == 1 &&
        g_select.choice[0].palette_id == palette_id;
}

/* Next colour in direction step (+1/-1, wrapping) that is not taken. */
static u8 step_colour(u8 from, s16 step)
{
    u8 colour = from;
    u8 tries;

    for (tries = 0; tries < PAL_COUNT; ++tries) {
        colour = (u8)((colour + PAL_COUNT + step) % PAL_COUNT);
        if (!select_colour_taken(colour))
            return colour;
    }
    return from;
}

void select_begin(u8 mode, u8 humans)
{
    g_select.mode = mode;
    g_select.humans = humans == 2 ? 2 : 1;
    g_select.current = 0;
    g_select.row = SELECT_ROW_VARIANT;
    g_select.reserved = 0;
    g_select.choice[0].palette_id = PAL_BLUE;
    g_select.choice[0].variant = PLAYER_VARIANT_MALE;
    g_select.choice[0].paddle_id = PADDLE_STANDARD;
    /* ADR-047: 1P starts on the active career player's body, shirt, and
     * paddle (changes are for this match). */
    if (career_active()) {
        g_select.choice[0].palette_id = career_active()->shirt;
        g_select.choice[0].variant = career_active()->variant;
        g_select.choice[0].paddle_id = career_active()->paddle;
    }
    g_select.choice[1].palette_id = PAL_RED;
    g_select.choice[1].variant = PLAYER_VARIANT_MALE;
    g_select.choice[1].paddle_id = PADDLE_STANDARD;
    g_select.changed = 1;
}

static void change_value(s16 step)
{
    PlayerChoice *choice = select_current();

    if (g_select.row == SELECT_ROW_VARIANT)
        choice->variant = step > 0 ? PLAYER_VARIANT_FEMALE :
            PLAYER_VARIANT_MALE;
    else if (g_select.row == SELECT_ROW_COLOUR)
        choice->palette_id = step_colour(choice->palette_id, step);
    else
        choice->paddle_id = (u8)((choice->paddle_id + PADDLE_COUNT + step) %
            PADDLE_COUNT);
}

u8 select_input(u16 pressed)
{
    if (!pressed)
        return SELECT_STAY;
    g_select.changed = 1;

    /* B steps down the rows and confirms on the last one; Start confirms
     * from any row. */
    if ((pressed & PAD_B) && g_select.row < SELECT_ROWS - 1) {
        ++g_select.row;
        return SELECT_STAY;
    }
    if (pressed & (PAD_B | PAD_START)) {
        if (g_select.current == 0 && g_select.humans == 2) {
            g_select.current = 1;
            g_select.row = SELECT_ROW_VARIANT;
            if (select_colour_taken(g_select.choice[1].palette_id))
                g_select.choice[1].palette_id =
                    step_colour(g_select.choice[1].palette_id, 1);
            return SELECT_STAY;
        }
        return SELECT_DONE;
    }
    /* Y steps back up the rows, then to 1P, then out to the title. */
    if (pressed & PAD_Y) {
        if (g_select.row > 0) {
            --g_select.row;
            return SELECT_STAY;
        }
        if (g_select.current == 1) {
            g_select.current = 0;
            g_select.row = SELECT_ROW_PADDLE;
            return SELECT_STAY;
        }
        return SELECT_BACK;
    }
    if ((pressed & PAD_UP) && g_select.row > 0)
        --g_select.row;
    else if ((pressed & PAD_DOWN) && g_select.row < SELECT_ROWS - 1)
        ++g_select.row;
    else if (pressed & PAD_LEFT)
        change_value(-1);
    else if (pressed & PAD_RIGHT)
        change_value(1);
    return SELECT_STAY;
}

void select_apply(void)
{
    match_config_select(g_select.mode, &g_select.choice[0],
        g_select.humans == 2 ? &g_select.choice[1] : 0);
    /* ADR-047: 1P plays as the active career player (skin, hair, hat). */
    g_match_config.career_p1 = career_active() != 0;
    /* ADR-023: against the CPU, the next opponent on the ladder. */
    if (g_select.humans == 1)
        match_config_opponent(g_save.settings.ladder);
    /* ADR-025: the saved options. */
    g_match_config.points_to_win = options_points(g_save.settings.points);
    g_match_config.difficulty = options_difficulty(g_save.settings.difficulty);
    /* ADR-033: the saved modifiers. */
    g_match_config.modifiers = modifiers_valid(g_save.settings.modifiers);
}
