# Innovation SSI-2001 replica (AmiBay) — evidence notes

Source: https://www.amibay.com/threads/innovation-ssi-2001-replica.95017/
Fetched: 2026-09-18 (200 OK). Sales thread for the VOGONS/Phantom
replica — kept as corroboration for card-level claims, NOT a programming manual
(schematics/replicas are not programming docs).

## Corroborated claims

- ISA 8-bit slot; MOS6581 (or 8580 in the replica) on the ISA bus.
- SID clock configurable: **0.89 MHz (original SSI-2001)** or 1.02 MHz (C64 NTSC).
- Selectable SID register port address: 0x280, 0x2A0, 0x2C0, 0x2E0
  (thread text literally prints "0x2C00" once — a typo for 0x2C0).
- Standard joystick port (0x201), switch-off-able. 3.5 mm out/in (+internal header).
- Replica changes vs original: 6581 needs +12 V, 8580 needs +9 V regulator
  (ISA has no 9 V rail); POT X/Y brought out to C64 joystick inputs on the replica
  (unconnected on the original); SID audio-in shunted to ground when disconnected.

## Modern-player note (context, not port evidence)

Thread claims the replica now plays MIDI (*.MID via PX Player) and *.SID files and
has 100+ game support via AIL/MIDPAK/Miles — a modern software ecosystem, not
period support. Period support stays at the ~15-game DOSBox-Staging list.
