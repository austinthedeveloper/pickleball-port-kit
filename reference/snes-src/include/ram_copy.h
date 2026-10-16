#ifndef RAM_COPY_H
#define RAM_COPY_H

#include "game_types.h"

/*
 * RAM_COPY(dst, src, n): fast copy between work-RAM objects in bank $7E
 * (src/asm/ram_copy.asm). Host builds use memcpy.
 */
#ifdef HOST_TEST
#include <string.h>
#define RAM_COPY(dst, src, n) memcpy((dst), (src), (n))
#else
extern u16 ram_copy_src;
extern u16 ram_copy_dst;
extern u16 ram_copy_len;
extern void ram_copy(void);
#define RAM_COPY(dst, src, n) \
    do { \
        ram_copy_dst = (u16)(dst); \
        ram_copy_src = (u16)(src); \
        ram_copy_len = (n); \
        ram_copy(); \
    } while (0)
#endif

#endif
