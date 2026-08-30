; ===========================================================================
; printer2.asm — pret mirror of engine/printer/printer2.asm.
;
; NOT IN THE LINKED FLOW:
;   PrinterDebug_LoadGFX, PrinterDebug_DoFunction,
;   PrinterDebug_ConvertStatusFlagsToTiles (pret :187-974) — debug test engine.
;   Its only pret caller is inside an unreferenced block
;   (engine/movie/title.asm:209-213), so it is not part of the linked printer
;   flow today. The associated Func_ea* / Data_ea9* helpers in this file are
;   only referenced from that debug engine, so they sit in its shadow too.
;   (Not a hardware/HAL deferral: the printer engine itself is ported.)
;
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "coords.inc"
%include "assets/printer_gfx.inc"

%ifndef SET_PAL_POKEDEX
SET_PAL_POKEDEX equ 0x01
%endif

GLYPH_NO        equ 0x74

global Printer_GetMonStats

extern PrinterMonStats_OT                ; src/engine/printer/printer.asm
extern PrinterMonStats_IDNo              ; src/engine/printer/printer.asm
extern PrinterMonStats_Stats             ; src/engine/printer/printer.asm
extern PrinterMonStats_Blank             ; src/engine/printer/printer.asm

extern GBPalWhiteOutWithDelay3           ; src/home/palettes.asm
extern ClearScreen                       ; src/home/copy2.asm
extern LoadHpBarAndStatusTilePatterns    ; src/home/load_font.asm
extern CopyVideoDataDouble               ; src/home/copy2.asm
extern LoadMonData                       ; src/home/pokemon.asm
extern TextBoxBorder                     ; src/home/text.asm
extern PrintLevelFull                    ; src/home/pokemon.asm
extern PrintNumber                       ; src/home/print_num.asm
extern GetMonName                        ; src/home/names.asm
extern IndexToPokedex                    ; src/engine/menus/pokedex.asm
extern PlaceString                       ; src/home/text.asm
extern GetMoveName                       ; src/home/names.asm
extern RunPaletteCommand                 ; src/home/palettes.asm
extern Delay3                            ; src/home/palettes.asm
extern GBPalNormal                       ; src/home/palettes.asm
extern LoadFlippedFrontSpriteByMonIndex  ; src/home/pokemon.asm
extern AddNTimes                         ; src/home/array.asm

section .text

; ---------------------------------------------------------------------------
; Printer_GetMonStats — pret engine/printer/printer2.asm:1-142.
;
; DEVIATION{class=projection; pret=engine/printer/printer2.asm:Printer_GetMonStats; behavior=the Pokémon Fan Club portrait screen layout is centered on the 40x25 canvas by adding 10 columns and 3 rows to pret hlcoords; evidence=pret 20x18 layout centered on port 40x25 canvas per maintainer screen projection ruling; lifetime=permanent while the port renders a 40x25 canvas}
; ---------------------------------------------------------------------------
Printer_GetMonStats:
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    call LoadHpBarAndStatusTilePatterns
    mov edx, GFX_ea563
    mov esi, vChars2 + 0x710
    mov bh, 0                            ; BANK(GFX_ea563) unused
    mov bl, (GFX_ea563End - GFX_ea563) / 8
    call CopyVideoDataDouble

    mov edx, GFX_ea56b
    mov esi, vChars2 + 0x6E0
    mov bh, 0                            ; BANK(GFX_ea56b) unused
    mov bl, (GFX_ea56bEnd - GFX_ea56b) / 8
    call CopyVideoDataDouble

    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    mov [ebp + wWhichTradeMonSelectionMenu], al
    call LoadMonData

    hlcoord 10, 3                        ; PROJ — pret hlcoord 0, 0 (wTileMap)
    mov bh, 16                           ; lb bc, 16, 18
    mov bl, 18
    call TextBoxBorder

    hlcoord 10, 15                       ; PROJ — pret hlcoord 0, 12
    mov bh, 4                            ; lb bc, 4, 18
    mov bl, 18
    call TextBoxBorder

    hlcoord 13, 13                       ; PROJ — pret hlcoord 3, 10
    call PrintLevelFull

    hlcoord 12, 13                       ; PROJ — pret hlcoord 2, 10
    mov byte [ebp + esi], 0x6E           ; ld a, $6e / ld [hli], a
    inc esi
    mov byte [ebp + esi], ' '            ; ld [hl], ' '

    hlcoord 12, 14                       ; PROJ — pret hlcoord 2, 11
    mov byte [ebp + esi], 0x71           ; ld [hl], '’' (HP symbol)

    hlcoord 14, 14                       ; PROJ — pret hlcoord 4, 11
    mov edx, wLoadedMonMaxHP
    mov bh, 2                            ; lb bc, 2, 3
    mov bl, 3
    call PrintNumber

    mov al, [ebp + wMonHIndex]
    mov [ebp + wPokedexNum], al
    mov [ebp + wCurSpecies], al
    mov esi, wPartyMonNicks
    call .GetNamePointer
    hlcoord 18, 5                        ; PROJ — pret hlcoord 8, 2
    call PlaceString

    call GetMonName
    hlcoord 19, 6                        ; PROJ — pret hlcoord 9, 3
    call PlaceString

    call IndexToPokedex                  ; predef IndexToPokedex
    hlcoord 12, 11                       ; PROJ — pret hlcoord 2, 8
    mov byte [ebp + esi], GLYPH_NO       ; ld [hl], '№'
    inc esi
    mov byte [ebp + esi], 0xF2           ; ld [hl], $f2
    inc esi
    mov edx, wPokedexNum
    mov bh, 0x80 | 1                     ; lb bc, $80 | 1, 3
    mov bl, 3
    call PrintNumber

    hlcoord 18, 7                        ; PROJ — pret hlcoord 8, 4
    mov edx, PrinterMonStats_OT          ; ld de, .OT
    call PlaceString

    mov esi, wPartyMonOT
    call .GetNamePointer
    hlcoord 19, 8                        ; PROJ — pret hlcoord 9, 5
    call PlaceString

    hlcoord 19, 9                        ; PROJ — pret hlcoord 9, 6
    mov edx, PrinterMonStats_IDNo        ; ld de, .IDNo
    call PlaceString

    hlcoord 23, 9                        ; PROJ — pret hlcoord 13, 6
    mov edx, wLoadedMonOTID
    mov bh, 0x80 | 2                     ; lb bc, $80 | 2, 5
    mov bl, 5
    call PrintNumber

    hlcoord 19, 11                       ; PROJ — pret hlcoord 9, 8
    mov edx, PrinterMonStats_Stats       ; ld de, .Stats
    or byte [ebp + hUILayoutFlags], 1 << BIT_SINGLE_SPACED_LINES
    call PlaceString
    and byte [ebp + hUILayoutFlags], ~(1 << BIT_SINGLE_SPACED_LINES) & 0xFF

    hlcoord 26, 11                       ; PROJ — pret hlcoord 16, 8
    mov edx, wLoadedMonAttack
    mov cl, 4                            ; ld a, 4
.loop:
    push ecx
    push edx

    push esi
    mov bh, 2                            ; lb bc, 2, 3
    mov bl, 3
    call PrintNumber
    pop esi
    add esi, SCREEN_WIDTH

    pop edx
    add edx, 2                           ; inc de / inc de
    pop ecx
    dec cl
    jnz .loop

    hlcoord 11, 16                       ; PROJ — pret hlcoord 1, 13
    mov al, [ebp + wLoadedMonMoves + 0]
    call .PlaceMoveName

    hlcoord 11, 17                       ; PROJ — pret hlcoord 1, 14
    mov al, [ebp + wLoadedMonMoves + 1]
    call .PlaceMoveName

    hlcoord 11, 18                       ; PROJ — pret hlcoord 1, 15
    mov al, [ebp + wLoadedMonMoves + 2]
    call .PlaceMoveName

    hlcoord 11, 19                       ; PROJ — pret hlcoord 1, 16
    mov al, [ebp + wLoadedMonMoves + 3]
    call .PlaceMoveName

    mov bl, SET_PAL_POKEDEX              ; ld b, SET_PAL_POKEDEX
    call RunPaletteCommand

    mov byte [ebp + hAutoBGTransferEnabled], 1
    call Delay3
    call GBPalNormal
    hlcoord 11, 4                        ; PROJ — pret hlcoord 1, 1
    call LoadFlippedFrontSpriteByMonIndex
    ret

.GetNamePointer:
    mov bh, 0
    mov bl, NAME_LENGTH
    mov al, [ebp + wWhichPokemon]
    call AddNTimes
    mov edx, esi
    ret

.PlaceMoveName:
    test al, al
    jz .no_move
    mov [ebp + wNamedObjectIndex], al
    call GetMoveName
    jmp .place_string

.no_move:
    mov edx, PrinterMonStats_Blank
.place_string:
    call PlaceString
    ret
