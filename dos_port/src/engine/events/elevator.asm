; ===========================================================================
; elevator.asm — pret mirror of engine/events/elevator.asm.
;
; pret has TWO elevator files and they are different things:
;   engine/overworld/elevator.asm — ShakeElevator, the ride animation. Mirrored at
;                                   dos_port/src/engine/overworld/elevator.asm.
;   engine/events/elevator.asm    — THIS file: the floor-select menu the elevator
;                                   button text opens, and the warp it writes.
; The routine below first landed in the overworld mirror by mistake;
; lint_pret_labels' `mirror` rule caught it and it was moved here.
;
; Register map (CLAUDE.md): A->AL, B->BH, C->BL, HL->ESI; GB memory = [ebp + SYM].
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"                  ; text_far / text_end

global DisplayElevatorFloorMenu
global WhichFloorText

extern PrintText                        ; src/home/window.asm
extern DisplayListMenuID                ; src/home/list_menu.asm

section .text

; ---------------------------------------------------------------------------
; DisplayElevatorFloorMenu — pret engine/events/elevator.asm:DisplayElevatorFloorMenu
;
; Register map for this routine: B->BH (destination warp ID), C->BL (destination
; map ID), HL->ESI. ESI holds a GB-space offset throughout (dereferenced via
; [ebp+esi]) — every value it is built from (wElevatorWarpMaps, wWarpEntries,
; wWhichPokemon*2) is a GB memory constant/offset, never a flat program pointer.
; The one exception is the PrintText call, whose ESI convention is documented
; flat (src/home/window.asm) — WhichFloorText is program-image data, loaded
; with `mov esi, WhichFloorText`, not `lea esi,[ebp+...]`.
;
; wElevatorWarpMaps is pret's `ds 11 * 2` (ram/wram.asm) — 2-byte entries
; (byte0 = destination warp ID, byte1 = destination map ID; see the
; CeladonMartElevatorWarpMaps `db 5, CELADON_MART_1F` table for the byte
; layout), so `wWhichPokemon * 2` is the correct byte stride here — confirmed
; against the port's own `src/scripts/*_elevator.asm` producers of this table.
;
; pret's `call .UpdateWarp` is placed IMMEDIATELY BEFORE the `.UpdateWarp`
; label with no intervening instruction, so its pushed return address IS the
; entry point of .UpdateWarp: the first `ret` inside the body pops that address
; and re-enters .UpdateWarp, running the body a SECOND time (writing a second
; consecutive wWarpEntries record at ESI+4..+7); the second `ret` then pops the
; real caller's return address. x86 `call`/`ret` behave identically (push
; return addr / pop-and-jump), so a literal `call .UpdateWarp` immediately
; followed by the `.UpdateWarp:` label reproduces this exactly — do not
; "simplify" it to two explicit calls or an inlined double-body.
; ---------------------------------------------------------------------------
DisplayElevatorFloorMenu:
    mov al, [ebp + wStatusFlags5]              ; ld hl, wStatusFlags5 / ld a,[hl]
    push eax                                    ; push af
    or al, 1 << BIT_NO_TEXT_DELAY                ; set BIT_NO_TEXT_DELAY,[hl]
    mov [ebp + wStatusFlags5], al
    mov esi, WhichFloorText                      ; ld hl, WhichFloorText (flat program data)
    call PrintText
    pop eax                                      ; pop af
    mov [ebp + wStatusFlags5], al                ; ld [wStatusFlags5], a

    mov word [ebp + wListPointer], wItemList     ; ld hl,wItemList / ld a,l/[wListPointer] / ld a,h/[wListPointer+1]

    mov al, [ebp + wListScrollOffset]
    push eax                                     ; push af (saved wListScrollOffset)
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wListScrollOffset], al
    mov [ebp + wPrintItemPrices], al
    mov byte [ebp + wListMenuID], SPECIALLISTMENU
    call DisplayListMenuID
    pop eax                                      ; pop bc (bl unused; al = saved wListScrollOffset)
    mov [ebp + wListScrollOffset], al            ; ld a,b / ld [wListScrollOffset],a
    jnc .storeWarp
    ret                                           ; ret c

.storeWarp:
    or byte [ebp + wCurrentMapScriptFlags], (1 << BIT_CUR_MAP_USED_ELEVATOR)

    movzx edx, byte [ebp + wWhichPokemon]         ; ld a,[wWhichPokemon]
    add edx, edx                                  ; add a  (a *= 2; d,e = 0,a in pret)
    lea esi, [wElevatorWarpMaps + edx]            ; ld hl,wElevatorWarpMaps / add hl,de

    mov bh, [ebp + esi]                           ; ld a,[hli] / ld b,a
    inc esi
    mov bl, [ebp + esi]                           ; ld a,[hl]  / ld c,a

    mov esi, wWarpEntries                         ; ld hl, wWarpEntries
    call .UpdateWarp

.UpdateWarp:
    inc esi
    inc esi
    mov al, bh                                    ; ld a,b
    mov [ebp + esi], al                           ; ld [hli],a  — destination warp ID
    inc esi
    mov al, bl                                    ; ld a,c
    mov [ebp + esi], al                           ; ld [hli],a  — destination map ID
    inc esi
    ret

; ---------------------------------------------------------------------------
; WhichFloorText — pret engine/events/elevator.asm:WhichFloorText.
; Stream generated at assets/elevator_text.inc (tools/generators/gen_overworld_strings.py).
; ---------------------------------------------------------------------------
section .data

%include "assets/elevator_text.inc"

WhichFloorText:
    text_far _WhichFloorText
    text_end
