; CeladonMartRoof.asm — translated from pret scripts/CeladonMartRoof.asm by dos_port/tools/sm83xlat.
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


global CeladonMartRoofDrinkList
global CeladonMartRoofSuperNerdText
global CeladonMartRoof_Script
global CeladonMartRoof_TextPointers
global RemoveItemByIDBank12

extern AddNTimes   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofCurrentFloorSignText   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofLittleGirlGiveHerWhichDrinkText   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofLittleGirlImNotThirstyText   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofLittleGirlNoRoomText   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofLittleGirlReceivedTM13Text   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofLittleGirlReceivedTM48Text   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofLittleGirlReceivedTM49Text   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofLittleGirlText   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofLittleGirlYayFreshWaterText   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofLittleGirlYayLemonadeText   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofLittleGirlYaySodaPopText   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofScript_GetDrinksInBag   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofScript_GiveDrinkToGirl   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofScript_PrintDrinksInBag   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofVendingMachineText   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GetItemName   ; NOT YET DEFINED IN THE PORT
extern GetQuantityOfItemInBag   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern HandleMenuInput   ; NOT YET DEFINED IN THE PORT
extern PlaceString   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern RemoveItemByID   ; NOT YET DEFINED IN THE PORT
extern TextBoxBorder   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlGiveHerADrinkText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlGiveHerWhichDrinkText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlImThirstyText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlReceivedTM13Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlYayFreshWaterText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofSuperNerdText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hItemCounter                                   equ 0xFFDB
wFilteredBagItems                              equ 0xCC5B
wFilteredBagItemsCount                         equ 0xCD37

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
CeladonMartRoof_Script:
    call EnableAutoTextBoxDrawing
    ret

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] CeladonMartRoofScript_GetDrinksInBag (scripts/CeladonMartRoof.asm:7-33) — at scripts/CeladonMartRoof.asm:12: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	xor a
; PRET| 	ld [wFilteredBagItemsCount], a
; PRET| 	ld de, wFilteredBagItems
; PRET| 	ld hl, CeladonMartRoofDrinkList
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
; PRET| 	; A drink is in the bag
; PRET| 	ld a, [wTempByteValue]
; PRET| 	ld [de], a
; PRET| 	inc de
; PRET| 	push hl
; PRET| 	ld hl, wFilteredBagItemsCount
; PRET| 	inc [hl]
; PRET| 	pop hl
; PRET| 	jr .loop

; ---------------------------------------------------------------------------
; BAIL[ld-via-bc-de] CeladonMartRoofScript_GetDrinksInBag.done (scripts/CeladonMartRoof.asm:35-37) — at scripts/CeladonMartRoof.asm:36: [dx] needs a 16-bit GB pointer
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, $ff
; PRET| 	ld [de], a
; PRET| 	ret

%assign event_byte -1
CeladonMartRoofDrinkList:
    db FRESH_WATER
    db SODA_POP
    db LEMONADE
    db 0

; ---------------------------------------------------------------------------
; BAIL[hl-half-register-access] CeladonMartRoofScript_GiveDrinkToGirl (scripts/CeladonMartRoof.asm:46-101) — at scripts/CeladonMartRoof.asm:66: `l` is a half of ESI and has no flag-safe 8-bit x86 form
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wStatusFlags5
; PRET| 	set BIT_NO_TEXT_DELAY, [hl]
; PRET| 	ld hl, CeladonMartRoofLittleGirlGiveHerWhichDrinkText
; PRET| 	call PrintText
; PRET| 	xor a
; PRET| 	ld [wCurrentMenuItem], a
; PRET| 	ld a, PAD_A | PAD_B
; PRET| 	ld [wMenuWatchedKeys], a
; PRET| 	ld a, [wFilteredBagItemsCount]
; PRET| 	dec a
; PRET| 	ld [wMaxMenuItem], a
; PRET| 	ld a, 2
; PRET| 	ld [wTopMenuItemY], a
; PRET| 	ld a, 1
; PRET| 	ld [wTopMenuItemX], a
; PRET| 	ld a, [wFilteredBagItemsCount]
; PRET| 	dec a
; PRET| 	ld bc, 2
; PRET| 	ld hl, 3
; PRET| 	call AddNTimes
; PRET| 	dec l
; PRET| 	ld b, l
; PRET| 	ld c, 12
; PRET| 	hlcoord 0, 0
; PRET| 	call TextBoxBorder
; PRET| 	call UpdateSprites
; PRET| 	call CeladonMartRoofScript_PrintDrinksInBag
; PRET| 	ld hl, wStatusFlags5
; PRET| 	res BIT_NO_TEXT_DELAY, [hl]
; PRET| 	call HandleMenuInput
; PRET| 	bit B_PAD_B, a
; PRET| 	ret nz
; PRET| 	ld hl, wFilteredBagItems
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	ld d, 0
; PRET| 	ld e, a
; PRET| 	add hl, de
; PRET| 	ld a, [hl]
; PRET| 	ldh [hItemToRemoveID], a
; PRET| 	cp FRESH_WATER
; PRET| 	jr z, .gaveFreshWater
; PRET| 	cp SODA_POP
; PRET| 	jr z, .gaveSodaPop
; PRET| ; gave Lemonade
; PRET| 	CheckEvent EVENT_GOT_TM49
; PRET| 	jr nz, .alreadyGaveDrink
; PRET| 	ld hl, CeladonMartRoofLittleGirlYayLemonadeText
; PRET| 	call PrintText
; PRET| 	call RemoveItemByIDBank12
; PRET| 	lb bc, TM_TRI_ATTACK, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bagFull
; PRET| 	ld hl, CeladonMartRoofLittleGirlReceivedTM49Text
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_TM49
; PRET| 	ret

%assign event_byte -1
.gaveSodaPop:
    CheckEvent EVENT_GOT_TM48
    jnz .alreadyGaveDrink
    mov esi, CeladonMartRoofLittleGirlYaySodaPopText
    call PrintText
    call RemoveItemByIDBank12
    mov bx, ((250) << 8) | (1)
    call GiveItem
    jae .bagFull
    mov esi, CeladonMartRoofLittleGirlReceivedTM48Text
    call PrintText
    SetEvent EVENT_GOT_TM48
    ret

%assign event_byte -1
.gaveFreshWater:
    CheckEvent EVENT_GOT_TM13
    jnz .alreadyGaveDrink
    mov esi, CeladonMartRoofLittleGirlYayFreshWaterText
    call PrintText
    call RemoveItemByIDBank12
    mov bx, ((215) << 8) | (1)
    call GiveItem
    jae .bagFull
    mov esi, CeladonMartRoofLittleGirlReceivedTM13Text
    call PrintText
    SetEvent EVENT_GOT_TM13
    ret

%assign event_byte -1
.bagFull:
    mov esi, CeladonMartRoofLittleGirlNoRoomText
    call PrintText
    ret

%assign event_byte -1
.alreadyGaveDrink:
    mov esi, CeladonMartRoofLittleGirlImNotThirstyText
    call PrintText
    ret

%assign event_byte -1
RemoveItemByIDBank12:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call RemoveItemByID
    ret

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] CeladonMartRoofLittleGirlGiveHerWhichDrinkText (scripts/CeladonMartRoof.asm:142-189) — at scripts/CeladonMartRoof.asm:152: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonMartRoofLittleGirlGiveHerWhichDrinkText
; PRET| 	text_end
; PRET| 
; PRET| CeladonMartRoofLittleGirlYayFreshWaterText:
; PRET| 	text_far _CeladonMartRoofLittleGirlYayFreshWaterText
; PRET| 	text_waitbutton
; PRET| 	text_end
; PRET| 
; PRET| CeladonMartRoofLittleGirlReceivedTM13Text:
; PRET| 	text_far _CeladonMartRoofLittleGirlReceivedTM13Text
; PRET| 	sound_get_item_1
; PRET| 	text_far _CeladonMartRoofLittleGirlTM13ExplanationText
; PRET| 	text_waitbutton
; PRET| 	text_end
; PRET| 
; PRET| CeladonMartRoofLittleGirlYaySodaPopText:
; PRET| 	text_far _CeladonMartRoofLittleGirlYaySodaPopText
; PRET| 	text_waitbutton
; PRET| 	text_end
; PRET| 
; PRET| CeladonMartRoofLittleGirlReceivedTM48Text:
; PRET| 	text_far _CeladonMartRoofLittleGirlReceivedTM48Text
; PRET| 	sound_get_item_1
; PRET| 	text_far _CeladonMartRoofLittleGirlTM48ExplanationText
; PRET| 	text_waitbutton
; PRET| 	text_end
; PRET| 
; PRET| CeladonMartRoofLittleGirlYayLemonadeText:
; PRET| 	text_far _CeladonMartRoofLittleGirlYayLemonadeText
; PRET| 	text_waitbutton
; PRET| 	text_end
; PRET| 
; PRET| CeladonMartRoofLittleGirlReceivedTM49Text:
; PRET| 	text_far _CeladonMartRoofLittleGirlReceivedTM49Text
; PRET| 	sound_get_item_1
; PRET| 	text_far _CeladonMartRoofLittleGirlTM49ExplanationText
; PRET| 	text_waitbutton
; PRET| 	text_end
; PRET| 
; PRET| CeladonMartRoofLittleGirlNoRoomText:
; PRET| 	text_far _CeladonMartRoofLittleGirlNoRoomText
; PRET| 	text_waitbutton
; PRET| 	text_end
; PRET| 
; PRET| CeladonMartRoofLittleGirlImNotThirstyText:
; PRET| 	text_far _CeladonMartRoofLittleGirlImNotThirstyText
; PRET| 	text_waitbutton
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[screen-coord-projection] CeladonMartRoofScript_PrintDrinksInBag (scripts/CeladonMartRoof.asm:192-211) — at scripts/CeladonMartRoof.asm:202: hlcoord 2, 2
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wFilteredBagItems
; PRET| 	xor a
; PRET| 	ldh [hItemCounter], a
; PRET| .loop
; PRET| 	ld a, [hli]
; PRET| 	cp $ff
; PRET| 	ret z
; PRET| 	push hl
; PRET| 	ld [wNamedObjectIndex], a
; PRET| 	call GetItemName
; PRET| 	hlcoord 2, 2
; PRET| 	ldh a, [hItemCounter]
; PRET| 	ld bc, SCREEN_WIDTH * 2
; PRET| 	call AddNTimes
; PRET| 	ld de, wNameBuffer
; PRET| 	call PlaceString
; PRET| 	ld hl, hItemCounter
; PRET| 	inc [hl]
; PRET| 	pop hl
; PRET| 	jr .loop

%assign event_byte -1
CeladonMartRoof_TextPointers:
    dd CeladonMartRoofSuperNerdText
    dd CeladonMartRoofLittleGirlText
    dd CeladonMartRoofVendingMachineText
    dd CeladonMartRoofVendingMachineText
    dd CeladonMartRoofVendingMachineText
    dd CeladonMartRoofCurrentFloorSignText
CeladonMartRoofSuperNerdText:
    text_far _CeladonMartRoofSuperNerdText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonMartRoofLittleGirlText (scripts/CeladonMartRoof.asm:228-241) — at scripts/CeladonMartRoof.asm:231: .noDrinksInBag is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call CeladonMartRoofScript_GetDrinksInBag
; PRET| 	ld a, [wFilteredBagItemsCount]
; PRET| 	and a
; PRET| 	jr z, .noDrinksInBag
; PRET| 	ld a, 1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld hl, .GiveHerADrinkText
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jr nz, .done
; PRET| 	call CeladonMartRoofScript_GiveDrinkToGirl
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonMartRoofLittleGirlText.noDrinksInBag (scripts/CeladonMartRoof.asm:243-246) — at scripts/CeladonMartRoof.asm:243: .ImThirstyText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .ImThirstyText
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-script-command-unported] CeladonMartRoofLittleGirlText.ImThirstyText (scripts/CeladonMartRoof.asm:249-261) — at scripts/CeladonMartRoof.asm:257: script_vending_machine
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonMartRoofLittleGirlImThirstyText
; PRET| 	text_end
; PRET| 
; PRET| .GiveHerADrinkText:
; PRET| 	text_far _CeladonMartRoofLittleGirlGiveHerADrinkText
; PRET| 	text_end
; PRET| 
; PRET| CeladonMartRoofVendingMachineText:
; PRET| 	script_vending_machine
; PRET| 
; PRET| CeladonMartRoofCurrentFloorSignText:
; PRET| 	text_far _CeladonMartRoofCurrentFloorSignText
; PRET| 	text_end
