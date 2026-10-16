#ifndef RENDER_INTERNAL_H
#define RENDER_INTERNAL_H

/* Shared by src/render.c and src/diagnostics.c only. */

#include "game_types.h"

#define CGRAM_OBJ 128
#define OBJ_PRIORITY 2

/* Inputs for oam_write (src/asm/oam_write.asm). */
extern u8 oam_in_id;
extern s16 oam_in_x;
extern s16 oam_in_y;
extern u16 oam_in_tile;
extern u8 oam_in_attr;
extern u8 oam_in_large;
extern u8 oam_tmp_bits;
extern u8 oam_tmp_mask;
extern void oam_write(void);

#define OBJ_ATTR(palette, hflip) \
    ((OBJ_PRIORITY << 4) | ((palette) << 1) | ((hflip) << 6))
#define OBJ_HFLIP 0x40
#define OBJ_VFLIP 0x80

/* A macro, not a function: 816-tcc's six stack arguments cost more than the
 * OAM write itself. */
#define obj_put(id, x, y, tile, attr, large) \
    do { \
        oam_in_id = (id); \
        oam_in_x = (x); \
        oam_in_y = (y); \
        oam_in_tile = (tile); \
        oam_in_attr = (attr); \
        oam_in_large = (large); \
        oam_write(); \
    } while (0)


void render_obj_hide(u8 id);
/* OBJ palette numbers in the active layout (render.h). */
extern u8 g_objpal_objects;
extern u8 g_objpal_flash;
extern u8 g_objpal_shadow;
/* Upload palettes (match or diagnostics) in the next VBlank. */
void render_request_palettes(void);
/* Re-hide unused body/shadow slots on the next frame. */
void render_reset_bodies(void);

#ifdef RENDER_DIAGNOSTICS
void diag_initialize(void);
void diag_draw_overlay(u8 paused);
void diag_stress_render(void);
u8 diag_upload_palettes(void);
#endif

#endif
