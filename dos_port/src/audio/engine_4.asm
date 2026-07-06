; engine_4.asm — pret audio/engine_4.asm translated to x86.
;
; Engine 4 (GB bank $20) is PlaySound only; it shares AudioCommon_PlaySound
; (engine_1.asm) via its parameter block. Its music-id boundary is $a3
; (bank $20 holds fewer sound headers than the others).

%include "gb_memmap.inc"
%include "assets/audio_constants.inc"

global Audio4_PlaySound

extern AudioCommon_PlaySound      ; src/audio/engine_1.asm
extern AudioRom                   ; src/data/audio_data.asm

section .text

Audio4_PlaySound:
    mov edi, audio4_params
    jmp AudioCommon_PlaySound

section .data

audio4_params:
    dd AudioRom + 3*0x4000              ; bank $20 = blob slot 3
    db MAX_SFX_ID_4
    db 0xA3                             ; music-id boundary
    dw GB_AUDIO4_CRYRET
