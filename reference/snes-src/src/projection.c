#define COURT_PROJECTION_DEFINE
#include "court_projection.h"
#include "projection.h"

/*
 * 128 + round_half_up((x - 128) * s(y) / 256), with s(y) = 256 + delta(y).
 * Expanding gives d + ((d * delta + 128) >> 8), which is exact and keeps the
 * product inside 16 bits (|d| <= 140, |delta| <= 64), avoiding 816-tcc's slow
 * 32-bit multiply.
 */
s16 projection_x(s16 x, s16 y)
{
    s16 d = x - 128;

    if (y < 0)
        y = 0;
    else if (y >= COURT_PROJECTION_ROWS)
        y = COURT_PROJECTION_ROWS - 1;
    return 128 + d + ((d * g_court_projection_delta[y] + 128) >> 8);
}
