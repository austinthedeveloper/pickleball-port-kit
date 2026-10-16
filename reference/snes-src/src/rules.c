#include "court.h"
#include "events.h"
#include "player.h"
#include "rules.h"
#include "serve.h"

static u8 opposing_team(u8 team)
{
    return team == 0 ? 1 : 0;
}

static u8 last_hitter_team(void)
{
    if (g_ball.last_hitter >= MAX_PLAYERS)
        return 0;
    /* Team is slot >= 2 (ADR-018): no multiply indexing g_players. */
    return g_ball.last_hitter >= 2;
}

static u8 server_team(void)
{
    return g_serve_state.server_index >= 2;
}

void rules_resolve_point(u8 losing_team, u8 fault)
{
    u8 winner;

    if (g_game_state.phase == GAME_PHASE_POINT_RESULT ||
        g_game_state.phase == GAME_PHASE_MATCH_RESULT)
        return;

    winner = opposing_team(losing_team);
    g_game_state.point_winner = winner;
    g_game_state.last_fault = fault;
    ++g_game_state.team_score[winner];
    if (fault != GAME_FAULT_SECOND_BOUNCE && fault != GAME_FAULT_NONE)
        events_emit(EVENT_FAULT, FROM_FP(g_ball.x_fp), FROM_FP(g_ball.y_fp),
            fault);
    events_emit(EVENT_POINT, FROM_FP(g_ball.x_fp), FROM_FP(g_ball.y_fp),
        winner);
    game_set_phase(GAME_PHASE_POINT_RESULT);
    g_game_state.required_bounce = GAME_REQUIRED_BOUNCE_NONE;
    g_serve_state.landing_pending = 0;
    g_ball.rally_state = BALL_RALLY_INACTIVE;
    g_ball.vx_fp = 0;
    g_ball.vy_fp = 0;
    g_ball.vz_fp = 0;
}

void rules_process_player_hit(u8 player_index)
{
    u8 player_team;

    if (g_game_state.phase != GAME_PHASE_LIVE)
        return;
    if (player_index >= MAX_PLAYERS)
        return;
    if (g_game_state.required_bounce == GAME_REQUIRED_BOUNCE_NONE)
        return;

    player_team = g_players[player_index].team;
    if (g_game_state.required_bounce == GAME_REQUIRED_BOUNCE_SERVE) {
        rules_resolve_point(player_team, GAME_FAULT_EARLY_VOLLEY);
        return;
    }

    if (player_team == server_team())
        rules_resolve_point(player_team, GAME_FAULT_EARLY_VOLLEY);
}

void rules_process_ball_events(u8 events)
{
    u8 side;
    u8 hitter;

    if (g_game_state.phase == GAME_PHASE_SERVE_FAULT) {
        rules_resolve_point(last_hitter_team(), g_game_state.last_fault);
        return;
    }

    if (g_game_state.phase != GAME_PHASE_LIVE)
        return;

    hitter = last_hitter_team();
    if (events & BALL_EVENT_NET_FAULT) {
        rules_resolve_point(hitter, GAME_FAULT_NET);
        return;
    }

    if (!(events & BALL_EVENT_BOUNCE)) {
        /* A ball that died without a recorded second bounce still ends the
         * rally against the side it rests on. */
        if (g_ball.z_fp == 0 && g_ball.vz_fp == 0 && g_ball.vx_fp == 0 &&
            g_ball.vy_fp == 0 && g_ball.bounce_count > 0)
            rules_resolve_point(court_side_of_x(g_ball.x_fp),
                GAME_FAULT_SECOND_BOUNCE);
        return;
    }

    side = court_side_of_x(g_ball.x_fp);
    if (g_ball.bounce_count >= 2) {
        /* The receiving side failed to return a ball that landed in. */
        rules_resolve_point(opposing_team(hitter), GAME_FAULT_SECOND_BOUNCE);
        return;
    }

    /* First ground contact after a hit. */
    if ((events & BALL_EVENT_OUT) || side == hitter) {
        rules_resolve_point(hitter, GAME_FAULT_OUT);
        return;
    }

    if (g_game_state.required_bounce == GAME_REQUIRED_BOUNCE_SERVE) {
        g_game_state.required_bounce = GAME_REQUIRED_BOUNCE_RETURN;
    } else if (g_game_state.required_bounce == GAME_REQUIRED_BOUNCE_RETURN) {
        if (hitter != server_team() && side == server_team())
            g_game_state.required_bounce = GAME_REQUIRED_BOUNCE_NONE;
    }
}
