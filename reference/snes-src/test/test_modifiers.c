#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "ai.h"
#include "ball.h"
#include "collision.h"
#include "court_style.h"
#include "game.h"
#include "input.h"
#include "match.h"
#include "modifiers.h"
#include "options.h"
#include "rules.h"
#include "save.h"
#include "select.h"
#include "serve.h"
#include "test_support.h"

/* ADR-033 play modifiers: BIG BALL, FAST BALL, WIN BY 2, LAVA. */

static void test_values_and_editor(void)
{
    u8 mods = 0xf5;

    assert(modifiers_valid(0xff) == MODIFIER_ALL);
    assert(strcmp(modifiers_value_name(MODIFIERS_ROW_BALL, 0), "NORMAL") == 0);
    assert(strcmp(modifiers_value_name(MODIFIERS_ROW_BALL, MODIFIER_BIG_BALL),
        "BIG") == 0);
    assert(strcmp(modifiers_value_name(MODIFIERS_ROW_SCORING,
        MODIFIER_WIN_BY_2), "WIN BY 2") == 0);
    assert(strcmp(modifiers_value_name(MODIFIERS_ROW_KITCHEN, MODIFIER_LAVA),
        "LAVA") == 0);

    /* The editor makes the value valid, toggles a row's bit with
     * Left/Right, wraps rows, and Y puts the value back. */
    modifiers_edit_begin(&mods);
    assert(mods == 5 && g_modifiers_edit.row == MODIFIERS_ROW_BALL);
    assert(modifiers_edit_input(&mods, PAD_RIGHT) == MODIFIERS_EDIT_STAY);
    assert(mods == 4 && modifiers_edit_changed(mods));
    modifiers_edit_input(&mods, PAD_UP);
    assert(g_modifiers_edit.row == MODIFIERS_ROW_KITCHEN);
    modifiers_edit_input(&mods, PAD_LEFT);
    assert(mods == (MODIFIER_WIN_BY_2 | MODIFIER_LAVA));
    modifiers_edit_input(&mods, PAD_DOWN);
    assert(g_modifiers_edit.row == MODIFIERS_ROW_BALL);
    assert(modifiers_edit_input(&mods, PAD_Y) == MODIFIERS_EDIT_CANCEL);
    assert(mods == 5 && !modifiers_edit_changed(mods));
    modifiers_edit_input(&mods, PAD_DOWN);
    modifiers_edit_input(&mods, PAD_RIGHT);
    assert(modifiers_edit_input(&mods, PAD_B) == MODIFIERS_EDIT_DONE);
    assert(mods == 7);
}

/* Player Select copies the saved modifiers; the demo plays without. */
static void test_select_copies(void)
{
    memset(g_host_sram, 0, sizeof(g_host_sram));
    save_initialize();
    assert(g_save.settings.modifiers == 0);
    g_save.settings.modifiers = MODIFIER_FAST_BALL | MODIFIER_LAVA | 0x40;
    select_begin(MATCH_SINGLES, 1);
    select_apply();
    assert(g_match_config.modifiers == (MODIFIER_FAST_BALL | MODIFIER_LAVA));
    game_start_attract();
    assert(g_match_config.modifiers == 0);
    match_config_defaults();
    g_attract = 0;
}

/* The pace over a cycle: the difficulty times BALL SPEED, spread evenly
 * (never two in a row missed below 100%), plus FAST BALL's every 3rd. */
static void test_ball_steps(void)
{
    u8 pace[GAME_BALL_PACE_TICKS];
    u16 count;
    u8 t;

    modifiers_ball_pace(pace, OPTIONS_BALL_CYCLE, DIFFICULTY_MEDIUM, 0, 90);
    for (count = 0, t = 0; t < OPTIONS_BALL_CYCLE; ++t) {
        assert(pace[t] <= 1);
        assert(t == 0 || pace[t] || pace[t - 1]);   /* spread out */
        count += pace[t];
    }
    assert(count == 54);
    modifiers_ball_pace(pace, OPTIONS_BALL_CYCLE, DIFFICULTY_KID, 0, 100);
    for (count = 0, t = 0; t < OPTIONS_BALL_CYCLE; ++t)
        count += pace[t];
    assert(count == 40);
    /* FAST BALL adds 20 a cycle; 120% takes two steps on some frames. */
    modifiers_ball_pace(pace, OPTIONS_BALL_CYCLE, DIFFICULTY_MEDIUM,
        MODIFIER_FAST_BALL, 100);
    for (count = 0, t = 0; t < OPTIONS_BALL_CYCLE; ++t)
        count += pace[t];
    assert(count == 80);
    modifiers_ball_pace(pace, OPTIONS_BALL_CYCLE, DIFFICULTY_MEDIUM, 0, 120);
    for (count = 0, t = 0; t < OPTIONS_BALL_CYCLE; ++t) {
        assert(pace[t] >= 1 && pace[t] <= 2);
        count += pace[t];
    }
    assert(count == 72);
    /* The lookahead past the cycle repeats its start. */
    modifiers_ball_pace(pace, GAME_BALL_PACE_TICKS, DIFFICULTY_EASY, 0, 90);
    for (t = 0; t < GAME_BALL_PACE_TICKS - OPTIONS_BALL_CYCLE; ++t)
        assert(pace[OPTIONS_BALL_CYCLE + t] == pace[t]);
}

/* Frames from a launch until the first bounce, and where it lands. */
static u8 frames_to_bounce(u8 modifiers, fx *land_x)
{
    PlayerIntent intents[MAX_PLAYERS];
    u8 frames = 0;

    memset(intents, 0, sizeof(intents));
    match_config_defaults();
    g_match_config.modifiers = modifiers;
    g_attract = 0;
    game_new_match();
    g_game_state.phase = GAME_PHASE_LIVE;
    g_game_state.required_bounce = GAME_REQUIRED_BOUNCE_NONE;
    g_ball.rally_state = BALL_RALLY_LIVE;
    g_ball.active = 1;
    g_ball.last_hitter = 0;
    g_ball.bounce_count = 0;
    g_ball.x_fp = TO_FP(80);
    g_ball.y_fp = TO_FP(130);
    g_ball.z_fp = TO_FP(20);
    ball_launch(&g_ball, 200, 130, 40);
    /* Out of everyone's reach: no one hits it. */
    g_players[2].x_fp = TO_FP(236);
    g_players[2].y_fp = TO_FP(96);
    while (g_ball.bounce_count == 0 && frames < 100) {
        game_update(intents);
        ++frames;
    }
    *land_x = g_ball.x_fp;
    return frames;
}

/* The same arc and landing, in three quarters of the frames. */
static void test_fast_ball_arc(void)
{
    fx normal_x;
    fx fast_x;
    u8 normal = frames_to_bounce(0, &normal_x);
    u8 fast = frames_to_bounce(MODIFIER_FAST_BALL, &fast_x);

    printf("modifiers: a 40-step shot bounces after %u frames, %u with FAST "
        "BALL\n", normal, fast);
    assert(normal == 40);
    assert(fast == 30);
    assert(normal_x == fast_x);
    match_config_defaults();
}

/* BIG BALL: reach and sweet spot grow by MODIFIER_BIG_REACH. */
static void test_big_ball_reach(void)
{
    Player player;
    Ball ball;

    memset(&player, 0, sizeof(player));
    memset(&ball, 0, sizeof(ball));
    player.active = 1;
    player.x_fp = TO_FP(60);
    player.y_fp = TO_FP(130);
    ball.active = 1;
    ball.rally_state = BALL_RALLY_LIVE;
    ball.x_fp = TO_FP(60 + HIT_REACH_X + 2);
    ball.y_fp = TO_FP(130);
    ball.z_fp = TO_FP(10);
    collision_configure(0);
    assert(!collision_ball_in_player_reach(&player, &ball));
    collision_configure(1);
    assert(collision_ball_in_player_reach(&player, &ball));
    ball.x_fp = TO_FP(60 + HIT_REACH_X + MODIFIER_BIG_REACH + 1);
    assert(!collision_ball_in_player_reach(&player, &ball));
    ball.x_fp = TO_FP(60);
    ball.z_fp = TO_FP(HIT_REACH_Z + 2);
    assert(collision_ball_in_player_reach(&player, &ball));
    ball.z_fp = TO_FP(10);
    ball.y_fp = TO_FP(130 + HIT_SWEET_Y + 2);
    assert(collision_ball_in_sweet_spot(&player, &ball));
    collision_configure(0);
    assert(!collision_ball_in_sweet_spot(&player, &ball));
}

/* Plays out one point for `winner` from the live phase. */
static void award_point(u8 winner)
{
    PlayerIntent intents[MAX_PLAYERS];
    u16 n;

    memset(intents, 0, sizeof(intents));
    g_game_state.phase = GAME_PHASE_LIVE;
    g_ball.rally_state = BALL_RALLY_LIVE;
    rules_resolve_point(winner ^ 1, GAME_FAULT_OUT);
    for (n = 0; n < 400 && g_game_state.phase == GAME_PHASE_POINT_RESULT; ++n)
        game_update(intents);
}

/* WIN BY 2: 5-4 plays on, 6-4 wins; MATCH POINT follows the lead. */
static void test_win_by_2(void)
{
    u8 i;

    match_config_defaults();
    g_game_state.team_score[0] = 5;
    g_game_state.team_score[1] = 4;
    assert(game_team_won(0) && !game_team_won(1));
    g_game_state.team_score[0] = 4;
    assert(game_match_point(0) && game_match_point(1));
    g_match_config.modifiers = MODIFIER_WIN_BY_2;
    assert(!game_match_point(0) && !game_match_point(1));
    g_game_state.team_score[0] = 5;
    assert(!game_team_won(0) && game_match_point(0) && !game_match_point(1));
    g_game_state.team_score[0] = 6;
    assert(game_team_won(0));
    g_game_state.team_score[1] = 0;
    g_game_state.team_score[0] = 5;
    assert(game_team_won(0));

    match_config_defaults();
    g_match_config.modifiers = MODIFIER_WIN_BY_2;
    g_attract = 0;
    game_new_match();
    for (i = 0; i < 4; ++i) {
        award_point(0);
        award_point(1);
    }
    award_point(0);                             /* 5-4 */
    assert(g_game_state.phase != GAME_PHASE_MATCH_RESULT);
    assert(game_match_point(0) && !game_match_point(1));
    award_point(1);                             /* 5-5: deuce */
    assert(!game_match_point(0) && !game_match_point(1));
    award_point(1);                             /* 5-6 */
    assert(g_game_state.phase != GAME_PHASE_MATCH_RESULT);
    assert(!game_match_point(0) && game_match_point(1));
    award_point(1);                             /* 5-7 */
    assert(g_game_state.phase == GAME_PHASE_MATCH_RESULT);
    assert(g_game_state.match_winner == 1);
    assert(g_game_state.team_score[1] == 7);
    match_config_defaults();
}

/* LAVA: a foot in your own kitchen during a rally loses the point. */
static void test_lava_rule(void)
{
    PlayerIntent intents[MAX_PLAYERS];
    u8 mods;

    assert(modifiers_in_kitchen(TO_FP(COURT_KITCHEN_LEFT_X + 1),
        TO_FP(COURT_CENTERLINE_Y), 0));
    assert(!modifiers_in_kitchen(TO_FP(COURT_KITCHEN_LEFT_X),
        TO_FP(COURT_CENTERLINE_Y), 0));
    assert(!modifiers_in_kitchen(TO_FP(COURT_KITCHEN_LEFT_X + 1),
        TO_FP(COURT_SIDELINE_TOP - 2), 0));
    assert(modifiers_in_kitchen(TO_FP(COURT_KITCHEN_RIGHT_X - 1),
        TO_FP(COURT_CENTERLINE_Y), 1));
    assert(!modifiers_in_kitchen(TO_FP(COURT_KITCHEN_RIGHT_X - 1),
        TO_FP(COURT_CENTERLINE_Y), 0));
    assert(modifiers_lava_target(120, 0) ==
        COURT_KITCHEN_LEFT_X - MODIFIER_LAVA_MARGIN);
    assert(modifiers_lava_target(40, 0) == 40);
    assert(modifiers_lava_target(140, 1) ==
        COURT_KITCHEN_RIGHT_X + MODIFIER_LAVA_MARGIN);

    memset(intents, 0, sizeof(intents));
    for (mods = 0; mods <= MODIFIER_LAVA; mods += MODIFIER_LAVA) {
        match_config_defaults();
        g_match_config.modifiers = mods;
        g_attract = 0;
        game_new_match();
        g_game_state.phase = GAME_PHASE_LIVE;
        g_ball.rally_state = BALL_RALLY_LIVE;
        g_ball.active = 1;
        g_ball.z_fp = TO_FP(30);
        ball_launch(&g_ball, 200, 130, 40);
        g_players[0].x_fp = TO_FP(COURT_KITCHEN_LEFT_X + 6);
        g_players[0].y_fp = TO_FP(COURT_CENTERLINE_Y);
        game_update(intents);
        if (mods) {
            assert(g_game_state.phase == GAME_PHASE_POINT_RESULT);
            assert(g_game_state.last_fault == GAME_FAULT_LAVA);
            assert(g_game_state.point_winner == 1);
        } else {
            assert(g_game_state.phase == GAME_PHASE_LIVE);
        }
    }
    match_config_defaults();
}

/* The LAVA kitchen recolours exactly the kitchen's entries. */
static void test_lava_colors(void)
{
    u16 plain[COURT_GROUND_COLORS];
    u16 lava[COURT_GROUND_COLORS];
    u16 painted[COURT_GROUND_COLORS];
    u8 choice[COURT_PARTS];
    u8 changed = 0;
    u8 i;

    for (i = 0; i < COURT_GROUND_COLORS; ++i)
        painted[i] = (u16)(i * 0x111);
    memset(choice, 0, sizeof(choice));
    court_style_compose(plain, painted, choice, 0);
    memcpy(lava, plain, sizeof(lava));
    court_style_lava(lava);
    for (i = 0; i < COURT_GROUND_COLORS; ++i) {
        if (lava[i] == plain[i])
            continue;
        ++changed;
        assert(i == g_court_part_entries[COURT_PART_KITCHEN][0] ||
            i == g_court_part_entries[COURT_PART_KITCHEN][1]);
    }
    assert(changed == g_court_part_size[COURT_PART_KITCHEN]);
}

typedef struct {
    int wins;
    int points;
    int shots;
    int lava[2];
    int close_wins;             /* won by one point */
} MatchStats;

/* Bot (slot 0, the same AI) vs a CPU opponent (OPPONENT_NONE: the
 * default) with modifiers; in doubles every other slot is a CPU too. */
static MatchStats bot_matches(u8 modifiers, u8 matches, u8 mode, u8 opponent)
{
    PlayerIntent intents[MAX_PLAYERS];
    MatchStats stats;
    unsigned long frames = 0;
    u8 match = 0;
    u8 counted = 0;
    u8 scored = 0;
    u8 serial = 0;

    memset(&stats, 0, sizeof(stats));
    if (mode == MATCH_DOUBLES)
        match_config_doubles();
    else
        match_config_defaults();
    match_config_opponent(opponent);
    g_match_config.modifiers = modifiers;
    g_attract = 0;
    game_new_match();
    while (match < matches && frames < 60UL * 60 * 60) {
        test_bot_skill(5, match);
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
                stats.wins += g_game_state.match_winner == 0;
                stats.close_wins += g_game_state.team_score[0] ==
                    g_game_state.team_score[1] + 1 ||
                    g_game_state.team_score[1] ==
                    g_game_state.team_score[0] + 1;
            }
        } else {
            counted = 0;
        }
        if (g_game_state.phase == GAME_PHASE_POINT_RESULT) {
            if (!scored) {
                scored = 1;
                ++stats.points;
                if (g_game_state.last_fault == GAME_FAULT_LAVA)
                    ++stats.lava[g_game_state.point_winner ^ 1];
            }
        } else {
            scored = 0;
        }
        if (mode == MATCH_DOUBLES) {
            ai_update(1, &intents[1]);
            ai_update(3, &intents[3]);
        }
        test_step(intents);
        /* B after a ladder win asks main.c for the next opponent: here,
         * the same one again. */
        if (g_next_opponent)
            game_new_match();
        if (g_game_state.shot_serial != serial) {
            serial = g_game_state.shot_serial;
            ++stats.shots;
        }
        ++frames;
    }
    assert(match == matches);
    match_config_defaults();
    return stats;
}

static void test_matches(void)
{
    static const char *const names[5] = {
        "none", "BIG BALL", "FAST BALL", "WIN BY 2", "LAVA"
    };
    static const u8 mods[5] = {
        0, MODIFIER_BIG_BALL, MODIFIER_FAST_BALL, MODIFIER_WIN_BY_2,
        MODIFIER_LAVA
    };
    MatchStats stats[5];
    u8 i;

    for (i = 0; i < 5; ++i) {
        stats[i] = bot_matches(mods[i], 12, MATCH_SINGLES, OPPONENT_NONE);
        printf("modifiers: %-9s bot wins %2d of 12, %3d points, %.1f shots "
            "a point, lava faults P1 %d CPU %d\n", names[i], stats[i].wins,
            stats[i].points, (double)stats[i].shots / stats[i].points,
            stats[i].lava[0], stats[i].lava[1]);
    }
    /* Rallies still happen. AI against AI, a big ball makes them shorter
     * (ADR-033): the larger sweet spot puts more shots where aimed. */
    assert(stats[1].shots > 2 * stats[1].points);
    assert(stats[2].shots > 2 * stats[2].points);
    /* WIN BY 2 never ends a match on a one-point lead. */
    assert(stats[3].close_wins == 0);
    /* CPUs (both of these are the AI) never step into the lava. */
    assert(stats[4].lava[0] == 0 && stats[4].lava[1] == 0);
}

/* The CPU's nearest x while chasing a short ball into its kitchen. */
static fx cpu_chase_min_x(u8 modifiers)
{
    PlayerIntent intents[MAX_PLAYERS];
    fx min_x = 0x7fff;
    u8 f;

    match_config_defaults();
    g_match_config.modifiers = modifiers;
    g_attract = 0;
    game_new_match();
    g_game_state.phase = GAME_PHASE_LIVE;
    g_game_state.required_bounce = GAME_REQUIRED_BOUNCE_NONE;
    g_ball.rally_state = BALL_RALLY_LIVE;
    g_ball.active = 1;
    g_ball.last_hitter = 0;
    g_ball.bounce_count = 0;
    g_ball.x_fp = TO_FP(100);
    g_ball.y_fp = TO_FP(130);
    g_ball.z_fp = TO_FP(16);
    ball_launch(&g_ball, 136, 130, 34);     /* a drop shot, 8 px past the net */
    g_players[2].x_fp = TO_FP(COURT_KITCHEN_RIGHT_X + 12);
    g_players[2].y_fp = TO_FP(130);
    for (f = 0; f < 60 && g_game_state.phase == GAME_PHASE_LIVE; ++f) {
        memset(intents, 0, sizeof(intents));
        test_step(intents);
        if (g_players[2].x_fp < min_x)
            min_x = g_players[2].x_fp;
    }
    printf("modifiers: CPU chasing a drop shot gets to x %d (LAVA: %s)\n",
        FROM_FP(min_x), modifiers ? "on" : "off");
    match_config_defaults();
    return min_x;
}

/* No CPU steps into the lava: every ladder opponent, singles and doubles
 * (where the net players and the human's CPU partner play too). */
static void test_lava_cpus(void)
{
    MatchStats stats;
    int points = 0;
    u8 mode;
    u8 o;

    /* A drop shot pulls the CPU into its kitchen, but not onto lava. */
    assert(cpu_chase_min_x(0) < TO_FP(COURT_KITCHEN_RIGHT_X));
    assert(cpu_chase_min_x(MODIFIER_LAVA) >= TO_FP(COURT_KITCHEN_RIGHT_X));
    for (mode = MATCH_SINGLES; mode <= MATCH_DOUBLES; ++mode) {
        for (o = 0; o < OPPONENT_COUNT; ++o) {
            stats = bot_matches(MODIFIER_LAVA, 2, mode, o);
            points += stats.points;
            assert(stats.lava[0] == 0 && stats.lava[1] == 0);
        }
    }
    printf("modifiers: LAVA, %d points against every opponent in singles "
        "and doubles, no CPU in the lava\n", points);
}

int main(void)
{
    test_values_and_editor();
    test_select_copies();
    test_ball_steps();
    test_fast_ball_arc();
    test_big_ball_reach();
    test_win_by_2();
    test_lava_rule();
    test_lava_colors();
    test_matches();
    test_lava_cpus();
    printf("modifiers host checks passed\n");
    return 0;
}
