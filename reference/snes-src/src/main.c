#include <snes.h>
#include "ai.h"
#include "audio_events.h"
#include "collision.h"
#include "career_page.h"
#include "court_style.h"
#include "game.h"
#include "hud_scene.h"
#include "serve.h"
#include "input.h"
#include "match.h"
#include "modifiers.h"
#include "open_play.h"
#include "options.h"
#include "pause_menu.h"
#include "practice.h"
#include "sfx.h"
#include "player.h"
#include "profile.h"
#include "render.h"
#include "save.h"
#include "select.h"
#include "story.h"

/* The court (title, attract, match), Player Select (ADR-020), or the open
 * play park (ADR-034). */
enum { SCENE_MATCH = 0, SCENE_SELECT = 1, SCENE_PARK = 2 };
static u8 s_scene;
static u8 s_open_select;
static u8 s_open_park;
/* s_open_park leaving practice: the title demo is set up first. */
#define S_OPEN_PARK_FROM_PRACTICE 2
/* Player Select is open on the way to practice (ADR-028). */
static u8 s_practice_pending;
/* This frame set up a new match (a scene switch for the overrun latch). */
static u8 s_switched;

/* Menu sounds (ADR-029): Y goes back, a choice confirms, a move blips. */
static void ui_sounds(u16 pressed)
{
    if (pressed & PAD_Y)
        audio_ui(SFX_BACK);
    else if (pressed & (PAD_START | PAD_B | PAD_A))
        audio_ui(SFX_CONFIRM);
    else if (pressed & (PAD_UP | PAD_DOWN | PAD_LEFT | PAD_RIGHT))
        audio_ui(SFX_BLIP);
}

/* Pause menu (ADR-030): RESUME, RESTART, or MAIN MENU. Nonzero when it
 * acted, so this frame's buttons (a B) do not reach the match. */
static u8 update_pause_menu(u16 pressed)
{
    u8 action = pause_input(pressed);

    if (action == PAUSE_STAY)
        return 0;
    g_game_state.paused = 0;
    if (action == PAUSE_DO_RESTART) {
        game_new_match();
    } else if (action == PAUSE_DO_MAIN_MENU) {
        if (g_match_config.practice)
            practice_finish();
        /* Practice from the park (M4-OPEN-05): back to the ball machine.
         * The title demo behind the park is set up as the park loads, in
         * forced blank: on this frame, with the session's save, it went
         * past the frame budget. */
        if (g_pause_park) {
            g_pause_park = 0;
            s_open_park = S_OPEN_PARK_FROM_PRACTICE;
        } else {
            game_start_attract();
        }
    }
    return 1;
}

/* Your game in the park is up (ADR-034): doubles with a regular partner
 * (the default CPU) against the team drawn with you, on the saved options
 * and modifiers. No intro card, and the ladder stays where it is. */
static void start_open_play_match(void)
{
    match_config_doubles();
    match_config_opponent(g_open_play.opponent);
    /* 2P partners you on slot 1 (port 2); otherwise the captain next in
     * line does. */
    if (g_open_play.two_players)
        g_match_config.human[1] = 1;
    else
        match_config_partner(g_open_play.partner);
    g_match_config.points_to_win = options_points(g_save.settings.points);
    /* The court's level sets the difficulty (KID keeps its assist). */
    g_match_config.difficulty = open_court_difficulty(g_open_play.called,
        options_difficulty(g_save.settings.difficulty));
    g_match_config.modifiers = modifiers_valid(g_save.settings.modifiers);
    g_match_config.open_play = 1;
    /* ADR-047: you play as your career player, in their saved look. */
    match_config_career_p1();
    game_start_match();
    g_match_config_changed = 0;
    render_open_match();
    s_scene = SCENE_MATCH;
    profile_resync();
}

/* The park's ball machine (M4-OPEN-05): practice on the saved drill, in
 * the default look (no Player Select), and PARK on the pause menu goes
 * back. The park waits, as for your game. */
static void start_park_practice(void)
{
    match_config_defaults();
    match_config_practice();
    match_config_career_p1();           /* ADR-047 */
    game_start_match();
    g_match_config_changed = 0;
    g_pause_park = 1;
    render_open_match();
    s_scene = SCENE_MATCH;
    profile_resync();
}

/* The park, from the title or back from your game. */
static void open_park(void)
{
    render_park_open();
    s_scene = SCENE_PARK;
    profile_resync();
}

/* One park frame (ADR-034): the D-pad walks, B stacks or takes your
 * paddle, Start leaves for the title. */
static void update_park(void)
{
    u16 held = g_pad_snapshots[0].held;
    u16 pressed = g_pad_snapshots[0].pressed;
    s16 move_x = (held & PAD_RIGHT) ? 1 : (held & PAD_LEFT) ? -1 : 0;
    s16 move_y = (held & PAD_DOWN) ? 1 : (held & PAD_UP) ? -1 : 0;
    u8 event;

    /* Start on pad 2: 2P joins as your partner, or leaves. */
    if ((g_pad_snapshots[1].pressed & PAD_START) &&
            g_open_play.called == OPEN_NONE) {
        g_open_play.two_players ^= 1;
        g_title_2p = g_open_play.two_players;
        audio_ui(g_open_play.two_players ? SFX_CONFIRM : SFX_BACK);
    }
    if ((pressed & PAD_START) && g_open_play.called == OPEN_NONE) {
        audio_ui(SFX_BACK);
        game_start_attract();
        g_match_config_changed = 0;
        render_open_match();
        s_scene = SCENE_MATCH;
        profile_resync();
        return;
    }
    event = open_play_update(move_x, move_y, (pressed & PAD_B) != 0);
    if (event == OPEN_EVENT_STACKED || event == OPEN_EVENT_CALLED)
        audio_ui(SFX_CONFIRM);
    else if (event == OPEN_EVENT_UNSTACKED || event == OPEN_EVENT_FULL)
        audio_ui(SFX_BACK);
    if (event == OPEN_EVENT_BOARD)
        audio_ui(SFX_BLIP);
    if (event == OPEN_EVENT_PLAY) {
        start_open_play_match();
        return;
    }
    if (event == OPEN_EVENT_PRACTICE) {
        audio_ui(SFX_CONFIRM);
        start_park_practice();
        return;
    }
    render_park_prepare();
    profile_work_done();
    audio_update();
    WaitForVBlank();
    render_park_commit();
    profile_vblank_done();
}

/* B after a ladder win (ADR-023): the next opponent, with their intro card
 * and (on AUTO) their home court. */
static void start_next_opponent(void)
{
    g_next_opponent = 0;
    match_config_opponent(g_save.settings.ladder);
    game_start_match();
    story_begin_intro();
    /* render_open_match applies the new config itself. */
    g_match_config_changed = 0;
    render_open_match();
    profile_resync();
}

/* The CAREER page (ADR-047, the RECORDS entry): career_page.c reads the
 * input; here the save is written. While a look is edited the title demo
 * stops and its P1 stands at the left baseline in that look, beside the
 * editor; leaving the editor starts a fresh demo. */
#define CAREER_PREVIEW_X (COURT_BASELINE_LEFT + 6)
#define CAREER_PREVIEW_Y 150
static u8 s_career_frozen;

static void career_preview(u8 on)
{
    const CareerPlayer *player = career_active();

    if (on && player) {
        if (!s_career_frozen) {
            s_career_frozen = 1;
            player_place(&g_players[0], CAREER_PREVIEW_X, CAREER_PREVIEW_Y);
            g_players[0].frozen = 1;
            g_players[0].pose = PLAYER_POSE_NONE;
            g_ball.active = 0;
        }
        g_match_config.career_p1 = 1;
        /* The palette takes the match's shirt and paddle (Player Select
         * may change them for a match): here, the saved ones. The fresh
         * demo after the editor puts the demo's back. */
        g_match_config.palette_id[0] = player->shirt;
        g_match_config.paddle_id[0] = player->paddle;
        g_players[0].variant = player->variant;
        render_apply_p1_look();
        return;
    }
    if (s_career_frozen) {
        s_career_frozen = 0;
        /* A fresh demo: palettes, ponytails, and positions are its own. */
        game_start_attract();
    }
}

static void update_title_career(u16 pressed)
{
    u8 result = career_page_input(pressed, g_pad_snapshots[0].held);
    u8 want = g_career_page.view == CAREER_VIEW_EDIT && career_active() != 0;

    if (result == CAREER_PAGE_SAVE)
        save_write();
    if (result == CAREER_PAGE_CLOSE) {
        g_title_page = TITLE_PAGE_MENU;
        want = 0;
    }
    /* RECORDS erased: the table redraws. */
    if (g_career_page.look_changed &&
            g_career_page.view == CAREER_VIEW_RECORDS)
        hud_scene_refresh_title();
    if (g_career_page.look_changed || want != s_career_frozen) {
        g_career_page.look_changed = 0;
        career_preview(want);
    }
}

/* Court page (ADR-022/024): colour changes show on the court behind it at
 * once; B or Start keeps them (and saves), Y puts them back. A VENUE the
 * cursor rests on loads behind the page with the short fade (M4-VENUE-02),
 * so scrolling past venues loads none; closing loads the kept venue if it
 * isn't showing, and Y the one that was showing before a preview. */
#define COURT_PREVIEW_REST_FRAMES 20
static u8 s_venue_rest;
static u8 s_venue_previewed;

/* The title court shows this saved VENUE (AUTO is the attract's PARK):
 * a preview without the ambience, or with it on closing the page. */
static void court_show_venue(u8 saved, u8 preview)
{
    if (court_style_venue(saved, OPPONENT_NONE) != render_court_venue()) {
        if (preview)
            render_preview_court();
        else
            render_open_match();
        profile_resync();
    }
    /* Closing on a previewed venue (or a new TIME, ADR-045): its
     * ambience, under a fade. */
    if (!preview && audio_ambience_venue() != court_style_ambience(
            render_court_venue(), g_save.settings.time)) {
        render_fade(1);
        audio_ambience(court_style_ambience(render_court_venue(),
            g_save.settings.time));
        render_fade(0);
        profile_resync();
    }
}

static void update_title_court(u16 pressed)
{
    SaveSettings *settings = &g_save.settings;
    u8 venue = settings->venue;
    u8 result = court_edit_input(settings->court, &settings->venue,
        &settings->time, pressed);

    if (g_court_edit.retime) {
        g_court_edit.retime = 0;
        g_court_edit.recolor = 0;
        render_apply_court_time();
    } else if (g_court_edit.recolor) {
        g_court_edit.recolor = 0;
        render_apply_court_colors();
    }
    if (result == COURT_EDIT_STAY) {
        if (settings->venue != venue)
            s_venue_rest = 0;
        else if (s_venue_rest < COURT_PREVIEW_REST_FRAMES &&
                ++s_venue_rest == COURT_PREVIEW_REST_FRAMES &&
                court_style_venue(settings->venue, OPPONENT_NONE) !=
                    render_court_venue()) {
            s_venue_previewed = 1;
            court_show_venue(settings->venue, 1);
        }
        return;
    }
    g_title_page = TITLE_PAGE_MENU;
    if (result == COURT_EDIT_DONE &&
            court_edit_changed(settings->court, settings->venue,
                settings->time))
        save_write();
    /* Y restored the venue: only a preview changed what shows. A new TIME
     * may change the ambience (court_show_venue loads it). */
    if (s_venue_previewed || settings->venue != g_court_edit.original_venue ||
            settings->time != g_court_edit.original_time)
        court_show_venue(settings->venue, 0);
}

/* Options page (ADR-025): B or Start keeps (and saves), Y puts back. */
static void update_title_options(u16 pressed)
{
    SaveSettings *settings = &g_save.settings;
    u8 result = options_edit_input(&settings->points, &settings->difficulty,
        &settings->sound, &settings->ball_speed, &g_save.camera, pressed);

    if (result == OPTIONS_EDIT_STAY)
        return;
    g_title_page = TITLE_PAGE_MENU;
    if (result == OPTIONS_EDIT_DONE &&
            options_edit_changed(settings->points, settings->difficulty,
                settings->sound, settings->ball_speed, g_save.camera)) {
        save_write();
        audio_refresh();            /* SOUND may start or stop ambience */
    }
}

/* Modifiers page (ADR-033): B or Start keeps (and saves), Y puts back.
 * KITCHEN: LAVA previews on the court behind the page while it is open. */
static void update_title_modifiers(u16 pressed)
{
    u8 *modifiers = &g_save.settings.modifiers;
    u8 lava = *modifiers & MODIFIER_LAVA;
    u8 result = modifiers_edit_input(modifiers, pressed);

    if (result != MODIFIERS_EDIT_STAY)
        g_title_page = TITLE_PAGE_MENU;
    if (lava != (*modifiers & MODIFIER_LAVA) ||
            (result != MODIFIERS_EDIT_STAY && lava))
        render_apply_court_colors();
    if (result == MODIFIERS_EDIT_DONE && modifiers_edit_changed(*modifiers))
        save_write();
}

/* Practice page (ADR-028): B or Start saves any change and goes on to
 * Player Select for the session; Y puts the settings back. */
static void update_title_practice(u16 pressed)
{
    u8 *values = g_save.settings.practice;
    u8 result = practice_edit_input(values, pressed);

    if (result == PRACTICE_EDIT_STAY)
        return;
    g_title_page = TITLE_PAGE_MENU;
    if (result != PRACTICE_EDIT_DONE)
        return;
    if (practice_edit_changed(values))
        save_write();
    select_begin(MATCH_SINGLES, 1);
    s_practice_pending = 1;
    s_open_select = 1;
}

/* The slot is serving: the serve setup and toss only. server_index keeps
 * the last server through the rally, and a lane cover thinking every frame
 * there put a third think on most rally frames (M4-UI-03/04). */
#define SERVING(slot) \
    (g_serve_state.server_index == (slot) && \
     g_game_state.phase <= GAME_PHASE_SERVE_TOSS)

/* Title: Up/Down picks an entry, Start on pad 2 toggles 2P, and Start/B
 * opens Player Select (singles, doubles) or a page (court, records). */
static void update_title(void)
{
    u16 pressed = g_pad_snapshots[0].pressed;

    ui_sounds(pressed | (g_pad_snapshots[1].pressed & PAD_START));

    if (g_title_page == TITLE_PAGE_RECORDS)
        update_title_career(pressed);
    else if (g_title_page == TITLE_PAGE_COURT)
        update_title_court(pressed);
    else if (g_title_page == TITLE_PAGE_OPTIONS)
        update_title_options(pressed);
    else if (g_title_page == TITLE_PAGE_PRACTICE)
        update_title_practice(pressed);
    else if (g_title_page == TITLE_PAGE_MODIFIERS)
        update_title_modifiers(pressed);
    else {
        if (pressed & PAD_UP)
            g_title_mode = g_title_mode ? g_title_mode - 1 :
                TITLE_ENTRIES - 1;
        if (pressed & PAD_DOWN)
            g_title_mode = g_title_mode == TITLE_ENTRIES - 1 ? 0 :
                g_title_mode + 1;
        if (g_pad_snapshots[1].pressed & PAD_START)
            g_title_2p ^= 1;
        if (pressed & (PAD_START | PAD_B)) {
            if (g_title_mode == TITLE_RECORDS) {
                career_page_begin();
                g_title_page = TITLE_PAGE_RECORDS;
            } else if (g_title_mode == TITLE_PRACTICE) {
                practice_edit_begin(g_save.settings.practice);
                g_title_page = TITLE_PAGE_PRACTICE;
            } else if (g_title_mode == TITLE_OPEN_PLAY) {
                open_play_begin(g_game_state.frame_count, g_title_2p);
                s_open_park = 1;
                return;
            } else if (g_title_mode == TITLE_MODIFIERS) {
                modifiers_edit_begin(&g_save.settings.modifiers);
                g_title_page = TITLE_PAGE_MODIFIERS;
                if (g_save.settings.modifiers & MODIFIER_LAVA)
                    render_apply_court_colors();
            } else if (g_title_mode == TITLE_OPTIONS) {
                options_edit_begin(&g_save.settings.points,
                    &g_save.settings.difficulty, &g_save.settings.sound,
                    &g_save.settings.ball_speed, &g_save.camera);
                g_title_page = TITLE_PAGE_OPTIONS;
            } else if (g_title_mode == TITLE_COURT) {
                court_edit_begin(g_save.settings.court,
                    &g_save.settings.venue, &g_save.settings.time);
                s_venue_rest = COURT_PREVIEW_REST_FRAMES;
                s_venue_previewed = 0;
                g_title_page = TITLE_PAGE_COURT;
            } else {
                select_begin(g_title_mode == TITLE_DOUBLES ? MATCH_DOUBLES :
                    MATCH_SINGLES, g_title_2p ? 2 : 1);
                s_open_select = 1;
                return;
            }
        }
    }
    if (s_open_select || s_open_park)
        return;
    /* The demo P1: in singles every other frame (KNOWN_ISSUES #9). In
     * doubles, every frame while the ball is in its lane, else on the one
     * frame in four no other slot covers (UPDATE_CPU), serving included:
     * its serve waits a few frames anyway. Every other frame there put two
     * lane covers on one frame and three or four thinks in all, which
     * dropped frames (M4-UI-03). */
    if (g_match_config.mode == MATCH_DOUBLES ?
            (g_ai_slots[0].has_target || ((u8)g_loop_count & 3) == 0) :
            (g_loop_count & 1))
        ai_update(0, &g_player_intents[0]);
    else
        ai_hold_intent(0, &g_player_intents[0]);
}

/*
 * A CPU playing the ball (or alone on its side, or serving) thinks every
 * frame; a doubles CPU covering its lane thinks every fourth frame,
 * staggered by slot, and repeats its movement in between (ADR-018).
 * A macro so every index is a constant: 816-tcc multiplies for each
 * variable g_players[i] / g_ai_slots[i] access.
 */
#define UPDATE_CPU(slot) \
    do { \
        if (g_input_owners[slot] == INPUT_OWNER_CPU && \
                g_players[slot].active) { \
            if (!g_players[(slot) ^ 1].active || \
                    g_ai_slots[slot].has_target || \
                    SERVING(slot) || \
                    ((u8)g_loop_count & 3) == (slot)) \
                ai_update(slot, &g_player_intents[slot]); \
            else \
                ai_hold_intent(slot, &g_player_intents[slot]); \
        } \
    } while (0)

/* KID (ADR-025): a human swings as soon as the swing would meet the ball.
 * Humans play slot 0, and 2 (versus) or 1 (co-op, ADR-034); a macro keeps
 * the indices constant. */
#define ASSIST_KID(slot) \
    do { \
        if (g_input_owners[slot] == INPUT_OWNER_HUMAN && \
                g_players[slot].active && ai_assist_swing(slot)) { \
            g_player_intents[slot].hit_pressed = 1; \
            g_player_intents[slot].shot = SHOT_STANDARD; \
        } \
    } while (0)

/* Human and CPU intents for this frame (frame pipeline steps 1-3). The pads
 * were already captured this frame. */
static void update_controllers(void)
{
    if (g_attract) {
        update_title();
        PROFILE_MARK(6);
    } else if (g_match_config.difficulty == DIFFICULTY_KID) {
        ASSIST_KID(0);
        ASSIST_KID(1);                  /* 2P partnering (ADR-034) */
        ASSIST_KID(2);
    }
    /* Constant slot numbers keep 816-tcc from multiplying per access. */
    UPDATE_CPU(1);
    UPDATE_CPU(2);
    UPDATE_CPU(3);
    PROFILE_MARK(0);
}

/* One Player Select frame: 1P reads port 1, 2P port 2. */
static void update_select(void)
{
    u16 pressed = g_pad_snapshots[g_select.current].pressed;
    u8 result = select_input(pressed);

    ui_sounds(pressed);
    if (result == SELECT_STAY) {
        render_select_prepare();
        audio_update();
        WaitForVBlank();
        render_select_commit();
        profile_vblank_done();
        return;
    }
    if (result == SELECT_DONE) {
        select_apply();
        if (s_practice_pending)
            match_config_practice();
        game_start_match();
        /* ADR-026: a ladder match opens with the opponent's intro card. */
        story_begin_intro();
    } else {
        game_start_attract();
    }
    s_practice_pending = 0;
    /* render_open_match applies the new config itself. */
    g_match_config_changed = 0;
    render_open_match();
    s_scene = SCENE_MATCH;
    profile_resync();
}

int main(void)
{
    input_initialize();
    audio_events_initialize();
    save_initialize();
    story_initialize();
    match_config_defaults();
    collision_configure(0);         /* ADR-033: the normal hit box */
#ifdef BUILD_DEBUG
    /* ADR-010: every active player has a unique palette. */
    if (!match_config_palettes_unique())
        while (1)
            ;
#endif
    /* Before the first render: the debug overlay reads the counters. */
    profile_initialize();
    g_attract = 0;
    g_title_mode = TITLE_SINGLES;
    g_title_page = TITLE_PAGE_MENU;
    g_title_2p = 0;
    s_scene = SCENE_MATCH;
    s_open_select = 0;
    s_open_park = 0;
    g_pause_park = 0;
    s_practice_pending = 0;
    s_switched = 0;
    s_career_frozen = 0;
    g_match_config_changed = 0;
    g_demo_mode = 0;
    g_next_opponent = 0;
    game_start_attract();
    render_initialize();
    /* render_initialize applied the attract config already. */
    g_match_config_changed = 0;
    /* Restart timing after the forced-blank uploads. */
    profile_initialize();

    /* docs/02_TECHNICAL_PLAN.md frame pipeline. */
    while (1) {
        profile_frame_begin();
        input_capture_frame();
        if (s_scene == SCENE_SELECT) {
            update_select();
            profile_frame_end();
            continue;
        }
        if (s_scene == SCENE_PARK) {
            update_park();
            profile_frame_end();
            continue;
        }
        if (s_open_park) {
            if (s_open_park == S_OPEN_PARK_FROM_PRACTICE) {
                game_start_attract();
                g_match_config_changed = 0;
            }
            s_open_park = 0;
            open_park();
            continue;
        }
        if (s_open_select) {
            s_open_select = 0;
            render_select_open();
            s_scene = SCENE_SELECT;
            profile_resync();
            continue;
        }
#ifdef RENDER_DIAGNOSTICS
        /* Select toggles the OBJ stress scene, which freezes the match. */
        if (g_pad_snapshots[0].pressed & PAD_SELECT)
            render_stress_toggle();
        if (!render_stress_active())
#endif
        {
            /* The match waits under a story card (ADR-026). The frame that
             * closes it is the card's too: the serve buffers presses, so the
             * closing B would otherwise serve. */
            if (g_story.card != STORY_CARD_NONE) {
                if (!story_update(g_pad_snapshots[0].pressed,
                        g_pad_snapshots[0].held))
                    audio_ui(SFX_CONFIRM);
                else if (g_story.card == STORY_CARD_INITIALS)
                    ui_sounds(g_pad_snapshots[0].pressed);
            } else {
                update_controllers();
                /* Pause, unpause, or back to the title. */
                if (!g_attract && g_player_intents[0].pause_pressed)
                    audio_ui(SFX_BLIP);
                if (g_game_state.paused && !g_attract) {
                    ui_sounds(g_pad_snapshots[0].pressed & ~PAD_START);
                    if (!update_pause_menu(g_pad_snapshots[0].pressed))
                        game_update(g_player_intents);
                } else if (!s_career_frozen) {
                    /* The CAREER editor holds the title demo (ADR-047). */
                    game_update(g_player_intents);
                    if (g_game_state.paused)
                        pause_begin();      /* just paused: on RESUME */
                }
                /* A record beaten (ADR-040): initials before the result. */
                if (g_game_state.phase == GAME_PHASE_MATCH_RESULT) {
                    story_begin_initials();
                    /* ADR-047: then what the career player unlocked. */
                    if (g_story.card == STORY_CARD_NONE)
                        story_begin_unlock();
                }
            }
            if (g_next_opponent)
                start_next_opponent();
            /* B after an open play game (ADR-034): back to the park. */
            if (g_back_to_park) {
                g_back_to_park = 0;
                open_play_return(g_game_state.match_winner == 0,
                    g_game_state.team_score[0], g_game_state.team_score[1]);
                game_start_attract();
                g_match_config_changed = 0;
                open_park();
                continue;
            }
            PROFILE_MARK(1);
        }
        /* A new attract demo or a return to the title: palettes, ponytails
         * and HUD names follow the new config. */
        if (g_match_config_changed) {
            render_apply_match_config();
            hud_scene_invalidate();
            g_match_config_changed = 0;
            s_switched = 1;
        }
        render_prepare();
        PROFILE_MARK(7);
        profile_work_done();
        /* Queued sound effects go to the sound CPU if there is time left
         * before VBlank (ADR-029). */
        audio_update();
        WaitForVBlank();
        render_commit();
        profile_vblank_done();
        /* A new match set up this frame (game_new_match, about 180
         * scanlines, then the first draw) runs past one VBlank: a scene
         * switch, like a fade, so the held frame is not an overrun. */
        if (s_switched) {
            s_switched = 0;
            profile_resync();
        } else {
            profile_frame_end();
        }
    }

    return 0;
}
