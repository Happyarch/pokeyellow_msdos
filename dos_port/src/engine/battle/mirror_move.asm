; mirror_move.asm — MirrorMoveCopyMove / ReloadMoveData / IncrementMovePP
; (battle-engine move-effect translation swarm).
;
; Faithful translation of engine/battle/core.asm:MirrorMoveCopyMove,
; ReloadMoveData, IncrementMovePP (pret/pokeyellow, ~line 5132 onward).
;
; MirrorMoveCopyMove copies the target's last-used move into the acting side's
; SelectedMove slot (failing if the target hasn't moved yet, or last used
; Mirror Move itself) and tail-jumps into the shared ReloadMoveData helper.
; ReloadMoveData (also used by Metronome — see scratch/metronome.asm, a sibling
; file in this swarm) reloads the picked move's 6-byte record from the flat
; `Moves` table into the acting side's wPlayerMoveNum/wEnemyMoveNum struct,
; restores the move's PP (IncrementMovePP — undoing the double PP loss that
; would otherwise happen when one move runs another within the same turn), and
; reloads the move's name into wStringBuffer.
;
; Fidelity boundary: docs/plans/move_translation_divergence.md. Divergences are
; called out inline below; §2 (bank-switch drop) is allowlisted. The FarCopyData
; substitution is NOT on the allowlist verbatim — it's a necessary consequence of
; §2 (Moves has no bank in the flat model, and is a flat table, not GB WRAM) —
; see the comment at ReloadMoveData for the full reasoning; it mirrors existing
; precedent in get_current_move.asm for the identical situation.
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH,C=BL), DE=EDX, HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]. hWhoseTurn is HRAM (0xFFF3), accessed the same way as
; the rest of the swarm (poison.asm, metronome.asm, residual_damage.asm).
;
; Build: nasm -f coff -I include/ -I . -o mirror_move.o mirror_move.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global MirrorMoveCopyMove
global ReloadMoveData
global IncrementMovePP

; --- shared scaffold externs (call, never define) ---
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern GetMoveName                  ; home/names.asm — index [wNamedObjectIndex] -> wNameBuffer
extern CopyToStringBuffer            ; engine/battle/core.asm (global) — EDX = source '@'-str
extern AddNTimes                    ; home/array.asm — ESI += BX*AL
extern Moves                        ; data/pokemon_data.asm (assets/moves.inc) — flat table,
                                      ; MOVE_LENGTH(6)-byte records, move-id order
extern MirrorMoveFailedText          ; assets/battle_text.inc (global)

; MIRROR_MOVE move id (constants/move_constants.asm: `const MIRROR_MOVE ; 77` = 0x4D).
; Not carried in gb_constants.inc — used raw per ticket instruction.
MIRROR_MOVE equ 0x4D

; wEnemyMon1PP now lives in gb_memmap.inc (0xD8C0) — added during integration.

; ===========================================================================
; MirrorMoveCopyMove — pret core.asm:5132. Copies the target's last-used move
; (wEnemyUsedMove on the player's turn, wPlayerUsedMove on the enemy's turn)
; into the acting side's SelectedMove slot, then tail-jumps into ReloadMoveData.
; Fails (AL=0, ZF=1) if the target hasn't used a move yet, or if the target's
; last move was Mirror Move itself (Gen-1: Mirror Move can't mirror Mirror Move).
; Out: ZF=1 -> failed (caller: jz ExecutePlayerMoveDone); ZF=0 -> success,
;      control passed into ReloadMoveData (falls through / tail-jumps).
; ===========================================================================
MirrorMoveCopyMove:
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    test al, al                         ; and a  (ZF tested below; not clobbered by
                                          ;         the plain `mov`s that follow)
    ; values for player turn
    mov al, [ebp + wEnemyUsedMove]      ; ld a, [wEnemyUsedMove]
    mov esi, wPlayerSelectedMove        ; ld hl, wPlayerSelectedMove
    mov edx, wPlayerMoveNum             ; ld de, wPlayerMoveNum
    jz .next                            ; jr z, .next
    ; values for enemy turn
    mov al, [ebp + wPlayerUsedMove]     ; ld a, [wPlayerUsedMove]
    mov edx, wEnemyMoveNum              ; ld de, wEnemyMoveNum
    mov esi, wEnemySelectedMove         ; ld hl, wEnemySelectedMove
.next:
    mov [ebp + esi], al                 ; ld [hl], a
    cmp al, MIRROR_MOVE                 ; did the target last use Mirror Move (and miss)?
    je .mirrorMoveFailed                ; jr z, .mirrorMoveFailed
    test al, al                         ; and a — has the target selected any move yet?
    jnz ReloadMoveData                  ; jr nz, ReloadMoveData (tail jump)
.mirrorMoveFailed:
    mov esi, MirrorMoveFailedText       ; ld hl, MirrorMoveFailedText
    call PrintText
    xor al, al                          ; xor a  (AL=0, ZF=1 -> failure)
    ret

; ===========================================================================
; ReloadMoveData — pret core.asm:5167. Reloads move [AL]'s (1-based id) 6-byte
; record into the struct at [EDX] (wPlayerMoveNum/wEnemyMoveNum), restores its
; PP (IncrementMovePP), and reloads its name into wStringBuffer. Shared tail
; target for MirrorMoveCopyMove and MetronomePickMove (scratch/metronome.asm).
; In:  AL = move id (1-based), EDX = dest struct offset.
; Out: AL=1, ZF=0 (success). ESI/EDX left advanced past the copied range.
; ===========================================================================
ReloadMoveData:
    mov [ebp + wNamedObjectIndex], al   ; ld [wNamedObjectIndex], a
    dec al                              ; dec a
    mov esi, Moves                      ; ld hl, Moves  (flat program-image table)
    mov bx, MOVE_LENGTH                 ; ld bc, MOVE_LENGTH
    call AddNTimes                      ; esi = Moves + (id-1)*MOVE_LENGTH  (flat; AddNTimes
                                          ; does a plain `add esi,ecx` — no EBP bias — so it's
                                          ; safe to use on this flat pointer, exactly as
                                          ; names.asm:GetMonName does for the flat MonsterNames
                                          ; table)
    ; ALLOWLIST (§2 item 4, bank switching): pret does `ld a, BANK(Moves)` here before
    ; FarCopyData. The flat DPMI model has no ROM banks, so that load is dropped entirely
    ; (nothing to translate it into).
    ;
    ; DIVERGENCE (forced by the above, not itself allowlisted — reported per ticket):
    ; pret's next step is `call FarCopyData` (copy MOVE_LENGTH bytes a:HL -> DE). This
    ; port's FarCopyData/CopyData (src/home/copy_data.asm) both do `lea esi, [ebp+esi]`
    ; on the SOURCE: they assume the source is a GB-space offset relative to EBP. `Moves`
    ; is a FLAT program-image label (data/pokemon_data.asm / assets/moves.inc), not a GB
    ; WRAM offset — the identical situation already documented and solved in
    ; get_current_move.asm's "Flat-source note" for this same Moves table. Calling
    ; FarCopyData on the ESI computed above would compute [ebp + (Moves+offset)],
    ; double-counting the bias and copying garbage. So, exactly as get_current_move.asm
    ; already does, this uses an inline flat-src -> WRAM-dst byte copy instead of
    ; FarCopyData/CopyData.
    push ecx
    mov ecx, MOVE_LENGTH
.copy:
    mov al, [esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    dec ecx
    jnz .copy
    pop ecx
    ; the following two calls are used to reload the move's PP and name
    call IncrementMovePP
    call GetMoveName
    ; DIVERGENCE-COMPENSATION (not a bug in this file — a pre-existing gap in the
    ; already-linked GetMoveName): pret's GetMoveName (home/names.asm:129) explicitly
    ; does `ld de, wNameBuffer` right after `call GetName`, so DE is guaranteed to point
    ; at the freshly-loaded name string when the caller (here) falls into
    ; CopyToStringBuffer. The PORT's GetMoveName (dos_port/src/home/names.asm) instead
    ; tail-jumps into GetName (`jmp GetName`) and never sets EDX = wNameBuffer itself
    ; before returning — GetName's own `.walk`/GetMonName paths never touch EDX either.
    ; Left alone, EDX here would still hold the stale wPlayerMoveNum/wEnemyMoveNum offset
    ; from earlier in this routine, and CopyToStringBuffer would copy the wrong bytes.
    ; Set EDX = wNameBuffer explicitly to preserve ReloadMoveData's faithful behavior
    ; without editing names.asm (out of scope for this file).
    mov edx, wNameBuffer
    call CopyToStringBuffer
    mov al, 1                           ; ld a, $01
    test al, al                         ; and a  (AL=1, ZF=0 -> success)
    ret

; ===========================================================================
; IncrementMovePP — pret core.asm:5214. Increments PP for the move at
; [wPlayerMoveListIndex]/[wEnemyMoveListIndex] in BOTH the currently-battling
; copy (wBattleMonPP/wEnemyMonPP) and the underlying party-mon copy
; (wPartyMon1PP/wEnemyMon1PP, offset by the active party position), so that a
; move which runs another move within the same turn (Mirror Move, Metronome)
; doesn't lose 2 PP net.
; ===========================================================================
IncrementMovePP:
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    test al, al                         ; and a
    ; values for player turn
    mov esi, wBattleMonPP               ; ld hl, wBattleMonPP
    mov edx, wPartyMon1PP               ; ld de, wPartyMon1PP
    mov al, [ebp + wPlayerMoveListIndex]; ld a, [wPlayerMoveListIndex]
    jz .next                            ; jr z, .next
    ; values for enemy turn
    mov esi, wEnemyMonPP                ; ld hl, wEnemyMonPP
    mov edx, wEnemyMon1PP               ; ld de, wEnemyMon1PP  (derived above)
    mov al, [ebp + wEnemyMoveListIndex] ; ld a, [wEnemyMoveListIndex]
.next:
    mov bh, 0                           ; ld b, $00
    mov bl, al                          ; ld c, a
    movzx ecx, bx                       ; add hl, bc  (16-bit add, zero-extended per
    add esi, ecx                        ;              src/home/move_mon.asm precedent)
    inc byte [ebp + esi]                ; inc [hl]  — battle-mon copy's PP
    mov esi, edx                        ; ld h, d / ld l, e
    add esi, ecx                        ; add hl, bc  (same bc: move-list index)
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    test al, al                         ; and a
    mov al, [ebp + wPlayerMonNumber]    ; ld a, [wPlayerMonNumber]  (value for player turn)
    jz .updatePP                        ; jr z, .updatePP
    mov al, [ebp + wEnemyMonPartyPos]   ; ld a, [wEnemyMonPartyPos]  (value for enemy turn)
.updatePP:
    mov bx, PARTYMON_STRUCT_LENGTH      ; ld bc, PARTYMON_STRUCT_LENGTH
    call AddNTimes                      ; esi += PARTYMON_STRUCT_LENGTH * (party position)
    inc byte [ebp + esi]                ; inc [hl]  — party-mon copy's PP
    ret
