/*
 * Bot-vs-CPU balance statistics (docs/REFACTOR_PLAN.md R1, M3-MATCH-04).
 *
 * Plays N full matches on the host using the real simulation sources: the
 * CPU at its shipped difficulty against a stand-in P1 driven by the same AI
 * with a human skill level. Prints match length, win rate, and how points
 * ended.
 *
 * Doubles (M4-OPP-02) plays P1 with the CPU partner a human gets (the
 * partner style, ADR-035) against both CPUs of the team. The regular bot
 * stays back like the default CPU; the net bot plays the net (the partner
 * style without footwork: a human mis-hits too), as in ADR-038.
 *
 *   make stats                     # defaults
 *   build/host/match_stats 4 20    # P1 mistimes every 4th shot, 20 matches
 *   build/host/match_stats 4 20 3  # ... against opponent 3 (ADR-023)
 *   build/host/match_stats 4 20 -1 1  # ... default CPU on EASY (ADR-025)
 *   build/host/match_stats 4 20 3 2 1 # ... opponent 3 in doubles
 *   build/host/match_stats 0 20 -2 2 3 # the doubles ladder, net bot, at
 *                                      # three bot skills (LATE 0)
 *
 * SPEED (6th): BALL SPEED percent (70..120 by 5; ADR-049), default 100.
 * MODE (5th): 0 singles, 1 doubles, +2 the net bot. OPPONENT -2 runs every
 * ladder opponent in order and prints a table; LATE 0 adds up three bot
 * skills (late every 3rd, 4th, and 5th shot) like the ADR tables.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ai.h"
#include "game.h"
#include "match.h"
#include "options.h"
#include "save.h"
#include "serve.h"
#include "test_support.h"

enum { MODE_DOUBLES = 1, MODE_NET_BOT = 2, FAULTS = 7 };

static PlayerIntent intents[MAX_PLAYERS];
static const char *fault_names[FAULTS] = {
    "none", "net", "kitchen", "wrong box", "out", "2 bounces", "volley"
};

typedef struct {
    int matches;
    int bot_wins;
    int points;
    unsigned long frames;
    int faults[2][FAULTS];
} Stats;

/* The net bot (ADR-038): the partner style without footwork. */
static void net_bot(void)
{
    g_ai_styles[0] = g_ai_partner_style;
    g_ai_styles[0].footwork = 0;
}

static void play(int late, int matches, int opponent, int difficulty,
    int mode, Stats *stats)
{
    unsigned long frames = 0;
    unsigned long cap = 60UL * 60 * 60;
    u8 previous = 0xff;
    u8 counted = 0;
    int match = 0;

    if (mode & MODE_DOUBLES)
        match_config_doubles();
    else
        match_config_defaults();
    if (opponent >= 0)
        match_config_opponent((u8)opponent);
    g_match_config.difficulty = (u8)difficulty;
    g_attract = 0;
    game_new_match();
    if (mode & MODE_NET_BOT)
        net_bot();
    while (match < matches && frames < cap) {
        test_bot_skill((u8)late, (u8)match);
        memset(intents, 0, sizeof(intents));
        ai_update(0, &intents[0]);
        if (g_game_state.phase == GAME_PHASE_SERVE_SETUP &&
            g_serve_state.server_index == 0 && (frames & 31) == 0)
            intents[0].hit_pressed = 1;
        if (g_game_state.phase == GAME_PHASE_MATCH_RESULT) {
            intents[0].hit_pressed = 1;
            if (!counted) {
                counted = 1;
                ++match;
                stats->bot_wins += g_game_state.match_winner == 0;
            }
        } else {
            counted = 0;
        }
        /* Doubles: the CPUs on main.c's schedule (a lane-covering CPU
         * thinks every fourth frame). */
        if (mode & MODE_DOUBLES)
            test_step_scheduled(intents, (u16)frames);
        else
            test_step(intents);
        /* Measuring one opponent: a win's B rematches them here. */
        if (g_next_opponent) {
            game_new_match();
            if (mode & MODE_NET_BOT)
                net_bot();
        }
        ++frames;
        if (g_game_state.phase == GAME_PHASE_POINT_RESULT &&
            previous != GAME_PHASE_POINT_RESULT) {
            ++stats->faults[g_game_state.point_winner]
                [g_game_state.last_fault % FAULTS];
            ++stats->points;
        }
        previous = g_game_state.phase;
    }
    stats->matches += match;
    stats->frames += frames;
}

/* LATE 0: three bot skills, as the ADR tables measure. */
static void play_skills(int late, int matches, int opponent, int difficulty,
    int mode, Stats *stats)
{
    int skill;

    memset(stats, 0, sizeof(*stats));
    if (late)
        play(late, matches, opponent, difficulty, mode, stats);
    else
        for (skill = 3; skill <= 5; ++skill)
            play(skill, matches, opponent, difficulty, mode, stats);
}

static const char *opponent_name(int opponent, int mode)
{
    if (opponent < 0 || opponent >= OPPONENT_COUNT)
        return "default CPU";
    return (mode & MODE_DOUBLES) ? g_opponent_team[opponent] :
        g_opponent_captain[opponent];
}

int main(int argc, char **argv)
{
    int late = argc > 1 ? atoi(argv[1]) : 4;
    int matches = argc > 2 ? atoi(argv[2]) : 20;
    int opponent = argc > 3 ? atoi(argv[3]) : -1;
    int difficulty = argc > 4 ? atoi(argv[4]) : DIFFICULTY_MEDIUM;
    int mode = argc > 5 ? atoi(argv[5]) : 0;
    int speed = argc > 6 ? atoi(argv[6]) : 0;
    u8 choice;

    /* SPEED (6th, ADR-049): a BALL SPEED percent; 0 keeps the default. */
    for (choice = 0; speed && choice < OPTIONS_SPEED_CHOICES; ++choice)
        if (g_options_speeds[choice] == speed)
            g_save.settings.ball_speed = choice + 1;
    Stats stats;
    int team;
    int i;

    printf("%s, %s bot, P1 late %s; %d matches each on %s\n",
        (mode & MODE_DOUBLES) ? "Doubles (P1 + CPU partner)" : "Singles",
        (mode & MODE_NET_BOT) ? "net" : "regular",
        late ? "" : "every 3rd/4th/5th", late ? matches : matches * 3,
        options_difficulty_name((u8)difficulty));
    if (late)
        printf("  (P1 mistimes every %d shot(s))\n", late);

    if (opponent == -2) {
        /* The ladder (M4-OPP-02): each rung should be harder. */
        int previous = 0x7fff;
        int ordered = 1;

        printf("  %-10s %9s %8s %7s\n", "rung", "bot wins", "of", "avg s");
        for (i = 0; i < OPPONENT_COUNT; ++i) {
            play_skills(late, matches, i, difficulty, mode, &stats);
            printf("  %d %-10s %7d %8d %7.1f%s\n", i + 1,
                opponent_name(i, mode), stats.bot_wins, stats.matches,
                stats.matches ? stats.frames / 60.0 / stats.matches : 0.0,
                stats.bot_wins > previous ? "  (easier than the rung before)" :
                "");
            if (stats.bot_wins > previous)
                ordered = 0;
            previous = stats.bot_wins;
        }
        printf("  ladder order: %s\n", ordered ? "yes" : "NO");
        return 0;
    }

    play_skills(late, matches, opponent, difficulty, mode, &stats);
    printf("  vs %s: P1 won %d of %d matches; average match %.1f s; "
        "%d points\n", opponent_name(opponent, mode), stats.bot_wins,
        stats.matches,
        stats.matches ? stats.frames / 60.0 / stats.matches : 0.0,
        stats.points);
    for (team = 0; team < 2; ++team) {
        printf("  points won by %s:", team ? "CPU" : "P1 ");
        for (i = 0; i < FAULTS; ++i)
            if (stats.faults[team][i])
                printf(" %s %d", fault_names[i], stats.faults[team][i]);
        printf("\n");
    }
    return 0;
}
