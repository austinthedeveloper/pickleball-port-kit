#include <snes.h>
#include <string.h>
#define VENUE_DATA_DEFINE
#include "ai.h"
#include "asset_frames.h"
#include "ball.h"
#include "court.h"
#include "audio_events.h"
#include "court_style.h"
#include "fx.h"
#include "game.h"
#include "hud.h"
#include "hud_tiles.h"
#include "input.h"
#include "match.h"
#include "modifiers.h"
#include "player.h"
#include "profile.h"
#include "projection.h"
#include "render.h"
#include "asm_shared.h"
#include "options.h"
#include "render_internal.h"
#include "hud_scene.h"
#include "save.h"
#include "practice.h"
#include "serve.h"
#include "opponents.h"
#include "story.h"
#include "replay.h"


/* The ground every venue shares (ADR-024); venues.h has the rest. */
extern char court_tiles, court_tiles_end;
extern char court_palette, court_palette_end;
extern char hud_tiles, hud_tiles_end;
extern char hud_palette, hud_palette_end;
extern char obj_tiles, obj_tiles_end;
extern char objects_palette, objects_palette_end;
extern char bust_tiles, bust_tiles_end;
extern char bust_m_map, bust_m_map_end;
extern char bust_f_map, bust_f_map_end;
extern char closeup_map, closeup_map_end;

/* The intro card's bust (M4-STORY-03) in BG palette 1, the one a match
 * leaves free. Its frame uses two roles a bust never shows: 10 (shoe) is
 * the inner border, in the HUD's border grey, and 13 (paddle edge) the
 * backdrop (tools/art/prep_opponent_busts.py). */
#define RENDER_BUST_CGRAM 16
#define RENDER_BUST_FRAME 10
#define RENDER_BUST_BACKDROP 13
static u16 s_bust_palette[16];
static u8 s_bust_shown;
/* The close call's close-up is on BG2 (ADR-041); its ball's OAM is used. */
static u8 s_replay_shown;
static u8 s_replay_ball;
/* The opponent's partner is in the stands (ADR-042). */
static u8 s_watcher_shown;

u16 g_obj_overflow_frames;
/* Each slot's hat tile pair, 0 for the cap (M4-OPP-04); set with the match
 * config, read by render_bodies (src/asm/render_bodies.asm). */
u16 rb_hat[MAX_PLAYERS];
static const u16 s_hat_tiles[HAT_COUNT] = HAT_TILES;

/* Inputs for ram_copy (src/asm/ram_copy.asm). */
u16 ram_copy_src;
u16 ram_copy_dst;
u16 ram_copy_len;

#define REG_STAT77_FLAGS (*(vuint8 *)0x213E)

static u16 s_player_palettes[MAX_PLAYERS][16];
static u16 s_hud_team_colors[2][2];
static u8 s_palette_dirty;
/* BG1 palette 2 with the saved court colours (ADR-022). */
static u16 s_ground_palette[COURT_GROUND_COLORS];
/* Palette 2 as painted, copied from ROM when the court loads: composing
 * from WRAM is far cheaper for 816-tcc than reading ROM per colour, and a
 * live recolour (COURT page) must fit a busy title frame. */
static u16 s_painted_ground[COURT_GROUND_COLORS];
/* A recolour waits for a frame with time left (the title demo alone
 * reaches ~200 scanlines on its heavy frames), but at most a few frames. */
static u8 s_ground_pending;
static u8 s_ground_waits;
/* 96 and 6 (were 110 and 3): with the career save (ADR-047) boot runs a
 * little longer, which moved heavy title-demo frames onto COURT page
 * recolours (and a LAVA one in a match); a lighter frame or more chances
 * keep every make perf run at zero. */
#define RENDER_RECOLOR_SCANLINE_LIMIT 96
#define RENDER_RECOLOR_MAX_WAITS 6
static u8 s_ground_dirty;
/* KNOWN_ISSUES #26: the court's surface is so dark (BLACK) that a black
 * shadow vanishes on it; shadows are then grey (render_shadow_palette). */
static u8 s_dark_court;
#define RENDER_DARK_COURT_SUM 12        /* r + g + b of the surface, 5-bit */
#define RENDER_DARK_SHADOW 0x4210       /* (16, 16, 16): half of it shows */
static u16 s_shadow_palette[16];
static const u8 *render_shadow_palette(const u16 *source);
/* The venue's backdrop, BG1 palettes 3-7, at the saved TIME (ADR-045):
 * composed here and uploaded whole. A TIME change on the COURT page
 * recomposes it on a light frame after the ground's. */
static u16 s_backdrop[5 * 16];
/* The backdrop as painted, copied from ROM when the court loads (the
 * transform reads work RAM, src/asm/court_time.asm). */
static u16 s_backdrop_painted[5 * 16];
static u8 s_backdrop_pending;
static u8 s_backdrop_dirty;
/* Venue on screen (ADR-024). */
static u8 s_venue;
/* A preview keeps the ambience that plays (render_preview_court). */
static u8 s_keep_ambience;
/* The LAVA kitchen is on the ground palette (ADR-033). */
static u8 s_lava_shown;
u8 g_render_busy;
/* A LAVA match, or its preview on the title's MODIFIERS page. A macro: it
 * runs on a new match's frame, which is near the budget. */
#define RENDER_LAVA_WANTED() \
    (g_attract ? (g_title_page == TITLE_PAGE_MODIFIERS && \
                  (g_save.settings.modifiers & MODIFIER_LAVA) != 0) : \
     (g_match_config.modifiers & MODIFIER_LAVA) != 0)
static u8 s_doubles;
static u8 s_applied_mode;

static void render_load_court(void);

u8 render_match_mode_applied(void)
{
    return s_applied_mode;
}
u8 g_objpal_objects;
u8 g_objpal_flash;
u8 g_objpal_shadow;

/* Composes player palettes and picks the OBJ layout for the match mode
 * (ADR-018); uploads happen in render_commit's VBlank. */
void render_apply_match_config(void)
{
    u8 team;
    u8 slot;

    s_doubles = g_match_config.mode == MATCH_DOUBLES;
    s_applied_mode = g_match_config.mode;
    g_objpal_objects = s_doubles ? RENDER_OBJPAL_DOUBLES_OBJECTS :
        RENDER_OBJPAL_OBJECTS;
    g_objpal_flash = s_doubles ? RENDER_OBJPAL_DOUBLES_FLASH :
        RENDER_OBJPAL_FLASH;
    g_objpal_shadow = s_doubles ? RENDER_OBJPAL_DOUBLES_SHADOW :
        RENDER_OBJPAL_SHADOW;
    for (slot = 0; slot < MAX_PLAYERS; ++slot)
        if (match_slot_active(slot))
            match_compose_palette(slot, s_player_palettes[slot]);
    /* Hats (M4-OPP-04): render_bodies draws or parks them every frame. */
    for (slot = 0; slot < MAX_PLAYERS; ++slot)
        rb_hat[slot] = s_hat_tiles[match_slot_hat(slot)];
    /* Ponytails are written only for female players; park the rest. */
    for (slot = 0; slot < MAX_PLAYERS; ++slot)
        if (!match_slot_active(slot) ||
                g_match_config.variant[slot] != PLAYER_VARIANT_FEMALE)
            render_obj_hide(RENDER_OAM_ACCESSORIES + slot);
    for (team = 0; team < 2; ++team) {
        s_hud_team_colors[team][0] = match_team_hud_colors(team)[0];
        s_hud_team_colors[team][1] = match_team_hud_colors(team)[1];
    }
    s_palette_dirty = 1;
    /* Back to the title from a LAVA match, or into one: the kitchen. */
    if (s_lava_shown != RENDER_LAVA_WANTED())
        s_ground_pending = 1;
}

/* Every OBJ palette of the active layout, the HUD team colours, and the
 * shadow colour math (on for singles, off for doubles). */
static void render_upload_palettes(void)
{
    u8 team;

    if (s_doubles) {
        dmaCopyCGram((u8 *)s_player_palettes, CGRAM_OBJ, 4 * 32);
        dmaCopyCGram((u8 *)render_shadow_palette(
                (const u16 *)((u8 *)&objects_palette + 64)),
            CGRAM_OBJ + g_objpal_shadow * 16, 32);
        setColorEffect(0x02, 0x00);
    } else {
        dmaCopyCGram((u8 *)s_player_palettes[0], CGRAM_OBJ, 32);
        dmaCopyCGram((u8 *)s_player_palettes[2], CGRAM_OBJ + 16, 32);
        dmaCopyCGram((u8 *)render_shadow_palette(
                (const u16 *)((u8 *)&objects_palette + 32)),
            CGRAM_OBJ + g_objpal_shadow * 16, 32);
        /* Shadows: OBJ palette 4 pixels are black and averaged with BG1 on
         * the subscreen, i.e. half-brightness court under every shadow. */
        setColorEffect(0x02, 0x50);
    }
    dmaCopyCGram((u8 *)&objects_palette, CGRAM_OBJ + g_objpal_objects * 16,
        32);
    dmaCopyCGram((u8 *)g_pal_flash, CGRAM_OBJ + g_objpal_flash * 16, 32);
    /* BG3 palettes 2/3 colours 1-2 are the team label colours. */
    for (team = 0; team < 2; ++team)
        dmaCopyCGram((u8 *)s_hud_team_colors[team],
            (HUD_PAL_TEAM_LEFT + team) * 4 + 1, 4);
    s_palette_dirty = 0;
}

/* M3-OBJ-02: OAM ranges from docs/03 cannot overlap; a violation fails the
 * build with a negative array size. */
typedef char oam_bodies_after_ball[
    (RENDER_OAM_BODIES > RENDER_OAM_BALL_SHADOW) ? 1 : -1];
typedef char oam_shadows_after_bodies[
    (RENDER_OAM_SHADOWS >=
        RENDER_OAM_BODIES + RENDER_OAM_GROUP_SIZE * MAX_PLAYERS) ? 1 : -1];
typedef char oam_group_holds_hat_and_body[
    (RENDER_OAM_GROUP_BODY == 2 && RENDER_OAM_GROUP_SIZE == 3) ? 1 : -1];
typedef char oam_effects_after_shadows[
    (RENDER_OAM_SPARK >= RENDER_OAM_SHADOWS + MAX_PLAYERS) ? 1 : -1];
typedef char oam_effects_within_reserve[
    (RENDER_OAM_DEBUG_MARKER < RENDER_OAM_SPARK + 4) ? 1 : -1];
typedef char oam_accessories_after_effects[
    (RENDER_OAM_ACCESSORIES >= RENDER_OAM_SPARK + 4) ? 1 : -1];
typedef char oam_machine_after_accessories[
    (RENDER_OAM_MACHINE >= RENDER_OAM_ACCESSORIES + MAX_PLAYERS) ? 1 : -1];
typedef char oam_replay_after_machine[
    (RENDER_OAM_REPLAY >= RENDER_OAM_MACHINE + 4) ? 1 : -1];
typedef char oam_watcher_after_replay[
    (RENDER_OAM_WATCHER >= RENDER_OAM_REPLAY + 2) ? 1 : -1];
typedef char oam_zone_after_watcher[
    (RENDER_OAM_ZONE >= RENDER_OAM_WATCHER + 2) ? 1 : -1];
typedef char oam_hidden_after_zone[
    (RENDER_OAM_FIRST_HIDDEN >= RENDER_OAM_ZONE + 4) ? 1 : -1];

/* OAM writer inputs (src/asm/oam_write.asm); declared in render_internal.h. */
u8 oam_in_id;
s16 oam_in_x;
s16 oam_in_y;
u16 oam_in_tile;
u8 oam_in_attr;
u8 oam_in_large;
u8 oam_tmp_bits;
u8 oam_tmp_mask;
/* The camera's offset (ADR-050), taken off every object oam_write places;
 * 0 outside the court. */
#define REG_HDMAEN (*(vuint8 *)0x420C)
s16 oam_cam_x;
s16 oam_cam_y;
extern s16 g_cam_far_x;                /* the backdrop's pan (ADR-051) */
s16 oam_tmp_x;
s16 oam_tmp_y;

void render_obj_hide(u8 id)
{
    oam_in_id = id;
    oam_in_x = 0;
    oam_in_y = 240;
    oam_write();
}




/*
 * ADR-012: bodies take OAM 2-5 nearest-first (larger y wins; ties by slot) so
 * the nearer player draws on top; shadows keep fixed per-slot IDs 6-9.
 */
/* Working variables for src/asm/render_bodies.asm (all words). */
s16 rb_depth[MAX_PLAYERS];
u16 rb_order[MAX_PLAYERS];
u16 rb_i;
u16 rb_key;
s16 rb_kd;
u16 rb_tmp;
u16 rb_slot;
s16 rb_y;
s16 rb_d;
u16 rb_sign;
s16 rb_prod;
s16 rb_sx;
u16 rb_attr;
u16 rb_count;
u16 rb_frame;
u16 rb_oam;
extern void render_bodies(void);

static u8 s_active_bodies;

void render_reset_bodies(void)
{
    s_active_bodies = 0xff;
}

/* Nonzero when the composed surface (palette 2 entry 4) is very dark. */
static u8 render_dark_surface(void)
{
    u16 c = s_ground_palette[4];

    return (c & 31) + ((c >> 5) & 31) + ((c >> 10) & 31) <=
        RENDER_DARK_COURT_SUM;
}

static void render_compose_ground(void)
{
    court_style_compose(s_ground_palette, s_painted_ground,
        g_save.settings.court, s_venue);
    s_lava_shown = RENDER_LAVA_WANTED();
    if (s_lava_shown)
        court_style_lava(s_ground_palette);
    court_style_time_ground(s_ground_palette, g_save.settings.time);
    s_ground_dirty = 1;
    /* A dark surface changes the shadows' colour (uploaded with the other
     * OBJ palettes). Entry 4 is the surface. */
    if (render_dark_surface() != s_dark_court) {
        s_dark_court = render_dark_surface();
        s_palette_dirty = 1;
    }
    s_ground_pending = 0;
    s_ground_waits = 0;
}

/* Grey shadows on a dark court, else the objects' own. */
static const u8 *render_shadow_palette(const u16 *source)
{
    u8 i;

    if (!s_dark_court)
        return (const u8 *)source;
    /* The shadow is black (0): every colour but transparency goes grey. */
    s_shadow_palette[0] = source[0];
    for (i = 1; i < 16; ++i)
        s_shadow_palette[i] = RENDER_DARK_SHADOW;
    return (const u8 *)s_shadow_palette;
}

void render_apply_court_colors(void)
{
    s_ground_pending = 1;
}

/* The backdrop as painted, then at the saved TIME (ADR-045). */
static void render_compose_backdrop(void)
{
    court_style_time_copy(s_backdrop_painted, s_backdrop, 5 * 16,
        g_save.settings.time, 0);
    s_backdrop_pending = 0;
}

void render_apply_court_time(void)
{
    s_ground_pending = 1;
    s_backdrop_pending = 1;
}

/* In render_prepare: a pending recolour on a light frame (or a late one):
 * the ground first, the backdrop on a later frame. */
static void render_update_ground(void)
{
    if (!s_ground_pending && !s_backdrop_pending)
        return;
    if (profile_scanline() > RENDER_RECOLOR_SCANLINE_LIMIT &&
            s_ground_waits < RENDER_RECOLOR_MAX_WAITS) {
        ++s_ground_waits;
        return;
    }
    if (s_ground_pending) {
        render_compose_ground();
    } else {
        render_compose_backdrop();
        s_backdrop_dirty = 1;
    }
    /* The HUD skips its own big redraw this frame: the two together ran
     * past the budget on the COURT page (a row and the recolour). */
    g_render_busy = 1;
}

void render_request_palettes(void)
{
    s_palette_dirty = 1;
}

/*
 * ADR-012: bodies take OAM 2-5 nearest-first and shadows keep per-slot IDs
 * 6-9. The per-player work is in src/asm/render_bodies.asm (four players in
 * doubles did not fit the frame in 816-tcc C); here only the rare re-hide
 * when the number of active players changes.
 */
static void render_players(void)
{
    u8 j;

    render_bodies();
    if (rb_count != s_active_bodies) {
        s_active_bodies = (u8)rb_count;
        for (j = 0; j < MAX_PLAYERS; ++j) {
            if (j >= rb_count) {
                render_obj_hide(RENDER_OAM_BODIES +
                    RENDER_OAM_GROUP_SIZE * j);
                render_obj_hide(RENDER_OAM_BODIES +
                    RENDER_OAM_GROUP_SIZE * j + 1);
                render_obj_hide(RENDER_OAM_BODIES +
                    RENDER_OAM_GROUP_SIZE * j + RENDER_OAM_GROUP_BODY);
            }
            if (rb_depth[j] == -32767)
                render_obj_hide(RENDER_OAM_SHADOWS + j);
        }
    }
}

static void render_ball(void)
{
    s16 x;
    s16 y;
    s16 z;
    s16 sx;

    if (!g_ball.active) {
        render_obj_hide(RENDER_OAM_BALL);
        render_obj_hide(RENDER_OAM_BALL_SHADOW);
        return;
    }
    x = FROM_FP(g_ball.x_fp);
    y = FROM_FP(g_ball.y_fp);
    z = FROM_FP(g_ball.z_fp);
    sx = projection_x(x, y);
    if (g_match_config.modifiers & MODIFIER_BIG_BALL) {
        /* BIG BALL (ADR-033): a 14 px ball centred in a 32x32 object. */
        obj_put(RENDER_OAM_BALL_SHADOW, sx - 4, y - 4,
            OBJTILE_BIG_BALL_SHADOW, OBJ_ATTR(g_objpal_shadow, 0), 0);
        obj_put(RENDER_OAM_BALL, sx - 16, y - z - 16, OBJTILE_BIG_BALL,
            OBJ_ATTR(g_objpal_objects, 0), 1);
        return;
    }
    obj_put(RENDER_OAM_BALL_SHADOW, sx - 4, y - 4, OBJTILE_BALL_SHADOW,
        OBJ_ATTR(g_objpal_shadow, 0), 0);
    obj_put(RENDER_OAM_BALL, sx - 4, y - z - 4, OBJTILE_BALL,
        OBJ_ATTR(g_objpal_objects, 0), 0);
}

/* The practice ball machine (ADR-028): four 8x8 objects, its nozzle (the
 * left edge, 8 px up) where the feeds leave. The left half turns the nozzle
 * toward the next feed's lane; a feed kicks the machine back 2 px.
 * Hidden outside practice. */
static void render_machine(void)
{
    static const u8 left_top[3] = {
        OBJTILE_MACHINE_UP_TL, OBJTILE_MACHINE_TL, OBJTILE_MACHINE_DOWN_TL
    };
    static const u8 left_bottom[3] = {
        OBJTILE_MACHINE_UP_BL, OBJTILE_MACHINE_BL, OBJTILE_MACHINE_DOWN_BL
    };
    s16 x;
    s16 y = PRACTICE_MACHINE_Y - 16;
    u8 attr = OBJ_ATTR(g_objpal_objects, 0);
    u8 pose = g_practice.pose;
    u8 i;

    if (!g_match_config.practice || g_attract) {
        for (i = 0; i < 4; ++i)
            render_obj_hide(RENDER_OAM_MACHINE + i);
        return;
    }
    x = projection_x(PRACTICE_MACHINE_X, PRACTICE_MACHINE_Y) - 1;
    if (g_practice.kick)
        x += g_practice.kick > PRACTICE_KICK_FRAMES / 2 ? 2 : 1;
    obj_put(RENDER_OAM_MACHINE, x, y, left_top[pose], attr, 0);
    obj_put(RENDER_OAM_MACHINE + 1, x + 8, y, OBJTILE_MACHINE_TR, attr, 0);
    obj_put(RENDER_OAM_MACHINE + 2, x, y + 8, left_bottom[pose], attr, 0);
    obj_put(RENDER_OAM_MACHINE + 3, x + 8, y + 8, OBJTILE_MACHINE_BR, attr, 0);
}

/* The practice return zone (M4-PRACTICE-03): a corner object at each corner
 * of its ground rectangle, the select cursor's corner flipped; they blink
 * after a return lands in it. Hidden once when there is none. */
static u8 s_zone_drawn;
/* The machine or the zone may be on screen: hide them once after practice. */
static u8 s_practice_drawn;

static void render_zone(void)
{
    const s16 *rect;
    u8 attr = OBJ_ATTR(g_objpal_objects, 0);
    u8 i;

    if (!g_match_config.practice || g_attract ||
            g_practice.zone == PRACTICE_ZONE_ANY ||
            (g_practice.zone_flash & 4)) {
        if (s_zone_drawn)
            for (i = 0; i < 4; ++i)
                render_obj_hide(RENDER_OAM_ZONE + i);
        s_zone_drawn = 0;
        return;
    }
    /* The corner's yellow edge is 1 px in from the tile's (6 px flipped). */
    rect = g_practice_zone_rects[g_practice.zone];
    obj_put(RENDER_OAM_ZONE, projection_x(rect[0], rect[1]) - 1, rect[1] - 1,
        OBJTILE_SELECT_CORNER, attr, 0);
    obj_put(RENDER_OAM_ZONE + 1, projection_x(rect[2], rect[1]) - 6,
        rect[1] - 1, OBJTILE_SELECT_CORNER, attr | OBJ_HFLIP, 0);
    obj_put(RENDER_OAM_ZONE + 2, projection_x(rect[0], rect[3]) - 1,
        rect[3] - 6, OBJTILE_SELECT_CORNER, attr | OBJ_VFLIP, 0);
    obj_put(RENDER_OAM_ZONE + 3, projection_x(rect[2], rect[3]) - 6,
        rect[3] - 6, OBJTILE_SELECT_CORNER, attr | OBJ_HFLIP | OBJ_VFLIP, 0);
    s_zone_drawn = 1;
}

static void render_effects(void)
{
    s16 sx;

    if (g_fx.spark_timer) {
        sx = projection_x(g_fx.spark_x, g_fx.spark_y);
        obj_put(RENDER_OAM_SPARK, sx - 4,
            g_fx.spark_y - FROM_FP(g_ball.z_fp) - 4,
            (g_fx.spark_style == FX_SPARK_BIG ||
             (g_fx.spark_style == FX_SPARK_ALTERNATE &&
              (g_fx.spark_timer & 2))) ? OBJTILE_SPARK : OBJTILE_SPARK_SMALL, OBJ_ATTR(g_objpal_objects, 0), 0);
    } else {
        render_obj_hide(RENDER_OAM_SPARK);
    }

#ifdef BUILD_DEBUG
    if (g_ai.has_target) {
        obj_put(RENDER_OAM_DEBUG_MARKER,
            projection_x(g_ai.predicted_land_x, g_ai.predicted_land_y) - 4,
            g_ai.predicted_land_y - 4, OBJTILE_SPARK_SMALL,
            OBJ_ATTR(g_objpal_objects, 0), 0);
    } else {
        render_obj_hide(RENDER_OAM_DEBUG_MARKER);
    }
#else
    render_obj_hide(RENDER_OAM_DEBUG_MARKER);
#endif
}

/* The close call (ADR-041) shows during its point result only. */
#define RENDER_REPLAY_WANTED() \
    (g_replay.active && !g_attract && \
     g_game_state.phase == GAME_PHASE_POINT_RESULT)
#define RENDER_REPLAY_ROWS_BYTES (REPLAY_ROWS * 32 * 2)
#define RENDER_REPLAY_DROP_START 6
#define RENDER_REPLAY_DROP_FRAMES 24  /* falls 36 px: (t * t) / 16 */
#define RENDER_REPLAY_BOUNCE_FRAMES 16
#define RENDER_REPLAY_BALL_RADIUS 7   /* the BIG BALL is 14 px */
#define RENDER_REPLAY_LINE_HALF 4

/* VBlank: the close-up's rows for this line and side, then BG2 on; off
 * when the point result ends. */
static void render_commit_replay(void)
{
    u8 variant;

    /* After the HUD's frame is up: never a bare close-up for a frame. */
    if (RENDER_REPLAY_WANTED() && hud_replay_framed()) {
        if (s_replay_shown)
            return;
        variant = (g_replay.vertical ? 0 : 2) + (g_replay.out_dir > 0);
        dmaCopyVram((u8 *)&closeup_map + variant * RENDER_REPLAY_ROWS_BYTES,
            RENDER_BG2_REPLAY_MAP_ADDR + REPLAY_ROW * 32,
            RENDER_REPLAY_ROWS_BYTES);
        bgSetMapPtr(1, RENDER_BG2_REPLAY_MAP_ADDR, SC_32x32);
        bgSetScroll(1, 0, 0);
        bgSetEnable(1);
        s_replay_shown = 1;
    } else if (s_replay_shown) {
        bgSetDisable(1);
        s_replay_shown = 0;
    }
}

/* The ball dropping onto its spot in slow motion, with a bounce, and its
 * shadow; in front of the close-up (OBJ priority 3). Zoomed 4x: the ball's
 * edge is 4 px per pixel past the line's edge. */
static void render_replay_ball(void)
{
    s16 x = REPLAY_COL * 8 + REPLAY_COLS * 4;
    s16 y = REPLAY_ROW * 8 + REPLAY_ROWS * 4;
    s16 out = RENDER_REPLAY_LINE_HALF + RENDER_REPLAY_BALL_RADIUS +
        (g_replay.dist_fp >> 2);
    s16 t = (s16)g_game_state.phase_timer - RENDER_REPLAY_DROP_START;
    s16 z;

    if (!s_replay_shown || t < 0) {
        if (s_replay_ball) {
            render_obj_hide(RENDER_OAM_REPLAY);
            render_obj_hide(RENDER_OAM_REPLAY + 1);
            s_replay_ball = 0;
        }
        return;
    }
    /* Inside the close-up whatever the distance (the threshold keeps it
     * there anyway: 6 inches is 10 zoomed pixels). */
    if (g_replay.vertical) {
        if (out > REPLAY_COLS * 4 - RENDER_REPLAY_BALL_RADIUS - 8)
            out = REPLAY_COLS * 4 - RENDER_REPLAY_BALL_RADIUS - 8;
        x = REPLAY_LINE_COL * 8 + 4 + g_replay.out_dir * out;
    } else {
        if (out > (REPLAY_ROWS / 2) * 8 + 3 - RENDER_REPLAY_BALL_RADIUS)
            out = (REPLAY_ROWS / 2) * 8 + 3 - RENDER_REPLAY_BALL_RADIUS;
        y = REPLAY_LINE_ROW * 8 + 4 + g_replay.out_dir * out;
    }
    if (t < RENDER_REPLAY_DROP_FRAMES) {
        z = RENDER_REPLAY_DROP_FRAMES - t;
        z = (s16)((z * z) >> 4);
    } else if (t < RENDER_REPLAY_DROP_FRAMES + RENDER_REPLAY_BOUNCE_FRAMES) {
        t -= RENDER_REPLAY_DROP_FRAMES;
        z = (s16)((t * (RENDER_REPLAY_BOUNCE_FRAMES - t)) >> 3);
    } else {
        z = 0;
    }
    /* The close-up is BG2, which doesn't pan: undo the camera. */
    x += oam_cam_x;
    y += oam_cam_y;
    obj_put(RENDER_OAM_REPLAY + 1, x - 4, y - 4, OBJTILE_PLAYER_SHADOW,
        (3 << 4) | (g_objpal_shadow << 1), 0);
    obj_put(RENDER_OAM_REPLAY, x - 16, y - z - 16, OBJTILE_BIG_BALL,
        (3 << 4) | (g_objpal_objects << 1), 1);
    s_replay_ball = 1;
}

/*
 * A crowd of the players sitting out (GOOFY_IDEAS.md, ADR-042): in a
 * singles ladder match the opponent's doubles partner watches from the
 * venue's stands, in the team's kit (the captain's palette: singles has no
 * other OBJ palette outside the shadows' colour math), facing the court.
 * They hop while their side wins a point or the match.
 */
#define RENDER_WATCHER_WANTED() \
    (!g_attract && g_match_config.mode == MATCH_SINGLES && \
     g_match_config.opponent < OPPONENT_COUNT && \
     !g_match_config.open_play && !g_match_config.practice)

static void render_watcher(void)
{
    const u8 *seat = g_venue_watcher[s_venue];
    s16 x;
    s16 y;
    u8 attr;
    u8 cheer;

    if (!RENDER_WATCHER_WANTED()) {
        if (s_watcher_shown) {
            render_obj_hide(RENDER_OAM_WATCHER);
            render_obj_hide(RENDER_OAM_WATCHER + 1);
            s_watcher_shown = 0;
        }
        return;
    }
    /* In the stands, the backdrop: it pans at half the camera (ADR-051),
     * and oam_write takes the whole camera off. */
    x = seat[0] - 4 + oam_cam_x - g_cam_far_x;
    y = seat[1] - 8;
    cheer = (g_game_state.phase == GAME_PHASE_POINT_RESULT &&
            g_game_state.point_winner == 1) ||
        (g_game_state.phase == GAME_PHASE_MATCH_RESULT &&
            g_game_state.match_winner == 1);
    if (cheer && (g_game_state.frame_count & 8))
        y -= 2;
    /* KNOWN_ISSUES #24: at NIGHT the watcher is a silhouette in the dark
     * stands (the shadow palette: the stands behind at half brightness),
     * not lit like the players. Singles only, where it is palette 4. */
    attr = g_save.settings.time == COURT_TIMES - 1 ?
        OBJ_ATTR(g_objpal_shadow, 1) : OBJ_ATTR(g_players[2].palette, 1);
    if (seat[2]) {
        obj_put(RENDER_OAM_WATCHER, x, y, OBJTILE_PERSON_TOP, attr, 0);
        render_obj_hide(RENDER_OAM_WATCHER + 1);
    } else {
        obj_put(RENDER_OAM_WATCHER, x, y - 8, OBJTILE_PERSON_TOP, attr, 0);
        obj_put(RENDER_OAM_WATCHER + 1, x, y, OBJTILE_PERSON_LEGS, attr, 0);
    }
    s_watcher_shown = 1;
}

/*
 * The camera (ADR-050): the court leans a little toward the ball, as on
 * older consoles' sports games. Presentation only: it reads the ball and
 * never changes the match. At 100% (the OPTIONS page's CAMERA) the target
 * is a sixteenth of the ball's distance from the net across (up to 8 px)
 * and an eighth of it from the centre line along (up to 4 px), or the
 * centre with no ball in play; the setting scales it (85% by default, OFF
 * keeps it still). The camera eases toward it, an eighth of the way a
 * frame in 1/16 px, at most half a pixel a frame, so it drifts and never
 * jumps. The step is src/asm/camera.asm (in C it took about 8 scanlines).
 * BG1 scrolls by the whole-pixel camera in VBlank; oam_write takes it off
 * every object, so sprites stay on the court. The map has a mirrored tile
 * beyond each edge to pan into (scene.py: camera_map).
 */
s16 g_cam_fx;                           /* 1/16 px */
s16 g_cam_fy;
s16 g_cam_tx;                           /* this frame's target */
s16 g_cam_ty;
s16 g_cam_sign;                         /* camera.asm's scratch */
s16 g_cam_mag;
u8 g_cam_k;                             /* CAMERA in 1/128ths */
u8 g_cam_dirty;
/* Parallax (ADR-051): camera.asm's HDMA table halves for BG1's horizontal
 * scroll, the half it writes next, the backdrop's offset (half the
 * camera), and its scratch. */
u8 g_cam_hdma[2 * ASM_CAM_TABLE_BYTES];
u8 g_cam_back;
u8 g_cam_hdma_on;
u8 g_cam_new;                           /* a table to swap in */
s16 g_cam_built_fx;                     /* the camera the last table is for */
s16 g_cam_built_fy;
s16 g_cam_far_x;
s16 g_cam_acc;
s16 g_cam_step;
extern void render_camera_commit(void);
static u8 s_cam_saved;                  /* the g_save.camera g_cam_k is for */
extern void render_camera(void);

/* Centre the camera at once (a new court, or leaving it for another
 * screen, where nothing pans). */
void render_camera_reset(void)
{
    g_cam_fx = 0;
    g_cam_fy = 0;
    oam_cam_x = 0;
    oam_cam_y = 0;
    g_cam_dirty = 1;                    /* render_commit scrolls BG1 home */
    g_cam_far_x = 0;
    g_cam_back = 0;
    g_cam_hdma_on = 0;
    g_cam_new = 0;
    g_cam_built_fx = 0x7fff;            /* no table yet: build one */
    g_cam_built_fy = 0x7fff;
    REG_HDMAEN = 0;                     /* no parallax off the court */
    s_cam_saved = 0xff;                 /* g_cam_k on the next frame */
}

void render_prepare(void)
{
#ifdef RENDER_DIAGNOSTICS
    if (render_stress_active()) {
        render_camera_reset();
        diag_stress_render();
        return;
    }
#endif
    if (g_save.camera != s_cam_saved) {
        s_cam_saved = g_save.camera;
        g_cam_k = g_options_camera_k[options_camera_index(s_cam_saved)];
    }
    render_camera();
    render_players();
    PROFILE_MARK(2);
    render_ball();
    render_replay_ball();
    render_watcher();
    render_effects();
    /* The practice objects only in practice, and once more to hide them:
     * outside it their per-frame hides cost the doubles budget. */
    if ((g_match_config.practice && !g_attract) || s_practice_drawn) {
        render_machine();
        render_zone();
        s_practice_drawn = g_match_config.practice && !g_attract;
    }
    render_update_ground();
    PROFILE_MARK(3);
    hud_scene_update();
}

void render_commit(void)
{
    /* Range/time-over flags describe the frame just drawn; they clear at
     * the end of VBlank. */
    if (REG_STAT77_FLAGS & 0xC0)
        ++g_obj_overflow_frames;
#ifdef RENDER_DIAGNOSTICS
    if (s_palette_dirty && diag_upload_palettes())
        s_palette_dirty = 0;
#endif
    if (s_palette_dirty)
        render_upload_palettes();
    if (s_backdrop_dirty) {
        dmaCopyCGram((u8 *)s_backdrop, 48, sizeof(s_backdrop));
        s_backdrop_dirty = 0;
    }
    if (s_ground_dirty) {
        dmaCopyCGram((u8 *)s_ground_palette, 32, 32);
        s_ground_dirty = 0;
    }
    if (g_cam_dirty) {
        bgSetScroll(0, (u16)oam_cam_x, (u16)oam_cam_y);
        g_cam_dirty = 0;
    }
    render_camera_commit();             /* the parallax (ADR-051) */
    /* The card closed: the bust goes with the HUD's clear. */
    if (s_bust_shown && g_story.card == STORY_CARD_NONE) {
        bgSetDisable(1);
        s_bust_shown = 0;
    }
    render_commit_replay();
    hud_commit();
}

void render_initialize(void)
{
    u8 i;

    /* RAM is not cleared at power-on (real hardware or emulators that
     * randomize it), so every piece of renderer state is set explicitly. */
    s_palette_dirty = 0;
    s_keep_ambience = 0;
    s_zone_drawn = 0;
    s_practice_drawn = 1;          /* hidden on the first frame */
    s_ground_dirty = 0;
    s_dark_court = 0;
    s_ground_pending = 0;
    s_ground_waits = 0;
    s_backdrop_pending = 0;
    s_backdrop_dirty = 0;
    s_active_bodies = 0xff;
    g_obj_overflow_frames = 0;
    hud_scene_initialize();
#ifdef RENDER_DIAGNOSTICS
    diag_initialize();
#endif

    setScreenOff();
    oamInit();
    for (i = 0; i < 128; ++i)
        render_obj_hide(i);

    dmaCopyVram((u8 *)&hud_tiles, RENDER_BG3_TILES_ADDR,
        (u16)(&hud_tiles_end - &hud_tiles));
    dmaCopyVram((u8 *)&obj_tiles, RENDER_OBJ_TILES_ADDR,
        (u16)(&obj_tiles_end - &obj_tiles));
    dmaCopyCGram((u8 *)&hud_palette, 0,
        (u16)(&hud_palette_end - &hud_palette));

    bgSetGfxPtr(0, RENDER_BG1_TILES_ADDR);
    bgSetMapPtr(0, RENDER_BG1_MAP_ADDR, SC_64x32);
    bgSetGfxPtr(2, RENDER_BG3_TILES_ADDR);
    bgSetMapPtr(2, RENDER_BG3_MAP_ADDR, SC_32x32);
    oamInitGfxAttr(RENDER_OBJ_TILES_ADDR, OBJ_SIZE8_L32);

    setMode(BG_MODE1, BG3_MODE1_PRIORITY_HIGH);
    bgSetEnable(0);
    bgSetEnable(2);
    /* Shadows: OBJ palette 4 pixels are black and averaged with BG1 on the
     * subscreen, i.e. half-brightness court under every shadow. */
    bgSetEnableSub(0);

    render_load_court();
    setScreenOn();
}

/* The captain's bust on BG2 when the match opens on its intro card
 * (M4-STORY-03), else BG2 off; forced blank only. The map follows the
 * captain's variant; the colours are theirs. */
static void render_load_bust(void)
{
    u8 opponent = g_match_config.opponent;
    u8 i;

    /* The tiles (busts and the close call's) and a blank close-up map go
     * up with every court, BG2 off until a card or a close call. */
    dmaCopyVram((u8 *)&bust_tiles, RENDER_BG2_TILES_ADDR,
        (u16)(&bust_tiles_end - &bust_tiles));
    dmaCopyVram((u8 *)&bust_m_map, RENDER_BG2_REPLAY_MAP_ADDR,
        (u16)(&bust_m_map_end - &bust_m_map));
    bgSetGfxPtr(1, RENDER_BG2_BASE_ADDR);
    s_replay_shown = 0;
    s_replay_ball = 1;          /* parked on the first frame */
    s_watcher_shown = 1;
    s_bust_shown = g_story.card == STORY_CARD_INTRO &&
        opponent < OPPONENT_COUNT;
    if (!s_bust_shown) {
        bgSetDisable(1);
        return;
    }
    if (g_opponent_variant[opponent][0])
        dmaCopyVram((u8 *)&bust_f_map, RENDER_BG2_MAP_ADDR,
            (u16)(&bust_f_map_end - &bust_f_map));
    else
        dmaCopyVram((u8 *)&bust_m_map, RENDER_BG2_MAP_ADDR,
            (u16)(&bust_m_map_end - &bust_m_map));
    for (i = 0; i < 16; ++i)
        s_bust_palette[i] = g_opponent_palettes[opponent][0][i];
    s_bust_palette[RENDER_BUST_FRAME] = RGB5(21, 22, 26);
    s_bust_palette[RENDER_BUST_BACKDROP] = RGB5(13, 16, 21);
    dmaCopyCGram((u8 *)s_bust_palette, RENDER_BUST_CGRAM, 32);
    bgSetGfxPtr(1, RENDER_BG2_BASE_ADDR);
    bgSetMapPtr(1, RENDER_BG2_MAP_ADDR, SC_32x32);
    bgSetScroll(1, 0, 0);
    bgSetEnable(1);
}

/* Court scene into VRAM/CGRAM and the match HUD; forced blank only. Also
 * how the match returns from the Player Select screen. The venue is the
 * saved choice, or for AUTO the opponent's home court (ADR-024): shared
 * ground tiles first, then the venue's tiles, map, and palettes 3-7. */
static void render_load_court(void)
{
    u16 ground = (u16)(&court_tiles_end - &court_tiles);
    const VenueData *venue;

    /* Open play (ADR-034) is at the park: AUTO gives the first venue. */
    s_venue = court_style_venue(g_save.settings.venue,
        (g_attract || g_match_config.open_play) ? OPPONENT_NONE :
            g_match_config.opponent);
    /* The venue's ambience (ADR-031); loads only when the venue changed. */
    if (!s_keep_ambience)
        audio_ambience(court_style_ambience(s_venue, g_save.settings.time));
    venue = &g_venue_data[s_venue];
    dmaCopyVram((u8 *)&court_tiles, RENDER_BG1_TILES_ADDR, ground);
    dmaCopyVram((u8 *)venue->tiles, RENDER_BG1_TILES_ADDR + ground / 2,
        venue->tiles_size);
    dmaCopyVram((u8 *)venue->map, RENDER_BG1_MAP_ADDR, venue->map_size);
    /* 64x32 for the camera's edges (ADR-050); the park (M4-OPEN-05)
     * scrolls a 64x32 map of its own elsewhere. */
    bgSetMapPtr(0, RENDER_BG1_MAP_ADDR, SC_64x32);
    render_camera_reset();
    bgSetScroll(0, 0, 0);
    memcpy(s_backdrop_painted, venue->palettes, sizeof(s_backdrop_painted));
    render_compose_backdrop();
    dmaCopyCGram((u8 *)s_backdrop, 48, sizeof(s_backdrop));
    s_backdrop_dirty = 0;
    memcpy(s_painted_ground, &court_palette, sizeof(s_painted_ground));
    render_compose_ground();
    dmaCopyCGram((u8 *)s_ground_palette, 32, 32);
    s_ground_dirty = 0;
    render_load_bust();
    /* Match palettes are composed and uploaded inside this forced blank. */
    render_apply_match_config();
    render_upload_palettes();
    render_reset_bodies();

    hud_initialize();
    hud_scene_invalidate();
    render_prepare();
    hud_commit_all();
}

/* Slot 0's look alone (ADR-047: the career player previewed on the title
 * demo's P1): its palette, hat, and ponytail; uploads in render_commit. */
void render_apply_p1_look(void)
{
    match_compose_palette(0, s_player_palettes[0]);
    rb_hat[0] = s_hat_tiles[match_slot_hat(0)];
    if (g_players[0].variant != PLAYER_VARIANT_FEMALE)
        render_obj_hide(RENDER_OAM_ACCESSORIES);
    s_palette_dirty = 1;
}

u8 render_court_venue(void)
{
    return s_venue;
}

void render_preview_court(void)
{
    s_keep_ambience = 1;
    render_open_match();
    s_keep_ambience = 0;
}

void render_open_match(void)
{
    u8 i;

    render_fade(1);
    setScreenOff();
    for (i = 0; i < 128; ++i)
        render_obj_hide(i);
    s_zone_drawn = 0;
    s_practice_drawn = 1;          /* hidden on the first frame */
    render_load_court();
    render_fade(0);
}
