; field_move_messages.asm — Strength/Surf field-move messages (OW-4.4).
;
; Intended repo path: dos_port/src/engine/overworld/field_move_messages.asm
; pret source: engine/overworld/field_move_messages.asm
;
; PrintStrengthText: arm Strength (BIT_STRENGTH_ACTIVE) and print the "used
; STRENGTH / can move boulders" messages. IsSurfingAllowed: set/clear
; BIT_SURF_ALLOWED for the current map (blocked on Cycling Road and in the
; lowest Seafoam Islands level until the current has been slowed with boulders),
; printing the "current too fast" / "cycling is fun" message when it's blocked.
;
; The FAR text streams (_UsedStrengthText etc.) are Tier-1 generated data
; (tools/gen_overworld_strings.py → assets/field_move_text.inc, flattening pret's
; data/text/text_8.asm). The text-command WRAPPERS (UsedStrengthText…) are Tier-2
; code here — the text_far pointer + the text_asm cry hook (pret's grammar branch,
; not machine-generatable).
;
; Register map (SM83 -> x86): A->AL, HL->ESI. PrintText / ArePlayerCoordsInArray
; take the pointer/array in ESI. GB memory is [ebp+offset].
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/field_move_messages.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "gb_text.inc"                       ; text_far / text_asm / text_end + TX_* codes
%include "coords.inc"                        ; dbmapcoord
%include "events.inc"                        ; CheckBothEventsSet / CheckEvent
%include "assets/event_constants.inc"        ; EVENT_SEAFOAM4_BOULDER*_DOWN_HOLE

; --- symbols not yet in the shared headers (pret constants/*.asm, sym-verified) ---
%ifndef BIT_STRENGTH_ACTIVE
BIT_STRENGTH_ACTIVE equ 0     ; wStatusFlags1 bit (constants/ram_constants.asm)
%endif
%ifndef BIT_SURF_ALLOWED
BIT_SURF_ALLOWED    equ 1     ; wStatusFlags1 bit (constants/ram_constants.asm)
%endif
%ifndef SEAFOAM_ISLANDS_B4F
SEAFOAM_ISLANDS_B4F equ 0xA2  ; constants/map_constants.asm ($A2)
%endif

global PrintStrengthText
global UsedStrengthText
global CanMoveBouldersText
global IsSurfingAllowed
global SeafoamIslandsB4FStairsCoords
global CurrentTooFastText
global CyclingIsFunText

extern PrintText                    ; src/text/text.asm
extern PlayCry                      ; UNPORTED (pret home/pokemon.asm) — cry synth deferred
                                    ; (status_screen.asm plays the regular cry as TODO-HW).
extern Delay3                       ; src/video/frame.asm
extern TextScriptEnd                ; src/engine/overworld/overworld_text.asm
extern ArePlayerCoordsInArray       ; src/engine/overworld/hidden_events.asm
extern msgbox_dialog                    ; src/home/text.asm — overworld dialog projection
extern text_msgbox                      ; src/home/text.asm — active msgbox projection (msgbox.inc)

section .text

; ---------------------------------------------------------------------------
; PrintStrengthText — pret engine/overworld/field_move_messages.asm:PrintStrengthText
; ---------------------------------------------------------------------------
PrintStrengthText:
    or byte [ebp + W_STATUS_FLAGS_1], (1 << BIT_STRENGTH_ACTIVE) ; set BIT_STRENGTH_ACTIVE,[hl]
    mov esi, UsedStrengthText
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    call PrintText
    mov esi, CanMoveBouldersText
    jmp PrintText                               ; jp PrintText (tail)

; text-command wrappers (Tier-2): text_far → generated far stream, text_asm cry hook.
UsedStrengthText:
    text_far _UsedStrengthText
    text_asm                                    ; TX_START_ASM → runtime jumps to the code below
    mov al, [ebp + wCurPartySpecies]
    call PlayCry                                ; TODO-HW: cry synth unported (see status_screen.asm)
    call Delay3
    jmp TextScriptEnd

CanMoveBouldersText:
    text_far _CanMoveBouldersText
    text_end

; ---------------------------------------------------------------------------
; IsSurfingAllowed — pret engine/overworld/field_move_messages.asm:IsSurfingAllowed
; Sets BIT_SURF_ALLOWED of wStatusFlags1; clears it (and prints why) on the
; Cycling Road and in Seafoam Islands B4F before the current has been slowed.
; ---------------------------------------------------------------------------
IsSurfingAllowed:
    or byte [ebp + W_STATUS_FLAGS_1], (1 << BIT_SURF_ALLOWED)   ; set BIT_SURF_ALLOWED,[hl]
    mov al, [ebp + W_STATUS_FLAGS_6]
    test al, (1 << BIT_ALWAYS_ON_BIKE)
    jnz .forcedToRideBike
    mov al, [ebp + W_CUR_MAP]
    cmp al, SEAFOAM_ISLANDS_B4F
    jne .ret                                    ; ret nz (not Seafoam B4F → surf allowed)
    CheckBothEventsSet EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE, EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE
    jz .ret                                     ; ret z (both boulders down → current slowed)
    mov esi, SeafoamIslandsB4FStairsCoords
    call ArePlayerCoordsInArray
    jnc .ret                                    ; ret nc (not on the stairs tiles → surf allowed)
    and byte [ebp + W_STATUS_FLAGS_1], ~(1 << BIT_SURF_ALLOWED) ; res BIT_SURF_ALLOWED,[hl]
    mov esi, CurrentTooFastText
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    jmp PrintText
.forcedToRideBike:
    and byte [ebp + W_STATUS_FLAGS_1], ~(1 << BIT_SURF_ALLOWED)
    mov esi, CyclingIsFunText
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    jmp PrintText
.ret:
    ret

SeafoamIslandsB4FStairsCoords:
    dbmapcoord 7, 11
    db -1                                       ; end

CurrentTooFastText:
    text_far _CurrentTooFastText
    text_end

CyclingIsFunText:
    text_far _CyclingIsFunText
    text_end

; Tier-1 generated FAR text streams (_UsedStrengthText … ) — section .data.
%include "assets/field_move_text.inc"
