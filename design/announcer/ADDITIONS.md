# The Announcer: additions to record

The second batch: **76 lines**, the same voice and settings as the first
(`SCRIPT.md`, whose recording spec holds here too). `additions.csv` has
one row per file. Put the recordings in `audio/announcer/raw/` beside the
first batch; the game already asks for these (all but the power-ups, which
aren't built yet) and uses each once it's there (until then it says what
it said before).

Re-recording everything: `SCRIPT.md` is the first batch. Leave out the
lines in `removed.txt` (the team intros, `team_*`).

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

## The dinosaur game's levels

*As a match at RUINS, GLACIER, LAB or STATION (the venues from the dinosaur game, ADR-085) begins. Not recorded yet: until then the match opens with the format.*

| id | line | delivery | max s |
|---|---|---|---|
| `venue_ruins_1` | Welcome to the ruins! Mind the rubble, and the raptors. | Warm, friendly, a smile in the voice. | 3.5 |
| `venue_ruins_2` | The city's on fire, folks, and so are these players! | Big, booming 1994 TV sports energy. | 3.0 |
| `venue_glacier_1` | Welcome to the glacier! Bundle up, it's a cold one today. | Warm, friendly, a smile in the voice. | 3.5 |
| `venue_glacier_2` | Careful out there. The only thing colder is that serve! | Dry, playful, a little deadpan; let the pun land. | 3.0 |
| `venue_lab_1` | Welcome to the lab! And please, nobody tap on the tanks. | Dry, playful, a little deadpan; let the pun land. | 3.0 |
| `venue_lab_2` | Today's experiment: pickleball! Let's see what happens. | Warm, friendly, a smile in the voice. | 3.0 |
| `venue_station_1` | Welcome aboard the station! Gravity's on. Mostly. | Dry, playful, a little deadpan; let the pun land. | 3.0 |
| `venue_station_2` | Live from orbit, it's pickleball! | Big, booming 1994 TV sports energy. | 2.2 |

## The painted venues

*As a match at WESTERN, ROOFTOP, PIRATES, MOTEL, FAIR, DRIVE-IN or MALL (ADR-088) begins. Not recorded yet: until then the match opens with the format.*

| id | line | delivery | max s |
|---|---|---|---|
| `venue_western_1` | Welcome to town, partner! This court ain't big enough for four. | Dry, playful, a little deadpan; let the pun land. | 3.5 |
| `venue_western_2` | High noon on Main Street. Somebody's getting dinked! | Big, booming 1994 TV sports energy. | 3.0 |
| `venue_rooftop_1` | Welcome to the rooftop! Watch that lob, it's a long way down. | Dry, playful, a little deadpan; let the pun land. | 3.5 |
| `venue_rooftop_2` | Pickleball above the city lights! | Big, booming 1994 TV sports energy. | 2.2 |
| `venue_pirate_1` | Ahoy! Welcome aboard, and mind the cannons. | Warm, friendly, a smile in the voice. | 3.0 |
| `venue_pirate_2` | All hands on deck, it's pickleball on the high seas! | Big, booming 1994 TV sports energy. | 3.0 |
| `venue_motel_1` | Welcome to the motel! The pool's closed, but the court's open. | Dry, playful, a little deadpan; let the pun land. | 3.5 |
| `venue_motel_2` | Vacancy! And these players are checking in. | Warm, friendly, a smile in the voice. | 2.8 |
| `venue_fair_1` | Welcome to the county fair! Step right up! | Warm, friendly, a smile in the voice. | 3.0 |
| `venue_fair_2` | Forget the ring toss, folks. This is the real game! | Big, booming 1994 TV sports energy. | 3.0 |
| `venue_drivein_1` | Welcome to the drive-in! Tonight's feature: pickleball! | Warm, friendly, a smile in the voice. | 3.0 |
| `venue_drivein_2` | Two thumbs up already, and nobody's served yet! | Dry, playful, a little deadpan; let the pun land. | 3.0 |
| `venue_mall_1` | Welcome to the mall! Shop till you drop, then play till you drop. | Warm, friendly, a smile in the voice. | 3.5 |
| `venue_mall_2` | Attention, shoppers: pickleball, at center court! | Big, booming 1994 TV sports energy. | 2.8 |

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
| `achievement_globetrotter` | A win at every venue! A true globetrotter! | Big, booming 1994 TV sports energy. | 3.0 |
| `achievement_scholar` | Class dismissed! They know the real game now. | Warm, friendly, a smile in the voice. | 3.0 |
| `achievement_ace` | An ace for the record books! | Big, booming 1994 TV sports energy. | 2.2 |
| `achievement_marathon` | Twenty shots! That's a marathon! | Big, booming 1994 TV sports energy. | 2.2 |
| `achievement_on_fire` | Thirty shots! They're on fire! | Big, booming 1994 TV sports energy. | 2.2 |
| `achievement_comeback` | Down five and came back! The comeback kid! | Big, booming 1994 TV sports energy. | 3.0 |
| `achievement_mad_scientist` | Three modifiers at once? That's mad science! | Dry, playful, a little deadpan; let the pun land. | 2.8 |
| `achievement_park_saved` | The park is saved! Riverdale thanks you! | Warm, friendly, a smile in the voice. | 2.8 |

## Specials

*With SPECIALS on (ADR-080): the match's introduction, a player's meter filling up, PICKLE SMASH itself, its return popping up (the knock-back), and a smash that wins the point or sets up the side's next shot to win it.*

| id | line | delivery | max s |
|---|---|---|---|
| `mod_specials_1` | Specials are on! Keep an eye on those meters! | Big, booming 1994 TV sports energy. | 3.0 |
| `mod_specials_2` | Specials today, folks. Somebody's getting smashed! | Dry, playful, a little deadpan; let the pun land. | 3.0 |
| `special_ready_1` | The meter's full! | Big, booming 1994 TV sports energy. | 1.5 |
| `special_ready_2` | Special's ready! | Big, booming 1994 TV sports energy. | 1.5 |
| `special_ready_3` | They're all charged up! | Big, booming 1994 TV sports energy. | 1.8 |
| `pickle_smash_1` | Pickle smash! | Big, booming 1994 TV sports energy. | 1.2 |
| `pickle_smash_2` | Pickle... SMASH! | Big, booming 1994 TV sports energy. | 1.6 |
| `pickle_smash_3` | Kaboom! Pickle smash! | Big, booming 1994 TV sports energy. | 1.8 |
| `pickle_smash_4` | They're in a pickle now! | Dry, playful, a little deadpan; let the pun land. | 1.8 |
| `smash_return_1` | They got a paddle on it! | Big, booming 1994 TV sports energy. | 1.5 |
| `smash_return_2` | Just barely! | Big, booming 1994 TV sports energy. | 1.0 |
| `smash_return_3` | That one rattled the paddle! | Dry, playful, a little deadpan; let the pun land. | 1.8 |
| `smash_winner_1` | Untouchable! | Big, booming 1994 TV sports energy. | 1.0 |
| `smash_winner_2` | Nobody's getting that one! | Big, booming 1994 TV sports energy. | 1.8 |
| `smash_winner_3` | Smashed to bits! | Dry, playful, a little deadpan; let the pun land. | 1.5 |
| `smash_finish_1` | Set it up and knock it down! | Big, booming 1994 TV sports energy. | 2.0 |
| `smash_finish_2` | And they finish the job! | Big, booming 1994 TV sports energy. | 1.8 |

## Power-ups (for later)

*Not in the game yet: the power-ups in design/SPECIALS_AND_POWERUPS.md (route B). Recording them now saves a session later; the game will use them when power-ups are built.*

| id | line | delivery | max s |
|---|---|---|---|
| `powerup_appear_1` | Power-up on the court! | Big, booming 1994 TV sports energy. | 1.8 |
| `powerup_appear_2` | Ooh, what's that? | Dry, playful, a little deadpan; let the pun land. | 1.2 |
| `powerup_grab_1` | Got it! | Big, booming 1994 TV sports energy. | 0.8 |
| `powerup_grab_2` | Snagged it! | Big, booming 1994 TV sports energy. | 1.0 |
| `powerup_big_paddle` | Big paddle! | Big, booming 1994 TV sports energy. | 1.2 |
| `powerup_sneakers` | Speed shoes! | Big, booming 1994 TV sports energy. | 1.2 |
| `powerup_ice_patch` | Slippery out there! | Dry, playful, a little deadpan; let the pun land. | 1.5 |
| `powerup_slow_mo` | Slow... motion! | Dry, playful, a little deadpan; let the pun land. | 1.8 |
| `powerup_magnet` | Magnet ball! | Big, booming 1994 TV sports energy. | 1.2 |
| `powerup_golden_ball` | Golden ball! This one's worth two! | Big, booming 1994 TV sports energy. | 2.5 |
| `powerup_banana` | Watch your step! | Dry, playful, a little deadpan; let the pun land. | 1.2 |
| `powerup_pickle_jar` | Pickle jar! Smash time! | Big, booming 1994 TV sports energy. | 1.8 |
