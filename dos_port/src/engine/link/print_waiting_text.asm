; ===========================================================================
; print_waiting_text.asm — mirror of pret engine/link/print_waiting_text.asm
; (link plan Stage 3). One routine: the "Waiting...!" box both the trade
; center (via Serial_PrintWaitingTextAndSyncAndExchangeNybble) and the link
; battle (Stage 4) draw while a nybble rendezvous is in flight.
;
; PROJECTION: pret's hlcoord 3,10 / 4,11 land on the port's 40x25 canvas
; through the uniform (X+10, Y+3) projection — the SAME transform for both
; branches, because the battle projection (BCOORD, include/coords.inc) and
; the cinematic surface origin (UI_TITLE_COL/UI_TITLE_ROW = 10/3,
; assets/ui_layout_intro.inc) are numerically identical. Only the coordinate
; VALUES move; every write is pret's.
;
; WaitingText (the string, pret's own label in this file) is Tier-1 generated
; data riding in assets/link_text.inc (carrier: link_menu.asm — recorded
; there; a label has exactly one provider).
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH, C=BL), DE=DX, HL=ESI,
; EBP = GB base.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/engine/link/print_waiting_text.asm
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "coords.inc"

global PrintWaitingText

extern TextBoxBorder            ; src/home/text.asm — ESI=top-left, BL=w, BH=h
extern CableClub_TextBoxBorder  ; src/engine/link/cable_club.asm — same iface
extern PlaceString              ; src/home/text.asm — EAX=flat src, ESI=dest
extern DelayFrames              ; src/home/delay.asm — BL = frame count
extern WaitingText              ; assets/link_text.inc (carrier link_menu.asm)

section .text

; ---------------------------------------------------------------------------
; PrintWaitingText — pret engine/link/print_waiting_text.asm:PrintWaitingText.
; Draws a 1x11 box at (3,10) — TextBoxBorder in battle, CableClub_TextBoxBorder
; in the trade center — prints "Waiting...!" at (4,11), waits 50 frames.
; ---------------------------------------------------------------------------
PrintWaitingText:
    mov esi, BCOORD(3, 10)          ; hlcoord 3,10 (projected — header note)
    mov bh, 1                       ; lb bc, 1, 11
    mov bl, 11
    mov al, [ebp + wIsInBattle]
    test al, al                     ; and a
    jz .trade
    ; battle
    call TextBoxBorder
    jmp .border_done
.trade:
    call CableClub_TextBoxBorder
.border_done:
    mov eax, WaitingText            ; ld de, WaitingText (port: EAX = flat src)
    mov esi, BCOORD(4, 11)          ; hlcoord 4,11 (projected)
    call PlaceString
    mov bl, 50                      ; ld c, 50
    jmp DelayFrames                 ; jp DelayFrames
