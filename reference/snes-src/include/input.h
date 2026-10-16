#ifndef INPUT_H
#define INPUT_H

#include "game_types.h"

#define MAX_HUMAN_PADS 4
#define MAX_PLAYERS 4
/* Pad positions reported by the library: port 1, then port 2 or the four
 * Super Multitap pads (docs/04_INPUT_MULTITAP_PLAN.md). */
#define MAX_PADS 5
#define INPUT_NO_PAD 0xff

/* SNES pad bits (match PVSnesLib's KEY_* values). */
#define PAD_B 0x8000
#define PAD_Y 0x4000
#define PAD_SELECT 0x2000
#define PAD_START 0x1000
#define PAD_UP 0x0800
#define PAD_DOWN 0x0400
#define PAD_LEFT 0x0200
#define PAD_RIGHT 0x0100
#define PAD_A 0x0080
#define PAD_X 0x0040
#define PAD_L 0x0020
#define PAD_R 0x0010

/* Shot types (docs/decisions/ADR-019-shots.md): B, A, Y. */
typedef enum {
    SHOT_STANDARD = 0,
    SHOT_DRIVE = 1,     /* A: faster, flatter */
    SHOT_SOFT = 2       /* Y: lob, or a dink when aimed away from the net */
} ShotType;

typedef enum {
    INPUT_OWNER_NONE = 0,
    INPUT_OWNER_HUMAN = 1,
    INPUT_OWNER_CPU = 2
} InputOwner;

typedef struct {
    u16 held;
    u16 pressed;
    u16 released;
} PadSnapshot;

typedef struct {
    s16 move_x;
    s16 move_y;
    /* Shot direction read at contact; humans aim with the D-pad (= move). */
    s16 aim_x;
    s16 aim_y;
    u8 hit_pressed;     /* any swing button (B, A, Y) */
    u8 shot;            /* ShotType of that swing */
    u8 pause_pressed;
    u8 hit_held;        /* a swing button is down (the charged serve) */
} PlayerIntent;

extern PadSnapshot g_pad_snapshots[MAX_PADS];
extern PlayerIntent g_player_intents[MAX_PLAYERS];
extern u8 g_input_owners[MAX_PLAYERS];
/* Pad position feeding each game player, or INPUT_NO_PAD. */
extern u8 g_input_pad_for_player[MAX_PLAYERS];
extern u8 g_multitap_present;

/* Hardware layer (input.c): boot detection and the per-frame pad read. */
void input_initialize(void);
void input_capture_frame(void);

/* Pure layer (input_state.c), host-testable. */
void input_update_snapshot(PadSnapshot *snapshot, u16 current);
/* Default ownership: P1 human on pad 0, P3 CPU; with a Multitap P2/P4 map
 * to Multitap pads 3/4 (positions 2/3) and P3's pad is position 1. */
void input_configure(u8 multitap_present);
/* Updates every snapshot from raw pad words and rebuilds the intents of
 * human-owned players. CPU/unowned intents are cleared for the AI layer. */
void input_map_frame(const u16 raw[MAX_PADS]);
/* Ownership for a match: P1 human, 2P human on slot 2 when chosen
 * (ADR-020), every other active slot CPU (ADR-018). */
void input_assign_match(const u8 active[MAX_PLAYERS],
    const u8 human[MAX_PLAYERS]);

#endif

