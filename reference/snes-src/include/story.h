#ifndef STORY_H
#define STORY_H

#include "game_types.h"

/*
 * Story cards (docs/decisions/ADR-026-story-cards.md). The intro card
 * shows before a ladder match from Player Select; the match waits under it.
 * The result lines are drawn from the match state (hud_scene.c). The
 * initials card (ADR-040) opens on the match result after a new record,
 * arcade style, and the result waits under it. Pure.
 */

enum {
    STORY_CARD_NONE = 0,
    STORY_CARD_INTRO = 1,
    STORY_CARD_INITIALS = 2,
    STORY_CARD_UNLOCK = 3       /* ADR-047: the career unlocks just earned */
};
enum {
    STORY_INTRO_MIN_FRAMES = 30,    /* a held button cannot skip it */
    STORY_INTRO_FRAMES = 300,       /* then it goes by itself (5 s) */
    STORY_INITIALS_MIN_FRAMES = 30, /* mashing B past the result can't
                                       enter AAA */
    STORY_INITIALS_FRAMES = 1800,   /* then the letters shown are kept */
    STORY_UNLOCK_MIN_FRAMES = 30,   /* the unlock card, like the intro */
    STORY_UNLOCK_FRAMES = 300,
    STORY_REPEAT_DELAY = 16,        /* a held Up/Down repeats after this, */
    STORY_REPEAT_FRAMES = 4         /* then every this many frames */
};

/* The captain's bust on the intro card (M4-STORY-03): a 6x6-tile BG2
 * frame, centred between the rung (row 14) and the prompt (row 24).
 * tools/assetgen/select.py reads these. */
#define STORY_BUST_COL 13
#define STORY_BUST_ROW 16
#define STORY_BUST_TILES 6

typedef struct {
    u8 card;
    u16 timer;
    /* The initials card: the letters, the one being chosen, and how long
     * Up or Down has been held. */
    u8 letters[3];
    u8 cursor;
    u8 held_frames;
} StoryState;

extern StoryState g_story;

/* No card. Call at boot: RAM is not cleared at power-on, and a stray card
 * value would freeze the attract demo under an invisible card. */
void story_initialize(void);
/* Shows the intro card when the match has a ladder opponent. */
void story_begin_intro(void);
/* Shows the initials card when a record was beaten (g_save_new_records)
 * outside the attract demo, starting from the last initials entered. */
void story_begin_initials(void);
/* Shows the unlock card (ADR-047) when the career player just earned
 * unlocks (g_career_new_unlocks), outside the attract demo; it clears them
 * when it closes. After the initials card, on the match result. */
void story_begin_unlock(void);
/* Quips (GOOFY_IDEAS.md): the line the side that lost the point says, or
 * 0 (about two points in three). A ladder team speaks its own lines, a
 * human side and the default CPU the generic ones. roll varies the pick
 * (the frame count); the line just said is not said again next. */
const char *story_quip(u8 loser, u16 roll);
/* One frame of 1P's newly pressed and held buttons. Intro: B, A, or Start
 * ends it after STORY_INTRO_MIN_FRAMES. Initials: Up and Down change the
 * letter (held, they repeat), B, A, or Right moves to the next and past the
 * third saves them, Y or Left goes back, Start saves them; after
 * STORY_INITIALS_MIN_FRAMES. Nonzero while a card stays up. The caller
 * keeps that frame's input from the match even when the card closes. */
u8 story_update(u16 pressed, u16 held);

#endif
