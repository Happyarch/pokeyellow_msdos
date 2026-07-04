; clear_variables.asm — ClearVariablesOnEnterMap (OW-1.1, pure-logic leaf).
;
; Faithful translation of pret engine/overworld/clear_variables.asm.
; Runs on map entry: hides the window, disables the auto-BG-transfer flag,
; zeroes several step/battle/joypad scratch bytes, and bulk-clears the block
; from wWhichTrade through wStandingOnWarpPadOrHole via FillMemory.
;
; Register map (SM83->x86): A->AL, HL->ESI, BC->BX (B=BH,C=BL).
; GB memory = [ebp + SYM], SYM from gb_memmap.inc.
;
; Reuses (does not duplicate):
;   extern FillMemory   ; src/home/fill_memory.asm
;     Contract (per that file's header): ESI = dest (EBP-relative GB offset),
;     BX = byte count, AL = fill value. Preserves ESI/EBX/EAX/ECX.
;   extern hide_window  ; src/ppu/ppu.asm
;     Contract (per that file's header): empties the window list
;     (g_window_count = 0) and sets H_WY = RENDER_H. No inputs; all registers
;     preserved. This is the port's existing idiom for pret's
;     "ldh [hWY],a (SCREEN_HEIGHT_PX) / ldh [rWY],a" hide-the-window pattern —
;     see ResetMapVariables (src/engine/overworld/overworld.asm) which performs
;     the identical hide_window + IO_WY=RENDER_H sequence for the same pret
;     instructions in a sibling map-entry routine.
;
; Build (default, LINK): nasm -f coff -I include/ -I . \
;                             -o clear_variables.o clear_variables.asm
; Build (standalone verify): nasm -f coff -I dos_port/include -I dos_port \
;                             -o /dev/null clear_variables.asm

bits 32

%include "gb_memmap.inc"

; WRAM symbols consumed here (wWhichTrade 0xCD3D, wStandingOnWarpPadOrHole
; 0xCD5B, wStepCounter 0xD13A, wUnusedMapVariable 0xD5A2, wCardKeyDoorY 0xD73E,
; wCardKeyDoorX 0xD73F) are defined in gb_memmap.inc (root-promoted, sym-verified
; against origin/symbols:pokeyellow.sym). H_WY/IO_WY/H_AUTO_BG_TRANSFER_EN/
; H_JOY_*/RENDER_H and wActionResultOrTookBattleTurn/wLoneAttackNo pre-existing.

section .text

global ClearVariablesOnEnterMap
extern FillMemory
extern hide_window

; ---------------------------------------------------------------------------
; ClearVariablesOnEnterMap — faithful translation.
; Pret ref: engine/overworld/clear_variables.asm:ClearVariablesOnEnterMap
;
; In:  EBP = GB memory base.
; Out: none (matches pret's bare `ret`).
; Clobbers: EAX, ESI, EBX (all overwritten internally; pret's routine clobbers
;           A/HL/BC too, so callers already expect no register preservation).
; ---------------------------------------------------------------------------
ClearVariablesOnEnterMap:
    ; ld a, SCREEN_HEIGHT_PX / ldh [hWY],a / ldh [rWY],a
    ; TODO-HW: rWY ($FF4A) is a real GB LCD register; the port's software
    ; renderer does not scan out a window via hardware WY. The port's
    ; established idiom for this exact "hide the window" pattern (see
    ; ResetMapVariables, same file area, and hide_window's own header) is:
    ;   call hide_window          -> g_window_count = 0, H_WY = RENDER_H
    ;   mov byte [ebp+IO_WY], RENDER_H  -> mirror the real-register shadow
    ; RENDER_H (200, the port's back-buffer height) stands in for pret's
    ; SCREEN_HEIGHT_PX (144, the GB's LCD height) — same "off the bottom of
    ; the visible area" sentinel, scaled to the port's own screen height, per
    ; the convention already established at every other hWY/rWY-hide call
    ; site (hide_window, ResetMapVariables, title.asm). ; PROJ
    call hide_window
    mov byte [ebp + IO_WY], RENDER_H

    ; xor a
    xor al, al

    ; ldh [hAutoBGTransferEnabled], a
    ; Not hardware I/O — hAutoBGTransferEnabled is a plain HRAM shadow byte
    ; the port's own VBlank-transfer gate reads (src/video/frame.asm,
    ; src/home/copy2.asm). Faithful direct write.
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], al

    ; ld [wStepCounter], a
    mov byte [ebp + wStepCounter], al

    ; ld [wLoneAttackNo], a
    mov byte [ebp + wLoneAttackNo], al

    ; ldh [hJoyPressed], a / ldh [hJoyReleased], a / ldh [hJoyHeld], a
    ; The port's joypad ISR (src/input/joypad.asm) owns and actively
    ; maintains H_JOY_PRESSED/H_JOY_RELEASED/H_JOY_HELD each frame; these are
    ; plain WRAM/HRAM shadow bytes (not hardware registers), so a faithful
    ; direct zero is correct here (clears stale input state on map entry,
    ; same as pret).
    mov byte [ebp + H_JOY_PRESSED], al
    mov byte [ebp + H_JOY_RELEASED], al
    mov byte [ebp + H_JOY_HELD], al

    ; ld [wActionResultOrTookBattleTurn], a
    mov byte [ebp + wActionResultOrTookBattleTurn], al

    ; ld [wUnusedMapVariable], a
    mov byte [ebp + wUnusedMapVariable], al

    ; ld hl, wCardKeyDoorY
    ; ld [hli], a
    ; ld [hl], a
    mov byte [ebp + wCardKeyDoorY], al
    mov byte [ebp + wCardKeyDoorX], al

    ; ld hl, wWhichTrade
    ; ld bc, wStandingOnWarpPadOrHole - wWhichTrade
    ; call FillMemory
    ; FillMemory contract (src/home/fill_memory.asm): ESI = dest (EBP-rel),
    ; BX = count, AL = fill value (already 0 from the xor above). ESI/EBX/EAX
    ; are all preserved by FillMemory, but none of them are live past this
    ; call, so no save/restore is needed here.
    mov esi, wWhichTrade
    mov bx, wStandingOnWarpPadOrHole - wWhichTrade
    call FillMemory

    ; ret
    ret
