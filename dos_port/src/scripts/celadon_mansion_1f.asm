; CeladonMansion1F.asm — translated from pret scripts/CeladonMansion1F.asm, scripts/CeladonMansion1F_2.asm by dos_port/tools/sm83xlat.
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

%include "assets/pika_pcm.inc"

global CeladonMansion1FClefairyText
global CeladonMansion1FManagersSuiteSignText
global CeladonMansion1FMeowthText
global CeladonMansion1FNidoranFText
global CeladonMansion1FPrintGrannyText
global CeladonMansion1F_Script
global CeladonMansion1F_TextPointers
global CeladonMansion1Text_f1e96
global CeladonMansion1Text_f1ed5
global CeladonMansion1Text_f1eda
global CeladonMansion1Text_f1edf
global CeladonMansion1Text_f1ee4
global CeladonMansion1Text_f1ee9
global CeladonMansion1Text_f1eee
global CeladonMansionText_f1e9c
global PikachuHappinessThresholds_f1eb9

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CeladonMansion1FGrannyText   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern Func_f1ea2   ; NOT YET DEFINED IN THE PORT
extern IsStarterPikachuAliveInOurParty   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern PlayPikachuSoundClip   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion1FClefairyText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion1FManagersSuiteSignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion1FMeowthText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion1FNidoranFText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion1Text10   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion1Text11   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion1Text12   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion1Text2   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion1Text6   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion1Text7   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion1Text8   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion1Text9   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion1F_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion1F_TextPointers:
    dd CeladonMansion1FMeowthText
    dd CeladonMansion1FGrannyText
    dd CeladonMansion1FClefairyText
    dd CeladonMansion1FNidoranFText
    dd CeladonMansion1FManagersSuiteSignText
CeladonMansion1FMeowthText:
    text_far _CeladonMansion1FMeowthText

%assign event_byte -1
%assign event_byte_a -1
    mov al, 77
    call PlayCry
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonMansion1FGrannyText (scripts/CeladonMansion1F.asm:22-31) — at scripts/CeladonMansion1F.asm:25: .asm_485d9 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	farcall CeladonMansion1FPrintGrannyText
; PRET| 	ld a, [wPikachuHappiness]
; PRET| 	cp 251
; PRET| 	jr c, .asm_485d9
; PRET| 	ld c, 50
; PRET| 	call DelayFrames
; PRET| 	ldpikacry e, PikachuCry23
; PRET| 	callfar PlayPikachuSoundClip
; PRET| .asm_485d9
; PRET| 	jp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion1FClefairyText:
    text_far _CeladonMansion1FClefairyText

%assign event_byte -1
%assign event_byte_a -1
    mov al, 4
    call PlayCry
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion1FNidoranFText:
    text_far _CeladonMansion1FNidoranFText

%assign event_byte -1
%assign event_byte_a -1
    mov al, 15
    call PlayCry
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion1FManagersSuiteSignText:
    text_far _CeladonMansion1FManagersSuiteSignText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion1FPrintGrannyText:
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, CeladonMansion1Text_f1e96
    call PrintText
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call IsStarterPikachuAliveInOurParty
    jb .nr_7
        ret
.nr_7:
    mov esi, CeladonMansionText_f1e9c
    call PrintText
    mov al, 0x0
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    call Func_f1ea2
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion1Text_f1e96:
    text_far _CeladonMansion1Text2
    text_waitbutton
    text_end
CeladonMansionText_f1e9c:
    text_far _CeladonMansion1Text6
    text_promptbutton
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Func_f1ea2 (scripts/CeladonMansion1F_2.asm:27-39) — at scripts/CeladonMansion1F_2.asm:32: .asm_f1eb5 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, PikachuHappinessThresholds_f1eb9
; PRET| .asm_f1ea5
; PRET| 	ld a, [hli]
; PRET| 	inc hl
; PRET| 	and a
; PRET| 	jr z, .asm_f1eb5
; PRET| 	ld b, a
; PRET| 	ld a, [wPikachuHappiness]
; PRET| 	cp b
; PRET| 	jr c, .asm_f1eb5
; PRET| 	inc hl
; PRET| 	inc hl
; PRET| 	jr .asm_f1ea5

; ---------------------------------------------------------------------------
; BAIL[hl-half-register-access] Func_f1ea2.asm_f1eb5 (scripts/CeladonMansion1F_2.asm:42-45) — at scripts/CeladonMansion1F_2.asm:43: `h` is a half of ESI and has no flag-safe 8-bit x86 form
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [hli]
; PRET| 	ld h, [hl]
; PRET| 	ld l, a
; PRET| 	ret

%assign event_byte -1
%assign event_byte_a -1
PikachuHappinessThresholds_f1eb9:
    dd 51, CeladonMansion1Text_f1ed5
    dd 101, CeladonMansion1Text_f1eda
    dd 131, CeladonMansion1Text_f1edf
    dd 161, CeladonMansion1Text_f1ee4
    dd 201, CeladonMansion1Text_f1ee9
    dd 255, CeladonMansion1Text_f1eee
    dd -256, CeladonMansion1Text_f1eee
CeladonMansion1Text_f1ed5:
    text_far _CeladonMansion1Text7
    text_end
CeladonMansion1Text_f1eda:
    text_far _CeladonMansion1Text8
    text_end
CeladonMansion1Text_f1edf:
    text_far _CeladonMansion1Text9
    text_end
CeladonMansion1Text_f1ee4:
    text_far _CeladonMansion1Text10
    text_end
CeladonMansion1Text_f1ee9:
    text_far _CeladonMansion1Text11
    text_end
CeladonMansion1Text_f1eee:
    text_far _CeladonMansion1Text12
    text_end
