#include "crc8.h"

uint8_t reverse8(uint8_t in)
{
    uint8_t x = in;
    x = (((x & 0xAA) >> 1) | ((x & 0x55) << 1));
    x = (((x & 0xCC) >> 2) | ((x & 0x33) << 2));
    x = ((x >> 4) | (x << 4));
    return x;
}

// CRC POLYNOME = x8 + x5 + x4 + 1 = 1001 1000 = 0x8C
uint8_t crc8(CRC8_PARAMS params, uint8_t *array, uint8_t length)
{
    uint8_t polynome = params.polynome;
    uint8_t startmask = params.startmask;
    uint8_t endmask = params.endmask;
    bool reverseIn = params.reverseIn;
    bool reverseOut = params.reverseOut;

    uint8_t crc = startmask;
    while (length--)
    {
        uint8_t data = *array++;
        if (reverseIn)
            data = reverse8(data);
        crc ^= data;
        for (uint8_t i = 8; i; i--)
        {
            if (crc & 0x80)
            {
                crc <<= 1;
                crc ^= polynome;
            }
            else
            {
                crc <<= 1;
            }
        }
    }
    crc ^= endmask;
    if (reverseOut)
        crc = reverse8(crc);
    return crc;
}
