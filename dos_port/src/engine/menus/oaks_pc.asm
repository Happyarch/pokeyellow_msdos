; ===========================================================================
; oaks_pc.asm — OPEN OAK's PC (menus-port Session 6, package A).
; Faithful port of pret engine/menus/oaks_pc.asm:OpenOaksPC.
;
; pret flow: SaveScreenTilesToBuffer2 / PrintText AccessedOaksPCText /
; PrintText GetDexRatedText / YesNoChoice / if NO skip / predef DisplayDexRating
; / PrintText ClosedOaksPCText / LoadScreenTilesFromBuffer2.
;
; Port model (window compositor, see docs/translation_log.md "menus-port S2-S5"):
; - DEVIATION(text): the three PrintText dialogs (AccessedOaksPCText,
;   GetDexRatedText, ClosedOaksPCText) are drawn WHOLE into the stride-20
;   W_TILEMAP scratch rows 12-17, mirrored to GB_TILEMAP1, and shown through the
;   UI_MESSAGE_BOX window — the established S4/S5 dialog DEVIATION (PrintText_
;   Overworld would collapse the window list, and the far-text streams aren't
;   GB-space assets yet). pret wording is reproduced exactly (data/text/text_3.asm
;   _AccessedOaksPCText/_GetDexRatedText/_ClosedOaksPCText). The texts' terminal
;   `prompt`/`text_waitbutton` become the ▼ + A/B wait (oak_prompt); the `para`
;   page break in AccessedOaksPCText becomes an extra prompt between the two pages.
; - DEVIATION: SaveScreenTilesToBuffer2 / LoadScreenTilesFromBuffer2 (the GB
;   screen-stash idiom) collapse to window-list save/restore — remember
;   g_window_count on entry, restore it on exit, dropping our dialog windows
;   (same net effect as pret's buffer restore; see S5 StartMenu_Pokemon .exitMenu
;   and yes_no.asm yn_teardown).
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/oaks_pc.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"


global OpenOaksPC

extern TextBoxBorder            ; text/text.asm — ESI=top-left, BL=int_w, BH=int_h
extern place_flat_str           ; text/text.asm — EAX=flat src, ESI=dest
extern add_window               ; ppu/ppu.asm
extern g_window_count           ; ppu/ppu.asm
extern DelayFrame               ; video/frame.asm
extern YesNoChoice              ; home/yes_no.asm — CF=0 YES, CF=1 NO

%ifdef DEBUG_OAKSPC
extern DumpBackbuffer           ; debug/debug_dump.asm — writes FRAME.BIN + exits
global RunOaksPCTest
%endif

; charmap glyphs (see constants/charmap.asm)
OAK_TERM   equ 0x50             ; '@'
OAK_DOWN   equ 0xEE             ; ▼ (text prompt arrow)
OAK_SPC    equ 0x7F             ; blank tile

section .data
align 4
; --- pret data/text/text_3.asm wording, GB charmap ---------------------------
; _AccessedOaksPCText page 1: "Accessed PROF." / "OAK's PC."
oak_acc1_l1: db 0x80,0xA2,0xA2,0xA4,0xB2,0xB2,0xA4,0xA3,0x7F,0x8F,0x91,0x8E,0x85,0xE8, OAK_TERM
oak_acc1_l2: db 0x8E,0x80,0x8A,0xBD,0x7F,0x8F,0x82,0xE8, OAK_TERM
; _AccessedOaksPCText page 2: "Accessed POKéDEX" / "Rating System." (# = POKé)
oak_acc2_l1: db 0x80,0xA2,0xA2,0xA4,0xB2,0xB2,0xA4,0xA3,0x7F,0x8F,0x8E,0x8A,0xBA,0x83,0x84,0x97, OAK_TERM
oak_acc2_l2: db 0x91,0xA0,0xB3,0xA8,0xAD,0xA6,0x7F,0x92,0xB8,0xB2,0xB3,0xA4,0xAC,0xE8, OAK_TERM
; _GetDexRatedText: "Want to get your" / "POKéDEX rated?"
oak_rate_l1: db 0x96,0xA0,0xAD,0xB3,0x7F,0xB3,0xAE,0x7F,0xA6,0xA4,0xB3,0x7F,0xB8,0xAE,0xB4,0xB1, OAK_TERM
oak_rate_l2: db 0x8F,0x8E,0x8A,0xBA,0x83,0x84,0x97,0x7F,0xB1,0xA0,0xB3,0xA4,0xA3,0xE6, OAK_TERM
; _ClosedOaksPCText: "Closed link to" / "PROF.OAK's PC."
oak_clos_l1: db 0x82,0xAB,0xAE,0xB2,0xA4,0xA3,0x7F,0xAB,0xA8,0xAD,0xAA,0x7F,0xB3,0xAE, OAK_TERM
oak_clos_l2: db 0x8F,0x91,0x8E,0x85,0xE8,0x8E,0x80,0x8A,0xBD,0x7F,0x8F,0x82,0xE8, OAK_TERM

section .bss
align 4
oak_saved_wc:  resd 1           ; g_window_count on entry (buffer2 save analog)
oak_msg_wc:    resd 1           ; g_window_count before the current dialog window

section .text

; ---------------------------------------------------------------------------
; OpenOaksPC — pret ref: engine/menus/oaks_pc.asm:OpenOaksPC.
; ---------------------------------------------------------------------------
OpenOaksPC:
    ; call SaveScreenTilesToBuffer2 — DEVIATION: window-model save (see header)
    mov eax, [g_window_count]
    mov [oak_saved_wc], eax

    ; ld hl, AccessedOaksPCText / call PrintText — DEVIATION(text): drawn whole.
    ; page 1 ("Accessed PROF." / "OAK's PC.")
    mov eax, oak_acc1_l1
    mov edx, oak_acc1_l2
    call oak_draw_msg
%ifdef DEBUG_OAKSPC
    ; static FRAME.BIN dump of the opened PC message over the map — taken here,
    ; before the blocking ▼-wait / YesNoChoice, so the headless harness never
    ; stalls on input (same in-routine hook idea as RunPartyMenuTest).
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer          ; writes FRAME.BIN + exits (never returns)
%endif
    call oak_prompt              ; text `para` page break
    ; page 2 ("Accessed POKéDEX" / "Rating System.")
    mov eax, oak_acc2_l1
    mov edx, oak_acc2_l2
    call oak_draw_msg
    call oak_prompt              ; text terminal `prompt`
    call oak_msg_drop

    ; ld hl, GetDexRatedText / call PrintText — "Want to get your #DEX rated?".
    ; This text ends in `done` (no wait); it stays visible while YesNoChoice
    ; runs, so its window persists (dropped after the choice).
    mov eax, oak_rate_l1
    mov edx, oak_rate_l2
    call oak_draw_msg

    call YesNoChoice             ; CF=0 -> YES (item 0), CF=1 -> NO (item 1)
    call oak_msg_drop            ; drop the "get rated?" dialog window
    mov al, [ebp + wCurrentMenuItem]
    and al, al
    jnz .closePC                 ; jr nz — NO chosen, skip the rating
    ; predef DisplayDexRating — STUB(S8: pokedex package): the dex-rating cutscene
    ; (rating text + fanfare) lands with the pokédex package; the branch is kept,
    ; the call is a no-op until then.
.closePC:
    ; ld hl, ClosedOaksPCText / call PrintText — "Closed link to PROF.OAK's PC."
    mov eax, oak_clos_l1
    mov edx, oak_clos_l2
    call oak_draw_msg
    call oak_prompt              ; text_waitbutton
    call oak_msg_drop

    ; jp LoadScreenTilesFromBuffer2 — DEVIATION: restore the entry window list
    mov eax, [oak_saved_wc]
    mov [g_window_count], eax
    ret

; ===========================================================================
; Dialog plumbing (port; DEVIATION(text), mirrors item_effects.asm ti_dialog_*).
; oak_draw_msg draws a 2-line message box into the stride-20 W_TILEMAP scratch
; rows 12-17, mirrors it to GB_TILEMAP1 rows 0-5, and appends the UI_MESSAGE_BOX
; window (remembering the count for oak_msg_drop). oak_prompt shows the ▼ and
; waits an A/B cycle. oak_msg_drop drops the appended window.
; ; PROJ menus: GB(0,12) 20x6 --(anchor=center/bottom)--> wx=87 wy=152 clip=160
;   max_y=200 [UI_MESSAGE_BOX_*]
; ---------------------------------------------------------------------------
; In: EAX = line-1 flat str ptr, EDX = line-2 flat str ptr.
oak_draw_msg:
    push eax
    push edx
    ; border into scratch rows 12-17 (stride 20)
    mov esi, W_TILEMAP + 12 * 20
    mov bl, 18                          ; interior width  (total 20)
    mov bh, 4                           ; interior height (total 6)
    call TextBoxBorder
    pop edx
    pop eax
    push edx
    mov esi, W_TILEMAP + 14 * 20 + 1    ; line 1
    call place_flat_str                 ; EAX = flat src
    pop eax                             ; line 2
    mov esi, W_TILEMAP + 16 * 20 + 1
    call place_flat_str
    ; fall through to oak_msg_show

; mirror scratch rows 12-17 -> GB_TILEMAP1 rows 0-5 (pad cols 20-31), append the
; dialog window (remembering the caller's window count for oak_msg_drop).
oak_msg_show:
    pushad
    mov ecx, 6
    lea esi, [ebp + W_TILEMAP + 12 * 20]
    lea edi, [ebp + GB_TILEMAP1]
.row:
    push ecx
    push edi
    mov ecx, 20
    rep movsb
    mov al, OAK_SPC
    mov ecx, 12                         ; pad cols 20-31
    rep stosb
    pop edi
    pop ecx
    add edi, 32
    dec ecx
    jnz .row
    mov eax, [g_window_count]
    mov [oak_msg_wc], eax
    mov eax, UI_MESSAGE_BOX_WX          ; 87 — overworld dialog anchor
    mov ebx, UI_MESSAGE_BOX_WY          ; 152
    mov ecx, UI_MESSAGE_BOX_CLIP        ; 160
    mov edx, UI_MESSAGE_BOX_MAXY        ; 200
    mov esi, GB_TILEMAP1
    xor edi, edi
    call add_window
    popad
    ret

; ▼ + wait for an A/B press cycle (the texts' terminal prompt), then clear the ▼.
oak_prompt:
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], OAK_DOWN
.release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .release
.press:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jz .press
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], OAK_SPC
    ret

; drop the current dialog window (restore the count oak_msg_show saved)
oak_msg_drop:
    push eax
    mov eax, [oak_msg_wc]
    mov [g_window_count], eax
    pop eax
    ret

%ifdef DEBUG_OAKSPC
; ---------------------------------------------------------------------------
; RunOaksPCTest — package-A FRAME.BIN gate. Loads the font, opens OpenOaksPC over
; the (already loaded) overworld; the in-routine DEBUG_OAKSPC hook renders 3
; frames and dumps FRAME.BIN before the first blocking wait. Never returns.
; In: EBP = GB base. Call from EnterMap after the overworld is set up.
; ---------------------------------------------------------------------------
extern LoadFontTilePatterns     ; gfx/load_font.asm
RunOaksPCTest:
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call OpenOaksPC             ; the DEBUG hook dumps FRAME.BIN + exits mid-way
.hang:
    jmp .hang
%endif
