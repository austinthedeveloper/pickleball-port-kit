#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "game.h"
#include "input.h"
#include "match.h"
#include "open_play.h"
#include "opponents.h"
#include "options.h"

/* ADR-034 open play: the park's stacks, games, walking, and your turn. */

static void place_you(s16 x, s16 y)
{
    g_open_play.x_fp = TO_FP(x);
    g_open_play.y_fp = TO_FP(y);
}

/* Every team is in exactly one place: on a court or in one stack. You are
 * in at most one stack, and only where your_court says. */
static void check_population(void)
{
    u8 seen[OPPONENT_COUNT];
    u8 you = 0;
    u8 c;
    u8 i;
    u8 e;

    memset(seen, 0, sizeof(seen));
    for (c = 0; c < OPEN_COURTS; ++c) {
        const OpenCourt *court = &g_open_play.court[c];
        for (i = 0; i < 2 + court->stack_count; ++i) {
            e = i < 2 ? court->playing[i] : court->stack[i - 2];
            if (e == OPEN_NONE)
                continue;
            if (e == OPEN_YOU) {
                ++you;
                assert(i < 2 || g_open_play.your_court == c);
                continue;
            }
            assert(e < OPPONENT_COUNT);
            ++seen[e];
        }
        assert(court->stack_count <= OPEN_STACK_MAX);
    }
    for (e = 0; e < OPPONENT_COUNT; ++e)
        assert(seen[e] == 1);
    assert(you <= 1);
}

static void test_begin(void)
{
    u8 c;
    u8 side;

    open_play_begin(1234, 0);
    for (c = 0; c < OPEN_COURTS; ++c) {
        assert(g_open_play.court[c].state == OPEN_COURT_PLAYING);
        assert(g_open_play.court[c].score[0] < OPEN_GAME_POINTS);
    }
    /* Every team starts at its level's court. */
    for (c = 0; c < OPEN_COURTS; ++c)
        for (side = 0; side < 2; ++side)
            assert(open_team_court(g_open_play.court[c].playing[side]) == c);
    assert(g_open_play.your_court == OPEN_NONE);
    assert(g_open_play.called == OPEN_NONE);
    assert(open_walkable(g_open_play.x_fp, g_open_play.y_fp));
    check_population();
}

static void test_walking(void)
{
    s16 left = open_court_left(1);
    u16 n;

    open_play_begin(1, 0);
    /* Inside a court is fenced off; the walks between courts are open. */
    assert(!open_walkable(TO_FP(left + 20), TO_FP(OPEN_COURT_TOP + 40)));
    assert(open_walkable(TO_FP(left - 12), TO_FP(OPEN_COURT_TOP + 40)));
    assert(!open_walkable(TO_FP(2), TO_FP(150)));
    /* Walking up into a court stops at its fence. */
    place_you(left + 20, OPEN_RACK_Y);
    for (n = 0; n < 200; ++n)
        open_play_update(0, -1, 0);
    assert(FROM_FP(g_open_play.y_fp) >=
        OPEN_COURT_TOP + OPEN_COURT_H + OPEN_FENCE_MARGIN - 1);
    /* Diagonally, you slide along it. */
    open_play_update(1, -1, 0);
    assert(FROM_FP(g_open_play.x_fp) > left + 20);
    assert(g_open_play.walking && !g_open_play.facing_left);
    open_play_update(-1, 0, 0);
    assert(g_open_play.facing_left);
}

static void test_stacking(void)
{
    u8 c = 2;

    open_play_begin(7, 0);
    /* Away from every rack, B does nothing. */
    place_you(128, 200);
    assert(open_rack_near() == OPEN_NONE);
    assert(open_play_update(0, 0, 1) == OPEN_EVENT_NONE);
    place_you(open_rack_x(c), OPEN_RACK_Y + 4);
    assert(open_rack_near() == c);
    assert(open_play_update(0, 0, 1) == OPEN_EVENT_STACKED);
    assert(g_open_play.your_court == c);
    assert(g_open_play.court[c].stack[g_open_play.court[c].stack_count - 1] ==
        OPEN_YOU);
    assert(open_your_wait() == (g_open_play.court[c].stack_count - 1) / 2);
    check_population();
    /* B again takes it back. */
    assert(open_play_update(0, 0, 1) == OPEN_EVENT_UNSTACKED);
    assert(g_open_play.your_court == OPEN_NONE);
    assert(open_your_wait() == OPEN_NONE);
    /* Stacking at another court moves your paddle there. */
    open_play_update(0, 0, 1);
    place_you(open_rack_x(0), OPEN_RACK_Y);
    assert(open_play_update(0, 0, 1) == OPEN_EVENT_STACKED);
    assert(g_open_play.your_court == 0);
    check_population();
    /* A full stack has no room. */
    g_open_play.court[1].stack_count = OPEN_STACK_MAX;
    place_you(open_rack_x(1), OPEN_RACK_Y);
    assert(open_play_update(0, 0, 1) == OPEN_EVENT_FULL);
    assert(g_open_play.your_court == 0);
}

/* Stack, wait for your game, play it, come back: the park goes on. */
static void test_your_turn(void)
{
    unsigned long frames = 0;
    u8 event = OPEN_EVENT_NONE;
    u8 c = 1;
    u8 called_court;
    u8 opponent;

    open_play_begin(99, 0);
    place_you(open_rack_x(c), OPEN_RACK_Y);
    assert(open_play_update(0, 0, 1) == OPEN_EVENT_STACKED);
    place_you(128, 200);
    while (event != OPEN_EVENT_CALLED && frames < 60UL * 60 * 5) {
        event = open_play_update(0, 0, 0);
        check_population();
        ++frames;
    }
    assert(event == OPEN_EVENT_CALLED);
    printf("open play: called after %lu s on court %u\n",
        (unsigned long)(frames / 60), g_open_play.called + 1);
    called_court = g_open_play.called;
    assert(called_court == c);
    opponent = g_open_play.opponent;
    assert(opponent < OPPONENT_COUNT);
    assert(open_team_court(opponent) == c);     /* a team of that level */
    /* Your partner: the team waiting next there (not your opponents). */
    if (g_open_play.court[c].stack_count) {
        assert(g_open_play.partner == g_open_play.court[c].stack[0]);
        assert(g_open_play.partner != opponent);
        assert(open_team_court(g_open_play.partner) == c);
    } else {
        assert(g_open_play.partner == OPEN_NONE);
    }
    printf("open play: you and %s's captain vs %s\n",
        g_open_play.partner < OPPONENT_COUNT ?
            g_opponent_team[g_open_play.partner] : "the regular",
        g_opponent_team[opponent]);
    assert(g_open_play.court[c].state == OPEN_COURT_YOURS);
    assert(g_open_play.your_court == OPEN_NONE);
    /* The call shows for a while, input ignored, then the match. */
    place_you(128, 200);
    for (frames = 1; frames < OPEN_CALL_FRAMES; ++frames)
        assert(open_play_update(1, 0, 1) == OPEN_EVENT_NONE);
    assert(FROM_FP(g_open_play.x_fp) == 128);
    assert(open_play_update(0, 0, 0) == OPEN_EVENT_PLAY);
    /* Back from the match: you leave, the court changes over. */
    open_play_return(1, 11, 7);
    assert(g_open_play.called == OPEN_NONE);
    assert(g_open_play.last_won == 1 && g_open_play.last_score[0] == 11);
    assert(g_open_play.court[c].state == OPEN_COURT_CHANGEOVER);
    assert(open_walkable(g_open_play.x_fp, g_open_play.y_fp));
    for (frames = 0; frames <= OPEN_CHANGEOVER_FRAMES; ++frames)
        open_play_update(0, 0, 0);
    assert(g_open_play.court[c].state == OPEN_COURT_PLAYING);
    check_population();
}

/* A long soak: games end and start on every court, teams move between
 * courts, and nobody is lost or duplicated. */
static void test_soak(void)
{
    u16 games[OPEN_COURTS] = { 0, 0, 0 };
    u8 away = 0;
    u8 side;
    u8 e;
    unsigned long f;
    u8 c;
    u8 before[OPEN_COURTS];

    open_play_begin(4321, 0);

    for (f = 0; f < 60UL * 60 * 20; ++f) {
        for (c = 0; c < OPEN_COURTS; ++c)
            before[c] = g_open_play.court[c].state;
        open_play_update(0, 0, 0);
        for (c = 0; c < OPEN_COURTS; ++c) {
            if (before[c] == OPEN_COURT_CHANGEOVER &&
                    g_open_play.court[c].state == OPEN_COURT_PLAYING)
                ++games[c];
            /* Teams only play at their own level. */
            for (side = 0; side < 2; ++side) {
                e = g_open_play.court[c].playing[side];
                if (e < OPPONENT_COUNT && open_team_court(e) != c)
                    away = 1;
            }
        }
        if ((f & 255) == 0)
            check_population();
    }
    printf("open play: 20 minutes, games by court %u %u %u\n", games[0],
        games[1], games[2]);
    for (c = 0; c < OPEN_COURTS; ++c)
        assert(games[c] >= 15);
    assert(!away);
}

/* The levels: ladder order, names, and the difficulty of your game. */
static void test_levels(void)
{
    assert(open_team_court(0) == 0 && open_team_court(2) == 0);
    assert(open_team_court(3) == 1 && open_team_court(5) == 1);
    assert(open_team_court(6) == 2 && open_team_court(7) == 2);
    assert(strcmp(open_court_level_name(0), "<3.5") == 0);
    assert(strcmp(open_court_level_name(2), "4.5+") == 0);
    assert(open_court_difficulty(0, DIFFICULTY_HARD) == DIFFICULTY_EASY);
    assert(open_court_difficulty(1, DIFFICULTY_EASY) == DIFFICULTY_MEDIUM);
    assert(open_court_difficulty(2, DIFFICULTY_MEDIUM) == DIFFICULTY_HARD);
    assert(open_court_difficulty(2, DIFFICULTY_KID) == DIFFICULTY_KID);
}

/* 2P as your partner (M4-OPEN-04): slot 1 is human on the port 2 pad;
 * in versus, port 2 still plays slot 2. */
static void test_two_players(void)
{
    u16 raw[MAX_PADS];

    open_play_begin(5, 1);
    assert(g_open_play.two_players == 1);
    input_configure(0);
    match_config_doubles();
    g_match_config.human[1] = 1;
    g_attract = 0;
    game_new_match();
    assert(g_input_owners[1] == INPUT_OWNER_HUMAN);
    assert(g_input_pad_for_player[1] == 1);
    assert(!g_players[1].cpu_controlled);
    memset(raw, 0, sizeof(raw));
    raw[1] = PAD_RIGHT;
    input_map_frame(raw);
    assert(g_player_intents[1].move_x == 1);
    assert(g_player_intents[2].move_x == 0);
    /* Versus: port 2 is slot 2's again, and slot 1 has no pad. */
    match_config_doubles();
    g_match_config.human[2] = 1;
    game_new_match();
    assert(g_input_pad_for_player[1] == INPUT_NO_PAD);
    input_map_frame(raw);
    assert(g_player_intents[2].move_x == 1);
    match_config_defaults();
    game_new_match();
}

/* M4-OPEN-05: the clubhouse. Its walls are solid; the door in the bottom
 * wall lets you in. Inside, B at the board turns its page and B at the
 * ball machine asks for practice; the bench seats the first two teams
 * waiting. */
static void test_clubhouse(void)
{
    u16 n;

    open_play_begin(7, 0);
    /* Walls, inside, the door. */
    assert(!open_walkable(TO_FP(OPEN_HOUSE_LEFT + 2), TO_FP(100)));
    assert(!open_walkable(TO_FP(OPEN_HOUSE_RIGHT - 2), TO_FP(100)));
    assert(!open_walkable(TO_FP(360), TO_FP(OPEN_HOUSE_TOP + 2)));
    assert(!open_walkable(TO_FP(340), TO_FP(OPEN_HOUSE_BOTTOM - 2)));
    assert(open_walkable(TO_FP(360), TO_FP(100)));
    assert(open_walkable(TO_FP(OPEN_HOUSE_DOOR_X),
        TO_FP(OPEN_HOUSE_BOTTOM - 2)));
    assert(open_walkable(TO_FP(OPEN_HOUSE_LEFT - 8), TO_FP(100)));
    /* Walk in: along the path to the door, then up through it. */
    place_you(OPEN_HOUSE_DOOR_X, OPEN_START_Y);
    assert(!open_in_house());
    for (n = 0; n < 60; ++n)
        open_play_update(0, -1, 0);
    assert(open_in_house());
    /* Walking into a wall from inside stops at it. */
    for (n = 0; n < 200; ++n)
        open_play_update(1, 0, 0);
    assert(FROM_FP(g_open_play.x_fp) <
        OPEN_HOUSE_RIGHT - OPEN_HOUSE_WALL);
    /* The board: each B the next page, round again; leaving clears it. */
    place_you(OPEN_BOARD_X, OPEN_BOARD_Y);
    assert(open_play_update(0, 0, 1) == OPEN_EVENT_BOARD);
    assert(g_open_play.board_page == 0);
    for (n = 1; n < OPEN_BOARD_PAGES; ++n)
        open_play_update(0, 0, 1);
    assert(g_open_play.board_page == OPEN_BOARD_PAGES - 1);
    open_play_update(0, 0, 1);
    assert(g_open_play.board_page == 0);
    place_you(400, 120);
    open_play_update(0, 0, 0);
    assert(g_open_play.board_page == OPEN_NONE);
    /* The ball machine. */
    place_you(OPEN_MACHINE_X, OPEN_MACHINE_Y);
    assert(open_machine_near());
    assert(open_play_update(0, 0, 1) == OPEN_EVENT_PRACTICE);
    /* The bench: the two teams waiting at the start (one each at the
     * first two levels' courts). */
    assert(open_waiting_team(0) < OPPONENT_COUNT);
    assert(open_waiting_team(1) < OPPONENT_COUNT);
    assert(open_waiting_team(0) != open_waiting_team(1));
    assert(open_waiting_team(2) == OPEN_NONE);
    place_you(OPEN_BENCH_X + 24, OPEN_BENCH_Y + 8);
    assert(open_bench_near());
    check_population();
}

int main(void)
{
    test_levels();
    test_begin();
    test_walking();
    test_stacking();
    test_your_turn();
    test_soak();
    test_two_players();
    test_clubhouse();
    printf("open play host checks passed\n");
    return 0;
}
