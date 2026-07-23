; title_yellow.asm — Yellow title-screen helpers, at their pret mirror.
;
; Source: engine/movie/title_yellow.asm (pret/pokeyellow). Started at the
; menu-intro review (2026-07-23) with Bank3D_CopyBox; the rest of that pret
; file's labels (LoadYellowTitleScreenGFX, TitleScreen_PlacePokemonLogo /
; _PlacePikachu / _PlacePikaSpeechBubble, the tilemap data) still live in the
; port's legacy title module src/movie/title.asm (relocation debt, see
; tools/pret_label_allowlist.json); move them here when touched.
;
; Build: nasm -f coff -I include/ -o title_yellow.o title_yellow.asm

bits 32

%include "gb_memmap.inc"

section .text

; ---------------------------------------------------------------------------
; Bank3D_CopyBox — copy a c-wide × b-tall tile box from a flat source into the
; canvas (pret engine/movie/title_yellow.asm:Bank3D_CopyBox; the row step is the
; canvas stride SCREEN_TILES_W instead of pret's SCREEN_WIDTH — the projection).
; In: ESI = flat src (advances through the box), EDI = flat dest (EBP-biased,
;     top-left corner), BH = rows (pret b), BL = cols (pret c).
; Clobbers ECX/ESI/EDI/EBX.
; ---------------------------------------------------------------------------
global Bank3D_CopyBox
Bank3D_CopyBox:
.row:
    movzx ecx, bl                      ; ld c (cols)
    push edi                           ; push hl
    rep movsb                          ; the .col loop
    pop edi                            ; pop hl
    add edi, SCREEN_TILES_W            ; ld bc, SCREEN_WIDTH / add hl, bc
    dec bh                             ; dec b
    jnz .row                           ; jr nz, .row
    ret
