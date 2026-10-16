#include <string.h>
#include "game.h"
#include "hud_tiles.h"
#include "input.h"
#include "serve.h"
#include "hud.h"
#include "hud_scene.h"
#include "match.h"
#include "profile.h"
#include "render.h"
#include "render_internal.h"
#include "court_style.h"
#include "audio_events.h"
#include "career_page.h"
#include "modifiers.h"
#include "options.h"
#include "paddle_stats.h"
#include "pause_menu.h"
#include "practice.h"
#include "save.h"
#include "story.h"
#include "replay.h"

/*
 * Score panels and scene overlays (title, serve prompt, point and match
 * results, pause) on BG3. The BG3 map is rebuilt only when what it shows
 * changes, and overlays are drawn in steps across frames (see below).
 */

/*
 * BG3 layout in tile rows/columns (32x28 map). Panels are three rows tall
 * (border, text, border); see hud_panel().
 */
#define SCORE_PANEL_ROW 1           /* text on row 2 */
#define SCORE_TEXT_ROW (SCORE_PANEL_ROW + 1)
#define LEFT_PANEL_COL 1            /* "P1    n" */
#define CENTER_PANEL_COL 9          /* "ARCADE RULES" */
#define RIGHT_PANEL_COL 23          /* "CPU   n" */
#define SIDE_PANEL_WIDTH 6
#define CENTER_PANEL_WIDTH 12
#define LEFT_SCORE_COL 6            /* two digit cells, right-aligned */
#define RIGHT_SCORE_COL 28
#define TITLE_ROW 7                 /* PICKLEBALL / '94, two big rows each */
#define CENTER_BIG_ROW 8            /* fault word or match result */
#define CENTER_PANEL_ROW 11         /* "P1 POINT", "PAUSED" */
#define BANNER_ROW 24               /* serve / rematch / title prompt */
#define SUB_PANEL_ROW 4             /* ARCADE RULES / MATCH POINT */
#define TITLE_MENU_ROW 12           /* SINGLES ... PRACTICE (rows 12-19) */
#define TITLE_MENU_COL 11           /* cursor + 10: columns 11-21, centred */
#define TITLE_2P_ROW 20
#define TITLE_2P_COL 9              /* 14-character 2P join line */
#define TITLE_AREA_ROWS 11          /* menu or a page: rows 12-22 */
#define RECORDS_COL 4               /* the records box: columns 4-27 */
#define RECORDS_WIDTH 24
#define RECORDS_ROWS 11
#define RECORDS_COUNT_COL 23        /* four digits, one cell from the edge */
#define COURT_PAGE_ROWS 8           /* the court box: header, gap, 6 rows */
#define COURT_FIRST_ROW (TITLE_MENU_ROW + 2)
#define COURT_LABEL_COL 6
#define COURT_VALUE_COL 16          /* "<NAME    >" */
#define OPTIONS_PAGE_ROWS 7         /* header, gap, points, difficulty, sound,
                                       ball speed, camera */
#define PRACTICE_PAGE_ROWS 8        /* header, gap, 4 rows, gap, best */
#define MODIFIERS_PAGE_ROWS 6       /* header, gap, 4 rows */

/* Last HUD inputs, so the BG3 map is only rebuilt when something changes. */
static u8 s_hud_score[2];
static u16 s_hud_scene;
static u8 s_hud_valid;
static u8 s_sub_panel;             /* 0 none, 1 ARCADE RULES, 2 MATCH POINT */

/* Title menu choice (TITLE_*), the open page (TITLE_PAGE_*), and 2P join;
 * owned by main.c's title input. */
u8 g_title_mode;
u8 g_title_page;
u8 g_title_2p;
/*
 * Title area (rows 12-22: the menu or a page), drawn a part per
 * idle frame by hud_title_area_update, apart from the staged scene steps so
 * the prompt blink never interrupts it. s_title_view is the view on screen
 * or being drawn (hud_title_view), HUD_TITLE_CLEARED after a clear, or
 * HUD_TITLE_UNKNOWN; s_title_part is the next part to draw.
 */
static u8 s_title_view;
static u8 s_title_part;
/* A menu item that lost the cursor and still shows it, redrawn on the
 * frame after the move (0xff: none). */
static u8 s_title_stale;
/* Court and options page rows on screen: value | cursor (bit 7); 0xff not
 * drawn. */
static u8 s_court_row_drawn[COURT_ROWS];
static u8 s_options_row_drawn[OPTIONS_ROWS];
static u8 s_practice_row_drawn[PRACTICE_ROWS];
static u8 s_practice_best_drawn;   /* the zone whose best is shown */
static u8 s_modifiers_row_drawn[MODIFIERS_ROWS];
#define HUD_TITLE_CLEARED 0xfe
#define HUD_TITLE_UNKNOWN 0xff
/* Title drawing (staged steps and area parts) waits for a later frame once
 * the frame's work has reached this scanline: a row or the prompt can cost
 * 60+ scanlines, VBlank starts at 225, and the attract demo alone reaches
 * about 200 on its heavy frames. */
#define HUD_TITLE_SCANLINE_LIMIT 140
/* ...but for at most this many frames in a row: the doubles demo is busy on
 * nearly every frame (M4-UI-03), and a menu that never finishes drawing is
 * worse than an occasional dropped frame. */
#define HUD_TITLE_MAX_WAITS 6
static u8 s_title_waits;


/* The title prompt's rows (BANNER_ROW - 1 and its panel) as last drawn, for
 * TITLE_PAGE_* s_prompt_page (0xff: none yet). Its blink brings it back
 * every 64 frames; redrawing cost about 100 scanlines, which the doubles
 * demo rarely had, so it was forced onto a heavy frame after
 * HUD_TITLE_MAX_WAITS: most of its dropped frames (M4-UI-03). */
#define HUD_PROMPT_ROWS 4
static u16 s_prompt_rows[HUD_PROMPT_ROWS * 32];
static u8 s_prompt_page;
/* A new prompt's panel is up and its text comes next (EXTRA2, EXTRA3). */
static u8 s_prompt_text;

/* Nonzero when title drawing should wait for a lighter frame: the frame's
 * work is past `limit`, and it has not waited HUD_TITLE_MAX_WAITS yet. */
static u8 hud_title_wait(u16 limit)
{
    if (profile_scanline() > limit &&
            s_title_waits < HUD_TITLE_MAX_WAITS) {
        ++s_title_waits;
        return 1;
    }
    s_title_waits = 0;
    return 0;
}

/* Score-panel labels: at most 4 characters before the score digits. */
static const char *const s_palette_names[PAL_COUNT] = {
    "BLUE", "RED", "GRN", "GOLD"
};

static u8 hud_doubles(void)
{
    return g_match_config.mode == MATCH_DOUBLES;
}

static u8 hud_versus_2p(void)
{
    return g_match_config.human[2];
}

static u8 hud_opponent_team(u8 team)
{
    return team && g_match_config.opponent != OPPONENT_NONE;
}

static u8 hud_practice(void)
{
    return g_match_config.practice && !g_attract;
}

/* The active career player's name for the score panel: four cells. */
static const char *hud_career_short_name(void)
{
    static char name[5];
    const CareerPlayer *player = career_active();
    u8 i;

    for (i = 0; i < 4; ++i)
        name[i] = (char)player->name[i];
    name[4] = 0;
    while (i && name[i - 1] == ' ')
        name[--i] = 0;
    return name;
}

/* Singles: P1 / CPU (or P2). Doubles: the team's palette name
 * (ADR-010/018), or CPU for a ladder opponent (ADR-023). */
static const char *team_name(u8 team)
{
    /* Practice (ADR-028): P1's streak and the best streak. */
    if (hud_practice())
        return team ? "BEST" : "P1";
    /* ADR-047: the career player's name, its first four letters. */
    if (team == 0 && g_match_config.career_p1 && career_active())
        return hud_career_short_name();
    if (hud_doubles() && !hud_opponent_team(team))
        return s_palette_names[match_team_palette(team)];
    if (team)
        return hud_versus_2p() ? "P2" : "CPU";
    return "P1";
}

void hud_scene_invalidate(void)
{
    s_hud_valid = 0;
    /* No previous scene: the staged redraw starts from scratch (a title
     * logo is redrawn, not assumed to be on screen). */
    s_hud_scene = 0xff;
    s_title_view = HUD_TITLE_UNKNOWN;
}

void hud_scene_refresh_title(void)
{
    s_title_view = HUD_TITLE_UNKNOWN;
}

static const char *fault_word(u8 fault)
{
    switch (fault) {
    case GAME_FAULT_NET:
        return "NET!";
    case GAME_FAULT_KITCHEN:
        return "KITCHEN!";
    case GAME_FAULT_WRONG_BOX:
        return "FAULT!";
    case GAME_FAULT_OUT:
        return "OUT!";
    case GAME_FAULT_SECOND_BOUNCE:
        return "2 BOUNCES";
    case GAME_FAULT_EARLY_VOLLEY:
        return "VOLLEY!";
    case GAME_FAULT_LAVA:
        return "LAVA!";
    default:
        return "POINT!";
    }
}

static u8 team_hud_palette(u8 team)
{
    return team ? HUD_PAL_TEAM_RIGHT : HUD_PAL_TEAM_LEFT;
}

/* Score digits only; tens are drawn as a leading digit or a blank. */
static void hud_draw_score_digits(void)
{
    static const char digits[] = "0123456789";
    char text[3];
    u8 team;
    u8 score;

    for (team = 0; team < 2; ++team) {
        score = g_game_state.team_score[team];
        text[0] = ' ';
        while (score >= 10) {      /* no 816-tcc division */
            score -= 10;
            text[0] = text[0] == ' ' ? '1' : text[0] + 1;
        }
        text[1] = digits[score];
        text[2] = 0;
        hud_text(team ? RIGHT_SCORE_COL : LEFT_SCORE_COL, SCORE_TEXT_ROW,
            HUD_PAL_WHITE, text);
    }
    s_hud_score[0] = g_game_state.team_score[0];
    s_hud_score[1] = g_game_state.team_score[1];
}

/* "VS NAME" centred in a 12-cell panel interior (ADR-023): singles names
 * the captain, doubles the team. */
static void hud_versus(u8 row)
{
    const char *name = hud_doubles() ?
        g_opponent_team[g_match_config.opponent] :
        g_opponent_captain[g_match_config.opponent];
    u8 length = 0;
    u8 col;

    while (name[length])
        ++length;
    col = CENTER_PANEL_COL + 1 + (CENTER_PANEL_WIDTH - 3 - length) / 2;
    hud_text(col, row, HUD_PAL_WHITE, "VS");
    hud_text(col + 3, row, HUD_PAL_TEAM_RIGHT, name);
}

/* Practice: PRACTICE, or the return zone the streak counts (centred). */
static void hud_practice_title(void)
{
    const char *name = practice_zone_name(g_practice.zone);
    u8 length = 0;

    if (g_practice.zone == PRACTICE_ZONE_ANY) {
        hud_text(CENTER_PANEL_COL + 1, SCORE_TEXT_ROW, HUD_PAL_YELLOW,
            "  PRACTICE");
        return;
    }
    while (name[length])
        ++length;
    hud_text(CENTER_PANEL_COL + 1 + (CENTER_PANEL_WIDTH - 2 - length) / 2,
        SCORE_TEXT_ROW, HUD_PAL_YELLOW, name);
}

/* Panels and labels never change during a match; drawn on full redraws. */
static void hud_draw_scores(void)
{
    hud_clear_rows(SCORE_PANEL_ROW, 3);
    hud_panel(LEFT_PANEL_COL, SCORE_PANEL_ROW, SIDE_PANEL_WIDTH);
    hud_text(LEFT_PANEL_COL + 1, SCORE_TEXT_ROW, team_hud_palette(0),
        team_name(0));
    hud_panel(CENTER_PANEL_COL, SCORE_PANEL_ROW, CENTER_PANEL_WIDTH);
    if (hud_practice())
        hud_practice_title();
    else if (!g_attract && !hud_doubles() && hud_opponent_team(1))
        hud_versus(SCORE_TEXT_ROW);
    else
        hud_text(CENTER_PANEL_COL + 1, SCORE_TEXT_ROW, HUD_PAL_YELLOW,
            hud_doubles() ? "  DOUBLES" : "ARCADE RULES");
    hud_panel(RIGHT_PANEL_COL, SCORE_PANEL_ROW, SIDE_PANEL_WIDTH);
    hud_text(RIGHT_PANEL_COL + 1, SCORE_TEXT_ROW, team_hud_palette(1),
        team_name(1));
    s_sub_panel = 0xff;     /* re-evaluate the sub-panel */
    hud_draw_score_digits();
}

/*
 * Scene keys: what the overlay currently shows. A key change starts a
 * staged redraw. Game phases use their own value (with winner/fault bits for
 * results); these special keys sit above that range.
 */
#define HUD_KEY_PAUSED 0x80        /* | the menu choice (ADR-030) */
#define HUD_IS_PAUSED(k) (((k) & ~3u) == HUD_KEY_PAUSED)
#define PAUSE_BOX_COL 9
#define PAUSE_BOX_ROW 9             /* header, gap, 3 items: rows 9-13 */
#define PAUSE_BOX_WIDTH 14
#define HUD_KEY_TITLE 0x100
#define HUD_KEY_TITLE_BLINK 0x101
#define HUD_KEY_INTRO 0x200         /* the story intro card (ADR-026) */
#define HUD_KEY_PRACTICE 0x400      /* a practice session (ADR-028); not bit 8 */
#define HUD_KEY_INITIALS 0x800      /* the initials card (ADR-040) */
#define HUD_KEY_UNLOCK 0x1000       /* the career unlock card (ADR-047) */
/* The initials card: three big letters on rows 16-17, four columns apart
 * and centred, the chosen one underlined on row 18. */
#define INITIALS_ROW 16
#define INITIALS_COL 11
#define INITIALS_STEP 4
#define INITIALS_LAST_ROW (INITIALS_ROW + 2)

/* WIN BY 2 (ADR-033): one more point wins from a lead. */
static u8 hud_win_by_2_match_point(void)
{
    u8 left = g_game_state.team_score[0];
    u8 right = g_game_state.team_score[1];
    u8 points = g_match_config.points_to_win;

    return (left + 1 >= points && left > right) ||
        (right + 1 >= points && right > left);
}

/* Doubles shows ARCADE RULES under DOUBLES; either mode shows MATCH POINT
 * when a team is one point from winning (the doubles mockup). Runs every
 * match frame, close to the budget: without WIN BY 2 it is the original
 * test plus one bit. */
static u8 hud_sub_panel_wanted(void)
{
    if (g_attract || g_match_config.practice)
        return 0;
    if (g_game_state.phase != GAME_PHASE_MATCH_RESULT &&
        ((g_match_config.modifiers & MODIFIER_WIN_BY_2) ?
            hud_win_by_2_match_point() :
            (g_game_state.team_score[0] == g_match_config.points_to_win - 1 ||
             g_game_state.team_score[1] == g_match_config.points_to_win - 1)))
        return 2;
    return hud_doubles() ? 1 : 0;
}

static void hud_draw_sub_panel(u8 wanted)
{
    hud_clear_rows(SUB_PANEL_ROW, 3);
    if (wanted == 1) {
        hud_panel(CENTER_PANEL_COL, SUB_PANEL_ROW, CENTER_PANEL_WIDTH);
        if (hud_opponent_team(1))
            hud_versus(SUB_PANEL_ROW + 1);
        else
            hud_text(CENTER_PANEL_COL + 1, SUB_PANEL_ROW + 1, HUD_PAL_WHITE,
                "ARCADE RULES");
    } else if (wanted == 2) {
        hud_panel(CENTER_PANEL_COL, SUB_PANEL_ROW, CENTER_PANEL_WIDTH);
        hud_text(CENTER_PANEL_COL + 1, SUB_PANEL_ROW + 1, HUD_PAL_WHITE,
            "MATCH POINT");
    }
    s_sub_panel = wanted;
}

static const char *hud_point_text(u8 winner)
{
    static const char *const doubles[PAL_COUNT] = {
        "BLUE POINT", "RED POINT", "GREEN POINT", "GOLD POINT"
    };
    if (hud_doubles() && !hud_opponent_team(winner))
        return doubles[match_team_palette(winner)];
    if (winner == 0)
        return "P1 POINT";
    return hud_versus_2p() ? "P2 POINT" : "CPU POINT";
}

static const char *hud_match_winner_text(void)
{
    /* ADR-026: beating the last ladder opponent. */
    if (g_game_state.match_winner == 0 && !g_attract &&
            !g_match_config.open_play &&
            g_match_config.opponent == OPPONENT_COUNT - 1)
        return "CHAMPION!";
    if (hud_versus_2p())
        return g_game_state.match_winner == 0 ? "P1 WINS" : "P2 WINS";
    return g_game_state.match_winner == 0 ? "YOU WIN!" : "CPU WINS";
}

/* The title prompt (bits 1-4 of a title key): the page, or for the
 * CAREER page (ADR-047) its sub-view, so each has its own. */
#define HUD_PROMPT_CAREER 8
#define HUD_PROMPT_CAREER_NAMING 12
#define HUD_PROMPT_CAREER_NAMING_EMPTY 13   /* nothing to erase: Y backs out */
static u8 hud_title_prompt_id(void)
{
    if (g_title_page != TITLE_PAGE_RECORDS)
        return g_title_page;
    if (g_career_page.view == CAREER_VIEW_EDIT && g_career_page.naming)
        return g_career_page.cursor ? HUD_PROMPT_CAREER_NAMING :
            HUD_PROMPT_CAREER_NAMING_EMPTY;
    return HUD_PROMPT_CAREER + g_career_page.view;
}

static u16 hud_scene_key(void)
{
    u8 phase = g_game_state.phase;

    if (g_story.card == STORY_CARD_INTRO)
        return HUD_KEY_INTRO;
    if (g_story.card == STORY_CARD_INITIALS)
        return HUD_KEY_INITIALS;
    if (g_story.card == STORY_CARD_UNLOCK)
        return HUD_KEY_UNLOCK;
    if (g_game_state.paused && !g_attract)
        return HUD_KEY_PAUSED | g_pause_choice;
    if (hud_practice())
        return HUD_KEY_PRACTICE;

    if (g_attract)
        return ((g_game_state.frame_count & 32) ? HUD_KEY_TITLE_BLINK :
            HUD_KEY_TITLE) | (hud_title_prompt_id() << 1);
    if (phase == GAME_PHASE_SERVE_TOSS || phase == GAME_PHASE_SERVE_FAULT)
        phase = GAME_PHASE_LIVE;
    if (phase == GAME_PHASE_SERVE_SETUP)
        return phase | (g_serve_state.server_index << 4);
    if (phase == GAME_PHASE_POINT_RESULT || phase == GAME_PHASE_MATCH_RESULT)
        return phase | (g_game_state.point_winner << 4) |
            ((g_game_state.last_fault & 7) << 5);
    return phase;
}

/* Title keys: 0x100 | blink (bit 0) | page (bits 1-3, for its prompt).
 * Bit 8 keeps them apart from phase keys: a kitchen fault point for P1 is
 * 0x44. The menu choice and 2P are drawn by hud_title_area_update. */
#define HUD_IS_TITLE(k) (((k) & HUD_KEY_TITLE) != 0)

/*
 * Scene overlays are drawn in three steps on consecutive frames (clear, big
 * text, prompt). Doing all three on the frame a point ends made that one
 * frame overrun; spread out, no frame does more than one step.
 */
enum { HUD_STEP_CLEAR = 0, HUD_STEP_BIG = 1, HUD_STEP_PROMPT = 2,
       /* Story cards (intro, match result): one panel per frame. */
       HUD_STEP_EXTRA = 3, HUD_STEP_EXTRA2 = 4,
       /* The match result only: a panel and its text on separate frames
        * (other scenes go from EXTRA2 to DONE). */
       HUD_STEP_EXTRA3 = 5, HUD_STEP_EXTRA4 = 6, HUD_STEP_EXTRA5 = 7,
       HUD_STEP_EXTRA6 = 8, HUD_STEP_DONE = 9 };

static u8 s_scene_step;
static u16 s_prev_scene;
/* The close call's frame is up (rows 14-23, ADR-041): the next clear takes
 * those rows too. */
static u8 s_replay_drawn;
/* The point result's quip (story_quip), or 0, and whether its panel is up
 * (the next clear covers its rows). */
static const char *s_quip;
static u8 s_quip_drawn;
#define QUIP_PANEL_ROW (CENTER_PANEL_ROW + 3)

u8 hud_replay_framed(void)
{
    return s_replay_drawn;
}

/* The opponent speaking on the story cards: singles names the captain,
 * doubles the team. */
static const char *hud_opponent_name(void)
{
    return hud_doubles() ? g_opponent_team[g_match_config.opponent] :
        g_opponent_captain[g_match_config.opponent];
}

/* A line of text centred on a row, without a panel. */
static void hud_center_text(u8 row, u8 palette, const char *text)
{
    u8 length = 0;

    while (text[length])
        ++length;
    hud_text((u8)(16 - length / 2), row, palette, text);
}

/* A count as text without leading zeros (no 816-tcc division); returns
 * the end of the text. */
static char *hud_count_text(char *out, u16 value)
{
    static const u16 powers[4] = { 10000, 1000, 100, 10 };
    u8 i;
    u8 leading = 1;
    char digit;

    for (i = 0; i < 4; ++i) {
        digit = '0';
        while (value >= powers[i]) {
            value -= powers[i];
            ++digit;
        }
        if (!leading || digit != '0') {
            *out++ = digit;
            leading = 0;
        }
    }
    *out++ = (char)('0' + value);
    *out = 0;
    return out;
}

static char *hud_copy_text(char *out, const char *text)
{
    while (*text)
        *out++ = *text++;
    *out = 0;
    return out;
}

/* The records just beaten: "BEST STREAK 5", "LONGEST RALLY 12", or both
 * as "STREAK 5  RALLY 12". */
static const char *hud_new_records_text(void)
{
    static char text[29];
    char *end = text;
    u8 both = g_save_new_records == (SAVE_NEW_STREAK | SAVE_NEW_RALLY);

    if (g_save_new_records & SAVE_NEW_STREAK) {
        end = hud_copy_text(end, both ? "STREAK " : "BEST STREAK ");
        end = hud_count_text(end, g_save.records.best_streak);
        if (both)
            end = hud_copy_text(end, "  ");
    }
    if (g_save_new_records & SAVE_NEW_RALLY) {
        end = hud_copy_text(end, both ? "RALLY " : "LONGEST RALLY ");
        hud_count_text(end, g_save.records.longest_rally);
    }
    return text;
}

/* The charged serve's meter (ADR-044): a bar over the serve prompt's
 * text, one cell for two levels. The first cell is the dud zone, white;
 * the rest fill yellow. */
#define SERVE_PROMPT_CHARGED "HOLD @ TO SERVE"
#define METER_CELLS 15
#define METER_COL (16 - (METER_CELLS + 2) / 2 + 1)
#define METER_UNDRAWN 0xff
static u8 s_meter_cells;            /* cells lit as drawn; METER_UNDRAWN */

/* Lights or clears the cells that changed; nonzero if it drew. On idle
 * frames: one cell a frame once the bar is up. */
static u8 hud_serve_meter_refresh(void)
{
    u8 cells = g_serve_charge.level >> 1;
    u8 i;
    u8 from;
    u8 to;

    if (!g_serve_charge.charging || cells == s_meter_cells)
        return 0;
    if (s_meter_cells == METER_UNDRAWN) {
        from = 0;
        to = METER_CELLS;
    } else if (cells > s_meter_cells) {
        from = s_meter_cells;
        to = cells;
    } else {
        from = cells;
        to = s_meter_cells;
    }
    for (i = from; i < to; ++i)
        hud_tile(METER_COL + i, BANNER_ROW + 1, i >= cells ?
            hud_entry(HUD_TILE_BAR_OFF, HUD_PAL_WHITE) :
            hud_entry(HUD_TILE_BAR_ON,
                i < (SERVE_CHARGE_DUD >> 1) ? HUD_PAL_WHITE : HUD_PAL_YELLOW));
    s_meter_cells = cells;
    return 1;
}

/* Letters and cursor as drawn; 0 forces a redraw. */
static u8 s_initials_drawn[3];
static u8 s_initials_cursor;

/* The letters whose letter or underline changed: on idle frames. */
static void hud_initials_refresh(void)
{
    static char letter[2];
    u8 i;
    u8 col;
    u8 chosen;
    u8 was = s_initials_cursor;

    for (i = 0; i < 3; ++i) {
        chosen = g_story.cursor == i;
        if (s_initials_drawn[i] == g_story.letters[i] && (was == i) == chosen)
            continue;
        col = INITIALS_COL + i * INITIALS_STEP;
        /* Statics are not zeroed at power-on: terminate it here. */
        letter[0] = (char)g_story.letters[i];
        letter[1] = 0;
        hud_big_text(col, INITIALS_ROW, chosen ? HUD_PAL_YELLOW :
            HUD_PAL_WHITE, letter);
        hud_tile(col, INITIALS_LAST_ROW, chosen ?
            hud_entry(HUD_TILE_BAR_ON, HUD_PAL_YELLOW) : HUD_TILE_CLEAR);
        hud_tile(col + 1, INITIALS_LAST_ROW, chosen ?
            hud_entry(HUD_TILE_BAR_ON, HUD_PAL_YELLOW) : HUD_TILE_CLEAR);
        s_initials_drawn[i] = g_story.letters[i];
    }
    s_initials_cursor = g_story.cursor;
}

/* Initials card (ADR-040): NEW RECORD!, the records, and the prompt, one
 * per frame; the letters draw on the idle frames after. */
static void hud_initials_step(u8 step)
{
    if (step == HUD_STEP_BIG) {
        hud_center_big(CENTER_BIG_ROW, HUD_PAL_YELLOW, "NEW RECORD!");
    } else if (step == HUD_STEP_PROMPT) {
        hud_center_prompt(CENTER_PANEL_ROW, HUD_PAL_WHITE,
            hud_new_records_text());
    } else if (step == HUD_STEP_EXTRA) {
        hud_center_prompt(BANNER_ROW, HUD_PAL_WHITE,
            "UP DOWN  @ NEXT  START OK");
    }
}

/* The close call (ADR-041): a frame around the BG2 close-up, then the
 * caption under it ("OUT BY 2 INCHES!"). */
static void hud_replay_step(u8 step)
{
    static char caption[20];
    char *end;

    if (step == HUD_STEP_EXTRA) {
        hud_frame(REPLAY_COL - 1, REPLAY_ROW - 1, REPLAY_COLS, REPLAY_ROWS);
        s_replay_drawn = 1;
    } else if (step == HUD_STEP_EXTRA2) {
        if (!g_replay.inches) {
            hud_copy_text(caption, "OUT BY A HAIR!");
        } else {
            end = hud_copy_text(caption, "OUT BY ");
            end = hud_count_text(end, g_replay.inches);
            hud_copy_text(end, g_replay.inches == 1 ? " INCH!" : " INCHES!");
        }
        hud_center_text(REPLAY_ROW + REPLAY_ROWS + 1, HUD_PAL_YELLOW, caption);
    }
}

/* Intro card (ADR-026): the opponent's name, their line, the prompt, and
 * the rung, one per frame. */
static void hud_intro_step(u8 step)
{
    static char rung[] = "LADDER 0 OF 0";

    if (step == HUD_STEP_BIG) {
        hud_center_big(CENTER_BIG_ROW, HUD_PAL_TEAM_RIGHT, hud_opponent_name());
    } else if (step == HUD_STEP_PROMPT) {
        hud_center_prompt(CENTER_PANEL_ROW, HUD_PAL_WHITE,
            g_opponent_lines[g_match_config.opponent][OPPONENT_LINE_INTRO]);
    } else if (step == HUD_STEP_EXTRA) {
        hud_center_prompt(BANNER_ROW, HUD_PAL_WHITE, "@ PLAY");
    } else if (step == HUD_STEP_EXTRA2) {
        rung[7] = (char)('1' + g_match_config.opponent);
        rung[12] = (char)('0' + OPPONENT_COUNT);
        hud_center_text(CENTER_PANEL_ROW + 3, HUD_PAL_YELLOW, rung);
    }
}

/* The unlocks just earned (ADR-047): "VISOR, PINK HAIR", and " +n" for
 * any that don't fit the panel. */
static const char *hud_unlock_text(void)
{
    static char text[29];
    u16 bit = 1;
    u8 length = 0;
    u8 more = 0;
    u8 i;
    const char *name;
    u8 size;

    for (i = 0; i < CAREER_UNLOCKS; ++i, bit <<= 1) {
        if ((g_career_new_unlocks & bit) == 0)
            continue;
        name = g_career_unlock_names[i];
        for (size = 0; name[size]; ++size)
            ;
        if (length + (length ? 2 : 0) + size > 24) {
            ++more;
            continue;
        }
        if (length) {
            text[length++] = ',';
            text[length++] = ' ';
        }
        while (*name)
            text[length++] = *name++;
    }
    if (more) {
        text[length++] = ' ';
        text[length++] = '+';
        text[length++] = (char)('0' + more);
    }
    text[length] = 0;
    return text;
}

static void hud_unlock_step(u8 step)
{
    if (step == HUD_STEP_BIG)
        hud_center_big(CENTER_BIG_ROW, HUD_PAL_YELLOW, "UNLOCKED!");
    else if (step == HUD_STEP_PROMPT)
        hud_center_prompt(CENTER_PANEL_ROW, HUD_PAL_WHITE, hud_unlock_text());
    else if (step == HUD_STEP_EXTRA)
        hud_center_prompt(BANNER_ROW, HUD_PAL_WHITE, "@ OK");
}

/* Under the match result (ADR-026): the opponent's line (EXTRA), and
 * after a win the next opponent or the ladder cleared (EXTRA2). */
static const char *hud_result_prompt(void)
{
    if (g_match_config.open_play)
        return "@ PARK  START MENU";
    if (g_game_state.match_winner == 0 &&
            g_match_config.opponent != OPPONENT_NONE)
        return "@ NEXT  START MENU";
    return "@ REMATCH  START MENU";
}

static void hud_result_story(u8 step)
{
    static char next[] = "NEXT UP: 123456789";
    u8 won = g_game_state.match_winner == 0;
    const char *const *lines;
    const char *team;
    u8 i;

    if (g_match_config.opponent == OPPONENT_NONE)
        return;
    if (step <= HUD_STEP_EXTRA5) {
        /* Separate steps: 816-tcc fails (ICE 2) on a ternary as the index. */
        lines = g_opponent_lines[g_match_config.opponent];
        if (won)
            lines += OPPONENT_LINE_CONCEDE;
        else
            lines += OPPONENT_LINE_TAUNT;
        /* The panel, then the line in halves: each half is a frame. */
        if (step == HUD_STEP_EXTRA3)
            hud_center_prompt_panel(CENTER_PANEL_ROW, *lines);
        else
            hud_center_prompt_half(CENTER_PANEL_ROW, HUD_PAL_TEAM_RIGHT,
                *lines, step == HUD_STEP_EXTRA5);
        return;
    }
    /* Open play (ADR-034) is off the ladder: no next-up line. */
    if (!won || g_match_config.open_play)
        return;
    if (g_match_config.opponent == OPPONENT_COUNT - 1) {
        hud_center_text(CENTER_PANEL_ROW + 3, HUD_PAL_YELLOW,
            "LADDER CLEARED!");
        return;
    }
    team = g_opponent_team[g_save.settings.ladder < OPPONENT_COUNT ?
        g_save.settings.ladder : 0];
    for (i = 0; team[i]; ++i)
        next[9 + i] = team[i];
    next[9 + i] = 0;
    hud_center_text(CENTER_PANEL_ROW + 3, HUD_PAL_YELLOW, next);
}

/* Four digits, right-aligned; leading zeros are spaces, which the font
 * draws as dark cells like the box. Records saturate at SAVE_COUNTER_MAX.
 * No 816-tcc division. */
static void hud_count(u8 col, u8 row, u16 value)
{
    static const u16 powers[3] = { 1000, 100, 10 };
    char text[5];
    u8 i;
    u8 leading = 1;

    for (i = 0; i < 3; ++i) {
        text[i] = '0';
        while (value >= powers[i]) {
            value -= powers[i];
            ++text[i];
        }
        if (leading && text[i] == '0')
            text[i] = ' ';
        else
            leading = 0;
    }
    text[3] = (char)('0' + value);
    text[4] = 0;
    hud_text(col, row, HUD_PAL_WHITE, text);
}

/* " LONGEST RALLY        nnnn " */
static void hud_record_line(u8 row, const char *label, u16 value)
{
    hud_text(RECORDS_COL + 1, row, HUD_PAL_WHITE, label);
    hud_count(RECORDS_COUNT_COL, row, value);
}

/* The holder's initials before the count (ADR-040), --- for nobody. */
#define RECORDS_INITIALS_COL (RECORDS_COUNT_COL - 4)
static void hud_record_initials(u8 row, const u8 *initials)
{
    static char text[4];

    text[0] = initials[0] ? (char)initials[0] : '-';
    text[1] = initials[0] ? (char)initials[1] : '-';
    text[2] = initials[0] ? (char)initials[2] : '-';
    text[3] = 0;
    hud_text(RECORDS_INITIALS_COL, row, HUD_PAL_YELLOW, text);
}

/* " SINGLES  W nnnn  L nnnn " */
static void hud_record_mode_line(u8 row, const char *label, u8 mode)
{
    hud_text(RECORDS_COL + 1, row, HUD_PAL_WHITE, label);
    hud_text(RECORDS_COUNT_COL - 9, row, HUD_PAL_YELLOW, "W");
    hud_count(RECORDS_COUNT_COL - 7, row, g_save.records.wins[mode]);
    hud_text(RECORDS_COUNT_COL - 2, row, HUD_PAL_YELLOW, "L");
    hud_count(RECORDS_COUNT_COL, row, g_save.records.losses[mode]);
}

/* Two menu items per call (half 0 or 1); the cursor marks the choice. */
/* " LADDER 4/8       PIRATES ": the rung and the team up next (ADR-023). */
static void hud_record_ladder(u8 row)
{
    u8 rung = g_save.settings.ladder;
    const char *team;
    char text[4];
    u8 length = 0;

    if (rung >= OPPONENT_COUNT)
        rung = 0;
    team = g_opponent_team[rung];
    text[0] = (char)('1' + rung);
    text[1] = '/';
    text[2] = (char)('0' + OPPONENT_COUNT);
    text[3] = 0;
    hud_text(RECORDS_COL + 1, row, HUD_PAL_WHITE, "LADDER");
    hud_text(RECORDS_COL + 8, row, HUD_PAL_YELLOW, text);
    while (team[length])
        ++length;
    hud_text(RECORDS_COUNT_COL + 4 - length, row, HUD_PAL_WHITE, team);
}

/* One menu item; the choice is yellow with the cursor. Items overwrite
 * their cells (the leading spaces cover the cursor). */
static void hud_title_item(u8 item, u8 choice)
{
    static const char *const items[TITLE_ENTRIES] = {
        "  SINGLES  ", "  DOUBLES  ", "  OPEN PLAY", "  COURT    ",
        "  CAREER   ", "  OPTIONS  ", "  MODIFIERS", "  PRACTICE "
    };

    hud_text(TITLE_MENU_COL, TITLE_MENU_ROW + item,
        item == choice ? HUD_PAL_YELLOW : HUD_PAL_WHITE, items[item]);
    if (item == choice)
        hud_tile(TITLE_MENU_COL, TITLE_MENU_ROW + item,
            hud_entry(HUD_TILE_CURSOR, HUD_PAL_YELLOW));
}

/* Two menu items per call (half 0 to 3). */
static void hud_title_menu(u8 choice, u8 half)
{
    u8 i = half * 2;
    u8 last = i + 2 > TITLE_ENTRIES ? TITLE_ENTRIES : i + 2;

    for (; i < last; ++i)
        hud_title_item(i, choice);
}

static void hud_title_2p_line(void)
{
    /* ADR-020: Start on pad 2 joins (or leaves) as 2P. */
    hud_text(TITLE_2P_COL, TITLE_2P_ROW,
        g_title_2p ? HUD_PAL_YELLOW : HUD_PAL_WHITE,
        g_title_2p ? "  2P JOINED!  " : "2P PRESS START");
}

/* A court page row's value: the venue choice, or a part's preset. */
static u8 hud_court_value(u8 index)
{
    if (index == COURT_ROW_VENUE)
        return g_save.settings.venue;
    if (index == COURT_ROW_TIME)
        return g_save.settings.time;
    return g_save.settings.court[index - COURT_ROW_PARTS];
}

/* A settings page row: cursor, label, and "<VALUE   >". */
static void hud_setting_row(u8 row, const char *label, const char *name,
    u8 cursor)
{
    char text[11];
    u8 i = 1;

    hud_tile(COURT_LABEL_COL - 1, row, cursor ?
        hud_entry(HUD_TILE_CURSOR, HUD_PAL_YELLOW) :
        hud_entry(' ', HUD_PAL_WHITE));
    hud_text(COURT_LABEL_COL, row, cursor ? HUD_PAL_YELLOW : HUD_PAL_WHITE,
        label);
    text[0] = '<';
    while (*name)
        text[i++] = *name++;
    while (i < 9)
        text[i++] = ' ';
    text[9] = '>';
    text[10] = 0;
    hud_text(COURT_VALUE_COL, row, HUD_PAL_WHITE, text);
}

/* One court page row. */
static void hud_court_row(u8 index)
{
    static const char *const labels[COURT_ROWS] = {
        "VENUE", "TIME", "SURFACE", "KITCHEN", "SURROUND", "LINES"
    };
    u8 value = hud_court_value(index);
    u8 cursor = g_court_edit.row == index;

    hud_setting_row(COURT_FIRST_ROW + index, labels[index],
        index == COURT_ROW_VENUE ? court_style_venue_name(value) :
        index == COURT_ROW_TIME ? court_style_time_name(value) :
        court_style_name(index - COURT_ROW_PARTS, value), cursor);
    s_court_row_drawn[index] = value | (cursor << 7);
}

/* An options page value: the points, or the difficulty. */
static u8 hud_options_value(u8 index)
{
    if (index == OPTIONS_ROW_POINTS)
        return g_save.settings.points;
    if (index == OPTIONS_ROW_SOUND)
        return g_save.settings.sound;
    if (index == OPTIONS_ROW_SPEED)
        return g_save.settings.ball_speed;
    if (index == OPTIONS_ROW_CAMERA)
        return g_save.camera;
    return g_save.settings.difficulty;
}

/* One options page row (ADR-025). */
static void hud_options_row(u8 index)
{
    u8 value = hud_options_value(index);
    u8 cursor = g_options_edit.row == index;
    char points[3];
    char speed[5];

    if (index == OPTIONS_ROW_POINTS) {
        points[0] = value >= 20 ? '2' : value >= 10 ? '1' : '0' + value;
        points[1] = value >= 10 ? (char)('0' + value % 10) : 0;
        points[2] = 0;
        hud_setting_row(COURT_FIRST_ROW, "POINTS", points, cursor);
    } else if (index == OPTIONS_ROW_SOUND) {
        hud_setting_row(COURT_FIRST_ROW + 2, "SOUND",
            audio_setting_name(value), cursor);
    } else if (index == OPTIONS_ROW_SPEED) {
        /* ADR-049: "90%". */
        speed[0] = (char)('0' + options_ball_speed(value) / 100);
        speed[1] = (char)('0' + options_ball_speed(value) / 10 % 10);
        speed[2] = (char)('0' + options_ball_speed(value) % 10);
        speed[3] = '%';
        speed[4] = 0;
        hud_setting_row(COURT_FIRST_ROW + 3, "BALL SPEED",
            speed[0] == '0' ? speed + 1 : speed, cursor);
    } else if (index == OPTIONS_ROW_CAMERA) {
        /* ADR-050: "OFF", "85%", "100%". */
        value = g_options_cameras[options_camera_index(value)];
        speed[0] = (char)('0' + value / 100);
        speed[1] = (char)('0' + value / 10 % 10);
        speed[2] = (char)('0' + value % 10);
        speed[3] = '%';
        speed[4] = 0;
        hud_setting_row(COURT_FIRST_ROW + 4, "CAMERA", value == 0 ? "OFF" :
            speed[0] == '0' ? speed + 1 : speed, cursor);
        value = g_save.camera;
    } else {
        hud_setting_row(COURT_FIRST_ROW + 1, "DIFFICULTY",
            options_difficulty_name(value), cursor);
    }
    s_options_row_drawn[index] = value | (cursor << 7);
}

/* Options page: the box, the header, then a row per frame. */
static u8 hud_options_draw_part(u8 part)
{
    if (part == 0) {
        hud_fill_box(RECORDS_COL, TITLE_MENU_ROW, RECORDS_WIDTH,
            OPTIONS_PAGE_ROWS, hud_entry(' ', HUD_PAL_WHITE));
        s_options_row_drawn[0] = 0xff;
        s_options_row_drawn[1] = 0xff;
        s_options_row_drawn[2] = 0xff;
        return 0;
    }
    if (part == 1) {
        hud_text(12, TITLE_MENU_ROW, HUD_PAL_YELLOW, "OPTIONS");
        return 0;
    }
    hud_options_row(part - 2);
    return part - 2 == OPTIONS_ROWS - 1;
}

/* One modifiers page row (ADR-033): the row's bit is its value. */
static void hud_modifiers_row(u8 index)
{
    u8 value = (g_save.settings.modifiers >> index) & 1;
    u8 cursor = g_modifiers_edit.row == index;

    hud_setting_row(COURT_FIRST_ROW + index, modifiers_row_label(index),
        modifiers_value_name(index, g_save.settings.modifiers), cursor);
    s_modifiers_row_drawn[index] = value | (cursor << 7);
}

/* Modifiers page: the box, the header, then a row per frame. */
static u8 hud_modifiers_draw_part(u8 part)
{
    u8 i;

    if (part == 0) {
        hud_fill_box(RECORDS_COL, TITLE_MENU_ROW, RECORDS_WIDTH,
            MODIFIERS_PAGE_ROWS, hud_entry(' ', HUD_PAL_WHITE));
        for (i = 0; i < MODIFIERS_ROWS; ++i)
            s_modifiers_row_drawn[i] = 0xff;
        return 0;
    }
    if (part == 1) {
        hud_text(12, TITLE_MENU_ROW, HUD_PAL_YELLOW, "MODIFIERS");
        return 0;
    }
    hud_modifiers_row(part - 2);
    return part - 2 == MODIFIERS_ROWS - 1;
}

/* After the modifiers page is drawn: a changed row, one per frame. */
static void hud_modifiers_refresh(void)
{
    u8 index;

    for (index = 0; index < MODIFIERS_ROWS; ++index) {
        if (s_modifiers_row_drawn[index] !=
                (((g_save.settings.modifiers >> index) & 1) |
                 ((g_modifiers_edit.row == index) << 7))) {
            hud_modifiers_row(index);
            return;
        }
    }
}

/* One practice page row (ADR-028). */
static void hud_practice_row(u8 index)
{
    static const char *const labels[PRACTICE_ROWS] = {
        "SHOT", "TARGET", "RATE", "RETURN TO"
    };
    u8 value = g_save.settings.practice[index];
    u8 cursor = g_practice_edit.row == index;
    const char *name = index == PRACTICE_ROW_SHOT ? practice_shot_name(value) :
        index == PRACTICE_ROW_TARGET ? practice_target_name(value) :
        index == PRACTICE_ROW_RATE ? practice_rate_name(value) :
        practice_zone_name(value);

    hud_setting_row(COURT_FIRST_ROW + index, labels[index], name, cursor);
    s_practice_row_drawn[index] = value | (cursor << 7);
}

/* The best streak for the RETURN TO zone (M4-PRACTICE-03). */
static void hud_practice_best(void)
{
    u8 zone = g_save.settings.practice[PRACTICE_ROW_ZONE];

    hud_record_line(COURT_FIRST_ROW + PRACTICE_ROWS + 1, "BEST STREAK",
        practice_saved_best(zone));
    s_practice_best_drawn = zone;
}

/* Practice page: the box, the header, a row per frame, then the best. */
static u8 hud_practice_draw_part(u8 part)
{
    if (part == 0) {
        hud_fill_box(RECORDS_COL, TITLE_MENU_ROW, RECORDS_WIDTH,
            PRACTICE_PAGE_ROWS, hud_entry(' ', HUD_PAL_WHITE));
        for (part = 0; part < PRACTICE_ROWS; ++part)
            s_practice_row_drawn[part] = 0xff;
        s_practice_best_drawn = 0xff;
        return 0;
    }
    if (part == 1) {
        hud_text(12, TITLE_MENU_ROW, HUD_PAL_YELLOW, "PRACTICE");
        return 0;
    }
    if (part < 2 + PRACTICE_ROWS) {
        hud_practice_row(part - 2);
        return 0;
    }
    hud_practice_best();
    return 1;
}

static void hud_practice_refresh(void)
{
    u8 index;

    for (index = 0; index < PRACTICE_ROWS; ++index) {
        if (s_practice_row_drawn[index] != (g_save.settings.practice[index] |
                ((g_practice_edit.row == index) << 7))) {
            hud_practice_row(index);
            return;
        }
    }
    if (s_practice_best_drawn != g_save.settings.practice[PRACTICE_ROW_ZONE])
        hud_practice_best();
}

/* After the options page is drawn: a changed row, one per frame. */
static void hud_options_refresh(void)
{
    u8 index;

    for (index = 0; index < OPTIONS_ROWS; ++index) {
        if (s_options_row_drawn[index] != (hud_options_value(index) |
                ((g_options_edit.row == index) << 7))) {
            hud_options_row(index);
            return;
        }
    }
}

/* Title views for the area: the menu choice (bits 0-2) and 2P (bit 3), or
 * a page: 0x7f + its TITLE_PAGE_*. */
#define HUD_TITLE_VIEW_PAGE(page) (0x7f + (page))
#define HUD_TITLE_VIEW_COURT HUD_TITLE_VIEW_PAGE(TITLE_PAGE_COURT)
#define HUD_TITLE_VIEW_RECORDS HUD_TITLE_VIEW_PAGE(TITLE_PAGE_RECORDS)
#define HUD_TITLE_VIEW_OPTIONS HUD_TITLE_VIEW_PAGE(TITLE_PAGE_OPTIONS)
#define HUD_TITLE_VIEW_PRACTICE HUD_TITLE_VIEW_PAGE(TITLE_PAGE_PRACTICE)
#define HUD_TITLE_VIEW_MODIFIERS HUD_TITLE_VIEW_PAGE(TITLE_PAGE_MODIFIERS)
/* The CAREER page (ADR-047, the RECORDS entry): a view per sub-view. */
#define HUD_TITLE_VIEW_CAREER 0x90
#define HUD_CAREER_NAMING 4         /* EDIT while typing the name */

/* Runs on every idle title frame behind the demo: one test, not one per
 * page. */
static u8 hud_title_view(void)
{
    if (g_title_page == TITLE_PAGE_RECORDS)
        return HUD_TITLE_VIEW_CAREER + (g_career_page.view ==
            CAREER_VIEW_EDIT && g_career_page.naming ? HUD_CAREER_NAMING :
            g_career_page.view);
    if (g_title_page != TITLE_PAGE_MENU)
        return HUD_TITLE_VIEW_PAGE(g_title_page);
    return g_title_mode | (g_title_2p << 3);
}

/* Court page: the box, the header, then a part per frame. */
static u8 hud_court_draw_part(u8 part)
{
    u8 i;

    if (part == 0) {
        hud_fill_box(RECORDS_COL, TITLE_MENU_ROW, RECORDS_WIDTH,
            COURT_PAGE_ROWS, hud_entry(' ', HUD_PAL_WHITE));
        for (i = 0; i < COURT_ROWS; ++i)
            s_court_row_drawn[i] = 0xff;
        return 0;
    }
    if (part == 1) {
        hud_text(13, TITLE_MENU_ROW, HUD_PAL_YELLOW, "COURT");
        return 0;
    }
    hud_court_row(part - 2);
    return part - 2 == COURT_ROWS - 1;
}

/* After the court page is drawn: the first row whose value or cursor
 * changed (Left/Right, Up/Down), one per frame. */
static void hud_court_refresh(void)
{
    u8 index;
    u8 want;

    for (index = 0; index < COURT_ROWS; ++index) {
        want = hud_court_value(index) | ((g_court_edit.row == index) << 7);
        if (s_court_row_drawn[index] != want) {
            hud_court_row(index);
            return;
        }
    }
}


/* ---- The CAREER page (ADR-047, M4-CAREER-02) ---- */

#define CAREER_SLOTS_ROWS 8         /* header, gap, 3 slots, gap, NO PLAYER,
                                       RECORDS */
#define CAREER_EDIT_PAGE_ROWS 9     /* header, gap, 7 rows */
#define CAREER_NAME_COL 8
#define CAREER_UNDRAWN 0xff

/* Slots view rows as drawn: cursor << 7 | active << 6 | used << 5. */
static u8 s_career_slot_drawn[CAREER_SLOT_ROWS];
/* Edit rows as drawn: value | cursor << 7; the name row keeps its own. */
static u8 s_career_edit_drawn[CAREER_EDIT_ROWS];
static u8 s_career_name_drawn[CAREER_NAME + 2];   /* letters, cursor, mode */

static u8 hud_career_slot_state(u8 row)
{
    u8 state = (u8)((g_career_page.row == row) << 7);

    if (row < CAREER_SLOTS) {
        state |= (u8)((g_save.career_active == row) << 6);
        state |= (u8)(g_save.career[row].used << 5);
    } else if (row == CAREER_ROW_NOBODY) {
        state |= (u8)((career_active() == 0) << 6);
    }
    return state;
}

/* "> 1 ACE          12W", "  2 NEW PLAYER", then NO PLAYER (yellow when
 * nobody is active) and RECORDS after a gap. */
static void hud_career_slot_row(u8 row)
{
    static char name[CAREER_NAME + 1];
    const CareerPlayer *player;
    u8 line = TITLE_MENU_ROW + 2 + row + (row >= CAREER_ROW_NOBODY);
    u8 cursor = g_career_page.row == row;
    u8 i;

    hud_fill_box(RECORDS_COL + 1, line, RECORDS_WIDTH - 2, 1,
        hud_entry(' ', HUD_PAL_WHITE));
    hud_tile(RECORDS_COL + 1, line, cursor ?
        hud_entry(HUD_TILE_CURSOR, HUD_PAL_YELLOW) :
        hud_entry(' ', HUD_PAL_WHITE));
    if (row == CAREER_ROW_RECORDS) {
        hud_text(CAREER_NAME_COL, line,
            cursor ? HUD_PAL_YELLOW : HUD_PAL_WHITE, "RECORDS");
    } else if (row == CAREER_ROW_NOBODY) {
        hud_text(CAREER_NAME_COL, line, career_active() == 0 ?
            HUD_PAL_YELLOW : HUD_PAL_WHITE, "NO PLAYER");
    } else {
        player = &g_save.career[row];
        name[0] = (char)('1' + row);
        name[1] = 0;
        hud_text(RECORDS_COL + 2, line, HUD_PAL_WHITE, name);
        if (player->used) {
            for (i = 0; i < CAREER_NAME; ++i)
                name[i] = (char)player->name[i];
            name[CAREER_NAME] = 0;
            hud_text(CAREER_NAME_COL, line, g_save.career_active == row ?
                HUD_PAL_YELLOW : HUD_PAL_WHITE, name);
            hud_count(RECORDS_COUNT_COL - 1, line,
                player->wins[0] + player->wins[1]);
            hud_text(RECORDS_COUNT_COL + 3, line, HUD_PAL_YELLOW, "W");
        } else {
            hud_text(CAREER_NAME_COL, line, HUD_PAL_WHITE, "NEW PLAYER");
        }
    }
    s_career_slot_drawn[row] = hud_career_slot_state(row);
}

static void hud_career_slots_refresh(void)
{
    u8 row;

    for (row = 0; row < CAREER_SLOT_ROWS; ++row)
        if (s_career_slot_drawn[row] != hud_career_slot_state(row)) {
            hud_career_slot_row(row);
            return;
        }
}

/* " SINGLES  W nnnn  L nnnn " for the card's player. */
static void hud_career_mode_line(u8 row, const char *label, u16 wins,
    u16 losses)
{
    hud_text(RECORDS_COL + 1, row, HUD_PAL_WHITE, label);
    hud_text(RECORDS_COUNT_COL - 9, row, HUD_PAL_YELLOW, "W");
    hud_count(RECORDS_COUNT_COL - 7, row, wins);
    hud_text(RECORDS_COUNT_COL - 2, row, HUD_PAL_YELLOW, "L");
    hud_count(RECORDS_COUNT_COL, row, losses);
}

/* "UNLOCKS             n/9" */
static void hud_career_unlocks_line(u8 row, const CareerPlayer *player)
{
    static char text[6];
    u8 count = career_unlock_count(player);
    u8 i = 0;

    if (count >= 10)
        text[i++] = '1';
    text[i++] = (char)('0' + count % 10);
    text[i++] = '/';
    text[i++] = (char)('0' + CAREER_UNLOCKS % 10);
    text[i] = 0;
    hud_text(RECORDS_COL + 1, row, HUD_PAL_WHITE, "UNLOCKS");
    hud_text(RECORDS_COUNT_COL + 4 - i, row, HUD_PAL_YELLOW, text);
}

/* "NEXT: HEADBAND" and how to earn it, or ALL UNLOCKED! */
static void hud_career_next_lines(u8 row, const CareerPlayer *player)
{
    u8 next = career_next_unlock(player);

    if (next >= CAREER_UNLOCKS) {
        hud_text(RECORDS_COL + 1, row, HUD_PAL_YELLOW, "ALL UNLOCKED!");
        return;
    }
    hud_text(RECORDS_COL + 1, row, HUD_PAL_WHITE, "NEXT:");
    hud_text(RECORDS_COL + 7, row, HUD_PAL_YELLOW,
        g_career_unlock_names[next]);
    hud_text(RECORDS_COL + 1, row + 1, HUD_PAL_WHITE,
        g_career_unlock_how[next]);
}

static void hud_career_line(u8 row, const char *label, u16 value)
{
    hud_text(RECORDS_COL + 1, row, HUD_PAL_WHITE, label);
    hud_count(RECORDS_COUNT_COL, row, value);
}

/* The card: a part per frame, two rows at most. */
static u8 hud_career_card_part(u8 part)
{
    static char name[CAREER_NAME + 1];
    const CareerPlayer *player = &g_save.career[g_career_page.slot];
    u8 i;

    switch (part) {
    case 0:
        hud_fill_box(RECORDS_COL, TITLE_MENU_ROW, RECORDS_WIDTH, RECORDS_ROWS,
            hud_entry(' ', HUD_PAL_WHITE));
        return 0;
    case 1:
        for (i = 0; i < CAREER_NAME; ++i)
            name[i] = (char)player->name[i];
        name[CAREER_NAME] = 0;
        hud_text(12, TITLE_MENU_ROW, HUD_PAL_YELLOW, name);
        return 0;
    case 2:
        hud_career_mode_line(TITLE_MENU_ROW + 2, "SINGLES", player->wins[0],
            player->losses[0]);
        hud_career_mode_line(TITLE_MENU_ROW + 3, "DOUBLES", player->wins[1],
            player->losses[1]);
        return 0;
    case 3:
        hud_career_line(TITLE_MENU_ROW + 4, "ACES", player->aces);
        hud_career_line(TITLE_MENU_ROW + 5, "SHUTOUTS", player->shutouts);
        return 0;
    case 4:
        hud_career_line(TITLE_MENU_ROW + 6, "BEST STREAK",
            player->best_streak);
        hud_career_line(TITLE_MENU_ROW + 7, "LONGEST RALLY",
            player->longest_rally);
        return 0;
    case 5:
        hud_career_unlocks_line(TITLE_MENU_ROW + 8, player);
        return 0;
    default:
        hud_career_next_lines(TITLE_MENU_ROW + 9, player);
        return 1;
    }
}

/* A look row's display name. */
static const char *hud_career_look_name(const CareerPlayer *player, u8 row)
{
    u8 value = career_look_value(player, row);

    switch (row) {
    case CAREER_EDIT_BODY:
        return career_body_name(value);
    case CAREER_EDIT_SKIN:
        return g_career_skin_names[value % CAREER_SKINS];
    case CAREER_EDIT_HAIR:
        return g_career_hair_names[value % CAREER_HAIRS];
    case CAREER_EDIT_SHIRT:
        return career_shirt_name(value);
    case CAREER_EDIT_HAT:
        return g_career_hat_names[value % CAREER_HATS];
    default:
        return career_paddle_name(value);
    }
}

/* The editor (and the keyboard) sit right of the title demo's P1, who
 * stands still at the left baseline wearing the look. */
#define CAREER_EDIT_COL 8
#define CAREER_EDIT_WIDTH 20
#define CAREER_EDIT_LABEL_COL (CAREER_EDIT_COL + 2)
#define CAREER_EDIT_VALUE_COL (CAREER_EDIT_COL + 9)     /* "<NAME    >" */

/* An editor row: cursor, label, and "<VALUE   >". */
static void hud_career_setting(u8 row, const char *label, const char *name,
    u8 cursor)
{
    char text[11];
    u8 i = 1;

    hud_tile(CAREER_EDIT_LABEL_COL - 1, row, cursor ?
        hud_entry(HUD_TILE_CURSOR, HUD_PAL_YELLOW) :
        hud_entry(' ', HUD_PAL_WHITE));
    hud_text(CAREER_EDIT_LABEL_COL, row,
        cursor ? HUD_PAL_YELLOW : HUD_PAL_WHITE, label);
    text[0] = '<';
    while (*name && i < 9)
        text[i++] = *name++;
    while (i < 9)
        text[i++] = ' ';
    text[9] = '>';
    text[10] = 0;
    hud_text(CAREER_EDIT_VALUE_COL, row, HUD_PAL_WHITE, text);
}

static void hud_career_edit_row(u8 row)
{
    static const char *const labels[CAREER_EDIT_ROWS] = {
        "NAME", "BODY", "SKIN", "HAIR", "SHIRT", "HAT", "PADDLE"
    };
    static char name[CAREER_NAME + 1];
    const CareerPlayer *player = &g_save.career[g_career_page.slot];
    u8 cursor = g_career_page.row == row;
    u8 i;

    if (row == CAREER_EDIT_NAME) {
        for (i = 0; i < CAREER_NAME; ++i)
            name[i] = (char)player->name[i];
        name[CAREER_NAME] = 0;
        hud_career_setting(TITLE_MENU_ROW + 2, labels[0], name, cursor);
        s_career_edit_drawn[row] = (u8)(cursor << 7);
        return;
    }
    hud_career_setting(TITLE_MENU_ROW + 2 + row, labels[row],
        hud_career_look_name(player, row), cursor);
    s_career_edit_drawn[row] = (u8)(career_look_value(player, row) |
        (cursor << 7));
}

/* The look's paddle stats with the hat's gear (stage 4): "PWR 2  CTL 4
 * SPD 3" at the box's foot. */
#define CAREER_STATS_ROW (TITLE_MENU_ROW + 10)
static u8 s_career_stats_drawn;

static u8 hud_career_profile(void)
{
    const CareerPlayer *player = &g_save.career[g_career_page.slot];

    return PADDLE_PROFILE(player->paddle % PADDLE_COUNT,
        player->hat % PADDLE_GEARS);
}

static void hud_career_stats_line(void)
{
    static char text[] = "PWR 0  CTL 0  SPD 0";
    u8 profile = hud_career_profile();

    text[4] = (char)('0' + g_paddle_stats[profile][0]);
    text[11] = (char)('0' + g_paddle_stats[profile][1]);
    text[18] = (char)('0' + g_paddle_stats[profile][2]);
    hud_text(CAREER_EDIT_COL + 1, CAREER_STATS_ROW, HUD_PAL_YELLOW, text);
    s_career_stats_drawn = profile;
}

static void hud_career_edit_refresh(void)
{
    const CareerPlayer *player = &g_save.career[g_career_page.slot];
    u8 row;

    if (s_career_stats_drawn != hud_career_profile()) {
        hud_career_stats_line();
        return;
    }
    for (row = 0; row < CAREER_EDIT_ROWS; ++row)
        if (s_career_edit_drawn[row] != (u8)((row == CAREER_EDIT_NAME ? 0 :
                career_look_value(player, row)) |
                ((g_career_page.row == row) << 7))) {
            hud_career_edit_row(row);
            return;
        }
}

/* The keyboard (typing the name): the name with a box per empty place,
 * the letters, then DEL and END; the key picked is yellow. */
#define CAREER_NAME_LINE_COL 14
#define CAREER_KEYS_COL (CAREER_EDIT_COL + 1)
#define CAREER_KEYS_ROW (TITLE_MENU_ROW + 4)
/* The key last drawn picked, and a keyboard row still to redraw (the old
 * key's, when the pick moved to another row), or 0xff. */
static u8 s_career_key_drawn;
static u8 s_career_row_pending;

static void hud_career_name_line(void)
{
    static char letter[2];
    const CareerPlayer *player = &g_save.career[g_career_page.slot];
    u8 cursor = g_career_page.cursor;
    u8 row = TITLE_MENU_ROW + 2;
    u8 i;

    /* Typed letters, then an empty box per place left, the next one
     * yellow (the font has no visible underscore). */
    letter[1] = 0;
    for (i = 0; i < CAREER_NAME; ++i) {
        if (i < cursor) {
            letter[0] = (char)player->name[i];
            hud_text(CAREER_NAME_LINE_COL + i, row, HUD_PAL_WHITE, letter);
        } else {
            hud_tile(CAREER_NAME_LINE_COL + i, row,
                hud_entry(HUD_TILE_BAR_OFF,
                    i == cursor ? HUD_PAL_YELLOW : HUD_PAL_WHITE));
        }
    }
    memcpy(s_career_name_drawn, player->name, CAREER_NAME);
    s_career_name_drawn[CAREER_NAME] = cursor;
}

/* A keyboard row: letters two cells apart (a space shows as _), or DEL
 * and END. */
static void hud_career_key_row(u8 row)
{
    static char key[4];
    u8 picked = career_page_key();
    u8 first = row * CAREER_KEY_COLS;
    u8 i;

    if (row == CAREER_KEY_ROWS - 1) {
        hud_text(CAREER_KEYS_COL + 2, CAREER_KEYS_ROW + row,
            picked == CAREER_KEY_DEL ? HUD_PAL_YELLOW : HUD_PAL_WHITE, "DEL");
        hud_text(CAREER_KEYS_COL + 12, CAREER_KEYS_ROW + row,
            picked == CAREER_KEY_END ? HUD_PAL_YELLOW : HUD_PAL_WHITE, "END");
        return;
    }
    key[1] = 0;
    for (i = 0; i < CAREER_KEY_COLS && first + i < CAREER_KEY_CHARS; ++i) {
        /* The space key is an empty box, like an empty place. */
        if (g_career_key_chars[first + i] == ' ') {
            hud_tile(CAREER_KEYS_COL + 2 * i, CAREER_KEYS_ROW + row,
                hud_entry(HUD_TILE_BAR_OFF, first + i == picked ?
                    HUD_PAL_YELLOW : HUD_PAL_WHITE));
            continue;
        }
        key[0] = g_career_key_chars[first + i];
        hud_text(CAREER_KEYS_COL + 2 * i, CAREER_KEYS_ROW + row,
            first + i == picked ? HUD_PAL_YELLOW : HUD_PAL_WHITE, key);
    }
}

/* The keyboard row a key is on. */
static u8 hud_career_key_row_of(u8 key)
{
    if (key >= CAREER_KEY_CHARS)
        return CAREER_KEY_ROWS - 1;
    return key / CAREER_KEY_COLS;
}

static void hud_career_naming_refresh(void)
{
    const CareerPlayer *player = &g_save.career[g_career_page.slot];
    u8 picked = career_page_key();
    u8 old = s_career_key_drawn;

    if (memcmp(s_career_name_drawn, player->name, CAREER_NAME) != 0 ||
            s_career_name_drawn[CAREER_NAME] != g_career_page.cursor) {
        hud_career_name_line();
        return;
    }
    /* The old key's row, a frame after the new one's. */
    if (s_career_row_pending != 0xff) {
        hud_career_key_row(s_career_row_pending);
        s_career_row_pending = 0xff;
        return;
    }
    if (old == picked)
        return;
    hud_career_key_row(hud_career_key_row_of(picked));
    if (hud_career_key_row_of(old) != hud_career_key_row_of(picked))
        s_career_row_pending = hud_career_key_row_of(old);
    s_career_key_drawn = picked;
}

static u8 hud_career_naming_part(u8 part)
{
    if (part == 0) {
        hud_fill_box(CAREER_EDIT_COL, TITLE_MENU_ROW, CAREER_EDIT_WIDTH,
            CAREER_EDIT_PAGE_ROWS, hud_entry(' ', HUD_PAL_WHITE));
        s_career_row_pending = 0xff;
        return 0;
    }
    if (part == 1) {
        hud_text(16, TITLE_MENU_ROW, HUD_PAL_YELLOW, "NAME");
        hud_career_name_line();
        return 0;
    }
    hud_career_key_row(part - 2);
    if (part - 2 == CAREER_KEY_ROWS - 1) {
        s_career_key_drawn = career_page_key();
        return 1;
    }
    return 0;
}

/* One part of a CAREER view. */
static u8 hud_career_draw_part(u8 view, u8 part)
{
    u8 i;

    if (view == CAREER_VIEW_CARD)
        return hud_career_card_part(part);
    if (view == HUD_CAREER_NAMING)
        return hud_career_naming_part(part);
    if (view == CAREER_VIEW_EDIT) {
        if (part == 0) {
            /* Two more rows than the keyboard's: the stats line. */
            hud_fill_box(CAREER_EDIT_COL, TITLE_MENU_ROW, CAREER_EDIT_WIDTH,
                CAREER_EDIT_PAGE_ROWS + 2, hud_entry(' ', HUD_PAL_WHITE));
            for (i = 0; i < CAREER_EDIT_ROWS; ++i)
                s_career_edit_drawn[i] = CAREER_UNDRAWN;
            return 0;
        }
        if (part == 1) {
            hud_text(15, TITLE_MENU_ROW, HUD_PAL_YELLOW, "PLAYER");
            return 0;
        }
        if (part - 2 < CAREER_EDIT_ROWS) {
            hud_career_edit_row(part - 2);
            return 0;
        }
        hud_career_stats_line();
        return 1;
    }
    /* SLOTS */
    if (part == 0) {
        hud_fill_box(RECORDS_COL, TITLE_MENU_ROW, RECORDS_WIDTH,
            CAREER_SLOTS_ROWS, hud_entry(' ', HUD_PAL_WHITE));
        for (i = 0; i < CAREER_SLOT_ROWS; ++i)
            s_career_slot_drawn[i] = CAREER_UNDRAWN;
        return 0;
    }
    if (part == 1) {
        hud_text(13, TITLE_MENU_ROW, HUD_PAL_YELLOW, "CAREER");
        return 0;
    }
    hud_career_slot_row(part - 2);
    return part - 2 == CAREER_SLOT_ROWS - 1;
}

static u8 hud_records_draw_part(u8 part);

/* One part of the area; returns nonzero when the view is complete. One
 * row per part: the title demo leaves little frame time. */
static u8 hud_title_draw_part(u8 view, u8 part)
{
    if (view == HUD_TITLE_VIEW_COURT)
        return hud_court_draw_part(part);
    if (view == HUD_TITLE_VIEW_OPTIONS)
        return hud_options_draw_part(part);
    if (view == HUD_TITLE_VIEW_PRACTICE)
        return hud_practice_draw_part(part);
    if (view == HUD_TITLE_VIEW_MODIFIERS)
        return hud_modifiers_draw_part(part);
    if (view == HUD_TITLE_VIEW_CAREER + CAREER_VIEW_RECORDS)
        return hud_records_draw_part(part);
    if (view >= HUD_TITLE_VIEW_CAREER)
        return hud_career_draw_part(view - HUD_TITLE_VIEW_CAREER, part);
    /* Parts stay at most two rows: each waits for a frame under
     * HUD_TITLE_SCANLINE_LIMIT, which leaves room for no more. */
    if (part < 4) {
        hud_title_menu(view & 7, part);
        return 0;
    }
    hud_title_2p_line();
    return 1;
}

/* The records table (ADR-021), now a section of the CAREER page. */
static u8 hud_records_draw_part(u8 part)
{
    switch (part) {
    case 0:
        /* The font's space is a dark cell: a solid box over the court. */
        hud_fill_box(RECORDS_COL, TITLE_MENU_ROW, RECORDS_WIDTH, RECORDS_ROWS,
            hud_entry(' ', HUD_PAL_WHITE));
        return 0;
    case 1:
        hud_text(12, TITLE_MENU_ROW, HUD_PAL_YELLOW, "RECORDS");
        return 0;
    case 2:
        hud_record_mode_line(TITLE_MENU_ROW + 2, "SINGLES", MATCH_SINGLES);
        return 0;
    case 3:
        hud_record_mode_line(TITLE_MENU_ROW + 3, "DOUBLES", MATCH_DOUBLES);
        return 0;
    case 4:
        hud_record_line(TITLE_MENU_ROW + 5, "WIN STREAK",
            g_save.records.streak);
        return 0;
    case 5:
        hud_record_line(TITLE_MENU_ROW + 6, "BEST STREAK",
            g_save.records.best_streak);
        hud_record_initials(TITLE_MENU_ROW + 6, g_save.initials.best_streak);
        return 0;
    case 6:
        hud_record_line(TITLE_MENU_ROW + 7, "SHUTOUTS",
            g_save.records.shutouts);
        return 0;
    case 7:
        hud_record_line(TITLE_MENU_ROW + 8, "LONGEST RALLY",
            g_save.records.longest_rally);
        hud_record_initials(TITLE_MENU_ROW + 8,
            g_save.initials.longest_rally);
        return 0;
    case 8:
        hud_record_ladder(TITLE_MENU_ROW + 9);
        return 0;
    default:
        hud_record_line(TITLE_MENU_ROW + 10, "LADDER CLEARS",
            g_save.records.ladder_clears);
        return 1;
    }
}

/* Idle frames on the title: clear the area when the view changed, then
 * draw it a part per frame. */
static void hud_title_area_update(void)
{
    u8 view = hud_title_view();

    /* A drawn menu whose cursor or 2P line changed: redraw only what
     * changed, in place, at once (two rows are cheap, so this skips the
     * wait for a lighter frame; no clear, so nothing flickers). */
    /* The item the cursor left, a frame after the move: the two items on
     * one frame cost about 140 scanlines, which the title demo's frames do
     * not always have (M4-UI-03). */
    if (s_title_stale != 0xff) {
        /* Coloured by the choice now, so another move since is fine. */
        if (s_title_part == 0xff && s_title_view < HUD_TITLE_VIEW_COURT &&
                view < HUD_TITLE_VIEW_COURT)
            hud_title_item(s_title_stale, view & 7);
        s_title_stale = 0xff;
        return;
    }
    if (s_title_view != view && s_title_part == 0xff &&
            s_title_view < HUD_TITLE_VIEW_COURT &&
            view < HUD_TITLE_VIEW_COURT) {
        if ((s_title_view ^ view) & 7) {
            hud_title_item(view & 7, view & 7);
            s_title_stale = s_title_view & 7;
        }
        if ((s_title_view ^ view) & 8)
            hud_title_2p_line();
        s_title_view = view;
        return;
    }
    if (hud_title_wait(HUD_TITLE_SCANLINE_LIMIT))
        return;

    if (s_title_view == view) {
        if (s_title_part == 0xff) {
            /* A drawn page redraws a changed row; a drawn menu, nothing. */
            if (view < HUD_TITLE_VIEW_COURT)
                return;
            if (view == HUD_TITLE_VIEW_COURT)
                hud_court_refresh();
            else if (view == HUD_TITLE_VIEW_OPTIONS)
                hud_options_refresh();
            else if (view == HUD_TITLE_VIEW_PRACTICE)
                hud_practice_refresh();
            else if (view == HUD_TITLE_VIEW_MODIFIERS)
                hud_modifiers_refresh();
            else if (view == HUD_TITLE_VIEW_CAREER + CAREER_VIEW_SLOTS)
                hud_career_slots_refresh();
            else if (view == HUD_TITLE_VIEW_CAREER + CAREER_VIEW_EDIT)
                hud_career_edit_refresh();
            else if (view == HUD_TITLE_VIEW_CAREER + HUD_CAREER_NAMING)
                hud_career_naming_refresh();
            return;
        }
        /* Parts back to back while the frame stays under the limit
         * (M4-UI-01): each fits after it, as the first one does. */
        do {
            if (hud_title_draw_part(view, s_title_part)) {
                s_title_part = 0xff;
                return;
            }
            ++s_title_part;
        } while (profile_scanline() <= HUD_TITLE_SCANLINE_LIMIT);
        return;
    }
    /* Otherwise draw the whole view a part per frame. Menu to menu still
     * needs no clear (every item overwrites its cells); a page does. */
    if (s_title_view != HUD_TITLE_CLEARED &&
            !(s_title_view < HUD_TITLE_VIEW_COURT &&
              view < HUD_TITLE_VIEW_COURT))
        hud_clear_rows(TITLE_MENU_ROW, TITLE_AREA_ROWS);
    s_title_view = view;
    s_title_part = 0;
}

/* The scanline a title step waits under: the logo steps between two title
 * views draw nothing; every other step (a logo row, a clear, a prompt's
 * panel or half its text, a restored prompt) fits an ordinary frame. A new
 * prompt in one step (about 106 scanlines) needed a light frame, waited
 * them out on the singles demo, and dropped one (court.timeline). */
static u16 hud_title_step_limit(u8 step)
{
    if (step == HUD_STEP_BIG || step == HUD_STEP_EXTRA)
        return HUD_IS_TITLE(s_prev_scene) ? 0xffff : HUD_TITLE_SCANLINE_LIMIT;
    return HUD_TITLE_SCANLINE_LIMIT;
}

static const char *hud_title_prompt(u8 page)
{
    /* The CAREER page's prompts (hud_title_prompt_id). */
    if (page == HUD_PROMPT_CAREER + CAREER_VIEW_SLOTS)
        return "@ OPEN  Y BACK";
    if (page == HUD_PROMPT_CAREER + CAREER_VIEW_CARD)
        return "@ EDIT  Y BACK";
    if (page == HUD_PROMPT_CAREER + CAREER_VIEW_EDIT)
        return "@ OK  Y CANCEL";
    if (page == HUD_PROMPT_CAREER_NAMING)
        return "@ TYPE  Y ERASE";
    if (page == HUD_PROMPT_CAREER_NAMING_EMPTY)
        return "@ TYPE  Y BACK";
    if (page == TITLE_PAGE_COURT || page == TITLE_PAGE_OPTIONS ||
            page == TITLE_PAGE_MODIFIERS)
        return "@ OK  Y CANCEL";
    if (page == TITLE_PAGE_PRACTICE)
        return "@ PLAY  Y BACK";
    if (page == HUD_PROMPT_CAREER + CAREER_VIEW_RECORDS)
        return "@ BACK";
    return "PRESS START";
}

/*
 * Title steps: CLEAR wipes the match overlays (coming from a match), BIG
 * and then EXTRA draw the logo's two rows, and PROMPT the blinking prompt.
 * Only the prompt blinks; the logo stays. The logo in one step (about 100
 * scanlines) fit only a light frame, which the demos rarely have; forced
 * onto an ordinary one after HUD_TITLE_MAX_WAITS, it dropped a frame.
 */
static void hud_title_step(u16 key, u8 step, u8 from_title)
{
    switch (step) {
    case HUD_STEP_CLEAR:
        if (!from_title) {
            hud_clear_rows(CENTER_BIG_ROW - 2, 6 + TITLE_AREA_ROWS);
            s_title_view = HUD_TITLE_CLEARED;
        }
        break;
    case HUD_STEP_BIG:
        if (!from_title)
            hud_center_big(TITLE_ROW, HUD_PAL_YELLOW, "PICKLEBALL");
        break;
    case HUD_STEP_EXTRA:
        if (!from_title)
            hud_center_big(TITLE_ROW + 2, HUD_PAL_YELLOW, "'94");
        break;
    case HUD_STEP_PROMPT:
        s_prompt_text = 0;
        if (!(key & 1) && s_prompt_page == ((key >> 1) & 15)) {
            hud_restore_rows(BANNER_ROW - 1, HUD_PROMPT_ROWS, s_prompt_rows);
            break;
        }
        hud_clear_rows(BANNER_ROW - 1, HUD_PROMPT_ROWS);
        if (!(key & 1)) {
            hud_center_prompt_panel(BANNER_ROW,
                hud_title_prompt((key >> 1) & 15));
            s_prompt_text = 1;
        }
        break;
    /* A new prompt's text, in halves on the next two steps; then it is
     * kept for the blink. */
    case HUD_STEP_EXTRA2:
    case HUD_STEP_EXTRA3:
        hud_center_prompt_half(BANNER_ROW, HUD_PAL_WHITE,
            hud_title_prompt((key >> 1) & 15), step == HUD_STEP_EXTRA3);
        if (step == HUD_STEP_EXTRA3) {
            hud_save_rows(BANNER_ROW - 1, HUD_PROMPT_ROWS, s_prompt_rows);
            s_prompt_page = (key >> 1) & 15;
            s_prompt_text = 0;
        }
        break;
    default:
        break;
    }
}

/* Pause menu (ADR-030): a box with PAUSED and the three choices. */
static void hud_pause_step(u8 step)
{
    u8 i;
    u8 on;

    if (step == HUD_STEP_PROMPT) {
        hud_fill_box(PAUSE_BOX_COL, PAUSE_BOX_ROW, PAUSE_BOX_WIDTH, 5,
            hud_entry(' ', HUD_PAL_WHITE));
        hud_text(PAUSE_BOX_COL + 4, PAUSE_BOX_ROW, HUD_PAL_YELLOW, "PAUSED");
    } else if (step == HUD_STEP_EXTRA) {
        for (i = 0; i < PAUSE_CHOICES; ++i) {
            on = i == g_pause_choice;
            hud_tile(PAUSE_BOX_COL + 1, PAUSE_BOX_ROW + 2 + i, on ?
                hud_entry(HUD_TILE_CURSOR, HUD_PAL_YELLOW) :
                hud_entry(' ', HUD_PAL_WHITE));
            hud_text(PAUSE_BOX_COL + 3, PAUSE_BOX_ROW + 2 + i,
                on ? HUD_PAL_YELLOW : HUD_PAL_WHITE, pause_choice_name(i));
        }
    }
}

static void hud_scene_step(u16 key, u8 step)
{
    u8 winner = g_game_state.point_winner;
    u8 from_title = HUD_IS_TITLE(s_prev_scene);

    if (HUD_IS_TITLE(key)) {
        hud_title_step(key, step, from_title);
        return;
    }

    if (step == HUD_STEP_CLEAR) {
        /* The initials card also uses rows 15-18 (ADR-040). */
        hud_clear_rows(from_title ? CENTER_BIG_ROW - 2 : CENTER_BIG_ROW,
            from_title ? 6 + TITLE_AREA_ROWS : s_replay_drawn ?
                REPLAY_ROW + REPLAY_ROWS + 1 - CENTER_BIG_ROW :
            (key == HUD_KEY_INITIALS || s_prev_scene == HUD_KEY_INITIALS) ?
                INITIALS_LAST_ROW + 1 - CENTER_BIG_ROW :
            s_quip_drawn ? QUIP_PANEL_ROW + 3 - CENTER_BIG_ROW : 7);
        s_replay_drawn = 0;
        s_quip_drawn = 0;
        hud_clear_rows(BANNER_ROW - 1, 4);
        s_initials_drawn[0] = 0;
        s_initials_drawn[1] = 0;
        s_initials_drawn[2] = 0;
        s_initials_cursor = 0xff;
        return;
    }
    if (key == HUD_KEY_INTRO) {
        hud_intro_step(step);
        return;
    }
    if (key == HUD_KEY_INITIALS) {
        hud_initials_step(step);
        return;
    }
    if (key == HUD_KEY_UNLOCK) {
        hud_unlock_step(step);
        return;
    }
    if (key == HUD_KEY_PRACTICE) {
        if (step == HUD_STEP_PROMPT)
            hud_center_prompt(BANNER_ROW, HUD_PAL_WHITE, "START  PAUSE");
        return;
    }
    if (HUD_IS_PAUSED(key)) {
        hud_pause_step(step);
        return;
    }
    if (g_game_state.phase == GAME_PHASE_MATCH_RESULT &&
            step >= HUD_STEP_PROMPT) {
        /* The prompt's panel, then its text in halves, then the story
         * card (hud_result_story): each on its own frame. Together they
         * overran the doubles result frame. */
        if (step == HUD_STEP_PROMPT)
            hud_center_prompt_panel(BANNER_ROW, hud_result_prompt());
        else if (step <= HUD_STEP_EXTRA2)
            hud_center_prompt_half(BANNER_ROW, HUD_PAL_WHITE,
                hud_result_prompt(), step == HUD_STEP_EXTRA2);
        else if (!g_attract)
            hud_result_story(step);
        return;
    }
    if (g_game_state.phase == GAME_PHASE_POINT_RESULT &&
            step >= HUD_STEP_PROMPT) {
        /* The point's panel, then its text in halves, each on its own
         * frame: drawn whole on the frame after the big banner, with the
         * score, it was the doubles budget's worst frame (as the match
         * result's was, M4-UI-04). Then the close call's frame and caption
         * (ADR-041). */
        if (step == HUD_STEP_PROMPT) {
            hud_center_prompt_panel(CENTER_PANEL_ROW, hud_point_text(winner));
            /* A quip from the side that lost it, now and then; never over
             * a close call's replay (GOOFY_IDEAS.md). */
            s_quip = (g_replay.active && !g_attract) ? 0 :
                story_quip(winner ^ 1, g_game_state.frame_count);
        } else if (step <= HUD_STEP_EXTRA2) {
            hud_center_prompt_half(CENTER_PANEL_ROW, team_hud_palette(winner),
                hud_point_text(winner), step == HUD_STEP_EXTRA2);
        } else if (g_replay.active && !g_attract) {
            hud_replay_step(step - (HUD_STEP_EXTRA3 - HUD_STEP_EXTRA));
        } else if (step == HUD_STEP_EXTRA3 && s_quip) {
            /* The quip's panel under the point's, then its text. */
            hud_center_prompt_panel(QUIP_PANEL_ROW, s_quip);
            s_quip_drawn = 1;
        } else if (step == HUD_STEP_EXTRA4 && s_quip) {
            hud_center_prompt_half(QUIP_PANEL_ROW, team_hud_palette(winner ^ 1),
                s_quip, 0);
            hud_center_prompt_half(QUIP_PANEL_ROW, team_hud_palette(winner ^ 1),
                s_quip, 1);
        }
        return;
    }
    if (step >= HUD_STEP_EXTRA)
        return;
    switch (g_game_state.phase) {
    case GAME_PHASE_SERVE_SETUP:
        if (step != HUD_STEP_PROMPT)
            break;
        s_meter_cells = METER_UNDRAWN;
        if (serve_charged())
            hud_center_prompt(BANNER_ROW, HUD_PAL_WHITE,
                SERVE_PROMPT_CHARGED);
        else if (g_input_owners[g_serve_state.server_index] ==
                INPUT_OWNER_HUMAN)
            hud_center_prompt(BANNER_ROW, HUD_PAL_WHITE, "PRESS @ TO SERVE");
        else
            hud_center_prompt(BANNER_ROW, HUD_PAL_WHITE, "CPU TO SERVE");
        break;
    case GAME_PHASE_POINT_RESULT:
        if (step == HUD_STEP_BIG)
            hud_center_big(CENTER_BIG_ROW, HUD_PAL_YELLOW,
                fault_word(g_game_state.last_fault));
        break;
    case GAME_PHASE_MATCH_RESULT:
        if (step == HUD_STEP_BIG)
            hud_center_big(CENTER_BIG_ROW, HUD_PAL_YELLOW,
                hud_match_winner_text());
        break;
    default:
        break;
    }
}

void hud_scene_update(void)
{
    u16 key;

    /* Spread big redraws over frames: a score change and a scene change on
     * the same frame (every point) would overrun 816-tcc's budget, as
     * would a redraw with the renderer's recolour (g_render_busy). */
    u8 busy = g_render_busy;
    u8 idle;

    g_render_busy = 0;
    if (!s_hud_valid)
        hud_draw_scores();
    else if (s_hud_score[0] != g_game_state.team_score[0] ||
             s_hud_score[1] != g_game_state.team_score[1]) {
        hud_draw_score_digits();
        busy = 1;               /* the scene step waits one frame */
    }

    key = hud_scene_key();
    if (!s_hud_valid || key != s_hud_scene) {
        s_prev_scene = s_hud_scene;
        s_hud_scene = key;
        /* Title to title (the prompt blinks, a page opens): only the prompt
         * changes; the logo stays and the area draws itself. One idle step
         * first, so the prompt is not drawn on the frame of the input that
         * changed the page (a recolour or a reload can share it). */
        s_scene_step = (s_hud_valid && HUD_IS_TITLE(key) &&
            HUD_IS_TITLE(s_prev_scene)) ? HUD_STEP_BIG : HUD_STEP_CLEAR;
        /* The pause cursor moved: only the items redraw (no flicker). */
        if (s_hud_valid && HUD_IS_PAUSED(key) && HUD_IS_PAUSED(s_prev_scene))
            s_scene_step = HUD_STEP_EXTRA;
    }
    /* Title steps also wait for a lighter frame (the demo runs behind). */
    idle = 0;
    if (s_scene_step < HUD_STEP_DONE && !busy && HUD_IS_TITLE(key) &&
            hud_title_wait(hud_title_step_limit(s_scene_step))) {
        busy = 1;
    } else if (s_scene_step < HUD_STEP_DONE && !busy) {
        /* The logo steps between two title views draw nothing, so the
         * title area may still draw on their frames (M4-UI-01). */
        idle = HUD_IS_TITLE(key) && HUD_IS_TITLE(s_prev_scene) &&
            (s_scene_step == HUD_STEP_BIG || s_scene_step == HUD_STEP_EXTRA);
        PROFILE_MARK(15);
        hud_scene_step(key, s_scene_step);
        /* The title: CLEAR, BIG, EXTRA (the logo's second row), PROMPT,
         * and a new prompt's text in halves (EXTRA2, EXTRA3). */
        if (HUD_IS_TITLE(key))
            s_scene_step = s_scene_step == HUD_STEP_BIG ? HUD_STEP_EXTRA :
                s_scene_step == HUD_STEP_EXTRA ? HUD_STEP_PROMPT :
                s_scene_step == HUD_STEP_PROMPT ? (s_prompt_text ?
                    HUD_STEP_EXTRA2 : HUD_STEP_DONE) :
                s_scene_step == HUD_STEP_EXTRA3 ? HUD_STEP_DONE :
                s_scene_step + 1;
        else if ((++s_scene_step == HUD_STEP_EXTRA3 &&
                    g_game_state.phase != GAME_PHASE_MATCH_RESULT &&
                    !(g_game_state.phase == GAME_PHASE_POINT_RESULT &&
                      ((g_replay.active && !g_attract) || s_quip))) ||
                (s_scene_step == HUD_STEP_EXTRA5 &&
                    g_game_state.phase == GAME_PHASE_POINT_RESULT))
            s_scene_step = HUD_STEP_DONE;
    } else if (!busy) {
        idle = 1;
    }
    /* Only on otherwise idle frames: keeps each frame to one redraw. */
    if (idle) {
        if (HUD_IS_TITLE(key))
            hud_title_area_update();
        else if (key == HUD_KEY_INITIALS)
            hud_initials_refresh();
        else if (g_game_state.phase == GAME_PHASE_SERVE_SETUP &&
                hud_serve_meter_refresh())
            ;
        else if (hud_sub_panel_wanted() != s_sub_panel)
            hud_draw_sub_panel(hud_sub_panel_wanted());
    }
    s_hud_valid = 1;

#ifdef RENDER_DIAGNOSTICS
    diag_draw_overlay(HUD_IS_PAUSED(key));
#endif
}


void hud_scene_initialize(void)
{
    s_hud_valid = 0;
    s_replay_drawn = 0;
    s_quip = 0;
    s_quip_drawn = 0;
    s_meter_cells = METER_UNDRAWN;
    s_sub_panel = 0;
    s_hud_scene = 0xff;
    s_scene_step = HUD_STEP_DONE;
    s_prev_scene = 0xff;
    s_title_view = HUD_TITLE_UNKNOWN;
    s_title_part = 0;
    s_title_waits = 0;
    s_prompt_page = 0xff;
    s_prompt_text = 0;
    s_title_stale = 0xff;
}
