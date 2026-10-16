#ifndef SAVE_H
#define SAVE_H

#include "game_types.h"
#include "court_colors.h"

/*
 * Battery-backed save RAM (docs/decisions/ADR-021-battery-save.md).
 * The cart has 2 KiB of SRAM holding two copies of SaveData; each write goes
 * to the older copy, so a power cut mid-write loses at most that write.
 */

enum {
    SAVE_SRAM_BYTES = 2048,
    SAVE_COPY_STRIDE = 1024,    /* copy 0 at offset 0, copy 1 at 1024 */
    SAVE_VERSION = 12,          /* 2: settings (ADR-022); 3: venue; 4: options;
                                   5: ladder clears (ADR-026); 6: kitchen;
                                   7: practice (ADR-028); 8: modifiers
                                   (ADR-033); 9: record initials (ADR-040);
                                   10: practice return zones (ADR-028);
                                   11: the court's time (ADR-045);
                                   12: career players (ADR-047).
                                   Shipped: 4 in v0.4.0, 7 in v0.5.0, 8 in
                                   v0.6.0 to v0.12.0, 9 in v0.13.0
                                   (ADR-032). */
    SAVE_INITIALS = 3,          /* letters per record holder (ADR-040) */
    SAVE_COUNTER_MAX = 9999     /* counters saturate; four digits on screen */
};

/* Records against the CPU (2P matches only count toward the longest rally). */
typedef struct {
    u16 wins[2];                /* by MatchMode: singles, doubles */
    u16 losses[2];
    u16 streak;                 /* current win streak, either mode */
    u16 best_streak;
    u16 shutouts;               /* wins without conceding a point */
    u16 longest_rally;          /* shots in one point, serve included */
    u16 ladder_clears;          /* wins over the last ladder opponent */
    u16 practice_best;          /* best practice return streak (ADR-028) */
    u8 practice_zone_best[4];   /* best streak into each return zone:
                                   KITCHEN, DEEP, LEFT LINE, RIGHT LINE */
} SaveRecords;

/* Choices that persist (ADR-022). */
typedef struct {
    u8 court[COURT_PARTS];      /* court colour preset per part; 0 DEFAULT */
    u8 ladder;                  /* next opponent (ADR-023) */
    u8 venue;                   /* COURT_VENUE_AUTO or venue + 1 (ADR-024) */
    u8 points;                  /* points to win (ADR-025) */
    u8 difficulty;              /* Difficulty (ADR-025) */
    u8 practice[4];             /* shot, target, rate, return zone (ADR-028) */
    u8 sound;                   /* AUDIO_* (ADR-029); 0 ALL in older saves */
    u8 modifiers;               /* MODIFIER_* bits (ADR-033) */
    u8 time;                    /* COURT_TIME_* (ADR-045); 0 DAY */
    u8 ball_speed;              /* BALL SPEED choice + 1 (ADR-049); 0, in
                                   saves before it, is the default (100%) */
} SaveSettings;

/* Who holds a record (ADR-040): three capitals, or zeros for nobody yet
 * (the records page shows ---). */
typedef struct {
    u8 best_streak[SAVE_INITIALS];
    u8 longest_rally[SAVE_INITIALS];
} SaveInitials;

/* A career player (ADR-047). Words first and an even size, so the layout is
 * the same on the host and the SNES (816-tcc does not pad). Counters
 * saturate at SAVE_COUNTER_MAX, beaten[] at 255. */
enum {
    CAREER_SLOTS = 3,
    CAREER_NAME = 8,            /* letters, space-padded */
    CAREER_TEAMS = 8,           /* ladder teams (OPPONENT_COUNT, checked) */
    CAREER_NONE = 0xff          /* no active player */
};

typedef struct {
    u16 wins[2];                /* by MatchMode, against the CPU */
    u16 losses[2];
    u16 points_won;
    u16 points_lost;
    u16 aces;                   /* your serves that were not returned */
    u16 shutouts;
    u16 streak;
    u16 best_streak;
    u16 longest_rally;
    u16 ladder_clears;
    u16 open_play;              /* open play games finished */
    u16 unlocked;               /* bit n: career.json's unlock n */
    u8 used;                    /* 0: an empty slot */
    u8 name[CAREER_NAME];
    u8 variant;                 /* PLAYER_VARIANT_* */
    u8 skin;                    /* CAREER_SKINS */
    u8 hair;                    /* CAREER_HAIRS */
    u8 shirt;                   /* PAL_* team colour */
    u8 hat;                     /* HAT id, 0 the cap */
    u8 paddle;                  /* PADDLE_* */
    u8 beaten[CAREER_TEAMS];    /* wins over each ladder team */
    u8 reserved;
} CareerPlayer;

typedef struct {
    u8 magic[4];                /* "PB94" */
    u8 version;                 /* SAVE_VERSION, or a frozen older layout
                                   (migrated); anything else resets */
    u8 sequence;                /* the newer copy has the higher (wrapping) */
    SaveRecords records;
    SaveSettings settings;
    SaveInitials initials;
    CareerPlayer career[CAREER_SLOTS];
    u8 career_active;           /* slot, or CAREER_NONE */
    u8 camera;                  /* CAMERA choice + 1 (ADR-050); 0, in
                                   saves before it, is the default (OFF) */
    u16 checksum;               /* over every byte before it */
} SaveData;

extern SaveData g_save;

/* Records beaten since the holder last entered initials (ADR-040); WRAM
 * only. A beaten record's initials are cleared until they are entered. */
enum { SAVE_NEW_STREAK = 1, SAVE_NEW_RALLY = 2 };
extern u8 g_save_new_records;

/*
 * Frozen layouts of released saves (ADR-032). A valid save in one of these
 * is migrated to SaveData on boot and written back; nothing is lost. When
 * SAVE_VERSION is bumped, the outgoing SaveData is frozen here as
 * SaveV<old version> and gets a migration step in save.c.
 */
enum {
    SAVE_V4 = 4, SAVE_V7 = 7, SAVE_V8 = 8, SAVE_V9 = 9, SAVE_V10 = 10,
    SAVE_V11 = 11
};
/* v0.4.0, v0.5.0, v0.6.0 to v0.12.0, v0.13.0, v0.14.0, v0.15.0 */

typedef struct {
    u8 magic[4];
    u8 version;                 /* 4 */
    u8 sequence;
    u16 wins[2];
    u16 losses[2];
    u16 streak;
    u16 best_streak;
    u16 shutouts;
    u16 longest_rally;
    u8 court[3];                /* surface, surround, lines (no kitchen) */
    u8 ladder;
    u8 venue;
    u8 points;
    u8 difficulty;
    u8 reserved;
    u16 checksum;
} SaveV4;

/* v0.5.0 to v0.9.0: the records before the practice return zones. */
typedef struct {
    u16 wins[2];
    u16 losses[2];
    u16 streak;
    u16 best_streak;
    u16 shutouts;
    u16 longest_rally;
    u16 ladder_clears;
    u16 practice_best;
} SaveRecordsV8;

/* v0.5.0: SaveData before the modifiers. */
typedef struct {
    u8 court[COURT_PARTS];
    u8 ladder;
    u8 venue;
    u8 points;
    u8 difficulty;
    u8 practice[3];
    u8 sound;
} SaveSettingsV7;

typedef struct {
    u8 magic[4];
    u8 version;                 /* 7 */
    u8 sequence;
    SaveRecordsV8 records;
    SaveSettingsV7 settings;
    u16 checksum;
} SaveV7;

/* v0.6.0 to v0.13.0: the settings before the practice return zones. */
typedef struct {
    u8 court[COURT_PARTS];
    u8 ladder;
    u8 venue;
    u8 points;
    u8 difficulty;
    u8 practice[3];
    u8 sound;
    u8 modifiers;
    u8 reserved;
} SaveSettingsV8;

/* v0.6.0 to v0.12.0: SaveData before the initials and the return zones. */
typedef struct {
    u8 magic[4];
    u8 version;                 /* 8 */
    u8 sequence;
    SaveRecordsV8 records;
    SaveSettingsV8 settings;
    u16 checksum;
} SaveV8;

/* v0.13.0: SaveData with the initials, before the return zones. */
typedef struct {
    u8 magic[4];
    u8 version;                 /* 9 */
    u8 sequence;
    SaveRecordsV8 records;
    SaveSettingsV8 settings;
    SaveInitials initials;
    u16 checksum;
} SaveV9;

/* v0.14.0: the settings before the court's time. */
typedef struct {
    u8 court[COURT_PARTS];
    u8 ladder;
    u8 venue;
    u8 points;
    u8 difficulty;
    u8 practice[4];
    u8 sound;
    u8 modifiers;
} SaveSettingsV10;

/* v0.14.0: SaveData before the court's time. */
typedef struct {
    u8 magic[4];
    u8 version;                 /* 10 */
    u8 sequence;
    SaveRecords records;
    SaveSettingsV10 settings;
    SaveInitials initials;
    u16 checksum;
} SaveV10;

/* v0.15.0: SaveData before the career players. */
typedef struct {
    u8 magic[4];
    u8 version;                 /* 11 */
    u8 sequence;
    SaveRecords records;
    SaveSettings settings;
    SaveInitials initials;
    u16 checksum;
} SaveV11;

/* Loads the newer valid copy, or formats SRAM with defaults when neither
 * copy is valid (blank cart, corruption, older layout). */
void save_initialize(void);
/* Writes g_save to the older copy. Call only at safe points. */
void save_write(void);
/* Back to defaults and written to both copies. */
void save_clear(void);
/* Zeroes the records and their initials (settings stay) and writes. */
void save_clear_records(void);
/* The holder's initials for every record in g_save_new_records, which
 * clears; writes. */
void save_set_initials(const u8 *letters);

/* A finished human match. vs_cpu: the opponents were all CPU (1P is always
 * on team 0). Updates the records and writes. */
void save_record_match(u8 mode, u8 vs_cpu, u8 won, u8 points_against);
/* A win over a ladder opponent: the next one is up (after the last, the
 * first again, and a ladder clear is recorded). Written with the match. */
void save_advance_ladder(void);
/* A finished point with this many shots; written with the match. */
void save_record_rally(u8 shots);

/* Validation, exposed for the host tests. */
u16 save_checksum(const SaveData *data);
u8 save_valid(const SaveData *data);
/* The checksum over any layout's bytes before its checksum field. */
u16 save_checksum_bytes(const u8 *bytes, u16 count);

#ifdef HOST_TEST
/* Stand-in for the cartridge SRAM. */
extern u8 g_host_sram[SAVE_SRAM_BYTES];
#endif

#endif
