#ifndef RULES_H
#define RULES_H

#include "ball.h"
#include "game.h"

void rules_resolve_point(u8 losing_team, u8 fault);
void rules_process_ball_events(u8 events);
void rules_process_player_hit(u8 player_index);

#endif
