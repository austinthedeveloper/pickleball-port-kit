#ifndef CAREER_PAGE_H
#define CAREER_PAGE_H

#include "game_types.h"
#include "career.h"

/*
 * The CAREER page (ADR-047, M4-CAREER-02): the title's RECORDS entry. Pure
 * input logic, like the court and options editors; hud_scene.c draws it
 * and main.c acts on the results.
 *
 *   SLOTS   the three players, NO PLAYER, and RECORDS. B opens a player
 *           (making them active), creates one in an empty slot, or on NO
 *           PLAYER makes nobody active; Y leaves.
 *   CARD    the player's stats and unlocks. B edits; L+R+X deletes; Y back.
 *   EDIT    name and look. Up/Down rows, Left/Right values (locked hair and
 *           hats are skipped); B on NAME types it, B elsewhere keeps, Y
 *           puts the look back (and drops a player just created).
 *           Typing is an arcade keyboard: the D-pad picks a key, B types
 *           it, DEL or Y erases the last letter, END or Start is done; Y
 *           with nothing to erase backs out (a new player is dropped, an
 *           old one keeps their name).
 *   RECORDS the old records table. L+R+X erases; B, Y, or Start back.
 */
enum {
    CAREER_VIEW_SLOTS = 0,
    CAREER_VIEW_CARD = 1,
    CAREER_VIEW_EDIT = 2,
    CAREER_VIEW_RECORDS = 3
};

/* SLOTS rows: a row per slot, NO PLAYER (nobody active: matches as
 * before, no stats), then RECORDS. */
enum {
    CAREER_ROW_NOBODY = CAREER_SLOTS,
    CAREER_ROW_RECORDS = CAREER_SLOTS + 1,
    CAREER_SLOT_ROWS = CAREER_SLOTS + 2
};

/* EDIT rows. */
enum {
    CAREER_EDIT_NAME = 0,
    CAREER_EDIT_BODY = 1,
    CAREER_EDIT_SKIN = 2,
    CAREER_EDIT_HAIR = 3,
    CAREER_EDIT_SHIRT = 4,
    CAREER_EDIT_HAT = 5,
    CAREER_EDIT_PADDLE = 6,
    CAREER_EDIT_ROWS = 7
};

/* career_page_input results. */
enum {
    CAREER_PAGE_STAY = 0,
    CAREER_PAGE_CLOSE = 1,      /* back to the title menu */
    CAREER_PAGE_SAVE = 2        /* stay; write the save */
};

/* The name keyboard: rows of CAREER_KEY_COLS letters ("A".."Z", space,
 * "-"), then DEL and END on a row of their own. */
enum {
    CAREER_KEY_CHARS = 28,
    CAREER_KEY_COLS = 10,
    CAREER_KEY_ROWS = 4,        /* three of letters, one of DEL and END */
    CAREER_KEY_DEL = 28,
    CAREER_KEY_END = 29,
    CAREER_KEYS = 30
};
extern const char g_career_key_chars[CAREER_KEY_CHARS + 1];

typedef struct {
    u8 view;
    u8 row;
    u8 slot;                    /* the player on the CARD and EDIT views */
    u8 naming;                  /* typing the name */
    u8 cursor;                  /* letters typed (the next goes here) */
    u8 creating;                /* a new player: Y drops them */
    u8 key_row;                 /* the keyboard key picked */
    u8 key_col;
    u8 look_changed;            /* the look changed: the caller re-previews
                                   it and clears this */
    CareerPlayer original;      /* the player when EDIT opened */
} CareerPage;

extern CareerPage g_career_page;

/* Opens on SLOTS, the cursor on the active player (else the first slot). */
void career_page_begin(void);
/* One frame of input: newly pressed and held buttons. */
u8 career_page_input(u16 pressed, u16 held);

/* The keyboard key picked: 0..CAREER_KEY_CHARS-1 a letter, else DEL or
 * END. */
u8 career_page_key(void);

/* Display names. */
const char *career_body_name(u8 variant);
const char *career_shirt_name(u8 shirt);
const char *career_paddle_name(u8 paddle);
/* A look row's value on the player (EDIT rows BODY to PADDLE). */
u8 career_look_value(const CareerPlayer *player, u8 row);
/* The next unlock the player has not earned, or CAREER_UNLOCKS. */
u8 career_next_unlock(const CareerPlayer *player);
/* How many unlocks the player holds. */
u8 career_unlock_count(const CareerPlayer *player);

#endif
