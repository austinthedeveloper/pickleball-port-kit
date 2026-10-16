#include <snes.h>
#include "asset_frames.h"
#include "career.h"
#include "hud.h"
#include "hud_tiles.h"
#include "match.h"
#include "paddle_stats.h"
#include "player.h"
#include "render.h"
#include "render_internal.h"
#include "select.h"
#include "select_layout.h"

/*
 * Player Select screen (ADR-020). BG1 holds the static art, BG2 the
 * portrait (one map per variant, recoloured through BG palette 7), BG3 the
 * stat bars and tags, OBJ the colour thumbnails and the corner cursors.
 */

extern char select_tiles, select_tiles_end;
extern char select_map, select_map_end;
extern char select_palette, select_palette_end;
extern char portrait_tiles, portrait_tiles_end;
extern char portrait_m_map, portrait_m_map_end;
extern char portrait_f_map, portrait_f_map_end;
extern char objects_palette;

#define SEL_BG2_MAP_MALE 0x0800
#define SEL_BG2_MAP_FEMALE 0x0C00
#define SEL_BG2_TILES 0x4000
#define SEL_BG_PORTRAIT_PALETTE 7

/* OBJ palettes: 0-3 thumbnails (BLUE..GOLD), then the cursors. */
#define SEL_OBJPAL_CURSOR 4
#define SEL_OBJPAL_CURSOR_DIM 5
#define SEL_OBJPAL_TAKEN 6

/* OAM: the career player's hats 0-7 (two halves each, in front of the
 * thumbnails: a lower index is drawn on top), thumbnails 8-11, their
 * ponytails 12-15 (behind), cursor corners 16-27. */
#define SEL_OAM_HATS 0
#define SEL_OAM_THUMBS 8
#define SEL_OAM_PONYTAILS 12
#define SEL_OAM_CURSORS 16

static const u16 s_hat_tiles[HAT_COUNT] = HAT_TILES;

/* Priority 3: above BG1 and the BG2 portrait. */
#define SEL_ATTR(palette, flags) ((3 << 4) | ((palette) << 1) | (flags))
#define SEL_HFLIP 0x40
#define SEL_VFLIP 0x80

#define SEL_THUMB_CEL_FRAMES 24

static u16 s_pal_portrait[16];
static u16 s_pal_thumbs[PAL_COUNT][16];
static u16 s_pal_cursor_dim[16];
static u16 s_pal_taken[16];
static u8 s_palettes_dirty;
static u8 s_variant_shown;
static u8 s_anim;
static u8 s_cel;

static const char *const s_paddle_names[PADDLE_COUNT] = {
    " CONTROL  ", " STANDARD ", "  POWER   ", "  SPEED   "
};

static void draw_thumbnails(const PlayerChoice *choice)
{
    u8 i;
    s16 x;
    s16 y = SEL_THUMB_Y0 + 1;
    u8 palette;
    u16 tile = s_cel ? FRAME_IDLE1 : FRAME_IDLE0;
    s16 acc_y = s_cel ? FRAME_IDLE1_ACC_Y : FRAME_IDLE0_ACC_Y;
    /* ADR-047: 1P's career hat on every thumbnail (0: the cap they wear). */
    u16 hat = (g_select.current == 0 && career_active()) ?
        s_hat_tiles[career_active()->hat % HAT_COUNT] : 0;

    for (i = 0; i < PAL_COUNT; ++i) {
        x = SEL_THUMB_X0 + i * SEL_THUMB_PITCH;
        palette = select_colour_taken(i) ? SEL_OBJPAL_TAKEN : i;
        obj_put(SEL_OAM_THUMBS + i, x, y, tile, SEL_ATTR(palette, 0), 1);
        /* As in a match (render_bodies.asm): the frame's accessory spot,
         * HAT_DX in and HAT_RAISE up, two small halves. */
        if (hat) {
            obj_put(SEL_OAM_HATS + 2 * i, x + FRAME_IDLE0_ACC_X + HAT_DX,
                y + acc_y - HAT_RAISE, hat, SEL_ATTR(palette, 0), 0);
            obj_put(SEL_OAM_HATS + 2 * i + 1,
                x + FRAME_IDLE0_ACC_X + HAT_DX + 8, y + acc_y - HAT_RAISE,
                hat ^ 1, SEL_ATTR(palette, 0), 0);
        } else {
            render_obj_hide(SEL_OAM_HATS + 2 * i);
            render_obj_hide(SEL_OAM_HATS + 2 * i + 1);
        }
        if (choice->variant == PLAYER_VARIANT_FEMALE)
            obj_put(SEL_OAM_PONYTAILS + i, x + FRAME_IDLE0_ACC_X,
                y + acc_y, OBJTILE_PONYTAIL, SEL_ATTR(palette, 0), 0);
        else
            render_obj_hide(SEL_OAM_PONYTAILS + i);
    }
}

/* Four corner objects around a box; first is the OAM id of the first. */
static void draw_cursor(u8 first, s16 x0, s16 y0, s16 x1, s16 y1,
    u8 focused)
{
    u8 palette = focused ? SEL_OBJPAL_CURSOR : SEL_OBJPAL_CURSOR_DIM;

    obj_put(first, x0 - 2, y0 - 2, OBJTILE_SELECT_CORNER,
        SEL_ATTR(palette, 0), 0);
    obj_put(first + 1, x1 - 5, y0 - 2, OBJTILE_SELECT_CORNER,
        SEL_ATTR(palette, SEL_HFLIP), 0);
    obj_put(first + 2, x0 - 2, y1 - 5, OBJTILE_SELECT_CORNER,
        SEL_ATTR(palette, SEL_VFLIP), 0);
    obj_put(first + 3, x1 - 5, y1 - 5, OBJTILE_SELECT_CORNER,
        SEL_ATTR(palette, SEL_HFLIP | SEL_VFLIP), 0);
}

static void draw_cursors(const PlayerChoice *choice)
{
    s16 x0;

    if (choice->variant == PLAYER_VARIANT_FEMALE)
        draw_cursor(SEL_OAM_CURSORS, SEL_FEMALE_X0, SEL_TOGGLE_Y0,
            SEL_FEMALE_X1, SEL_TOGGLE_Y1,
            g_select.row == SELECT_ROW_VARIANT);
    else
        draw_cursor(SEL_OAM_CURSORS, SEL_MALE_X0, SEL_TOGGLE_Y0,
            SEL_MALE_X1, SEL_TOGGLE_Y1, g_select.row == SELECT_ROW_VARIANT);
    x0 = SEL_THUMB_X0 + choice->palette_id * SEL_THUMB_PITCH;
    draw_cursor(SEL_OAM_CURSORS + 4, x0, SEL_THUMB_Y0,
        x0 + SEL_THUMB_W - 1, SEL_LABEL_Y1,
        g_select.row == SELECT_ROW_COLOUR);
    x0 = SEL_PADDLE_X0 + choice->paddle_id * SEL_PADDLE_PITCH;
    draw_cursor(SEL_OAM_CURSORS + 8, x0, SEL_PADDLE_Y0,
        x0 + SEL_PADDLE_W - 1, SEL_PADDLE_Y1,
        g_select.row == SELECT_ROW_PADDLE);
}

static void draw_stats(const PlayerChoice *choice)
{
    u8 stat;
    u8 cell;
    u8 value;

    /* ADR-047 stage 4: 1P's bars with their career hat's gear. */
    u8 profile = (g_select.current == 0 && career_active()) ?
        PADDLE_PROFILE(choice->paddle_id, career_active()->hat) :
        choice->paddle_id;

    for (stat = 0; stat < 3; ++stat) {
        value = g_paddle_stats[profile][stat];
        for (cell = 0; cell < PADDLE_STAT_MAX; ++cell)
            hud_tile(SEL_BAR_COL + cell, SEL_BAR_ROW + stat * 2,
                cell < value ? hud_entry(HUD_TILE_BAR_ON, HUD_PAL_YELLOW) :
                    hud_entry(HUD_TILE_BAR_OFF, HUD_PAL_WHITE));
    }
    hud_text(SEL_NAME_COL, SEL_NAME_ROW, HUD_PAL_WHITE,
        s_paddle_names[choice->paddle_id]);
    hud_text(SEL_TAG_COL, SEL_TAG_ROW, HUD_PAL_YELLOW,
        g_select.current ? "2P" : "1P");
}

static void select_redraw(void)
{
    const PlayerChoice *choice = select_current();
    u8 i;

    /* ADR-047: 1P's portrait and thumbnails in the active career player's
     * skin and hair. */
    if (g_select.current == 0 && career_active()) {
        career_compose_with(career_active(), choice->palette_id,
            choice->paddle_id, s_pal_portrait);
        for (i = 0; i < PAL_COUNT; ++i)
            career_compose_with(career_active(), i, choice->paddle_id,
                s_pal_thumbs[i]);
    } else {
        match_compose_parts(choice->palette_id, 0, choice->paddle_id,
            s_pal_portrait);
        for (i = 0; i < PAL_COUNT; ++i)
            match_compose_parts(i, 0, choice->paddle_id, s_pal_thumbs[i]);
    }
    s_palettes_dirty = 1;
    draw_thumbnails(choice);
    draw_cursors(choice);
    draw_stats(choice);
}

void render_select_prepare(void)
{
    if (g_select.changed) {
        g_select.changed = 0;
        select_redraw();
    } else if (++s_anim >= SEL_THUMB_CEL_FRAMES) {
        s_anim = 0;
        s_cel ^= 1;
        draw_thumbnails(select_current());
    }
}

/* VBlank: palettes, the portrait variant (BG2 map pointer), HUD bands. */
void render_select_commit(void)
{
    u8 variant = select_current()->variant;

    if (s_palettes_dirty) {
        dmaCopyCGram((u8 *)s_pal_portrait, SEL_BG_PORTRAIT_PALETTE * 16, 32);
        dmaCopyCGram((u8 *)s_pal_thumbs, CGRAM_OBJ, PAL_COUNT * 32);
        s_palettes_dirty = 0;
    }
    if (variant != s_variant_shown) {
        bgSetMapPtr(1, variant == PLAYER_VARIANT_FEMALE ?
            SEL_BG2_MAP_FEMALE : SEL_BG2_MAP_MALE, SC_32x32);
        s_variant_shown = variant;
    }
    hud_commit();
}

#define SEL_FADE_STEP_FRAMES 1    /* per brightness step: 16 frames */

/* Fades through brightness; the screen ends black but not force-blanked. */
void render_fade(u8 out)
{
    if (out) {
        setFadeEffectEx(FADE_OUT, SEL_FADE_STEP_FRAMES);
    } else {
        setBrightness(0);
        setFadeEffectEx(FADE_IN, SEL_FADE_STEP_FRAMES);
    }
}

void render_select_open(void)
{
    const u16 *objects = (const u16 *)&objects_palette;
    u8 i;

    render_fade(1);
    setScreenOff();
    render_camera_reset();              /* ADR-050: Player Select is still */
    for (i = 0; i < 128; ++i)
        render_obj_hide(i);

    dmaCopyVram((u8 *)&select_tiles, RENDER_BG1_TILES_ADDR,
        (u16)(&select_tiles_end - &select_tiles));
    dmaCopyVram((u8 *)&select_map, RENDER_BG1_MAP_ADDR,
        (u16)(&select_map_end - &select_map));
    bgSetMapPtr(0, RENDER_BG1_MAP_ADDR, SC_32x32);
    bgSetScroll(0, 0, 0);
    dmaCopyVram((u8 *)&portrait_tiles, SEL_BG2_TILES,
        (u16)(&portrait_tiles_end - &portrait_tiles));
    dmaCopyVram((u8 *)&portrait_m_map, SEL_BG2_MAP_MALE,
        (u16)(&portrait_m_map_end - &portrait_m_map));
    dmaCopyVram((u8 *)&portrait_f_map, SEL_BG2_MAP_FEMALE,
        (u16)(&portrait_f_map_end - &portrait_f_map));
    dmaCopyCGram((u8 *)&select_palette, 16,
        (u16)(&select_palette_end - &select_palette));

    /* Cursor palettes: the object palette (yellow) and a grey copy for
     * rows without focus; taken colours are a dark silhouette. */
    for (i = 0; i < 16; ++i) {
        s_pal_cursor_dim[i] = objects[i];
        s_pal_taken[i] = RGB5(5, 7, 10);
    }
    s_pal_cursor_dim[5] = RGB5(14, 15, 17);
    s_pal_taken[0] = 0;
    s_pal_taken[1] = RGB5(1, 2, 5);
    dmaCopyCGram((u8 *)&objects_palette, CGRAM_OBJ + SEL_OBJPAL_CURSOR * 16,
        32);
    dmaCopyCGram((u8 *)s_pal_cursor_dim,
        CGRAM_OBJ + SEL_OBJPAL_CURSOR_DIM * 16, 32);
    dmaCopyCGram((u8 *)s_pal_taken, CGRAM_OBJ + SEL_OBJPAL_TAKEN * 16, 32);
    setColorEffect(0x00, 0x00);

    bgSetGfxPtr(1, SEL_BG2_TILES);
    bgSetMapPtr(1, SEL_BG2_MAP_MALE, SC_32x32);
    bgSetScroll(1, SEL_PORTRAIT_SCROLL_X, 0);
    bgSetEnable(1);

    s_variant_shown = PLAYER_VARIANT_MALE;
    s_anim = 0;
    s_cel = 0;
    hud_initialize();
    g_select.changed = 1;
    render_select_prepare();
    render_select_commit();
    hud_commit_all();
    render_fade(0);
}
