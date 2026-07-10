; elevator.asm — elevator shake animation (OW-6.3).
;
; Intended repo path: dos_port/src/engine/overworld/elevator.asm
; pret source: engine/overworld/elevator.asm
;
; ShakeElevator jerks the BG up/down 100× (SFX per jerk) via the fine-scroll
; register, then plays the "PA announcement" jingle and restores the map music.
;
; Register map (SM83 -> x86): A->AL, B->BH, C->BL, D->DH, E->DL. GB memory is
; [ebp+offset]. hSCY -> [ebp+H_SCY], the native renderer's fine-scroll shadow
; (honored directly — the shake is visible). PlayMusic: AL=sound id, BL=audio ROM
; bank (vestigial under the single flat engine — passed as 0).
;
; DIVERGENCE (bounded audio wait): the port has no VBlank audio ISR, so pret's
; bare `.musicLoop` spin on wChannelSoundIDs+CHAN5 (advanced only on the
; frame-loop tick) would hang — bounded here.
;
; ShakeElevatorRedrawRow is a documented NO-OP (tail-calls Delay3 for its one
; observable side effect): pret itself notes it "does not appear to ever result
; in any visible effect"; its wMapViewVRAMPointer / vBGMap0 torus manipulation
; has no analog in the port's native-width renderer (the VRAM torus is gone), so
; there is nothing to redraw. ; PROJ: no vBGMap ring in the port.
;
; Check-only.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/elevator.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "assets/audio_constants.inc"         ; SFX_COLLISION / SFX_SAFARI_ZONE_PA

; --- symbols not yet in the shared headers (golden sym-verified) ---
%ifndef wChannelSoundIDs
wChannelSoundIDs   equ 0xC026 ; golden 00:c026
%endif

WAIT_PA_MAX  equ 600  ; bounded audio-wait cap (DIVERGENCE — see header)

global ShakeElevator
global ShakeElevatorRedrawRow

extern Delay3                      ; video/frame.asm
extern DelayFrames                 ; video/frame.asm
extern StopAllMusic                ; home/audio.asm (LIVE)
extern PlayMusic                   ; home/audio.asm (LIVE; AL=id, BL=bank)
extern PlayDefaultMusic            ; home/audio.asm (LIVE)
extern UpdateSprites               ; engine/overworld/movement.asm

section .text

; ---------------------------------------------------------------------------
; ShakeElevator — pret engine/overworld/elevator.asm:ShakeElevator
; ---------------------------------------------------------------------------
ShakeElevator:
    mov edx, -0x20 & 0xFFFFFFFF                 ; ld de, -$20
    call ShakeElevatorRedrawRow
    mov edx, 18 * 0x20                          ; ld de, SCREEN_HEIGHT*$20 (pret 18 tiles; dead — no-op)
    call ShakeElevatorRedrawRow
    call Delay3
    call StopAllMusic
    mov al, [ebp + H_SCY]                       ; ldh a,[hSCY]
    mov dh, al                                  ; ld d, a
    mov dl, 1                                   ; ld e, $1
    mov bh, 100                                 ; ld b, 100
.shakeLoop:                                     ; scroll BG up/down + play SFX
    mov al, dl                                  ; ld a, e
    xor al, 0xfe                                ; xor $fe
    mov dl, al                                  ; ld e, a
    add al, dh                                  ; add d
    mov [ebp + H_SCY], al                       ; ldh [hSCY], a
    push ebx                                    ; push bc
    xor bl, bl                                  ; ld c, BANK(SFX_Collision_1) — flat: irrelevant
    mov al, SFX_COLLISION
    call PlayMusic
    pop ebx                                     ; pop bc
    mov bl, 2                                   ; ld c, 2
    call DelayFrames
    dec bh
    jnz .shakeLoop
    mov al, dh                                  ; ld a, d
    mov [ebp + H_SCY], al                       ; ldh [hSCY], a
    call StopAllMusic
    xor bl, bl                                  ; ld c, BANK(SFX_Safari_Zone_PA) — flat: irrelevant
    mov al, SFX_SAFARI_ZONE_PA
    call PlayMusic
    ; DIVERGENCE (bounded): wait for the PA jingle to finish
    mov ecx, WAIT_PA_MAX
.musicLoop:
    mov al, [ebp + wChannelSoundIDs + CHAN5]
    cmp al, SFX_SAFARI_ZONE_PA                  ; is the PA jingle still playing?
    jne .musicDone
    dec ecx
    jnz .musicLoop
.musicDone:
    call UpdateSprites
    jmp PlayDefaultMusic                        ; jp (tail)

; ---------------------------------------------------------------------------
; ShakeElevatorRedrawRow — documented NO-OP (see header). Preserves the one
; observable effect (a Delay3). pret's VRAM-pointer/vBGMap0 rewrite has no
; native-renderer analog and produced no visible effect even on GB.
; ---------------------------------------------------------------------------
ShakeElevatorRedrawRow:
    jmp Delay3                                  ; pret: jp Delay3 (tail)
