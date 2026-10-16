#include <snes.h>
#include "asset_frames.h"
#include "ball.h"
#include "court.h"
#include "game.h"
#include "hud.h"
#include "hud_scene.h"
#include "input.h"
#include "match.h"
#include "player.h"
#include "render.h"
#include "render_internal.h"

/*
 * Debug/hardware-test builds only: the status overlay and the OBJ stress
 * scene (M3-OBJ-01/02). Release builds compile none of this.
 */
#ifdef RENDER_DIAGNOSTICS

static u8 s_hud_debug_build_shown;

extern u16 g_overrun_frames;
static const char s_hex[] = "0123456789ABCDEF";
static char s_debug_line[20];

/* Hex only: 816-tcc division is far too slow for a per-frame overlay. */
static void debug_hex(u8 at, u16 value)
{
    s_debug_line[at] = s_hex[(value >> 8) & 15];
    s_debug_line[at + 1] = s_hex[(value >> 4) & 15];
    s_debug_line[at + 2] = s_hex[value & 15];
}

static void hud_draw_debug(void)
{
    static const char req[3] = { '-', 'S', 'R' };

    debug_hex(0, (u16)FROM_FP(g_players[0].x_fp));
    s_debug_line[3] = ',';
    debug_hex(4, (u16)FROM_FP(g_players[0].y_fp));
    s_debug_line[7] = ' ';
    s_debug_line[8] = req[g_game_state.required_bounce % 3];
    s_debug_line[9] = '0' + g_game_state.phase;
    s_debug_line[10] = ' ';
    s_debug_line[11] = 'O';
    debug_hex(12, g_overrun_frames);
    s_debug_line[15] = 0;
    hud_text(0, 0, HUD_PAL_WHITE, s_debug_line);
}

void diag_draw_overlay(u8 paused)
{
    hud_draw_debug();
    if (paused && !s_hud_debug_build_shown) {
        hud_text(0, 26, HUD_PAL_WHITE,
            g_multitap_present ? "MULTITAP: YES" : "MULTITAP: NO");
        hud_text(0, 27, HUD_PAL_WHITE, BUILD_ID_STRING);
        s_hud_debug_build_shown = 1;
    } else if (!paused && s_hud_debug_build_shown) {
        hud_clear_rows(26, 2);
        s_hud_debug_build_shown = 0;
    }
}

/*
 * OBJ stress scene (M3-OBJ-01/02, M3-ASSET-03). The worst planned row is
 * at head height (ADR-014, M4-OPP-04): every object below overlaps screen
 * row 124 but the shadows, which sit at the feet (row 148):
 *   4 bodies x 4 slivers                    16
 *   3 hats x 2 (only CPU opponents and an
 *     open play partner wear one)            6
 *   4 accessory placeholders (OAM 22-25)     4
 *   ball + ball shadow (OAM 0-1)             2
 *   4 impact effects (OAM 18-21)             4
 *                                    total  32 of 34
 * Bodies use OBJ palettes 0-3 loaded with all four composed team palettes
 * (one shared tile set), rotate palettes every 64 frames, flip every 32,
 * and step through every frame slot. The PPU's range/time-over flags are
 * latched in g_obj_overflow_frames.
 */
#define STRESS_ROW 150
#define STRESS_HEAD_ROW (STRESS_ROW - 26)
static u8 s_stress;
static u8 s_stress_hud_drawn;
static u8 s_stress_timer;
static u16 s_stress_palettes[4][16];
static const u16 s_stress_frames[11] = {
    FRAME_IDLE0, FRAME_IDLE1, FRAME_RUN0, FRAME_RUN1, FRAME_RUN2, FRAME_RUN3,
    FRAME_WINDUP, FRAME_SWING, FRAME_FOLLOW, FRAME_TOSS, FRAME_CHEER
};
static const s16 s_stress_x[4] = { 40, 96, 152, 208 };

u8 render_stress_active(void)
{
    return s_stress;
}

void render_stress_toggle(void)
{
    u8 i;

    s_stress = !s_stress;
    s_stress_timer = 0;
    s_stress_hud_drawn = 0;
    for (i = 0; i < RENDER_OAM_FIRST_HIDDEN; ++i)
        render_obj_hide(i);
    for (i = 0; i < 4; ++i)
        match_compose_parts(i, 0, i, s_stress_palettes[i]);
    render_request_palettes();
    render_reset_bodies();
    hud_scene_invalidate();
    hud_clear_rows(4, 24);
    g_obj_overflow_frames = 0;
}

void diag_stress_render(void)
{
    u8 i;
    u8 pal;
    u8 frame;
    s16 x;

    ++s_stress_timer;
    for (i = 0; i < 4; ++i) {
        x = s_stress_x[i];
        pal = (u8)((i + (s_stress_timer >> 6)) & 3);
        frame = (u8)(((s_stress_timer >> 3) + i * 3) % 11);
        if (i) {
            obj_put(RENDER_OAM_BODIES + RENDER_OAM_GROUP_SIZE * i,
                x - 8, STRESS_HEAD_ROW - 4, OBJTILE_HAT_TRICORN,
                OBJ_ATTR(pal, 0), 0);
            obj_put(RENDER_OAM_BODIES + RENDER_OAM_GROUP_SIZE * i + 1,
                x, STRESS_HEAD_ROW - 4, OBJTILE_HAT_TRICORN + 1,
                OBJ_ATTR(pal, 0), 0);
        }
        obj_put(RENDER_OAM_BODIES + RENDER_OAM_GROUP_SIZE * i +
                RENDER_OAM_GROUP_BODY, x - PLAYER_SPRITE_HALF_WIDTH,
            STRESS_ROW - PLAYER_SPRITE_FOOT_Y, s_stress_frames[frame],
            OBJ_ATTR(pal, ((s_stress_timer >> 5) + i) & 1), 1);
        obj_put(RENDER_OAM_SHADOWS + i, x - 4, STRESS_ROW - 4,
            OBJTILE_PLAYER_SHADOW, OBJ_ATTR(g_objpal_shadow, 0), 0);
        obj_put(RENDER_OAM_ACCESSORIES + i, x + 10, STRESS_HEAD_ROW - 4,
            OBJTILE_SPARK_SMALL, OBJ_ATTR(pal, 0), 0);
        obj_put(RENDER_OAM_SPARK + i, x + 18, STRESS_HEAD_ROW - 4,
            (s_stress_timer & 4) ? OBJTILE_SPARK : OBJTILE_SPARK_SMALL,
            OBJ_ATTR(g_objpal_objects, 0), 0);
    }
    obj_put(RENDER_OAM_BALL, 120, STRESS_HEAD_ROW - 4, OBJTILE_BALL,
        OBJ_ATTR(g_objpal_objects, 0), 0);
    obj_put(RENDER_OAM_BALL_SHADOW, 124, STRESS_HEAD_ROW - 2,
        OBJTILE_BALL_SHADOW, OBJ_ATTR(g_objpal_shadow, 0), 0);

    if (!s_stress_hud_drawn) {
        s_stress_hud_drawn = 1;
        hud_clear_rows(4, 24);
        hud_center_prompt(5, HUD_PAL_YELLOW, "OBJ STRESS 32/34");
        hud_text(2, 22, HUD_PAL_WHITE, "4 PALETTES, 1 TILE SET");
        hud_text(2, 24, HUD_PAL_WHITE, "SELECT: BACK TO GAME");
    }
    hud_text(2, 9, HUD_PAL_WHITE,
        g_obj_overflow_frames ? "OBJ OVERFLOW: YES" : "OBJ OVERFLOW: NO ");
    hud_text(2, 10, HUD_PAL_WHITE,
        g_multitap_present ? "MULTITAP: YES" : "MULTITAP: NO ");
}

/* Called with pending palette work in VBlank. Returns 1 when the stress
 * scene's palettes replaced the match palettes; otherwise render restores
 * the full match layout. */
u8 diag_upload_palettes(void)
{
    if (!s_stress)
        return 0;
    dmaCopyCGram((u8 *)s_stress_palettes, CGRAM_OBJ, 4 * 32);
    return 1;
}

void diag_initialize(void)
{
    s_hud_debug_build_shown = 0;
    s_stress = 0;
    s_stress_timer = 0;
}

#endif
