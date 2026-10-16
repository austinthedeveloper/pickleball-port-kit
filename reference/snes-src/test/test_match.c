#include <assert.h>
#include <stdio.h>
#include "match.h"
#include "player.h"

int main(void)
{
    u16 pal[16];

    match_config_defaults();
    assert(g_match_config.palette_id[0] == PAL_BLUE);
    assert(g_match_config.palette_id[2] == PAL_RED);
    assert(g_match_config.palette_id[1] == MATCH_NO_PALETTE);
    assert(match_config_palettes_unique());
    assert(match_team_palette(0) == PAL_BLUE);
    assert(match_team_palette(1) == PAL_RED);

    /* Contract v2 composition (ADR-013). */
    match_compose_palette(0, pal);
    assert(pal[0] == 0);
    assert(pal[1] == g_pal_shared[0][0]);
    assert(pal[2] == g_pal_skin[0][0] && pal[4] == g_pal_skin[0][2]);
    assert(pal[5] == g_pal_team[PAL_BLUE][0]);
    assert(pal[10] == g_pal_team[PAL_BLUE][5]);
    assert(pal[11] == g_pal_paddle[PADDLE_STANDARD][0]);
    assert(pal[13] == g_pal_paddle[PADDLE_STANDARD][2]);
    assert(pal[14] == g_pal_shared[0][1]);
    assert(pal[15] == g_pal_skin[0][3]);

    /* Colour is per match, not per slot: gold vs green is valid (ADR-010). */
    g_match_config.palette_id[0] = PAL_GOLD;
    g_match_config.palette_id[2] = PAL_GREEN;
    assert(match_config_palettes_unique());
    assert(match_team_palette(1) == PAL_GREEN);
    match_compose_palette(2, pal);
    assert(pal[6] == g_pal_team[PAL_GREEN][1]);

    g_match_config.palette_id[2] = PAL_GOLD;
    assert(!match_config_palettes_unique());

    /* Player Select (ADR-020): CPUs take the unused colours in order. */
    {
        PlayerChoice p1 = { PAL_BLUE, PLAYER_VARIANT_FEMALE, PADDLE_RED };
        PlayerChoice p2 = { PAL_RED, PLAYER_VARIANT_MALE, PADDLE_WOOD };

        match_config_select(MATCH_SINGLES, &p1, 0);
        assert(g_match_config.palette_id[0] == PAL_BLUE);
        assert(g_match_config.variant[0] == PLAYER_VARIANT_FEMALE);
        assert(g_match_config.paddle_id[0] == PADDLE_RED);
        assert(g_match_config.palette_id[2] == PAL_RED);
        assert(g_match_config.paddle_id[2] == PADDLE_STANDARD);
        assert(!match_slot_active(1) && !match_slot_active(3));
        assert(g_match_config.human[0] && !g_match_config.human[2]);

        p1.palette_id = PAL_RED;
        match_config_select(MATCH_SINGLES, &p1, 0);
        assert(g_match_config.palette_id[2] == PAL_BLUE);

        p1.palette_id = PAL_GREEN;
        match_config_select(MATCH_DOUBLES, &p1, &p2);
        assert(g_match_config.palette_id[0] == PAL_GREEN);
        assert(g_match_config.palette_id[1] == PAL_BLUE);
        assert(g_match_config.palette_id[2] == PAL_RED);
        assert(g_match_config.palette_id[3] == PAL_GOLD);
        assert(g_match_config.human[2] && !g_match_config.human[1]);
        assert(g_match_config.paddle_id[2] == PADDLE_WOOD);
        assert(g_match_config.variant[1] == PLAYER_VARIANT_FEMALE);
        assert(match_config_palettes_unique());

        /* Composition follows the chosen paddle, not the team colour. */
        match_compose_palette(2, pal);
        assert(pal[11] == g_pal_paddle[PADDLE_WOOD][0]);
    }
    puts("match host checks passed");
    return 0;
}
