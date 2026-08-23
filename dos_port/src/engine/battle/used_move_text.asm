; used_move_text.asm — the "<USER><LINE>used <MOVE>!" line.
;
; Faithful mirror of pret engine/battle/used_move_text.asm, holding EVERY label
; that file defines except the five EndUsedMoveNText streams (pure text_far/text_end
; wrappers, so Tier-1 data — generated into assets/battle_text.inc and externed).
;
; HISTORY, because the shape of this file changed and the reason matters: the port
; used to compose the line BYTE BY BYTE in WRAM (NPC_DIALOG_BUF) and print it with
; RunBattleTextStream, leaving UsedMoveText, UsedMove1Text, UsedMove2Text,
; UsedMoveText_CheckObedience, MoveNameText and GetMoveGrammar with no port body at
; all. That was not merely unfaithful, it DROPPED TWO BEHAVIOURS:
;   * pret's hook writes the move id to wPlayerUsedMove / wEnemyUsedMove. Nothing in
;     the port ever wrote either byte (they were only ever cleared), so MirrorMove —
;     which reads exactly those two bytes at core.asm's MirrorMoveCopyMove — always
;     saw 0 and could never copy the opponent's move.
;   * the disobedience branch ("instead,") and the whole grammar-set chain were
;     absent; the port printed a single hardcoded " used " sentence.
; The composed-in-WRAM path is gone. Do not reintroduce it.
;
; MECHANISM: pret's chain is four text_asm-bearing wrappers, each of which opens
; with `text_far _XxxText` and then splices real SM83 into the command stream; the
; hook returns HL = the next stream to run, and TextCommandProcessor continues
; there. The port's engine implements both halves natively — TextCommand_FAR
; recurses on a 32-bit flat pointer, TextCommand_START_ASM is
; `push NextTextCommand / jmp esi` (src/home/text.asm) — so the translation is
; literal: the stream IS the code, ESI IS pret's HL, and a hook `ret`s with ESI
; pointing at its successor. Same pattern as home/trainers.asm:TrainerEndBattleText.
;
; The far payloads (_ActorNameText, _UsedMove1Text, _UsedMove2Text, _UsedInsteadText,
; _MoveNameText) are Tier-1 data from tools/generators/gen_used_move_text.py;
; gen_battle_text.py cannot emit them because it INLINES text_far into its wrapper
; and skips any wrapper carrying a text_asm.
;
; _MoveNameText is `text_ram wStringBuffer`, so the printed move name comes from
; wStringBuffer — staged by GetCurrentMove's GetName/CopyToStringBuffer tail
; (and, on the enemy's charging-move re-entry, by EnemyCanExecuteChargingMove's own
; fetch), both in engine/battle/core.asm. Do not fetch the name here.
;
; WHY MoveNameText's HOOK AND .endusedmovetexts ARE UNREACHED IN ENGLISH, and why
; that is correct rather than a porting mistake: _MoveNameText ends with `text "@"`
; and NO text_end, so TextCommand_START leaves the stream pointer one past the '@'
; and the far run BLEEDS into the next bytes in ROM — _EndUsedMove1Text — which
; prints "!" and terminates the whole message on its <DONE>. Control therefore never
; returns to the outer stream, so neither this hook nor GetMoveGrammar's result is
; ever consumed. pret says as much of GetMoveGrammar ("this serves no purpose"); the
; port reproduces it by emitting the five _EndUsedMoveNText payloads immediately
; after _MoveNameText in assets/used_move_text.inc, in pret's data/text/text_2.asm
; order. Both halves are mirrored anyway — an unreached pret body is still a pret
; body, and a Japanese-grammar build would reach them.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
;
; Build: nasm -f coff -I include/ -I . -o used_move_text.o used_move_text.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"

global DisplayUsedMoveText
global UsedMoveText
global UsedMove1Text
global UsedMove2Text
global UsedMoveText_CheckObedience
global MoveNameText
global GetMoveGrammar

extern PrintBattleText               ; src/engine/battle/core.asm — pret PrintText,
                                     ;   battle msgbox projection (EAX = flat stream)
extern MoveGrammar                   ; generated Tier-1 table, assets/move_grammar.inc
extern EndUsedMove1Text               ; assets/battle_text.inc — the five grammar tails
extern EndUsedMove2Text
extern EndUsedMove3Text
extern EndUsedMove4Text
extern EndUsedMove5Text

section .text

; ---------------------------------------------------------------------------
; DisplayUsedMoveText — pret: ld hl, UsedMoveText / jp PrintText.
; The port routes battle text through PrintBattleText (PrintText plus selecting the
; battle msgbox projection), exactly as the rest of engine/battle/core.asm does.
; ---------------------------------------------------------------------------
DisplayUsedMoveText:
    mov eax, UsedMoveText
    jmp PrintBattleText                 ; jp PrintText

; ---------------------------------------------------------------------------
; UsedMoveText — "<USER>", then pick the grammar/obedience continuation.
; ---------------------------------------------------------------------------
UsedMoveText:
    db TX_FAR
    dd _ActorNameText
    db TX_START_ASM
    ; ld a,[wPlayerMoveNum] / ld hl,wPlayerUsedMove sit BETWEEN the `and a` and the
    ; `jr z` on the SM83 because neither touches F; x86 `mov` is likewise flagless,
    ; so the ZF from `test al, al` survives to the branch unchanged.
    mov al, [ebp + hWhoseTurn]
    test al, al
    mov al, [ebp + wPlayerMoveNum]
    mov esi, wPlayerUsedMove
    jz .playerTurn
    mov al, [ebp + wEnemyMoveNum]
    mov esi, wEnemyUsedMove
.playerTurn:
    mov [ebp + esi], al                 ; ld [hl], a — the byte MirrorMove reads
    mov [ebp + wMoveGrammar], al
    call GetMoveGrammar
    mov al, [ebp + wMonIsDisobedient]
    test al, al
    mov esi, UsedMove2Text
    jnz .done                           ; ret nz
    mov al, [ebp + wMoveGrammar]
    cmp al, 3
    mov esi, UsedMove2Text
    jb .done                            ; ret c  (SM83 cp is unsigned)
    mov esi, UsedMove1Text
.done:
    ret

; ---------------------------------------------------------------------------
UsedMove1Text:
    db TX_FAR
    dd _UsedMove1Text
    db TX_START_ASM
    jmp UsedMoveText_CheckObedience     ; jr UsedMoveText_CheckObedience

; ---------------------------------------------------------------------------
UsedMove2Text:
    db TX_FAR
    dd _UsedMove2Text
    db TX_START_ASM
    ; fall through

UsedMoveText_CheckObedience:
    mov al, [ebp + wMonIsDisobedient]
    test al, al
    jz .GetMoveNameText
    mov esi, .UsedInsteadText           ; print "instead,"
    ret

.UsedInsteadText:
    db TX_FAR
    dd _UsedInsteadText
    db TX_START_ASM
    ; fall through

.GetMoveNameText:
    mov esi, MoveNameText
    ret

; ---------------------------------------------------------------------------
; MoveNameText — print wStringBuffer (the move name), then tail off to the
; EndUsedMoveNText for this grammar set.
; ---------------------------------------------------------------------------
MoveNameText:
    db TX_FAR
    dd _MoveNameText
    db TX_START_ASM
    ; pret: ld hl,.endusedmovetexts / ld a,[wMoveGrammar] / add a / push bc /
    ;       ld b,0 / ld c,a / add hl,bc / pop bc / ld a,[hli] / ld h,[hl] / ld l,a.
    ; pret scales by 2 for its dw table; the flat port's entries are dd, so 4.
    ; wMoveGrammar is a GROUP index (0-4) written by GetMoveGrammar, never a move id.
    movzx ecx, byte [ebp + wMoveGrammar]
    mov esi, [.endusedmovetexts + ecx * 4]
    ret

; Entries correspond to MoveGrammar sets. Never executed — reached only as data,
; immediately after the `ret` above, exactly where pret puts it.
.endusedmovetexts:
    dd EndUsedMove1Text
    dd EndUsedMove2Text
    dd EndUsedMove3Text
    dd EndUsedMove4Text
    dd EndUsedMove5Text

; ---------------------------------------------------------------------------
; GetMoveGrammar — map the move id in wMoveGrammar to its grammar-set index,
; writing the index back over it.
;
; This function is redundant in the English localization. In Japanese, it selects
; one of 5 distinct sentence structures. In English, all of these sentences have
; the exact same structure, so this serves no purpose. (pret's own comment; the
; base game still walks the table, so the port does too.)
;
; Counter note: no counter here — the walk is table-terminated ($FF), and the
; -1 sentinel is checked BEFORE the match, exactly as pret does.
; ---------------------------------------------------------------------------
GetMoveGrammar:
    push ebx                            ; push bc
    mov al, [ebp + wMoveGrammar]        ; move ID
    mov bl, al                          ; ld c, a
    mov bh, 0                           ; ld b, $0
    mov esi, MoveGrammar                ; flat table (program image, not GB memory)
.loop:
    mov al, [esi]
    inc esi
    cmp al, 0xFF                        ; end of table?
    je .end
    cmp al, bl                          ; match?
    je .end
    test al, al                         ; advance grammar type at 0
    jnz .loop
    inc bh                              ; next grammar type
    jmp .loop
.end:
    mov al, bh                          ; wMoveGrammar now contains move grammar
    mov [ebp + wMoveGrammar], al
    pop ebx                             ; pop bc
    ret

section .data
align 4
%include "assets/used_move_text.inc"
