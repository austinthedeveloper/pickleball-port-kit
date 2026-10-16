#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "career_page.h"
#include "input.h"
#include "palette_parts.h"
#include "test_support.h"

/* ADR-047 (M4-CAREER-02): the CAREER page's input. */

static u8 press(u16 pressed)
{
    return career_page_input(pressed, pressed);
}

/* A blank save, the page open; nobody is active, so it opens on NO
 * PLAYER: the tests start from slot 1 (row 0). */
static void fresh(void)
{
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    career_page_begin();
    assert(g_career_page.row == CAREER_ROW_NOBODY);
    g_career_page.row = 0;
}

/* Types a letter on the keyboard: the D-pad to its key, then B. */
static void type_key(u8 key)
{
    while (career_page_key() != key) {
        if (key >= CAREER_KEY_DEL) {
            if (g_career_page.key_row != CAREER_KEY_ROWS - 1)
                press(PAD_UP);              /* wraps to DEL/END */
            else
                press(PAD_RIGHT);
        } else if (g_career_page.key_row != key / CAREER_KEY_COLS) {
            press(PAD_DOWN);
        } else {
            press(PAD_RIGHT);
        }
    }
    press(PAD_B);
}

static void test_create_and_name(void)
{
    CareerPlayer *p;

    fresh();
    assert(g_career_page.view == CAREER_VIEW_SLOTS && g_career_page.row == 0);
    /* Slot 2: a new player, on the keyboard at once, the name blank. */
    press(PAD_DOWN);
    press(PAD_DOWN);
    assert(press(PAD_B) == CAREER_PAGE_STAY);
    assert(g_career_page.view == CAREER_VIEW_EDIT && g_career_page.naming);
    assert(g_career_page.creating && g_save.career_active == 2);
    p = &g_save.career[2];
    assert(memcmp(p->name, "        ", CAREER_NAME) == 0);
    assert(career_page_key() == 0 && g_career_page.cursor == 0);
    /* END with no letters: still typing. */
    press(PAD_START);
    assert(g_career_page.naming);
    /* "ACE": A is picked (B), then C, E. */
    press(PAD_B);
    type_key(2);
    type_key(4);
    assert(memcmp(p->name, "ACE     ", CAREER_NAME) == 0);
    /* Y (or DEL) erases the last letter. */
    press(PAD_Y);
    assert(memcmp(p->name, "AC      ", CAREER_NAME) == 0);
    type_key(CAREER_KEY_DEL);
    type_key(4);                                /* "AE" */
    assert(memcmp(p->name, "AE      ", CAREER_NAME) == 0);
    /* Space and dash. */
    type_key(26);
    type_key(27);
    assert(memcmp(p->name, "AE -    ", CAREER_NAME) == 0);
    /* END: done typing, and a new player goes on to their look. */
    type_key(CAREER_KEY_END);
    assert(!g_career_page.naming && g_career_page.row == CAREER_EDIT_BODY);
    /* B keeps: the card, and a save. */
    assert(press(PAD_B) == CAREER_PAGE_SAVE);
    assert(g_career_page.view == CAREER_VIEW_CARD && !g_career_page.creating);
}

static void test_name_full_and_edit(void)
{
    CareerPlayer *p;
    u8 i;

    fresh();
    press(PAD_B);                               /* slot 0: new */
    p = &g_save.career[0];
    for (i = 0; i < CAREER_NAME; ++i)
        press(PAD_B);                           /* AAAAAAAA */
    assert(memcmp(p->name, "AAAAAAAA", CAREER_NAME) == 0);
    assert(career_page_key() == CAREER_KEY_END);    /* full: on END */
    press(PAD_B);                               /* an extra B: END */
    assert(!g_career_page.naming);
    /* Editing the name again picks up after the last letter. */
    press(PAD_UP);                              /* NAME */
    press(PAD_B);
    assert(g_career_page.naming && g_career_page.cursor == CAREER_NAME);
    press(PAD_Y);
    press(PAD_Y);
    assert(memcmp(p->name, "AAAAAA  ", CAREER_NAME) == 0);
    press(PAD_START);
    assert(!g_career_page.naming);
}

static void test_cancel_new_player(void)
{
    fresh();
    press(PAD_B);                               /* slot 0: new */
    press(PAD_B);                               /* A */
    press(PAD_START);                           /* done typing */
    press(PAD_Y);                               /* never mind */
    assert(g_career_page.view == CAREER_VIEW_SLOTS);
    assert(g_save.career[0].used == 0 && career_active() == 0);
    /* Keeping a nameless player isn't possible: B goes back to typing. */
    press(PAD_B);
    g_career_page.naming = 0;                   /* (as if left without END) */
    g_career_page.row = CAREER_EDIT_BODY;
    assert(press(PAD_B) == CAREER_PAGE_STAY);
    assert(g_career_page.naming && g_career_page.row == CAREER_EDIT_NAME);
}

static void test_edit_look(void)
{
    CareerPlayer *p;

    fresh();
    career_create(1, "MAX");
    career_page_begin();
    assert(g_career_page.row == 1);             /* on the active player */
    assert(press(PAD_B) == CAREER_PAGE_SAVE);   /* the card */
    press(PAD_B);                               /* edit */
    assert(g_career_page.view == CAREER_VIEW_EDIT && !g_career_page.naming);
    p = &g_save.career[1];
    g_career_page.look_changed = 0;
    press(PAD_DOWN);                            /* BODY */
    press(PAD_RIGHT);
    assert(p->variant == PLAYER_VARIANT_FEMALE && g_career_page.look_changed);
    press(PAD_DOWN);                            /* SKIN */
    press(PAD_LEFT);
    assert(p->skin == CAREER_SKINS - 1);
    press(PAD_DOWN);                            /* HAIR: the locked skipped */
    press(PAD_LEFT);
    assert(career_hair_unlocked(p, p->hair) && p->hair != 0);
    press(PAD_DOWN);                            /* SHIRT */
    press(PAD_RIGHT);
    assert(p->shirt == PAL_RED);
    press(PAD_DOWN);                            /* HAT: nothing won yet */
    press(PAD_RIGHT);
    assert(p->hat == CAREER_HATS - 1);          /* past the locked: NONE */
    press(PAD_RIGHT);
    assert(p->hat == 0);
    /* Y puts it all back. */
    press(PAD_Y);
    assert(g_career_page.view == CAREER_VIEW_CARD);
    assert(p->variant == PLAYER_VARIANT_MALE && p->skin == 0 && p->hair == 0);
    assert(p->shirt == PAL_BLUE);
    /* An unlocked hat can be worn. */
    p->unlocked = 1;                            /* VISOR */
    press(PAD_B);
    for (g_career_page.row = 0; g_career_page.row != CAREER_EDIT_HAT;)
        press(PAD_DOWN);
    press(PAD_RIGHT);
    assert(p->hat == 1);
    assert(press(PAD_B) == CAREER_PAGE_SAVE && p->hat == 1);
}

static void test_delete_and_records(void)
{
    fresh();
    career_create(0, "ACE");
    career_page_begin();
    press(PAD_B);                               /* the card */
    /* X alone does nothing; L+R+X deletes. */
    press(PAD_X);
    assert(g_save.career[0].used);
    assert(career_page_input(PAD_X, PAD_L | PAD_R | PAD_X) ==
        CAREER_PAGE_SAVE);
    assert(g_save.career[0].used == 0 && career_active() == 0);
    assert(g_career_page.view == CAREER_VIEW_SLOTS);
    /* RECORDS, erase, and back. */
    g_save.records.wins[0] = 9;
    press(PAD_UP);                              /* wraps to RECORDS */
    assert(g_career_page.row == CAREER_ROW_RECORDS);
    press(PAD_B);
    assert(g_career_page.view == CAREER_VIEW_RECORDS);
    career_page_input(PAD_X, PAD_L | PAD_R | PAD_X);
    assert(g_save.records.wins[0] == 0);
    press(PAD_Y);
    assert(g_career_page.view == CAREER_VIEW_SLOTS);
    assert(press(PAD_Y) == CAREER_PAGE_CLOSE);
}

/* Y with nothing left to erase backs out of typing. */
static void test_back_out_of_name(void)
{
    CareerPlayer *p;

    /* A new player: dropped, back to the slots. */
    fresh();
    press(PAD_B);
    assert(g_career_page.naming && g_career_page.cursor == 0);
    press(PAD_Y);
    assert(!g_career_page.naming && g_career_page.view == CAREER_VIEW_SLOTS);
    assert(g_save.career[0].used == 0);
    /* Typed, erased, then back out: still dropped. */
    press(PAD_B);
    press(PAD_B);                               /* A */
    press(PAD_Y);                               /* erased */
    assert(g_career_page.naming);
    press(PAD_Y);
    assert(g_save.career[0].used == 0);

    /* An old player: erasing then backing out keeps the old name. */
    fresh();
    career_create(0, "MAX");
    career_page_begin();
    press(PAD_B);                               /* card */
    press(PAD_B);                               /* edit, on NAME */
    press(PAD_B);                               /* typing, after "MAX" */
    p = &g_save.career[0];
    assert(g_career_page.naming && g_career_page.cursor == 3);
    press(PAD_Y);
    press(PAD_Y);
    press(PAD_Y);
    assert(memcmp(p->name, "        ", CAREER_NAME) == 0);
    press(PAD_Y);                               /* back out */
    assert(!g_career_page.naming && g_career_page.view == CAREER_VIEW_EDIT);
    assert(memcmp(p->name, "MAX     ", CAREER_NAME) == 0 && p->used);
}

/* NO PLAYER: nobody active; the page opens there. */
static void test_no_player(void)
{
    fresh();
    career_create(1, "MAX");
    career_page_begin();
    assert(g_career_page.row == 1 && career_active() != 0);
    press(PAD_DOWN);
    press(PAD_DOWN);
    assert(g_career_page.row == CAREER_ROW_NOBODY);
    assert(press(PAD_B) == CAREER_PAGE_SAVE);
    assert(career_active() == 0 && g_career_page.view == CAREER_VIEW_SLOTS);
    assert(g_save.career[1].used);              /* still there */
}

static void test_card_helpers(void)
{
    CareerPlayer p;

    memset(&p, 0, sizeof(p));
    assert(career_next_unlock(&p) == 0 && career_unlock_count(&p) == 0);
    p.unlocked = 0x0b;                          /* 0, 1, 3 */
    assert(career_next_unlock(&p) == 2 && career_unlock_count(&p) == 3);
    p.unlocked = (1 << CAREER_UNLOCKS) - 1;
    assert(career_next_unlock(&p) == CAREER_UNLOCKS);
    assert(strcmp(career_paddle_name(0), "WOOD") == 0);
    assert(strcmp(career_body_name(1), "FEMALE") == 0);
}

int main(void)
{
    test_create_and_name();
    test_name_full_and_edit();
    test_cancel_new_player();
    test_edit_look();
    test_delete_and_records();
    test_no_player();
    test_back_out_of_name();
    test_card_helpers();
    puts("career page host checks passed");
    return 0;
}
