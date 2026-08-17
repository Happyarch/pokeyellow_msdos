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
extern PewterJigglypuff   ; NOT YET DEFINED IN THE PORT
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

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] PewterJigglypuff (scripts/PewterPokecenter_2.asm:11-68) — at scripts/PewterPokecenter_2.asm:22: bc cannot hold the 32-bit address of .FacingDirectionsEnd - .FacingDirections; callee CopyData has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, TRUE
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 
; PRET| 	call StopAllMusic
; PRET| 	ld c, 32
; PRET| 	call DelayFrames
; PRET| 
; PRET| 	ld hl, .FacingDirections
; PRET| 	ld de, wJigglypuffFacingDirections
; PRET| 	ld bc, .FacingDirectionsEnd - .FacingDirections
; PRET| 	call CopyData
; PRET| 
; PRET| 	ld a, [wSprite03StateData1ImageIndex]
; PRET| 	ld hl, wJigglypuffFacingDirections
; PRET| .findMatchingFacingDirectionLoop
; PRET| 	cp [hl]
; PRET| 	inc hl
; PRET| 	jr nz, .findMatchingFacingDirectionLoop
; PRET| 	dec hl
; PRET| 
; PRET| 	push hl
; PRET| 	ld c, BANK(Music_JigglypuffSong)
; PRET| 	ld a, MUSIC_JIGGLYPUFF_SONG
; PRET| 	call PlayMusic
; PRET| 	pop hl
; PRET| 
; PRET| .spinMovementLoop
; PRET| 	ld a, [hl]
; PRET| 	ld [wSprite03StateData1ImageIndex], a
; PRET| ; rotate the array
; PRET| 	push hl
; PRET| 	ld hl, wJigglypuffFacingDirections
; PRET| 	ld de, wJigglypuffFacingDirections - 1
; PRET| 	ld bc, .FacingDirectionsEnd - .FacingDirections
; PRET| 	call CopyData
; PRET| 	ld a, [wJigglypuffFacingDirections - 1]
; PRET| 	ld [wJigglypuffFacingDirections + 3], a
; PRET| 	pop hl
; PRET| 	ld c, 24
; PRET| 	call DelayFrames
; PRET| 	ld a, [wChannelSoundIDs]
; PRET| 	ld b, a
; PRET| 	ld a, [wChannelSoundIDs + CHAN2]
; PRET| 	or b
; PRET| 	jr nz, .spinMovementLoop
; PRET| 
; PRET| 	ld c, 48
; PRET| 	call DelayFrames
; PRET| 	call PlayDefaultMusic
; PRET| 	ld a, [wPikachuSpawnStateFlags]
; PRET| 	bit BIT_PIKACHU_SPAWN_STARTER, a
; PRET| 	ret z
; PRET| 	callfar CheckPikachuStatusCondition
; PRET| 	ret c
; PRET| 	call DisablePikachuFollowingPlayer
; PRET| 	ret

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
