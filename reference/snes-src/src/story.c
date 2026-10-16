#include "career.h"
#include "game.h"
#include "input.h"
#include "match.h"
#include "opponents.h"
#include "save.h"
#include "story.h"

StoryState g_story;
/* The initials entered last this session: the next card starts there. */
static u8 s_last[3];
/* The quip said last (story_quip): not said again next. */
static const char *s_last_quip;

void story_initialize(void)
{
    g_story.card = STORY_CARD_NONE;
    g_story.timer = 0;
    s_last_quip = 0;
    s_last[0] = 'A';
    s_last[1] = 'A';
    s_last[2] = 'A';
}

void story_begin_initials(void)
{
    /* Two tests, not `g_attract || !g_save_new_records`: 816-tcc
     * miscompiles `|| !` (CLAUDE.md), and the attract demo's matches
     * opened this card. */
    if (g_attract)
        return;
    if (g_save_new_records == 0)
        return;
    g_story.card = STORY_CARD_INITIALS;
    g_story.timer = 0;
    g_story.cursor = 0;
    g_story.held_frames = 0;
    g_story.letters[0] = s_last[0];
    g_story.letters[1] = s_last[1];
    g_story.letters[2] = s_last[2];
}

/* A letter step, A to Z around. */
static void story_letter(s16 step)
{
    u8 *letter = &g_story.letters[g_story.cursor];

    if (step > 0)
        *letter = *letter == 'Z' ? 'A' : *letter + 1;
    else
        *letter = *letter == 'A' ? 'Z' : *letter - 1;
}

static void story_save_initials(void)
{
    s_last[0] = g_story.letters[0];
    s_last[1] = g_story.letters[1];
    s_last[2] = g_story.letters[2];
    save_set_initials(g_story.letters);
    g_story.card = STORY_CARD_NONE;
}

static u8 story_update_initials(u16 pressed, u16 held)
{
    u16 vertical = held & (PAD_UP | PAD_DOWN);

    ++g_story.timer;
    if (g_story.timer >= STORY_INITIALS_FRAMES) {
        story_save_initials();
        return 0;
    }
    /* Up/Down: a press steps; held, it repeats. */
    if (pressed & (PAD_UP | PAD_DOWN)) {
        story_letter((pressed & PAD_UP) ? 1 : -1);
        g_story.held_frames = 0;
    } else if (vertical) {
        if (++g_story.held_frames >= STORY_REPEAT_DELAY) {
            g_story.held_frames -= STORY_REPEAT_FRAMES;
            story_letter((vertical & PAD_UP) ? 1 : -1);
        }
    } else {
        g_story.held_frames = 0;
    }
    if (g_story.timer < STORY_INITIALS_MIN_FRAMES)
        return 1;
    if (pressed & PAD_START) {
        story_save_initials();
        return 0;
    }
    if (pressed & (PAD_B | PAD_A | PAD_RIGHT)) {
        if (g_story.cursor == 2) {
            story_save_initials();
            return 0;
        }
        ++g_story.cursor;
    } else if ((pressed & (PAD_Y | PAD_LEFT)) && g_story.cursor) {
        --g_story.cursor;
    }
    return 1;
}

const char *story_quip(u8 loser, u16 roll)
{
    const char *const *lines;
    u8 pick;

    if (roll % 3 != 0)
        return 0;
    if (loser == 0)
        lines = g_side_quips[QUIPS_PLAYER];
    else if (g_match_config.opponent < OPPONENT_COUNT)
        lines = g_opponent_quips[g_match_config.opponent];
    else if (g_match_config.human[2])
        lines = g_side_quips[QUIPS_PLAYER];
    else
        lines = g_side_quips[QUIPS_CPU];
    pick = (u8)((roll >> 2) & (OPPONENT_QUIPS - 1));
    if (lines[pick] == s_last_quip)
        pick = (u8)((pick + 1) & (OPPONENT_QUIPS - 1));
    s_last_quip = lines[pick];
    return s_last_quip;
}

void story_begin_unlock(void)
{
    if (g_attract)
        return;
    if (g_career_new_unlocks == 0)
        return;
    g_story.card = STORY_CARD_UNLOCK;
    g_story.timer = 0;
}

void story_begin_intro(void)
{
    g_story.timer = 0;
    g_story.card = (!g_attract && g_match_config.opponent != OPPONENT_NONE) ?
        STORY_CARD_INTRO : STORY_CARD_NONE;
}

u8 story_update(u16 pressed, u16 held)
{
    if (g_story.card == STORY_CARD_NONE)
        return 0;
    if (g_story.card == STORY_CARD_INITIALS)
        return story_update_initials(pressed, held);
    ++g_story.timer;
    if (g_story.card == STORY_CARD_UNLOCK) {
        if (g_story.timer >= STORY_UNLOCK_FRAMES ||
                (g_story.timer >= STORY_UNLOCK_MIN_FRAMES &&
                 (pressed & (PAD_B | PAD_A | PAD_START)))) {
            g_story.card = STORY_CARD_NONE;
            g_career_new_unlocks = 0;
        }
        return g_story.card != STORY_CARD_NONE;
    }
    if (g_story.timer >= STORY_INTRO_FRAMES ||
            (g_story.timer >= STORY_INTRO_MIN_FRAMES &&
             (pressed & (PAD_B | PAD_A | PAD_START))))
        g_story.card = STORY_CARD_NONE;
    return g_story.card != STORY_CARD_NONE;
}
