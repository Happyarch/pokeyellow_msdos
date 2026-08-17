; SilphCo1F.asm — translated from pret scripts/SilphCo1F.asm by dos_port/tools/sm83xlat.
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


global SilphCo1FLinkReceptionistText
global SilphCo1F_Script
global SilphCo1F_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern _SilphCo1FLinkReceptionistText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
SilphCo1F_Script:
    call EnableAutoTextBoxDrawing
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    jnz .nr_4
        ret
.nr_4:
    CheckAndSetEvent EVENT_SILPH_CO_RECEPTIONIST_AT_DESK
    jz .nr_6
        ret
.nr_6:
    mov al, 76
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    jmp ShowObject

%assign event_byte -1
SilphCo1F_TextPointers:
    dd SilphCo1FLinkReceptionistText
SilphCo1FLinkReceptionistText:
    text_far _SilphCo1FLinkReceptionistText
    text_end
