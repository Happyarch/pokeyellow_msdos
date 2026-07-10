; play_battle_music.asm — pret audio/play_battle_music.asm translated to x86.
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB memory base.

%include "gb_memmap.inc"
%include "m8_2_pending_symbols.inc"   ; OPP_* trainer ids
%include "assets/audio_constants.inc"

global PlayBattleMusic
; Relocated from pret engine/battle/core.asm (co-located here with the other
; battle-music routines; see tools/pret_label_allowlist.json relocated_labels).
global PlayBattleVictoryMusic
global EndLowHealthAlarm

extern StopAllMusic               ; src/home/audio.asm
extern PlayMusic                  ; src/home/audio.asm
extern DelayFrame                 ; src/video/frame.asm
extern Delay3                     ; src/video/frame.asm

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

; ---------------------------------------------------------------------------
; PlayBattleVictoryMusic — pret engine/battle/core.asm:PlayBattleVictoryMusic.
; In: AL = victory music id (MUSIC_DEFEATED_WILD_MON or MUSIC_DEFEATED_TRAINER).
; Stops the current battle theme and plays the victory jingle, then Delay3.
; The bank is fixed (BANK(Music_DefeatedTrainer) = $08); both victory tracks
; share it, matching pret. Preserves the id in AL across StopAllMusic (pret push/pop af).
; ---------------------------------------------------------------------------
PlayBattleVictoryMusic:
    push eax                       ; pret: push af (keep music id across StopAllMusic)
    call StopAllMusic
    mov bl, AUDIO_BANK_2           ; pret: ld c, BANK(Music_DefeatedTrainer) = $08
    pop eax                        ; pret: pop af
    call PlayMusic                 ; AL = song, BL = bank
    jmp Delay3                     ; pret: jp Delay3 (tail)

; ---------------------------------------------------------------------------
; EndLowHealthAlarm — pret engine/battle/core.asm:EndLowHealthAlarm.
; Called on battle win: turn off the low-health alarm and free its SFX channel.
; DIVERGENCE: pret also sets wLowHealthAlarmDisabled=1 to prevent the alarm from
; reactivating until the next battle. The port's alarm engine does not consult that
; flag (no reader exists in the tree), and the alarm can only re-arm while in battle
; — which is ending here — so the store is inert and omitted (no memmap symbol added).
; ---------------------------------------------------------------------------
EndLowHealthAlarm:
    xor al, al
    mov [ebp + wLowHealthAlarm], al               ; turn off low-health alarm
    mov [ebp + wChannelSoundIDs + CHAN5], al       ; free the alarm's SFX channel
    ret
