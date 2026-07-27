; print_text.asm — PrintLetterDelay.
;
; Mirror of pret home/print_text.asm. pret's file also defines PrintText and
; its helpers, but in THIS port those live in src/home/window.asm (PrintText)
; and src/home/text.asm (the placement engine) — measured, not assumed: the
; labels table reports PrintLetterDelay as this pret file's only entry.
;
; Carried by src/home/text.asm until chunk 18 of the relocated-label grind.
; Four callers reach it as an extern: PlaceNextChar (text.asm), PrintBCDDigit
; and PrintBCDNumber (print_bcd.asm), and print_dec (battle_menu.asm).
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
;
; Build: nasm -f coff -I include/ -I . -o print_text.o print_text.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global PrintLetterDelay

extern DelayFrame                    ; src/home/vblank.asm
extern sync_dialog_window            ; src/home/text.asm

section .text

; ---------------------------------------------------------------------------
; PrintLetterDelay — wait per-character delay based on the text speed setting.
; Pret ref: home/print_text.asm:PrintLetterDelay.
;
; Reads delay frame count from wOptions bits 3-0 (TEXT_DELAY_FAST/MEDIUM/SLOW = 1/3/5).
; Exits early if A or B is held. No-op if BIT_TEXT_DELAY is not set in
; wLetterPrintingDelayFlags (TextCommandProcessor sets it) or if BIT_NO_TEXT_DELAY
; is set in wStatusFlags5 (cutscenes, auto-scroll).
; All registers preserved.
; ---------------------------------------------------------------------------
PrintLetterDelay:
    push eax
    push ecx
    movzx eax, byte [ebp + W_STATUS_FLAGS_5]
    test al, (1 << BIT_NO_TEXT_DELAY)          ; cutscene/auto-scroll: skip delay
    jnz .done
    movzx eax, byte [ebp + W_LETTER_PRINTING_DELAY]
    test al, (1 << BIT_TEXT_DELAY)             ; delay enabled by TextCommandProcessor?
    jz .done
    call sync_dialog_window                    ; mirror latest char to window before first frame
    movzx ecx, byte [ebp + H_JOY_HELD]
    test cl, PAD_A | PAD_B
    jnz .one_frame                             ; button held: skip to one-frame exit
    test al, (1 << BIT_FAST_TEXT_DELAY)        ; use wOptions speed or fixed 1-frame?
    jz .one_frame
    movzx ecx, byte [ebp + W_OPTIONS]
    and cl, TEXT_DELAY_MASK                    ; isolate speed bits (1, 3, or 5)
    jz .done                                   ; speed 0: instant (not used in practice)
    jmp .count_down
.one_frame:
    mov cl, 1
.count_down:
    call DelayFrame                            ; renders frame + updates H_JOY_HELD
    movzx eax, byte [ebp + H_JOY_HELD]
    test al, PAD_A | PAD_B
    jnz .done                                  ; button held: abort remaining delay
    dec cl
    jnz .count_down
.done:
    pop ecx
    pop eax
    ret
