#include <assert.h>
#include <stdio.h>
#include "court.h"
#include "court_projection.h"
#include "projection.h"

/* ADR-011 PROJ-01..03 against the generated table the game uses. */
int main(void)
{
    s16 y;
    s16 x;

    for (y = 0; y < COURT_PROJECTION_ROWS; ++y) {
        s16 s = 256 + g_court_projection_delta[y];
        assert(s >= 192 && s <= 282);                          /* PROJ-01 */
        if (y > 0)
            assert(g_court_projection_delta[y] >=
                g_court_projection_delta[y - 1]);
        assert(projection_x(COURT_NET_X, y) == 128);           /* PROJ-02 */
    }
    assert(256 + g_court_projection_delta[COURT_SIDELINE_TOP] ==
        COURT_PROJ_SCALE_TOP);
    assert(256 + g_court_projection_delta[COURT_SIDELINE_BOTTOM] ==
        COURT_PROJ_SCALE_BOTTOM);
    for (x = COURT_BASELINE_LEFT; x <= COURT_BASELINE_RIGHT;
            x += COURT_BASELINE_RIGHT - COURT_BASELINE_LEFT) {
        for (y = COURT_SIDELINE_TOP; y <= COURT_SIDELINE_BOTTOM;
                y += COURT_SIDELINE_BOTTOM - COURT_SIDELINE_TOP) {
            s16 sx = projection_x(x, y);
            assert(sx >= 8 && sx <= 247);                      /* PROJ-03 */
        }
    }
    /* Near sideline is unscaled; the far sideline narrows symmetrically to
     * within the one pixel that round-half-up gives exact halves. */
    assert(projection_x(COURT_BASELINE_LEFT, COURT_SIDELINE_BOTTOM) ==
        COURT_BASELINE_LEFT);
    x = projection_x(COURT_BASELINE_LEFT, COURT_SIDELINE_TOP) +
        projection_x(COURT_BASELINE_RIGHT, COURT_SIDELINE_TOP);
    assert(x >= 255 && x <= 257);
    /* Out-of-range rows clamp instead of reading past the table. */
    assert(projection_x(0, -5) == projection_x(0, 0));
    assert(projection_x(0, 400) == projection_x(0, 223));
    puts("projection host checks passed");
    return 0;
}
