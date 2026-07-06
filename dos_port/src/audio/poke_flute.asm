; poke_flute.asm — pret audio/poke_flute.asm translated to x86.
;
; The in-battle pokéflute: starts the "caught mon" fanfare, then immediately
; hijacks the three SFX channels' command pointers to the pokéflute streams.
; The GB_SFX_POKEFLUTE_* constants are the streams' GB addresses inside the
; blob (bank $08 — the fanfare just played from there, so wAudioROMBank is
; already right, exactly as on the GB).
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB memory base.

%include "gb_memmap.inc"
%include "assets/audio_constants.inc"

global Music_PokeFluteInBattle
global Audio2_OverwriteChannelPointer

extern PlaySoundWaitForCurrent    ; src/home/audio.asm

section .text

Music_PokeFluteInBattle:
    ; begin playing the "caught mon" sound effect
    mov al, SFX_CAUGHT_MON
    call PlaySoundWaitForCurrent
    ; then immediately overwrite the channel pointers
    mov esi, wChannelCommandPointers + CHAN5 * 2
    mov dx, GB_SFX_POKEFLUTE_CH5
    call Audio2_OverwriteChannelPointer
    mov dx, GB_SFX_POKEFLUTE_CH6
    call Audio2_OverwriteChannelPointer
    mov dx, GB_SFX_POKEFLUTE_CH7
    ; fall through

Audio2_OverwriteChannelPointer:
    mov [ebp + esi], dl                 ; pointers stored LE, as everywhere
    inc esi
    mov [ebp + esi], dh
    inc esi
    ret
