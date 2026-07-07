; engine_3.asm — pret audio/engine_3.asm translated to x86.
;
; Engine 3 (GB bank $1f) is PlaySound only; it shares AudioCommon_PlaySound
; (engine_1.asm) via its parameter block. Note the music-id boundary is $fd
; here (engines 1/2 use $fe, engine 4 uses $a3).

%include "gb_memmap.inc"
%include "assets/audio_constants.inc"

global Audio3_PlaySound

extern AudioCommon_PlaySound      ; src/audio/engine_1.asm
extern AudioRom                   ; src/data/audio_data.asm

section .text

Audio3_PlaySound:
    mov edi, audio3_params
    jmp AudioCommon_PlaySound

section .data

audio3_params:
    dd AudioRom + 2*0x4000              ; bank $1f = blob slot 2
    db MAX_SFX_ID_3
    db 0xFD                             ; music-id boundary
    dw GB_AUDIO3_CRYRET
