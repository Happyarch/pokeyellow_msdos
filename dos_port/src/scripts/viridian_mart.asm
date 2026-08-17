; ViridianMart.asm — translated from pret scripts/ViridianMart.asm by dos_port/tools/sm83xlat.
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


global ViridianMartDefaultScript
global ViridianMartOaksParcelScript
global ViridianMart_Script
global ViridianMart_ScriptPointers

extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern DecodeRLEList   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern ViridianMartCheckParcelDeliveredScript   ; NOT YET DEFINED IN THE PORT
extern ViridianMartClerkParcelQuestText   ; NOT YET DEFINED IN THE PORT
extern ViridianMartClerkSayHiToOakText   ; NOT YET DEFINED IN THE PORT
extern ViridianMartClerkText   ; NOT YET DEFINED IN THE PORT
extern ViridianMartClerkYouCameFromPalletTownText   ; NOT YET DEFINED IN THE PORT
extern ViridianMartCooltrainerMText   ; NOT YET DEFINED IN THE PORT
extern ViridianMartScript2   ; NOT YET DEFINED IN THE PORT
extern ViridianMartYoungsterText   ; NOT YET DEFINED IN THE PORT
extern ViridianMart_TextPointers   ; NOT YET DEFINED IN THE PORT
extern ViridianMart_TextPointers2   ; NOT YET DEFINED IN THE PORT
extern _ViridianMartClerkParcelQuestText   ; NOT YET DEFINED IN THE PORT
extern _ViridianMartClerkSayHiToOakText   ; NOT YET DEFINED IN THE PORT
extern _ViridianMartClerkYouCameFromPalletTownText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_VIRIDIANMART_OAKS_PARCEL                equ 1
SCRIPT_VIRIDIANMART_SCRIPT2                    equ 2
TEXT_VIRIDIANMART_CLERK_YOU_CAME_FROM_PALLET_TOWN equ 3
TEXT_VIRIDIANMART_CLERK_PARCEL_QUEST           equ 4
TEXT_VIRIDIANMART_CLERK                        equ 1
TEXT_VIRIDIANMART_YOUNGSTER                    equ 2
TEXT_VIRIDIANMART_COOLTRAINER_M                equ 3

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wViridianMartCurScript                         equ 0xD60C

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

ViridianMart_Script:
    call ViridianMartCheckParcelDeliveredScript
    call EnableAutoTextBoxDrawing
    mov esi, ViridianMart_ScriptPointers
    mov al, [ebp + wViridianMartCurScript]
    call CallFunctionInTable
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] ViridianMartCheckParcelDeliveredScript (scripts/ViridianMart.asm:10-13) — at scripts/ViridianMart.asm:11: .delivered_parcel is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_OAK_GOT_PARCEL
; PRET| 	jr nz, .delivered_parcel
; PRET| 	ld hl, ViridianMart_TextPointers
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[hl-half-register-access] ViridianMartCheckParcelDeliveredScript.delivered_parcel (scripts/ViridianMart.asm:15-21) — at scripts/ViridianMart.asm:17: `l` is a half of ESI and has no flag-safe 8-bit x86 form
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, ViridianMart_TextPointers2
; PRET| .done
; PRET| 	ld a, l
; PRET| 	ld [wCurMapTextPtr], a
; PRET| 	ld a, h
; PRET| 	ld [wCurMapTextPtr+1], a
; PRET| 	ret

ViridianMart_ScriptPointers:
    dd ViridianMartDefaultScript
    dd ViridianMartOaksParcelScript
    dd ViridianMartScript2

ViridianMartDefaultScript:
    call UpdateSprites
    mov al, TEXT_VIRIDIANMART_CLERK_YOU_CAME_FROM_PALLET_TOWN
    mov [ebp + hTextID], al
    call DisplayTextID
    mov esi, wSimulatedJoypadStatesEnd
    mov edi, .PlayerMovement   ; pret: ld de, .PlayerMovement — DecodeRLEList takes it in EDI
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_VIRIDIANMART_OAKS_PARCEL
    mov [ebp + wViridianMartCurScript], al
    ret

.PlayerMovement:
    db PAD_LEFT, 1
    db PAD_UP, 2
    db -1

ViridianMartOaksParcelScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_52
        ret
.nr_52:
    call Delay3
    mov al, TEXT_VIRIDIANMART_CLERK_PARCEL_QUEST
    mov [ebp + hTextID], al
    call DisplayTextID
    mov bx, ((70) << 8) | (1)
    call GiveItem
    SetEvent EVENT_GOT_OAKS_PARCEL
    mov al, SCRIPT_VIRIDIANMART_SCRIPT2
    mov [ebp + wViridianMartCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] ViridianMartScript2 (scripts/ViridianMart.asm:65-75) — at scripts/ViridianMart.asm:67: CheckAndSetEventReuseHL EVENT_SPAWNED_OLD_MAN_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventHL EVENT_COMPLETED_CATCH_TRAINING
; PRET| 	ret z
; PRET| 	CheckAndSetEventReuseHL EVENT_SPAWNED_OLD_MAN_1
; PRET| 	ret nz
; PRET| 	ld a, TOGGLE_OLD_MAN_2
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	ld a, TOGGLE_OLD_MAN_1
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] ViridianMart_TextPointers (scripts/ViridianMart.asm:78-111) — at scripts/ViridianMart.asm:102: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	dw ViridianMartClerkSayHiToOakText
; PRET| 	dw ViridianMartYoungsterText
; PRET| 	dw ViridianMartCooltrainerMText
; PRET| 	const_def 4
; PRET| 	dw_const ViridianMartClerkYouCameFromPalletTownText, TEXT_VIRIDIANMART_CLERK_YOU_CAME_FROM_PALLET_TOWN
; PRET| 	dw_const ViridianMartClerkParcelQuestText,           TEXT_VIRIDIANMART_CLERK_PARCEL_QUEST
; PRET| 
; PRET| ViridianMart_TextPointers2:
; PRET| 	; This becomes the primary text pointers table when Oak's parcel has been delivered.
; PRET| 	def_text_pointers
; PRET| 	dw_const ViridianMartClerkText,        TEXT_VIRIDIANMART_CLERK
; PRET| 	dw_const ViridianMartYoungsterText,    TEXT_VIRIDIANMART_YOUNGSTER
; PRET| 	dw_const ViridianMartCooltrainerMText, TEXT_VIRIDIANMART_COOLTRAINER_M
; PRET| 
; PRET| ViridianMartClerkSayHiToOakText:
; PRET| 	text_far _ViridianMartClerkSayHiToOakText
; PRET| 	text_end
; PRET| 
; PRET| ViridianMartClerkYouCameFromPalletTownText:
; PRET| 	text_far _ViridianMartClerkYouCameFromPalletTownText
; PRET| 	text_end
; PRET| 
; PRET| ViridianMartClerkParcelQuestText:
; PRET| 	text_far _ViridianMartClerkParcelQuestText
; PRET| 	sound_get_key_item
; PRET| 	text_end
; PRET| 
; PRET| ViridianMartYoungsterText:
; PRET| 	text_far _ViridianMartYoungsterText
; PRET| 	text_end
; PRET| 
; PRET| ViridianMartCooltrainerMText:
; PRET| 	text_far _ViridianMartCooltrainerMText
; PRET| 	text_end
