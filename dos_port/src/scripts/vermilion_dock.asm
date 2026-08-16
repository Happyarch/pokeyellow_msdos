; VermilionDock.asm — translated from pret scripts/VermilionDock.asm by dos_port/tools/sm83xlat.
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
%include "assets/map_dims.inc"

global VermilionDockOAMBlock
global VermilionDockUnusedText
global VermilionDock_TextPointers

extern CopyScreenTileBufferToVRAM   ; NOT YET DEFINED IN THE PORT
extern CopyVideoData   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern FillMemory   ; NOT YET DEFINED IN THE PORT
extern LoadPlayerSpriteGraphics   ; NOT YET DEFINED IN THE PORT
extern LoadSmokeTileFourTimes   ; NOT YET DEFINED IN THE PORT
extern PlayMusic   ; NOT YET DEFINED IN THE PORT
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern PlaySoundWaitForCurrent   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern UpdateCGBPal_OBP1   ; NOT YET DEFINED IN THE PORT
extern VermilionDockSSAnneLeavesScript   ; NOT YET DEFINED IN THE PORT
extern VermilionDock_AnimSmokePuffDriftRight   ; NOT YET DEFINED IN THE PORT
extern VermilionDock_EmitSmokePuff   ; NOT YET DEFINED IN THE PORT
extern VermilionDock_EraseSSAnne   ; NOT YET DEFINED IN THE PORT
extern VermilionDock_Script   ; NOT YET DEFINED IN THE PORT
extern VermilionDock_SyncScrollWithLY   ; NOT YET DEFINED IN THE PORT
extern WriteOAMBlock   ; NOT YET DEFINED IN THE PORT
extern _VermilionDockUnusedText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSSAnneSmokeDriftAmount                        equ 0xCD3D
wSSAnneSmokeX                                  equ 0xCD3E
wShadowOAMSprite04XCoord                       equ 0xC311
wSpritePlayerStateData2MovementByte1           equ 0xC206
wVermilionDockTileMapBuffer                    equ 0xCC5B
wVermilionDockTileMapBufferEnd                 equ 0xCD0F

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VermilionDock_Script (scripts/VermilionDock.asm:2-28) — at scripts/VermilionDock.asm:4: .walking_out_of_dock is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	CheckEventHL EVENT_STARTED_WALKING_OUT_OF_DOCK
; PRET| 	jr nz, .walking_out_of_dock
; PRET| 	CheckEventReuseHL EVENT_GOT_HM01
; PRET| 	ret z
; PRET| 	ld a, [wDestinationWarpID]
; PRET| 	cp $1
; PRET| 	ret nz
; PRET| 	CheckEventReuseHL EVENT_SS_ANNE_LEFT
; PRET| 	jp z, VermilionDockSSAnneLeavesScript
; PRET| 	SetEventReuseHL EVENT_STARTED_WALKING_OUT_OF_DOCK
; PRET| 	call Delay3
; PRET| 	ld hl, wStatusFlags5
; PRET| 	set BIT_SCRIPTED_MOVEMENT_STATE, [hl]
; PRET| 	ld hl, wSimulatedJoypadStatesEnd
; PRET| 	ld a, PAD_UP
; PRET| 	ld [hli], a
; PRET| 	ld [hli], a
; PRET| 	ld [hl], a
; PRET| 	ld a, $3
; PRET| 	ld [wSimulatedJoypadStatesIndex], a
; PRET| 	xor a
; PRET| 	ld [wSpritePlayerStateData2MovementByte1], a
; PRET| 	ld [wOverrideSimulatedJoypadStatesMask], a
; PRET| 	dec a
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] VermilionDock_Script.walking_out_of_dock (scripts/VermilionDock.asm:30-37) — at scripts/VermilionDock.asm:30: CheckEventAfterBranchReuseHL EVENT_WALKED_OUT_OF_DOCK, EVENT_STARTED_WALKING_OUT_OF_DOCK
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventAfterBranchReuseHL EVENT_WALKED_OUT_OF_DOCK, EVENT_STARTED_WALKING_OUT_OF_DOCK
; PRET| 	ret nz
; PRET| 	ld a, [wSimulatedJoypadStatesIndex]
; PRET| 	and a
; PRET| 	ret nz
; PRET| 	ld [wJoyIgnore], a
; PRET| 	SetEventReuseHL EVENT_WALKED_OUT_OF_DOCK
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[unknown-macro] VermilionDockSSAnneLeavesScript (scripts/VermilionDock.asm:40-122) — at scripts/VermilionDock.asm:40: SetEventForceReuseHL EVENT_SS_ANNE_LEFT
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	SetEventForceReuseHL EVENT_SS_ANNE_LEFT
; PRET| 	ld a, $ff
; PRET| 	ld [wJoyIgnore], a
; PRET| 	call StopAllMusic
; PRET| 	ld c, BANK(Music_Surfing)
; PRET| 	ld a, MUSIC_SURFING
; PRET| 	call PlayMusic
; PRET| 	farcall LoadSmokeTileFourTimes
; PRET| 	xor a
; PRET| 	ld [wSpritePlayerStateData1ImageIndex], a
; PRET| 	ld c, 120
; PRET| 	call DelayFrames
; PRET| 	ld b, HIGH(vBGMap1)
; PRET| 	call CopyScreenTileBufferToVRAM
; PRET| 	hlcoord 0, 10
; PRET| 	ld bc, SCREEN_WIDTH * 6
; PRET| 	ld a, $14 ; water tile
; PRET| 	call FillMemory
; PRET| 	ld a, 1
; PRET| 	ldh [hAutoBGTransferEnabled], a
; PRET| 	call Delay3
; PRET| 	xor a
; PRET| 	ldh [hAutoBGTransferEnabled], a
; PRET| 	ld [wSSAnneSmokeDriftAmount], a
; PRET| 	ldh [rOBP1], a
; PRET| 	call UpdateCGBPal_OBP1
; PRET| 	ld a, 88
; PRET| 	ld [wSSAnneSmokeX], a
; PRET| 	ld hl, wMapViewVRAMPointer
; PRET| 	ld c, [hl]
; PRET| 	inc hl
; PRET| 	ld b, [hl]
; PRET| 	push bc
; PRET| 	push hl
; PRET| 	ld a, SFX_SS_ANNE_HORN
; PRET| 	call PlaySoundWaitForCurrent
; PRET| 	ld a, $ff
; PRET| 	ld [wUpdateSpritesEnabled], a
; PRET| 	ld d, $0
; PRET| 	ld e, $8
; PRET| .shift_columns_up
; PRET| 	ld hl, $2
; PRET| 	add hl, bc
; PRET| 	ld a, l
; PRET| 	ld [wMapViewVRAMPointer], a
; PRET| 	ld a, h
; PRET| 	ld [wMapViewVRAMPointer + 1], a
; PRET| 	push hl
; PRET| 	push de
; PRET| 	call ScheduleEastColumnRedraw
; PRET| 	call VermilionDock_EmitSmokePuff
; PRET| 	pop de
; PRET| 	ld b, $10
; PRET| .smoke_puff_drift_loop
; PRET| 	call VermilionDock_AnimSmokePuffDriftRight
; PRET| 	ld c, $8
; PRET| .delay_between_drifts
; PRET| 	call VermilionDock_SyncScrollWithLY
; PRET| 	dec c
; PRET| 	jr nz, .delay_between_drifts
; PRET| 	inc d
; PRET| 	dec b
; PRET| 	jr nz, .smoke_puff_drift_loop
; PRET| 	pop bc
; PRET| 	dec e
; PRET| 	jr nz, .shift_columns_up
; PRET| 	xor a
; PRET| 	ldh [rWY], a
; PRET| 	ldh [hWY], a
; PRET| 	call VermilionDock_EraseSSAnne
; PRET| 	ld a, $90
; PRET| 	ldh [hWY], a
; PRET| 	ld a, $1
; PRET| 	ld [wUpdateSpritesEnabled], a
; PRET| 	pop hl
; PRET| 	pop bc
; PRET| 	ld [hl], b
; PRET| 	dec hl
; PRET| 	ld [hl], c
; PRET| 	call LoadPlayerSpriteGraphics
; PRET| 	ld hl, wNumberOfWarps
; PRET| 	dec [hl]
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[add-hl-r16] VermilionDock_AnimSmokePuffDriftRight (scripts/VermilionDock.asm:125-140) — at scripts/VermilionDock.asm:135: hl de
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	push bc
; PRET| 	push de
; PRET| 	ld hl, wShadowOAMSprite04XCoord
; PRET| 	ld a, [wSSAnneSmokeDriftAmount]
; PRET| 	swap a
; PRET| 	ld c, a
; PRET| 	ld de, OBJ_SIZE
; PRET| .drift_loop
; PRET| 	inc [hl]
; PRET| 	inc [hl]
; PRET| 	add hl, de
; PRET| 	dec c
; PRET| 	jr nz, .drift_loop
; PRET| 	pop de
; PRET| 	pop bc
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] VermilionDock_EmitSmokePuff (scripts/VermilionDock.asm:144-155) — at scripts/VermilionDock.asm:153: de cannot hold the 32-bit address of VermilionDockOAMBlock; callee WriteOAMBlock has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wSSAnneSmokeX]
; PRET| 	sub 16
; PRET| 	ld [wSSAnneSmokeX], a
; PRET| 	ld c, a
; PRET| 	ld b, 100 ; Y
; PRET| 	ld a, [wSSAnneSmokeDriftAmount]
; PRET| 	inc a
; PRET| 	ld [wSSAnneSmokeDriftAmount], a
; PRET| 	ld a, $1
; PRET| 	ld de, VermilionDockOAMBlock
; PRET| 	call WriteOAMBlock
; PRET| 	ret

VermilionDockOAMBlock:
    db 0xfc, OAM_PAL1
    db 0xfd, OAM_PAL1
    db 0xfe, OAM_PAL1
    db 0xff, OAM_PAL1

; ---------------------------------------------------------------------------
; BAIL[hl-half-register-access] VermilionDock_SyncScrollWithLY (scripts/VermilionDock.asm:165-180) — at scripts/VermilionDock.asm:165: `h` is a half of ESI and has no flag-safe 8-bit x86 form
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld h, d
; PRET| 	ld l, $50
; PRET| 	call .sync_scroll_ly
; PRET| 	ld h, $0
; PRET| 	ld l, $80
; PRET| .sync_scroll_ly
; PRET| 	ldh a, [rLY]
; PRET| 	cp l
; PRET| 	jr nz, .sync_scroll_ly
; PRET| 	ld a, h
; PRET| 	ldh [rSCX], a
; PRET| .wait_for_ly_match
; PRET| 	ldh a, [rLY]
; PRET| 	cp h
; PRET| 	jr z, .wait_for_ly_match
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[screen-coord-projection] VermilionDock_EraseSSAnne (scripts/VermilionDock.asm:184-209) — at scripts/VermilionDock.asm:188: hlbgcoord 0, 10
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wVermilionDockTileMapBuffer
; PRET| 	ld bc, wVermilionDockTileMapBufferEnd - wVermilionDockTileMapBuffer
; PRET| 	ld a, $14 ; water tile
; PRET| 	call FillMemory
; PRET| 	hlbgcoord 0, 10
; PRET| 	ld de, wVermilionDockTileMapBuffer
; PRET| 	lb bc, BANK(wVermilionDockTileMapBuffer), 12
; PRET| 	call CopyVideoData
; PRET| 
; PRET| ; Replace the blocks of the lower half of the ship with water blocks. This
; PRET| ; leaves the upper half alone, but that doesn't matter because replacing any of
; PRET| ; the blocks is unnecessary because the blocks the ship occupies are south of
; PRET| ; the player and won't be redrawn when the player automatically walks north and
; PRET| ; exits the map. This code could be removed without affecting anything.
; PRET| 	hlowcoord 5, 2, VERMILION_DOCK_WIDTH
; PRET| 	ld a, $d ; water block
; PRET| 	ld [hli], a
; PRET| 	ld [hli], a
; PRET| 	ld [hli], a
; PRET| 	ld [hl], a
; PRET| 
; PRET| 	ld a, SFX_SS_ANNE_HORN
; PRET| 	call PlaySound
; PRET| 	ld c, 120
; PRET| 	call DelayFrames
; PRET| 	ret

VermilionDock_TextPointers:
    dd VermilionDockUnusedText
VermilionDockUnusedText:
    text_far _VermilionDockUnusedText
    text_end
