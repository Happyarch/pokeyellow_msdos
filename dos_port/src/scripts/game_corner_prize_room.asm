; GameCornerPrizeRoom.asm — translated from pret scripts/GameCornerPrizeRoom.asm by dos_port/tools/sm83xlat.
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


global GameCornerPrizeRoom_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GameCornerPRizeRoomPrizeVendorText   ; NOT YET DEFINED IN THE PORT
extern GameCornerPrizeRoomBaldingGuyText   ; NOT YET DEFINED IN THE PORT
extern GameCornerPrizeRoomGamblerText   ; NOT YET DEFINED IN THE PORT
extern GameCornerPrizeRoom_TextPointers   ; NOT YET DEFINED IN THE PORT
extern _GameCornerPrizeRoomBaldingGuyText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerPrizeRoomGamblerText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
TEXT_GAMECORNERPRIZEROOM_BALDING_GUY           equ 1
TEXT_GAMECORNERPRIZEROOM_GAMBLER               equ 2
TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_1        equ 3
TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_2        equ 4
TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_3        equ 5

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

GameCornerPrizeRoom_Script:
    jmp EnableAutoTextBoxDrawing

; ---------------------------------------------------------------------------
; BAIL[text-script-command-unported] GameCornerPrizeRoom_TextPointers (scripts/GameCornerPrizeRoom.asm:5-22) — at scripts/GameCornerPrizeRoom.asm:22: script_prize_vendor
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const GameCornerPrizeRoomBaldingGuyText,  TEXT_GAMECORNERPRIZEROOM_BALDING_GUY
; PRET| 	dw_const GameCornerPrizeRoomGamblerText,     TEXT_GAMECORNERPRIZEROOM_GAMBLER
; PRET| 	dw_const GameCornerPRizeRoomPrizeVendorText, TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_1
; PRET| 	dw_const GameCornerPRizeRoomPrizeVendorText, TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_2
; PRET| 	dw_const GameCornerPRizeRoomPrizeVendorText, TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_3
; PRET| 	EXPORT TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_1 ; used by engine/events/prize_menu.asm
; PRET| 
; PRET| GameCornerPrizeRoomBaldingGuyText:
; PRET| 	text_far _GameCornerPrizeRoomBaldingGuyText
; PRET| 	text_end
; PRET| 
; PRET| GameCornerPrizeRoomGamblerText:
; PRET| 	text_far _GameCornerPrizeRoomGamblerText
; PRET| 	text_end
; PRET| 
; PRET| GameCornerPRizeRoomPrizeVendorText:
; PRET| 	script_prize_vendor
