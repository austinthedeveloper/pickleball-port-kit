#define CAREER_DATA_DEFINE
#include <string.h>
#include "career.h"
#include "match.h"
#include "opponents.h"
#include "paddle_stats.h"
#include "palette_parts.h"
#include "player.h"

/* beaten[] holds one count per ladder team. */
typedef char career_teams_fit[OPPONENT_COUNT <= CAREER_TEAMS ? 1 : -1];
/* The unlocked mask is a u16. */
typedef char career_unlocks_fit[CAREER_UNLOCKS <= 16 ? 1 : -1];

u16 g_career_new_unlocks;

CareerPlayer *career_active(void)
{
    u8 slot = g_save.career_active;

    if (slot >= CAREER_SLOTS)
        return 0;
    if (g_save.career[slot].used == 0)
        return 0;
    return &g_save.career[slot];
}

u8 career_create(u8 slot, const char *name)
{
    CareerPlayer *player;
    u8 i;

    if (slot >= CAREER_SLOTS)
        return 0;
    player = &g_save.career[slot];
    if (player->used)
        return 0;
    memset(player, 0, sizeof(*player));
    player->used = 1;
    for (i = 0; i < CAREER_NAME; ++i)
        player->name[i] = ' ';
    for (i = 0; i < CAREER_NAME && name[i]; ++i)
        player->name[i] = (u8)name[i];
    player->variant = PLAYER_VARIANT_MALE;
    player->shirt = PAL_BLUE;
    player->paddle = PADDLE_STANDARD;
    g_save.career_active = slot;
    return 1;
}

void career_delete(u8 slot)
{
    if (slot >= CAREER_SLOTS)
        return;
    memset(&g_save.career[slot], 0, sizeof(CareerPlayer));
    if (g_save.career_active == slot)
        g_save.career_active = CAREER_NONE;
}

void career_select(u8 slot)
{
    if (slot < CAREER_SLOTS && g_save.career[slot].used)
        g_save.career_active = slot;
    else
        g_save.career_active = CAREER_NONE;
}

static u8 career_unlock_held(const CareerPlayer *player, u8 unlock)
{
    if (unlock == CAREER_FREE)
        return 1;
    return (player->unlocked >> unlock) & 1;
}

u8 career_hair_unlocked(const CareerPlayer *player, u8 hair)
{
    if (hair >= CAREER_HAIRS)
        return 0;
    return career_unlock_held(player, g_career_hair_unlock[hair]);
}

u8 career_hat_unlocked(const CareerPlayer *player, u8 hat)
{
    if (hat >= CAREER_HATS)
        return 0;
    return career_unlock_held(player, g_career_hat_unlock[hat]);
}

static void career_bump(u16 *counter)
{
    if (*counter < SAVE_COUNTER_MAX)
        ++*counter;
}

void career_record_point(u8 shots, u8 won, u8 served)
{
    CareerPlayer *player = career_active();

    if (player == 0)
        return;
    if (won) {
        career_bump(&player->points_won);
        /* An ace: your serve, and nobody touched it after. */
        if (served && shots == 1)
            career_bump(&player->aces);
    } else {
        career_bump(&player->points_lost);
    }
    if (shots > player->longest_rally)
        player->longest_rally = shots;
}

void career_record_match(u8 mode, u8 won, u8 points_against, u8 opponent,
    u8 open_play)
{
    CareerPlayer *player = career_active();

    g_career_new_unlocks = 0;
    if (player == 0)
        return;
    if (mode > MATCH_DOUBLES)
        mode = MATCH_DOUBLES;
    if (open_play)
        career_bump(&player->open_play);
    if (won) {
        career_bump(&player->wins[mode]);
        career_bump(&player->streak);
        if (player->streak > player->best_streak)
            player->best_streak = player->streak;
        if (points_against == 0)
            career_bump(&player->shutouts);
        if (opponent < OPPONENT_COUNT) {
            if (player->beaten[opponent] < 255)
                ++player->beaten[opponent];
            /* The ladder's last team, on the ladder (not at the park). */
            if (opponent == OPPONENT_COUNT - 1 && open_play == 0)
                career_bump(&player->ladder_clears);
        }
    } else {
        career_bump(&player->losses[mode]);
        player->streak = 0;
    }
    g_career_new_unlocks = career_check_unlocks(player);
}

/* The player's count for a rule (BEAT: wins over that team). */
static u16 career_rule_count(const CareerPlayer *player, u8 rule, u16 value)
{
    switch (rule) {
    case CAREER_RULE_WINS:
        return player->wins[0] + player->wins[1];
    case CAREER_RULE_RALLY:
        return player->longest_rally;
    case CAREER_RULE_ACES:
        return player->aces;
    case CAREER_RULE_SHUTOUTS:
        return player->shutouts;
    case CAREER_RULE_STREAK:
        return player->best_streak;
    case CAREER_RULE_BEAT:
        return value < CAREER_TEAMS ? player->beaten[value] : 0;
    case CAREER_RULE_CLEARS:
        return player->ladder_clears;
    case CAREER_RULE_OPEN:
        return player->open_play;
    default:
        return 0;
    }
}

void career_compose_with(const CareerPlayer *player, u8 shirt, u8 paddle,
    u16 out[16])
{
    const u16 *team = g_pal_team[shirt % PAL_COUNT];
    const u16 *skin = g_career_skins[player->skin % CAREER_SKINS];
    const u16 *part = g_pal_paddle[paddle % PADDLE_PART_COUNT];
    u8 i;

    out[0] = 0;
    out[1] = g_pal_shared[0][0];
    for (i = 0; i < 3; ++i) {
        out[2 + i] = skin[i];
        out[11 + i] = part[i];
    }
    for (i = 0; i < 6; ++i)
        out[5 + i] = team[i];
    out[14] = g_pal_shared[0][1];
    out[15] = g_career_hair[player->hair % CAREER_HAIRS];
}

void career_compose_palette(const CareerPlayer *player, u16 out[16])
{
    career_compose_with(player, player->shirt, player->paddle, out);
}

u16 career_check_unlocks(CareerPlayer *player)
{
    u16 earned = 0;
    u16 bit = 1;
    u16 need;
    u8 i;

    for (i = 0; i < CAREER_UNLOCKS; ++i, bit <<= 1) {
        if (player->unlocked & bit)
            continue;
        /* BEAT's value names the team: one win is enough. */
        need = g_career_unlock_rule[i] == CAREER_RULE_BEAT ? 1 :
            g_career_unlock_value[i];
        if (career_rule_count(player, g_career_unlock_rule[i],
                g_career_unlock_value[i]) >= need)
            earned |= bit;
    }
    player->unlocked |= earned;
    return earned;
}
