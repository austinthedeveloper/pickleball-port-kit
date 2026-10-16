#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "game.h"
#include "input.h"
#include "match.h"
#include "pause_menu.h"

/* ADR-030 pause menu: choices, actions, and Start still toggling pause. */
int main(void)
{
    PlayerIntent intents[MAX_PLAYERS];

    pause_begin();
    assert(g_pause_choice == PAUSE_RESUME);
    assert(pause_input(PAD_UP) == PAUSE_STAY);
    assert(g_pause_choice == PAUSE_MAIN_MENU);          /* wraps */
    assert(pause_input(PAD_B) == PAUSE_DO_MAIN_MENU);
    pause_input(PAD_DOWN);
    assert(g_pause_choice == PAUSE_RESUME);
    pause_input(PAD_DOWN);
    assert(pause_input(PAD_A) == PAUSE_DO_RESTART);
    assert(pause_input(PAD_Y) == PAUSE_DO_RESUME);      /* Y resumes */
    assert(pause_input(PAD_START) == PAUSE_STAY);       /* Start: game.c */
    assert(strcmp(pause_choice_name(PAUSE_MAIN_MENU), "MAIN MENU") == 0);

    /* Start pauses and unpauses a match; the game stands still while
     * paused. */
    match_config_defaults();
    g_attract = 0;
    game_new_match();
    memset(intents, 0, sizeof(intents));
    intents[0].pause_pressed = 1;
    game_update(intents);
    assert(g_game_state.paused);
    intents[0].pause_pressed = 0;
    {
        u16 timer = g_game_state.phase_timer;
        game_update(intents);
        assert(g_game_state.phase_timer == timer);
    }
    intents[0].pause_pressed = 1;
    game_update(intents);
    assert(!g_game_state.paused);

    /* Practice pauses the same way (Start no longer leaves at once). */
    match_config_practice();
    game_new_match();
    intents[0].pause_pressed = 1;
    game_update(intents);
    assert(g_game_state.paused && !g_attract);
    printf("pause host checks passed\n");
    return 0;
}
