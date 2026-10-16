#include "input.h"
#include "pause_menu.h"

u8 g_pause_choice;
u8 g_pause_park;

void pause_begin(void)
{
    g_pause_choice = PAUSE_RESUME;
}

const char *pause_choice_name(u8 choice)
{
    static const char *const names[PAUSE_CHOICES] = {
        "RESUME", "RESTART", "MAIN MENU"
    };
    if (choice == PAUSE_MAIN_MENU && g_pause_park)
        return "PARK";
    return names[choice < PAUSE_CHOICES ? choice : PAUSE_RESUME];
}

u8 pause_input(u16 pressed)
{
    if (pressed & PAD_Y)
        return PAUSE_DO_RESUME;
    if (pressed & (PAD_B | PAD_A)) {
        if (g_pause_choice == PAUSE_RESTART)
            return PAUSE_DO_RESTART;
        if (g_pause_choice == PAUSE_MAIN_MENU)
            return PAUSE_DO_MAIN_MENU;
        return PAUSE_DO_RESUME;
    }
    if (pressed & PAD_UP)
        g_pause_choice = g_pause_choice ? g_pause_choice - 1 :
            PAUSE_CHOICES - 1;
    else if (pressed & PAD_DOWN)
        g_pause_choice = g_pause_choice + 1 >= PAUSE_CHOICES ? 0 :
            g_pause_choice + 1;
    return PAUSE_STAY;
}
