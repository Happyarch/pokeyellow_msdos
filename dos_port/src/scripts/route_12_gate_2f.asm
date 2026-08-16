; Route12Gate2F.asm — translated from pret scripts/Route12Gate2F.asm by dos_port/tools/sm83xlat.
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


global Route12Gate2FLeftBinocularsText
global Route12Gate2FRightBinocularsText
global Route12Gate2F_Script
global Route12Gate2F_TextPointers

extern DisableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GateUpstairsScript_PrintIfFacingUp   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern Route12Gate2FBrunetteGirlText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _Route12Gate2FBrunetteGirlReceivedTM39Text   ; NOT YET DEFINED IN THE PORT
extern _Route12Gate2FBrunetteGirlYouCanHaveThisText   ; NOT YET DEFINED IN THE PORT
extern _Route12Gate2FLeftBinocularsText   ; NOT YET DEFINED IN THE PORT
extern _Route12Gate2FRightBinocularsText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route12Gate2F_Script:
    jmp DisableAutoTextBoxDrawing

Route12Gate2F_TextPointers:
    dd Route12Gate2FBrunetteGirlText
    dd Route12Gate2FLeftBinocularsText
    dd Route12Gate2FRightBinocularsText

; ---------------------------------------------------------------------------
; BAIL[checkevent-carry-form] Route12Gate2FBrunetteGirlText (scripts/Route12Gate2F.asm:12-22) — at scripts/Route12Gate2F.asm:12: CheckEvent EVENT_GOT_TM39, 1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_TM39, 1
; PRET| 	jr c, .got_item
; PRET| 	ld hl, .YouCanHaveThisText
; PRET| 	call PrintText
; PRET| 	lb bc, TM_SWIFT, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, .ReceivedTM39Text
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_TM39
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route12Gate2FBrunetteGirlText.bag_full (scripts/Route12Gate2F.asm:24-26) — at scripts/Route12Gate2F.asm:24: .TM39NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM39NoRoomText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route12Gate2FBrunetteGirlText.got_item (scripts/Route12Gate2F.asm:28-31) — at scripts/Route12Gate2F.asm:28: .TM39ExplanationText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM39ExplanationText
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] Route12Gate2FBrunetteGirlText.YouCanHaveThisText (scripts/Route12Gate2F.asm:34-48) — at scripts/Route12Gate2F.asm:39: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route12Gate2FBrunetteGirlYouCanHaveThisText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedTM39Text:
; PRET| 	text_far _Route12Gate2FBrunetteGirlReceivedTM39Text
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .TM39ExplanationText:
; PRET| 	text_far _Route12Gate2FBrunetteGirlTM39ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| .TM39NoRoomText:
; PRET| 	text_far _Route12Gate2FBrunetteGirlTM39NoRoomText
; PRET| 	text_end

Route12Gate2FLeftBinocularsText:
    mov esi, .Text
    jmp GateUpstairsScript_PrintIfFacingUp

.Text:
    text_far _Route12Gate2FLeftBinocularsText
    text_end

Route12Gate2FRightBinocularsText:
    mov esi, .Text
    jmp GateUpstairsScript_PrintIfFacingUp

.Text:
    text_far _Route12Gate2FRightBinocularsText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GateUpstairsScript_PrintIfFacingUp (scripts/Route12Gate2F.asm:69-73) — at scripts/Route12Gate2F.asm:73: .done is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wSpritePlayerStateData1FacingDirection]
; PRET| 	cp SPRITE_FACING_UP
; PRET| 	jr z, .up
; PRET| 	ld a, TRUE
; PRET| 	jr .done

.up:
    call PrintText
    xor al, al
.done:
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    jmp TextScriptEnd
