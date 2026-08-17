; Museum2F.asm — translated from pret scripts/Museum2F.asm by dos_port/tools/sm83xlat.
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


global Museum2FBrunetteGirlText
global Museum2FGrampsText
global Museum2FHikerText
global Museum2FMoonStoneSignText
global Museum2FScientistText
global Museum2FSpaceShuttleSignText
global Museum2FText_5c20e
global Museum2FText_5c213
global Museum2FText_5c218
global Museum2FYoungsterText
global Museum2F_Script
global Museum2F_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _Museum2FBrunetteGirlText   ; NOT YET DEFINED IN THE PORT
extern _Museum2FGrampsText   ; NOT YET DEFINED IN THE PORT
extern _Museum2FHikerText   ; NOT YET DEFINED IN THE PORT
extern _Museum2FMoonStoneSignText   ; NOT YET DEFINED IN THE PORT
extern _Museum2FPikachuText1   ; NOT YET DEFINED IN THE PORT
extern _Museum2FPikachuText2   ; NOT YET DEFINED IN THE PORT
extern _Museum2FScientistText   ; NOT YET DEFINED IN THE PORT
extern _Museum2FSpaceShuttleSignText   ; NOT YET DEFINED IN THE PORT
extern _Museum2FYoungsterText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPikachuSpawnStateFlags                        equ 0xD471

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
Museum2F_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
Museum2F_TextPointers:
    dd Museum2FYoungsterText
    dd Museum2FGrampsText
    dd Museum2FScientistText
    dd Museum2FBrunetteGirlText
    dd Museum2FHikerText
    dd Museum2FSpaceShuttleSignText
    dd Museum2FMoonStoneSignText
Museum2FYoungsterText:
    text_far _Museum2FYoungsterText
    text_end
Museum2FGrampsText:
    text_far _Museum2FGrampsText
    text_end
Museum2FScientistText:
    text_far _Museum2FScientistText
    text_end
Museum2FBrunetteGirlText:
    text_far _Museum2FBrunetteGirlText
    text_end

%assign event_byte -1
Museum2FHikerText:
    mov al, [ebp + wPikachuSpawnStateFlags]
    test al, (1 << (7))
    jnz .asm_5c1f6
    mov esi, Museum2FText_5c20e
    call PrintText
    jmp .asm_5c20b

%assign event_byte -1
.asm_5c1f6:
    mov al, [ebp + wPikachuHappiness]
    cmp al, 101
    jb .asm_5c205
    mov esi, Museum2FText_5c218
    call PrintText
    jmp .asm_5c20b

%assign event_byte -1
.asm_5c205:
    mov esi, Museum2FText_5c213
    call PrintText
.asm_5c20b:
    jmp TextScriptEnd

%assign event_byte -1
Museum2FText_5c20e:
    text_far _Museum2FHikerText
    text_end
Museum2FText_5c213:
    text_far _Museum2FPikachuText1
    text_end
Museum2FText_5c218:
    text_far _Museum2FPikachuText2
    text_end
Museum2FSpaceShuttleSignText:
    text_far _Museum2FSpaceShuttleSignText
    text_end
Museum2FMoonStoneSignText:
    text_far _Museum2FMoonStoneSignText
    text_end
