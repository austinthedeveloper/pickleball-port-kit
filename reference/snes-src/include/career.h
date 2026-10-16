#ifndef CAREER_H
#define CAREER_H

#include "game_types.h"
#include "career_data.h"
#include "save.h"

/*
 * Career players (docs/decisions/ADR-047-career.md): three save slots, each
 * a named player with a look, lifetime stats, and unlocked hats and hair.
 * The active player is 1P; stats record from finished points and matches
 * against the CPU, outside the attract demo and practice. Pure: the save
 * is written by the match hooks (save_record_match) and the pages.
 */

/* The unlocks newly earned by the last finished match (bit n: unlock n);
 * WRAM only, for the result screen. */
extern u16 g_career_new_unlocks;

/* The active player, or 0 when none is chosen. */
CareerPlayer *career_active(void);
/* A new player in an empty slot with a name (CAREER_NAME letters or
 * fewer, 0-terminated or full), the default look, and no stats; made
 * active. Returns 0 if the slot is taken. */
u8 career_create(u8 slot, const char *name);
/* Empties a slot; if it was active, no player is active. */
void career_delete(u8 slot);
/* Makes a used slot active (CAREER_NONE: no player). */
void career_select(u8 slot);

/* Nonzero when the player may wear that hair colour or hat. */
u8 career_hair_unlocked(const CareerPlayer *player, u8 hair);
u8 career_hat_unlocked(const CareerPlayer *player, u8 hat);

/* A finished point in a career match: its shots, whether 1P's team won
 * it, and whether 1P served it. */
void career_record_point(u8 shots, u8 won, u8 served);
/* A finished career match against the CPU; opponent is the ladder team
 * (OPPONENT_NONE for the default CPU), open_play a park game. Updates the
 * stats and the unlocks (g_career_new_unlocks); the caller writes. */
void career_record_match(u8 mode, u8 won, u8 points_against, u8 opponent,
    u8 open_play);
/* The player's OBJ palette (ADR-013 roles): skin ramp and hair from the
 * career looks, shirt and shorts from their team colour, their paddle. */
void career_compose_palette(const CareerPlayer *player, u16 out[16]);
/* The same with another shirt and paddle (one match's Player Select
 * choice: the skin and hair are always the player's). */
void career_compose_with(const CareerPlayer *player, u8 shirt, u8 paddle,
    u16 out[16]);

/* Unlocks whose rules the player now meets and did not have; marks them.
 * Returns the new ones. */
u16 career_check_unlocks(CareerPlayer *player);

#endif
