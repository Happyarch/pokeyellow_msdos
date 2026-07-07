; alternate_tempo.asm — pret audio/alternate_tempo.asm translated to x86.
;
; Script-triggered music variants: MeetRival with an alternate first measure
; and/or slower tempo, and the Hall of Fame's slowed Cities1. Each plays the
; base song via PlayMusic, then rewrites channel command pointers to the
; alternate streams (GB addresses inside the blob; both songs are bank $02).
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB memory base.

%include "gb_memmap.inc"
%include "assets/audio_constants.inc"

global Music_RivalAlternateStart
global Music_RivalAlternateTempo
global Music_RivalAlternateStartAndTempo
global Music_Cities1AlternateTempo
global Audio1_OverwriteChannelPointer

extern PlayMusic                  ; src/home/audio.asm
extern DelayFrames                ; src/video/frame.asm

section .text

; an alternate start for MeetRival which has a different first measure
Music_RivalAlternateStart:
    mov bl, AUDIO_BANK_1                ; = BANK(Music_MeetRival), $02
    mov al, MUSIC_MEET_RIVAL
    call PlayMusic
    mov esi, wChannelCommandPointers
    mov dx, GB_MUSIC_MEETRIVAL_CH1_ALTERNATESTART
    call Audio1_OverwriteChannelPointer
    mov dx, GB_MUSIC_MEETRIVAL_CH2_ALTERNATESTART
    call Audio1_OverwriteChannelPointer
    mov dx, GB_MUSIC_MEETRIVAL_CH3_ALTERNATESTART
    ; fall through

Audio1_OverwriteChannelPointer:
    mov [ebp + esi], dl                 ; pointers stored LE, as everywhere
    inc esi
    mov [ebp + esi], dh
    inc esi
    ret

; an alternate tempo for MeetRival which is slightly slower
Music_RivalAlternateTempo:
    mov bl, AUDIO_BANK_1                ; = BANK(Music_MeetRival)
    mov al, MUSIC_MEET_RIVAL
    call PlayMusic
    mov dx, GB_MUSIC_MEETRIVAL_CH1_ALTERNATETEMPO
    jmp FinishAlternateRivalMusic

; applies both the alternate start and alternate tempo
Music_RivalAlternateStartAndTempo:
    call Music_RivalAlternateStart
    mov dx, GB_MUSIC_MEETRIVAL_CH1_ALTERNATESTARTANDTEMPO
FinishAlternateRivalMusic:
    mov esi, wChannelCommandPointers
    jmp Audio1_OverwriteChannelPointer

; an alternate tempo for Cities1 which is used for the Hall of Fame room
Music_Cities1AlternateTempo:
    mov al, 10
    mov [ebp + wAudioFadeOutCounterReloadValue], al
    mov [ebp + wAudioFadeOutCounter], al
    mov al, 0xFF                        ; stop playing music after the fade-out
    mov [ebp + wAudioFadeOutControl], al
    mov bl, 100
    call DelayFrames                    ; wait for the fade-out to finish
    mov bl, AUDIO_BANK_1                ; = BANK(Music_Cities1), $02
    mov al, MUSIC_CITIES1
    call PlayMusic
    mov esi, wChannelCommandPointers
    mov dx, GB_MUSIC_CITIES1_CH1_ALTERNATETEMPO
    jmp Audio1_OverwriteChannelPointer
