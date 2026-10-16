#include "open_play.h"
#include "options.h"
#include "opponents.h"

OpenPlay g_open_play;

/* xorshift16: no multiply (816-tcc calls a routine for one). */
static u16 open_random(void)
{
    u16 x = g_open_play.seed;

    x ^= x << 7;
    x ^= x >> 9;
    x ^= x << 8;
    g_open_play.seed = x;
    return x;
}

/* A table: the walking and rack checks ask for court edges many times a
 * frame, and 816-tcc calls a routine for each multiply. */
static const s16 s_court_left[OPEN_COURTS] = {
    OPEN_COURT_LEFT0, OPEN_COURT_LEFT0 + OPEN_COURT_PITCH,
    OPEN_COURT_LEFT0 + 2 * OPEN_COURT_PITCH
};
typedef char open_court_table_is_3[OPEN_COURTS == 3 ? 1 : -1];

/* Skill levels: the ladder's first three teams, the next three, the last
 * two (the ladder is ordered by difficulty, ADR-023). */
static const u8 s_team_court[OPPONENT_COUNT] = { 0, 0, 0, 1, 1, 1, 2, 2 };
typedef char open_team_table_is_8[OPPONENT_COUNT == 8 ? 1 : -1];

u8 open_team_court(u8 team)
{
    return team < OPPONENT_COUNT ? s_team_court[team] : 0;
}

const char *open_court_level_name(u8 court)
{
    static const char *const names[OPEN_COURTS] = {
        "<3.5", "3.5-4.5", "4.5+"
    };
    return names[court < OPEN_COURTS ? court : 0];
}

u8 open_court_difficulty(u8 court, u8 saved_difficulty)
{
    static const u8 levels[OPEN_COURTS] = {
        DIFFICULTY_EASY, DIFFICULTY_MEDIUM, DIFFICULTY_HARD
    };
    if (saved_difficulty == DIFFICULTY_KID)
        return DIFFICULTY_KID;
    return levels[court < OPEN_COURTS ? court : 0];
}

s16 open_court_left(u8 court)
{
    return s_court_left[court < OPEN_COURTS ? court : 0];
}

s16 open_rack_x(u8 court)
{
    return open_court_left(court) + OPEN_RACK_DX;
}

static s16 abs_s16(s16 v)
{
    return v < 0 ? -v : v;
}

u8 open_rack_near(void)
{
    s16 x = FROM_FP(g_open_play.x_fp);
    s16 y = FROM_FP(g_open_play.y_fp);
    u8 c;

    for (c = 0; c < OPEN_COURTS; ++c)
        if (abs_s16(x - open_rack_x(c)) <= OPEN_RACK_REACH &&
                abs_s16(y - OPEN_RACK_Y) <= OPEN_RACK_REACH)
            return c;
    return OPEN_NONE;
}

u8 open_court_near(void)
{
    s16 x = FROM_FP(g_open_play.x_fp);
    s16 y = FROM_FP(g_open_play.y_fp);
    s16 left;
    u8 c;

    for (c = 0; c < OPEN_COURTS; ++c) {
        left = open_court_left(c);
        if (x >= left - OPEN_PEEK_REACH / 2 &&
                x <= left + OPEN_COURT_W + OPEN_PEEK_REACH / 2 &&
                y >= OPEN_COURT_TOP - OPEN_PEEK_REACH &&
                y <= OPEN_COURT_TOP + OPEN_COURT_H + OPEN_PEEK_REACH)
            return c;
    }
    return OPEN_NONE;
}

/* The clubhouse walls, with the margin (M4-OPEN-05). */
#define HOUSE_M OPEN_FENCE_MARGIN

static u8 open_house_wall(s16 x, s16 y)
{
    if (x <= OPEN_HOUSE_LEFT - HOUSE_M || x >= OPEN_HOUSE_RIGHT + HOUSE_M ||
            y <= OPEN_HOUSE_TOP - HOUSE_M || y >= OPEN_HOUSE_BOTTOM + HOUSE_M)
        return 0;                   /* outside it */
    if (x >= OPEN_HOUSE_LEFT + OPEN_HOUSE_WALL + HOUSE_M &&
            x <= OPEN_HOUSE_RIGHT - OPEN_HOUSE_WALL - HOUSE_M &&
            y >= OPEN_HOUSE_TOP + OPEN_HOUSE_WALL + HOUSE_M &&
            y <= OPEN_HOUSE_BOTTOM - OPEN_HOUSE_WALL - HOUSE_M)
        return 0;                   /* the room */
    /* The door: through the bottom wall only. */
    if (y > OPEN_HOUSE_BOTTOM - OPEN_HOUSE_WALL - HOUSE_M &&
            x >= OPEN_HOUSE_DOOR_X - OPEN_HOUSE_DOOR_W / 2 + HOUSE_M &&
            x <= OPEN_HOUSE_DOOR_X + OPEN_HOUSE_DOOR_W / 2 - HOUSE_M)
        return 0;
    return 1;
}

u8 open_in_house(void)
{
    s16 x = FROM_FP(g_open_play.x_fp);
    s16 y = FROM_FP(g_open_play.y_fp);

    return x > OPEN_HOUSE_LEFT && x < OPEN_HOUSE_RIGHT &&
        y > OPEN_HOUSE_TOP && y < OPEN_HOUSE_BOTTOM - OPEN_HOUSE_WALL;
}

static u8 open_spot_near(s16 spot_x, s16 spot_y)
{
    return abs_s16(FROM_FP(g_open_play.x_fp) - spot_x) <= OPEN_SPOT_REACH &&
        abs_s16(FROM_FP(g_open_play.y_fp) - spot_y) <= OPEN_SPOT_REACH;
}

u8 open_board_near(void)
{
    return open_spot_near(OPEN_BOARD_X, OPEN_BOARD_Y);
}

u8 open_machine_near(void)
{
    return open_spot_near(OPEN_MACHINE_X, OPEN_MACHINE_Y);
}

u8 open_bench_near(void)
{
    return open_spot_near(OPEN_BENCH_X + 24, OPEN_BENCH_Y + 8);
}

u8 open_waiting_team(u8 n)
{
    const OpenCourt *court = g_open_play.court;
    u8 c;
    u8 i;

    for (c = 0; c < OPEN_COURTS; ++c, ++court)
        for (i = 0; i < court->stack_count; ++i)
            if (court->stack[i] < OPPONENT_COUNT && n-- == 0)
                return court->stack[i];
    return OPEN_NONE;
}

u8 open_walkable(fx x_fp, fx y_fp)
{
    s16 x = FROM_FP(x_fp);
    s16 y = FROM_FP(y_fp);
    s16 left;
    u8 c;

    if (x < OPEN_WALK_LEFT || x > OPEN_WALK_RIGHT ||
            y < OPEN_WALK_TOP || y > OPEN_WALK_BOTTOM)
        return 0;
    if (open_house_wall(x, y))
        return 0;
    for (c = 0; c < OPEN_COURTS; ++c) {
        left = open_court_left(c);
        if (x > left - OPEN_FENCE_MARGIN &&
                x < left + OPEN_COURT_W + OPEN_FENCE_MARGIN &&
                y > OPEN_COURT_TOP - OPEN_FENCE_MARGIN &&
                y < OPEN_COURT_TOP + OPEN_COURT_H + OPEN_FENCE_MARGIN)
            return 0;
    }
    return 1;
}

u8 open_your_wait(void)
{
    const OpenCourt *court;
    u8 i;

    if (g_open_play.your_court == OPEN_NONE)
        return OPEN_NONE;
    court = &g_open_play.court[g_open_play.your_court];
    for (i = 0; i < court->stack_count; ++i)
        if (court->stack[i] == OPEN_YOU)
            return i >> 1;
    return OPEN_NONE;
}

static u8 stack_pop(OpenCourt *court)
{
    u8 entry;
    u8 i;

    if (!court->stack_count)
        return OPEN_NONE;
    entry = court->stack[0];
    ++g_open_play.stacks;
    for (i = 1; i < court->stack_count; ++i)
        court->stack[i - 1] = court->stack[i];
    --court->stack_count;
    return entry;
}

static u8 stack_remove(OpenCourt *court, u8 entry)
{
    u8 i;
    u8 j;

    for (i = 0; i < court->stack_count; ++i) {
        if (court->stack[i] != entry)
            continue;
        for (j = i + 1; j < court->stack_count; ++j)
            court->stack[j - 1] = court->stack[j];
        --court->stack_count;
        ++g_open_play.stacks;
        return 1;
    }
    return 0;
}

/* A team coming off joins its own court's stack (its skill level); if that
 * is full, the shortest stack (ties: from a random court). */
static void stack_join(u8 entry)
{
    /* Walking pointers and no %: 816-tcc multiplies for each court[c] and
     * divides in a routine, and this runs on a changeover frame. */
    u8 start = (u8)(open_random() & 3);
    OpenCourt *const first = g_open_play.court;
    OpenCourt *const end = first + OPEN_COURTS;
    OpenCourt *court;
    OpenCourt *best = 0;
    u8 n;

    if (entry == OPEN_NONE || entry == OPEN_YOU)
        return;
    court = &g_open_play.court[open_team_court(entry)];
    if (court->stack_count < OPEN_STACK_MAX) {
        court->stack[court->stack_count++] = entry;
        ++g_open_play.stacks;
        return;
    }
    court = first;
    for (n = start; n && n < OPEN_COURTS; --n)
        ++court;
    for (n = 0; n < OPEN_COURTS; ++n) {
        if (court->stack_count < OPEN_STACK_MAX &&
                (!best || court->stack_count < best->stack_count))
            best = court;
        if (++court == end)
            court = first;
    }
    if (best) {
        best->stack[best->stack_count++] = entry;
        ++g_open_play.stacks;
    }
}

/* The next entry for a court: its own stack, else the front team of the
 * longest other stack (never your paddle: it waits where you put it). */
static u8 next_entry(u8 c)
{
    OpenCourt *court = &g_open_play.court[c];
    OpenCourt *other = g_open_play.court;
    OpenCourt *best = 0;
    u8 o;

    if (court->stack_count)
        return stack_pop(court);
    for (o = 0; o < OPEN_COURTS; ++o, ++other) {
        if (other == court || other->stack_count == 0 ||
                other->stack[0] == OPEN_YOU)
            continue;
        if (!best || other->stack_count > best->stack_count)
            best = other;
    }
    return best ? stack_pop(best) : OPEN_NONE;
}

static void court_next_point(OpenCourt *court)
{
    court->timer = OPEN_POINT_MIN_FRAMES +
        (u16)(open_random() & (OPEN_POINT_SPAN_FRAMES - 1));
    court->rally = 0;
}

/* Changeover over: the next two on, then the two off join stacks. */
static u8 court_start_game(u8 c)
{
    OpenCourt *court = &g_open_play.court[c];
    u8 off0 = court->playing[0];
    u8 off1 = court->playing[1];
    u8 side;

    /* The two off go to the back of their stacks first, so a court whose
     * stack is short keeps its own level playing (the 4.5+ court has two
     * teams); anyone waiting is ahead of them. */
    ++g_open_play.lineup;
    court->playing[0] = OPEN_NONE;
    court->playing[1] = OPEN_NONE;
    stack_join(off0);
    stack_join(off1);
    court->playing[0] = next_entry(c);
    court->playing[1] = next_entry(c);
    court->score[0] = 0;
    court->score[1] = 0;
    if (court->playing[0] == OPEN_NONE || court->playing[1] == OPEN_NONE) {
        /* Not enough players yet: wait for the next changeover. */
        stack_join(court->playing[0]);
        stack_join(court->playing[1]);
        court->playing[0] = OPEN_NONE;
        court->playing[1] = OPEN_NONE;
        court->state = OPEN_COURT_CHANGEOVER;
        court->timer = OPEN_CHANGEOVER_FRAMES;
        return OPEN_EVENT_NONE;
    }
    for (side = 0; side < 2; ++side) {
        if (court->playing[side] != OPEN_YOU)
            continue;
        court->state = OPEN_COURT_YOURS;
        g_open_play.your_court = OPEN_NONE;
        g_open_play.called = c;
        g_open_play.call_timer = 0;
        g_open_play.opponent = court->playing[side ^ 1];
        /* Your partner: the captain of the team waiting next at this
         * court (they stay in line); none waiting, the regular. */
        g_open_play.partner = court->stack_count &&
            court->stack[0] != OPEN_YOU ? court->stack[0] : OPEN_NONE;
        return OPEN_EVENT_CALLED;
    }
    court->state = OPEN_COURT_PLAYING;
    court_next_point(court);
    /* The new four walk on from the gate before the first serve. */
    court->age = 0;
    court->timer += OPEN_WALK_FRAMES;
    return OPEN_EVENT_NONE;
}

static u8 court_update(u8 c)
{
    OpenCourt *court = &g_open_play.court[c];
    u8 side;

    if (court->state == OPEN_COURT_YOURS)
        return OPEN_EVENT_NONE;
    if (court->timer)
        --court->timer;
    if (court->state == OPEN_COURT_CHANGEOVER)
        return court->timer ? OPEN_EVENT_NONE : court_start_game(c);
    if (court->age != 255)
        ++court->age;
    ++court->rally;
    if (court->timer)
        return OPEN_EVENT_NONE;
    side = (u8)(open_random() & 1);
    if (++court->score[side] >= OPEN_GAME_POINTS) {
        court->state = OPEN_COURT_CHANGEOVER;
        court->timer = OPEN_CHANGEOVER_FRAMES;
        return OPEN_EVENT_NONE;
    }
    court_next_point(court);
    return OPEN_EVENT_NONE;
}

void open_play_begin(u16 seed, u8 two_players)
{
    OpenCourt *court;
    u8 c;
    u8 entry = 0;

    g_open_play.seed = seed ? seed : 0xace1;
    ++g_open_play.lineup;
    for (c = 0; c < OPEN_COURTS; ++c) {
        court = &g_open_play.court[c];
        court->state = OPEN_COURT_PLAYING;
        court->playing[0] = OPEN_NONE;
        court->playing[1] = OPEN_NONE;
        court->score[0] = (u8)(open_random() & 3);
        court->score[1] = (u8)(open_random() & 3);
        court->stack_count = 0;
        court_next_point(court);
        court->age = 255;           /* these games are already going */
    }
    /* Each team at its level's court: the first two play, the rest wait. */
    for (entry = 0; entry < OPPONENT_COUNT; ++entry) {
        court = &g_open_play.court[open_team_court(entry)];
        if (court->playing[0] == OPEN_NONE)
            court->playing[0] = entry;
        else if (court->playing[1] == OPEN_NONE)
            court->playing[1] = entry;
        else
            court->stack[court->stack_count++] = entry;
    }
    g_open_play.x_fp = TO_FP(OPEN_START_X);
    g_open_play.y_fp = TO_FP(OPEN_START_Y);
    g_open_play.facing_left = 0;
    g_open_play.walking = 0;
    g_open_play.step = 0;
    g_open_play.your_court = OPEN_NONE;
    g_open_play.called = OPEN_NONE;
    g_open_play.call_timer = 0;
    g_open_play.opponent = OPEN_NONE;
    g_open_play.partner = OPEN_NONE;
    g_open_play.two_players = two_players != 0;
    g_open_play.last_won = OPEN_NONE;
    g_open_play.last_score[0] = 0;
    g_open_play.last_score[1] = 0;
    g_open_play.board_page = OPEN_NONE;
}

static u8 open_press_rack(u8 rack)
{
    OpenCourt *court = &g_open_play.court[rack];

    if (g_open_play.your_court == rack) {
        stack_remove(court, OPEN_YOU);
        g_open_play.your_court = OPEN_NONE;
        return OPEN_EVENT_UNSTACKED;
    }
    if (court->stack_count >= OPEN_STACK_MAX)
        return OPEN_EVENT_FULL;
    if (g_open_play.your_court != OPEN_NONE)
        stack_remove(&g_open_play.court[g_open_play.your_court], OPEN_YOU);
    court->stack[court->stack_count++] = OPEN_YOU;
    ++g_open_play.stacks;
    g_open_play.your_court = rack;
    return OPEN_EVENT_STACKED;
}

static void open_walk(s16 move_x, s16 move_y)
{
    fx x = g_open_play.x_fp + move_x * OPEN_WALK_FP;
    fx y = g_open_play.y_fp + move_y * OPEN_WALK_FP;

    /* Each axis on its own, so you slide along a fence. */
    if (move_x && open_walkable(x, g_open_play.y_fp))
        g_open_play.x_fp = x;
    if (move_y && open_walkable(g_open_play.x_fp, y))
        g_open_play.y_fp = y;
    if (move_x)
        g_open_play.facing_left = move_x < 0;
    g_open_play.walking = move_x || move_y;
    if (g_open_play.walking)
        ++g_open_play.step;
}

u8 open_play_update(s16 move_x, s16 move_y, u8 b_pressed)
{
    u8 event = OPEN_EVENT_NONE;
    u8 result;
    u8 rack;
    u8 c;

    for (c = 0; c < OPEN_COURTS; ++c) {
        result = court_update(c);
        if (result != OPEN_EVENT_NONE)
            event = result;
    }
    if (g_open_play.called != OPEN_NONE) {
        g_open_play.walking = 0;
        if (event == OPEN_EVENT_CALLED)
            return event;
        if (++g_open_play.call_timer >= OPEN_CALL_FRAMES) {
            g_open_play.call_timer = OPEN_CALL_FRAMES;
            return OPEN_EVENT_PLAY;
        }
        return OPEN_EVENT_NONE;
    }
    open_walk(move_x, move_y);
    /* The board's page shows while you stand there. */
    if (!open_board_near())
        g_open_play.board_page = OPEN_NONE;
    if (b_pressed) {
        rack = open_rack_near();
        if (rack != OPEN_NONE) {
            event = open_press_rack(rack);
        } else if (open_board_near()) {
            g_open_play.board_page = g_open_play.board_page >=
                OPEN_BOARD_PAGES - 1 ? 0 : g_open_play.board_page + 1;
            event = OPEN_EVENT_BOARD;
        } else if (open_machine_near()) {
            event = OPEN_EVENT_PRACTICE;
        }
    }
    return event;
}

void open_play_return(u8 won, u8 points_for, u8 points_against)
{
    u8 c = g_open_play.called;
    OpenCourt *court;

    g_open_play.last_won = won ? 1 : 0;
    g_open_play.last_score[0] = points_for;
    g_open_play.last_score[1] = points_against;
    g_open_play.called = OPEN_NONE;
    if (c >= OPEN_COURTS)
        return;
    court = &g_open_play.court[c];
    /* You leave; the court's next game starts after a changeover. */
    if (court->playing[0] == OPEN_YOU)
        court->playing[0] = OPEN_NONE;
    if (court->playing[1] == OPEN_YOU)
        court->playing[1] = OPEN_NONE;
    court->state = OPEN_COURT_CHANGEOVER;
    court->timer = OPEN_CHANGEOVER_FRAMES;
    ++g_open_play.lineup;
    g_open_play.x_fp = TO_FP(open_rack_x(c));
    g_open_play.y_fp = TO_FP(OPEN_RACK_Y + 8);
}
