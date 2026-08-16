; audio_data.asm — generated audio data blobs (Tier-1 data; `make assets`).
;
; AudioRom: the four GB audio banks ($02/$08/$1F/$20) as 16 KB images at
; their true GB addresses (slot = 0/1/2/3), so every 16-bit pointer the
; translated engine dereferences resolves at blob + slot*$4000 + (ptr-$4000).
; CryData moved to its mirrored carrier src/data/pokemon/cries.asm on 2026-08-16
; (docs/current_plan_data_path_mirror.md).

section .data

global AudioRom
global AudioRomEnd

%include "assets/audio_rom.inc"
