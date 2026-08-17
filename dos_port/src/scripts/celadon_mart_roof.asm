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


global CeladonMartRoofCurrentFloorSignText
global CeladonMartRoofDrinkList
global CeladonMartRoofLittleGirlGiveHerWhichDrinkText
global CeladonMartRoofLittleGirlImNotThirstyText
global CeladonMartRoofLittleGirlNoRoomText
global CeladonMartRoofLittleGirlReceivedTM13Text
global CeladonMartRoofLittleGirlReceivedTM48Text
global CeladonMartRoofLittleGirlReceivedTM49Text
global CeladonMartRoofLittleGirlText
global CeladonMartRoofLittleGirlYayFreshWaterText
global CeladonMartRoofLittleGirlYayLemonadeText
global CeladonMartRoofLittleGirlYaySodaPopText
global CeladonMartRoofSuperNerdText
global CeladonMartRoofVendingMachineText
global CeladonMartRoof_Script
global CeladonMartRoof_TextPointers
global RemoveItemByIDBank12

extern AddNTimes
extern Bankswitch
extern CeladonMartRoofScript_GetDrinksInBag   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofScript_GiveDrinkToGirl   ; NOT YET DEFINED IN THE PORT
extern CeladonMartRoofScript_PrintDrinksInBag   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing
extern GetItemName
extern GetQuantityOfItemInBag
extern GiveItem
extern HandleMenuInput
extern PlaceString
extern PrintText
extern RemoveItemByID
extern TextBoxBorder
extern TextScriptEnd
extern UpdateSprites
extern YesNoChoice
extern _CeladonMartRoofCurrentFloorSignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlGiveHerADrinkText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlGiveHerWhichDrinkText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlImNotThirstyText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlImThirstyText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlNoRoomText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlReceivedTM13Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlReceivedTM48Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlReceivedTM49Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlTM13ExplanationText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlTM48ExplanationText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlTM49ExplanationText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlYayFreshWaterText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlYayLemonadeText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMartRoofLittleGirlYaySodaPopText   ; NOT YET DEFINED IN THE PORT
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
%assign event_byte_a -1
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
%assign event_byte_a -1
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
%assign event_byte_a -1
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
%assign event_byte_a -1
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
%assign event_byte_a -1
.bagFull:
    mov esi, CeladonMartRoofLittleGirlNoRoomText
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.alreadyGaveDrink:
    mov esi, CeladonMartRoofLittleGirlImNotThirstyText
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
RemoveItemByIDBank12:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call RemoveItemByID
    ret

%assign event_byte -1
%assign event_byte_a -1
CeladonMartRoofLittleGirlGiveHerWhichDrinkText:
    text_far _CeladonMartRoofLittleGirlGiveHerWhichDrinkText
    text_end
CeladonMartRoofLittleGirlYayFreshWaterText:
    text_far _CeladonMartRoofLittleGirlYayFreshWaterText
    text_waitbutton
    text_end
CeladonMartRoofLittleGirlReceivedTM13Text:
    text_far _CeladonMartRoofLittleGirlReceivedTM13Text
    sound_get_item_1
    text_far _CeladonMartRoofLittleGirlTM13ExplanationText
    text_waitbutton
    text_end
CeladonMartRoofLittleGirlYaySodaPopText:
    text_far _CeladonMartRoofLittleGirlYaySodaPopText
    text_waitbutton
    text_end
CeladonMartRoofLittleGirlReceivedTM48Text:
    text_far _CeladonMartRoofLittleGirlReceivedTM48Text
    sound_get_item_1
    text_far _CeladonMartRoofLittleGirlTM48ExplanationText
    text_waitbutton
    text_end
CeladonMartRoofLittleGirlYayLemonadeText:
    text_far _CeladonMartRoofLittleGirlYayLemonadeText
    text_waitbutton
    text_end
CeladonMartRoofLittleGirlReceivedTM49Text:
    text_far _CeladonMartRoofLittleGirlReceivedTM49Text
    sound_get_item_1
    text_far _CeladonMartRoofLittleGirlTM49ExplanationText
    text_waitbutton
    text_end
CeladonMartRoofLittleGirlNoRoomText:
    text_far _CeladonMartRoofLittleGirlNoRoomText
    text_waitbutton
    text_end
CeladonMartRoofLittleGirlImNotThirstyText:
    text_far _CeladonMartRoofLittleGirlImNotThirstyText
    text_waitbutton
    text_end

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
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
CeladonMartRoofLittleGirlText:
    call CeladonMartRoofScript_GetDrinksInBag
    mov al, [ebp + wFilteredBagItemsCount]
    test al, al
    jz .noDrinksInBag
    mov al, 1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, .GiveHerADrinkText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .done
    call CeladonMartRoofScript_GiveDrinkToGirl
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.noDrinksInBag:
    mov esi, .ImThirstyText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.ImThirstyText:
    text_far _CeladonMartRoofLittleGirlImThirstyText
    text_end
.GiveHerADrinkText:
    text_far _CeladonMartRoofLittleGirlGiveHerADrinkText
    text_end
CeladonMartRoofVendingMachineText:
    script_vending_machine
CeladonMartRoofCurrentFloorSignText:
    text_far _CeladonMartRoofCurrentFloorSignText
    text_end
