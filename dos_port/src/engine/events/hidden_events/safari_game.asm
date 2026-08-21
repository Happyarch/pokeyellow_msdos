; safari_game.asm — pret engine/events/hidden_events/safari_game.asm translated to x86.
;
; Safari Zone check and game-over handling:
; - SafariZoneCheck: check if in Safari Zone and if balls remain.
; - SafariZoneCheckSteps: decrement step counter, check if 0 steps remain.
; - SafariZoneGameStillGoing: clear game-over flag and return.
; - SafariZoneGameOver: play PA sound, display game over text, warp to gate script.
; - PrintSafariGameOverText: print SafariGameOverText (TimesUpText + GameOverText).
; - SafariGameOverText: text_asm dispatcher.
; - TimesUpText / GameOverText: Tier-1 text data (assets/safari_text.inc).
;
; Register map (CLAUDE.md / asm-translation skill):
;   A -> AL, F -> EFLAGS (ZF, CF)
;   BC -> BX (B = BH, C = BL)
;   DE -> DX (D = DH, E = DL)
;   HL -> ESI
;   EBP = emulated GB memory base ([ebp + SYM])

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "assets/event_constants.inc"
%include "assets/audio_constants.inc"
%include "assets/map_dims.inc"
%include "events.inc"

SCRIPT_SAFARIZONEGATE_LEAVING_SAFARI equ 5

section .text

global SafariZoneCheck
global SafariZoneCheckSteps
global SafariZoneGameStillGoing
global SafariZoneGameOver
global PrintSafariGameOverText
global SafariGameOverText

extern EnableAutoTextBoxDrawing        ; src/home/window.asm
extern StopAllMusic                    ; src/home/audio.asm
extern PlayMusic                       ; src/home/audio.asm
extern g_audio_engine_online           ; src/home/audio.asm
extern DisplayTextID                   ; src/home/text_script.asm
extern PrintText                       ; src/home/window.asm
extern TextScriptEnd                   ; src/home/overworld_text.asm

; ---------------------------------------------------------------------------
; SafariZoneCheck — pret engine/events/hidden_events/safari_game.asm:SafariZoneCheck
; ---------------------------------------------------------------------------
SafariZoneCheck:
    CheckEventHL EVENT_IN_SAFARI_ZONE           ; if we are not in the Safari Zone,
    jz SafariZoneGameStillGoing                 ; don't bother printing game over text
    mov al, [ebp + wNumSafariBalls]
    and al, al
    jz SafariZoneGameOver
    jmp SafariZoneGameStillGoing

; ---------------------------------------------------------------------------
; SafariZoneCheckSteps — pret engine/events/hidden_events/safari_game.asm:SafariZoneCheckSteps
; ---------------------------------------------------------------------------
; DEVIATION{class=data-model; pret=engine/events/hidden_events/safari_game.asm:SafariZoneCheckSteps; behavior=pret IF DEF(_DEBUG) DebugPressedOrHeldB call is omitted in release build; evidence=the port defines no _DEBUG matching retail Yellow where _DEBUG is unset; lifetime=until a debug build defines _DEBUG}
SafariZoneCheckSteps:
    ; (pret _DEBUG block with DebugPressedOrHeldB omitted in release build)
    mov al, [ebp + wSafariSteps]
    mov bh, al
    mov al, [ebp + wSafariSteps + 1]
    mov bl, al
    or al, bh
    jz SafariZoneGameOver
    dec bx
    mov al, bh
    mov [ebp + wSafariSteps], al
    mov al, bl
    mov [ebp + wSafariSteps + 1], al

SafariZoneGameStillGoing:
    xor al, al
    mov [ebp + wSafariZoneGameOver], al
    ret

; ---------------------------------------------------------------------------
; SafariZoneGameOver — pret engine/events/hidden_events/safari_game.asm:SafariZoneGameOver
; ---------------------------------------------------------------------------
; DEVIATION{class=HAL; pret=engine/events/hidden_events/safari_game.asm:SafariZoneGameOver; behavior=poll on wChannelSoundIDs CHAN5 SFX_SAFARI_ZONE_PA early-outs when g_audio_engine_online is 0; evidence=DelayFrame audio tick self-gates on g_audio_engine_online and without the guard the loop spins forever on a machine with no sound card; lifetime=permanent while the port supports running with no sound device}
SafariZoneGameOver:
    call EnableAutoTextBoxDrawing
    xor al, al
    mov [ebp + wAudioFadeOutControl], al
    call StopAllMusic
    mov bl, AUDIO_BANK_1                        ; ld c, BANK(SFX_Safari_Zone_PA)
    mov al, SFX_SAFARI_ZONE_PA
    call PlayMusic
.waitForMusicToPlay:
    cmp byte [g_audio_engine_online], 0
    jz .audioReady
    mov al, [ebp + wChannelSoundIDs + CHAN5]
    cmp al, SFX_SAFARI_ZONE_PA
    jnz .waitForMusicToPlay
.audioReady:
    mov al, TEXT_SAFARI_GAME_OVER
    mov [ebp + hTextID], al                     ; ldh [hTextID], a
    call DisplayTextID
    xor al, al
    mov [ebp + wPlayerMovingDirection], al
    mov al, SAFARI_ZONE_GATE
    mov [ebp + hWarpDestinationMap], al         ; ldh [hWarpDestinationMap], a
    mov al, 3
    mov [ebp + wDestinationWarpID], al
    mov al, SCRIPT_SAFARIZONEGATE_LEAVING_SAFARI
    mov [ebp + wSafariZoneGateCurScript], al
    SetEvent EVENT_SAFARI_GAME_OVER
    mov al, 1
    mov [ebp + wSafariZoneGameOver], al
    ret

; ---------------------------------------------------------------------------
; PrintSafariGameOverText — pret engine/events/hidden_events/safari_game.asm:PrintSafariGameOverText
; ---------------------------------------------------------------------------
PrintSafariGameOverText:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov esi, SafariGameOverText
    jmp PrintText

; ---------------------------------------------------------------------------
; SafariGameOverText — pret engine/events/hidden_events/safari_game.asm:SafariGameOverText
; ---------------------------------------------------------------------------
SafariGameOverText:
    text_asm
    mov al, [ebp + wNumSafariBalls]
    and al, al
    jz .noMoreSafariBalls
    mov esi, TimesUpText
    call PrintText
.noMoreSafariBalls:
    mov esi, GameOverText
    call PrintText
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Tier-1 Generated Text Streams (TimesUpText, GameOverText)
; ---------------------------------------------------------------------------
%include "assets/safari_text.inc"
