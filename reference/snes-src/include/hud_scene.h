#ifndef HUD_SCENE_H
#define HUD_SCENE_H

#include "game_types.h"

/* Score panels and staged scene overlays on BG3 (src/hud_scene.c). */
void hud_scene_initialize(void);
/* Forces a full redraw on the next update (after a full-screen overlay). */
void hud_scene_invalidate(void);
/* Redraws the title menu or records page (after the records change). */
void hud_scene_refresh_title(void);
/* Call once per frame before VBlank; touches only WRAM. */
void hud_scene_update(void);

/* Title menu entries (g_title_mode). */
enum { TITLE_SINGLES = 0, TITLE_DOUBLES = 1, TITLE_OPEN_PLAY = 2,
       TITLE_COURT = 3, TITLE_RECORDS = 4, TITLE_OPTIONS = 5,
       TITLE_MODIFIERS = 6, TITLE_PRACTICE = 7, TITLE_ENTRIES = 8 };
/* Title pages (g_title_page): the menu, or a page over it. */
enum { TITLE_PAGE_MENU = 0, TITLE_PAGE_COURT = 1, TITLE_PAGE_RECORDS = 2,
       TITLE_PAGE_OPTIONS = 3, TITLE_PAGE_PRACTICE = 4,
       TITLE_PAGE_MODIFIERS = 5 };

/* Title menu choice, the open page, and 2P joined (set by main.c). */
extern u8 g_title_mode;
extern u8 g_title_page;
extern u8 g_title_2p;

/* The close call's frame is drawn (ADR-041): its close-up may show. */
u8 hud_replay_framed(void);

#endif
