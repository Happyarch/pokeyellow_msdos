; Route15Gate2F.asm — translated from pret scripts/Route15Gate2F.asm by dos_port/tools/sm83xlat.
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


global Route15Gate2FBinocularsText
global Route15Gate2FOaksAideText
global Route15Gate2F_Script
global Route15Gate2F_TextPointers

extern CopyData   ; NOT YET DEFINED IN THE PORT
extern DisableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GateUpstairsScript_PrintIfFacingUp   ; NOT YET DEFINED IN THE PORT
extern GetItemName   ; NOT YET DEFINED IN THE PORT
extern OaksAideScript   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _Route15Gate2FBinocularsText   ; NOT YET DEFINED IN THE PORT
extern _Route15Gate2FOaksAideExpAllText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hOaksAideRequirement                           equ 0xFFDB
hOaksAideResult                                equ 0xFFDB
hOaksAideRewardItem                            equ 0xFFDC
wOaksAideRewardItemName                        equ 0xCC5B

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route15Gate2F_Script:
    jmp DisableAutoTextBoxDrawing

Route15Gate2F_TextPointers:
    dd Route15Gate2FOaksAideText
    dd Route15Gate2FBinocularsText

Route15Gate2FOaksAideText:
    CheckEvent EVENT_GOT_EXP_ALL
    jnz .got_item
    mov al, 50
    mov [ebp + hOaksAideRequirement], al
    mov al, EXP_ALL
    mov [ebp + hOaksAideRewardItem], al
    mov [ebp + wNamedObjectIndex], al
    call GetItemName
    mov esi, wNameBuffer
    mov dx, wOaksAideRewardItemName
    mov bx, 13
    call CopyData
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call OaksAideScript
    mov al, [ebp + hOaksAideResult]
    cmp al, 1
    jnz .no_item
    SetEvent EVENT_GOT_EXP_ALL
.got_item:
    mov esi, .ExpAllText
    call PrintText
.no_item:
    jmp TextScriptEnd

.ExpAllText:
    text_far _Route15Gate2FOaksAideExpAllText
    text_end

Route15Gate2FBinocularsText:
    mov esi, .Text
    jmp GateUpstairsScript_PrintIfFacingUp

.Text:
    text_far _Route15Gate2FBinocularsText
    text_end
