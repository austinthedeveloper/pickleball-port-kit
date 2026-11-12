# ADR-114 — Player Arms and Swings

Status: **Accepted 2026-11-11** (asked for by the user: the players'
animations were "very compact", the arms "terrible", and overheads
handled badly; walking was fine, and so were the heads).

## Context

The 960×540 players are drawn by a rig (`art/levels/tools/players.py`):
each pose is a set of joints. Three things made the arms read badly:

- **Each pose set its own arm length.** Elbows and hands were typed in by
  hand, so a forearm was 5 px in one frame and 7 in the next (at the
  rig's 1× scale), and most were short: hands stopped close to the body.
- **The overhead had two frames.** A windup with the paddle folded at the
  shoulder, a contact with the hand at cap height, and then the
  forehand's finish, which put the paddle back up at the face.
- **The low swings had no way in or out.** A scoop held one pose from the
  windup to the recovery; a scoop or a reach then stood up into the
  forehand's high finish in a single frame.

## Decision

**One arm length (`solve_arm`).** `scaled()` now places every elbow
itself: the upper arm and the forearm are 7.5 px each (1×), about a fifth
longer than the old average. A pose gives the shoulder and the hand; its
elbow only says which way the arm bends, and a hand past full reach is
brought in to it. Legs, torsos and necks are as they were, so walking is
unchanged and every head and hat sits where it did.

**The forehand reaches.** The windup's paddle arm is long behind the
body, the contact is at full reach in front, and the finish carries up
and forward, clear of the face. The ready stance, the serve's toss, the
cheer, the lunge and the scoop hold their hands further out.

**The overhead is three frames:**
- `overhead_windup`, the trophy pose: knees loaded, the paddle cocked
  behind the head on a high back elbow, the free hand up at the ball;
- `overhead_contact`: the arm at full stretch up and in front, the free
  arm pulled in, up on the toes;
- `overhead_follow` (new): the paddle snapped down past the front knee,
  the body folded over it. It holds for the whole recovery.

**The low swings:**
- `scoop_windup` (new): the paddle drawn back low behind the back knee;
- `lift` (new): half risen, the paddle lifted through the ball. A scoop
  or a reach holds its contact, then shows `lift` for the last
  `MatchActors.LOW_LIFT` (4) frames of the recovery.

The sheets grow from 21 frames to 24; the new ones are appended, so
every older frame keeps its index. `MatchView.SLOTS` lists them, and
`test_overhead.test_each_swing_has_its_own_frames` checks the sheets'
frames against it and each swing's frames in order.

## Considered

- **A hop at the smash** (the view lifting the sprite off its shadow).
  Not done: an overhead's ball is at head height on screen (the players
  are drawn large against the court), so a hop would take the paddle
  further from the ball it hits.
- **A taller frame**, for an arm straight up. Not needed: at full reach
  up and in front, the paddle fits the 128 px frame under every hat.
- **Generated art.** The bodies are rig-drawn, so the poses are a code
  change; nothing was generated.

## Consequences

- Display only: the sim, the golden traces and the conformance traces
  are untouched.
- The 48 px rigs (`art/sprites/hd`, `hd/v2`) and the SNES sets keep their
  old poses; nothing in the game draws them.
