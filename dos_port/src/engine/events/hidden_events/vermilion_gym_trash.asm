; vermilion_gym_trash.asm — Vermilion Gym trash can puzzle scripts and text handlers.
;
; Faithful translation of pret engine/events/hidden_events/vermilion_gym_trash.asm.
;
; Register map: A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -o vermilion_gym_trash.o src/engine/events/hidden_events/vermilion_gym_trash.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "predef.inc"
%include "events.inc"
%include "assets/event_constants.inc"
%include "assets/predef_text_ids.inc"
%include "assets/audio_constants.inc"

global PrintTrashText
global GymTrashScript
global GymTrashCans
global VermilionGymTrashSuccessText1
global VermilionGymTrashSuccessPlaySfx
global VermilionGymTrashSuccessText3
global VermilionGymTrashFailText

extern Yellow_SampleSecondTrashCan      ; src/engine/events/hidden_events/vermilion_gym_trash2.asm
extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm
extern Random                           ; src/home/random.asm
extern WaitForSoundToFinish             ; src/home/delay.asm
extern PlaySound                        ; src/home/audio.asm
extern TextScriptEnd                    ; src/home/overworld_text.asm
extern PrintText_NoCreatingTextBox      ; src/home/window.asm — ESI = flat TX stream
extern text_msgbox                      ; src/home/text.asm — active msgbox projection
extern msgbox_dialog                    ; src/home/text.asm — overworld dialog projection

section .text

; ─────────────────────────────────────────────────────────────────────────────
; PrintTrashText — pret engine/events/hidden_events/vermilion_gym_trash.asm:PrintTrashText
; ─────────────────────────────────────────────────────────────────────────────
PrintTrashText:
    call EnableAutoTextBoxDrawing
    tx_pre_id VermilionGymTrashText
    jmp PrintPredefTextID

; ─────────────────────────────────────────────────────────────────────────────
; GymTrashScript — pret engine/events/hidden_events/vermilion_gym_trash.asm:GymTrashScript
; ─────────────────────────────────────────────────────────────────────────────
GymTrashScript:
    call EnableAutoTextBoxDrawing
    mov al, [ebp + wHiddenEventFunctionArgument]
    mov [ebp + wGymTrashCanIndex], al

; Don't do the trash can puzzle if it's already been done.
    CheckEvent EVENT_2ND_LOCK_OPENED
    jz .ok

    tx_pre_id VermilionGymTrashText
    jmp .done

.ok:
    CheckEventReuseA EVENT_1ST_LOCK_OPENED
    jnz .trySecondLock

    mov al, [ebp + wFirstLockTrashCanIndex]
    mov bh, al                          ; ld b, a
    mov al, [ebp + wGymTrashCanIndex]
    cmp al, bh                          ; cp b
    jz .openFirstLock

    tx_pre_id VermilionGymTrashText
    jmp .done

.openFirstLock:
; Next can is trying for the second switch.
    SetEvent EVENT_1ST_LOCK_OPENED
    call Yellow_SampleSecondTrashCan
    tx_pre_id VermilionGymTrashSuccessText1
    jmp .done

.trySecondLock:
    mov al, [ebp + wGymTrashCanIndex]
    mov bh, al                          ; ld b, a
    mov al, [ebp + wSecondLockTrashCanIndex]
    cmp al, bh                          ; cp b
    jz .openSecondLock
    mov al, [ebp + wSecondLockTrashCanIndex + 1]
    cmp al, bh                          ; cp b
    jz .openSecondLock

; Reset the cans.
    ResetEvent EVENT_1ST_LOCK_OPENED
    call Random

    and al, 0x0E                        ; and $e
    mov [ebp + wFirstLockTrashCanIndex], al

    tx_pre_id VermilionGymTrashFailText
    jmp .done

.openSecondLock:
; Completed the trash can puzzle.
    SetEvent EVENT_2ND_LOCK_OPENED
    or byte [ebp + wCurrentMapScriptFlags], 1 << BIT_CUR_MAP_LOADED_2

    tx_pre_id VermilionGymTrashSuccessText3

.done:
    jmp PrintPredefTextID

; ─────────────────────────────────────────────────────────────────────────────
; THE FOUR text_asm ENTRIES BELOW — the shape, once, for all of them.
;
; pret's label names the TEXT STREAM: `text_far _Foo` then `text_asm` then the
; hook's instructions, and TextCommandProcessor walks off the end of the stream
; straight into the hook.
;
; The port's TextPredefs rows for these labels are `predef_code` rows
; (src/data/text_predef_pointers.asm), and DisplayTextID CALLS such a row's pointer
; as code — "text_asm routine owns its own text stream", src/home/text_script.asm:213.
; A label pointing at `db` bytes would therefore be EXECUTED as instructions.
;
; So each pret stream is kept VERBATIM at a `.stream` local label, and the pret
; label becomes a three-instruction trampoline that does exactly what
; DisplayTextID's own `.notScriptEntry` path does with a stream
; (src/home/text_script.asm:281-283): select the overworld dialog projection, then
; PrintText_NoCreatingTextBox. It returns to DisplayTextID, which continues into
; AfterDisplayingTextID's button wait — the same place pret arrives.
;
; TX_ASM inside `.stream` is dispatched by TextCommandProcessor's `.cmd_asm`
; (`push .next_cmd / jmp esi`, src/home/text.asm), which is pret's
; `ld de, NextTextCommand / push de / jp hl` exactly, so each hook runs under pret's
; contract and its `jmp TextScriptEnd` terminates the message the same way.
;
; DEVIATION{class=projection; pret=engine/events/hidden_events/vermilion_gym_trash.asm:VermilionGymTrashSuccessText1; behavior=the pret label is a code trampoline that prints an embedded verbatim copy of pret's stream instead of naming the stream itself, and the same shape is used for VermilionGymTrashSuccessText3, VermilionGymTrashFailText and VermilionGymTrashSuccessPlaySfx; evidence=the port's TextPredefs rows for text_asm entries carry the TEXT_ASM_ENTRY sentinel and DisplayTextID calls the pointer rather than streaming it, src/home/text_script.asm:210-214, so a label naming db bytes would be executed as instructions; lifetime=permanent unless the port's predef table grows a stream-with-asm row kind}
; ─────────────────────────────────────────────────────────────────────────────

; VermilionGymTrashSuccessText1 — first-switch success line, then the switch sound (TextPredefs id $3D).
VermilionGymTrashSuccessText1:
    mov dword [text_msgbox], msgbox_dialog   ; overworld dialog projection
    mov esi, .stream
    call PrintText_NoCreatingTextBox
    ret
.stream:
    text_far _VermilionGymTrashSuccessText1
    text_asm
.hook:
    call WaitForSoundToFinish
    mov al, SFX_SWITCH
    call PlaySound
    call WaitForSoundToFinish
    jmp TextScriptEnd

; VermilionGymTrashSuccessPlaySfx — UNUSED, in pret and here: no TextPredefs row
; names it, and pret marks it `; unused`. Ported for label completeness. pret's body
; is a bare `text_asm` hook with NO text_far, so .stream holds only the TX_ASM byte;
; the trampoline is kept identical to its three siblings so that if the label is ever
; given a row it behaves like them.
; VermilionGymTrashSuccessPlaySfx — switch sound with no message of its own.
VermilionGymTrashSuccessPlaySfx:
    mov dword [text_msgbox], msgbox_dialog   ; overworld dialog projection
    mov esi, .stream
    call PrintText_NoCreatingTextBox
    ret
.stream:
    text_asm
.hook:
    call WaitForSoundToFinish
    mov al, SFX_SWITCH
    call PlaySound
    call WaitForSoundToFinish
    jmp TextScriptEnd

; VermilionGymTrashSuccessText3 — second-switch success line, puzzle complete, then the door sound (id $3F).
VermilionGymTrashSuccessText3:
    mov dword [text_msgbox], msgbox_dialog   ; overworld dialog projection
    mov esi, .stream
    call PrintText_NoCreatingTextBox
    ret
.stream:
    text_far _VermilionGymTrashSuccessText3
    text_asm
.hook:
    call WaitForSoundToFinish
    mov al, SFX_GO_INSIDE
    call PlaySound
    call WaitForSoundToFinish
    jmp TextScriptEnd

; VermilionGymTrashFailText — wrong-can line, then the denied sound. The switch pair has just been reset (id $40).
VermilionGymTrashFailText:
    mov dword [text_msgbox], msgbox_dialog   ; overworld dialog projection
    mov esi, .stream
    call PrintText_NoCreatingTextBox
    ret
.stream:
    text_far _VermilionGymTrashFailText
    text_asm
.hook:
    call WaitForSoundToFinish
    mov al, SFX_DENIED
    call PlaySound
    call WaitForSoundToFinish
    jmp TextScriptEnd

section .data

; byte 0: mask for random number
; bytes 1-4: indices of the trash cans that can have the second lock
; Note that the mask is simply the number of valid trash can indices that
; follow. The remaining bytes are filled with -1 to pad the length of each entry
; to 5 bytes.
; This is functionally replaced with GymTrashCans3a but was never removed from source.
; (pret's comment says 3a; the table that actually replaces it is GymTrashCans3c in
;  vermilion_gym_trash2.asm. Kept verbatim so the mirror reads against pret.)
GymTrashCans:
    db 2,  1,  3, -1, -1 ; 0
    db 3,  0,  2,  4, -1 ; 1
    db 2,  1,  5, -1, -1 ; 2
    db 3,  0,  4,  6, -1 ; 3
    db 4,  1,  3,  5,  7 ; 4
    db 3,  2,  4,  8, -1 ; 5
    db 3,  3,  7,  9, -1 ; 6
    db 4,  4,  6,  8, 10 ; 7
    db 3,  5,  7, 11, -1 ; 8
    db 3,  6, 10, 12, -1 ; 9
    db 4,  7,  9, 11, 13 ; 10
    db 3,  8, 10, 14, -1 ; 11
    db 2,  9, 13, -1, -1 ; 12
    db 3, 10, 12, 14, -1 ; 13
    db 2, 11, 13, -1, -1 ; 14

%include "assets/vermilion_gym_trash_text.inc"
