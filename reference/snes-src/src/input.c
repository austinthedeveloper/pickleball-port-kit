#include <snes.h>
#include "input.h"

/* The only module that touches pad hardware (docs/04). */

void input_initialize(void)
{
    /* Boot-time Multitap detection through the library path; hot-plugging
     * is unsupported. */
    detectMPlay5();
    input_configure(snes_mplay5 != 0);
}

void input_capture_frame(void)
{
    static u16 raw[MAX_PADS];

    /* Constant indices: 816-tcc multiplies for variable array indexing. */
    raw[0] = padsCurrent(0);
    raw[1] = padsCurrent(1);
    raw[2] = padsCurrent(2);
    raw[3] = padsCurrent(3);
    raw[4] = padsCurrent(4);
    input_map_frame(raw);
}
