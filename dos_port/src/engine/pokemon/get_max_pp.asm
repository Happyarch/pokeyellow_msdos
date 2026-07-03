; get_max_pp.asm — GetMaxPP + AddBonusPP + GetSelectedMoveOffset.
;
; Faithful port of pret engine/items/item_effects.asm:GetMaxPP (and its helpers
; AddBonusPP / GetSelectedMoveOffset / GetSelectedMoveOffset2). Split into its own
; file (like knows_hm_move.asm) so it links independently of the still-deferred
; item-USE dispatch. Computes the PP-Up-adjusted max PP of move [wCurrentMenuItem]
; of the mon at [wWhichPokemon] in list [wMonDataLocation], into [wMaxPP].
;
; The port's Moves table is a flat program-image label (no ROM bank), so the base
; max PP is read directly from Moves rather than pret's FarCopyData-into-wMoveData;
; the base byte is still staged at wMoveData+MOVE_PP where AddBonusPP reads it.
;
; Build: nasm -f coff -I include/ -I . -o get_max_pp.o get_max_pp.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global GetMaxPP
global GetSelectedMoveOffset
global GetSelectedMoveOffset2

extern AddNTimes
extern Divide
extern Moves                                         ; flat move-data table

; ---------------------------------------------------------------------------
; GetSelectedMoveOffset — ESI (hl) = move-list base + wWhichPokemon*BX + menu item.
; GetSelectedMoveOffset2 — ESI += wCurrentMenuItem only.  In: ESI = list base,
; BX = per-mon struct stride.  Out: ESI = GB offset of the selected move id byte.
; ---------------------------------------------------------------------------
GetSelectedMoveOffset:
    mov al, [ebp + wWhichPokemon]
    call AddNTimes                                   ; ESI += AL * BX (AL cleared, BX kept)
GetSelectedMoveOffset2:
    movzx ecx, byte [ebp + wCurrentMenuItem]
    add esi, ecx
    ret

; ---------------------------------------------------------------------------
; GetMaxPP — [wMaxPP] = max PP (incl. PP-Up bonus) of the selected move.
; ---------------------------------------------------------------------------
GetMaxPP:
    ; --- pick the source move list into ESI, per-mon stride into BX ---
    mov al, [ebp + wMonDataLocation]
    test al, al
    mov esi, wPartyMon1Moves
    mov bx, PARTYMON_STRUCT_LENGTH
    jz .multi
    mov esi, wEnemyMon1Moves
    dec al
    jz .multi
    mov esi, wBoxMon1Moves
    mov bx, BOXMON_STRUCT_LENGTH
    dec al
    jz .multi
    mov esi, wDayCareMonMoves
    dec al
    jz .oneMon
    mov esi, wBattleMonMoves                          ; player's in-battle mon (loc 4)
.oneMon:
    call GetSelectedMoveOffset2
    jmp .next
.multi:
    call GetSelectedMoveOffset
.next:
    ; ESI = GB offset of the selected move's id byte
    movzx eax, byte [ebp + esi]                       ; move id
    dec eax
    imul eax, eax, MOVE_LENGTH                        ; (id-1) * MOVE_LENGTH
    movzx edx, byte [Moves + eax + MOVE_PP]           ; base (normal) max PP
    mov [ebp + wMoveData + MOVE_PP], dl               ; stage where AddBonusPP reads [de]
    ; step from the move slot to the same-index PP byte within the mon struct
    mov ecx, MON_PP - MON_MOVES
    cmp byte [ebp + wMonDataLocation], BATTLE_MON_DATA
    jne .addPPOffset
    mov ecx, wBattleMonPP - wBattleMonMoves
.addPPOffset:
    add esi, ecx                                      ; ESI = current-PP byte for this move
    movzx eax, byte [ebp + esi]
    and al, PP_UP_MASK                                ; keep the PP-Up bits
    or al, dl                                         ; a = PP-Up bits | normal max PP
    mov [ebp + wPPUpCountAndMaxPP], al                ; work byte (hl)
    mov byte [ebp + wUsingPPUp], 0                    ; not applying a PP Up right now
    mov edx, wMoveData + MOVE_PP                      ; AddBonusPP: de = base-PP addr
    mov esi, wPPUpCountAndMaxPP                        ; AddBonusPP: hl = work byte
    call AddBonusPP
    movzx eax, byte [ebp + wPPUpCountAndMaxPP]
    and al, PP_MASK                                   ; strip the PP-Up bits → max PP
    mov [ebp + wMaxPP], al
    ret

; ---------------------------------------------------------------------------
; AddBonusPP — add the PP-Up bonus to the work byte at [ESI] (hl).
; In:  EDX = GB addr of the move's normal max PP (de); ESI = work byte (hl,
;      = PP-Up bits | normal max PP); [wUsingPPUp] = 1 to add one bonus only.
; Out: [ESI] = work byte with the PP-Up bonus folded in.
; ---------------------------------------------------------------------------
AddBonusPP:
    push ebx
    ; hDividend = normal max PP; hQuotient = maxPP / 5
    movzx eax, byte [ebp + edx]
    mov [ebp + hDividend + 3], al
    xor al, al
    mov [ebp + hDividend], al
    mov [ebp + hDividend + 1], al
    mov [ebp + hDividend + 2], al
    mov byte [ebp + hDivisor], 5
    mov bh, 4                                         ; dividend byte count
    call Divide                                       ; preserves BX
    movzx eax, byte [ebp + esi]                       ; work byte
    mov bl, al                                        ; b = running total (8-bit, starts = work byte)
    shr al, 6                                          ; PP-Up count = bits 7-6 (pret swap/and/srl/srl)
    mov cl, al                                        ; c = PP-Up count (8-bit counter — SM83-faithful)
.loop:
    movzx eax, byte [ebp + hQuotient + 3]             ; per-PP-Up bonus = maxPP/5, capped at 7
    cmp al, 8
    jb .addAmount
    mov al, 7
.addAmount:
    add bl, al                                        ; 8-bit add (wraps like SM83 `add b`)
    mov al, [ebp + wUsingPPUp]
    dec al
    jz .done                                          ; applying a PP Up now → add only once
    ; NB: 8-bit `dec cl` (not ecx): c=0 (no PP-Ups) loops 256×, and adding a constant
    ; to the 8-bit BL exactly 256 times is a net no-op (mod 256) → base PP unchanged.
    ; This is how pret's do-while is correct-yet-bounded for 0 PP-Ups; a 32-bit dec
    ; would spin ~4 billion times instead.
    dec cl
    jnz .loop
.done:
    mov [ebp + esi], bl
    pop ebx
    ret
