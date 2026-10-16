#include "input.h"

PadSnapshot g_pad_snapshots[MAX_PADS];
PlayerIntent g_player_intents[MAX_PLAYERS];
u8 g_input_owners[MAX_PLAYERS];
u8 g_input_pad_for_player[MAX_PLAYERS];
u8 g_multitap_present;

void input_update_snapshot(PadSnapshot *snapshot, u16 current)
{
    u16 previous = snapshot->held;
    snapshot->held = current;
    snapshot->pressed = current & (u16)~previous;
    snapshot->released = previous & (u16)~current;
}

void input_configure(u8 multitap_present)
{
    u8 i;

    g_multitap_present = multitap_present;
    for (i = 0; i < MAX_PADS; ++i) {
        g_pad_snapshots[i].held = 0;
        g_pad_snapshots[i].pressed = 0;
        g_pad_snapshots[i].released = 0;
    }
    g_input_owners[0] = INPUT_OWNER_HUMAN;
    g_input_owners[1] = INPUT_OWNER_NONE;
    g_input_owners[2] = INPUT_OWNER_CPU;
    g_input_owners[3] = INPUT_OWNER_NONE;
    g_input_pad_for_player[0] = 0;
    g_input_pad_for_player[2] = 1;
    g_input_pad_for_player[1] = multitap_present ? 2 : INPUT_NO_PAD;
    g_input_pad_for_player[3] = multitap_present ? 3 : INPUT_NO_PAD;
}

#define OWNER(i) (!active[i] ? INPUT_OWNER_NONE : \
    human[i] ? INPUT_OWNER_HUMAN : INPUT_OWNER_CPU)

void input_assign_match(const u8 active[MAX_PLAYERS],
    const u8 human[MAX_PLAYERS])
{
    g_input_owners[0] = INPUT_OWNER_HUMAN;
    g_input_owners[1] = OWNER(1);
    g_input_owners[2] = OWNER(2);
    g_input_owners[3] = OWNER(3);
    /* Co-op (ADR-034): 2P partners P1 on slot 1 with the port 2 pad, which
     * otherwise belongs to slot 2 (versus). Slot 1 has a pad of its own only
     * on a Multitap. */
    if (human[1] && !human[2])
        g_input_pad_for_player[1] = 1;
    else if (g_input_pad_for_player[1] == 1)
        g_input_pad_for_player[1] = g_multitap_present ? 2 : INPUT_NO_PAD;
}

static void build_intent(PlayerIntent *intent, const PadSnapshot *pad,
    u8 may_pause)
{
    u16 held = pad->held;

    intent->move_x = 0;
    intent->move_y = 0;
    if (held & PAD_LEFT)
        intent->move_x = -1;
    else if (held & PAD_RIGHT)
        intent->move_x = 1;
    if (held & PAD_UP)
        intent->move_y = -1;
    else if (held & PAD_DOWN)
        intent->move_y = 1;
    intent->aim_x = intent->move_x;
    intent->aim_y = intent->move_y;
    intent->hit_pressed = (pad->pressed & (PAD_B | PAD_A | PAD_Y)) != 0;
    intent->hit_held = (held & (PAD_B | PAD_A | PAD_Y)) != 0;
    if (pad->pressed & PAD_A)
        intent->shot = SHOT_DRIVE;
    else if (pad->pressed & PAD_Y)
        intent->shot = SHOT_SOFT;
    else
        intent->shot = SHOT_STANDARD;
    /* Pause is arbitrated centrally; only P1 pauses in the POC. */
    intent->pause_pressed = may_pause && (pad->pressed & PAD_START) != 0;
}

/* Constant indices: 816-tcc multiplies for variable struct-array indexing,
 * and this runs every frame. */
#define SNAPSHOT(n) \
    do { \
        u16 now = raw[n]; \
        u16 before = g_pad_snapshots[n].held; \
        g_pad_snapshots[n].held = now; \
        g_pad_snapshots[n].pressed = now & (u16)~before; \
        g_pad_snapshots[n].released = before & (u16)~now; \
    } while (0)

#define MAP_PLAYER(i) \
    do { \
        if (g_input_owners[i] == INPUT_OWNER_HUMAN && \
                g_input_pad_for_player[i] != INPUT_NO_PAD) { \
            build_intent(&g_player_intents[i], \
                &g_pad_snapshots[g_input_pad_for_player[i]], (i) == 0); \
        } else { \
            g_player_intents[i].move_x = 0; \
            g_player_intents[i].move_y = 0; \
            g_player_intents[i].aim_x = 0; \
            g_player_intents[i].aim_y = 0; \
            g_player_intents[i].hit_pressed = 0; \
            g_player_intents[i].hit_held = 0; \
            g_player_intents[i].shot = SHOT_STANDARD; \
            g_player_intents[i].pause_pressed = 0; \
        } \
    } while (0)

void input_map_frame(const u16 raw[MAX_PADS])
{
    SNAPSHOT(0);
    SNAPSHOT(1);
    SNAPSHOT(2);
    SNAPSHOT(3);
    SNAPSHOT(4);
    MAP_PLAYER(0);
    MAP_PLAYER(1);
    MAP_PLAYER(2);
    MAP_PLAYER(3);
}
