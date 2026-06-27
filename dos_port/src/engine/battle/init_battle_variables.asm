; init_battle_variables.asm — InitBattleVariables (battle front-end, Wave 2 Stage 0).
;
; Faithful translation of engine/battle/init_battle_variables.asm:InitBattleVariables.
; Clears the battle WRAM scratch area, primes the test-battle move (POUND=1), and
; sets BATTLE_TYPE_SAFARI when the current map is in the Safari Zone range.
;
; Register map: A=AL, HL=ESI, EBP=GB memory base; GB memory = [EBP+addr].
; `ld [hli],a` = mov [ebp+esi],al ; inc esi.
;
%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32
section .text

global InitBattleVariables

InitBattleVariables:
    mov al, [ebp + hTileAnimations]
    mov [ebp + wSavedTileAnimations], al
    xor al, al
    mov [ebp + wActionResultOrTookBattleTurn], al
    mov [ebp + wBattleResult], al
    ; wPartyAndBillsPCSavedMenuItem[0..3] = 0  (ld [hli]a ×3 + ld [hl],a)
    mov esi, wPartyAndBillsPCSavedMenuItem
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    mov [ebp + wListScrollOffset], al
    mov [ebp + wCriticalHitOrOHKO], al
    mov [ebp + wBattleMonSpecies], al
    mov [ebp + wPartyGainExpFlags], al
    mov [ebp + wPlayerMonNumber], al
    mov [ebp + wEscapedFromBattle], al
    mov [ebp + wMapPalOffset], al
    mov [ebp + wPlayerHPBarColor], al        ; ld [hli],a (wPlayerHPBarColor)
    mov [ebp + wEnemyHPBarColor], al         ; ld [hl],a  (wEnemyHPBarColor)
    ; clear the wMiscBattleData block (wCanEvolveFlags .. wMiscBattleDataEnd)
    mov esi, wMiscBattleData
    mov cl, wMiscBattleDataEnd - wMiscBattleData
.loop:
    mov [ebp + esi], al
    inc esi
    dec cl
    jnz .loop
    inc al                                   ; a = 1 (POUND)
    mov [ebp + wTestBattlePlayerSelectedMove], al
    mov al, [ebp + wCurMap]
    cmp al, SAFARI_ZONE_EAST
    jc .notSafariBattle                      ; map < first safari map
    cmp al, SAFARI_ZONE_CENTER_REST_HOUSE
    jnc .notSafariBattle                     ; map >= rest-house (past safari range)
    mov al, BATTLE_TYPE_SAFARI
    mov [ebp + wBattleType], al
.notSafariBattle:
    ; TODO-HW: jpfar PlayBattleMusic — audio HAL deferred (Wave-2 audio cross-cut).
    ret
