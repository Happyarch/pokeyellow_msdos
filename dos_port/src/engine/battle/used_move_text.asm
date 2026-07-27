; used_move_text.asm — DisplayUsedMoveText, the "<USER> used <MOVE>!" line.
;
; Mirror of pret engine/battle/used_move_text.asm. It holds that file's FIRST
; label and only executable one; it arrived here in chunk 18 of the
; relocated-label grind, from src/engine/battle/core.asm.
;
; WHAT THIS MIRROR DOES NOT HOLD, measured from the labels table:
;   EndUsedMove1Text..EndUsedMove5Text  translated, in assets/battle_text.inc
;                                       (generated Tier-1 data; externed here)
;   UsedMoveText, UsedMove1Text, UsedMove2Text, UsedMoveText_CheckObedience,
;   MoveNameText, GetMoveGrammar        all `missing` — the port composes the
;                                       line in code rather than running pret's
;                                       text_asm chain, so these have no port body
;
; The port's DisplayUsedMoveText builds the stream into the dialog buffer
; directly because pret's version is text_asm-composed and the generator skips
; it. <USER> ($5A) is still resolved by the text engine, so the rendered result
; matches.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
;
; Build: nasm -f coff -I include/ -I . -o used_move_text.o used_move_text.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global DisplayUsedMoveText

extern PlaceString                   ; src/home/text.asm
extern FindMoveName                  ; src/engine/battle/battle_menu.asm
extern RunBattleTextStream           ; src/engine/battle/core.asm
extern str_used_grammar              ; assets/battle_core_runtime_strings.inc via engine/battle/core.asm

section .text

; ---------------------------------------------------------------------------
; DisplayUsedMoveText — pret engine/battle/used_move_text.asm (text_asm-composed).
; Builds "<USER> used <MOVE>!" into the dialog buffer and prints it (no wait —
; pret's text ends in text_end). <USER> ($5A) is resolved by the text engine
; (player nick, or "Enemy "+enemy nick on the enemy's turn).
; ---------------------------------------------------------------------------
DisplayUsedMoveText:
    lea edi, [ebp + NPC_DIALOG_BUF]
    mov byte [edi], 0x00                ; TX_START
    inc edi
    mov byte [edi], 0x5A                ; <USER>
    inc edi
    mov esi, str_used_grammar           ; " used "
    call .copyFlat
    movzx eax, byte [ebp + hWhoseTurn]
    test al, al
    jz  .playerName
    mov al, [ebp + wEnemySelectedMove]
    jmp .gotId
.playerName:
    mov al, [ebp + wPlayerSelectedMove]
.gotId:
    call FindMoveName                   ; EAX = flat ptr to the move name
    mov esi, eax
    call .copyFlat
    mov byte [edi], 0xE7                ; '!'
    inc edi
    mov byte [edi], 0x50                ; '@' (PlaceString terminator)
    inc edi
    mov byte [edi], 0x50                ; TX_END
    jmp RunBattleTextStream
.copyFlat:                              ; copy a $50-terminated flat string [ESI] → [EDI]
    mov al, [esi]
    cmp al, 0x50
    je  .copyDone
    mov [edi], al
    inc edi
    inc esi
    jmp .copyFlat
.copyDone:
    ret
