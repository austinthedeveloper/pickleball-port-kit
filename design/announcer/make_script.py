"""The complete announcer script: core lines plus make_additions.py, minus
removed.txt. Writes SCRIPT.md and lines.csv for a full recording batch.
Run: python3 design/announcer/make_script.py design/announcer"""
import csv, fnmatch, sys, os

from make_additions import G as ADDITION_GROUPS

# Delivery shorthands
HYPE = "Big, booming 1994 TV sports energy."
FAST = "Quick and punchy, one breath. Under a second."
WARM = "Warm, friendly, a smile in the voice."
WRY = "Dry, playful, a little deadpan; let the pun land."
CALM = "Clear and even, like an umpire calling it."
HUSH = "Hushed, leaning into the mic, building tension."
SAD = "Sympathetic, a gentle 'ohh' feel, not mocking."

# (group, intro, [(id, text, delivery, max_seconds)])
G = []

def group(name, when, lines):
    G.append((name, when, lines))

group("Title and attract", "On the title screen (the logo appearing) and over the demo.", [
    ("title_logo_1", "Pickleball Ninety-Four!", HYPE, 2),
    ("title_logo_2", "It's Pickleball Ninety-Four!", HYPE, 2),
    ("title_press_start", "Grab a paddle and press start!", WARM, 2),
    ("demo_1", "Welcome back to Riverdale Park, where the dinks are soft and the stakes are high.", WARM, 5),
    ("demo_2", "Pull up a lawn chair, folks. We've got pickleball.", WARM, 4),
])

group("Match start: venues", "As a match begins, once, for its venue.", [
    ("venue_park_1", "Good afternoon, and welcome to Riverdale Park!", HYPE, 3),
    ("venue_park_2", "A beautiful day for pickleball here at Riverdale Park.", WARM, 4),
    ("venue_lakeside_1", "We're coming to you live from the lakeside courts!", HYPE, 3),
    ("venue_lakeside_2", "Lakeside today. Watch out for the geese, folks.", WRY, 3),
    ("venue_sunset_1", "Live from the sunset courts, where the light is golden and so is the play!", HYPE, 4),
    ("venue_sunset_2", "The sun is setting, and the pickleball is just getting started.", WARM, 4),
    ("venue_dinosaur_1", "Welcome to the dinosaur courts! Mind the T. rex.", HYPE, 3),
    ("venue_dinosaur_2", "Pickleball in the age of the dinosaurs. Prehistoric!", WRY, 4),
    ("venue_space_1", "Coming to you from outer space! In space, no one can hear you dink.", WRY, 5),
    ("venue_space_2", "Zero gravity? Not quite. But it's out of this world!", HYPE, 4),
    ("venue_undersea_1", "We're live from the bottom of the sea! Hold your breath, folks!", HYPE, 4),
    ("venue_undersea_2", "Undersea pickleball. The fish have the best seats in the house.", WRY, 4),
    ("time_night", "Under the lights tonight!", HYPE, 2),
    ("time_dusk", "The lights are coming on. What an evening for it.", WARM, 3),
])

group("Match start", "As a match begins, after the venue.", [
    ("team_henderson", "Here come the Hendersons, Dad and Kiddo! Dad jokes incoming!", WARM, 4),
    ("team_snowbirds", "Marge and Walt, the Snowbirds! They say they've played since 1962. Pickleball was invented in 1965. Hmm.", WRY, 6),
    ("team_gym_bros", "Here come the Gym Bros, Brad and Chad! Do they even dink?", WRY, 4),
    ("team_pirates", "Ahoy! Pete and Bilge, the Pirates! Prepare to be boarded!", HYPE, 4),
    ("team_goth_club", "The Goth Club, Raven and Vlad. They are not excited. They are never excited.", WRY, 5),
    ("team_surf_crew", "Cowabunga! It's Kai and Lani, the Surf Crew!", HYPE, 3),
    ("team_twins", "It's the Twins, Max and Mia! Double trouble, folks.", HYPE, 3.5),
    ("team_champs", "Ladies and gentlemen, the reigning Champs, Ace and Jade!", HYPE, 4),
    ("team_dawson", "Ladies and gentlemen, the man on the box himself: Dale Dink Dawson!", HYPE, 5),
    ("match_begin_1", "Let's play some pickleball!", HYPE, 2),
    ("match_begin_2", "Here we go!", HYPE, 1.5),
    ("match_begin_3", "Players ready. Let's get it on!", HYPE, 2.5),
    ("match_doubles", "It's doubles today, two on two!", HYPE, 2.5),
    ("match_singles", "Singles! One on one. Nowhere to hide.", HYPE, 3),
])

group("Match start: modifiers", "As a match begins with this modifier on (the first one, if several).", [
    ("mod_big_ball", "Big ball today, folks! Very big. Enormous, really.", WRY, 4),
    ("mod_fast_ball", "Fast ball! Blink and you'll miss it.", HYPE, 3),
    ("mod_ghost_ball", "Ghost ball! Now you see it, now you don't.", HUSH, 3),
    ("mod_popcorn", "Popcorn rules! The longer the rally, the faster it pops.", HYPE, 4),
    ("mod_ice", "The court is ice today! Careful out there.", HYPE, 3),
    ("mod_glow", "Lights out! Glow in the dark pickleball!", HYPE, 3),
    ("mod_inverse", "Something's off with the picture, folks. That's on purpose.", WRY, 4),
    ("mod_moon", "Moon gravity! These shots are going to hang.", HYPE, 3),
    ("mod_bouncy", "Bouncy ball! Boing!", WRY, 2),
    ("mod_wind", "It's blowing out there today. Watch that wind!", HYPE, 3),
    ("mod_win_by_2", "Remember, you've got to win by two.", CALM, 3),
    ("mod_lava", "The floor is lava! I'm not kidding, it is actually lava.", WRY, 4),
    ("mod_side_out", "Traditional scoring today. Only the server scores!", CALM, 3),
    ("mod_momentum", "Momentum rules are in effect. Watch those feet after a volley.", CALM, 4),
    ("mod_dink_or_die", "Dink or die! No drives allowed!", HYPE, 2.5),
    ("mod_sudden_death", "Sudden death! One point takes it all!", HYPE, 3),
    ("mod_multi_ball", "Multi ball! Balls everywhere!", HYPE, 2.5),
])

group("The serve", "At a serve: now and then, not every one. Score calls come before these.", [
    ("serve_1", "Here's the serve.", CALM, 1.5),
    ("serve_2", "Serving now.", CALM, 1.2),
    ("serve_3", "And the serve.", CALM, 1.2),
    ("serve_deep", "Deep serve!", FAST, 1),
    ("serve_quiet", "Quiet, please.", HUSH, 1.5),
    ("ace_1", "Ace!", FAST, 1),
    ("ace_2", "Ace! Didn't touch it!", HYPE, 1.5),
    ("ace_3", "Untouchable!", HYPE, 1.2),
    ("ace_4", "Service winner! Right on the line!", HYPE, 2),
    ("ace_5", "That serve had a return address. Nobody was home.", WRY, 3),
    ("serve_fault_1", "Fault on the serve.", CALM, 1.5),
    ("serve_fault_2", "Wrong service box!", CALM, 1.5),
    ("serve_fault_3", "That serve's in the kitchen. Fault!", CALM, 2),
])

group("Score calls", "Built from pieces: two numbers for rally scoring (rising, then falling: \"four... two\"), three for side-out (\"four, two, one\"), and \"all\" for a tie (\"five all\"). Record every number twice, once rising (as if more is coming) and once falling (the end of the call).", [])
NUMS = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
        "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen",
        "Nineteen", "Twenty", "Twenty-one", "Twenty-two", "Twenty-three", "Twenty-four", "Twenty-five"]
score = []
for i, n in enumerate(NUMS):
    score.append(("num_%02d_up" % i, n, "Rising, like a list that continues. Clean, no breath.", 0.8))
    score.append(("num_%02d_down" % i, n, "Falling, the end of the call. Clean, no breath.", 0.8))
score += [
    ("score_all", "All.", "Falling, ends the call (\"five ALL\").", 0.6),
    ("score_love", "Love.", "Falling. A wink: pickleball says zero.", 0.6),
    ("score_server_1", "First server.", CALM, 1.2),
    ("score_server_2", "Second server.", CALM, 1.2),
    ("side_out_1", "Side out!", CALM, 1),
    ("side_out_2", "Side out. Change of serve.", CALM, 1.8),
    ("side_out_3", "And that's a side out.", CALM, 1.5),
]
G[-1] = (G[-1][0], G[-1][1], score)

group("In the rally: shots", "During a rally, on a hit: rarely (about one hit in four at most, never two in a row), so it never chatters.", [
    ("shot_dink_1", "Dink!", FAST, 0.6),
    ("shot_dink_2", "Soft hands!", FAST, 0.8),
    ("shot_dink_3", "Just over!", FAST, 0.7),
    ("shot_drive_1", "Drive!", FAST, 0.6),
    ("shot_drive_2", "Rips it!", FAST, 0.7),
    ("shot_drive_3", "Pow!", FAST, 0.5),
    ("shot_lob_1", "Lob!", FAST, 0.6),
    ("shot_lob_2", "Up and over!", FAST, 0.8),
    ("shot_slice_1", "Slice!", FAST, 0.6),
    ("shot_slice_2", "Nasty spin!", FAST, 0.8),
    ("shot_smash_1", "Smash!", FAST, 0.6),
    ("shot_smash_2", "Overhead!", FAST, 0.7),
    ("shot_smash_3", "Puts it away!", FAST, 0.9),
    ("shot_volley_1", "Volley!", FAST, 0.6),
    ("shot_volley_2", "Off the bounce? No, out of the air!", FAST, 1.5),
    ("shot_get_1", "What a get!", FAST, 0.8),
    ("shot_get_2", "Gets there!", FAST, 0.7),
    ("shot_get_3", "Diving save!", FAST, 0.8),
    ("shot_net_cord", "Off the tape!", FAST, 0.8),
])

group("In the rally: long rallies", "As a rally reaches 10 shots (the ball catches fire), 15 (the focus), 20, 25 and 30, once each.", [
    ("rally_10_1", "Ten shots!", HYPE, 1),
    ("rally_10_2", "This rally is heating up!", HYPE, 1.5),
    ("rally_10_3", "Ten and counting!", HYPE, 1.2),
    ("rally_15_1", "Fifteen! They're on fire!", HYPE, 1.5),
    ("rally_15_2", "Nobody wants to miss!", HYPE, 1.5),
    ("rally_20_1", "Twenty shots! Unbelievable!", HYPE, 1.8),
    ("rally_20_2", "Somebody get these players a glass of water!", WRY, 2.5),
    ("rally_25", "Twenty-five! I've never seen anything like it!", HYPE, 2.5),
    ("rally_30_1", "Thirty! This is the rally of the century!", HYPE, 2.5),
    ("rally_30_2", "Folks, I may need to sit down.", WRY, 2),
])

group("The point: how it ended", "After a point, by its fault (the HUD's fault word). Short: the score call often follows.", [
    ("out_1", "Out!", CALM, 0.6),
    ("out_2", "Long!", CALM, 0.6),
    ("out_3", "Just wide.", CALM, 1),
    ("out_4", "That one had a passport. Way out.", WRY, 2.5),
    ("out_close_1", "Ooh, just out!", SAD, 1.2),
    ("out_close_2", "By a whisker!", SAD, 1),
    ("net_1", "Into the net.", CALM, 1),
    ("net_2", "Net!", CALM, 0.6),
    ("net_3", "The net says no.", WRY, 1.5),
    ("kitchen_1", "Kitchen violation!", CALM, 1.2),
    ("kitchen_2", "Foot in the kitchen!", CALM, 1.2),
    ("kitchen_3", "You can't volley from the kitchen! Kitchen's closed!", WRY, 2.5),
    ("early_volley_1", "Let it bounce! Two-bounce rule!", CALM, 2),
    ("early_volley_2", "Too eager! That one had to bounce.", WRY, 2),
    ("two_bounces_1", "Couldn't get there.", SAD, 1.2),
    ("two_bounces_2", "Two bounces!", CALM, 1),
    ("two_bounces_3", "Nobody home!", WRY, 1),
    ("wrong_box", "Wrong box!", CALM, 1),
    ("lava_1", "Into the lava!", HYPE, 1),
    ("lava_2", "Ouch! Hot hot hot!", WRY, 1.5),
    ("momentum_1", "Momentum carried them into the kitchen!", CALM, 2),
    ("momentum_2", "Couldn't stop! Fault!", CALM, 1.5),
    ("drive_banned_1", "A drive? Not today! Dink or die!", WRY, 2),
    ("drive_banned_2", "That's a drive. Rules are rules!", WRY, 2),
    ("winner_1", "Winner!", HYPE, 0.8),
    ("winner_2", "Right on the line!", HYPE, 1.2),
    ("winner_3", "No chance on that one!", HYPE, 1.5),
    ("winner_4", "Put it where they ain't!", WRY, 1.5),
])

group("Between points: the match", "After a point, by the match's state: a streak, a comeback, match point. Plays instead of the fault line, now and then.", [
    ("streak_3_1", "Three in a row!", HYPE, 1.2),
    ("streak_3_2", "They're rolling now!", HYPE, 1.3),
    ("streak_5_1", "Five straight! Somebody stop them!", HYPE, 2),
    ("streak_5_2", "Is anybody going to slow this down?", WRY, 2),
    ("comeback_1", "We are all tied up!", HYPE, 1.5),
    ("comeback_2", "What a comeback!", HYPE, 1.2),
    ("comeback_3", "Never count them out!", HYPE, 1.3),
    ("shutout_watch", "Still looking for that first point.", SAD, 2),
    ("close_game", "This is a close one, folks.", HUSH, 1.8),
    ("game_point", "Game point.", HUSH, 1.2),
    ("match_point_1", "Match point!", HUSH, 1.2),
    ("match_point_2", "One point away!", HUSH, 1.2),
    ("match_point_saved", "Match point saved!", HYPE, 1.5),
    ("win_by_2_1", "Got to win by two!", CALM, 1.3),
    ("win_by_2_2", "And we keep going!", HYPE, 1.2),
    ("sudden_death", "Sudden death! Next point wins it all!", HUSH, 2.5),
])

group("Pickle puns and quips", "Now and then between points, when nothing else is said; at most one every few points.", [
    ("quip_1", "That's a big dill!", WRY, 1.2),
    ("quip_2", "They're in a real pickle now.", WRY, 1.5),
    ("quip_3", "Relish the moment, folks.", WRY, 1.5),
    ("quip_4", "Kitchen's open for business!", WRY, 1.5),
    ("quip_5", "Brine time!", WRY, 1),
    ("quip_6", "No dinking around out there.", WRY, 1.5),
    ("quip_7", "Somebody call the sweet and sour police!", WRY, 2),
    ("quip_8", "That's what I call a dill-ightful point.", WRY, 2),
    ("quip_9", "Pickle power!", HYPE, 1),
    ("quip_10", "You can't teach that. Well, you can. But you can't teach that.", WRY, 3),
    ("quip_11", "My grandmother plays like that. That's a compliment. She's very good.", WRY, 4),
    ("quip_12", "Totally radical!", HYPE, 1.2),
    ("quip_13", "Excellent!", HYPE, 0.8),
    ("quip_14", "Booyah!", HYPE, 0.8),
    ("quip_15", "Is it hot out here, or is it just this rally?", WRY, 2.5),
    ("quip_16", "I've seen softer hands on a pillow.", WRY, 2),
    ("quip_17", "That ball is going home in a jar.", WRY, 2),
    ("quip_18", "Somebody get that paddle a raise.", WRY, 2),
    ("quip_19", "Paddle up, folks!", HYPE, 1.2),
    ("quip_20", "And the crowd goes mild!", WRY, 1.5),
])

group("Pause, close calls and replays", "On the pause menu, the close-call replay (ADR-041) and PLAY OF THE MATCH (ADR-075).", [
    ("pause_1", "Timeout on the court.", CALM, 1.5),
    ("pause_2", "Don't touch that dial!", WRY, 1.5),
    ("resume_1", "And we're back!", HYPE, 1),
    ("resume_2", "Back to the action!", HYPE, 1.2),
    ("close_call_1", "Ooh, was that out? Let's take a look.", HUSH, 2.5),
    ("close_call_2", "Close call! Let's go to the replay.", HUSH, 2),
    ("close_call_3", "Out by a hair!", SAD, 1.2),
    ("potm_1", "And now, the play of the match!", HYPE, 2),
    ("potm_2", "Let's look at that one again.", WARM, 1.8),
    ("potm_3", "Roll the tape!", HYPE, 1),
    ("potm_end_1", "Just beautiful.", WARM, 1.2),
    ("potm_end_2", "They'll be talking about that one for weeks.", WARM, 2.5),
])

group("Match over", "When a match ends: who won, and how. The player's win gets the loud ones.", [
    ("match_win_1", "And that's the match!", HYPE, 1.5),
    ("match_win_2", "Game, set, and pickle!", WRY, 1.8),
    ("match_win_3", "What a performance!", HYPE, 1.5),
    ("match_win_4", "Victory at Riverdale!", HYPE, 1.5),
    ("match_win_shutout", "A shutout! Didn't give up a single point!", HYPE, 2.5),
    ("match_win_close", "Oh, what a finish! That was too close to call!", HYPE, 2.5),
    ("match_loss_1", "Tough break. They'll get them next time.", SAD, 2.5),
    ("match_loss_2", "Not today. But what a fight.", SAD, 2),
    ("match_loss_3", "Shake it off. Rematch?", WARM, 1.8),
    ("handshake", "Paddle taps at the net. That's pickleball.", WARM, 2.5),
    ("new_record_1", "A new record!", HYPE, 1.2),
    ("new_record_2", "That one's going in the record books!", HYPE, 2),
    ("rematch", "They're going again! Rematch!", HYPE, 1.8),
])

group("Ladder, tournament and story", "Around the ladder, the bracket (and the couch cup) and STORY mode.", [
    ("ladder_next", "On to the next challenger!", HYPE, 1.8),
    ("ladder_cleared", "They've beaten the whole ladder! Unbelievable!", HYPE, 2.5),
    ("cup_quarter", "The quarterfinals!", HYPE, 1.2),
    ("cup_semi", "The semifinals! Two wins from glory!", HYPE, 2),
    ("cup_final", "This is it. The final!", HUSH, 1.8),
    ("cup_champion", "Your champions!", HYPE, 1.2),
    ("story_stakes_1", "The park is on the line today, folks.", HUSH, 2.5),
    ("story_stakes_2", "Another signature for the petition!", HYPE, 2),
    ("story_saved", "They did it! Riverdale Park is saved!", HYPE, 2.5),
    ("story_grimsby", "Somewhere, Mr. Grimsby is not happy.", WRY, 2),
    ("open_play_1", "Next up on court two!", CALM, 1.5),
    ("open_play_2", "Winners stay on!", HYPE, 1.2),
    ("multi_ball_new", "Another ball!", FAST, 0.8),
])

out = sys.argv[1]

# The additions generator remains the source for the second batch, while this
# generator produces the complete list needed for a full recording run.
G.extend(ADDITION_GROUPS)

removed_path = os.path.join(os.path.dirname(__file__), "removed.txt")
removed_patterns = []
with open(removed_path) as f:
    for line in f:
        pattern = line.split("#", 1)[0].strip()
        if pattern:
            removed_patterns.append(pattern)

G = [
    (name, when, [
        line for line in lines
        if not any(fnmatch.fnmatchcase(line[0], pattern) for pattern in removed_patterns)
    ])
    for name, when, lines in G
]
G = [(name, when, lines) for name, when, lines in G if lines]

os.makedirs(out, exist_ok=True)
rows = []
for name, when, lines in G:
    for (i, t, d, s) in lines:
        rows.append((i, name, t, d, s))
ids = [r[0] for r in rows]
assert len(ids) == len(set(ids)), "duplicate id"
with open(os.path.join(out, "lines.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["id", "file", "text", "delivery", "max_seconds", "group"])
    for (i, name, t, d, s) in rows:
        w.writerow([i, i + ".wav", t, d, s, name])
md = []
md.append("# The Announcer: script for the voiceover\n")
md.append("A 1994 TV sports announcer for Pickleball '94: big and warm, a little")
md.append("cheesy, never mean, family friendly. One voice for every line. The")
md.append("game plays these between points and, briefly, during rallies, under")
md.append("its own crowd and music, and never two at once. **%d lines**; the same" % len(rows))
md.append("list is `lines.csv` (one row per file, for batching).\n")
md.append("Remaster-only (the canon bible has no announcer): see the roadmap's")
md.append("For you.\n")
md.append("## For the recording\n")
md.append("- **One file per line**, named by its id: `ace_1.wav`. All in one folder.")
md.append("- **WAV, 48 kHz (or 44.1), 16-bit, mono.** No music, crowd or effects in")
md.append("  them; the game adds its own.")
md.append("- **Trim the silence**: start within 50 ms of the first sound, end within")
md.append("  100 ms of the last. The game times them.")
md.append("- **Even loudness**: about -16 LUFS each, peaks under -1 dBFS, so no line")
md.append("  jumps out.")
md.append("- **The same voice and settings for every line**, the numbers above all:")
md.append("  the score calls are built from them, so they must sound like one call.")
md.append("- **Mind the length**: each line has a most-seconds; the rally lines")
md.append("  especially, which have to land between shots.")
md.append("- The text is written as it should be said (\"Twenty-one\", \"Pickleball")
md.append("  Ninety-Four\"). If a word comes out wrong, respell it, and keep the id.")
md.append("- Variants (`_1`, `_2`, ...) are alternatives the game picks between, so")
md.append("  they should differ a little in delivery too.\n")
for name, when, lines in G:
    md.append("## %s\n" % name)
    md.append("*%s*\n" % when)
    md.append("| id | line | delivery | max s |")
    md.append("|---|---|---|---|")
    for (i, t, d, s) in lines:
        md.append("| `%s` | %s | %s | %s |" % (i, t.replace("|", "/"), d, s))
    md.append("")
open(os.path.join(out, "SCRIPT.md"), "w").write("\n".join(md))
print(len(rows), "lines in", len(G), "groups")
