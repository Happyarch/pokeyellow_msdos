; reload_sprites.asm — ReloadMapSpriteTilePatterns translated from SM83 to x86.
;
; Source: home/reload_sprites.asm:ReloadMapSpriteTilePatterns (pret/pokeyellow).
; Intended path: dos_port/src/engine/overworld/reload_sprites.asm
;
; Copies the current map's sprites' tile patterns back to VRAM after they were
; overwritten by other tile patterns (e.g. after a menu / battle / animation).
; Composed entirely from already-ported parts — no new VRAM logic here, so the
; g_tilecache_dirty flag is set by the callees that actually write VRAM
; (InitMapSprites, LoadPlayerSpriteGraphics, LoadFontTilePatterns), matching
; CLAUDE.md's "any routine that writes VRAM tile data must set g_tilecache_dirty"
; rule at the correct level.
;
; pret structure (faithful):
;   save wFontLoaded; clear BIT_FONT_LOADED so InitMapSprites reloads sprite
;   tiles into the VRAM region the font time-shares; wSpriteSetID = 0 forces a
;   full sprite-set reload; DisableLCD/InitMapSprites/EnableLCD; restore
;   wFontLoaded; reload the player graphics + font; tail-call UpdateSprites.
;
; Build: nasm -f coff -I include/ -o reload_sprites.o reload_sprites.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global ReloadMapSpriteTilePatterns

extern DisableLCD                   ; src/video/lcd_control.asm
extern EnableLCD                    ; src/video/lcd_control.asm
extern InitMapSprites               ; src/engine/overworld/map_sprites.asm
extern LoadPlayerSpriteGraphics     ; src/engine/overworld/overworld.asm
extern LoadFontTilePatterns         ; src/gfx/load_font.asm
extern UpdateSprites                ; src/engine/overworld/movement.asm

section .text

; ---------------------------------------------------------------------------
; ReloadMapSpriteTilePatterns — reload map sprite tiles into VRAM.
;   No inputs. Clobbers registers freely (faithful to pret, which does too).
;   Tail-jumps to UpdateSprites.
; ---------------------------------------------------------------------------
ReloadMapSpriteTilePatterns:
    mov al, [ebp + W_FONT_LOADED]                       ; ld hl,wFontLoaded; ld a,[hl]
    push eax                                            ; push af (save font state)
    and byte [ebp + W_FONT_LOADED], ~(1 << BIT_FONT_LOADED) & 0xFF ; res BIT_FONT_LOADED,[hl]

    mov byte [ebp + W_SPRITE_SET_ID], 0                 ; xor a; ld [wSpriteSetID],a

    call DisableLCD
    call InitMapSprites
    call EnableLCD

    pop eax                                             ; pop af
    mov [ebp + W_FONT_LOADED], al                       ; ld [hl],a (restore font state)

    call LoadPlayerSpriteGraphics
    call LoadFontTilePatterns
    jmp UpdateSprites                                   ; jp UpdateSprites (tail call)
