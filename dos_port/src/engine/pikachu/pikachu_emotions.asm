; pikachu_emotions.asm — pret engine/pikachu/pikachu_emotions.asm.
;
; Only IsPlayerPikachuAsleepInParty is translated so far; the rest of pret's
; emotion/mood engine (PikachuWalksToNurseJoy and the emotion data table) is
; overworld-owned and not needed by the battle path. The file exists so this
; routine sits in its mirrored path rather than being parked in a neighbour.
;
; Register map: A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI, EBP = GB memory base.
;
; Build: nasm -f coff -I include/ -I . -o pikachu_emotions.o pikachu_emotions.asm
%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

section .text

global IsPlayerPikachuAsleepInParty
global InitializePikachuTextID

extern IsThisPartyMonStarterPikachu   ; pikachu_status.asm — CF=1 when the slot is the starter
extern AddNTimes                      ; home/array.asm — ESI += EBX * AL
extern DisplayTextID                  ; home/text_script.asm

; ---------------------------------------------------------------------------
; InitializePikachuTextID — pret engine/pikachu/pikachu_emotions.asm:14.
;
; Runs the Pikachu emotion/animation "text" (TEXT_PIKACHU_ANIM) through the
; normal text engine with auto-textbox-drawing forced ON for the duration, then
; restores it. Called by the map scripts that make Pikachu react.
;
;   pret:
;     ld a, TEXT_PIKACHU_ANIM
;     ldh [hTextID], a
;     xor a
;     ld [wPlayerMovingDirection], a
;     ld a, $1
;     ld [wAutoTextBoxDrawingControl], a
;     call DisplayTextID
;     xor a
;     ld [wAutoTextBoxDrawingControl], a
;     ret
;
; Every dereference here is [ebp + SYM]: all four are emulated GB memory
; (hTextID is HRAM $FF8C, the other two are WRAM). Nothing reads a flag across
; a store, so no flag-preservation care is needed. The A-register moves are kept
; literal rather than folded into `mov byte [..], imm` so the value DisplayTextID
; sees in A on entry matches pret ($01).
; ---------------------------------------------------------------------------
InitializePikachuTextID:
    mov al, TEXT_PIKACHU_ANIM
    mov [ebp + hTextID], al                   ; ldh [hTextID], a
    xor al, al
    mov [ebp + wPlayerMovingDirection], al    ; xor a / ld [wPlayerMovingDirection], a
    mov al, 1
    mov [ebp + wAutoTextBoxDrawingControl], al
    call DisplayTextID
    xor al, al
    mov [ebp + wAutoTextBoxDrawingControl], al
    ret

; ---------------------------------------------------------------------------
; IsPlayerPikachuAsleepInParty — pret engine/pikachu/pikachu_emotions.asm:372.
;
; Walks wPartySpecies for the starter Pikachu and returns CF=1 when that mon's
; status byte has SLP_MASK set, CF=0 otherwise. Retires the ret-stub in
; pikachu_stubs.asm, which always answered "awake".
;
; Out: CF=1 the starter Pikachu is asleep, CF=0 otherwise.
;      wWhichPokemon is left at the scan position, exactly as pret leaves it —
;      that is a real output of this routine, not scratch: pret's callers run it
;      immediately before reading the party slot it settled on.
;
; The scan is bounded by pret's own two exits — the $FF species terminator and
; the `cp PARTY_LENGTH - 1` check — so the 8-bit party index cannot run past the
; array. No zero-guard is added and none is needed; see the counter-width rule.
; ---------------------------------------------------------------------------
IsPlayerPikachuAsleepInParty:
    mov byte [ebp + wWhichPokemon], 0    ; xor a / ld [wWhichPokemon], a
.loop:
    movzx ebx, byte [ebp + wWhichPokemon] ; ld a,[wWhichPokemon] / ld c,a / ld b,0
    mov al, [ebp + wPartySpecies + ebx]   ; ld hl,wPartySpecies / add hl,bc / ld a,[hl]
    cmp al, 0xFF                          ; cp $ff — end of the party list
    je .done                              ; jr z
    cmp al, STARTER_PIKACHU
    jne .curMonNotStarterPikachu          ; jr nz
    call IsThisPartyMonStarterPikachu     ; callfar — CF=1 when it really is the starter
    jnc .curMonNotStarterPikachu          ; jr nc
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMon1Status
    mov ebx, wPartyMon2 - wPartyMon1
    call AddNTimes                        ; esi = &party[wWhichPokemon].status
    mov al, [ebp + esi]                   ; ld a, [hl]
    and al, SLP_MASK
    jz .done                              ; jr z — the starter is awake
    jmp .curMonSleepingPikachu            ; jr
.curMonNotStarterPikachu:
    mov al, [ebp + wWhichPokemon]
    cmp al, PARTY_LENGTH - 1
    je .done                              ; jr z — last slot, nothing found
    inc al
    mov [ebp + wWhichPokemon], al
    jmp .loop                             ; jr
.curMonSleepingPikachu:
    stc                                   ; scf
    ret
.done:
    and al, al                            ; and a — clears CF
    ret
