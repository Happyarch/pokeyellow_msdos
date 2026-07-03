; ===========================================================================
; pokedex_entry.asm — POKéDEX DATA (entry) page. menus-port Session 8, package G2.
; Faithful port of the entry-page half of pret engine/menus/pokedex.asm
; (lines ~438-693): ShowPokedexData / ShowPokedexDataInternal /
; DrawDexEntryOnScreen / Pokedex_PrintFlavorTextAtRow11 / …AtBC /
; Pokedex_PrepareDexEntryForPrinting, plus the data (HeightWeightText, PokeText,
; PokedexDataDividerLine).
;
; SEAM (G1↔G2): the 2D scroller + side menu (pokedex.asm, G1) is a separate
; worker/worktree. This file assembles + `make check` STANDALONE. Across the
; seam: we `extern` DrawTileLine / IsPokemonBitSet / PokedexToIndex (G1 defines
; them) and `global` ShowPokedexData / ShowPokedexDataInternal (G1's side menu +
; external callers jump here). Root finalizes the link/%include at integration.
;
; PORT MODEL — full-screen window takeover (options.asm pattern, the working
; reference for a stride-20 20x18 menu; sibling C/D/E use it):
; - The page is drawn at pret GB coords into the 20-wide stride-20 W_TILEMAP
;   scratch (hlcoord X,Y = W_TILEMAP + Y*20 + X; GBSCR_W = 20; text_row_stride
;   forced to 20 as InitOptionsMenu does).  dex_mirror blits the 20x18 scratch →
;   GB_TILEMAP1 rows 0-17 and dex_show_window defines the single descriptor at
;   UI_POKEDEX_ENTRY_*; g_bg_whiteout blanks the overworld behind it. This
;   stands in for pret's hAutoBGTransferEnabled VBlank BGMap transfer (frame.asm
;   do_bg_transfer is canvas-scoped/stride-40 and cannot serve a stride-20
;   scratch — same explicit-mirror pattern as S3/S5/S6 siblings).
;
; ; PROJ menus: GB(0,0) 20x18 --(center/top, X+10)--> wx=87 wy=0 clip=160
;   max_y=144 [UI_POKEDEX_ENTRY_*].
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH,C=BL), DE=DX (D=DH,E=DL), HL=ESI,
; EBP = GB memory base; GB memory = [ebp + symbol].
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/pokedex_entry.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

; ---------------------------------------------------------------------------
; Exports (called by ShowPokedexData callers + G1's side menu).
; ---------------------------------------------------------------------------
global ShowPokedexData
global ShowPokedexDataInternal
global DrawDexEntryOnScreen
global Pokedex_PrintFlavorTextAtRow11
global Pokedex_PrintFlavorTextAtBC
global Pokedex_PrepareDexEntryForPrinting

; ---------------------------------------------------------------------------
; Externs — seam (G1) + shared engine routines.
; ---------------------------------------------------------------------------
; --- G1 seam (engine/menus/pokedex.asm, defined by the sibling worker) -------
extern DrawTileLine              ; BH=tile, BL=count, DX=stride(1/20), ESI=dest
extern IsPokemonBitSet           ; reads wPokedexNum, ESI=flag base → AL/BL=owned
; (PokedexToIndex is G1's — the entry page never calls it, so it is not extern'd.)
; --- flat data table (src/data/pokemon_data.asm): byte[species-1]=dex# ---------
extern IndexToPokedex            ; NOTE: a TABLE in the port, not pret's routine
; --- text / numbers / names ---------------------------------------------------
extern PlaceString               ; text/text.asm — EAX=flat src, ESI=dest
extern PrintNumber               ; home/print_num.asm — EDX=src(EBP-rel), BH=flags|bytes, BL=digits, ESI=dest
extern TextCommandProcessor      ; text/text.asm — ESI=stream(GB off), EBX=cursor
extern GetMonName                ; home/names.asm — wNamedObjectIndex → wNameBuffer
extern GetMonHeader              ; home/pokemon.asm — wCurSpecies → wMonHeader
extern LoadFlippedFrontSpriteByMonIndex ; gfx/pics.asm — EDX=VRAM dest; decode → VRAM
; --- palette / fade / screen / timing (Phase-5 palette work is HAL-stubbed) ---
extern GBPalWhiteOut             ; home/fade.asm
extern GBPalWhiteOutWithDelay3   ; home/fade.asm
extern GBPalNormal               ; init/init.asm
extern ClearScreen               ; movie/title.asm (fills W_TILEMAP, Delay3)
extern Delay3                    ; video/frame.asm
extern DelayFrame                ; video/frame.asm
extern LoadTextBoxTilePatterns   ; gfx/load_font.asm
extern RunPaletteCommand         ; engine/battle/faint_switch.asm — palette HAL stub
extern UpdateSprites             ; engine/overworld/movement.asm
extern JoypadLowSensitivity      ; input/joypad_lowsens.asm → [hJoy5]
extern LoadPokedexTilePatterns   ; gfx (dex $60-$6f tileset + font) — root wires (see report)
; --- window compositor --------------------------------------------------------
extern set_single_window         ; ppu/ppu.asm
extern g_bg_whiteout             ; ppu/ppu.asm
extern text_row_stride           ; text/text.asm — active W_TILEMAP row stride

%ifdef DEBUG_G2
extern DumpBackbuffer            ; debug/debug_dump.asm — writes FRAME.BIN + exits
extern LoadFontTilePatterns      ; gfx/load_font.asm
extern ClearSprites              ; gfx/sprites.asm
global RunPokedexEntryTest
%endif

; ---------------------------------------------------------------------------
; Local equates — new WRAM/HRAM + bits/palette ids NOT yet in the shared
; includes. REPORTED to root for promotion to gb_memmap.inc / gb_constants.inc
; (placeholder addresses; root derives the real ones off the .sym). Placed here
; per the S6/S7 worker convention (options.asm's SOUND_MASK etc. were promoted
; the same way at integration).
; ---------------------------------------------------------------------------
; hDexWeight — pret ram/hram.asm: UNION at HRAM top (= hBaseTileID). 2-byte scratch
; that DrawDexEntryOnScreen stages the big-endian weight into for PrintNumber.
hDexWeight                        equ 0xFF8B   ; sym-verified (S8; was 0xFF81 guess)
; hClearLetterPrintingDelayFlags — pret ram/hram.asm (byte before hUILayoutFlags).
; Mirrors text.asm's own local equate; used to force-clear the letter delay so the
; flavor prints instantly (%10 = clear BIT_TEXT_DELAY).
H_CLEAR_LETTER_PRINTING_DELAY_FLAGS equ 0xFFF9
; hUILayoutFlags bit (pret constants/gfx_constants.asm) — treat <PAGE> as <NEXT>.
BIT_PAGE_CHAR_IS_NEXT             equ 3
; wStatusFlags2 bit (pret constants/ram_constants.asm).
BIT_NO_AUDIO_FADE_OUT             equ 1
; palette command id (pret constants/palette_constants.asm).
SET_PAL_POKEDEX                   equ 0x04
; wPrinterPokedexEntryTextPointer — pret ram/wram.asm:327 (dw). ONLY read by the
; out-of-scope printer path (Pokedex_PrepareDexEntryForPrinting). Placeholder; the
; printer path is unused in menus scope (see tag). REPORTED to root.
wPrinterPokedexEntryTextPointer   equ 0xCAF5   ; sym-verified (S8; was 0xCF17 guess)
; wDexFlavorBuf — PORT-ONLY staging buffer (DEVIATION, see Pokedex_PrintFlavorText).
; TextCommandProcessor is EBP-relative but the flavor stream lives in flat .data,
; so the flavor bytes are copied into GB space before TCP. Reuses wTileMapBackup2
; ($F000, 1000 B) — a screen-backup scratch NOT touched by the per-frame BG/window
; renderer (render_bg reads wSurroundingTiles $E000). REPORTED so root may give it
; a dedicated home.
wDexFlavorBuf                     equ W_TILEMAP_BACKUP2
DEX_FLAVOR_MAX                    equ 300         ; copy bound (entries are < ~140 B)

; charmap glyphs (constants/charmap.asm)
GLYPH_NO       equ 0x74     ; '№'
GLYPH_DOT      equ 0xF2     ; '<DOT>' decimal point
GLYPH_FEET     equ 0x60     ; '′'  (dex tileset, gfx/pokedex/pokedex.png)
GLYPH_INCHES   equ 0x61     ; '″'  (dex tileset)
GLYPH_ZERO     equ 0xF6     ; '0'
TILE_SPC       equ 0x7F     ; blank tile

GBSCR_W        equ 20       ; pret SCREEN_WIDTH — stride of the stride-20 scratch
; hlcoord X,Y helper (stride-20 scratch)
%define HL(X,Y)  (W_TILEMAP + (Y) * GBSCR_W + (X))

; ---------------------------------------------------------------------------
; .bss — port register spill (stands in for pret's push/pop chain across the
; long GetMonName/GetMonHeader/pic-load span; observably identical).
; ---------------------------------------------------------------------------
section .bss
align 4
dex_entry_ptr:    resd 1     ; FLAT .data ptr to the current PokedexEntry blob
dex_flavor_ptr:   resd 1     ; FLAT .data ptr to the flavor stream ($00 TX_START)
saved_pokedexnum: resb 1     ; internal index, saved while wPokedexNum holds dex#
saved_owned:      resb 1     ; owned flag (from IsPokemonBitSet)

; ---------------------------------------------------------------------------
; .data — dex entry blobs + this file's charmap strings.
; ---------------------------------------------------------------------------
section .data
align 4
; PokedexEntryPointers + all 152 entry blobs (flat .data, charmap-encoded).
; %included (not extern'd) because G2 is the primary consumer of the entry data;
; root ensures single inclusion across the G1/G2 seam at integration.
global PokedexEntryPointers          ; S8 seam: I2 (link_cups.asm PetitCup) externs it
%include "assets/dex_entries.inc"

align 4
; pret ref: pokedex.asm:HeightWeightText — db "HT  ?′??″" / next "WT   ???lb@"
HeightWeightText:
    db 0x87,0x93,0x7F,0x7F,0xE6,0x60,0xE6,0xE6,0x61   ; "HT  ?'??\""
    db 0x4E                                            ; <NEXT>
    db 0x96,0x93,0x7F,0x7F,0x7F,0xE6,0xE6,0xE6,0xAB,0xA1,0x50 ; "WT   ???lb@"

; pret ref: pokedex.asm:PokeText — leftover JP suffix "POKéMON". unreferenced.
; DEVIATION(unused): ported for parity; no caller in the port (or pret) reads it.
PokeText:
    db 0x54,0x50                                       ; "#@"  (# = POKé)

; pret ref: pokedex.asm:PokedexDataDividerLine — horizontal divider (dex tileset).
PokedexDataDividerLine:
    db 0x68,0x69,0x6B,0x69,0x6B,0x69,0x6B,0x69,0x6B,0x6B
    db 0x6B,0x6B,0x69,0x6B,0x69,0x6B,0x69,0x6B,0x69,0x6A
    db 0x50

section .text

; ===========================================================================
; ShowPokedexData — pret ref: pokedex.asm:ShowPokedexData.
; Display pokedex data from OUTSIDE the pokedex (loads the dex tile patterns
; first, then falls through to ShowPokedexDataInternal).
; ===========================================================================
ShowPokedexData:
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    call UpdateSprites
    call LoadPokedexTilePatterns        ; callfar LoadPokedexTilePatterns
    ; fall through

; ===========================================================================
; ShowPokedexDataInternal — pret ref: pokedex.asm:ShowPokedexDataInternal.
; Draw the entry page, print the flavor if owned, then wait for A/B.
; ===========================================================================
ShowPokedexDataInternal:
    ; ld hl, wStatusFlags2 / set BIT_NO_AUDIO_FADE_OUT, [hl]
    or byte [ebp + W_STATUS_FLAGS_2], 1 << BIT_NO_AUDIO_FADE_OUT
    ; ld a,$33 / ldh [rAUDVOL],a — TODO-HW: audio HAL (Phase 3). No APU; skipped.
    ; ldh a,[hTileAnimations] / push af / xor a / ldh [hTileAnimations],a
    movzx eax, byte [ebp + H_TILE_ANIMATIONS]
    push eax
    xor al, al
    mov [ebp + H_TILE_ANIMATIONS], al
    call GBPalWhiteOut                   ; zero all palettes
    mov al, [ebp + wPokedexNum]
    mov [ebp + wCurPartySpecies], al
    push eax                             ; push af (wPokedexNum)
    ; ld b, SET_PAL_POKEDEX / call RunPaletteCommand — TODO-HW: palette (Phase 5).
    ; RunPaletteCommand is a HAL no-op stub (faint_switch.asm); called for flow/label.
    mov bh, SET_PAL_POKEDEX
    call RunPaletteCommand
    pop eax                              ; pop af
    mov [ebp + wPokedexNum], al
    call DrawDexEntryOnScreen            ; sets CF = "print the flavor text" (owned)
    jnc .waitForButtonPress             ; call c, Pokedex_PrintFlavorTextAtRow11
    call Pokedex_PrintFlavorTextAtRow11
.waitForButtonPress:
    call JoypadLowSensitivity
    mov al, [ebp + H_JOY5]               ; ldh a,[hJoy5]
    and al, PAD_A | PAD_B
    jz .waitForButtonPress
    pop eax                              ; pop af (hTileAnimations)
    mov [ebp + H_TILE_ANIMATIONS], al
    call GBPalWhiteOut
    call ClearScreen
    ; call RunDefaultPaletteCommand — TODO-HW: default palette set (Phase 5), no-op
    ; (not defined in the port; same as league_pc's teardown).
    call LoadTextBoxTilePatterns
    call GBPalNormal
    ; ld hl, wStatusFlags2 / res BIT_NO_AUDIO_FADE_OUT, [hl]
    and byte [ebp + W_STATUS_FLAGS_2], (~(1 << BIT_NO_AUDIO_FADE_OUT)) & 0xFF
    ; ld a,$77 / ldh [rAUDVOL],a — TODO-HW: audio HAL (Phase 3). Skipped.
    ret

; ===========================================================================
; DrawDexEntryOnScreen — pret ref: pokedex.asm:DrawDexEntryOnScreen.
; Draw the bordered data page (border/divider/HT-WT/name/№/species + front pic).
; For OWNED mons also print height + weight and stash the flavor pointer.
; Out: CF set = "print the flavor" (owned); CF clear = unowned (skip flavor).
; ===========================================================================
DrawDexEntryOnScreen:
    call ClearScreen                     ; blanks W_TILEMAP
    ; port: the entry page runs on the 20-wide stride-20 scratch (PlaceString
    ; <NEXT> + the flavor advance by text_row_stride). Same reset InitOptionsMenu
    ; does; the START menu can leave it at 40.
    mov dword [text_row_stride], GBSCR_W

    ; --- border (four DrawTileLine edges; dex tileset $64/$6f/$66/$67) ----------
    mov esi, HL(0, 0)                    ; hlcoord 0,0 — top border
    mov edx, 1                           ; de = 1 (horizontal)
    mov bh, 0x64
    mov bl, GBSCR_W                      ; lb bc, $64, SCREEN_WIDTH
    call DrawTileLine
    mov esi, HL(0, 17)                   ; hlcoord 0,17 — bottom border
    mov edx, 1
    mov bh, 0x6F
    mov bl, GBSCR_W
    call DrawTileLine
    mov esi, HL(0, 1)                    ; hlcoord 0,1 — left border
    mov edx, GBSCR_W                     ; de = 20 (vertical)
    mov bh, 0x66
    mov bl, 0x10                         ; lb bc, $66, $10
    call DrawTileLine
    mov esi, HL(19, 1)                   ; hlcoord 19,1 — right border
    mov edx, GBSCR_W
    mov bh, 0x67
    mov bl, 0x10
    call DrawTileLine

    ; --- corner tiles (ldcoord_a) ----------------------------------------------
    mov byte [ebp + HL(0, 0)],  0x63     ; upper left
    mov byte [ebp + HL(19, 0)], 0x65     ; upper right
    mov byte [ebp + HL(0, 17)], 0x6C     ; lower left
    mov byte [ebp + HL(19, 17)],0x6E     ; lower right

    ; --- divider line (row 9) + HT/WT labels (row 6) ---------------------------
    mov eax, PokedexDataDividerLine
    mov esi, HL(0, 9)
    call PlaceString
    mov eax, HeightWeightText
    mov esi, HL(9, 6)
    call PlaceString

    ; --- mon name (row 2) — GetMonName reads wNamedObjectIndex(=wPokedexNum) ----
    call GetMonName
    lea eax, [ebp + wNameBuffer]         ; PlaceString wants a FLAT source ptr
    mov esi, HL(9, 2)
    call PlaceString

    ; --- entry pointer: PokedexEntryPointers[wPokedexNum-1] (flat .data) --------
    movzx eax, byte [ebp + wPokedexNum]
    dec eax
    mov eax, [PokedexEntryPointers + eax*4]
    mov [dex_entry_ptr], eax

    ; --- species classification name (row 4) — EAX = flat entry ptr -------------
    mov esi, HL(9, 4)
    call PlaceString                     ; entry+0 = '@'-terminated name

    ; --- № + national dex number (row 8) ---------------------------------------
    mov byte [ebp + HL(2, 8)], GLYPH_NO  ; '№'
    mov byte [ebp + HL(3, 8)], GLYPH_DOT ; '<DOT>'
    movzx eax, byte [ebp + wPokedexNum]  ; internal index
    mov [saved_pokedexnum], al
    dec eax
    movzx eax, byte [IndexToPokedex + eax] ; port: table read (pret: predef IndexToPokedex)
    mov [ebp + wPokedexNum], al          ; wPokedexNum := dex# (for PrintNumber + owned bit)
    mov edx, wPokedexNum
    mov bh, (1 << BIT_LEADING_ZEROES) | 1 ; LEADING_ZEROES | 1 byte
    mov bl, 3                            ; 3 digits
    mov esi, HL(4, 8)                    ; № and <DOT> consumed cols 2,3 (pret hli)
    call PrintNumber

    ; --- owned? (bit dex#-1 in wPokedexOwned) ----------------------------------
    mov esi, wPokedexOwned               ; ld hl, wPokedexOwned
    call IsPokemonBitSet                 ; reads wPokedexNum(=dex#); AL/BL = owned
    mov [saved_owned], al
    mov al, [saved_pokedexnum]
    mov [ebp + wPokedexNum], al          ; restore internal index
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wCurSpecies], al          ; ld a,[wCurPartySpecies] / ld [wCurSpecies],a

    ; --- front pic at (1,1) ----------------------------------------------------
    call Delay3
    call GBPalNormal
    call GetMonHeader                    ; load pokemon picture location
    ; PROJ: front pic → VRAM $9000 (GB_VCHARS2), the verified battle front-pic dest
    ; (signed tile addressing maps tile id $00 → $9000).
    mov edx, GB_VCHARS2
    call LoadFlippedFrontSpriteByMonIndex ; decode → VRAM (49 tiles)
    call dex_place_pic                    ; place the 7×7 tile ids at HL(1,1), stride 20
    ; ld a,[wCurPartySpecies] / call PlayCry — TODO-HW: audio HAL (Phase 3). No-op.

    ; --- owned gate (pret: ld a,c / and a / ret z) -----------------------------
    mov al, [saved_owned]
    test al, al                           ; and a  (clears CF)
    jnz .owned
    ; unowned: no height/weight/flavor. Show the page (border/name/№/pic) as-is.
    call dex_show_window                  ; port: mirror scratch + show window (before CF)
    clc                                   ; unowned: CF=0 → caller skips the flavor
    ret

.owned:
    ; scan the flat entry blob for the name terminator '@' → field offsets:
    ;   feet=@+1, inches=@+2, weight_lo=@+3, weight_hi=@+4, flavor=@+5.
    ; (Port note: pret walks these via DE through PrintNumber, which on the GB
    ; leaves DE=source-1 for a 1-byte value / net-0 for a 2-byte value so the
    ; inc-de chain lands right; the port's PrintNumber clobbers EDX, so the field
    ; addresses are computed here by scanning instead. EDI is preserved by
    ; PrintNumber, so it holds the '@' pointer across the calls.)
    mov edi, [dex_entry_ptr]
.scan_at:
    cmp byte [edi], 0x50                  ; '@'
    je .found_at
    inc edi
    jmp .scan_at
.found_at:
    ; --- feet (12,6) : PrintNumber 1 byte / 2 digits, then '′' ------------------
    movzx eax, byte [edi + 1]             ; feet (read; pret reads it too, unused value)
    mov [ebp + hDexWeight], al            ; stage into GB scratch for PrintNumber
    mov edx, hDexWeight
    mov bh, 1
    mov bl, 2
    mov esi, HL(12, 6)
    call PrintNumber                      ; ESI → HL(14,6)
    mov byte [ebp + esi], GLYPH_FEET      ; ld [hl], '′'
    ; --- inches (15,6) : LEADING_ZEROES|1 byte / 2 digits, then '″' -------------
    movzx eax, byte [edi + 2]             ; inches
    mov [ebp + hDexWeight], al
    mov edx, hDexWeight
    mov bh, (1 << BIT_LEADING_ZEROES) | 1
    mov bl, 2
    mov esi, HL(15, 6)
    call PrintNumber                      ; ESI → HL(17,6)
    mov byte [ebp + esi], GLYPH_INCHES    ; ld [hl], '″'
    ; --- weight (11,8) : big-endian into hDexWeight, 2 bytes / 5 digits ---------
    ; DEVIATION: pret save/restores the pre-existing hDexWeight bytes (politeness
    ; for a shared HRAM byte). hDexWeight is a port-local dex scratch with no other
    ; reader in this window, so the save/restore is dropped.
    movzx eax, byte [edi + 4]             ; weight upper byte
    mov [ebp + hDexWeight + 0], al        ; big-endian: [0]=upper
    movzx eax, byte [edi + 3]             ; weight lower byte
    mov [ebp + hDexWeight + 1], al        ; [1]=lower
    mov edx, hDexWeight
    mov bh, 2
    mov bl, 5
    mov esi, HL(11, 8)
    call PrintNumber
    ; --- decimal point: weight is tenths of pounds -----------------------------
    ; if weight < 10, put a '0' before the decimal point (pret's 16-bit compare).
    mov al, [ebp + hDexWeight + 1]        ; ldh a,[hDexWeight+1]
    sub al, 10                            ; sub 10
    mov al, [ebp + hDexWeight + 0]        ; ldh a,[hDexWeight]  (mov preserves CF)
    sbb al, 0                             ; sbc 0 (SM83) → sbb (x86)
    mov esi, HL(14, 8)                    ; hlcoord 14,8  (mov preserves CF)
    jnc .decpt                            ; jr nc, .next  (weight >= 10)
    mov byte [ebp + esi], GLYPH_ZERO      ; ld [hl], '0'
.decpt:
    ; inc hl / ld a,[hli] / ld [hld],a / ld [hl],'<DOT>' — shove the tenths digit
    ; one tile right and drop the decimal point into the gap.
    inc esi                               ; → (15,8)
    mov al, [ebp + esi]                   ; a = [hli] (digit at 15,8)
    inc esi                               ; hl → (16,8)
    mov [ebp + esi], al                   ; ld [hld],a → (16,8) = digit
    dec esi                               ; hl → (15,8)
    mov byte [ebp + esi], GLYPH_DOT       ; ld [hl], '<DOT>'
    ; --- flavor pointer = @+5 (pret: pop hl / inc hl) --------------------------
    lea eax, [edi + 5]
    mov [dex_flavor_ptr], eax
    ; port: HT/WT is now in the scratch — show the full page (mirror + window). The
    ; flavor path (if the caller runs it on CF=1) re-mirrors after TextCommandProcessor.
    call dex_show_window
    stc                                   ; scf → CF=1 = "print the flavor"
    ret

; ===========================================================================
; Pokedex_PrintFlavorTextAtRow11 / …AtBC — pret ref: pokedex.asm.
; Print the flavor description via TextCommandProcessor.
; ===========================================================================
Pokedex_PrintFlavorTextAtRow11:
    mov ebx, HL(1, 11)                    ; bccoord 1,11 (dest cursor for TCP)
Pokedex_PrintFlavorTextAtBC:
    ; DEVIATION: pret's flavor is a far-bank text run (text_far); the port data
    ; inlines it into the entry blob. TextCommandProcessor is EBP-relative but the
    ; blob is flat .data, so the flavor stream is staged into GB space first.
    call dex_stage_flavor                 ; [dex_flavor_ptr] → wDexFlavorBuf; ESI=GB off
    mov byte [ebp + H_CLEAR_LETTER_PRINTING_DELAY_FLAGS], 0x02  ; ld a,%10 (clear delay)
    call TextCommandProcessor             ; ESI=stream, EBX=cursor
    mov byte [ebp + H_CLEAR_LETTER_PRINTING_DELAY_FLAGS], 0     ; xor a
    call dex_mirror                       ; port: push the finished flavor to the window
    ret

; ===========================================================================
; Pokedex_PrepareDexEntryForPrinting — pret ref: pokedex.asm.
; The GB-Printer entry layout (13-row box). DEVIATION(out-of-scope/unused): the
; only caller is the printer path (PrintPokedexEntry), which menus scope does not
; port; kept for label parity. Draws into the stride-20 scratch and runs the
; flavor with <PAGE> forced to <NEXT> (BIT_PAGE_CHAR_IS_NEXT).
; ===========================================================================
Pokedex_PrepareDexEntryForPrinting:
    mov esi, HL(0, 0)                     ; hlcoord 0,0
    mov edx, GBSCR_W                      ; ld de, SCREEN_WIDTH (vertical)
    mov bh, 0x66
    mov bl, 0x0D                          ; lb bc, $66, $d
    call DrawTileLine
    mov esi, HL(19, 0)                    ; hlcoord 19,0
    mov edx, GBSCR_W
    mov bh, 0x67
    mov bl, 0x0D
    call DrawTileLine
    mov esi, HL(0, 13)                    ; hlcoord 0,13
    mov edx, 1                            ; ld de, $1 (horizontal)
    mov bh, 0x6F
    mov bl, GBSCR_W                       ; lb bc, $6f, SCREEN_WIDTH
    call DrawTileLine
    mov byte [ebp + HL(0, 13)],  0x6C     ; ldcoord_a 0,13
    mov byte [ebp + HL(19, 13)], 0x6E     ; ldcoord_a 19,13
    ; ld a,[wPrinterPokedexEntryTextPointer] / ld l,a / ld h,a+1 — printer text ptr.
    ; DEVIATION(out-of-scope): in the port the flavor is flat .data reached via
    ; dex_flavor_ptr; this printer pointer is never populated in menus scope.
    mov ebx, HL(1, 1)                     ; bccoord 1,1
    or byte [ebp + H_UI_LAYOUT_FLAGS], 1 << BIT_PAGE_CHAR_IS_NEXT
    call Pokedex_PrintFlavorTextAtBC
    and byte [ebp + H_UI_LAYOUT_FLAGS], (~(1 << BIT_PAGE_CHAR_IS_NEXT)) & 0xFF
    ret

; ===========================================================================
; Port plumbing (window compositor + flat→GB staging). Not pret routines.
; ===========================================================================

; ---------------------------------------------------------------------------
; dex_place_pic — write the 7×7 front-pic tile ids into the stride-20 scratch at
; HL(1,1), column-major starting at tile id $00 (port of CopyUncompressedPicToHL /
; PlacePicTilemap, re-strided from the 40-wide battle canvas to the 20-wide dex
; scratch). Preserves all registers.
; SPIKE NOTE: whether these tile ids composite as the mon picture in the menu
; window depends on the window renderer's tile-data addressing mode (see report).
; ---------------------------------------------------------------------------
dex_place_pic:
    pushad
    lea edi, [ebp + HL(1, 1)]             ; dest = (1,1)
    xor bl, bl                            ; running tile id ($00…)
    mov ecx, 7                            ; 7 columns
.col:
    push edi
    push ecx
    mov ecx, 7                            ; 7 rows
    mov al, bl
.row:
    mov [edi], al
    add edi, GBSCR_W                      ; down one row (stride 20)
    inc al
    dec ecx
    jnz .row
    mov bl, al                            ; next column continues the id sequence
    pop ecx
    pop edi
    inc edi                               ; next column to the right
    dec ecx
    jnz .col
    popad
    ret

; ---------------------------------------------------------------------------
; dex_stage_flavor — copy the flat flavor stream at [dex_flavor_ptr] into GB
; scratch (wDexFlavorBuf), stopping after the first $50 (TX_END). Out: ESI =
; wDexFlavorBuf (GB offset, for TextCommandProcessor). Clobbers EAX/ECX/EDX/EDI.
; ---------------------------------------------------------------------------
dex_stage_flavor:
    mov edx, [dex_flavor_ptr]             ; flat source
    lea edi, [ebp + wDexFlavorBuf]        ; GB-space dest (flat)
    mov ecx, DEX_FLAVOR_MAX
.copy:
    mov al, [edx]
    mov [edi], al
    inc edx
    inc edi
    cmp al, 0x50                          ; TX_END terminator (also '@' — first one wins)
    je .done
    dec ecx
    jnz .copy
.done:
    mov esi, wDexFlavorBuf                ; GB offset for TCP ([ebp+esi])
    ret

; ---------------------------------------------------------------------------
; dex_mirror — blit the stride-20 scratch rows 0-17 → GB_TILEMAP1 rows 0-17 (the
; window's source; stand-in for the hAutoBGTransferEnabled transfer, exactly like
; options_mirror). Preserves all registers.
; ---------------------------------------------------------------------------
dex_mirror:
    pushad
    xor ebx, ebx
.row:
    imul esi, ebx, GBSCR_W
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                            ; ×32 tilemap stride
    lea edi, [ebp + edi + GB_TILEMAP1]
    mov ecx, GBSCR_W
    rep movsb
    inc ebx
    cmp ebx, UI_POKEDEX_ENTRY_GBH         ; 18 rows
    jb .row
    popad
    ret

; ---------------------------------------------------------------------------
; dex_show_window — mirror + expose the scratch as the single full-screen window
; at UI_POKEDEX_ENTRY_*, over the whited-out overworld. Preserves all registers.
; ; PROJ menus: window = UI_POKEDEX_ENTRY_(WX,WY,CLIP,MAXY).
; ---------------------------------------------------------------------------
dex_show_window:
    pushad
    call dex_mirror
    mov dword [g_bg_whiteout], 1          ; dex page is a full takeover
    mov eax, UI_POKEDEX_ENTRY_WX
    mov ebx, UI_POKEDEX_ENTRY_WY
    mov ecx, UI_POKEDEX_ENTRY_CLIP
    mov edx, UI_POKEDEX_ENTRY_MAXY
    mov esi, GB_TILEMAP1
    xor edi, edi                          ; start_row = 0
    call set_single_window
    popad
    ret

; ===========================================================================
; DEBUG_G2 harness — RunPokedexEntryTest. Seeds a seen+owned mon (RHYDON, internal
; index 1 → national dex 112), draws the data page + front pic, dumps FRAME.BIN.
; The flavor is intentionally skipped: its <PAGE> break blocks on an A/B press,
; which is the S10 interactive pass. Root wires DEBUG_G2 + the EnterMap call site.
; ===========================================================================
%ifdef DEBUG_G2
section .text
RunPokedexEntryTest:
    mov byte [ebp + wPokedexNum], 1       ; RHYDON internal index (→ dex 112)
    mov byte [ebp + wCurPartySpecies], 1
    ; mark RHYDON (dex 112) seen+owned: bit 111 → byte 13, bit 7 of wPokedexOwned
    or byte [ebp + wPokedexOwned + 13], 1 << 7
    ; font + dex tileset ($60-$6f) into VRAM
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadPokedexTilePatterns
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0
    call DrawDexEntryOnScreen             ; page + pic + window (CF = owned)
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer                    ; writes FRAME.BIN + exits
.hang:
    jmp .hang
%endif
