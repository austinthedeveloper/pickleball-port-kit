#ifndef PROJECTION_H
#define PROJECTION_H

#include "game_types.h"

/* World (rules-space) x on row y to screen x; see ADR-011. */
s16 projection_x(s16 x, s16 y);

#endif
