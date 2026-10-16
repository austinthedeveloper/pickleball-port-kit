#ifndef PRACTICE_H
#define PRACTICE_H

#include "game_types.h"
#include "input.h"

/*
 * Practice mode (docs/decisions/ADR-028-practice.md): a ball machine on the
 * far baseline feeds the chosen shot to the chosen target; returns that
 * land in (in the chosen return zone, if any) count toward a streak. No
 * points, no serves, no rules faults.
 */

typedef enum {
    PRACTICE_SHOT_DRIVE = 0, PRACTICE_SHOT_LOB = 1, PRACTICE_SHOT_DINK = 2,
    PRACTICE_SHOT_MIX = 3, PRACTICE_SHOTS = 4
} PracticeShot;

typedef enum {
    PRACTICE_TARGET_KITCHEN = 0, PRACTICE_TARGET_DEEP = 1,
    PRACTICE_TARGET_FOREHAND = 2, PRACTICE_TARGET_BACKHAND = 3,
    PRACTICE_TARGET_AT_YOU = 4, PRACTICE_TARGET_RANDOM = 5,
    PRACTICE_TARGETS = 6
} PracticeTarget;

typedef enum {
    PRACTICE_RATE_SLOW = 0, PRACTICE_RATE_NORMAL = 1, PRACTICE_RATE_FAST = 2,
    PRACTICE_RATES = 3
} PracticeRate;

/* Where returns must land to count (M4-PRACTICE-03), on the machine's
 * side. LEFT and RIGHT are P1's, facing the net: the far and near
 * sidelines. */
typedef enum {
    PRACTICE_ZONE_ANY = 0, PRACTICE_ZONE_KITCHEN = 1, PRACTICE_ZONE_DEEP = 2,
    PRACTICE_ZONE_LEFT = 3, PRACTICE_ZONE_RIGHT = 4, PRACTICE_ZONES = 5
} PracticeZone;

/* Each zone's ground rectangle: x0, y0, x1, y1, edges in (ANY: the side). */
extern const s16 g_practice_zone_rects[PRACTICE_ZONES][4];

enum {
    /* The machine: on the far baseline, centred; feeds leave its nozzle
     * (the sprite's left edge, 8 px up; render.c draws it there). */
    PRACTICE_MACHINE_X = 232,
    PRACTICE_MACHINE_Y = 130,
    PRACTICE_MACHINE_Z = 8,
    PRACTICE_FIRST_FEED_FRAMES = 60,
    PRACTICE_FEED_TIMEOUT_FRAMES = 300, /* a stuck feed ends anyway */
    PRACTICE_STREAK_MAX = 99,           /* two digits on the score panel */
    /* The nozzle turns one pose per PRACTICE_TURN_FRAMES toward the next
     * feed's lane (up through centre to down), and kicks back on a feed. */
    PRACTICE_TURN_FRAMES = 6,
    PRACTICE_KICK_FRAMES = 6,
    PRACTICE_AIM_SPREAD = 12,           /* lanes this far off centre turn */
    PRACTICE_ZONE_DEEP_DEPTH = 36,      /* the DEEP zone, from the baseline */
    PRACTICE_ZONE_LINE_WIDTH = 22,      /* LEFT and RIGHT, from the sideline */
    PRACTICE_ZONE_FLASH_FRAMES = 32     /* the zone's corners blink on a hit */
};

/* Nozzle poses, as seen on screen: toward the far sideline (up), the
 * centre, or the near sideline (down). */
enum { PRACTICE_POSE_UP = 0, PRACTICE_POSE_CENTER = 1, PRACTICE_POSE_DOWN = 2 };

/* Feed state. */
enum { PRACTICE_WAIT = 0, PRACTICE_FEED = 1, PRACTICE_RETURN = 2 };

typedef struct {
    u8 shot;            /* settings for this session */
    u8 target;
    u8 rate;
    u8 zone;            /* PRACTICE_ZONE_* */
    u8 zone_flash;      /* frames left of the corners' blink */
    u8 state;
    u16 timer;          /* frames until the next feed, or in this feed */
    u8 streak;
    u8 best;            /* this session, with the saved best folded in */
    u8 feeds;           /* drives the lanes and the MIX/RANDOM pattern */
    u8 rng;
    u8 last_shot;       /* ShotType of the last feed */
    u8 next_shot;       /* the planned next feed: ShotType, dink, target */
    u8 next_dink;
    u8 next_target;
    s16 next_tx;        /* where it lands (AT YOU follows P1 in the wait) */
    s16 next_ty;
    u8 aim;             /* PRACTICE_AIM_* toward next_ty */
    u8 pose;            /* the nozzle on screen, turning toward aim */
    u8 turn_timer;
    u8 kick;            /* frames left of the feed's kick */
} PracticeState;

extern PracticeState g_practice;

/* Settings (saved): a valid value, or the default. */
u8 practice_shot(u8 saved);
u8 practice_target(u8 saved);
u8 practice_rate(u8 saved);
u8 practice_zone(u8 saved);
const char *practice_shot_name(u8 shot);
const char *practice_target_name(u8 target);
const char *practice_rate_name(u8 rate);
const char *practice_zone_name(u8 zone);
/* The saved best streak for a zone (ANY: the plain streak). */
u16 practice_saved_best(u8 zone);
/* A ground point (whole pixels) in a zone's rectangle. */
u8 practice_in_zone(u8 zone, s16 x, s16 y);
/* Frames between one feed ending and the next. */
u16 practice_rate_frames(u8 rate);

/* Starts a session (called by game_new_match in practice): no serve; the
 * first feed comes after PRACTICE_FIRST_FEED_FRAMES. */
void practice_begin(void);
/* One frame of the session, after the players moved (game_update). */
void practice_update(const PlayerIntent intents[MAX_PLAYERS]);
/* Leaving practice: a new best streak (for the session's zone) is saved. */
void practice_finish(void);

/* Practice page editor (like OPTIONS, ADR-025). */
enum { PRACTICE_ROW_SHOT = 0, PRACTICE_ROW_TARGET = 1, PRACTICE_ROW_RATE = 2,
       PRACTICE_ROW_ZONE = 3, PRACTICE_ROWS = 4 };
enum { PRACTICE_EDIT_STAY = 0, PRACTICE_EDIT_DONE = 1,
       PRACTICE_EDIT_CANCEL = 2 };

typedef struct {
    u8 row;
    u8 original[PRACTICE_ROWS];
} PracticeEdit;

extern PracticeEdit g_practice_edit;

/* values: shot, target, rate, zone (the saved settings, made valid in
 * place). */
void practice_edit_begin(u8 values[PRACTICE_ROWS]);
/* Up/Down rows, Left/Right values (wrapping), B or Start plays, Y cancels. */
u8 practice_edit_input(u8 values[PRACTICE_ROWS], u16 pressed);
u8 practice_edit_changed(const u8 values[PRACTICE_ROWS]);

#endif
