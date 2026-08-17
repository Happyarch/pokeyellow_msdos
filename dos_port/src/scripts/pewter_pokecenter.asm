; PewterPokecenter.asm — translated from pret scripts/PewterPokecenter.asm, scripts/PewterPokecenter_2.asm by dos_port/tools/sm83xlat.
;
; ONE-SHOT OUTPUT, NOW HAND-MAINTAINED. The transpiler ran once at the SHA
; recorded in dos_port/tools/sm83xlat/README.md and is not re-run; this file is
; ordinary Tier-2 source and editing it is the normal way it changes. There is
; deliberately no DO NOT EDIT header.
;
; Every pret label is preserved verbatim so the file stays line-for-line
; cross-referenceable against the disassembly.
;
; Regions the tool could not lower WITH CERTAINTY are reproduced below as
; commented pret source under a `; BAIL[reason]` banner, and define NO symbol —
; so a reference to one is a link error rather than a plausible wrong lowering.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "events.inc"
%include "assets/event_constants.inc"

%include "assets/audio_constants.inc"

global PewterJigglypuff
global PewterPokecenterChanseyText
global PewterPokecenterCooltrainerFText
global PewterPokecenterGentlemanText
global PewterPokecenterJigglypuffText
global PewterPokecenterLinkReceptionistText
global PewterPokecenterNurseText
global PewterPokecenterPrintCooltrainerFText
global PewterPokecenter_Script
global PewterPokecenter_TextPointers

extern Bankswitch
extern CheckPikachuStatusCondition
extern CopyData
extern DelayFrames
extern DisablePikachuFollowingPlayer
extern EnableAutoTextBoxDrawing
extern PlayDefaultMusic
extern PlayMusic
extern PokecenterChanseyText   ; NOT YET DEFINED IN THE PORT
extern PrintText
extern Serial_TryEstablishingExternallyClockedConnection   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic
extern TextScriptEnd
extern _PewterPokecenterGentlemanText   ; NOT YET DEFINED IN THE PORT
extern _PewterPokecenterJigglypuffText   ; NOT YET DEFINED IN THE PORT
extern _PewterPokecenterText3   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wJigglypuffFacingDirections                    equ 0xCD3F
wPikachuMapScriptFlags                         equ 0xD492
wPikachuSpawnStateFlags                        equ 0xD471
wSprite03StateData1ImageIndex                  equ 0xC132

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
PewterPokecenter_Script:
    mov esi, wPikachuMapScriptFlags
    or byte [ebp + esi], (1 << (7))
    call Serial_TryEstablishingExternallyClockedConnection
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
%assign event_byte_a -1
PewterPokecenter_TextPointers:
    dd PewterPokecenterNurseText
    dd PewterPokecenterGentlemanText
    dd PewterPokecenterJigglypuffText
    dd PewterPokecenterLinkReceptionistText
    dd PewterPokecenterCooltrainerFText
    dd PewterPokecenterChanseyText
PewterPokecenterNurseText:
    script_pokecenter_nurse
PewterPokecenterGentlemanText:
    text_far _PewterPokecenterGentlemanText
    text_end

%assign event_byte -1
%assign event_byte_a -1
PewterPokecenterJigglypuffText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call PewterJigglypuff
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
PewterPokecenterLinkReceptionistText:
    script_cable_club_receptionist

%assign event_byte -1
%assign event_byte_a -1
PewterPokecenterCooltrainerFText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call PewterPokecenterPrintCooltrainerFText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
PewterPokecenterChanseyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call PokecenterChanseyText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
PewterPokecenterPrintCooltrainerFText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _PewterPokecenterText3
    text_end

%assign event_byte -1
%assign event_byte_a -1
PewterJigglypuff:
    mov al, 1   ; TRUE
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, .Text
    call PrintText

    call StopAllMusic
    mov bl, 32
    call DelayFrames

    mov esi, .FacingDirections
    mov dx, wJigglypuffFacingDirections
    mov bx, .FacingDirectionsEnd - .FacingDirections
    call CopyData

    mov al, [ebp + wSprite03StateData1ImageIndex]
    mov esi, wJigglypuffFacingDirections
.findMatchingFacingDirectionLoop:
    cmp al, [ebp + esi]
    lea esi, [esi+1]
    jnz .findMatchingFacingDirectionLoop
    dec esi

    push esi
    mov bl, MUSIC_JIGGLYPUFF_SONG_BANK
    mov al, MUSIC_JIGGLYPUFF_SONG
    call PlayMusic
    pop esi

.spinMovementLoop:
    mov al, [ebp + esi]
    mov [ebp + wSprite03StateData1ImageIndex], al
; rotate the array
    push esi
    mov esi, wJigglypuffFacingDirections
    mov dx, wJigglypuffFacingDirections - 1
    mov bx, .FacingDirectionsEnd - .FacingDirections
    call CopyData
    mov al, [ebp + wJigglypuffFacingDirections - 1]
    mov [ebp + wJigglypuffFacingDirections + 3], al
    pop esi
    mov bl, 24
    call DelayFrames
    mov al, [ebp + wChannelSoundIDs]
    mov bh, al
    mov al, [ebp + wChannelSoundIDs + CHAN2]
    or al, bh
    jnz .spinMovementLoop

    mov bl, 48
    call DelayFrames
    call PlayDefaultMusic
    mov al, [ebp + wPikachuSpawnStateFlags]
    test al, (1 << (7))
    jnz .nr_pikachu_spawn
        ret
.nr_pikachu_spawn:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CheckPikachuStatusCondition
    jnc .nr_pikachu_status
        ret
.nr_pikachu_status:
    call DisablePikachuFollowingPlayer
    ret

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _PewterPokecenterJigglypuffText
    text_end
.FacingDirections:
    db 0x40 | SPRITE_FACING_DOWN
    db 0x40 | SPRITE_FACING_LEFT
    db 0x40 | SPRITE_FACING_UP
    db 0x40 | SPRITE_FACING_RIGHT
.FacingDirectionsEnd:
