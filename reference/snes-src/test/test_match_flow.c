#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "ai.h"
#include "game.h"
#include "rules.h"
#include "serve.h"
#include "test_support.h"

static PlayerIntent intents[MAX_PLAYERS];

typedef struct {
    GameState game;
    Player players[MAX_PLAYERS];
    Ball ball;
    ServeState serve;
    AiState ai[MAX_PLAYERS];
} Snapshot;

static void snapshot(Snapshot *s)
{
    memset(s, 0, sizeof(*s));
    s->game = g_game_state;
    memcpy(s->players, g_players, sizeof(g_players));
    s->ball = g_ball;
    s->serve = g_serve_state;
    memcpy(s->ai, g_ai_slots, sizeof(g_ai_slots));
}

/*
 * P1 stand-in: the same AI with a human skill level. `late` is how often it
 * mistimes a swing (every Nth shot); reaction and foot speed vary by match.
 */
static u8 s_bot_late;
static u8 s_match_index;

static void bot_p1(void)
{
    test_bot_skill(s_bot_late, s_match_index);
}

static void frame(u8 p1_bot, u8 press_b)
{
    memset(intents, 0, sizeof(intents));
    if (p1_bot)
        ai_update(0, &intents[0]);
    intents[0].hit_pressed |= press_b;
    test_step(intents);
}

static void test_first_to_five(void)
{
    u16 n;

    game_new_match();
    g_game_state.team_score[0] = 4;
    g_game_state.phase = GAME_PHASE_LIVE;
    g_ball.rally_state = BALL_RALLY_LIVE;
    rules_resolve_point(1, GAME_FAULT_OUT);
    assert(g_game_state.phase == GAME_PHASE_POINT_RESULT);
    assert(g_game_state.team_score[0] == 5);
    /* B is ignored before the minimum result time, then advances. */
    frame(0, 1);
    assert(g_game_state.phase == GAME_PHASE_POINT_RESULT);
    for (n = 0; n < GAME_POINT_RESULT_FRAMES + 2; ++n)
        frame(0, 0);
    assert(g_game_state.phase == GAME_PHASE_MATCH_RESULT);
    assert(g_game_state.match_winner == 0);
    /* MATCH_RESULT waits for B; it never times out. */
    for (n = 0; n < 600; ++n)
        frame(0, 0);
    assert(g_game_state.phase == GAME_PHASE_MATCH_RESULT);
    frame(0, 1);
    assert(g_game_state.phase == GAME_PHASE_SERVE_SETUP);
    assert(g_game_state.team_score[0] == 0 && g_game_state.team_score[1] == 0);
}

/* Plays one bot-vs-CPU match to the result screen; returns frames used. */
static unsigned long play_match(u8 *p1_points, u8 *cpu_points)
{
    unsigned long frames = 0;

    bot_p1();
    while (g_game_state.phase != GAME_PHASE_MATCH_RESULT) {
        /* The bot also has to press B to serve and to skip results. */
        bot_p1();
        frame(1, g_game_state.phase == GAME_PHASE_SERVE_SETUP &&
            g_serve_state.server_index == 0 && (frames & 31) == 0);
        ++frames;
        assert(frames < 60UL * 60 * 10);
    }
    *p1_points = g_game_state.team_score[0];
    *cpu_points = g_game_state.team_score[1];
    return frames;
}

static void test_rematch_matches_fresh_state(void)
{
    Snapshot fresh;
    Snapshot again;
    u8 i;
    u8 p1;
    u8 cpu;
    unsigned long frames;
    unsigned long total = 0;
    u8 p1_wins = 0;
    u16 p1_points = 0;

    s_bot_late = 4;
    game_new_match();
    snapshot(&fresh);
    for (i = 0; i < 20; ++i) {
        s_match_index = i;
        frames = play_match(&p1, &cpu);
        total += frames;
        p1_points += p1;
        if (p1 > cpu)
            ++p1_wins;
        /* Rematch through the real input path. */
        while (g_game_state.phase == GAME_PHASE_MATCH_RESULT)
            frame(0, 1);
        snapshot(&again);
        again.game.frame_count = fresh.game.frame_count;
        assert(memcmp(&fresh, &again, sizeof(fresh)) == 0);       /* RST-01 */
    }
    printf("20 rematches: avg %.1f s, bot won %d, avg points %.1f\n",
        total / 20.0 / 60.0, p1_wins, p1_points / 20.0);
}

/* M3-MATCH-04: the CPU beats sloppy timing but loses to sharp timing. */
static u8 bot_wins(u8 late)
{
    u8 i;
    u8 p1;
    u8 cpu;
    u8 wins = 0;

    s_bot_late = late;
    for (i = 0; i < 20; ++i) {
        s_match_index = i;
        game_new_match();
        play_match(&p1, &cpu);
        wins += p1 > cpu;
    }
    return wins;
}

static void test_cpu_is_beatable_but_not_trivial(void)
{
    u8 novice = bot_wins(2);
    u8 strong = bot_wins(10);

    printf("bot wins of 20: mistimes every 2nd shot %d, every 10th %d\n",
        novice, strong);
    assert(novice <= 5);
    assert(strong >= 15);
}

int main(void)
{
    test_first_to_five();
    test_rematch_matches_fresh_state();
    test_cpu_is_beatable_but_not_trivial();
    puts("match flow host checks passed");
    return 0;
}
