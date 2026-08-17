; CeruleanBadgeHouse.asm — translated from pret scripts/CeruleanBadgeHouse.asm by dos_port/tools/sm83xlat.
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


global CeruleanBadgeHouseBoulderBadgeText
global CeruleanBadgeHouseCascadeBadgeText
global CeruleanBadgeHouseEarthBadgeText
global CeruleanBadgeHouseMarshBadgeText
global CeruleanBadgeHouseRainbowBadgeText
global CeruleanBadgeHouseSoulBadgeText
global CeruleanBadgeHouseThunderBadgeText
global CeruleanBadgeHouseVolcanoBadgeText
global CeruleanBadgeHouse_Script
global CeruleanBadgeHouse_TextPointers

extern CeruleanBadgeHouseBadgeTextPointers   ; NOT YET DEFINED IN THE PORT
extern CeruleanBadgeHouseMiddleAgedManText   ; NOT YET DEFINED IN THE PORT
extern DisplayListMenuID   ; NOT YET DEFINED IN THE PORT
extern LoadItemList   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CeruleanBadgeHouseBoulderBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanBadgeHouseCascadeBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanBadgeHouseEarthBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanBadgeHouseMarshBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanBadgeHouseMiddleAgedManText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanBadgeHouseMiddleAgedManVisitAnyTimeText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanBadgeHouseMiddleAgedManWhichBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanBadgeHouseRainbowBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanBadgeHouseSoulBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanBadgeHouseThunderBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanBadgeHouseVolcanoBadgeText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
CeruleanBadgeHouse_Script:
    mov al, 1 << BIT_NO_AUTO_TEXT_BOX
    mov [ebp + wAutoTextBoxDrawingControl], al
    dec al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    ret

%assign event_byte -1
CeruleanBadgeHouse_TextPointers:
    dd CeruleanBadgeHouseMiddleAgedManText

; ---------------------------------------------------------------------------
; BAIL[hl-half-register-access] CeruleanBadgeHouseMiddleAgedManText (scripts/CeruleanBadgeHouse.asm:14-47) — at scripts/CeruleanBadgeHouse.asm:25: `l` is a half of ESI and has no flag-safe 8-bit x86 form
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	xor a
; PRET| 	ld [wCurrentMenuItem], a
; PRET| 	ld [wListScrollOffset], a
; PRET| .loop
; PRET| 	ld hl, .WhichBadgeText
; PRET| 	call PrintText
; PRET| 	ld hl, .BadgeItemList
; PRET| 	call LoadItemList
; PRET| 	ld hl, wItemList
; PRET| 	ld a, l
; PRET| 	ld [wListPointer], a
; PRET| 	ld a, h
; PRET| 	ld [wListPointer + 1], a
; PRET| 	xor a
; PRET| 	ld [wPrintItemPrices], a
; PRET| 	ld [wMenuItemToSwap], a
; PRET| 	ld a, SPECIALLISTMENU
; PRET| 	ld [wListMenuID], a
; PRET| 	call DisplayListMenuID
; PRET| 	jr c, .done
; PRET| 	ld hl, CeruleanBadgeHouseBadgeTextPointers
; PRET| 	ld a, [wCurItem]
; PRET| 	sub BOULDERBADGE
; PRET| 	add a
; PRET| 	ld d, $0
; PRET| 	ld e, a
; PRET| 	add hl, de
; PRET| 	ld a, [hli]
; PRET| 	ld h, [hl]
; PRET| 	ld l, a
; PRET| 	call PrintText
; PRET| 	jr .loop

%assign event_byte -1
.done:
    xor al, al
    mov [ebp + wListScrollOffset], al
    mov esi, .VisitAnyTimeText
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
.BadgeItemList:
    db 8
    db 21
    db 22
    db 23
    db 24
    db 25
    db 26
    db 27
    db 28
    db -1
.Text:
    text_far _CeruleanBadgeHouseMiddleAgedManText
    text_end
.WhichBadgeText:
    text_far _CeruleanBadgeHouseMiddleAgedManWhichBadgeText
    text_end
.VisitAnyTimeText:
    text_far _CeruleanBadgeHouseMiddleAgedManVisitAnyTimeText
    text_end
    dd CeruleanBadgeHouseBoulderBadgeText
    dd CeruleanBadgeHouseCascadeBadgeText
    dd CeruleanBadgeHouseThunderBadgeText
    dd CeruleanBadgeHouseRainbowBadgeText
    dd CeruleanBadgeHouseSoulBadgeText
    dd CeruleanBadgeHouseMarshBadgeText
    dd CeruleanBadgeHouseVolcanoBadgeText
    dd CeruleanBadgeHouseEarthBadgeText
CeruleanBadgeHouseBoulderBadgeText:
    text_far _CeruleanBadgeHouseBoulderBadgeText
    text_end
CeruleanBadgeHouseCascadeBadgeText:
    text_far _CeruleanBadgeHouseCascadeBadgeText
    text_end
CeruleanBadgeHouseThunderBadgeText:
    text_far _CeruleanBadgeHouseThunderBadgeText
    text_end
CeruleanBadgeHouseRainbowBadgeText:
    text_far _CeruleanBadgeHouseRainbowBadgeText
    text_end
CeruleanBadgeHouseSoulBadgeText:
    text_far _CeruleanBadgeHouseSoulBadgeText
    text_end
CeruleanBadgeHouseMarshBadgeText:
    text_far _CeruleanBadgeHouseMarshBadgeText
    text_end
CeruleanBadgeHouseVolcanoBadgeText:
    text_far _CeruleanBadgeHouseVolcanoBadgeText
    text_end
CeruleanBadgeHouseEarthBadgeText:
    text_far _CeruleanBadgeHouseEarthBadgeText
    text_end
