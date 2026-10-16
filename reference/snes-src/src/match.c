#define PALETTE_PARTS_DEFINE
#define PADDLE_STATS_DEFINE
#define OPPONENTS_DEFINE
#include "career.h"
#include "match.h"
#include "options.h"
#include "player.h"
#include "save.h"

#ifdef HOST_TEST
/* Host tests start from the singles defaults without calling them; on the
 * SNES main() calls match_config_defaults() (RAM is not initialized). */
MatchConfig g_match_config = {
    MATCH_SINGLES,
    { PAL_BLUE, MATCH_NO_PALETTE, PAL_RED, MATCH_NO_PALETTE },
    { 0, 0, 0, 0 },
    { PADDLE_STANDARD, PADDLE_STANDARD, PADDLE_STANDARD, PADDLE_STANDARD },
    { PLAYER_VARIANT_MALE, PLAYER_VARIANT_FEMALE, PLAYER_VARIANT_MALE,
      PLAYER_VARIANT_FEMALE },
    { 1, 0, 0, 0 },
    OPPONENT_NONE,
    OPTIONS_POINTS_DEFAULT,
    DIFFICULTY_MEDIUM,
    0,
    0,
    0,
    OPPONENT_NONE,
    0,
    100
};
#else
MatchConfig g_match_config;
#endif

void match_config_defaults(void)
{
    u8 i;

    g_match_config.mode = MATCH_SINGLES;
    for (i = 0; i < MAX_PLAYERS; ++i) {
        g_match_config.palette_id[i] = MATCH_NO_PALETTE;
        g_match_config.skin_id[i] = 0;
        g_match_config.paddle_id[i] = PADDLE_STANDARD;
        /* CPU variants (ADR-020): slots 1 and 3 female. */
        g_match_config.variant[i] = (i & 1) ? PLAYER_VARIANT_FEMALE :
            PLAYER_VARIANT_MALE;
        g_match_config.human[i] = 0;
    }
    g_match_config.human[0] = 1;
    g_match_config.palette_id[0] = PAL_BLUE;
    g_match_config.palette_id[2] = PAL_RED;
    g_match_config.opponent = OPPONENT_NONE;
    g_match_config.points_to_win = OPTIONS_POINTS_DEFAULT;
    g_match_config.difficulty = DIFFICULTY_MEDIUM;
    g_match_config.practice = 0;
    g_match_config.modifiers = 0;
    g_match_config.open_play = 0;
    g_match_config.partner = OPPONENT_NONE;
    g_match_config.career_p1 = 0;
    /* ADR-049: the saved BALL SPEED, for every match and the demo. */
    g_match_config.ball_speed = options_ball_speed(g_save.settings.ball_speed);
}

void match_config_practice(void)
{
    u8 slot;

    g_match_config.mode = MATCH_SINGLES;
    g_match_config.opponent = OPPONENT_NONE;
    for (slot = 1; slot < MAX_PLAYERS; ++slot) {
        g_match_config.palette_id[slot] = MATCH_NO_PALETTE;
        g_match_config.human[slot] = 0;
    }
    g_match_config.practice = 1;
}

void match_config_opponent(u8 opponent)
{
    u8 slot;
    u8 member;

    g_match_config.opponent = OPPONENT_NONE;
    if (opponent >= OPPONENT_COUNT || g_match_config.human[2] ||
            g_match_config.human[3])
        return;
    g_match_config.opponent = opponent;
    for (slot = 2; slot < MAX_PLAYERS; ++slot) {
        member = slot - 2;
        g_match_config.variant[slot] = g_opponent_variant[opponent][member];
        g_match_config.paddle_id[slot] = g_opponent_paddle[opponent][member];
    }
}

u8 match_slot_member(u8 slot)
{
    if (g_match_config.opponent == OPPONENT_NONE || slot < 2)
        return 0xff;
    return slot - 2;
}

/* Slot 1 as an open play partner's captain (ADR-034). */
static u8 match_slot_partner(u8 slot)
{
    return slot == 1 && g_match_config.partner < OPPONENT_COUNT;
}

void match_config_partner(u8 team)
{
    g_match_config.partner = team < OPPONENT_COUNT ? team : OPPONENT_NONE;
    if (g_match_config.partner == OPPONENT_NONE || g_match_config.human[1])
        return;
    g_match_config.variant[1] = g_opponent_variant[team][0];
    g_match_config.paddle_id[1] = g_opponent_paddle[team][0];
}

u8 match_slot_hat(u8 slot)
{
    u8 member = match_slot_member(slot);

    if (slot == 0 && g_match_config.career_p1 && career_active())
        return career_active()->hat;
    if (g_match_config.human[slot])
        return 0;
    if (match_slot_partner(slot))
        return g_opponent_hat[g_match_config.partner][0];
    if (member == 0xff)
        return 0;
    return g_opponent_hat[g_match_config.opponent][member];
}

const AiStyle *match_slot_style(u8 slot)
{
    u8 member = match_slot_member(slot);

    if (match_slot_partner(slot))
        return &g_opponent_styles[g_match_config.partner][0];
    /* ADR-035: a CPU partnering a human plays the smarter partner style. */
    if (member == 0xff && g_match_config.human[slot ^ 1] &&
            !g_match_config.human[slot])
        return &g_ai_partner_style;
    if (member == 0xff)
        return &g_ai_default_style;
    return &g_opponent_styles[g_match_config.opponent][member];
}

const u16 *match_team_hud_colors(u8 team)
{
    if (team && g_match_config.opponent != OPPONENT_NONE)
        return g_opponent_hud[g_match_config.opponent];
    return g_pal_hud[match_team_palette(team)];
}

void match_config_doubles(void)
{
    match_config_defaults();
    g_match_config.mode = MATCH_DOUBLES;
    g_match_config.palette_id[1] = PAL_GOLD;
    g_match_config.palette_id[3] = PAL_GREEN;
}

static u8 palette_taken(u8 palette_id)
{
    u8 i;

    for (i = 0; i < MAX_PLAYERS; ++i)
        if (g_match_config.palette_id[i] == palette_id)
            return 1;
    return 0;
}

static void apply_choice(u8 slot, const PlayerChoice *choice)
{
    g_match_config.palette_id[slot] = choice->palette_id;
    g_match_config.variant[slot] = choice->variant;
    g_match_config.paddle_id[slot] = choice->paddle_id;
    g_match_config.human[slot] = 1;
}

void match_config_select(u8 mode, const PlayerChoice *p1,
    const PlayerChoice *p2)
{
    u8 slot;
    u8 colour = 0;

    match_config_defaults();
    g_match_config.mode = mode;
    for (slot = 0; slot < MAX_PLAYERS; ++slot)
        g_match_config.palette_id[slot] = MATCH_NO_PALETTE;
    apply_choice(0, p1);
    if (p2)
        apply_choice(2, p2);
    for (slot = 1; slot < MAX_PLAYERS; ++slot) {
        if (g_match_config.human[slot])
            continue;
        if (mode == MATCH_SINGLES && slot != 2)
            continue;
        while (palette_taken(colour))
            ++colour;
        g_match_config.palette_id[slot] = colour;
    }
}

void match_config_career_p1(void)
{
    const CareerPlayer *player = career_active();
    u8 old = g_match_config.palette_id[0];
    u8 slot;

    if (player == 0)
        return;
    g_match_config.career_p1 = 1;
    g_match_config.variant[0] = player->variant;
    g_match_config.paddle_id[0] = player->paddle;
    for (slot = 1; slot < MAX_PLAYERS; ++slot)
        if (g_match_config.palette_id[slot] == player->shirt)
            g_match_config.palette_id[slot] = old;
    g_match_config.palette_id[0] = player->shirt;
}

u8 match_slot_active(u8 slot)
{
    return g_match_config.palette_id[slot] != MATCH_NO_PALETTE;
}

u8 match_slot_lane_top(u8 slot)
{
    return slot == 1 || slot == 2;
}

u8 match_config_palettes_unique(void)
{
    u8 i;
    u8 j;

    for (i = 0; i < MAX_PLAYERS; ++i) {
        if (g_match_config.palette_id[i] == MATCH_NO_PALETTE)
            continue;
        for (j = i + 1; j < MAX_PLAYERS; ++j)
            if (g_match_config.palette_id[j] == g_match_config.palette_id[i])
                return 0;
    }
    return 1;
}

/* Contract v2 layout: 1 outline, 2-4 skin, 5-10 team, 11-13 paddle,
 * 14 highlight, 15 hair. */
void match_compose_palette(u8 slot, u16 out[16])
{
    u8 member = match_slot_member(slot);
    u8 i;

    /* ADR-047: the career player's skin and hair, in this match's shirt
     * and paddle (Player Select starts on theirs). */
    if (slot == 0 && g_match_config.career_p1 && career_active()) {
        career_compose_with(career_active(), g_match_config.palette_id[0],
            g_match_config.paddle_id[0], out);
        return;
    }
    if (match_slot_partner(slot)) {
        const u16 *look = g_opponent_palettes[g_match_config.partner][0];

        for (i = 0; i < 16; ++i)
            out[i] = look[i];
        return;
    }
    if (member != 0xff) {
        const u16 *look = g_opponent_palettes[g_match_config.opponent][member];

        for (i = 0; i < 16; ++i)
            out[i] = look[i];
        return;
    }
    match_compose_parts(g_match_config.palette_id[slot],
        g_match_config.skin_id[slot], g_match_config.paddle_id[slot], out);
}

void match_compose_parts(u8 palette_id, u8 skin_id, u8 paddle_id,
    u16 out[16])
{
    const u16 *team = g_pal_team[palette_id & 3];
    const u16 *skin = g_pal_skin[skin_id % SKIN_COUNT];
    const u16 *paddle = g_pal_paddle[paddle_id % PADDLE_PART_COUNT];
    u8 i;

    out[0] = 0;
    out[1] = g_pal_shared[0][0];
    for (i = 0; i < 3; ++i) {
        out[2 + i] = skin[i];
        out[11 + i] = paddle[i];
    }
    for (i = 0; i < 6; ++i)
        out[5 + i] = team[i];
    out[14] = g_pal_shared[0][1];
    out[15] = skin[3];
}

u8 match_team_palette(u8 team)
{
    return g_match_config.palette_id[team ? 2 : 0] & 3;
}
