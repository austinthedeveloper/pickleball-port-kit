#ifndef GAME_TYPES_H
#define GAME_TYPES_H

#ifdef HOST_TEST
#include <stdint.h>
typedef uint8_t u8;
typedef uint16_t u16;
typedef int16_t s16;
typedef int32_t s32;
#else
#include <snes.h>
#endif

/* 12.4 fixed point: positions/velocities in 1/16 pixel units. */
typedef s16 fx;

#endif

