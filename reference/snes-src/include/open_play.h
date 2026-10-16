#ifndef OPEN_PLAY_H
#define OPEN_PLAY_H

#include "game_types.h"
#include "player.h"

/*
 * Open play (docs/decisions/ADR-034-open-play.md): a park with three
 * courts. Each court has a game going and a paddle stack: paddles in line
 * for the next game. Entries are ladder teams (ADR-023, a pair each) or
 * you. When a game ends all four come off and the top two entries go on;
 * the players coming off join the back of a stack. You walk the park, put
 * your paddle in a court's stack, and play when your turn comes. Pure:
 * render_park.c draws it and main.c runs the match.
 *
 * The courts are skill levels (ADR-034, amended): <3.5, 3.5-4.5, and 4.5+.
 * Each ladder team calls one home (the ladder's order is its difficulty),
 * and your game there is EASY, MEDIUM, or HARD.
 */

enum {
    OPEN_COURTS = 3,
    OPEN_STACK_MAX = 4,         /* entries waiting at one court */
    OPEN_YOU = 0x80,            /* an entry: you (and a regular partner) */
    OPEN_NONE = 0xff,
    OPEN_GAME_POINTS = 7,       /* the park's own games: first to 7 */
    /* A point every 1 to 3 s, so a game lasts about half a minute. */
    OPEN_POINT_MIN_FRAMES = 60,
    OPEN_POINT_SPAN_FRAMES = 128,  /* a power of two (a mask, no divide) */
    OPEN_CHANGEOVER_FRAMES = 120,   /* players walk off, then a pause */
    OPEN_WALK_FRAMES = 64,          /* walking off, or on before a game */
    OPEN_CALL_FRAMES = 150,         /* "YOUR GAME!" before the match */

    /* Park layout in pixels: two screens wide (OPEN_PARK_W x 224), the
     * view scrolling with you (M4-OPEN-05). The courts are on the first
     * screen; they run top to bottom, and the path along the bottom has a
     * paddle rack at each court's gate. */
    OPEN_PARK_W = 512,
    OPEN_COURT_W = 56,
    OPEN_COURT_H = 112,
    OPEN_COURT_TOP = 48,
    OPEN_COURT_LEFT0 = 20,
    OPEN_COURT_PITCH = 80,          /* court n's left edge: 20 + 80 n */
    OPEN_RACK_Y = OPEN_COURT_TOP + OPEN_COURT_H + 10,
    OPEN_RACK_DX = OPEN_COURT_W / 2,    /* the rack at the court's gate */
    OPEN_RACK_REACH = 14,           /* B works within this of a rack */
    OPEN_PEEK_REACH = 28,           /* the HUD names a court this close */

    /* You: a ground point (feet), in 12.4. */
    OPEN_START_X = 128,
    OPEN_START_Y = 196,
    OPEN_WALK_FP = 20,              /* 1.25 px per frame */
    OPEN_WALK_TOP = 30,
    OPEN_WALK_BOTTOM = 210,
    OPEN_WALK_LEFT = 8,
    OPEN_WALK_RIGHT = 504,
    OPEN_FENCE_MARGIN = 4,          /* feet stay this far off a fence */

    /* The clubhouse (M4-OPEN-05), on the second screen: a room seen from
     * above, its walls solid, a door in the bottom wall onto the path. */
    OPEN_HOUSE_LEFT = 296,
    OPEN_HOUSE_RIGHT = 488,
    OPEN_HOUSE_TOP = 40,
    OPEN_HOUSE_BOTTOM = 168,
    OPEN_HOUSE_WALL = 6,
    OPEN_HOUSE_DOOR_X = 392,        /* the door's middle */
    OPEN_HOUSE_DOOR_W = 28,
    /* Inside: B within OPEN_SPOT_REACH of the records board (on the top
     * wall) or the ball machine; the waiting teams sit on the bench (its
     * left end), four people 12 px apart. */
    OPEN_BOARD_X = 336,
    OPEN_BOARD_Y = 64,
    OPEN_MACHINE_X = 452,
    OPEN_MACHINE_Y = 84,
    OPEN_BENCH_X = 344,
    OPEN_BENCH_Y = 132,
    OPEN_SPOT_REACH = 16,
    OPEN_BOARD_PAGES = 4            /* records shown, one per B */
};

typedef enum {
    OPEN_COURT_PLAYING = 0,
    OPEN_COURT_CHANGEOVER = 1,      /* between games */
    OPEN_COURT_YOURS = 2            /* your game: the match is on */
} OpenCourtState;

typedef struct {
    u8 state;
    u8 playing[2];              /* the two entries on court (top, bottom) */
    u8 score[2];
    u8 stack[OPEN_STACK_MAX];   /* next first */
    u8 stack_count;
    u16 timer;                  /* frames to the next point or game */
    u8 rally;                   /* animation: frames into the rally */
    u8 age;                     /* frames since this game began (to 255):
                                   the new players walk on first */
} OpenCourt;

/* open_play_update results. */
enum {
    OPEN_EVENT_NONE = 0,
    OPEN_EVENT_STACKED = 1,     /* your paddle went into a stack */
    OPEN_EVENT_UNSTACKED = 2,   /* you took it back */
    OPEN_EVENT_FULL = 3,        /* that stack has no room */
    OPEN_EVENT_CALLED = 4,      /* your game is up: the call banner */
    OPEN_EVENT_PLAY = 5,        /* the banner is done: start the match */
    OPEN_EVENT_BOARD = 6,       /* B at the records board: the next page */
    OPEN_EVENT_PRACTICE = 7     /* B at the ball machine: start practice */
};

typedef struct {
    OpenCourt court[OPEN_COURTS];
    fx x_fp;                    /* you */
    fx y_fp;
    u8 facing_left;
    u8 walking;
    u8 step;                    /* walk animation frame counter */
    u8 your_court;              /* the court your paddle waits at, or none */
    u8 called;                  /* the court calling you, or OPEN_NONE */
    u8 call_timer;
    u8 opponent;                /* your opponents' team, when called */
    u8 partner;                 /* the team next in line: its captain
                                   partners you; OPEN_NONE: the regular */
    u16 seed;
    u8 lineup;                  /* changes when anyone comes on or off */
    u8 stacks;                  /* changes when any stack changes */
    u8 two_players;             /* 2P is with you: your partner */
    u8 last_won;                /* your last game: 1 won, 0 lost, none */
    u8 last_score[2];           /* yours, theirs */
    u8 board_page;              /* the records board's page, or OPEN_NONE */
} OpenPlay;

extern OpenPlay g_open_play;

/* A fresh park: six teams playing, two waiting, you at the gate; with
 * two_players, 2P comes along as your partner. */
void open_play_begin(u16 seed, u8 two_players);
/* One park frame: walking (the D-pad), B at a rack, the courts' games.
 * Returns OPEN_EVENT_*. While called, input is ignored. */
u8 open_play_update(s16 move_x, s16 move_y, u8 b_pressed);
/* Back from your match: you won or lost by this score; your court's game
 * ends and the next one starts. */
void open_play_return(u8 won, u8 points_for, u8 points_against);

/* A court's skill level as text ("<3.5", "3.5-4.5", "4.5+"), and the
 * difficulty (ADR-025) of your game there: EASY, MEDIUM, HARD; KID (the
 * saved difficulty) stays KID, for its swing assist. */
const char *open_court_level_name(u8 court);
u8 open_court_difficulty(u8 court, u8 saved_difficulty);
/* The court a ladder team plays at. */
u8 open_team_court(u8 team);

/* Court geometry and lookups (render_park.c and the HUD). */
s16 open_court_left(u8 court);
s16 open_rack_x(u8 court);
/* The rack within reach of you, or OPEN_NONE. */
u8 open_rack_near(void);
/* The court you are next to (for the HUD's peek), or OPEN_NONE. */
u8 open_court_near(void);
/* Your place in your stack: 0 = next game, 1 = the one after; OPEN_NONE
 * when not stacked. Two entries per game. */
u8 open_your_wait(void);
/* Nonzero when a ground point is walkable (not inside a fenced court or a
 * clubhouse wall). */
u8 open_walkable(fx x_fp, fx y_fp);
/* The clubhouse (M4-OPEN-05): nonzero when you are inside; within reach
 * of the records board or the ball machine; near the bench. */
u8 open_in_house(void);
u8 open_board_near(void);
u8 open_machine_near(void);
u8 open_bench_near(void);
/* The nth team waiting in a stack (stack order, court by court), or
 * OPEN_NONE: the bench shows the first two. */
u8 open_waiting_team(u8 n);

#endif
