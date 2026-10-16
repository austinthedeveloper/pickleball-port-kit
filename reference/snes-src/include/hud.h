#ifndef HUD_H
#define HUD_H

#include "game_types.h"

/* BG3 text palettes (see HUD_PALETTES in tools/generate_assets.py). */
enum {
    /* Only BG3 palettes 0-3 (CGRAM 0-15) are used (ADR-016). */
    HUD_PAL_WHITE = 0,
    HUD_PAL_YELLOW = 1,       /* title gold; also the red B button */
    HUD_PAL_TEAM_LEFT = 2,    /* rewritten at match start (ADR-010) */
    HUD_PAL_TEAM_RIGHT = 3
};

enum {
    HUD_ROWS = 28,
    HUD_BAND_ROWS = 4,
    HUD_BANDS = 7
};

#define HUD_PRIORITY 0x2000
/* A BG3 map entry. A macro: a 816-tcc call per tile made full redraws
 * overrun the frame. */
#define hud_entry(tile, palette) \
    ((u16)(tile) | ((u16)(palette) << 10) | HUD_PRIORITY)

void hud_initialize(void);
void hud_clear_rows(u8 first_row, u8 count);
/* Whole map rows to and from a buffer of count * 32 entries; restoring
 * marks them for upload. A block copy, far cheaper than redrawing. */
void hud_save_rows(u8 first_row, u8 count, u16 *out);
void hud_restore_rows(u8 first_row, u8 count, const u16 *in);
void hud_text(u8 col, u8 row, u8 palette, const char *text);
/* Single digit or two digits when value >= 10. */
void hud_number(u8 col, u8 row, u8 palette, u8 value);
void hud_tile(u8 col, u8 row, u16 entry);
/* Fills a width x rows block with one map entry (assembly fill per row). */
void hud_fill_box(u8 col, u8 row, u8 width, u8 rows, u16 entry);
/* Three-row panel: border rows at row and row+2, interior on row+1. */
void hud_panel(u8 col, u8 row, u8 inner_cols);
/* A panel border around inner_cols x inner_rows cells left clear. */
void hud_frame(u8 col, u8 row, u8 inner_cols, u8 inner_rows);
void hud_big_text(u8 col, u8 row, u8 palette, const char *text);
u8 hud_big_width(const char *text);
/* Big text centred on the 32-column map. */
void hud_center_big(u8 row, u8 palette, const char *text);
/* Centred three-row panel; '@' in the text draws the B button glyph. */
void hud_center_prompt(u8 row, u8 palette, const char *text);
/* Its panel, and half its text (part 0 the first, 1 the rest): for frames
 * that can't afford it all (the doubles match result, the scrolling
 * park). */
void hud_center_prompt_panel(u8 row, const char *text);
void hud_center_prompt_half(u8 row, u8 palette, const char *text, u8 part);
/* DMA up to three dirty 4-row bands; call only inside VBlank. */
void hud_commit(void);
/* Uploads every dirty band; forced blank only. */
void hud_commit_all(void);

#endif
