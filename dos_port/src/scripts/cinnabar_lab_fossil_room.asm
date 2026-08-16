; CinnabarLabFossilRoom.asm — translated from pret scripts/CinnabarLabFossilRoom.asm by dos_port/tools/sm83xlat.
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


global CinnabarLabFossilRoomScientist2Text
global CinnabarLabFossilRoom_Script
global CinnabarLabFossilRoom_TextPointers
global FossilsList
global LoadFossilItemAndMonNameBank1D

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CinnabarLabFossilRoomScientist1Text   ; NOT YET DEFINED IN THE PORT
extern DoInGameTradeDialogue   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GetQuantityOfItemInBag   ; NOT YET DEFINED IN THE PORT
extern GivePokemon   ; NOT YET DEFINED IN THE PORT
extern Lab4Script_GetFossilsInBag   ; NOT YET DEFINED IN THE PORT
extern LoadFossilItemAndMonName   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabFossilRoomScientist1FossilIsBackToLifeText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabFossilRoomScientist1GoForAWalkText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabFossilRoomScientist1NoFossilsText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabFossilRoomScientist1Text   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wFilteredBagItems                              equ 0xCC5B
wFilteredBagItemsCount                         equ 0xCD37
wFossilMon                                     equ 0xD70F

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

CinnabarLabFossilRoom_Script:
    jmp EnableAutoTextBoxDrawing

CinnabarLabFossilRoom_TextPointers:
    dd CinnabarLabFossilRoomScientist1Text
    dd CinnabarLabFossilRoomScientist2Text

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] Lab4Script_GetFossilsInBag (scripts/CinnabarLabFossilRoom.asm:11-37) — at scripts/CinnabarLabFossilRoom.asm:16: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	xor a
; PRET| 	ld [wFilteredBagItemsCount], a
; PRET| 	ld de, wFilteredBagItems
; PRET| 	ld hl, FossilsList
; PRET| .loop
; PRET| 	ld a, [hli]
; PRET| 	and a
; PRET| 	jr z, .done
; PRET| 	push hl
; PRET| 	push de
; PRET| 	ld [wTempByteValue], a
; PRET| 	ld b, a
; PRET| 	predef GetQuantityOfItemInBag
; PRET| 	pop de
; PRET| 	pop hl
; PRET| 	ld a, b
; PRET| 	and a
; PRET| 	jr z, .loop
; PRET| 	; A fossil is in the bag
; PRET| 	ld a, [wTempByteValue]
; PRET| 	ld [de], a
; PRET| 	inc de
; PRET| 	push hl
; PRET| 	ld hl, wFilteredBagItemsCount
; PRET| 	inc [hl]
; PRET| 	pop hl
; PRET| 	jr .loop

; ---------------------------------------------------------------------------
; BAIL[ld-via-bc-de] Lab4Script_GetFossilsInBag.done (scripts/CinnabarLabFossilRoom.asm:39-41) — at scripts/CinnabarLabFossilRoom.asm:40: [dx] needs a 16-bit GB pointer
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, $ff
; PRET| 	ld [de], a
; PRET| 	ret

FossilsList:
    db 41
    db 42
    db 31
    db 0

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CinnabarLabFossilRoomScientist1Text (scripts/CinnabarLabFossilRoom.asm:51-60) — at scripts/CinnabarLabFossilRoom.asm:52: .check_done_reviving is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GAVE_FOSSIL_TO_LAB
; PRET| 	jr nz, .check_done_reviving
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	call Lab4Script_GetFossilsInBag
; PRET| 	ld a, [wFilteredBagItemsCount]
; PRET| 	and a
; PRET| 	jr z, .no_fossils
; PRET| 	farcall GiveFossilToCinnabarLab
; PRET| 	jr .done

.no_fossils:
    mov esi, .NoFossilsText
    call PrintText
.done:
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] CinnabarLabFossilRoomScientist1Text.check_done_reviving (scripts/CinnabarLabFossilRoom.asm:67-71) — at scripts/CinnabarLabFossilRoom.asm:67: CheckEventAfterBranchReuseA EVENT_LAB_STILL_REVIVING_FOSSIL, EVENT_GAVE_FOSSIL_TO_LAB
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventAfterBranchReuseA EVENT_LAB_STILL_REVIVING_FOSSIL, EVENT_GAVE_FOSSIL_TO_LAB
; PRET| 	jr z, .done_reviving
; PRET| 	ld hl, .GoForAWalkText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CinnabarLabFossilRoomScientist1Text.done_reviving (scripts/CinnabarLabFossilRoom.asm:73-83) — at scripts/CinnabarLabFossilRoom.asm:81: .done is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call LoadFossilItemAndMonNameBank1D
; PRET| 	ld hl, .FossilIsBackToLifeText
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_LAB_HANDING_OVER_FOSSIL_MON
; PRET| 	ld a, [wFossilMon]
; PRET| 	ld b, a
; PRET| 	ld c, 30
; PRET| 	call GivePokemon
; PRET| 	jr nc, .done
; PRET| 	ResetEvents EVENT_GAVE_FOSSIL_TO_LAB, EVENT_LAB_STILL_REVIVING_FOSSIL, EVENT_LAB_HANDING_OVER_FOSSIL_MON
; PRET| 	jr .done

.Text:
    text_far _CinnabarLabFossilRoomScientist1Text
    text_end
.NoFossilsText:
    text_far _CinnabarLabFossilRoomScientist1NoFossilsText
    text_end
.GoForAWalkText:
    text_far _CinnabarLabFossilRoomScientist1GoForAWalkText
    text_end
.FossilIsBackToLifeText:
    text_far _CinnabarLabFossilRoomScientist1FossilIsBackToLifeText
    text_end

CinnabarLabFossilRoomScientist2Text:
    mov al, 3
    mov [ebp + wWhichTrade], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call DoInGameTradeDialogue
    jmp TextScriptEnd

LoadFossilItemAndMonNameBank1D:
; DEVIATION{class=banking; pret=macros/farcall.asm:farjp; behavior=bank switch dropped, jmp goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    jmp LoadFossilItemAndMonName
