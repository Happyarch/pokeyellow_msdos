; Route1.asm — translated from pret scripts/Route1.asm, scripts/Route1_2.asm by dos_port/tools/sm83xlat.
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


global Route1PrintSignText
global Route1PrintYoungster2Text
global Route1SignText
global Route1Youngster1Text
global Route1Youngster2Text
global Route1_Script
global Route1_TextPointers

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern Route1PrintYoungster1Text   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _Route1SignText   ; NOT YET DEFINED IN THE PORT
extern _Route1Youngster1GotPotionText   ; NOT YET DEFINED IN THE PORT
extern _Route1Youngster1MartSampleText   ; NOT YET DEFINED IN THE PORT
extern _Route1Youngster2Text   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
Route1_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
Route1_TextPointers:
    dd Route1Youngster1Text
    dd Route1Youngster2Text
    dd Route1SignText

%assign event_byte -1
Route1Youngster1Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Route1PrintYoungster1Text
    jmp TextScriptEnd

%assign event_byte -1
Route1Youngster2Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Route1PrintYoungster2Text
    jmp TextScriptEnd

%assign event_byte -1
Route1SignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Route1PrintSignText
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route1PrintYoungster1Text (scripts/Route1_2.asm:2-10) — at scripts/Route1_2.asm:3: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckAndSetEvent EVENT_GOT_POTION_SAMPLE
; PRET| 	jr nz, .got_item
; PRET| 	ld hl, .MartSampleText
; PRET| 	call PrintText
; PRET| 	lb bc, POTION, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, .GotPotionText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route1PrintYoungster1Text.bag_full (scripts/Route1_2.asm:12-13) — at scripts/Route1_2.asm:12: .NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .NoRoomText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route1PrintYoungster1Text.got_item (scripts/Route1_2.asm:15-18) — at scripts/Route1_2.asm:15: .AlsoGotPokeballsText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .AlsoGotPokeballsText
; PRET| .done
; PRET| 	call PrintText
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] Route1PrintYoungster1Text.MartSampleText (scripts/Route1_2.asm:21-35) — at scripts/Route1_2.asm:26: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route1Youngster1MartSampleText
; PRET| 	text_end
; PRET| 
; PRET| .GotPotionText:
; PRET| 	text_far _Route1Youngster1GotPotionText
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .AlsoGotPokeballsText:
; PRET| 	text_far _Route1Youngster1AlsoGotPokeballsText
; PRET| 	text_end
; PRET| 
; PRET| .NoRoomText:
; PRET| 	text_far _Route1Youngster1NoRoomText
; PRET| 	text_end

%assign event_byte -1
Route1PrintYoungster2Text:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
.text:
    text_far _Route1Youngster2Text
    text_end

%assign event_byte -1
Route1PrintSignText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
.text:
    text_far _Route1SignText
    text_end
