; audio_data.asm — generated audio data blobs (Tier-1 data; `make assets`).
;
; AudioRom: the four GB audio banks ($02/$08/$1F/$20) as 16 KB images at
; their true GB addresses (slot = 0/1/2/3), so every 16-bit pointer the
; translated engine dereferences resolves at blob + slot*$4000 + (ptr-$4000).
; CryData: 3 bytes per species index (base cry id, pitch mod, length mod),
; consumed by GetCryData when the cry path lands (Task 5+).

section .data

global AudioRom
global AudioRomEnd
global CryData
global CryDataEnd

%include "assets/audio_rom.inc"
%include "assets/cry_data.inc"
