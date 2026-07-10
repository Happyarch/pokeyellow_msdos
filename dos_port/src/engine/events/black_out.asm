; black_out.asm — ResetStatusAndHalveMoneyOnBlackout (pret engine/events/black_out.asm).
;
; The blackout bookkeeping half: clear the transient player/battle state, halve
; the player's money (3-byte BCD), arm the escape-warp flags so
; PrepareForSpecialWarp sends the player to their last Pokémon Center, and tail
; into HealParty. Reached from HandleBlackOut (home/overworld.asm, ported into
; engine/overworld/overworld.asm) via `callfar`.
;
; Register map (CLAUDE.md): A→AL, HL→ESI, BC→BX, DE→EDX; EBP = GB memory base.
;
; Build: nasm -f coff -I include/ -I . -o black_out.o black_out.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global ResetStatusAndHalveMoneyOnBlackout

extern HasEnoughMoney       ; home/money.asm — CF=1 => not enough (compares wPlayerMoney vs hMoney)
extern DivideBCDPredef3     ; engine/math/bcd.asm (predef; quotient lands on the divisor bytes)
extern HealParty            ; engine/events/heal_party.asm

section .text

; ---------------------------------------------------------------------------
; ResetStatusAndHalveMoneyOnBlackout — pret engine/events/black_out.asm
; Tail-jumps into HealParty (pret: `predef_jump HealParty`).
; ---------------------------------------------------------------------------
ResetStatusAndHalveMoneyOnBlackout:
    xor al, al
    mov [ebp + wPikachuCollisionCounter], al
    xor al, al                               ; pret: "gamefreak copypasting functions (double xor a)"
    mov [ebp + wBattleResult], al
    mov [ebp + W_WALK_BIKE_SURF_STATE], al
    mov [ebp + wIsInBattle], al
    mov [ebp + wMapPalOffset], al
    mov [ebp + W_NPC_MOVEMENT_SCRIPT_FUNCTION_NUM], al
    mov [ebp + H_JOY_HELD], al               ; ldh [hJoyHeld], a
    mov [ebp + wNPCMovementScriptPointerTableNum], al
    mov [ebp + wMiscFlags], al

    ; hMoney = 0, then "do we have at least 0 money?" — always yes.
    mov [ebp + H_MONEY], al
    mov [ebp + H_MONEY + 1], al
    mov [ebp + H_MONEY + 2], al
    call HasEnoughMoney
    jc .lostmoney                            ; jr c — never happens (pret's own comment)

    ; Halve the player's money: hMoney = wPlayerMoney; hDivideBCDDivisor = 2.
    ; 3-byte BCD, stored high byte first — copy verbatim, never byte-swap.
    mov al, [ebp + wPlayerMoney]
    mov [ebp + H_MONEY], al
    mov al, [ebp + wPlayerMoney + 1]
    mov [ebp + H_MONEY + 1], al
    mov al, [ebp + wPlayerMoney + 2]
    mov [ebp + H_MONEY + 2], al

    xor al, al
    mov [ebp + H_DIVIDE_BCD_DIVISOR], al
    mov [ebp + H_DIVIDE_BCD_DIVISOR + 1], al
    mov byte [ebp + H_DIVIDE_BCD_DIVISOR + 2], 2
    call DivideBCDPredef3                    ; predef DivideBCDPredef3

    ; hDivideBCDQuotient unions hDivideBCDDivisor at $FFA2 (golden sym), so the
    ; quotient is read back from the same three bytes the divisor occupied.
    mov al, [ebp + H_DIVIDE_BCD_QUOTIENT]
    mov [ebp + wPlayerMoney], al
    mov al, [ebp + H_DIVIDE_BCD_QUOTIENT + 1]
    mov [ebp + wPlayerMoney + 1], al
    mov al, [ebp + H_DIVIDE_BCD_QUOTIENT + 2]
    mov [ebp + wPlayerMoney + 2], al

.lostmoney:
    ; Arm the special-warp flags PrepareForSpecialWarp reads.
    or  byte [ebp + W_STATUS_FLAGS_6], (1 << BIT_FLY_OR_DUNGEON_WARP)
    and byte [ebp + W_STATUS_FLAGS_6], (~(1 << BIT_FLY_WARP)) & 0xFF
    or  byte [ebp + W_STATUS_FLAGS_6], (1 << BIT_ESCAPE_WARP)

    mov byte [ebp + W_JOY_IGNORE], PAD_BUTTONS | PAD_CTRL_PAD
    jmp HealParty                            ; predef_jump HealParty
