/*
 * midi_out.cpp — Host-side ALSA sequencer client for low-latency MIDI output.
 *
 * Connects directly to MT-32 (MUNT) or General MIDI (fluidsynth) ALSA sequencer
 * ports without external dependencies beyond libasound.
 */

#include <alsa/asoundlib.h>
#include <stdlib.h>
#include <stdint.h>

struct MidiOut {
    snd_seq_t* seq;
    snd_midi_event_t* coder;
    int port;
    int dest_client;
    int dest_port;
};

extern "C" {

MidiOut* midi_open(const char* name, int dest_client, int dest_port) {
    MidiOut* m = (MidiOut*)calloc(1, sizeof(MidiOut));
    if (!m) return NULL;
    if (snd_seq_open(&m->seq, "default", SND_SEQ_OPEN_OUTPUT, 0) < 0) {
        free(m);
        return NULL;
    }
    snd_seq_set_client_name(m->seq, name ? name : "Audition");
    m->port = snd_seq_create_simple_port(m->seq, "out",
        SND_SEQ_PORT_CAP_READ | SND_SEQ_PORT_CAP_SUBS_READ,
        SND_SEQ_PORT_TYPE_APPLICATION);
    if (m->port < 0) {
        snd_seq_close(m->seq);
        free(m);
        return NULL;
    }
    if (snd_seq_connect_to(m->seq, m->port, dest_client, dest_port) < 0) {
        snd_seq_close(m->seq);
        free(m);
        return NULL;
    }
    m->dest_client = dest_client;
    m->dest_port = dest_port;
    snd_midi_event_new(512, &m->coder);
    return m;
}

void midi_send_bytes(MidiOut* m, const uint8_t* bytes, int len) {
    if (!m || !m->seq || !m->coder || !bytes || len <= 0) return;
    snd_seq_event_t ev;
    for (int i = 0; i < len; i++) {
        long res = snd_midi_event_encode_byte(m->coder, bytes[i], &ev);
        if (res > 0) {
            snd_seq_ev_set_source(&ev, m->port);
            snd_seq_ev_set_subs(&ev);
            snd_seq_ev_set_direct(&ev);
            snd_seq_event_output_direct(m->seq, &ev);
        }
    }
}

void midi_all_notes_off(MidiOut* m) {
    if (!m) return;
    for (int ch = 0; ch < 16; ch++) {
        uint8_t cc_all_off[] = { (uint8_t)(0xB0 | ch), 123, 0 };
        midi_send_bytes(m, cc_all_off, 3);
        uint8_t cc_sound_off[] = { (uint8_t)(0xB0 | ch), 120, 0 };
        midi_send_bytes(m, cc_sound_off, 3);
    }
}

void midi_close(MidiOut* m) {
    if (!m) return;
    if (m->seq) {
        midi_all_notes_off(m);
        if (m->coder) snd_midi_event_free(m->coder);
        snd_seq_close(m->seq);
    }
    free(m);
}

}
