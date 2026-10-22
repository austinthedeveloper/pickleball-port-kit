# The Announcer: script for the voiceover

A 1994 TV sports announcer for Pickleball '94: big and warm, a little
cheesy, never mean, family friendly. One voice for every line. The
game plays these between points and, briefly, during rallies, under
its own crowd and music, and never two at once. **298 lines**; the same
list is `lines.csv` (one row per file, for batching).

Remaster-only (the canon bible has no announcer): see the roadmap's
For you.

## For the recording

- **One file per line**, named by its id: `ace_1.wav`. All in one folder.
- **WAV, 48 kHz (or 44.1), 16-bit, mono.** No music, crowd or effects in
  them; the game adds its own.
- **Trim the silence**: start within 50 ms of the first sound, end within
  100 ms of the last. The game times them.
- **Even loudness**: about -16 LUFS each, peaks under -1 dBFS, so no line
  jumps out.
- **The same voice and settings for every line**, the numbers above all:
  the score calls are built from them, so they must sound like one call.
- **Mind the length**: each line has a most-seconds; the rally lines
  especially, which have to land between shots.
- The text is written as it should be said ("Twenty-one", "Pickleball
  Ninety-Four"). If a word comes out wrong, respell it, and keep the id.
- Variants (`_1`, `_2`, ...) are alternatives the game picks between, so
  they should differ a little in delivery too.

## Title and attract

*On the title screen (the logo appearing) and over the demo.*

| id | line | delivery | max s |
|---|---|---|---|
| `title_logo_1` | Pickleball Ninety-Four! | Big, booming 1994 TV sports energy. | 2 |
| `title_logo_2` | It's Pickleball Ninety-Four! | Big, booming 1994 TV sports energy. | 2 |
| `title_press_start` | Grab a paddle and press start! | Warm, friendly, a smile in the voice. | 2 |
| `demo_1` | Welcome back to Riverdale Park, where the dinks are soft and the stakes are high. | Warm, friendly, a smile in the voice. | 5 |
| `demo_2` | Pull up a lawn chair, folks. We've got pickleball. | Warm, friendly, a smile in the voice. | 4 |

## Match start: venues

*As a match begins, once, for its venue.*

| id | line | delivery | max s |
|---|---|---|---|
| `venue_park_1` | Good afternoon, and welcome to Riverdale Park! | Big, booming 1994 TV sports energy. | 3 |
| `venue_park_2` | A beautiful day for pickleball here at Riverdale Park. | Warm, friendly, a smile in the voice. | 4 |
| `venue_lakeside_1` | We're coming to you live from the lakeside courts! | Big, booming 1994 TV sports energy. | 3 |
| `venue_lakeside_2` | Lakeside today. Watch out for the geese, folks. | Dry, playful, a little deadpan; let the pun land. | 3 |
| `venue_sunset_1` | Live from the sunset courts, where the light is golden and so is the play! | Big, booming 1994 TV sports energy. | 4 |
| `venue_sunset_2` | The sun is setting, and the pickleball is just getting started. | Warm, friendly, a smile in the voice. | 4 |
| `venue_dinosaur_1` | Welcome to the dinosaur courts! Mind the T. rex. | Big, booming 1994 TV sports energy. | 3 |
| `venue_dinosaur_2` | Pickleball in the age of the dinosaurs. Prehistoric! | Dry, playful, a little deadpan; let the pun land. | 4 |
| `venue_space_1` | Coming to you from outer space! In space, no one can hear you dink. | Dry, playful, a little deadpan; let the pun land. | 5 |
| `venue_space_2` | Zero gravity? Not quite. But it's out of this world! | Big, booming 1994 TV sports energy. | 4 |
| `venue_undersea_1` | We're live from the bottom of the sea! Hold your breath, folks! | Big, booming 1994 TV sports energy. | 4 |
| `venue_undersea_2` | Undersea pickleball. The fish have the best seats in the house. | Dry, playful, a little deadpan; let the pun land. | 4 |
| `time_night` | Under the lights tonight! | Big, booming 1994 TV sports energy. | 2 |
| `time_dusk` | The lights are coming on. What an evening for it. | Warm, friendly, a smile in the voice. | 3 |

## Match start

*As a match begins, after the venue.*

| id | line | delivery | max s |
|---|---|---|---|
| `match_begin_1` | Let's play some pickleball! | Big, booming 1994 TV sports energy. | 2 |
| `match_begin_2` | Here we go! | Big, booming 1994 TV sports energy. | 1.5 |
| `match_begin_3` | Players ready. Let's get it on! | Big, booming 1994 TV sports energy. | 2.5 |
| `match_doubles` | It's doubles today, two on two! | Big, booming 1994 TV sports energy. | 2.5 |
| `match_singles` | Singles! One on one. Nowhere to hide. | Big, booming 1994 TV sports energy. | 3 |

## Match start: modifiers

*As a match begins with this modifier on (the first one, if several).*

| id | line | delivery | max s |
|---|---|---|---|
| `mod_big_ball` | Big ball today, folks! Very big. Enormous, really. | Dry, playful, a little deadpan; let the pun land. | 4 |
| `mod_fast_ball` | Fast ball! Blink and you'll miss it. | Big, booming 1994 TV sports energy. | 3 |
| `mod_ghost_ball` | Ghost ball! Now you see it, now you don't. | Hushed, leaning into the mic, building tension. | 3 |
| `mod_popcorn` | Popcorn rules! The longer the rally, the faster it pops. | Big, booming 1994 TV sports energy. | 4 |
| `mod_ice` | The court is ice today! Careful out there. | Big, booming 1994 TV sports energy. | 3 |
| `mod_glow` | Lights out! Glow in the dark pickleball! | Big, booming 1994 TV sports energy. | 3 |
| `mod_inverse` | Something's off with the picture, folks. That's on purpose. | Dry, playful, a little deadpan; let the pun land. | 4 |
| `mod_moon` | Moon gravity! These shots are going to hang. | Big, booming 1994 TV sports energy. | 3 |
| `mod_bouncy` | Bouncy ball! Boing! | Dry, playful, a little deadpan; let the pun land. | 2 |
| `mod_wind` | It's blowing out there today. Watch that wind! | Big, booming 1994 TV sports energy. | 3 |
| `mod_win_by_2` | Remember, you've got to win by two. | Clear and even, like an umpire calling it. | 3 |
| `mod_lava` | The floor is lava! I'm not kidding, it is actually lava. | Dry, playful, a little deadpan; let the pun land. | 4 |
| `mod_side_out` | Traditional scoring today. Only the server scores! | Clear and even, like an umpire calling it. | 3 |
| `mod_momentum` | Momentum rules are in effect. Watch those feet after a volley. | Clear and even, like an umpire calling it. | 4 |
| `mod_dink_or_die` | Dink or die! No drives allowed! | Big, booming 1994 TV sports energy. | 2.5 |
| `mod_sudden_death` | Sudden death! One point takes it all! | Big, booming 1994 TV sports energy. | 3 |
| `mod_multi_ball` | Multi ball! Balls everywhere! | Big, booming 1994 TV sports energy. | 2.5 |

## The serve

*At a serve: now and then, not every one. Score calls come before these.*

| id | line | delivery | max s |
|---|---|---|---|
| `serve_1` | Here's the serve. | Clear and even, like an umpire calling it. | 1.5 |
| `serve_2` | Serving now. | Clear and even, like an umpire calling it. | 1.2 |
| `serve_3` | And the serve. | Clear and even, like an umpire calling it. | 1.2 |
| `serve_deep` | Deep serve! | Quick and punchy, one breath. Under a second. | 1 |
| `serve_quiet` | Quiet, please. | Hushed, leaning into the mic, building tension. | 1.5 |
| `ace_1` | Ace! | Quick and punchy, one breath. Under a second. | 1 |
| `ace_2` | Ace! Didn't touch it! | Big, booming 1994 TV sports energy. | 1.5 |
| `ace_3` | Untouchable! | Big, booming 1994 TV sports energy. | 1.2 |
| `ace_4` | Service winner! Right on the line! | Big, booming 1994 TV sports energy. | 2 |
| `ace_5` | That serve had a return address. Nobody was home. | Dry, playful, a little deadpan; let the pun land. | 3 |
| `serve_fault_1` | Fault on the serve. | Clear and even, like an umpire calling it. | 1.5 |
| `serve_fault_2` | Wrong service box! | Clear and even, like an umpire calling it. | 1.5 |
| `serve_fault_3` | That serve's in the kitchen. Fault! | Clear and even, like an umpire calling it. | 2 |

## Score calls

*Built from pieces: two numbers for rally scoring (rising, then falling: "four... two"), three for side-out ("four, two, one"), and "all" for a tie ("five all"). Record every number twice, once rising (as if more is coming) and once falling (the end of the call).*

| id | line | delivery | max s |
|---|---|---|---|
| `num_00_up` | Zero | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_00_down` | Zero | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_01_up` | One | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_01_down` | One | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_02_up` | Two | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_02_down` | Two | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_03_up` | Three | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_03_down` | Three | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_04_up` | Four | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_04_down` | Four | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_05_up` | Five | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_05_down` | Five | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_06_up` | Six | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_06_down` | Six | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_07_up` | Seven | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_07_down` | Seven | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_08_up` | Eight | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_08_down` | Eight | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_09_up` | Nine | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_09_down` | Nine | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_10_up` | Ten | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_10_down` | Ten | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_11_up` | Eleven | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_11_down` | Eleven | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_12_up` | Twelve | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_12_down` | Twelve | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_13_up` | Thirteen | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_13_down` | Thirteen | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_14_up` | Fourteen | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_14_down` | Fourteen | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_15_up` | Fifteen | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_15_down` | Fifteen | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_16_up` | Sixteen | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_16_down` | Sixteen | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_17_up` | Seventeen | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_17_down` | Seventeen | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_18_up` | Eighteen | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_18_down` | Eighteen | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_19_up` | Nineteen | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_19_down` | Nineteen | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_20_up` | Twenty | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_20_down` | Twenty | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_21_up` | Twenty-one | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_21_down` | Twenty-one | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_22_up` | Twenty-two | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_22_down` | Twenty-two | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_23_up` | Twenty-three | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_23_down` | Twenty-three | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_24_up` | Twenty-four | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_24_down` | Twenty-four | Falling, the end of the call. Clean, no breath. | 0.8 |
| `num_25_up` | Twenty-five | Rising, like a list that continues. Clean, no breath. | 0.8 |
| `num_25_down` | Twenty-five | Falling, the end of the call. Clean, no breath. | 0.8 |
| `score_all` | All. | Falling, ends the call ("five ALL"). | 0.6 |
| `score_love` | Love. | Falling. A wink: pickleball says zero. | 0.6 |
| `score_server_1` | First server. | Clear and even, like an umpire calling it. | 1.2 |
| `score_server_2` | Second server. | Clear and even, like an umpire calling it. | 1.2 |
| `side_out_1` | Side out! | Clear and even, like an umpire calling it. | 1 |
| `side_out_2` | Side out. Change of serve. | Clear and even, like an umpire calling it. | 1.8 |
| `side_out_3` | And that's a side out. | Clear and even, like an umpire calling it. | 1.5 |

## In the rally: shots

*During a rally, on a hit: rarely (about one hit in four at most, never two in a row), so it never chatters.*

| id | line | delivery | max s |
|---|---|---|---|
| `shot_dink_1` | Dink! | Quick and punchy, one breath. Under a second. | 0.6 |
| `shot_dink_2` | Soft hands! | Quick and punchy, one breath. Under a second. | 0.8 |
| `shot_dink_3` | Just over! | Quick and punchy, one breath. Under a second. | 0.7 |
| `shot_drive_1` | Drive! | Quick and punchy, one breath. Under a second. | 0.6 |
| `shot_drive_2` | Rips it! | Quick and punchy, one breath. Under a second. | 0.7 |
| `shot_drive_3` | Pow! | Quick and punchy, one breath. Under a second. | 0.5 |
| `shot_lob_1` | Lob! | Quick and punchy, one breath. Under a second. | 0.6 |
| `shot_lob_2` | Up and over! | Quick and punchy, one breath. Under a second. | 0.8 |
| `shot_slice_1` | Slice! | Quick and punchy, one breath. Under a second. | 0.6 |
| `shot_slice_2` | Nasty spin! | Quick and punchy, one breath. Under a second. | 0.8 |
| `shot_smash_1` | Smash! | Quick and punchy, one breath. Under a second. | 0.6 |
| `shot_smash_2` | Overhead! | Quick and punchy, one breath. Under a second. | 0.7 |
| `shot_smash_3` | Puts it away! | Quick and punchy, one breath. Under a second. | 0.9 |
| `shot_volley_1` | Volley! | Quick and punchy, one breath. Under a second. | 0.6 |
| `shot_volley_2` | Off the bounce? No, out of the air! | Quick and punchy, one breath. Under a second. | 1.5 |
| `shot_get_1` | What a get! | Quick and punchy, one breath. Under a second. | 0.8 |
| `shot_get_2` | Gets there! | Quick and punchy, one breath. Under a second. | 0.7 |
| `shot_get_3` | Diving save! | Quick and punchy, one breath. Under a second. | 0.8 |
| `shot_net_cord` | Off the tape! | Quick and punchy, one breath. Under a second. | 0.8 |

## In the rally: long rallies

*As a rally reaches 10 shots (the ball catches fire), 15 (the focus), 20, 25 and 30, once each.*

| id | line | delivery | max s |
|---|---|---|---|
| `rally_10_1` | Ten shots! | Big, booming 1994 TV sports energy. | 1 |
| `rally_10_2` | This rally is heating up! | Big, booming 1994 TV sports energy. | 1.5 |
| `rally_10_3` | Ten and counting! | Big, booming 1994 TV sports energy. | 1.2 |
| `rally_15_1` | Fifteen! They're on fire! | Big, booming 1994 TV sports energy. | 1.5 |
| `rally_15_2` | Nobody wants to miss! | Big, booming 1994 TV sports energy. | 1.5 |
| `rally_20_1` | Twenty shots! Unbelievable! | Big, booming 1994 TV sports energy. | 1.8 |
| `rally_20_2` | Somebody get these players a glass of water! | Dry, playful, a little deadpan; let the pun land. | 2.5 |
| `rally_25` | Twenty-five! I've never seen anything like it! | Big, booming 1994 TV sports energy. | 2.5 |
| `rally_30_1` | Thirty! This is the rally of the century! | Big, booming 1994 TV sports energy. | 2.5 |
| `rally_30_2` | Folks, I may need to sit down. | Dry, playful, a little deadpan; let the pun land. | 2 |

## The point: how it ended

*After a point, by its fault (the HUD's fault word). Short: the score call often follows.*

| id | line | delivery | max s |
|---|---|---|---|
| `out_1` | Out! | Clear and even, like an umpire calling it. | 0.6 |
| `out_2` | Long! | Clear and even, like an umpire calling it. | 0.6 |
| `out_3` | Just wide. | Clear and even, like an umpire calling it. | 1 |
| `out_4` | That one had a passport. Way out. | Dry, playful, a little deadpan; let the pun land. | 2.5 |
| `out_close_1` | Ooh, just out! | Sympathetic, a gentle 'ohh' feel, not mocking. | 1.2 |
| `out_close_2` | By a whisker! | Sympathetic, a gentle 'ohh' feel, not mocking. | 1 |
| `net_1` | Into the net. | Clear and even, like an umpire calling it. | 1 |
| `net_2` | Net! | Clear and even, like an umpire calling it. | 0.6 |
| `net_3` | The net says no. | Dry, playful, a little deadpan; let the pun land. | 1.5 |
| `kitchen_1` | Kitchen violation! | Clear and even, like an umpire calling it. | 1.2 |
| `kitchen_2` | Foot in the kitchen! | Clear and even, like an umpire calling it. | 1.2 |
| `kitchen_3` | You can't volley from the kitchen! Kitchen's closed! | Dry, playful, a little deadpan; let the pun land. | 2.5 |
| `early_volley_1` | Let it bounce! Two-bounce rule! | Clear and even, like an umpire calling it. | 2 |
| `early_volley_2` | Too eager! That one had to bounce. | Dry, playful, a little deadpan; let the pun land. | 2 |
| `two_bounces_1` | Couldn't get there. | Sympathetic, a gentle 'ohh' feel, not mocking. | 1.2 |
| `two_bounces_2` | Two bounces! | Clear and even, like an umpire calling it. | 1 |
| `two_bounces_3` | Nobody home! | Dry, playful, a little deadpan; let the pun land. | 1 |
| `wrong_box` | Wrong box! | Clear and even, like an umpire calling it. | 1 |
| `lava_1` | Into the lava! | Big, booming 1994 TV sports energy. | 1 |
| `lava_2` | Ouch! Hot hot hot! | Dry, playful, a little deadpan; let the pun land. | 1.5 |
| `momentum_1` | Momentum carried them into the kitchen! | Clear and even, like an umpire calling it. | 2 |
| `momentum_2` | Couldn't stop! Fault! | Clear and even, like an umpire calling it. | 1.5 |
| `drive_banned_1` | A drive? Not today! Dink or die! | Dry, playful, a little deadpan; let the pun land. | 2 |
| `drive_banned_2` | That's a drive. Rules are rules! | Dry, playful, a little deadpan; let the pun land. | 2 |
| `winner_1` | Winner! | Big, booming 1994 TV sports energy. | 0.8 |
| `winner_2` | Right on the line! | Big, booming 1994 TV sports energy. | 1.2 |
| `winner_3` | No chance on that one! | Big, booming 1994 TV sports energy. | 1.5 |
| `winner_4` | Put it where they ain't! | Dry, playful, a little deadpan; let the pun land. | 1.5 |

## Between points: the match

*After a point, by the match's state: a streak, a comeback, match point. Plays instead of the fault line, now and then.*

| id | line | delivery | max s |
|---|---|---|---|
| `streak_3_1` | Three in a row! | Big, booming 1994 TV sports energy. | 1.2 |
| `streak_3_2` | They're rolling now! | Big, booming 1994 TV sports energy. | 1.3 |
| `streak_5_1` | Five straight! Somebody stop them! | Big, booming 1994 TV sports energy. | 2 |
| `streak_5_2` | Is anybody going to slow this down? | Dry, playful, a little deadpan; let the pun land. | 2 |
| `comeback_1` | We are all tied up! | Big, booming 1994 TV sports energy. | 1.5 |
| `comeback_2` | What a comeback! | Big, booming 1994 TV sports energy. | 1.2 |
| `comeback_3` | Never count them out! | Big, booming 1994 TV sports energy. | 1.3 |
| `shutout_watch` | Still looking for that first point. | Sympathetic, a gentle 'ohh' feel, not mocking. | 2 |
| `close_game` | This is a close one, folks. | Hushed, leaning into the mic, building tension. | 1.8 |
| `game_point` | Game point. | Hushed, leaning into the mic, building tension. | 1.2 |
| `match_point_1` | Match point! | Hushed, leaning into the mic, building tension. | 1.2 |
| `match_point_2` | One point away! | Hushed, leaning into the mic, building tension. | 1.2 |
| `match_point_saved` | Match point saved! | Big, booming 1994 TV sports energy. | 1.5 |
| `win_by_2_1` | Got to win by two! | Clear and even, like an umpire calling it. | 1.3 |
| `win_by_2_2` | And we keep going! | Big, booming 1994 TV sports energy. | 1.2 |
| `sudden_death` | Sudden death! Next point wins it all! | Hushed, leaning into the mic, building tension. | 2.5 |

## Pickle puns and quips

*Now and then between points, when nothing else is said; at most one every few points.*

| id | line | delivery | max s |
|---|---|---|---|
| `quip_1` | That's a big dill! | Dry, playful, a little deadpan; let the pun land. | 1.2 |
| `quip_2` | They're in a real pickle now. | Dry, playful, a little deadpan; let the pun land. | 1.5 |
| `quip_3` | Relish the moment, folks. | Dry, playful, a little deadpan; let the pun land. | 1.5 |
| `quip_4` | Kitchen's open for business! | Dry, playful, a little deadpan; let the pun land. | 1.5 |
| `quip_5` | Brine time! | Dry, playful, a little deadpan; let the pun land. | 1 |
| `quip_6` | No dinking around out there. | Dry, playful, a little deadpan; let the pun land. | 1.5 |
| `quip_7` | Somebody call the sweet and sour police! | Dry, playful, a little deadpan; let the pun land. | 2 |
| `quip_8` | That's what I call a dill-ightful point. | Dry, playful, a little deadpan; let the pun land. | 2 |
| `quip_9` | Pickle power! | Big, booming 1994 TV sports energy. | 1 |
| `quip_10` | You can't teach that. Well, you can. But you can't teach that. | Dry, playful, a little deadpan; let the pun land. | 3 |
| `quip_11` | My grandmother plays like that. That's a compliment. She's very good. | Dry, playful, a little deadpan; let the pun land. | 4 |
| `quip_12` | Totally radical! | Big, booming 1994 TV sports energy. | 1.2 |
| `quip_13` | Excellent! | Big, booming 1994 TV sports energy. | 0.8 |
| `quip_14` | Booyah! | Big, booming 1994 TV sports energy. | 0.8 |
| `quip_15` | Is it hot out here, or is it just this rally? | Dry, playful, a little deadpan; let the pun land. | 2.5 |
| `quip_16` | I've seen softer hands on a pillow. | Dry, playful, a little deadpan; let the pun land. | 2 |
| `quip_17` | That ball is going home in a jar. | Dry, playful, a little deadpan; let the pun land. | 2 |
| `quip_18` | Somebody get that paddle a raise. | Dry, playful, a little deadpan; let the pun land. | 2 |
| `quip_19` | Paddle up, folks! | Big, booming 1994 TV sports energy. | 1.2 |
| `quip_20` | And the crowd goes mild! | Dry, playful, a little deadpan; let the pun land. | 1.5 |

## Pause, close calls and replays

*On the pause menu, the close-call replay (ADR-041) and PLAY OF THE MATCH (ADR-075).*

| id | line | delivery | max s |
|---|---|---|---|
| `pause_1` | Timeout on the court. | Clear and even, like an umpire calling it. | 1.5 |
| `pause_2` | Don't touch that dial! | Dry, playful, a little deadpan; let the pun land. | 1.5 |
| `resume_1` | And we're back! | Big, booming 1994 TV sports energy. | 1 |
| `resume_2` | Back to the action! | Big, booming 1994 TV sports energy. | 1.2 |
| `close_call_1` | Ooh, was that out? Let's take a look. | Hushed, leaning into the mic, building tension. | 2.5 |
| `close_call_2` | Close call! Let's go to the replay. | Hushed, leaning into the mic, building tension. | 2 |
| `close_call_3` | Out by a hair! | Sympathetic, a gentle 'ohh' feel, not mocking. | 1.2 |
| `potm_1` | And now, the play of the match! | Big, booming 1994 TV sports energy. | 2 |
| `potm_2` | Let's look at that one again. | Warm, friendly, a smile in the voice. | 1.8 |
| `potm_3` | Roll the tape! | Big, booming 1994 TV sports energy. | 1 |
| `potm_end_1` | Just beautiful. | Warm, friendly, a smile in the voice. | 1.2 |
| `potm_end_2` | They'll be talking about that one for weeks. | Warm, friendly, a smile in the voice. | 2.5 |

## Match over

*When a match ends: who won, and how. The player's win gets the loud ones.*

| id | line | delivery | max s |
|---|---|---|---|
| `match_win_1` | And that's the match! | Big, booming 1994 TV sports energy. | 1.5 |
| `match_win_2` | Game, set, and pickle! | Dry, playful, a little deadpan; let the pun land. | 1.8 |
| `match_win_3` | What a performance! | Big, booming 1994 TV sports energy. | 1.5 |
| `match_win_4` | Victory at Riverdale! | Big, booming 1994 TV sports energy. | 1.5 |
| `match_win_shutout` | A shutout! Didn't give up a single point! | Big, booming 1994 TV sports energy. | 2.5 |
| `match_win_close` | Oh, what a finish! That was too close to call! | Big, booming 1994 TV sports energy. | 2.5 |
| `match_loss_1` | Tough break. They'll get them next time. | Sympathetic, a gentle 'ohh' feel, not mocking. | 2.5 |
| `match_loss_2` | Not today. But what a fight. | Sympathetic, a gentle 'ohh' feel, not mocking. | 2 |
| `match_loss_3` | Shake it off. Rematch? | Warm, friendly, a smile in the voice. | 1.8 |
| `handshake` | Paddle taps at the net. That's pickleball. | Warm, friendly, a smile in the voice. | 2.5 |
| `new_record_1` | A new record! | Big, booming 1994 TV sports energy. | 1.2 |
| `new_record_2` | That one's going in the record books! | Big, booming 1994 TV sports energy. | 2 |
| `rematch` | They're going again! Rematch! | Big, booming 1994 TV sports energy. | 1.8 |

## Ladder, tournament and story

*Around the ladder, the bracket (and the couch cup) and STORY mode.*

| id | line | delivery | max s |
|---|---|---|---|
| `ladder_next` | On to the next challenger! | Big, booming 1994 TV sports energy. | 1.8 |
| `ladder_cleared` | They've beaten the whole ladder! Unbelievable! | Big, booming 1994 TV sports energy. | 2.5 |
| `cup_quarter` | The quarterfinals! | Big, booming 1994 TV sports energy. | 1.2 |
| `cup_semi` | The semifinals! Two wins from glory! | Big, booming 1994 TV sports energy. | 2 |
| `cup_final` | This is it. The final! | Hushed, leaning into the mic, building tension. | 1.8 |
| `cup_champion` | Your champions! | Big, booming 1994 TV sports energy. | 1.2 |
| `story_stakes_1` | The park is on the line today, folks. | Hushed, leaning into the mic, building tension. | 2.5 |
| `story_stakes_2` | Another signature for the petition! | Big, booming 1994 TV sports energy. | 2 |
| `story_saved` | They did it! Riverdale Park is saved! | Big, booming 1994 TV sports energy. | 2.5 |
| `story_grimsby` | Somewhere, Mr. Grimsby is not happy. | Dry, playful, a little deadpan; let the pun land. | 2 |
| `open_play_1` | Next up on court two! | Clear and even, like an umpire calling it. | 1.5 |
| `open_play_2` | Winners stay on! | Big, booming 1994 TV sports energy. | 1.2 |
| `multi_ball_new` | Another ball! | Quick and punchy, one breath. Under a second. | 0.8 |

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
