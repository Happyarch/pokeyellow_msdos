; check_user_interruption.asm — CheckForUserInterruption, translated SM83 -> x86.
;
; Source: home/overworld.asm:CheckForUserInterruption (pret/pokeyellow).
;
; The intro / title / Game Freak splash skip-check: wait C frames, returning carry
; if the user pressed the skip combo (Up+Select+B) or Start or A during them. Used
; by the movie code (AnimateShootingStar, MoveDownSmallStars, the Yellow intro
; scenes) to let the player skip the power-on cinematic.
;
; Register map: A->AL, BC->BX (C=BL frame count), F.CF->EFLAGS CF; GB mem = [ebp+SYM].
;
; Build: nasm -f coff -I include/ -o check_user_interruption.o check_user_interruption.asm

bits 32

%include "gb_memmap.inc"

extern DelayFrame                    ; video/frame.asm
extern JoypadLowSensitivity          ; home/joypad_lowsens.asm — writes hJoy5

section .text

; ---------------------------------------------------------------------------
; CheckForUserInterruption — return CF set if Up+Select+B, Start, or A are pressed
; within BL (pret C) frames; CF clear on timeout.
;
; DEVIATION{class=data-model; pret=home/overworld.asm:CheckForUserInterruption; behavior=the _DEBUG-only extra Select skip is dropped (release build); evidence=the port defines no _DEBUG, so pret's ELSE branch (Start|A) is the live one; lifetime=until a debug build defines _DEBUG}
;
; In:  BL = frame count (pret C). EBP = GB base.
; Out: CF = 1 if interrupted, 0 on timeout. Clobbers EAX; BL decremented to 0.
; ---------------------------------------------------------------------------
global CheckForUserInterruption
CheckForUserInterruption:
    call DelayFrame
    push ebx                          ; pret push bc — preserve the frame counter
    call JoypadLowSensitivity
    pop ebx
    mov al, [ebp + H_JOY_HELD]        ; ldh a, [hJoyHeld]
    cmp al, PAD_UP + PAD_SELECT + PAD_B   ; exactly Up+Select+B (the skip combo)
    je .input
    mov al, [ebp + H_JOY5]            ; ldh a, [hJoy5]
    and al, PAD_START | PAD_A         ; release build (pret _DEBUG also allows Select)
    jnz .input
    dec bl                            ; dec c
    jnz CheckForUserInterruption      ; jr nz — loop for the remaining frames
    and al, al                        ; pret `and a` — clear CF (no interruption)
    ret
.input:
    stc                               ; scf
    ret
