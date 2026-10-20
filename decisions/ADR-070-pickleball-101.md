# ADR-070 — PICKLEBALL 101: the Real Game

Status: **Accepted 2026-10-19**
Milestone: `PORT-45` (the user's ask: teach how to play pickleball for
real, "so they can take it and play in real life"; not a hard mode).

## Decision

PRACTICE gets a first row, **PICKLEBALL 101** ("the real game, for a
real court"). HOW TO PLAY (PORT-30) teaches this game's buttons; this
teaches the sport, by the current rules (USA Pickleball), with no match
in it. It is something to read and look at, with quizzes to check you
got it.

- **Eight lessons**: THE COURT (20 by 44 feet, the net 36 inches at the
  sidelines and 34 in the middle, the 7-foot kitchen and its line, right
  and left service courts); THE SERVE (underhand, below the waist, the
  paddle head below the wrist; a foot behind the baseline, inside the
  centerline and sideline extended; crosscourt; past the kitchen line,
  where the kitchen line is a fault and the others are in; one try; net
  serves play on; the drop serve; aim deep); LET IT BOUNCE (the
  two-bounce rule, serving team stays back, returner comes up); THE
  KITCHEN (no volleys in it or on its line, momentum, stepping in for a
  bounced ball, the dink); KEEPING SCORE (side-out scoring, 11 win by 2,
  the three-number call, switching sides after a point, server 2, side
  out, 0-0-2, the right court first, singles' even/odd; then rally
  scoring, which this game plays, and where SIDE-OUT is switched on); LINE CALLS
  (faults, the line is in, calling your side, when in doubt it's in, a
  ball that hits you); PLAYING SMART (get to the line, deep serves and
  returns, the third-shot drop, dink and wait, feet and the middle);
  COURT MANNERS (call the score, ball on court, crossing courts, the
  paddle rack, the paddle tap).
- **Every page has a court diagram**, from above with your side on the
  left: zones lit gold (where to stand, where the serve lands) or red
  (a fault), players, arrows for who moves, and the ball flying its path
  on a loop, leaving a ring at each bounce, a burst at a volley and an X
  at a fault. Scoring pages show the call, big.
- **Each lesson ends in a quiz or two** (18 in all): the first pick is
  the one that counts; right or wrong, the answer and why follow. A
  lesson is DONE when its closing page is reached, and PERFECT when every
  quiz was right the first time.
- **TRY IT IN THE GAME**: THE SERVE, LET IT BOUNCE and THE KITCHEN close
  with their HOW TO PLAY drill (the game's rules follow the real ones
  there), which comes back to the course when it's done.
- The pages are data (`data/pickleball101.json`), so the wording can be
  changed without code.

## How

`meta/course.gd` (`Course`): the lessons, the closing page, the drill,
and the progress in `save.data["course"]` (a new key with a default: the
save stays v6). `view/court_diagram.gd` (`CourtDiagram`): the court
drawn from a page. `view/course_screen.gd` (`CourseScreen`): the list
with a preview, a lesson's pages, quizzes and closing menu. Hit or Right
goes on, Left goes back, SOFT or a right click returns to the list.

## Tests

`test_course`: the data (every page drawable in the font, every answer in
range, every zone and drill known); the real numbers (the court, the
kitchen quiz, 6-4-2, 0-0-2, a serve on the kitchen line, the serve
diagram crosscourt); the progress (perfect kept, saved, an old save);
a lesson's paging, the quiz's first pick, the closing page and TRY IT;
PRACTICE to the course, the drill and back. `test_layout` checks the
list on every row and every page, quizzes answered both ways, with
keyboard and pad prompts.
