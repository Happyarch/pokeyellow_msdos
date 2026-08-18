; ===========================================================================
; diploma.asm — pret mirror of engine/events/diploma.asm.
;
; DisplayDiploma: save screen, clear, disable sprite updates, set
; BIT_NO_TEXT_DELAY in wStatusFlags5, call DisplayDiplomaTop, wait for button
; press, clear BIT_NO_TEXT_DELAY, restore screen and palettes.
;
; Register map (CLAUDE.md): A->AL, HL->ESI; GB memory = [ebp + SYM].
; ===========================================================================

bits 32

%include "gb_memmap.inc"

global DisplayDiploma

extern SaveScreenTilesToBuffer2                  ; src/home/tilemap.asm
extern GBPalWhiteOutWithDelay3                   ; src/home/palettes.asm
extern ClearScreen                              ; src/home/copy2.asm
extern DisplayDiplomaTop                        ; src/engine/events/diploma2.asm
extern WaitForTextScrollButtonPress             ; src/home/joypad2.asm
extern ReloadTilesetTilePatterns                ; src/home/reload_tiles.asm
extern RestoreScreenTilesAndReloadTilePatterns  ; src/home/palettes.asm
extern Delay3                                   ; src/home/palettes.asm
extern GBPalNormal                              ; src/home/palettes.asm

section .text

; ---------------------------------------------------------------------------
; DisplayDiploma — pret engine/events/diploma.asm:DisplayDiploma.
; ---------------------------------------------------------------------------
DisplayDiploma:
    call SaveScreenTilesToBuffer2
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    xor al, al                                  ; xor a
    mov [ebp + wUpdateSpritesEnabled], al        ; ld [wUpdateSpritesEnabled], a
    mov esi, wStatusFlags5                      ; ld hl, wStatusFlags5
    or byte [ebp + esi], 1 << BIT_NO_TEXT_DELAY ; set BIT_NO_TEXT_DELAY, [hl]
    call DisplayDiplomaTop                      ; callfar DisplayDiplomaTop
    call WaitForTextScrollButtonPress
    mov esi, wStatusFlags5                      ; ld hl, wStatusFlags5
    and byte [ebp + esi], ~(1 << BIT_NO_TEXT_DELAY) & 0xFF ; res BIT_NO_TEXT_DELAY, [hl]
    call GBPalWhiteOutWithDelay3
    call ReloadTilesetTilePatterns
    call RestoreScreenTilesAndReloadTilePatterns
    call Delay3
    jmp GBPalNormal                             ; jp GBPalNormal
