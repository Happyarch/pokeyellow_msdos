; ============================================================================
; cable_club.asm — Cable Club (link) helpers.
;
; menus S3: holds only CableClub_TextBoxBorder + CableClub_DrawHorizontalLine,
; needed by yes_no.asm's DisplayTwoOptionMenu TRADE_CANCEL_MENU branch (pret
; engine/menus/text_box.asm:257 picks this border for that menu id).
; Session 8 (link_menu packages I1/I2) extends this file with the rest of pret
; engine/link/cable_club.asm.
;
; TILE NOTE: the $76-$7D border tiles are the TrainerInfoTextBoxTileGraphics
; set, loaded to vChars2 tile $76 by LoadTrainerInfoTextBoxTiles (pret
; cable_club.asm:983 — NOT ported yet; S8/I1 scope). Until then a
; TRADE_CANCEL_MENU border renders with whatever tiles occupy $76-$7D; its only
; callers are the link menus, which also land in S8.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP=GB base.
;
; Build check: nasm -f coff -I include/ -I . -o /dev/null cable_club.asm
; ============================================================================

%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

extern text_row_stride          ; text.asm — active W_TILEMAP row stride

global CableClub_TextBoxBorder
global CableClub_DrawHorizontalLine

TILE_SPC        equ 0x7F        ; ' ' blank tile (charmap.asm)

section .text

; ----------------------------------------------------------------------------
; CableClub_TextBoxBorder — pret engine/link/cable_club.asm:944.
; Same interface as text.asm:TextBoxBorder so callers can swap them freely:
; In:  ESI = top-left tile-buffer offset (HL, EBP-relative)
;      BL  = interior width (C), BH = interior height (B)
; Out: ESI/EBX/EDX preserved. EAX, ECX, EDI clobbered.
; Row advance uses [text_row_stride] (pret hardcodes SCREEN_WIDTH=20; the port
; convention lets the caller pick the staging stride, like TextBoxBorder).
; ----------------------------------------------------------------------------
CableClub_TextBoxBorder:
    push esi
    push ebx
    push edx

    movzx ecx, bl               ; ECX = interior width
    movzx edx, bh               ; EDX = interior height (rows of middle)
    lea edi, [ebp + esi]

    ; top row: $78 + $79*width + $7a
    mov byte [edi], 0x78        ; border upper left corner tile
    mov al, 0x79                ; border top horizontal line tile
    call CableClub_DrawHorizontalLine
    mov byte [edi + ecx + 1], 0x7A  ; border upper right corner tile
    add edi, [text_row_stride]

    ; middle rows: $7b + ' '*width + $77 (EDX times)
.loop:
    mov byte [edi], 0x7B        ; border left vertical line tile
    mov al, TILE_SPC
    call CableClub_DrawHorizontalLine
    mov byte [edi + ecx + 1], 0x77  ; border right vertical line tile
    add edi, [text_row_stride]
    dec edx
    jnz .loop

    ; bottom row: $7c + $76*width + $7d
    mov byte [edi], 0x7C        ; border lower left corner tile
    mov al, 0x76                ; border bottom horizontal line tile
    call CableClub_DrawHorizontalLine
    mov byte [edi + ecx + 1], 0x7D  ; border lower right corner tile

    pop edx
    pop ebx
    pop esi
    ret

; ----------------------------------------------------------------------------
; CableClub_DrawHorizontalLine — pret engine/link/cable_club.asm:974.
; Write ECX copies of AL starting at [EDI+1]. Preserves EDI and ECX.
; ----------------------------------------------------------------------------
CableClub_DrawHorizontalLine:
    push ecx
    push edi
    inc edi
.dl_loop:
    mov [edi], al
    inc edi
    dec ecx
    jnz .dl_loop
    pop edi
    pop ecx
    ret
