"""mt32_presets.py — named program constants for the MIDI override YAMLs.

`mt32_program` / `gm_program` / `program` values in tools/audio/overrides/
*.yaml may be either a raw 0-based program number (what the MIDI Program
Change byte carries) or one of the names below — names are the readable,
hand-editable form (matching how gen_opl_patches.py names its FM patches).

MT32_FACTORY is the Roland MT-32 factory preset bank in program order
(0-based; the LCD shows 1-based, so "Square Wave" here at 47 is the
manual's patch #48). This is the bank a program change selects while
tools/audio/mt32/timbres.yaml uploads no custom timbres; once custom
timbres land, gen_mt32_patches.py's Patch Memory rewrites redefine slots
and those slots' names here stop being true — name the rewritten slots in
timbres.yaml instead.

GM_PROGRAMS is the General MIDI level-1 melodic program list (0-based),
for `gm_program` (fluidsynth / any GM synth via audition.py --target gm).

Name lookup is case- and punctuation-insensitive ("doctor solo",
"DoctorSolo" and "Doctor Solo" all resolve).
"""

from __future__ import annotations

MT32_FACTORY = [
    # 0-7: pianos
    "Acou Piano 1", "Acou Piano 2", "Acou Piano 3",
    "Elec Piano 1", "Elec Piano 2", "Elec Piano 3", "Elec Piano 4",
    "Honkytonk",
    # 8-15: organs
    "Elec Org 1", "Elec Org 2", "Elec Org 3", "Elec Org 4",
    "Pipe Org 1", "Pipe Org 2", "Pipe Org 3", "Accordion",
    # 16-23: keyboards
    "Harpsi 1", "Harpsi 2", "Harpsi 3",
    "Clavi 1", "Clavi 2", "Clavi 3", "Celesta 1", "Celesta 2",
    # 24-31: synth brass / synth bass
    "Syn Brass 1", "Syn Brass 2", "Syn Brass 3", "Syn Brass 4",
    "Syn Bass 1", "Syn Bass 2", "Syn Bass 3", "Syn Bass 4",
    # 32-47: synth
    "Fantasy", "Harmo Pan", "Chorale", "Glasses", "Soundtrack",
    "Atmosphere", "Warm Bell", "Funny Vox", "Echo Bell", "Ice Rain",
    "Oboe 2001", "Echo Pan", "Doctor Solo", "School Daze", "Bell Singer",
    "Square Wave",
    # 48-58: strings
    "Str Sect 1", "Str Sect 2", "Str Sect 3", "Pizzicato",
    "Violin 1", "Violin 2", "Cello 1", "Cello 2", "Contrabass",
    "Harp 1", "Harp 2",
    # 59-63: guitars
    "Guitar 1", "Guitar 2", "Elec Gtr 1", "Elec Gtr 2", "Sitar",
    # 64-71: basses
    "Acou Bass 1", "Acou Bass 2", "Elec Bass 1", "Elec Bass 2",
    "Slap Bass 1", "Slap Bass 2", "Fretless 1", "Fretless 2",
    # 72-77: flutes
    "Flute 1", "Flute 2", "Piccolo 1", "Piccolo 2", "Recorder",
    "Pan Pipes",
    # 78-87: reeds
    "Sax 1", "Sax 2", "Sax 3", "Sax 4", "Clarinet 1", "Clarinet 2",
    "Oboe", "Engl Horn", "Bassoon", "Harmonica",
    # 88-96: brass
    "Trumpet 1", "Trumpet 2", "Trombone 1", "Trombone 2",
    "Fr Horn 1", "Fr Horn 2", "Tuba", "Brs Sect 1", "Brs Sect 2",
    # 97-111: mallets / winds
    "Vibe 1", "Vibe 2", "Syn Mallet", "Wind Bell", "Glock", "Tube Bell",
    "Xylophone", "Marimba", "Koto", "Sho", "Shakuhachi",
    "Whistle 1", "Whistle 2", "Bottleblow", "Breathpipe",
    # 112-127: percussion / effects
    "Timpani", "Melodic Tom", "Deep Snare", "Elec Perc 1", "Elec Perc 2",
    "Taiko", "Taiko Rim", "Cymbal", "Castanets", "Triangle", "Orche Hit",
    "Telephone", "Bird Tweet", "One Note Jam", "Water Bells", "Jungle Tune",
]

GM_PROGRAMS = [
    "Acoustic Grand Piano", "Bright Acoustic Piano", "Electric Grand Piano",
    "Honky-tonk Piano", "Electric Piano 1", "Electric Piano 2",
    "Harpsichord", "Clavinet",
    "Celesta", "Glockenspiel", "Music Box", "Vibraphone", "Marimba",
    "Xylophone", "Tubular Bells", "Dulcimer",
    "Drawbar Organ", "Percussive Organ", "Rock Organ", "Church Organ",
    "Reed Organ", "Accordion", "Harmonica", "Tango Accordion",
    "Acoustic Guitar (nylon)", "Acoustic Guitar (steel)",
    "Electric Guitar (jazz)", "Electric Guitar (clean)",
    "Electric Guitar (muted)", "Overdriven Guitar", "Distortion Guitar",
    "Guitar Harmonics",
    "Acoustic Bass", "Electric Bass (finger)", "Electric Bass (pick)",
    "Fretless Bass", "Slap Bass 1", "Slap Bass 2", "Synth Bass 1",
    "Synth Bass 2",
    "Violin", "Viola", "Cello", "Contrabass", "Tremolo Strings",
    "Pizzicato Strings", "Orchestral Harp", "Timpani",
    "String Ensemble 1", "String Ensemble 2", "Synth Strings 1",
    "Synth Strings 2", "Choir Aahs", "Voice Oohs", "Synth Voice",
    "Orchestra Hit",
    "Trumpet", "Trombone", "Tuba", "Muted Trumpet", "French Horn",
    "Brass Section", "Synth Brass 1", "Synth Brass 2",
    "Soprano Sax", "Alto Sax", "Tenor Sax", "Baritone Sax", "Oboe",
    "English Horn", "Bassoon", "Clarinet",
    "Piccolo", "Flute", "Recorder", "Pan Flute", "Blown Bottle",
    "Shakuhachi", "Whistle", "Ocarina",
    "Lead 1 (square)", "Lead 2 (sawtooth)", "Lead 3 (calliope)",
    "Lead 4 (chiff)", "Lead 5 (charang)", "Lead 6 (voice)",
    "Lead 7 (fifths)", "Lead 8 (bass + lead)",
    "Pad 1 (new age)", "Pad 2 (warm)", "Pad 3 (polysynth)",
    "Pad 4 (choir)", "Pad 5 (bowed)", "Pad 6 (metallic)",
    "Pad 7 (halo)", "Pad 8 (sweep)",
    "FX 1 (rain)", "FX 2 (soundtrack)", "FX 3 (crystal)",
    "FX 4 (atmosphere)", "FX 5 (brightness)", "FX 6 (goblins)",
    "FX 7 (echoes)", "FX 8 (sci-fi)",
    "Sitar", "Banjo", "Shamisen", "Koto", "Kalimba", "Bag Pipe",
    "Fiddle", "Shanai",
    "Tinkle Bell", "Agogo", "Steel Drums", "Woodblock", "Taiko Drum",
    "Melodic Tom", "Synth Drum", "Reverse Cymbal",
    "Guitar Fret Noise", "Breath Noise", "Seashore", "Bird Tweet",
    "Telephone Ring", "Helicopter", "Applause", "Gunshot",
]

assert len(MT32_FACTORY) == 128 and len(GM_PROGRAMS) == 128


def _norm(name: str) -> str:
    return "".join(c for c in name.lower() if c.isalnum())


_LOOKUP = {
    "mt32": {_norm(n): i for i, n in enumerate(MT32_FACTORY)},
    "gm": {_norm(n): i for i, n in enumerate(GM_PROGRAMS)},
}


def resolve_program(value, target: str, context: str) -> int:
    """Program number (0-127) or preset name -> 0-based program number.

    target is "mt32" (factory bank) or "gm" (GM level 1); context names
    the YAML location for error messages.
    """
    if isinstance(value, int):
        if not 0 <= value <= 127:
            raise ValueError(f"{context}: program {value} out of range 0-127")
        return value
    if isinstance(value, str):
        idx = _LOOKUP[target].get(_norm(value))
        if idx is not None:
            return idx
        table = MT32_FACTORY if target == "mt32" else GM_PROGRAMS
        import difflib
        close = difflib.get_close_matches(
            value, table, n=3, cutoff=0.4)
        hint = f" (did you mean {', '.join(map(repr, close))}?)" if close else ""
        raise ValueError(
            f"{context}: unknown {target} preset name {value!r}{hint}")
    raise ValueError(f"{context}: program must be an int or a preset name, "
                     f"got {type(value).__name__}")
