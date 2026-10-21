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
        ("achievement_globetrotter", "Six venues, six wins. A true globetrotter!", HYPE, 3.0),
        ("achievement_scholar", "Class dismissed! They know the real game now.", WARM, 3.0),
    ]),
]

out = sys.argv[1]
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
      "first batch; the game already asks for these and uses each once it's",
      "there (until then it says what it said before).\n",
      "Score calls need nothing new: the numbers were recorded from zero to",
      "twenty-five, rising and falling, so any game to 11, 15 or 21 is",
      "covered (a game past 25-all is called by the score on the board).\n"]
for name, when, lines in G:
    md += ["## %s\n" % name, "*%s*\n" % when, "| id | line | delivery | max s |", "|---|---|---|---|"]
    md += ["| `%s` | %s | %s | %s |" % (i, t, d, s) for (i, t, d, s) in lines]
    md.append("")
open(os.path.join(out, "ADDITIONS.md"), "w").write("\n".join(md))
print(len(rows), "lines")
