#ifndef OPTIONS_H
#define OPTIONS_H

#include "game_types.h"
#include "opponents.h"

/*
 * Options (docs/decisions/ADR-025-options.md): points to win and
 * difficulty, kept in the save. Pure: game.c, ai.c, and main.c apply them.
 */

typedef enum {
    DIFFICULTY_KID = 0,         /* slowest ball, swings for you, easiest CPU */
    DIFFICULTY_EASY = 1,        /* slow ball, easier CPU */
    DIFFICULTY_MEDIUM = 2,      /* the shipped game */
    DIFFICULTY_HARD = 3,        /* normal ball, harder CPU */
    DIFFICULTY_COUNT = 4
} Difficulty;

enum {
    OPTIONS_POINTS_DEFAULT = 5,
    OPTIONS_POINT_CHOICES = 7,
    /* The ball's step pattern repeats every 60 frames: KID's 2 in 3 and
     * EASY's 3 in 4 divide it, and BALL SPEED's 5% steps (ADR-049). */
    OPTIONS_BALL_CYCLE = 60,
    /* BALL SPEED: 70% to 120% in 5% steps; saved as choice + 1, so 0 (every
     * older save) is the default, 100%. */
    OPTIONS_SPEED_CHOICES = 11,
    OPTIONS_SPEED_DEFAULT = 6,
    /* CAMERA (ADR-050): OFF, then 50% to 100% in 5% steps; saved as choice
     * + 1, so 0 (every older save) is the default, OFF (85% was tried as
     * the default first). */
    OPTIONS_CAMERA_CHOICES = 12,
    OPTIONS_CAMERA_DEFAULT = 0
};

/* 0 (OFF), 50, 55, ... 100 (percent of the camera's full lean). */
extern const u8 g_options_cameras[OPTIONS_CAMERA_CHOICES];
/* The same as a multiplier in 1/128ths (percent * 128 / 100, rounded), for
 * the hardware multiplier in render.c. */
extern const u8 g_options_camera_k[OPTIONS_CAMERA_CHOICES];

/* 70, 75, ... 120 (percent). */
extern const u8 g_options_speeds[OPTIONS_SPEED_CHOICES];

/* 3, 5, 7, 9, 11, 15, 21. */
extern const u8 g_options_points[OPTIONS_POINT_CHOICES];

/* A saved value, or the default when it is not a valid choice. */
u8 options_points(u8 saved);
u8 options_difficulty(u8 saved);
const char *options_difficulty_name(u8 difficulty);

/* A CPU opposing the humans plays this much better or worse: the late
 * period (mistakes), reaction, and speed of its style change. */
void options_apply_difficulty(AiStyle *style, u8 difficulty);
/* BALL SPEED (ADR-049): a saved choice's percent (0 or invalid: 100). */
u8 options_ball_speed(u8 saved);
/* Ball steps in one OPTIONS_BALL_CYCLE: the difficulty's share (KID 2 in
 * 3, EASY 3 in 4, else all) times the ball speed. Over 60 the ball takes
 * two steps on some frames. Arcs and bounces are unchanged. */
u8 options_ball_per_cycle(u8 difficulty, u8 percent);
/* CAMERA (ADR-050): a saved choice as its index (0 or invalid: OFF). */
u8 options_camera_index(u8 saved);

/* Options page editor (like the court page, ADR-022). */
enum { OPTIONS_ROW_POINTS = 0, OPTIONS_ROW_DIFFICULTY = 1,
       OPTIONS_ROW_SOUND = 2, OPTIONS_ROW_SPEED = 3, OPTIONS_ROW_CAMERA = 4,
       OPTIONS_ROWS = 5 };
enum { OPTIONS_EDIT_STAY = 0, OPTIONS_EDIT_DONE = 1, OPTIONS_EDIT_CANCEL = 2 };

typedef struct {
    u8 row;
    u8 original_points;
    u8 original_difficulty;
    u8 original_sound;
    u8 original_speed;
    u8 original_camera;
} OptionsEdit;

extern OptionsEdit g_options_edit;

/* Opens the editor on the saved values (made valid in place); sound is an
 * AUDIO_* setting (ADR-029). */
void options_edit_begin(u8 *points, u8 *difficulty, u8 *sound, u8 *speed,
    u8 *camera);
/* Up/Down rows, Left/Right values (wrapping), B or Start keeps, Y cancels.
 * speed is the saved BALL SPEED (choice + 1). */
u8 options_edit_input(u8 *points, u8 *difficulty, u8 *sound, u8 *speed,
    u8 *camera, u16 pressed);
u8 options_edit_changed(u8 points, u8 difficulty, u8 sound, u8 speed,
    u8 camera);

#endif
