; Route11Gate2F.asm — translated from pret scripts/Route11Gate2F.asm by dos_port/tools/sm83xlat.
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
%include "assets/script_constants.inc"


global Route11Gate2FLeftBinocularsText
global Route11Gate2FOaksAideText
global Route11Gate2FRightBinocularsText
global Route11Gate2FScriptEnd
global Route11Gate2FYoungsterText
global Route11Gate2F_Script
global Route11Gate2F_TextPointers

extern CopyData
extern DisableAutoTextBoxDrawing
extern DoInGameTradeDialogue   ; NOT YET DEFINED IN THE PORT
extern GateUpstairsScript_PrintIfFacingUp
extern GetItemName
extern OaksAideScript   ; NOT YET DEFINED IN THE PORT
extern PrintText
extern TextScriptEnd
extern _Route11Gate2FLeftBinocularsNoSnorlaxText   ; NOT YET DEFINED IN THE PORT
extern _Route11Gate2FLeftBinocularsSnorlaxText   ; NOT YET DEFINED IN THE PORT
extern _Route11Gate2FOaksAideItemfinderDescriptionText   ; NOT YET DEFINED IN THE PORT
extern _Route11Gate2FRightBinocularsText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hOaksAideRequirement                           equ 0xFFDB
hOaksAideResult                                equ 0xFFDB
hOaksAideRewardItem                            equ 0xFFDC
wOaksAideRewardItemName                        equ 0xCC5B
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route11Gate2F_Script:
    jmp DisableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
Route11Gate2F_TextPointers:
    dd Route11Gate2FYoungsterText
    dd Route11Gate2FOaksAideText
    dd Route11Gate2FLeftBinocularsText
    dd Route11Gate2FRightBinocularsText

%assign event_byte -1
%assign event_byte_a -1
Route11Gate2FYoungsterText:
    mov al, TRADE_FOR_GURIO
    mov [ebp + wWhichTrade], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call DoInGameTradeDialogue
Route11Gate2FScriptEnd:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route11Gate2FOaksAideText:
    CheckEvent EVENT_GOT_ITEMFINDER, 1   ; pret's 2-arg CARRY form (scripts/Route11Gate2F.asm:21)
    jb .got_item                         ; pret: jr c, .got_item
    mov al, 30
    mov [ebp + hOaksAideRequirement], al
    mov al, ITEMFINDER
    mov [ebp + hOaksAideRewardItem], al
    mov [ebp + wNamedObjectIndex], al
    call GetItemName
    mov esi, wNameBuffer
    mov dx, wOaksAideRewardItemName
    mov bx, 13
    call CopyData
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call OaksAideScript
    mov al, [ebp + hOaksAideResult]
    dec al   ; OAKS_AIDE_GOT_ITEM?
    jnz .no_item
    SetEvent EVENT_GOT_ITEMFINDER
.got_item:
    mov esi, .ItemfinderDescriptionText
    call PrintText
.no_item:
    jmp Route11Gate2FScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.ItemfinderDescriptionText:
    text_far _Route11Gate2FOaksAideItemfinderDescriptionText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Route11Gate2FLeftBinocularsText:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jnz GateUpstairsScript_PrintIfFacingUp
    CheckEvent EVENT_BEAT_ROUTE12_SNORLAX
    mov esi, .SnorlaxText
    jz .print
    mov esi, .NoSnorlaxText
.print:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.SnorlaxText:
    text_far _Route11Gate2FLeftBinocularsSnorlaxText
    text_end
.NoSnorlaxText:
    text_far _Route11Gate2FLeftBinocularsNoSnorlaxText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Route11Gate2FRightBinocularsText:
    mov esi, .Text
    jmp GateUpstairsScript_PrintIfFacingUp

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _Route11Gate2FRightBinocularsText
    text_end
