# The Announcer: additions to record

The second batch: **19 lines**, the same voice and settings as the first
(`SCRIPT.md`, whose recording spec holds here too). `additions.csv` has
one row per file. Put the recordings in `audio/announcer/raw/` beside the
first batch; the game already asks for these and uses each once it's
there (until then it says what it said before).

Score calls need nothing new: the numbers were recorded from zero to
twenty-five, rising and falling, so any game to 11, 15 or 21 is
covered (a game past 25-all is called by the score on the board).

## Win by two

*With WIN BY 2 on, past game point: one side a point up (advantage) or level again (deuce). Rally scoring: the side that won the point serves, so it's mostly the server's advantage.*

| id | line | delivery | max s |
|---|---|---|---|
| `advantage_server_1` | Advantage, serving side! | Big, booming 1994 TV sports energy. | 1.8 |
| `advantage_server_2` | Advantage to the server! | Big, booming 1994 TV sports energy. | 1.8 |
| `advantage_receiver_1` | Advantage, receiving side! | Big, booming 1994 TV sports energy. | 1.8 |
| `advantage_receiver_2` | Advantage to the receiver! | Big, booming 1994 TV sports energy. | 1.8 |
| `deuce_1` | Deuce! | Clear and even, like an umpire calling it. | 1.0 |
| `deuce_2` | Deuce! All square again! | Big, booming 1994 TV sports energy. | 1.8 |
| `deuce_3` | Back to even! | Big, booming 1994 TV sports energy. | 1.2 |
| `deuce_long` | We could be here all night, folks! | Dry, playful, a little deadpan; let the pun land. | 2.5 |

## The gym

*As a match at THE GYM (the indoor venue, ADR-078) begins.*

| id | line | delivery | max s |
|---|---|---|---|
| `venue_gym_1` | Welcome to the gym! The lights are bright and the floor is squeaky. | Warm, friendly, a smile in the voice. | 4.0 |
| `venue_gym_2` | We're indoors today, folks. No wind, no excuses! | Dry, playful, a little deadpan; let the pun land. | 3.0 |

## Achievements

*As an achievement unlocks (after the match's result): its own line if it has one, else a general one.*

| id | line | delivery | max s |
|---|---|---|---|
| `achievement_1` | Achievement unlocked! | Big, booming 1994 TV sports energy. | 1.5 |
| `achievement_2` | That's one for the trophy case! | Big, booming 1994 TV sports energy. | 2.0 |
| `achievement_pickled` | Pickled! They didn't score a single point! | Big, booming 1994 TV sports energy. | 3.0 |
| `achievement_first_win` | The first win of many! | Warm, friendly, a smile in the voice. | 2.0 |
| `achievement_ladder` | Top of the ladder! | Big, booming 1994 TV sports energy. | 1.5 |
| `achievement_champion` | Champion of the tournament! | Big, booming 1994 TV sports energy. | 2.0 |
| `achievement_cover_man` | They beat the man on the box! | Big, booming 1994 TV sports energy. | 2.2 |
| `achievement_globetrotter` | Six venues, six wins. A true globetrotter! | Big, booming 1994 TV sports energy. | 3.0 |
| `achievement_scholar` | Class dismissed! They know the real game now. | Warm, friendly, a smile in the voice. | 3.0 |
