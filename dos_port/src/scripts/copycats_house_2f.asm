; CopycatsHouse2F.asm — translated from pret scripts/CopycatsHouse2F.asm by dos_port/tools/sm83xlat.
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


global CopycatsHouse2FPCText
global CopycatsHouse2F_Script
global CopycatsHouse2F_TextPointers

extern CopycatsHouse2FCopycatText   ; NOT YET DEFINED IN THE PORT
extern CopycatsHouse2FDoduoText   ; NOT YET DEFINED IN THE PORT
extern CopycatsHouse2FRareDollText   ; NOT YET DEFINED IN THE PORT
extern CopycatsHouse2FSNESText   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern IsItemInBag   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern RemoveItemByID   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FCopycatDoYouLikePokemonText   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FCopycatReceivedTM31Text   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FCopycatTM31PreReceiveText   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FPCCantSeeText   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FPCMySecretsText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
CopycatsHouse2F_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
CopycatsHouse2F_TextPointers:
    dd CopycatsHouse2FCopycatText
    dd CopycatsHouse2FDoduoText
    dd CopycatsHouse2FRareDollText
    dd CopycatsHouse2FRareDollText
    dd CopycatsHouse2FRareDollText
    dd CopycatsHouse2FSNESText
    dd CopycatsHouse2FPCText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CopycatsHouse2FCopycatText (scripts/CopycatsHouse2F.asm:16-36) — at scripts/CopycatsHouse2F.asm:17: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_TM31
; PRET| 	jr nz, .got_item
; PRET| 	ld a, TRUE
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld hl, .DoYouLikePokemonText
; PRET| 	call PrintText
; PRET| 	ld b, POKE_DOLL
; PRET| 	call IsItemInBag
; PRET| 	jr z, .done
; PRET| 	ld hl, .TM31PreReceiveText
; PRET| 	call PrintText
; PRET| 	lb bc, TM_MIMIC, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, .ReceivedTM31Text
; PRET| 	call PrintText
; PRET| 	ld a, POKE_DOLL
; PRET| 	ldh [hItemToRemoveID], a
; PRET| 	farcall RemoveItemByID
; PRET| 	SetEvent EVENT_GOT_TM31
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CopycatsHouse2FCopycatText.bag_full (scripts/CopycatsHouse2F.asm:38-40) — at scripts/CopycatsHouse2F.asm:38: .TM31NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM31NoRoomText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CopycatsHouse2FCopycatText.got_item (scripts/CopycatsHouse2F.asm:42-45) — at scripts/CopycatsHouse2F.asm:42: .TM31Explanation2Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM31Explanation2Text
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] CopycatsHouse2FCopycatText.DoYouLikePokemonText (scripts/CopycatsHouse2F.asm:48-82) — at scripts/CopycatsHouse2F.asm:57: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CopycatsHouse2FCopycatDoYouLikePokemonText
; PRET| 	text_end
; PRET| 
; PRET| .TM31PreReceiveText:
; PRET| 	text_far _CopycatsHouse2FCopycatTM31PreReceiveText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedTM31Text:
; PRET| 	text_far _CopycatsHouse2FCopycatReceivedTM31Text
; PRET| 	sound_get_item_1
; PRET| .TM31Explanation1Text:
; PRET| 	text_far _CopycatsHouse2FCopycatTM31Explanation1Text
; PRET| 	text_waitbutton
; PRET| 	text_end
; PRET| 
; PRET| .TM31Explanation2Text:
; PRET| 	text_far _CopycatsHouse2FCopycatTM31Explanation2Text
; PRET| 	text_end
; PRET| 
; PRET| .TM31NoRoomText:
; PRET| 	text_far _CopycatsHouse2FCopycatTM31NoRoomText
; PRET| 	text_waitbutton
; PRET| 	text_end
; PRET| 
; PRET| CopycatsHouse2FDoduoText:
; PRET| 	text_far _CopycatsHouse2FDoduoText
; PRET| 	text_end
; PRET| 
; PRET| CopycatsHouse2FRareDollText:
; PRET| 	text_far _CopycatsHouse2FRareDollText
; PRET| 	text_end
; PRET| 
; PRET| CopycatsHouse2FSNESText:
; PRET| 	text_far _CopycatsHouse2FSNESText
; PRET| 	text_end

%assign event_byte -1
CopycatsHouse2FPCText:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    mov esi, .CantSeeText
    jnz .notUp
    mov esi, .MySecretsText
.notUp:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
.MySecretsText:
    text_far _CopycatsHouse2FPCMySecretsText
    text_end
.CantSeeText:
    text_far _CopycatsHouse2FPCCantSeeText
    text_end
