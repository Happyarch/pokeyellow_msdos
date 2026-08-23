; clear_save.asm — the title screen's CLEAR ALL SAVE DATA dialog.
;
; Mirror of pret engine/movie/oak_speech/clear_save.asm. Reached from
; DisplayTitleScreen's UP+SELECT+B reset-save combo (engine/movie/title.asm
; .doClearSaveDialogue — pret farjp, so there is no return address).
;
; THE BODY IS REAL AS OF 2026-08-23. It used to be `jmp Init` under a temporary
; deviation whose evidence read "save/SRAM is Phase 5 and there is
; no save file to clear yet, so the dialog would erase nothing". That blocker is
; gone and has been for a while: the port emulates all four SRAM banks resident,
; persists them to POKEMON.DSV, and `ClearAllSRAMBanks` is translated and linked
; (src/engine/menus/save.asm). So UP+SELECT+B now asks, and on YES actually erases.
;
; Build: nasm -f coff -I include/ -I . -o clear_save.o clear_save.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"

extern Init                          ; home/init.asm
extern ClearScreen                   ; home/copy2.asm
extern RunDefaultPaletteCommand      ; home/palettes.asm
extern LoadFontTilePatterns          ; home/load_font.asm
extern LoadTextBoxTilePatterns       ; home/load_font.asm
extern PrintText                     ; home/window.asm — In: ESI = text stream
extern DisplayTextBoxID              ; home/textbox.asm — [wTextBoxID] box
extern ClearAllSRAMBanks             ; engine/menus/save.asm
extern text_msgbox                   ; home/text.asm — active msgbox projection
extern msgbox_dialog                 ; home/text.asm — the standard bottom dialog box
extern yn_box_col                    ; home/yes_no.asm — two-option box top-left, GB X
extern yn_box_row                    ; home/yes_no.asm — two-option box top-left, GB Y
extern yn_proj_mode                  ; home/yes_no.asm — projection selector

section .data
align 4
; Tier-1 DATA: the prompt stream (gen_overworld_strings.py, data/text/text_3.asm).
%include "assets/clear_save_text.inc"

section .text

; ---------------------------------------------------------------------------
; DoClearSaveDialogue — pret engine/movie/oak_speech/clear_save.asm:1.
; "CLEAR ALL SAVE DATA?" with a NO/YES box; YES wipes every SRAM bank. Either way
; it falls into Init, so this never returns.
; ---------------------------------------------------------------------------
global DoClearSaveDialogue
DoClearSaveDialogue:
    call ClearScreen
    call RunDefaultPaletteCommand
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    mov dword [text_msgbox], msgbox_dialog   ; PORT: publish the box projection
    mov esi, ClearSaveDataText               ; ld hl, ClearSaveDataText
    call PrintText
%ifdef DEBUG_SOFT_RESET
    ; HARNESS ONLY. The soft_reset gate reaches here by SYNTHESIZING the UP+SELECT+B
    ; combo straight into hJoyHeld (engine/movie/title.asm) rather than running
    ; AutoKeyDrive, so it has no way to answer the two-option box below and would sit
    ; in its input loop until the 150 s timeout killed the run — which is exactly what
    ; happened the first time this routine got a real body.
    ; The golden's Lua taps A through the same box (tools/mgba_harness/scenarios/
    ; soft_reset.lua), and BOTH choices jump to Init, so the compared state — the
    ; replayed copyright screen after Init — is identical either way. This takes
    ; pret's NO branch directly.
    ; CONSEQUENCE, stated rather than hidden: soft_reset does NOT witness this dialog.
    ; A scenario that does needs a harness that can press A.
    jmp Init
%endif
    mov byte [ebp + wJoyIgnore], PAD_B       ; ld a, PAD_B / ld [wJoyIgnore], a
    ; pret: hlcoord 14, 7 / lb bc, 8, 15.
    ; DEVIATION{class=projection; pret=engine/movie/oak_speech/clear_save.asm:DoClearSaveDialogue; behavior=pass the two-option box geometry through the yn_box state instead of pret's HL plus BC triple; evidence=the port's DisplayTwoOptionMenu draws the box as a compositor window and takes its top-left from yn_box_col and yn_box_row in GB coordinates rather than from HL, deriving the cursor from the box instead of from B and C - the same contract engine/menus/save.asm SaveTheGame_YesOrNo already goes through; lifetime=until DisplayTwoOptionMenu accepts explicit geometry}
    mov dword [yn_box_col], 14
    mov dword [yn_box_row], 7
    mov dword [yn_proj_mode], 0
    mov byte [ebp + wTwoOptionMenuID], NO_YES_MENU
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    call DisplayTextBoxID
    mov byte [ebp + wJoyIgnore], 0           ; ld a, 0 / ld [wJoyIgnore], a
    mov al, [ebp + wCurrentMenuItem]
    and al, al
    jz  Init                                 ; jp z, Init — item 0 is NO here
    call ClearAllSRAMBanks                   ; farcall
    jmp Init                                 ; jp Init

; --- The prompt's Tier-2 wrapper over the Tier-1 stream above. ---
global ClearSaveDataText
ClearSaveDataText:
    text_far _ClearSaveDataText
    text_end
