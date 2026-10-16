#ifndef RENDER_H
#define RENDER_H

#include "game_types.h"

/* VRAM word addresses; see docs/09_M1_VRAM_AND_BUILD.md. */
#define RENDER_BG1_MAP_ADDR 0x0000
/* The court's BG1 map is 64x32 (ADR-050, the camera): words 0x0000-0x07ff.
 * The HUD map sits past the HUD font (0x5000-0x58bf, 280 tiles). */
#define RENDER_BG3_MAP_ADDR 0x5C00
/* The intro card's bust (M4-STORY-03): BG2, only while the card is up.
 * The tile base steps by 0x1000 words, so BG2 counts from 0x4000 and the
 * bust tiles start 128 tiles in (tools/assetgen/select.py). */
#define RENDER_BG2_MAP_ADDR 0x0800
#define RENDER_BG2_BASE_ADDR 0x4000
#define RENDER_BG2_TILES_ADDR 0x4800
/* The close call's close-up (ADR-041): its own BG2 map, rows 15-21 written
 * when a point shows it. */
#define RENDER_BG2_REPLAY_MAP_ADDR 0x0C00
#define RENDER_BG1_TILES_ADDR 0x1000
#define RENDER_BG3_TILES_ADDR 0x5000
#define RENDER_OBJ_TILES_ADDR 0x6000

/*
 * OBJ palette layouts (ADR-018). Only palettes 0-3 are exempt from colour
 * math. Singles: players 0-1, objects 2, flash 3, translucent shadow 4.
 * Doubles: players 0-3, objects 4, flash 5, opaque shadow 6, math off.
 * Player.palette holds the player's slot in the active layout.
 */
enum {
    RENDER_OBJPAL_OBJECTS = 2,        /* singles values */
    RENDER_OBJPAL_FLASH = 3,
    RENDER_OBJPAL_SHADOW = 4,
    RENDER_OBJPAL_DOUBLES_OBJECTS = 4,
    RENDER_OBJPAL_DOUBLES_FLASH = 5,
    RENDER_OBJPAL_DOUBLES_SHADOW = 6
};

/* OAM entry indices (docs/03_SPRITE_ASSET_PIPELINE.md OAM allocation). */
enum {
    RENDER_OAM_BALL = 0,
    RENDER_OAM_BALL_SHADOW = 1,
    /* 2-13: a group per player, nearest-first (ADR-012): the hat's two
     * halves (M4-OPP-04), then the body. A lower entry draws in front, so
     * a hat covers its own body's cap and stays behind nearer players. */
    RENDER_OAM_BODIES = 2,
    RENDER_OAM_GROUP_SIZE = 3,
    RENDER_OAM_GROUP_BODY = 2,    /* the body's entry in its group */
    RENDER_OAM_SHADOWS = 14,      /* 14-17: by slot */
    RENDER_OAM_SPARK = 18,        /* 18-21: impact effects reserve */
    RENDER_OAM_DEBUG_MARKER = 19,
    RENDER_OAM_ACCESSORIES = 22,  /* 22-25: ponytails by slot (ADR-014) */
    RENDER_OAM_MACHINE = 26,      /* 26-29: practice ball machine (ADR-028) */
    RENDER_OAM_REPLAY = 30,       /* 30-31: the close call's ball and shadow
                                     (ADR-041) */
    RENDER_OAM_WATCHER = 32,      /* 32-33: the opponent's partner watching
                                     a singles match (ADR-042) */
    RENDER_OAM_ZONE = 34,         /* 34-37: practice return zone corners */
    RENDER_OAM_FIRST_HIDDEN = 38
};

void render_initialize(void);
/* The camera (ADR-050) back to the centre at once; for screens that don't
 * pan (Player Select, the park) and a new court. */
void render_camera_reset(void);
/* Composes player palettes and HUD team colours from g_match_config; the
 * upload happens in the next render_commit (or immediately in forced blank
 * during render_initialize). */
void render_apply_match_config(void);
/* Recomposes the ground palette from the saved court colours (ADR-022);
 * uploaded in render_commit's VBlank. */
void render_apply_court_colors(void);
/* The saved TIME changed (ADR-045): the ground and the backdrop recompose
 * on light frames and upload in VBlank. */
void render_apply_court_time(void);
/* Slot 0's palette, hat, and ponytail again (the career preview). */
void render_apply_p1_look(void);
/* Mode whose palettes/colour math are currently set up. */
u8 render_match_mode_applied(void);
/* Scene switches with a fade (ADR-020): the court and match HUD from the
 * current g_match_config, or the Player Select screen. */
void render_open_match(void);
/* The venue the court shows (resolved: never AUTO). */
u8 render_court_venue(void);
/* render_open_match without the venue's ambience (M4-VENUE-02): loading a
 * sound module takes about 45 frames, too long for a preview. */
void render_preview_court(void);
void render_select_open(void);
/* Player Select frame: buffers before VBlank, uploads inside it. */
void render_select_prepare(void);
void render_select_commit(void);
/* The open play park (ADR-034): opens with a fade; a frame's buffers
 * before VBlank, uploads inside it. */
void render_park_open(void);
void render_park_prepare(void);
void render_park_commit(void);
/* Brightness fade out (1) or in (0) over a few frames. */
void render_fade(u8 out);
/* Builds OAM and HUD buffers; call before WaitForVBlank. */
void render_prepare(void);
/* VBlank-only uploads (HUD bands, pending palettes). */
void render_commit(void);

/* Set when render_prepare did heavy work this frame (a ground recolour):
 * hud_scene_update then waits a frame with its own, and clears it. */
extern u8 g_render_busy;

/* Frames on which the PPU reported OBJ range/time over ($213E bits 6/7). */
extern u16 g_obj_overflow_frames;

#if defined(BUILD_DEBUG) || defined(BUILD_HARDWARE_TEST)
#define RENDER_DIAGNOSTICS 1
/* OBJ stress scene (M3-OBJ-01): toggled with Select in diagnostic builds. */
void render_stress_toggle(void);
u8 render_stress_active(void);
#endif

#endif
