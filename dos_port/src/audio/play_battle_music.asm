; play_battle_music.asm — pret audio/play_battle_music.asm translated to x86.
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB memory base.

%include "gb_memmap.inc"
%include "m8_2_pending_symbols.inc"   ; OPP_* trainer ids
%include "assets/audio_constants.inc"

global PlayBattleMusic

extern StopAllMusic               ; src/home/audio.asm
extern PlayMusic                  ; src/home/audio.asm
extern DelayFrame                 ; src/video/frame.asm

section .text

PlayBattleMusic:
    xor al, al
    mov [ebp + wAudioFadeOutControl], al
    mov [ebp + wLowHealthAlarm], al
    call StopAllMusic
    call DelayFrame
    mov bl, AUDIO_BANK_2                ; = BANK(Music_GymLeaderBattle), $08
    mov al, [ebp + wGymLeaderNo]
    test al, al
    jz .notGymLeaderBattle
    mov al, MUSIC_GYM_LEADER_BATTLE
    jmp .playSong
.notGymLeaderBattle:
    mov al, [ebp + wCurOpponent]
    cmp al, OPP_ID_OFFSET
    jc .wildBattle
    cmp al, OPP_RIVAL3
    jz .finalBattle
    cmp al, OPP_LANCE
    jnz .normalTrainerBattle
    mov al, MUSIC_GYM_LEADER_BATTLE     ; lance also plays gym leader theme
    jmp .playSong
.normalTrainerBattle:
    mov al, MUSIC_TRAINER_BATTLE
    jmp .playSong
.finalBattle:
    mov al, MUSIC_FINAL_BATTLE
    jmp .playSong
.wildBattle:
    mov al, MUSIC_WILD_BATTLE
.playSong:
    jmp PlayMusic
