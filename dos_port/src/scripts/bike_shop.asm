; BikeShop.asm — translated from pret scripts/BikeShop.asm by dos_port/tools/sm83xlat.
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


global BikeShopMiddleAgedWomanText
global BikeShopYoungsterText
global BikeShop_Script
global BikeShop_TextPointers

extern BikeShopBagFullText   ; NOT YET DEFINED IN THE PORT
extern BikeShopCantAffordText   ; NOT YET DEFINED IN THE PORT
extern BikeShopClerkDoYouLikeItText   ; NOT YET DEFINED IN THE PORT
extern BikeShopClerkHowDoYouLikeYourBicycleText   ; NOT YET DEFINED IN THE PORT
extern BikeShopClerkOhThatsAVoucherText   ; NOT YET DEFINED IN THE PORT
extern BikeShopClerkText   ; NOT YET DEFINED IN THE PORT
extern BikeShopClerkWelcomeText   ; NOT YET DEFINED IN THE PORT
extern BikeShopComeAgainText   ; NOT YET DEFINED IN THE PORT
extern BikeShopExchangedVoucherText   ; NOT YET DEFINED IN THE PORT
extern BikeShopMenuPrice   ; NOT YET DEFINED IN THE PORT
extern BikeShopMenuText   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern HandleMenuInput   ; NOT YET DEFINED IN THE PORT
extern IsItemInBag   ; NOT YET DEFINED IN THE PORT
extern PlaceString   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern RemoveItemByID   ; NOT YET DEFINED IN THE PORT
extern TextBoxBorder   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern _BikeShopMiddleAgedWomanText   ; NOT YET DEFINED IN THE PORT
extern _BikeShopYoungsterCoolBikeText   ; NOT YET DEFINED IN THE PORT
extern _BikeShopYoungsterTheseBikesAreExpensiveText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
BikeShop_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
%assign event_byte_a -1
BikeShop_TextPointers:
    dd BikeShopClerkText
    dd BikeShopMiddleAgedWomanText
    dd BikeShopYoungsterText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] BikeShopClerkText (scripts/BikeShop.asm:13-17) — at scripts/BikeShop.asm:14: BikeShopClerkText.dontHaveBike is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_BICYCLE
; PRET| 	jr z, .dontHaveBike
; PRET| 	ld hl, BikeShopClerkHowDoYouLikeYourBicycleText
; PRET| 	call PrintText
; PRET| 	jp .Done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] BikeShopClerkText.dontHaveBike (scripts/BikeShop.asm:19-33) — at scripts/BikeShop.asm:21: BikeShopClerkText.dontHaveVoucher is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld b, BIKE_VOUCHER
; PRET| 	call IsItemInBag
; PRET| 	jr z, .dontHaveVoucher
; PRET| 	ld hl, BikeShopClerkOhThatsAVoucherText
; PRET| 	call PrintText
; PRET| 	lb bc, BICYCLE, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .BagFull
; PRET| 	ld a, BIKE_VOUCHER
; PRET| 	ldh [hItemToRemoveID], a
; PRET| 	farcall RemoveItemByID
; PRET| 	SetEvent EVENT_GOT_BICYCLE
; PRET| 	ld hl, BikeShopExchangedVoucherText
; PRET| 	call PrintText
; PRET| 	jr .Done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] BikeShopClerkText.BagFull (scripts/BikeShop.asm:35-37) — at scripts/BikeShop.asm:37: BikeShopClerkText.Done is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, BikeShopBagFullText
; PRET| 	call PrintText
; PRET| 	jr .Done

; ---------------------------------------------------------------------------
; BAIL[screen-coord-projection] BikeShopClerkText.dontHaveVoucher (scripts/BikeShop.asm:39-81) — at scripts/BikeShop.asm:54: hlcoord 0, 0
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, BikeShopClerkWelcomeText
; PRET| 	call PrintText
; PRET| 	xor a
; PRET| 	ld [wCurrentMenuItem], a
; PRET| 	ld [wLastMenuItem], a
; PRET| 	ld a, PAD_A | PAD_B
; PRET| 	ld [wMenuWatchedKeys], a
; PRET| 	ld a, $1
; PRET| 	ld [wMaxMenuItem], a
; PRET| 	ld a, $2
; PRET| 	ld [wTopMenuItemY], a
; PRET| 	ld a, $1
; PRET| 	ld [wTopMenuItemX], a
; PRET| 	ld hl, wStatusFlags5
; PRET| 	set BIT_NO_TEXT_DELAY, [hl]
; PRET| 	hlcoord 0, 0
; PRET| 	lb bc, 4, 15
; PRET| 	call TextBoxBorder
; PRET| 	call UpdateSprites
; PRET| 	hlcoord 2, 2
; PRET| 	ld de, BikeShopMenuText
; PRET| 	call PlaceString
; PRET| 	hlcoord 8, 3
; PRET| 	ld de, BikeShopMenuPrice
; PRET| 	call PlaceString
; PRET| 	ld hl, BikeShopClerkDoYouLikeItText
; PRET| 	call PrintText
; PRET| 	; This fixes the bike shop instatext glitch
; PRET| 	ld hl, wStatusFlags5
; PRET| 	res BIT_NO_TEXT_DELAY, [hl]
; PRET| 	call HandleMenuInput
; PRET| 	bit B_PAD_B, a
; PRET| 	jr nz, .cancel
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jr nz, .cancel
; PRET| 	ld hl, BikeShopCantAffordText
; PRET| 	call PrintText
; PRET| .cancel
; PRET| 	ld hl, BikeShopComeAgainText
; PRET| 	call PrintText
; PRET| .Done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[inline-text-db] BikeShopMenuText (scripts/BikeShop.asm:84-121) — at scripts/BikeShop.asm:84: db   "BICYCLE"
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	db   "BICYCLE"
; PRET| 	next "CANCEL@"
; PRET| 
; PRET| BikeShopMenuPrice:
; PRET| 	db "¥1000000@"
; PRET| 
; PRET| BikeShopClerkWelcomeText:
; PRET| 	text_far _BikeShopClerkWelcomeText
; PRET| 	text_end
; PRET| 
; PRET| BikeShopClerkDoYouLikeItText:
; PRET| 	text_far _BikeShopClerkDoYouLikeItText
; PRET| 	text_end
; PRET| 
; PRET| BikeShopCantAffordText:
; PRET| 	text_far _BikeShopCantAffordText
; PRET| 	text_end
; PRET| 
; PRET| BikeShopClerkOhThatsAVoucherText:
; PRET| 	text_far _BikeShopClerkOhThatsAVoucherText
; PRET| 	text_end
; PRET| 
; PRET| BikeShopExchangedVoucherText:
; PRET| 	text_far _BikeShopExchangedVoucherText
; PRET| 	sound_get_key_item
; PRET| 	text_end
; PRET| 
; PRET| BikeShopComeAgainText:
; PRET| 	text_far _BikeShopComeAgainText
; PRET| 	text_end
; PRET| 
; PRET| BikeShopClerkHowDoYouLikeYourBicycleText:
; PRET| 	text_far _BikeShopClerkHowDoYouLikeYourBicycleText
; PRET| 	text_end
; PRET| 
; PRET| BikeShopBagFullText:
; PRET| 	text_far _BikeShopBagFullText
; PRET| 	text_end

%assign event_byte -1
%assign event_byte_a -1
BikeShopMiddleAgedWomanText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _BikeShopMiddleAgedWomanText
    text_end

%assign event_byte -1
%assign event_byte_a -1
BikeShopYoungsterText:
    CheckEvent EVENT_GOT_BICYCLE
    mov esi, .CoolBikeText
    jnz .gotBike
    mov esi, .TheseBikesAreExpensiveText
.gotBike:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.TheseBikesAreExpensiveText:
    text_far _BikeShopYoungsterTheseBikesAreExpensiveText
    text_end
.CoolBikeText:
    text_far _BikeShopYoungsterCoolBikeText
    text_end
