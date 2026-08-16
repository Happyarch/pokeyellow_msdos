; WardensHouse.asm — translated from pret scripts/WardensHouse.asm by dos_port/tools/sm83xlat.
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


global WardensHouseDisplayText
global WardensHouse_Script
global WardensHouse_TextPointers

extern BoulderText   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern IsItemInBag   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern RemoveItemByID   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern WardensHouseWardenText   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _WardensHouseDisplayMerchandiseText   ; NOT YET DEFINED IN THE PORT
extern _WardensHouseDisplayPhotosAndFossilsText   ; NOT YET DEFINED IN THE PORT
extern _WardensHouseWardenGaveTheGoldTeethText   ; NOT YET DEFINED IN THE PORT
extern _WardensHouseWardenGibberish1Text   ; NOT YET DEFINED IN THE PORT
extern _WardensHouseWardenGibberish2Text   ; NOT YET DEFINED IN THE PORT
extern _WardensHouseWardenGibberish3Text   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
TEXT_WARDENSHOUSE_DISPLAY_LEFT                 equ 4

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

WardensHouse_Script:
    jmp EnableAutoTextBoxDrawing

WardensHouse_TextPointers:
    dd WardensHouseWardenText
    dd PickUpItemText
    dd BoulderText
    dd WardensHouseDisplayText
    dd WardensHouseDisplayText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] WardensHouseWardenText (scripts/WardensHouse.asm:14-31) — at scripts/WardensHouse.asm:15: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_HM04
; PRET| 	jr nz, .got_item
; PRET| 	ld b, GOLD_TEETH
; PRET| 	call IsItemInBag
; PRET| 	jr nz, .have_gold_teeth
; PRET| 	CheckEvent EVENT_GAVE_GOLD_TEETH
; PRET| 	jr nz, .gave_gold_teeth
; PRET| 	ld hl, .Gibberish1Text
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	ld hl, .Gibberish3Text
; PRET| 	jr nz, .refused
; PRET| 	ld hl, .Gibberish2Text
; PRET| .refused
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] WardensHouseWardenText.have_gold_teeth (scripts/WardensHouse.asm:33-48) — at scripts/WardensHouse.asm:33: .GaveTheGoldTeethText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .GaveTheGoldTeethText
; PRET| 	call PrintText
; PRET| 	ld a, GOLD_TEETH
; PRET| 	ldh [hItemToRemoveID], a
; PRET| 	farcall RemoveItemByID
; PRET| 	SetEvent EVENT_GAVE_GOLD_TEETH
; PRET| .gave_gold_teeth
; PRET| 	ld hl, .ThanksText
; PRET| 	call PrintText
; PRET| 	lb bc, HM_STRENGTH, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, .ReceivedHM04Text
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_HM04
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] WardensHouseWardenText.got_item (scripts/WardensHouse.asm:50-52) — at scripts/WardensHouse.asm:50: .HM04ExplanationText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .HM04ExplanationText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] WardensHouseWardenText.bag_full (scripts/WardensHouse.asm:54-57) — at scripts/WardensHouse.asm:54: .HM04NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .HM04NoRoomText
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] WardensHouseWardenText.Gibberish1Text (scripts/WardensHouse.asm:60-94) — at scripts/WardensHouse.asm:73: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _WardensHouseWardenGibberish1Text
; PRET| 	text_end
; PRET| 
; PRET| .Gibberish2Text:
; PRET| 	text_far _WardensHouseWardenGibberish2Text
; PRET| 	text_end
; PRET| 
; PRET| .Gibberish3Text:
; PRET| 	text_far _WardensHouseWardenGibberish3Text
; PRET| 	text_end
; PRET| 
; PRET| .GaveTheGoldTeethText:
; PRET| 	text_far _WardensHouseWardenGaveTheGoldTeethText
; PRET| 	sound_get_item_1
; PRET| 
; PRET| .PoppedInHisTeethText: ; unreferenced
; PRET| 	text_far _WardensHouseWardenTeethPoppedInHisTeethText
; PRET| 	text_end
; PRET| 
; PRET| .ThanksText:
; PRET| 	text_far _WardensHouseWardenThanksText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedHM04Text:
; PRET| 	text_far _WardensHouseWardenReceivedHM04Text
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .HM04ExplanationText:
; PRET| 	text_far _WardensHouseWardenHM04ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| .HM04NoRoomText:
; PRET| 	text_far _WardensHouseWardenHM04NoRoomText
; PRET| 	text_end

WardensHouseDisplayText:
    mov al, [ebp + hTextID]
    cmp al, TEXT_WARDENSHOUSE_DISPLAY_LEFT
    mov esi, .MerchandiseText
    jnz .print_text
    mov esi, .PhotosAndFossilsText
.print_text:
    call PrintText
    jmp TextScriptEnd

.PhotosAndFossilsText:
    text_far _WardensHouseDisplayPhotosAndFossilsText
    text_end
.MerchandiseText:
    text_far _WardensHouseDisplayMerchandiseText
    text_end
