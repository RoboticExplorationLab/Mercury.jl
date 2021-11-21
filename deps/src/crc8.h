#ifndef CRC8_H_INCLUDED
#define CRC8_H_INCLUDED

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct _CRC8_PARAMS
{
    uint8_t polynome;
    uint8_t startmask;
    uint8_t endmask;
    bool reverseIn;
    bool reverseOut;
} CRC8_PARAMS;

// CRC POLYNOME = x8 + x5 + x4 + 1 = 1001 1000 = 0x8C
#define DEFAULT_CRC8_PARAMS { 0xD5, 0x00, 0x00, false, false }

uint8_t crc8(CRC8_PARAMS params, uint8_t *array, uint8_t length);

#endif
