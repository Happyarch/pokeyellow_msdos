/*
 * gb_synth.cpp — C wrapper around Shay Green's Basic_Gb_Apu (Gb_Snd_Emu).
 *
 * Exposes a clean C ABI for Python ctypes in-process Game Boy APU synthesis.
 * Output: 16-bit signed stereo PCM at 49,716 Hz matching NukedOPL3.
 */

#include <stdint.h>
#include <stdlib.h>
#include "Basic_Gb_Apu.h"

// Default Wave RAM pattern from Pokémon Yellow (audio/wave_samples.asm: .wave0)
static const uint8_t s_default_wave[16] = {
    0x02, 0x46, 0x8A, 0xCE, 0xFF, 0xFE, 0xED, 0xCC,
    0xBA, 0x98, 0x76, 0x54, 0x43, 0x32, 0x21, 0x11
};

static void init_wave_ram(Basic_Gb_Apu* apu) {
    for (int i = 0; i < 16; i++) {
        apu->write_register(0xFF30 + i, s_default_wave[i]);
    }
}

extern "C" {

Basic_Gb_Apu* gb_apu_create(long sample_rate) {
    Basic_Gb_Apu* apu = new Basic_Gb_Apu();
    if (apu) {
        apu->set_sample_rate(sample_rate);
        // Initialize master audio registers
        apu->write_register(0xFF26, 0x80); // NR52: Sound on
        apu->write_register(0xFF24, 0x77); // NR50: Max volume left & right
        apu->write_register(0xFF25, 0xFF); // NR51: Enable all channels to both sides
        init_wave_ram(apu);
    }
    return apu;
}

void gb_apu_destroy(Basic_Gb_Apu* apu) {
    delete apu;
}

void gb_apu_reset(Basic_Gb_Apu* apu) {
    if (apu) {
        // Reset sound chip by toggling NR52 ($FF26)
        apu->write_register(0xFF26, 0x00);
        apu->write_register(0xFF26, 0x80);
        apu->write_register(0xFF24, 0x77);
        apu->write_register(0xFF25, 0xFF);
        init_wave_ram(apu);
    }
}

void gb_apu_write(Basic_Gb_Apu* apu, uint16_t addr, uint8_t data) {
    if (apu) {
        apu->write_register(addr, data);
    }
}

void gb_apu_end_frame(Basic_Gb_Apu* apu) {
    if (apu) {
        apu->end_frame();
    }
}

long gb_apu_samples_avail(Basic_Gb_Apu* apu) {
    return apu ? apu->samples_avail() : 0;
}

long gb_apu_read_samples(Basic_Gb_Apu* apu, int16_t* out, long count) {
    return apu ? apu->read_samples(out, count) : 0;
}

} // extern "C"
