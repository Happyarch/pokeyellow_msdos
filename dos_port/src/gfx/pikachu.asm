; pikachu.asm — mirror of pret gfx/pikachu.asm.
;
; Carrier for the pikapic (Pikachu front-pic facial animation) graphics: the
; compressed `Pic_*` front pics and the uncompressed `GFX_*` 2bpp cel sheets that
; PikaPicAnimCommand_loadgfx pulls into vNPCSprites.  pret puts them in two ROMX
; sections ("Pikachu Graphics 1"/"2"); under the flat model they are one .data run.
;
; Tier-1 data: the bytes are emitted by tools/generators/gen_pikachu_pic.py, which
; is a deterministic passthrough of the read-only pret .2bpp/.pic files.
;
; Build: nasm -f coff -I include/ -I . -o pikachu.o pikachu.asm

bits 32

%include "assets/pikachu_pic_gfx_globals.inc"

section .data

%include "assets/pikachu_pic_gfx.inc"
