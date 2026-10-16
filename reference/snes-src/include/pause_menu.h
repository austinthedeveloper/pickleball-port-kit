#ifndef PAUSE_MENU_H
#define PAUSE_MENU_H

#include "game_types.h"

/*
 * Pause menu (docs/decisions/ADR-030-pause-menu.md): RESUME, RESTART, and
 * MAIN MENU while a match or practice is paused. Start still toggles pause
 * (game_update); this is the menu's input. Pure: main.c acts on the result.
 */
enum { PAUSE_RESUME = 0, PAUSE_RESTART = 1, PAUSE_MAIN_MENU = 2,
       PAUSE_CHOICES = 3 };
/* pause_input results. */
enum { PAUSE_STAY = 0, PAUSE_DO_RESUME = 1, PAUSE_DO_RESTART = 2,
       PAUSE_DO_MAIN_MENU = 3 };

extern u8 g_pause_choice;
/* Practice from the park's ball machine (M4-OPEN-05): the third choice
 * reads PARK and goes back there. */
extern u8 g_pause_park;

/* The menu opens on RESUME. */
void pause_begin(void);
/* One frame of 1P's newly pressed buttons: Up/Down choose (wrapping), B or A
 * does the choice, Y resumes. */
u8 pause_input(u16 pressed);
const char *pause_choice_name(u8 choice);

#endif
