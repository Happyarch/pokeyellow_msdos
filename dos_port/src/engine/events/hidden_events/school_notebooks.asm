; school_notebooks.asm — Viridian school notebooks and page-turn handling.
;
; Faithful translation of pret `engine/events/hidden_events/school_notebooks.asm`.
;
; Functions ported here:
;   * PrintNotebookText — enables auto text-box drawing, sets
;     wDoNotWaitForButtonPressAfterDisplayingText, loads wHiddenEventFunctionArgument,
;     and tail-jumps into PrintPredefTextID.
;   * ViridianSchoolNotebook — 5-page text_asm interactive notebook reader that
;     prompts with TurnPageSchoolNotebook after pages 1-3, prints pages 4 and 5,
;     and finishes with TextScriptEnd.
;   * TurnPageSchoolNotebook — prints TurnPageText ("Turn the page?"), asks
;     YesNoChoice, and returns ZF=1 on Yes (wCurrentMenuItem == 0), ZF=0 on No.
;
; Text streams (Tier-1 data):
;   * TurnPageText, ViridianSchoolNotebookText1..5 are generated into
;     assets/school_notebooks_text.inc (tools/generators/gen_school_notebooks_text.py)
;     and included at the bottom of this file.
;   * TMNotebook is generated in assets/predef_text.inc (predef text id TMNotebook_id).
;
; Register map (CLAUDE.md):
;   A -> AL, HL -> ESI; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -o school_notebooks.o \
;            src/engine/events/hidden_events/school_notebooks.asm

bits 32

%include "gb_memmap.inc"

section .text

global PrintNotebookText
global ViridianSchoolNotebook
global TurnPageSchoolNotebook

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm
extern PrintText                        ; src/home/window.asm
extern TextScriptEnd                    ; src/home/overworld_text.asm
extern YesNoChoice                      ; src/home/yes_no.asm

; ─────────────────────────────────────────────────────────────────────────────
; PrintNotebookText — pret engine/events/hidden_events/school_notebooks.asm:PrintNotebookText.
; Hidden-event handler for school notebooks. Sets up text box flags and jumps
; to PrintPredefTextID with the predef ID passed in wHiddenEventFunctionArgument.
; ─────────────────────────────────────────────────────────────────────────────
PrintNotebookText:
    call EnableAutoTextBoxDrawing
    mov byte [ebp + wDoNotWaitForButtonPressAfterDisplayingText], 1
    mov al, [ebp + wHiddenEventFunctionArgument]
    jmp PrintPredefTextID

; ─────────────────────────────────────────────────────────────────────────────
; ViridianSchoolNotebook — pret engine/events/hidden_events/school_notebooks.asm:ViridianSchoolNotebook.
; Paged reader for Viridian School's notebook.
; ─────────────────────────────────────────────────────────────────────────────
ViridianSchoolNotebook:
    mov esi, ViridianSchoolNotebookText1
    call PrintText
    call TurnPageSchoolNotebook
    jnz .doneReading
    mov esi, ViridianSchoolNotebookText2
    call PrintText
    call TurnPageSchoolNotebook
    jnz .doneReading
    mov esi, ViridianSchoolNotebookText3
    call PrintText
    call TurnPageSchoolNotebook
    jnz .doneReading
    mov esi, ViridianSchoolNotebookText4
    call PrintText
    mov esi, ViridianSchoolNotebookText5
    call PrintText
.doneReading:
    jmp TextScriptEnd

; ─────────────────────────────────────────────────────────────────────────────
; TurnPageSchoolNotebook — pret engine/events/hidden_events/school_notebooks.asm:TurnPageSchoolNotebook.
; Prompts player if they want to turn the page.
; Returns ZF=1 if Yes (wCurrentMenuItem == 0), ZF=0 if No.
; ─────────────────────────────────────────────────────────────────────────────
TurnPageSchoolNotebook:
    mov esi, TurnPageText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    and al, al
    ret

; ─────────────────────────────────────────────────────────────────────────────
; assets/school_notebooks_text.inc — Tier-1 generated text streams
; (gen_school_notebooks_text.py):
; TurnPageText, ViridianSchoolNotebookText1..5 flattened into inline TX_FAR model.
; Emits its own section .data.
; ─────────────────────────────────────────────────────────────────────────────
%include "assets/school_notebooks_text.inc"
