"""The announcer's second batch (PORT-55): lines for things added since
the first script, and the user's asks. One source, two outputs, like
make_script.py: ADDITIONS.md to read, additions.csv for the voiceover.
Run: python3 design/announcer/make_additions.py design/announcer"""
import csv, os, sys

HYPE = "Big, booming 1994 TV sports energy."
CALM = "Clear and even, like an umpire calling it."
WARM = "Warm, friendly, a smile in the voice."
WRY = "Dry, playful, a little deadpan; let the pun land."

G = [
    ("Win by two", "With WIN BY 2 on, past game point: one side a point up (advantage) "
     "or level again (deuce). Rally scoring: the side that won the point serves, so it's "
     "mostly the server's advantage.", [
        ("advantage_server_1", "Advantage, serving side!", HYPE, 1.8),
        ("advantage_server_2", "Advantage to the server!", HYPE, 1.8),
        ("advantage_receiver_1", "Advantage, receiving side!", HYPE, 1.8),
        ("advantage_receiver_2", "Advantage to the receiver!", HYPE, 1.8),
        ("deuce_1", "Deuce!", CALM, 1.0),
        ("deuce_2", "Deuce! All square again!", HYPE, 1.8),
        ("deuce_3", "Back to even!", HYPE, 1.2),
        ("deuce_long", "We could be here all night, folks!", WRY, 2.5),
    ]),
    ("The gym", "As a match at THE GYM (the indoor venue, ADR-078) begins.", [
        ("venue_gym_1", "Welcome to the gym! The lights are bright and the floor is squeaky.", WARM, 4.0),
        ("venue_gym_2", "We're indoors today, folks. No wind, no excuses!", WRY, 3.0),
    ]),
    ("Achievements", "As an achievement unlocks (after the match's result): its own line "
     "if it has one, else a general one.", [
        ("achievement_1", "Achievement unlocked!", HYPE, 1.5),
        ("achievement_2", "That's one for the trophy case!", HYPE, 2.0),
        ("achievement_pickled", "Pickled! They didn't score a single point!", HYPE, 3.0),
        ("achievement_first_win", "The first win of many!", WARM, 2.0),
        ("achievement_ladder", "Top of the ladder!", HYPE, 1.5),
        ("achievement_champion", "Champion of the tournament!", HYPE, 2.0),
        ("achievement_cover_man", "They beat the man on the box!", HYPE, 2.2),
        ("achievement_globetrotter", "A win at every venue! A true globetrotter!", HYPE, 3.0),
        ("achievement_scholar", "Class dismissed! They know the real game now.", WARM, 3.0),
        ("achievement_ace", "An ace for the record books!", HYPE, 2.2),
        ("achievement_marathon", "Twenty shots! That's a marathon!", HYPE, 2.2),
        ("achievement_on_fire", "Thirty shots! They're on fire!", HYPE, 2.2),
        ("achievement_comeback", "Down five and came back! The comeback kid!", HYPE, 3.0),
        ("achievement_mad_scientist", "Three modifiers at once? That's mad science!", WRY, 2.8),
        ("achievement_park_saved", "The park is saved! Riverdale thanks you!", WARM, 2.8),
    ]),
    ("Specials", "With SPECIALS on (ADR-080): the match's introduction, a player's meter "
     "filling up, PICKLE SMASH itself, its return popping up (the knock-back), and a smash "
     "that wins the point or sets up the side's next shot to win it.", [
        ("mod_specials_1", "Specials are on! Keep an eye on those meters!", HYPE, 3.0),
        ("mod_specials_2", "Specials today, folks. Somebody's getting smashed!", WRY, 3.0),
        ("special_ready_1", "The meter's full!", HYPE, 1.5),
        ("special_ready_2", "Special's ready!", HYPE, 1.5),
        ("special_ready_3", "They're all charged up!", HYPE, 1.8),
        ("pickle_smash_1", "Pickle smash!", HYPE, 1.2),
        ("pickle_smash_2", "Pickle... SMASH!", HYPE, 1.6),
        ("pickle_smash_3", "Kaboom! Pickle smash!", HYPE, 1.8),
        ("pickle_smash_4", "They're in a pickle now!", WRY, 1.8),
        ("smash_return_1", "They got a paddle on it!", HYPE, 1.5),
        ("smash_return_2", "Just barely!", HYPE, 1.0),
        ("smash_return_3", "That one rattled the paddle!", WRY, 1.8),
        ("smash_winner_1", "Untouchable!", HYPE, 1.0),
        ("smash_winner_2", "Nobody's getting that one!", HYPE, 1.8),
        ("smash_winner_3", "Smashed to bits!", WRY, 1.5),
        ("smash_finish_1", "Set it up and knock it down!", HYPE, 2.0),
        ("smash_finish_2", "And they finish the job!", HYPE, 1.8),
    ]),
    ("Power-ups (for later)", "Not in the game yet: the power-ups in "
     "design/SPECIALS_AND_POWERUPS.md (route B). Recording them now saves a session later; "
     "the game will use them when power-ups are built.", [
        ("powerup_appear_1", "Power-up on the court!", HYPE, 1.8),
        ("powerup_appear_2", "Ooh, what's that?", WRY, 1.2),
        ("powerup_grab_1", "Got it!", HYPE, 0.8),
        ("powerup_grab_2", "Snagged it!", HYPE, 1.0),
        ("powerup_big_paddle", "Big paddle!", HYPE, 1.2),
        ("powerup_sneakers", "Speed shoes!", HYPE, 1.2),
        ("powerup_ice_patch", "Slippery out there!", WRY, 1.5),
        ("powerup_slow_mo", "Slow... motion!", WRY, 1.8),
        ("powerup_magnet", "Magnet ball!", HYPE, 1.2),
        ("powerup_golden_ball", "Golden ball! This one's worth two!", HYPE, 2.5),
        ("powerup_banana", "Watch your step!", WRY, 1.2),
        ("powerup_pickle_jar", "Pickle jar! Smash time!", HYPE, 1.8),
    ]),
]

def write_outputs(out):
    """Write the standalone additions list and recording notes."""
    rows = [(i, name, t, d, s) for name, when, lines in G for (i, t, d, s) in lines]
    assert len({r[0] for r in rows}) == len(rows), "duplicate id"
    with open(os.path.join(out, "additions.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "file", "text", "delivery", "max_seconds", "group"])
        for (i, name, t, d, s) in rows:
            w.writerow([i, i + ".wav", t, d, s, name])
    md = ["# The Announcer: additions to record\n",
          "The second batch: **%d lines**, the same voice and settings as the first" % len(rows),
          "(`SCRIPT.md`, whose recording spec holds here too). `additions.csv` has",
          "one row per file. Put the recordings in `audio/announcer/raw/` beside the",
          "first batch; the game already asks for these (all but the power-ups, which",
          "aren't built yet) and uses each once it's there (until then it says what",
          "it said before).\n",
          "Re-recording everything: `SCRIPT.md` is the first batch. Leave out the",
          "lines in `removed.txt` (the team intros, `team_*`).\n",
          "Score calls need nothing new: the numbers were recorded from zero to",
          "twenty-five, rising and falling, so any game to 11, 15 or 21 is",
          "covered (a game past 25-all is called by the score on the board).\n"]
    for name, when, lines in G:
        md += ["## %s\n" % name, "*%s*\n" % when, "| id | line | delivery | max s |", "|---|---|---|---|"]
        md += ["| `%s` | %s | %s | %s |" % (i, t, d, s) for (i, t, d, s) in lines]
        md.append("")
    open(os.path.join(out, "ADDITIONS.md"), "w").write("\n".join(md))
    print(len(rows), "lines")


if __name__ == "__main__":
    write_outputs(sys.argv[1])
