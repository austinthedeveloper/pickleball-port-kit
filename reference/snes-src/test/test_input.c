#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "input.h"

static u16 raw[MAX_PADS];

static void all_human(void)
{
    u8 i;
    for (i = 0; i < MAX_PLAYERS; ++i)
        g_input_owners[i] = INPUT_OWNER_HUMAN;
}

/* M3-IN-02: four slots, simultaneous directions and hit edges, no bleed. */
static void test_four_independent_slots(void)
{
    input_configure(1);
    all_human();
    memset(raw, 0, sizeof(raw));
    raw[0] = PAD_LEFT | PAD_UP | PAD_B;   /* P1 */
    raw[2] = PAD_RIGHT;                   /* P2: Multitap pad 3 */
    raw[1] = PAD_DOWN | PAD_B;            /* P3: port 2 / Multitap pad 2 */
    raw[3] = PAD_LEFT | PAD_DOWN;         /* P4: Multitap pad 4 */
    raw[4] = PAD_B | PAD_START;           /* fifth Multitap pad: unused */
    input_map_frame(raw);

    assert(g_player_intents[0].move_x == -1 && g_player_intents[0].move_y == -1);
    assert(g_player_intents[0].hit_pressed == 1);
    assert(g_player_intents[1].move_x == 1 && g_player_intents[1].move_y == 0);
    assert(g_player_intents[1].hit_pressed == 0);
    assert(g_player_intents[2].move_x == 0 && g_player_intents[2].move_y == 1);
    assert(g_player_intents[2].hit_pressed == 1);
    assert(g_player_intents[3].move_x == -1 && g_player_intents[3].move_y == 1);
    assert(g_player_intents[3].aim_x == -1 && g_player_intents[3].aim_y == 1);

    /* Holding B is one edge; P2 pressing now is independent of P1/P3. */
    raw[2] |= PAD_B;
    input_map_frame(raw);
    assert(g_player_intents[0].hit_pressed == 0);
    assert(g_player_intents[2].hit_pressed == 0);
    assert(g_player_intents[1].hit_pressed == 1);
    assert(g_player_intents[3].hit_pressed == 0);
}

static void test_pause_only_from_p1(void)
{
    input_configure(1);
    all_human();
    memset(raw, 0, sizeof(raw));
    input_map_frame(raw);
    raw[1] = PAD_START;
    raw[2] = PAD_START;
    raw[3] = PAD_START;
    input_map_frame(raw);
    assert(!g_player_intents[1].pause_pressed);
    assert(!g_player_intents[2].pause_pressed);
    assert(!g_player_intents[3].pause_pressed);
    raw[0] = PAD_START;
    input_map_frame(raw);
    assert(g_player_intents[0].pause_pressed);
}

static void test_poc_ownership_without_multitap(void)
{
    input_configure(0);
    assert(g_input_owners[0] == INPUT_OWNER_HUMAN);
    assert(g_input_owners[2] == INPUT_OWNER_CPU);
    assert(g_input_pad_for_player[1] == INPUT_NO_PAD);
    assert(g_input_pad_for_player[3] == INPUT_NO_PAD);
    memset(raw, 0, sizeof(raw));
    raw[1] = PAD_RIGHT | PAD_B;   /* a port-2 pad cannot drive the CPU slot */
    input_map_frame(raw);
    input_map_frame(raw);
    assert(g_player_intents[2].move_x == 0);
    assert(g_player_intents[2].hit_pressed == 0);
    /* The port-2 pad still reads normally for a future P3 human. */
    assert(g_pad_snapshots[1].held == (PAD_RIGHT | PAD_B));
}

int main(void)
{
    test_four_independent_slots();
    test_pause_only_from_p1();
    test_poc_ownership_without_multitap();
    puts("input host checks passed");
    return 0;
}
