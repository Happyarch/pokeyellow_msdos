; msgbox.inc — the message-box PROJECTION record.
;
; pret has exactly one message box: PrintText draws MESSAGE_BOX at GB (0,12) and
; types the stream at (1,14), on whatever tilemap is live. The port has exactly
; one PrintText too (home/window.asm) — but the port's canvas is 40x25, not the
; GB's 20x18, so *where* that box lands is a per-screen projection decision:
;
;   msgbox_dialog   (text.asm)  — the overworld dialog. Drawn in the GB-shaped
;                                 stride-20 scratch and shown through the dialog
;                                 window, at a placement hand-tuned for the wider
;                                 screen (not a mechanical GB->canvas mapping).
;   msgbox_centered (core.asm)  — the battle box: center-projected onto the
;                                 stride-40 canvas and drawn directly into it, so
;                                 it does not disturb the caller's window list.
;                                 Full-screen menus (save / naming / learn_move /
;                                 evolution / in-battle item use) select it for
;                                 exactly that reason.
;
; The DIFFERENCE BETWEEN THE TWO IS DATA, NOT CODE. There is one printer; a screen
; selects its projection by pointing `text_msgbox` at a record. Re-projecting the
; battle box (e.g. making it stride-40-native) is an edit to msgbox_centered — it
; must never become a second PrintText.
;
; All fields are dwords. Offsets are EBP-relative GB-memory offsets (W_TILEMAP-
; based), except MB_PROMPT (a flat code pointer) and the MB_WIN_* block.

MB_STRIDE       equ 0    ; tilemap row stride for this canvas (20 or 40)
MB_BOX_OFS      equ 4    ; W_TILEMAP offset of the box's top-left corner
MB_BOX_W        equ 8    ; TextBoxBorder interior width  (C)
MB_BOX_H        equ 12   ; TextBoxBorder interior height (B)
MB_LINE1        equ 16   ; cursor: 1st text line   (pret bccoord 1,14)
MB_LINE2        equ 20   ; <LINE>: 2nd text line
MB_ARROW        equ 24   ; <PROMPT> ▼ tile (0 = this projection has none)
MB_PROMPT       equ 28   ; <PROMPT> hook, flat ptr (0 = caller waits)
MB_WIN_WX       equ 32   ; --- window descriptor: only if MB_WIN_TILEMAP != 0 ---
MB_WIN_WY       equ 36
MB_WIN_CLIP     equ 40
MB_WIN_MAXY     equ 44
MB_WIN_TILEMAP  equ 48   ; source tilemap; 0 = NO window — draw straight into the
                         ; canvas and leave the caller's window list alone
MB_WIN_STARTROW equ 52
MB_SIZE         equ 56
