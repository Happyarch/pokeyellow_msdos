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
global CeladonMansion1FGrannyText
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
global Func_f1ea2
global PikachuHappinessThresholds_f1eb9

extern Bankswitch
extern DelayFrames
extern EnableAutoTextBoxDrawing
extern IsStarterPikachuAliveInOurParty
extern PlayCry
extern PlayPikachuSoundClip
extern PrintText
extern TextScriptEnd
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

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion1FGrannyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CeladonMansion1FPrintGrannyText
    mov al, [ebp + wPikachuHappiness]
    cmp al, 251
    jb .asm_485d9
    mov bl, 50   ; pret: ld c, 50
    call DelayFrames
    mov dl, 22   ; pret: ldpikacry e, PikachuCry23 (0-based clip index)
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call PlayPikachuSoundClip
.asm_485d9:
    jmp TextScriptEnd

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

%assign event_byte -1
%assign event_byte_a -1
Func_f1ea2:
    mov esi, PikachuHappinessThresholds_f1eb9
.asm_f1ea5:
    mov eax, [esi]
    add esi, 4   ; pret: ld a, [hli] / inc hl — advance ESI to point to text pointer (+4)
    test al, al  ; pret: and a — check for terminator sentinel (-256 has low byte 0)
    jz .asm_f1eb5
    mov bh, al   ; pret: ld b, a — threshold value (B = BH)
    mov al, [ebp + wPikachuHappiness]
    cmp al, bh   ; pret: cp b
    jb .asm_f1eb5
    add esi, 4   ; pret: inc hl / inc hl — advance past 4-byte text pointer to next entry
    jmp .asm_f1ea5

.asm_f1eb5:
    mov esi, [esi]   ; pret: ld a, [hli] / ld h, [hl] / ld l, a (dw->dd stride: dereference 32-bit pointer)
    ret

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
