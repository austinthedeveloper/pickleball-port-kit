#include "court.h"
#include "events.h"
#include "game.h"
#include "match.h"
#include "options.h"
#include "serve.h"

ServeState g_serve_state;
ServeCharge g_serve_charge;

u8 serve_charged(void)
{
    return !g_attract && g_match_config.difficulty != DIFFICULTY_KID &&
        g_input_owners[g_serve_state.server_index] == INPUT_OWNER_HUMAN;
}

u8 serve_flight_frames(u8 power)
{
    return (u8)(SERVE_FLIGHT_FRAMES - ((power - SERVE_CHARGE_DUD) >> 1));
}

static void serve_hold_ball(void)
{
    Player *server = &g_players[g_serve_state.server_index];
    s16 offset = server->team ? -SERVE_HAND_OFFSET_X : SERVE_HAND_OFFSET_X;

    g_ball.active = 1;
    g_ball.x_fp = server->x_fp + TO_FP(offset);
    g_ball.y_fp = server->y_fp + TO_FP(1);
    g_ball.z_fp = TO_FP(SERVE_HAND_Z);
    g_ball.vx_fp = 0;
    g_ball.vy_fp = 0;
    g_ball.vz_fp = 0;
    g_ball.last_hitter = BALL_NO_HITTER;
    g_ball.bounce_count = 0;
    g_ball.rally_state = BALL_RALLY_INACTIVE;
}

static void serve_select_target(const Player *server,
    const PlayerIntent *intent)
{
    s16 box_y;
    s16 depth;
    s16 x;

    /* Diagonal box: a server on the bottom half serves to the top box. */
    if (g_serve_state.server_y_fp >= TO_FP(COURT_CENTERLINE_Y))
        box_y = (COURT_SIDELINE_TOP + COURT_CENTERLINE_Y) / 2;
    else
        box_y = (COURT_CENTERLINE_Y + COURT_SIDELINE_BOTTOM) / 2;
    if (intent->aim_y < 0)
        box_y -= SERVE_TARGET_LANE_SHIFT;
    else if (intent->aim_y > 0)
        box_y += SERVE_TARGET_LANE_SHIFT;
    g_serve_state.aim_y = box_y;

    depth = court_aim_depth(server->team, intent->aim_x);
    if (depth > 0)
        x = SERVE_TARGET_DEEP_RIGHT;
    else if (depth < 0)
        x = SERVE_TARGET_SHORT_RIGHT;
    else
        x = SERVE_TARGET_NEUTRAL_RIGHT;
    g_serve_state.aim_x = court_target_x(server->team, x);
}

static void serve_contact(const PlayerIntent *intent)
{
    Player *server = &g_players[g_serve_state.server_index];

    serve_select_target(server, intent);
    if (g_serve_charge.power < SERVE_CHARGE_DUD)
        /* A dud (ADR-044): low and slow, into the net. */
        ball_launch(&g_ball,
            court_target_x(server->team, COURT_NET_X + SERVE_DUD_PAST_NET),
            g_serve_state.aim_y, SERVE_DUD_FRAMES);
    else
        ball_launch(&g_ball, g_serve_state.aim_x, g_serve_state.aim_y,
            serve_flight_frames(g_serve_charge.power));
    g_ball.last_hitter = g_serve_state.server_index;
    g_ball.bounce_count = 0;
    g_ball.rally_state = BALL_RALLY_LIVE;
    ++g_game_state.shot_serial;
    events_emit(EVENT_SERVE, FROM_FP(g_ball.x_fp), FROM_FP(g_ball.y_fp),
        g_serve_state.server_index);
    g_serve_state.landing_pending = 1;
    g_game_state.required_bounce = GAME_REQUIRED_BOUNCE_SERVE;
    server->contact_consumed = 1;
    server->pose = PLAYER_POSE_NONE;
    server->frozen = 0;
    game_set_phase(GAME_PHASE_LIVE);
}

void serve_initialize(void)
{
    g_serve_state.server_index = 0;
    g_serve_state.receiver_index = 2;
    g_serve_state.landing_pending = 0;
    g_serve_state.requested = 0;
    g_serve_state.aim_x = SERVE_TARGET_NEUTRAL_RIGHT;
    g_serve_state.aim_y = COURT_SIDELINE_TOP + 20;
    g_serve_state.server_y_fp = TO_FP(COURT_CENTERLINE_Y);
}

/* The team's active slot whose lane (ADR-018) is top/bottom; in singles the
 * team's only active slot, whatever its lane. */
static u8 serve_slot_for_lane(u8 team, u8 top)
{
    u8 first = team ? 2 : 0;

    if (!g_players[first + 1].active)
        return first;
    if (!g_players[first].active)
        return first + 1;
    return match_slot_lane_top(first) == top ? first : first + 1;
}

static void serve_place_partner(u8 slot, u8 at_kitchen)
{
    Player *player = &g_players[slot];
    s16 y = match_slot_lane_top(slot) ?
        COURT_CENTERLINE_Y - SERVE_STANCE_OFFSET_Y :
        COURT_CENTERLINE_Y + SERVE_STANCE_OFFSET_Y;
    s16 x;

    if (at_kitchen)
        x = player->team ? COURT_KITCHEN_RIGHT_X + SERVE_PARTNER_KITCHEN_GAP :
            COURT_KITCHEN_LEFT_X - SERVE_PARTNER_KITCHEN_GAP;
    else
        x = player->team ? COURT_BASELINE_RIGHT + SERVE_RECEIVER_GAP :
            COURT_BASELINE_LEFT - SERVE_RECEIVER_GAP;
    player_place(player, x, y);
    player->frozen = 0;
    player->pose = PLAYER_POSE_NONE;
}

void serve_setup(u8 serving_team)
{
    Player *server;
    Player *receiver;
    s16 server_y;
    s16 receiver_y;
    u8 even = (g_game_state.team_score[serving_team] & 1) == 0;
    u8 server_top;

    /* Serve from the right-hand court on an even score. The left team faces
     * +x so its right hand is +y; the right team's right hand is -y. */
    if ((serving_team == 0) == even)
        server_y = COURT_CENTERLINE_Y + SERVE_STANCE_OFFSET_Y;
    else
        server_y = COURT_CENTERLINE_Y - SERVE_STANCE_OFFSET_Y;
    receiver_y = server_y >= COURT_CENTERLINE_Y ?
        COURT_CENTERLINE_Y - SERVE_STANCE_OFFSET_Y :
        COURT_CENTERLINE_Y + SERVE_STANCE_OFFSET_Y;
    server_top = server_y < COURT_CENTERLINE_Y;

    /* ADR-018: the lane decides who serves; the receiver is diagonal. */
    g_serve_state.server_index = serve_slot_for_lane(serving_team, server_top);
    g_serve_state.receiver_index =
        serve_slot_for_lane(serving_team ? 0 : 1, !server_top);
    g_serve_state.landing_pending = 0;
    g_serve_state.requested = 0;
    g_serve_charge.charging = 0;
    g_serve_charge.level = 0;
    g_serve_charge.rising = 1;
    g_serve_charge.armed = 0;
    g_serve_charge.power = SERVE_CHARGE_CLASSIC;
    server = &g_players[g_serve_state.server_index];
    receiver = &g_players[g_serve_state.receiver_index];

    if (serving_team == 0) {
        player_place(server, COURT_BASELINE_LEFT - SERVE_BASELINE_GAP,
            server_y);
        player_place(receiver, COURT_BASELINE_RIGHT + SERVE_RECEIVER_GAP,
            receiver_y);
    } else {
        player_place(server, COURT_BASELINE_RIGHT + SERVE_BASELINE_GAP,
            server_y);
        player_place(receiver, COURT_BASELINE_LEFT - SERVE_RECEIVER_GAP,
            receiver_y);
    }
    server->frozen = 1;
    receiver->frozen = 0;
    server->pose = PLAYER_POSE_NONE;
    receiver->pose = PLAYER_POSE_NONE;
    /* Doubles partners: the server's behind the baseline, the receiver's at
     * the kitchen line. */
    if (g_players[g_serve_state.server_index ^ 1].active)
        serve_place_partner(g_serve_state.server_index ^ 1, 0);
    if (g_players[g_serve_state.receiver_index ^ 1].active)
        serve_place_partner(g_serve_state.receiver_index ^ 1, 1);
    g_serve_state.server_y_fp = server->y_fp;
    g_game_state.serving_team = serving_team;
    g_game_state.required_bounce = GAME_REQUIRED_BOUNCE_NONE;
    serve_hold_ball();
}

void serve_update(const PlayerIntent intents[MAX_PLAYERS], u8 paused)
{
    Player *server = &g_players[g_serve_state.server_index];
    const PlayerIntent *intent = &intents[server->logical_input_slot];

    if (paused)
        return;

    if (g_game_state.phase == GAME_PHASE_SERVE_SETUP) {
        serve_hold_ball();
        /* Buffer an early press so it is not lost to the ready delay. */
        if (intent->hit_pressed)
            g_serve_state.requested = 1;
        if (g_game_state.phase_timer < GAME_SERVE_READY_FRAMES)
            return;
        /* ADR-044: a human holding a button runs the meter. */
        if (serve_charged() && intent->hit_held) {
            if (!g_serve_charge.charging) {
                g_serve_charge.charging = 1;
            } else if (g_serve_charge.rising) {
                if (++g_serve_charge.level >= SERVE_CHARGE_MAX)
                    g_serve_charge.rising = 0;
                if (g_serve_charge.level >= SERVE_CHARGE_DUD)
                    g_serve_charge.armed = 1;
            } else if (--g_serve_charge.level == 0) {
                g_serve_charge.rising = 1;
            }
            return;
        }
        if (g_serve_charge.charging) {
            /* Let go: at the level shown. Before the meter has left the
             * dud zone it was a tap, a safe classic serve. */
            g_serve_charge.charging = 0;
            if (g_serve_charge.armed)
                g_serve_charge.power = g_serve_charge.level;
        } else if (!g_serve_state.requested) {
            return;
        }
        g_serve_state.requested = 0;
        g_ball.vz_fp = SERVE_TOSS_VZ_FP;
        server->pose = PLAYER_POSE_TOSS;
        game_set_phase(GAME_PHASE_SERVE_TOSS);
        g_game_state.last_fault = GAME_FAULT_NONE;
        return;
    }

    if (g_game_state.phase != GAME_PHASE_SERVE_TOSS)
        return;

    /* The toss is presentation: the ball rises and falls in the hand lane. */
    g_ball.z_fp += g_ball.vz_fp;
    g_ball.vz_fp += BALL_GRAVITY_FP;
    if (g_game_state.phase_timer == SERVE_TOSS_POSE_FRAMES) {
        server->pose = PLAYER_POSE_NONE;
        server->state = PLAYER_STATE_WINDUP;
        server->state_frames_remaining = PLAYER_WINDUP_FRAMES;
        server->contact_consumed = 1;
    }
    if (g_game_state.phase_timer >= SERVE_TOSS_FRAMES)
        serve_contact(intent);
}

u8 serve_validate_landing(fx x_fp, fx y_fp, u8 server_team,
    fx server_y_fp)
{
    if (!court_contains_ground_fp(x_fp, y_fp))
        return GAME_FAULT_OUT;

    if (server_team == 0) {
        if (x_fp <= TO_FP(COURT_NET_X))
            return GAME_FAULT_WRONG_BOX;
        if (x_fp <= TO_FP(COURT_KITCHEN_RIGHT_X))
            return GAME_FAULT_KITCHEN;
    } else {
        if (x_fp >= TO_FP(COURT_NET_X))
            return GAME_FAULT_WRONG_BOX;
        if (x_fp >= TO_FP(COURT_KITCHEN_LEFT_X))
            return GAME_FAULT_KITCHEN;
    }

    if (server_y_fp < TO_FP(COURT_CENTERLINE_Y)) {
        if (y_fp < TO_FP(COURT_CENTERLINE_Y))
            return GAME_FAULT_WRONG_BOX;
    } else {
        if (y_fp > TO_FP(COURT_CENTERLINE_Y))
            return GAME_FAULT_WRONG_BOX;
    }

    return GAME_FAULT_NONE;
}

void serve_process_ball_events(u8 events)
{
    Player *server;
    u8 fault;

    if (!g_serve_state.landing_pending)
        return;

    if (events & BALL_EVENT_NET_FAULT) {
        g_game_state.last_fault = GAME_FAULT_NET;
        g_game_state.phase = GAME_PHASE_SERVE_FAULT;
        g_serve_state.landing_pending = 0;
        g_ball.rally_state = BALL_RALLY_INACTIVE;
        return;
    }

    if (!(events & BALL_EVENT_BOUNCE))
        return;

    server = &g_players[g_serve_state.server_index];
    fault = serve_validate_landing(g_ball.x_fp, g_ball.y_fp,
        server->team, g_serve_state.server_y_fp);
    g_game_state.last_fault = fault;
    g_serve_state.landing_pending = 0;
    if (fault != GAME_FAULT_NONE) {
        g_game_state.phase = GAME_PHASE_SERVE_FAULT;
        g_ball.rally_state = BALL_RALLY_INACTIVE;
        g_ball.vx_fp = 0;
        g_ball.vy_fp = 0;
        g_ball.vz_fp = 0;
    }
}
