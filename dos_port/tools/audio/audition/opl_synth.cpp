/*
 * opl_synth.cpp — Host-side OPL3 synthesizer wrapper around NukedOPL.
 *
 * Can be compiled as:
 *   1. Shared library (libnukedopl.so) for direct Python ctypes in-process synthesis.
 *   2. Standalone CLI (opl_synth) for pipeline / shell streaming.
 *
 * Licensed under GNU LGPL v2.1 or later (matching NukedOPL).
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "nukedopl.h"

#ifdef _WIN32
#include <io.h>
#include <fcntl.h>
#define SET_BINARY_MODE(handle) _setmode(_fileno(handle), _O_BINARY)
#else
#define SET_BINARY_MODE(handle) ((void)0)
#endif

extern "C" {

opl3_chip* opl_create(uint32_t samplerate) {
    opl3_chip* chip = (opl3_chip*)calloc(1, sizeof(opl3_chip));
    if (chip) {
        OPL3_Reset(chip, samplerate);
    }
    return chip;
}

void opl_destroy(opl3_chip* chip) {
    if (chip) {
        free(chip);
    }
}

void opl_reset(opl3_chip* chip, uint32_t samplerate) {
    if (chip) {
        OPL3_Reset(chip, samplerate);
    }
}

void opl_write(opl3_chip* chip, uint16_t reg, uint8_t val) {
    if (chip) {
        OPL3_WriteReg(chip, reg, val);
    }
}

void opl_generate(opl3_chip* chip, int16_t* buf, uint32_t num_samples) {
    if (chip && buf && num_samples > 0) {
        OPL3_GenerateStream(chip, buf, num_samples);
    }
}

} // extern "C"

#ifndef OPL_LIB_ONLY

int main(int argc, char* argv[]) {
    uint32_t samplerate = 49716;
    if (argc > 1) {
        uint32_t rate = (uint32_t)atoi(argv[1]);
        if (rate >= 8000 && rate <= 96000) {
            samplerate = rate;
        }
    }

    SET_BINARY_MODE(stdin);
    SET_BINARY_MODE(stdout);

    opl3_chip* chip = opl_create(samplerate);
    if (!chip) {
        fprintf(stderr, "opl_synth: failed to allocate OPL3 chip\n");
        return 1;
    }

    int16_t out_buf[4096 * 2]; // interleaved stereo

    while (1) {
        int cmd = fgetc(stdin);
        if (cmd == EOF || cmd == 0xFF) {
            break;
        }

        if (cmd == 0x00) {
            // WriteReg: 2 bytes reg (LE), 1 byte val
            uint8_t reg_lo = (uint8_t)fgetc(stdin);
            uint8_t reg_hi = (uint8_t)fgetc(stdin);
            uint8_t val = (uint8_t)fgetc(stdin);
            uint16_t reg = ((uint16_t)reg_hi << 8) | reg_lo;
            OPL3_WriteReg(chip, reg, val);
        } else if (cmd == 0x01) {
            // Generate: 2 bytes count (LE)
            uint8_t cnt_lo = (uint8_t)fgetc(stdin);
            uint8_t cnt_hi = (uint8_t)fgetc(stdin);
            uint32_t count = ((uint32_t)cnt_hi << 8) | cnt_lo;
            while (count > 0) {
                uint32_t chunk = count > 4096 ? 4096 : count;
                OPL3_GenerateStream(chip, out_buf, chunk);
                if (fwrite(out_buf, sizeof(int16_t) * 2, chunk, stdout) != chunk) {
                    break;
                }
                count -= chunk;
            }
            fflush(stdout);
        } else if (cmd == 0x02) {
            // Reset: 4 bytes samplerate (LE)
            uint8_t b0 = (uint8_t)fgetc(stdin);
            uint8_t b1 = (uint8_t)fgetc(stdin);
            uint8_t b2 = (uint8_t)fgetc(stdin);
            uint8_t b3 = (uint8_t)fgetc(stdin);
            samplerate = ((uint32_t)b3 << 24) | ((uint32_t)b2 << 16) | ((uint32_t)b1 << 8) | b0;
            OPL3_Reset(chip, samplerate);
        }
    }

    opl_destroy(chip);
    return 0;
}

#endif
