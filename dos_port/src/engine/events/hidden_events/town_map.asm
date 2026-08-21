; town_map.asm — Wall Town Map hidden-event handler.
;
; Faithful translation of pret `engine/events/hidden_events/town_map.asm`.
;
; Register map: A=AL, HL=ESI; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null \
;            src/engine/events/hidden_events/town_map.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "assets/town_map_text.inc"

global TownMapText

extern PrintText_NoCreatingTextBox      ; src/home/window.asm
extern text_msgbox                      ; src/home/text.asm
extern msgbox_dialog                    ; src/home/text.asm
extern GBPalWhiteOutWithDelay3          ; src/home/palettes.asm
extern LoadFontTilePatterns             ; src/home/load_font.asm
extern DisplayTownMap                   ; src/engine/items/town_map.asm
extern CloseTextDisplay                 ; src/home/text_script.asm
extern TextScriptEnd                    ; src/home/overworld_text.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; TownMapText — pret engine/events/hidden_events/town_map.asm:TownMapText
; ─────────────────────────────────────────────────────────────────────────────
; DEVIATION{class=projection; pret=engine/events/hidden_events/town_map.asm:TownMapText; behavior=the pret label is a code trampoline that prints an embedded verbatim copy of pret's stream instead of naming the stream itself; evidence=the port's TextPredefs row for TownMapText carries the TEXT_ASM_ENTRY sentinel and DisplayTextID calls the pointer rather than streaming it, src/home/text_script.asm:210-214, so a label naming db bytes would be executed as instructions; lifetime=permanent unless the port's predef table grows a stream-with-asm row kind}
TownMapText:
    mov dword [text_msgbox], msgbox_dialog   ; overworld dialog projection
    mov esi, .stream
    call PrintText_NoCreatingTextBox
    ret

.stream:
    text_far _TownMapText
    text_promptbutton
    text_asm
.hook:
    mov byte [ebp + wDoNotWaitForButtonPressAfterDisplayingText], 1
    or byte [ebp + wStatusFlags5], (1 << BIT_NO_TEXT_DELAY)
    call GBPalWhiteOutWithDelay3
    xor al, al
    mov [ebp + hWY], al
    inc al
    mov [ebp + hAutoBGTransferEnabled], al
    call LoadFontTilePatterns
    call DisplayTownMap
    and byte [ebp + wStatusFlags5], ~(1 << BIT_NO_TEXT_DELAY) & 0xFF
    push dword TextScriptEnd
    movzx eax, byte [ebp + hLoadedROMBank]
    push eax
    jmp CloseTextDisplay
