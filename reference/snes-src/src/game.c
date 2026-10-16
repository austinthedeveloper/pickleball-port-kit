#include <string.h>
#include "ai.h"
#include "ball.h"
#include "career.h"
#include "collision.h"
#include "events.h"
#include "fx.h"
#include "input.h"
#include "match.h"
#include "modifiers.h"
#include "options.h"
#include "paddle_stats.h"
#include "practice.h"
#include "game.h"
#include "player.h"
#include "profile.h"
#include "rules.h"
#include "replay.h"
#include "save.h"
#include "serve.h"

GameState g_game_state;
u8 g_attract;
u8 g_match_config_changed;
/* Mode of the next attract demo; boot starts with singles. */
u8 g_demo_mode;
u8 g_next_opponent;
u8 g_back_to_park;
/* shot_serial at the serve: a point's rally length is the difference.
 * Outside g_game_state, which golden traces compare byte for byte. */
static u8 s_rally_start;
/* Ball pace (ADR-025/033); outside g_game_state. */
u8 g_ball_tick;
u8 g_ball_paced;
u8 g_ball_pace[GAME_BALL_PACE_TICKS];
u16 g_ball_steps;

#define GAME_SCORE_WINS(score, other) \
    MODIFIERS_SCORE_WINS(score, other, g_match_config.points_to_win, \
        g_match_config.modifiers)

u8 game_team_won(u8 team)
{
    return GAME_SCORE_WINS(g_game_state.team_score[team],
        g_game_state.team_score[team ^ 1]);
}

u8 game_match_point(u8 team)
{
    return GAME_SCORE_WINS(g_game_state.team_score[team] + 1,
        g_game_state.team_score[team ^ 1]);
}

void game_set_phase(u8 phase)
{
    g_game_state.phase = phase;
    g_game_state.phase_timer = 0;
}

void game_initialize(void)
{
    /* Zero padding too: the struct is compared whole by RST-01 and traces. */
    memset(&g_game_state, 0, sizeof(g_game_state));
    g_game_state.paused = 0;
    g_game_state.last_fault = GAME_FAULT_NONE;
    g_game_state.point_winner = GAME_NO_TEAM;
    g_game_state.match_winner = GAME_NO_TEAM;
    g_game_state.team_score[0] = 0;
    g_game_state.team_score[1] = 0;
    g_game_state.required_bounce = GAME_REQUIRED_BOUNCE_NONE;
    g_game_state.serving_team = 0;
    g_game_state.hit_stop = 0;
    g_game_state.shot_serial = 0;
    g_game_state.frame_count = 0;
    game_set_phase(GAME_PHASE_SERVE_SETUP);
}

static void game_begin_serve(u8 serving_team)
{
    Player *player = g_players;
    u8 i;

    for (i = 0; i < MAX_PLAYERS; ++i, ++player)
        player->pose = PLAYER_POSE_NONE;
    serve_setup(serving_team);
    s_rally_start = g_game_state.shot_serial;
    game_set_phase(GAME_PHASE_SERVE_SETUP);
}

/*
 * Slots follow the match config (ADR-018): singles plays slots 0 and 2,
 * doubles all four. Every active slot except P1 is CPU-owned for now; OBJ
 * palettes are slot order in doubles and 0/1 in singles (see render.h).
 */
static void game_activate_players(void)
{
    u8 active[MAX_PLAYERS];
    u8 doubles = g_match_config.mode == MATCH_DOUBLES;
    Player *player = g_players;
    const AiStyle *style;
    u8 big;
    u8 i;

    for (i = 0; i < MAX_PLAYERS; ++i)
        active[i] = match_slot_active(i);
    g_ball_tick = 0;
    g_ball_steps = 0;
    g_ball_paced = (g_match_config.modifiers & MODIFIER_FAST_BALL) ||
        options_ball_per_cycle(g_match_config.difficulty,
            g_match_config.ball_speed) != OPTIONS_BALL_CYCLE;
    if (g_ball_paced)
        modifiers_ball_pace(g_ball_pace, GAME_BALL_PACE_TICKS,
            g_match_config.difficulty, g_match_config.modifiers,
            g_match_config.ball_speed);
    /* Only on a change: a new match frame runs near the budget (the demo
     * restarts on one). */
    big = (g_match_config.modifiers & MODIFIER_BIG_BALL) != 0;
    if (big != g_hit_box.big)
        collision_configure(big);
    input_assign_match(active, g_match_config.human);
    for (i = 0; i < MAX_PLAYERS; ++i, ++player) {
        player->active = active[i];
        player->cpu_controlled = g_input_owners[i] == INPUT_OWNER_CPU;
        player->max_speed_fp = PLAYER_MAX_SPEED_FP;
        player->palette = doubles ? i : player->team;
        player->variant = g_match_config.variant[i];
        player->paddle = g_match_config.paddle_id[i];
        /* ADR-047 stage 4: a career player's hat shifts their paddle's
         * stats (the paddle tables hold every pairing). */
        if (i == 0 && g_match_config.career_p1 && career_active())
            player->paddle = PADDLE_PROFILE(g_match_config.paddle_id[0],
                career_active()->hat);
        if (player->cpu_controlled) {
            /* ADR-023: the slot's play style (the default CPU unless an
             * opponent is set). One lookup: this runs on a new match's
             * frame, near the budget. */
            style = match_slot_style(i);
            player->max_speed_fp = style->speed;
            g_ai_styles[i] = *style;
            /* ADR-025: difficulty changes the CPUs the humans play
             * against, not a human's CPU partner; MEDIUM changes none. */
            if (g_match_config.difficulty != DIFFICULTY_MEDIUM &&
                    !g_match_config.human[i & 2] &&
                    !g_match_config.human[(i & 2) + 1])
                options_apply_difficulty(&g_ai_styles[i],
                    g_match_config.difficulty);
            g_ai_slots[i].late_period = g_ai_styles[i].late_period;
            g_ai_slots[i].reaction_frames = g_ai_styles[i].reaction;
        }
    }
}

/* Fresh match without a console reset (RST-01): every simulation module is
 * re-initialized, so nothing from the previous match carries over. */
void game_new_match(void)
{
    g_next_opponent = 0;
    g_back_to_park = 0;
    /* A record beaten in a match left early keeps no initials (ADR-040):
     * only a finished match asks for them. */
    g_save_new_records = 0;
    g_career_new_unlocks = 0;
    players_initialize();
    ball_initialize();
    serve_initialize();
    ai_initialize();
    fx_initialize();
    replay_initialize();
    game_initialize();
    game_activate_players();
    if (g_match_config.practice)
        practice_begin();               /* ADR-028: no serve */
    else
        game_begin_serve(0);
}

/* The demo alternates singles and doubles. */
void game_start_attract(void)
{
    if (g_demo_mode == MATCH_DOUBLES)
        match_config_doubles();
    else
        match_config_defaults();
    g_demo_mode = g_demo_mode == MATCH_DOUBLES ? MATCH_SINGLES :
        MATCH_DOUBLES;
    g_match_config_changed = 1;
    game_new_match();
    g_attract = 1;
    g_ai_slots[0].late_period = GAME_ATTRACT_LATE_PERIOD;
}

/* A match from the current g_match_config (Player Select, ADR-020). */
void game_start_match(void)
{
    g_match_config_changed = 1;
    game_new_match();
    g_attract = 0;
}

void game_contact(u8 player_index)
{
    Player *player = &g_players[player_index];

    ++g_game_state.shot_serial;
    player->flash_timer = GAME_HIT_FLASH_FRAMES;
    g_game_state.hit_stop = GAME_HIT_STOP_FRAMES;
    events_emit(EVENT_HIT, FROM_FP(g_ball.x_fp), FROM_FP(g_ball.y_fp),
        player_index | (player->shot_type << 4));
}

u8 game_step_ball(void)
{
    u8 events = 0;
    u8 steps;

    /* ADR-025: a slow ball skips some steps, and FAST BALL (ADR-033) takes
     * an extra one; a steady pace skips the call. Two steps report both
     * steps' events. */
    if (!g_ball_paced) {
        ++g_ball_steps;
        return ball_update(0);
    }
    for (steps = GAME_BALL_STEPS_AHEAD(0); steps; --steps) {
        ++g_ball_steps;
        events |= ball_update(0);
    }
    if (++g_ball_tick >= OPTIONS_BALL_CYCLE)
        g_ball_tick = 0;
    return events;
}

/* LAVA (ADR-033): a player standing in their own kitchen while the ball
 * is in play loses the point for their team. */
/* modifiers_in_kitchen for one slot, by a constant index: four
 * three-argument calls, or a pointer walk, cost 816-tcc about 10 scanlines
 * a live frame, on doubles' worst frame (KNOWN_ISSUES #22). */
#define GAME_IN_LAVA(slot) \
    (g_players[slot].active && \
     g_players[slot].y_fp >= TO_FP(COURT_SIDELINE_TOP) && \
     g_players[slot].y_fp <= TO_FP(COURT_SIDELINE_BOTTOM) && \
     (g_players[slot].team ? \
        (g_players[slot].x_fp < TO_FP(COURT_KITCHEN_RIGHT_X) && \
         g_players[slot].x_fp > TO_FP(COURT_NET_X)) : \
        (g_players[slot].x_fp > TO_FP(COURT_KITCHEN_LEFT_X) && \
         g_players[slot].x_fp < TO_FP(COURT_NET_X))))

static void game_check_lava(void)
{
    if (GAME_IN_LAVA(0))
        rules_resolve_point(g_players[0].team, GAME_FAULT_LAVA);
    else if (GAME_IN_LAVA(1))
        rules_resolve_point(g_players[1].team, GAME_FAULT_LAVA);
    else if (GAME_IN_LAVA(2))
        rules_resolve_point(g_players[2].team, GAME_FAULT_LAVA);
    else if (GAME_IN_LAVA(3))
        rules_resolve_point(g_players[3].team, GAME_FAULT_LAVA);
}

static void game_update_live(const PlayerIntent intents[MAX_PLAYERS])
{
    u8 hit_player;
    u8 ball_events;

    if (g_match_config.modifiers & MODIFIER_LAVA) {
        game_check_lava();
        if (g_game_state.phase != GAME_PHASE_LIVE)
            return;
    }
    /* Only a swing in its active frames can hit: on most frames nobody's
     * is, and the call (four arguments, a pointer walk) cost 816-tcc about
     * 10 scanlines (#22). */
    hit_player = (g_players[0].state == PLAYER_STATE_ACTIVE ||
            g_players[1].state == PLAYER_STATE_ACTIVE ||
            g_players[2].state == PLAYER_STATE_ACTIVE ||
            g_players[3].state == PLAYER_STATE_ACTIVE) ?
        collision_resolve_player_hits(&g_ball, g_players, intents,
            MAX_PLAYERS) : 0;
    PROFILE_MARK(5);
    if (hit_player) {
        game_contact(hit_player - 1);
        rules_process_player_hit(hit_player - 1);
        if (g_game_state.phase != GAME_PHASE_LIVE)
            return;
    }
    ball_events = game_step_ball();
    if (ball_events & BALL_EVENT_BOUNCE)
        events_emit(EVENT_BOUNCE, FROM_FP(g_ball.x_fp), FROM_FP(g_ball.y_fp),
            g_ball.bounce_count);
    serve_process_ball_events(ball_events);
    rules_process_ball_events(ball_events);
}

/* Walks a pointer: 816-tcc multiplies for every variable g_players[i]. */
static void game_freeze_players(u8 winner)
{
    Player *player = g_players;
    u8 i;

    for (i = 0; i < MAX_PLAYERS; ++i, ++player) {
        if (!player->active)
            continue;
        player->frozen = 1;
        player->pose = player->team == winner ?
            PLAYER_POSE_CHEER : PLAYER_POSE_NONE;
    }
}

static void game_update_point_result(const PlayerIntent intents[MAX_PLAYERS])
{
    u8 winner = g_game_state.point_winner;

    game_freeze_players(winner);

    /* First frame of the result (the timer counts from 1 here). */
    if (g_game_state.phase_timer == 1 && !g_attract) {
        save_record_rally((u8)(g_game_state.shot_serial - s_rally_start));
        /* ADR-047: the active career player's point (against the CPU). */
        if (g_match_config.human[2] == 0)
            career_record_point(
                (u8)(g_game_state.shot_serial - s_rally_start),
                g_game_state.point_winner == 0,
                g_serve_state.server_index == 0);
        /* A close call after a long rally (ADR-041): display only. */
        replay_check((u8)(g_game_state.shot_serial - s_rally_start),
            g_game_state.last_fault);
    }
    if (g_game_state.phase_timer < GAME_POINT_RESULT_MIN_FRAMES)
        return;
    if (g_game_state.phase_timer < GAME_POINT_RESULT_FRAMES &&
        !intents[0].hit_pressed)
        return;

    if (GAME_SCORE_WINS(g_game_state.team_score[winner],
            g_game_state.team_score[winner ^ 1])) {
        g_game_state.match_winner = winner;
        game_set_phase(GAME_PHASE_MATCH_RESULT);
        /* ADR-021: 1P is on team 0; 2P (slot 2) makes it a versus match.
         * ADR-023: beating the ladder opponent brings on the next. */
        if (!g_attract && winner == 0 && !g_match_config.open_play &&
                g_match_config.opponent != OPPONENT_NONE)
            save_advance_ladder();
        /* ADR-047: before save_record_match, whose write keeps both. */
        if (!g_attract && g_match_config.human[2] == 0)
            career_record_match(g_match_config.mode, winner == 0,
                g_game_state.team_score[1], g_match_config.opponent,
                g_match_config.open_play);
        if (!g_attract)
            save_record_match(g_match_config.mode,
                !g_match_config.human[2], winner == 0,
                g_game_state.team_score[1]);
        return;
    }
    game_begin_serve(winner);
}

static void game_update_match_result(const PlayerIntent intents[MAX_PLAYERS])
{
    game_freeze_players(g_game_state.match_winner);
    if (g_attract) {
        if (g_game_state.phase_timer >= GAME_ATTRACT_RESULT_FRAMES)
            game_start_attract();
        return;
    }
    if (g_game_state.phase_timer < GAME_POINT_RESULT_MIN_FRAMES)
        return;
    if (intents[0].pause_pressed)
        game_start_attract();
    else if (intents[0].hit_pressed && g_match_config.open_play)
        g_back_to_park = 1;             /* ADR-034: back to the park */
    else if (intents[0].hit_pressed && g_match_config.opponent != OPPONENT_NONE &&
            g_game_state.match_winner == 0)
        g_next_opponent = 1;            /* a ladder win: on to the next */
    else if (intents[0].hit_pressed)
        game_new_match();
}

void game_update(const PlayerIntent intents[MAX_PLAYERS])
{
    ++g_game_state.frame_count;
    /* Start pauses; on the match result it returns to the title. */
    if (intents[0].pause_pressed && !g_attract &&
            g_game_state.phase != GAME_PHASE_MATCH_RESULT)
        g_game_state.paused = !g_game_state.paused;
    if (g_game_state.paused)
        return;

    fx_tick();
    if (g_game_state.hit_stop) {
        --g_game_state.hit_stop;
        return;
    }
    if (g_game_state.phase_timer < 0xffff)
        ++g_game_state.phase_timer;

    players_update(intents, 0);
    players_separate_teammates();
    PROFILE_MARK(4);
    if (g_match_config.practice) {
        practice_update(intents);
        return;
    }
    switch (g_game_state.phase) {
    case GAME_PHASE_SERVE_SETUP:
    case GAME_PHASE_SERVE_TOSS:
        serve_update(intents, 0);
        break;
    case GAME_PHASE_LIVE:
        game_update_live(intents);
        break;
    case GAME_PHASE_POINT_RESULT:
        game_update_point_result(intents);
        break;
    case GAME_PHASE_MATCH_RESULT:
        game_update_match_result(intents);
        break;
    default:
        break;
    }
}
