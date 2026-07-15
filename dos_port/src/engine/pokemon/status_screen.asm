; status_screen.asm — the Pokémon status / summary screen.
;
; Faithful port of pret engine/pokemon/status_screen.asm:
;   StatusScreen (page 1: name/level/HP/status/types/№/OT/ID/pic/cry),
;   DrawHP/DrawHP_ (HP bar), DrawLineBox, PrintStatsBox' status-box branch,
;   PrintMonType, PrintLevel, .GetStringPointer, and CalcExpToLevelUp.
;   StatusScreen2 (page 2) is TODO (next session).
;
; PROJECTION (PROJ status-screen): the port renders the 20×18 GB screen centered
; in the 40×25 widescreen BG canvas (W_TILEMAP), exactly as the battle screen does
; (init_battle flat-canvas path, PrintStatsBox.LevelUpStatsBox in battle_menu.asm).
; GB(x,y) → canvas offset (y+3)*40 + (x+10). scoord() below is that map; the +10/+3
; centers 20 cols in 40 and 18 rows in 25. Row-stride math inside routines uses FW
; (=40), and pret's SCREEN_WIDTH*n vertical steps become FW*n.
;
; Multi-byte GB mon values (HP, MaxHP, stats, OTID) are big-endian; PrintNumber now
; reads big-endian (matches pret — see home/print_num.asm / CLAUDE.md "Data
; Endianness"), so they are passed to it directly, no swap.
;
; Build: nasm -f coff -I include/ -I . -o status_screen.o status_screen.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

%define FW SCREEN_WIDTH                               ; 40 — W_TILEMAP row stride
%define scoord(x,y) (W_TILEMAP + ((y)+3)*FW + ((x)+10))

; --- tile ids (charmap.asm + HpBarAndStatus/BattleHud tile sets) --------------
T_SPACE     equ 0x7F
T_SLASH     equ 0xF3      ; '/'
T_DOT       equ 0xF2      ; '<DOT>' decimal point
T_NO        equ 0x74      ; '№'
T_ID        equ 0x73      ; '<ID>'
T_LV        equ 0x6E      ; ':L' level prefix ('<LV>')
T_BOLD_P    equ 0x72      ; '<BOLD_P>' bold P for "PP" (gfx/font/P.1bpp)
T_TO        equ 0x70      ; '<to>' narrow "to"
T_DASH      equ 0xE3      ; '-' (charmap; blank-move PP placeholder)
CHAR_ZERO_  equ 0xF6      ; '0'
; HP gauge (HpBarAndStatus set, loaded over $62+ by LoadHpBarAndStatusTilePatterns)
HPB_HP      equ 0x71      ; "HP:" narrow label
HPB_LEFT    equ 0x62      ; gauge left edge
HPB_EMPTY   equ 0x63      ; empty segment; $63+n = n-pixel partial
HPB_FULL    equ 0x6B      ; full (8px) segment
HPB_CAP     equ 0x6D      ; status/battle right cap (wHPBarType==1)
; DrawLineBox pieces (BattleHudTiles, loaded by LoadHudTilePatterns)
LB_VLINE    equ 0x78      ; │
LB_CORNER   equ 0x77      ; ┘
LB_HLINE    equ 0x76      ; ─
LB_ARROW    equ 0x6F      ; ← (halfarrow ending)

SECTION .data
align 4

; Status-screen PlaceString label strings (TypesIDNoOTText, StatusText, OKText,
; StatsText, StatusScreenExpText). pret keeps these as file-inline db/next data;
; the port generates them (charmap-encoded) per the two-tier rule — see
; tools/gen_status_strings.py. DO NOT hand-edit the .inc.
%include "assets/status_strings.inc"

; Name / OT pointer tables — 16-bit GB offsets (pret dw). Indexed by wMonDataLocation.
; NOT generated: these are port-specific WRAM-offset pointer tables (like a jump
; table), kept hand-written per the two-tier rule (code, not data).
OTPointers:
    dw wPartyMonOT, wEnemyMonOT, wBoxMonOT, wDayCareMonOT
NamePointers2:
    dw wPartyMonNicks, wEnemyMonNicks, wBoxMonNicks, wDayCareMonName

SECTION .text

global StatusScreen
global StatusScreen2
; NOTE: DrawHP is intentionally file-LOCAL here (no `global`). pret has a single
; DrawHP in engine/pokemon/status_screen.asm, but the port needs two because of
; the tilemap-stride divergence: this self-contained copy targets the 40-wide
; status canvas (fraction at +FW+1), while the party menu's global DrawHP/DrawHP2/
; DrawHP_ family (src/engine/menus/party_menu.asm) targets the stride-20 scratch.
; Both keep pret's name (CLAUDE.md "Preserve pret Labels" port-split rule); only
; the party-menu one is global. status_screen's `call DrawHP` binds to this local.
global DrawLineBox
global PrintMonType
global CalcExpToLevelUp

; data / stat helpers (all linked)
extern LoadMonData
extern CalcStats
extern CalcExperience
extern PrintNumber
extern PlaceString
extern PrintStatusCondition
extern SkipFixedLengthTextEntries
extern IndexToPokedex                                ; data table (internal idx → dex)
extern WideTypeNames                                 ; data table (type id*4 → name ptr)
extern GetHealthBarColor
extern RunPaletteCommand                             ; palette Phase 5 (no-op)
; screen / frame helpers
extern GBPalWhiteOutWithDelay3
extern GBPalNormal
extern ClearScreen
extern UpdateSprites
extern hide_window
extern LoadHpBarAndStatusTilePatterns
extern LoadStatusScreenHudTilePatterns               ; load_font.asm — pret's 4-load status HUD layout
extern LoadFlippedFrontSpriteByMonIndex              ; gfx/pics.asm — ESI=tilemap coord; decode $9000 + place
extern g_bg_whiteout                                 ; ppu/ppu.asm — full-screen BG whiteout flag
extern IsThisPartyMonStarterPikachu                  ; engine/pikachu/pikachu_status.asm (CF = starter)
extern IsThisBoxMonStarterPikachu                    ; engine/pikachu/pikachu_status.asm
extern PlayPikachuSoundClip                          ; engine/pikachu/pikachu_pcm.asm (DL = clip index)
extern WaitForTextScrollButtonPress
extern spr_oam_valid                                 ; ppu.asm — render_sprites active-entry count
extern Delay3
extern text_row_stride                               ; text.asm — engine row stride
; page 2 (StatusScreen2)
extern FillMemory
extern CopyData
extern FormatMovesString
extern ClearScreenArea
extern GetMonName
extern GetMaxPP
extern GBPalWhiteOut
%ifdef DEBUG_STATUS
extern DelayFrame
extern DumpBackbuffer
%endif

; ---------------------------------------------------------------------------
; StatusScreen — draw the summary screen page 1 for the mon at
; [wWhichPokemon] in list [wMonDataLocation]. Waits for A/B, then returns.
; ---------------------------------------------------------------------------
StatusScreen:
    call LoadMonData
    mov al, [ebp + wMonDataLocation]
    cmp al, BOX_DATA
    jb .DontRecalculate                              ; party/enemy: stats already computed
    ; mon is in a box or daycare → recompute stats from stat-exp
    mov al, [ebp + wLoadedMonBoxLevel]
    mov [ebp + wLoadedMonLevel], al
    mov [ebp + wCurEnemyLevel], al
    mov esi, wLoadedMonHPExp - 1
    mov edx, wLoadedMonStats
    mov bl, 1
    call CalcStats
.DontRecalculate:
    or byte [ebp + W_STATUS_FLAGS_2], (1 << BIT_NO_AUDIO_FADE_OUT)   ; set BIT_NO_AUDIO_FADE_OUT
    ; TODO-HW: audio HAL (Phase 3) — ld a,$33 / ldh [rAUDVOL],a (reduce volume).
    ; Disable sprite updates BEFORE the whiteout/clear DelayFrames. On the GB,
    ; DelayFrame only DMAs the existing shadow OAM; the port's update_oam instead
    ; rebuilds it via PrepareOAMData whenever W_UPDATE_SPRITES_ENABLED==1, so the
    ; frames inside GBPalWhiteOutWithDelay3/ClearScreen would re-populate the
    ; overworld player+NPC sprites into OAM (the caller's ClearSprites having just
    ; emptied it) and render_sprites would composite them over the status screen.
    ; Zeroing it here (not after the frames, as before) keeps OAM clear. pret is
    ; immune because its DelayFrame never calls PrepareOAMData.
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    call UpdateSprites
    ; Suppress all OBJ sprites on this flat-canvas screen. render_sprites does NOT count
    ; entries from the OAM Y bytes — it draws spr_oam_valid entries using the spr_dos_sy/sx
    ; position tables and reads only tile/attr from $FE00 (PrepareOAMData publishes all
    ; three). With sprite updates disabled PrepareOAMData never runs, so those tables keep
    ; the overworld's stale count+positions; because this screen clears g_bg_whiteout
    ; (below) render_sprites is NOT skipped and would ghost the overworld player+NPCs (all
    ; reading whatever tile the OAM holds). Zero the published count so render_sprites skips
    ; every entry. On return to the field PrepareOAMData republishes it (flag re-enabled),
    ; so the overworld is unaffected.
    mov dword [spr_oam_valid], 0

    ; --- PORT: flat-canvas render setup (mirror init_battle) so render_bg shows
    ; W_TILEMAP directly and PlaceString steps rows by FW (40) --------------------
    mov word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], 0
    mov byte [ebp + H_SCX], 0                         ; zero the SHADOWS too — commit_shadow_regs
    mov byte [ebp + H_SCY], 0                         ; copies them over IO_SCX/SCY each DelayFrame,
    mov byte [ebp + IO_SCX], 0                        ; so the overworld scroll would otherwise be
    mov byte [ebp + IO_SCY], 0                        ; restored and drag the flat canvas off-screen
    ; (W_UPDATE_SPRITES_ENABLED already zeroed above, before the whiteout frames)
    mov dword [text_row_stride], FW                  ; 40 (restored to 20 by caller / battle_menu)
    ; The party menu (our caller) sets g_bg_whiteout=1 to blank the BG behind its
    ; window; clear it so render_bg draws the flat status canvas instead of a full
    ; white-out (ppu.asm early-return). Battle doesn't need this — it enters from the
    ; overworld with the flag already 0. Applies to both pages (StatusScreen2 reuses
    ; this setup).
    mov dword [g_bg_whiteout], 0
    call hide_window

    ; --- tile patterns: HP-bar/status/":L" ($62-$7F incl. № $74 / <ID> $73), then the
    ; HUD frame/line/P pieces. LoadStatusScreenHudTilePatterns mirrors pret's four
    ; CopyVideoDataDouble(BattleHudTiles1/2/3, PTile) to the DISCONTIGUOUS slots
    ; $6d-$6f / $78 / $76-$77 / $72 — deliberately NOT the battle bundle's $73-$78,
    ; which would clobber the № / <ID> font glyphs this screen prints. --------------
    call LoadHpBarAndStatusTilePatterns
    call LoadStatusScreenHudTilePatterns
    ; Disable BG tile animations (pret: ldh a,[hTileAnimations]/push af/xor a/
    ; ldh [hTileAnimations],a). UpdateMovingBgTiles animates VRAM tiles $03/$14 every
    ; DelayFrame; on this screen those slots hold the mon front pic ($9000+), so
    ; without this the pic's own tiles cycle (the "Pikachu foot animates like water"
    ; bug). Restored after the button-wait so it stays off while the screen shows.
    mov al, [ebp + hTileAnimations]
    mov [ss_saved_tileanim], al
    mov byte [ebp + hTileAnimations], 0

    ; --- name / HP / status box (DrawLineBox 19,1 6×10) ---
    mov esi, scoord(19, 1)
    mov bh, 6
    mov bl, 10
    call DrawLineBox
    ; the "№" marker before the pokédex number. pret: DrawLineBox leaves hl at the box's
    ; lower-left arrow — GB(8,7); ld de,-6/add hl → GB(2,7)='<DOT>', dec hl → GB(1,7)='№'.
    ; So № at (1,7), <DOT> at (2,7), and the number prints at (3,7) below → "№.025".
    ; (The old scoord(19,1)+6*FW-6 form omitted DrawLineBox's horizontal traversal and
    ; landed the marker ~12 cols too far right, at GB(13,7) — the stray "№." seen floating
    ; near the level-up bar on page 2, which reuses this canvas.)
    mov byte [ebp + scoord(1, 7)], T_NO
    mov byte [ebp + scoord(2, 7)], T_DOT

    ; --- types / ID / OT box (DrawLineBox 19,9 8×6) + labels ---
    mov esi, scoord(19, 9)
    mov bh, 8
    mov bl, 6
    call DrawLineBox
    mov esi, scoord(10, 9)
    mov eax, TypesIDNoOTText
    call PlaceString

    ; --- HP bar at (11,3) ---
    mov esi, scoord(11, 3)
    call DrawHP                                      ; leaves DL = HP-bar pixel length
    mov esi, wStatusScreenHPBarColor
    call GetHealthBarColor                           ; cosmetic (palette Phase 5)
    mov bh, SET_PAL_STATUS_SCREEN
    call RunPaletteCommand                           ; no-op (Phase 5)

    ; --- status condition at (16,6), else "OK" ---
    mov esi, scoord(16, 6)
    mov edx, wLoadedMonStatus
    call PrintStatusCondition                        ; ZF set iff nothing written
    jnz .StatusWritten
    mov esi, scoord(16, 6)
    mov eax, OKText
    call PlaceString
.StatusWritten:
    mov esi, scoord(9, 6)
    mov eax, StatusText
    call PlaceString

    ; --- level at (14,2) ---
    mov esi, scoord(14, 2)
    call StatusScreen_PrintLevel

    ; --- pokédex number at (3,7): wPokedexNum = IndexToPokedex[wMonHIndex] ---
    mov al, [ebp + wMonHIndex]
    mov [ebp + wPokedexNum], al
    mov [ebp + wCurSpecies], al
    ; predef IndexToPokedex (data table lookup in the port)
    movzx eax, byte [ebp + wMonHIndex]
    dec eax
    movzx eax, byte [IndexToPokedex + eax]
    mov [ebp + wPokedexNum], al
    mov esi, scoord(3, 7)
    mov edx, wPokedexNum
    mov bh, LEADING_ZEROES | 1                        ; flags | 1 byte
    mov bl, 3
    call PrintNumber

    ; --- types at (11,10) ---
    mov esi, scoord(11, 10)
    call PrintMonType

    ; --- name at (9,1) ---
    mov eax, NamePointers2
    call .GetStringPointer                            ; ESI = source GB offset
    lea eax, [ebp + esi]                              ; flat src for PlaceString
    mov esi, scoord(9, 1)
    call PlaceString

    ; --- OT name at (12,16) ---
    mov eax, OTPointers
    call .GetStringPointer
    lea eax, [ebp + esi]
    mov esi, scoord(12, 16)
    call PlaceString

    ; --- ID number at (12,14) ---
    mov esi, scoord(12, 14)
    mov edx, wLoadedMonOTID
    mov bh, LEADING_ZEROES | 2                        ; flags | 2 bytes (big-endian)
    mov bl, 5
    call PrintNumber

    ; --- stats box (status-screen variant, pret PrintStatsBox d=0) ---
    call StatusScreen_StatsBox

    call Delay3
    call GBPalNormal

    ; --- front pic (pret: hlcoord 1,0 / call LoadFlippedFrontSpriteByMonIndex) ---
    ; The loader now decodes to $9000 AND places the 7×7 block itself (flip-aware),
    ; using text_row_stride (= FW here, the flat status canvas). Just set the coord.
    mov esi, scoord(1, 0)
    call LoadFlippedFrontSpriteByMonIndex

    ; --- cry (pret: starter Pikachu → digitized clip, anything else → PlayCry) ---
    mov al, [ebp + wMonDataLocation]
    cmp al, ENEMY_PARTY_DATA
    je .playRegularCry
    cmp al, BOX_DATA
    je .checkBoxData
    call IsThisPartyMonStarterPikachu
    jnc .playRegularCry
    jmp .playPikachuSoundClip
.checkBoxData:
    call IsThisBoxMonStarterPikachu
    jnc .playRegularCry
.playPikachuSoundClip:
    mov dl, 16                                       ; pret: ldpikacry e, PikachuCry17
    call PlayPikachuSoundClip
    jmp .continue
.playRegularCry:
    ; TODO-HW: pret plays [wCurPartySpecies] via PlayCry — synth-cry translation
    ; is deferred (audio plan, Phase A leftovers).
.continue:

%ifdef DEBUG_STATUS
  %ifdef DEBUG_STATUS_PAGE2
    mov al, [ss_saved_tileanim]                      ; restore anims (page-2 harness continues to StatusScreen2)
    mov [ebp + hTileAnimations], al
    ret                                              ; page-2 harness: return so it can call StatusScreen2
  %else
    call DelayFrame                                  ; render the finished canvas
    call DumpBackbuffer                              ; FRAME.BIN + exit (never returns)
  %endif
%endif
    call WaitForTextScrollButtonPress
    mov al, [ss_saved_tileanim]                      ; restore BG tile animations (pret: pop af)
    mov [ebp + hTileAnimations], al
    ret

; .GetStringPointer — pret StatusScreen.GetStringPointer.
; In:  EAX = flat ptr to a 4-entry dw table (NamePointers2 / OTPointers).
; Out: ESI = GB offset of the [wWhichPokemon] entry's name (daycare: no skip).
;      Clobbers EAX/EBX/ECX.
.GetStringPointer:
    movzx ecx, byte [ebp + wMonDataLocation]
    add ecx, ecx                                     ; location * 2
    movzx esi, word [eax + ecx]                      ; ESI = table[location] (GB offset)
    cmp byte [ebp + wMonDataLocation], DAYCARE_DATA
    je .gsp_done
    mov al, [ebp + wWhichPokemon]
    call SkipFixedLengthTextEntries                  ; ESI += AL * NAME_LENGTH
.gsp_done:
    ret

; ---------------------------------------------------------------------------
; DrawLineBox — pret DrawLineBox. Draw a line box: BH tall down, then BL wide left.
; In: ESI = start canvas offset, BH = height, BL = width.
; ---------------------------------------------------------------------------
DrawLineBox:
.vline:
    mov byte [ebp + esi], LB_VLINE                   ; │
    add esi, FW
    dec bh
    jnz .vline
    mov byte [ebp + esi], LB_CORNER                  ; ┘
    dec esi
.hline:
    mov byte [ebp + esi], LB_HLINE                   ; ─
    dec esi
    dec bl
    jnz .hline
    mov byte [ebp + esi], LB_ARROW                   ; ← (halfarrow ending)
    ret

; ---------------------------------------------------------------------------
; DrawHP — pret DrawHP_ for the status screen (wHPBarType == 1: cap $6d, fraction
; drawn BELOW the bar). Reads wLoadedMonHP/MaxHP (big-endian). Draws a 6-segment
; gauge at ESI + "cur/max" one row below.
; In:  ESI = canvas offset of the bar. Out: DL = bar pixel length (for
;      GetHealthBarColor). Preserves nothing meaningful else.
; ---------------------------------------------------------------------------
DrawHP:
    push esi                                         ; save bar position
    ; curHP → EBX (big-endian), pixel length → EDX
    movzx eax, byte [ebp + wLoadedMonHP]             ; hi
    shl eax, 8
    mov al, [ebp + wLoadedMonHP + 1]                 ; lo → EAX = curHP
    test eax, eax
    jnz .nonzeroHP
    ; fainted: 0-length bar, no sliver
    xor edx, edx                                     ; pixels = 0
    jmp .drawBar
.nonzeroHP:
    ; pixels = curHP*48 / maxHP, at least 1 (pret GetHPBarLength)
    imul eax, eax, 48
    movzx ecx, byte [ebp + wLoadedMonMaxHP]          ; hi
    shl ecx, 8
    mov cl, [ebp + wLoadedMonMaxHP + 1]              ; lo → ECX = maxHP
    ; BUG(cosmetic): pret GetHPBarLength ÷4's both curHP*48 and maxHP when maxHP>=256
    ; before an 8-bit divide (lossy). Preserved to match pret (see battle_hud.asm).
%if BUG_FIX_LEVEL < 2
    cmp ecx, 256
    jb .exactDiv
    shr eax, 2
    shr ecx, 2
.exactDiv:
%endif
    xor edx, edx
    div ecx
    test eax, eax
    jnz .havePixels
    mov eax, 1                                       ; alive → at least 1 pixel
.havePixels:
    mov edx, eax                                     ; EDX = pixel length
.drawBar:
    pop esi                                          ; ESI = bar position
    push edx                                         ; save pixel length (for GetHealthBarColor)
    ; --- draw gauge (pret DrawHPBar, d=6 segments, status cap) ---
    mov byte [ebp + esi], HPB_HP                     ; "HP:"
    mov byte [ebp + esi + 1], HPB_LEFT               ; gauge left edge
    mov byte [ebp + esi + 8], HPB_CAP                ; right cap (status/battle)
    lea edi, [esi + 2]                               ; first of 6 gauge segments
    mov ecx, 6
.seg:
    cmp edx, 8
    jb .partial
    mov byte [ebp + edi], HPB_FULL
    sub edx, 8
    jmp .segNext
.partial:
    lea eax, [edx + HPB_EMPTY]                        ; $63 + n-pixel partial
    mov [ebp + edi], al
    xor edx, edx                                     ; rest stays empty
.segNext:
    inc edi
    dec ecx
    jnz .seg
    ; --- "cur/max" one row below the bar (pret .printFractionBelowBar: +SCREEN_WIDTH+1) ---
    lea esi, [esi + FW + 1]
    mov edx, wLoadedMonHP
    mov bh, 2                                         ; 2 bytes (big-endian)
    mov bl, 3                                         ; 3 digits
    call PrintNumber
    mov byte [ebp + esi], T_SLASH
    inc esi
    mov edx, wLoadedMonMaxHP
    mov bh, 2
    mov bl, 3
    call PrintNumber
    pop edx                                          ; DL = pixel length (GetHealthBarColor)
    ret

; ---------------------------------------------------------------------------
; PrintLevel — pret home/pokemon.asm PrintLevel: ":L" + 2 digits (<100), or 3
; digits overwriting ":L" (>=100). In: ESI = dest canvas offset.
; ---------------------------------------------------------------------------
StatusScreen_PrintLevel:
    mov byte [ebp + esi], T_LV                       ; ':L'
    inc esi
    mov bl, 2                                         ; digit count
    mov al, [ebp + wLoadedMonLevel]
    cmp al, 100
    jb .common
    dec esi                                          ; write over ':L'
    mov bl, 3
.common:
    mov edx, wLoadedMonLevel                          ; 1-byte value (endian-agnostic)
    mov bh, (1 << BIT_LEFT_ALIGN) | 1                ; LEFT_ALIGN | 1 byte
    call PrintNumber
    ret

; ---------------------------------------------------------------------------
; PrintMonType — pret engine/battle/print_type.asm PrintMonType. Prints the loaded
; mon's type name(s) from WideTypeNames. In: ESI = dest canvas offset (type1 row).
; Reads wMonHType1/2 (base-stats header, filled by LoadMonData→GetMonHeader).
; ---------------------------------------------------------------------------
PrintMonType:
    push esi                                          ; save type1 dest
    movzx ecx, byte [ebp + wMonHType1]
    mov eax, [WideTypeNames + ecx * 4]
    call PlaceString                                  ; type1 name at ESI (clobbers ESI)
    pop esi                                           ; ESI = type1 dest
    mov al, [ebp + wMonHType1]
    mov ah, [ebp + wMonHType2]
    cmp ah, al
    je .eraseType2                                    ; single type
    lea esi, [esi + FW * 2]                            ; type2 two rows down
    movzx ecx, byte [ebp + wMonHType2]
    mov eax, [WideTypeNames + ecx * 4]
    call PlaceString
    ret
.eraseType2:
    ; pret EraseType2Text: blank 6 tiles at type1 dest + $13 (the "TYPE2/" label at
    ; GB(10,11)). scoord(10,11) is that cell on the wide canvas.
    lea edi, [ebp + scoord(10, 11)]
    mov al, T_SPACE
    mov ecx, 6
    rep stosb
    ret

; ---------------------------------------------------------------------------
; StatusScreen_StatsBox — pret PrintStatsBox with d=STATUS_SCREEN_STATS_BOX (0):
; box at (0,8) 8×8 + ATTACK/DEFENSE/SPEED/SPECIAL labels & values from wLoadedMon*.
; (The d!=0 LevelUpStatsBox branch lives in battle_menu.asm's PrintStatsBox, which
; reads the party struct directly since battle stubs LoadMonData.)
; ---------------------------------------------------------------------------
StatusScreen_StatsBox:
    mov esi, scoord(0, 8)
    mov bh, 8
    mov bl, 8
    call TextBoxBorder
    ; labels at (1,9); values 5 cols right, one row down (pret .PrintStats bc=SCREEN_WIDTH+5)
    mov esi, scoord(1, 9)
    mov eax, StatsText
    call PlaceString
    ; value column start = labels + FW + 5 = one row below, 5 cols right
    mov esi, scoord(1, 9) + FW + 5
    mov edx, wLoadedMonAttack
    call .printStat
    mov edx, wLoadedMonDefense
    call .printStat
    mov edx, wLoadedMonSpeed
    call .printStat
    mov edx, wLoadedMonSpecial
    ; last stat: no advance
    mov bh, 2
    mov bl, 3
    call PrintNumber
    ret
.printStat:
    ; PrintNumber(2 bytes, 3 digits) then step two rows down (pret .PrintStat).
    push esi
    mov bh, 2                                        ; 2 bytes (big-endian)
    mov bl, 3
    call PrintNumber
    pop esi
    lea esi, [esi + FW * 2]
    ret

extern TextBoxBorder

section .bss
align 4
ss_saved_tileanim: resb 1   ; saved hTileAnimations across StatusScreen / StatusScreen2 (pret push af)
ss2_hl: resd 1          ; StatusScreen2 .PrintPP: wLoadedMonMoves cursor
ss2_de: resd 1          ; StatusScreen2 .PrintPP: PP-fraction coord cursor
ss2_b:  resd 1          ; StatusScreen2 .PrintPP: move index (0..NUM_MOVES-1)

section .text

; ---------------------------------------------------------------------------
; StatusScreen2 — summary screen page 2: moves + PP, EXP + EXP-to-next, name.
; Faithful port of pret status_screen.asm:StatusScreen2. Assumes the page-1
; canvas/tile setup is already active (called right after StatusScreen).
; ---------------------------------------------------------------------------
StatusScreen2:
    ; Disable BG tile animations (pret StatusScreen2: ldh a,[hTileAnimations]/push af/
    ; xor a/ldh [hTileAnimations],a). Page 1 restored them on exit, so re-disable here
    ; or the mon pic's tiles ($03/$14 at $9000+) animate on page 2 too. Restored after
    ; the button-wait below. hAutoBGTransferEnabled: render_bg shows W_TILEMAP directly
    ; — no torus BG transfer to gate.
    mov al, [ebp + hTileAnimations]
    mov [ss_saved_tileanim], al
    mov byte [ebp + hTileAnimations], 0
    ; wMoves[0..3] := wLoadedMonMoves; wMoves[4] := 0 (FillMemory then CopyData)
    mov esi, wMoves
    xor al, al
    mov bx, NUM_MOVES + 1
    call FillMemory                                  ; zero wMoves[0..4]
    mov esi, wLoadedMonMoves
    mov edx, wMoves
    mov bx, NUM_MOVES
    call CopyData
    call FormatMovesString                            ; wMoves → wMovesString + wNumMovesMinusOne

    mov esi, scoord(9, 2)                              ; clear under the name
    mov bh, 5
    mov bl, 10
    call ClearScreenArea
    mov byte [ebp + scoord(19, 3)], LB_VLINE          ; │ divider
    mov esi, scoord(0, 8)                             ; move container box
    mov bh, 8
    mov bl, 18
    call TextBoxBorder
    mov esi, scoord(2, 9)
    mov eax, wMovesString
    lea eax, [ebp + eax]                              ; wMovesString is GB memory → flat ptr
    call PlaceString

    ; --- PP labels: "PP" for each known move, "--" for each blank ---
    movzx eax, byte [ebp + wNumMovesMinusOne]
    inc eax
    mov cl, al                                        ; c = number of known moves
    mov bl, NUM_MOVES
    sub bl, cl                                        ; b (BL) = number of blank moves
    mov esi, scoord(11, 10)
    mov al, T_BOLD_P                                  ; $72 bold P (loaded by LoadStatusScreenHudTilePatterns)
    call StatusScreen_PrintPP                         ; ESI flows to the blank rows
    test bl, bl
    jz .InitPP
    mov cl, bl
    mov al, T_DASH
    call StatusScreen_PrintPP                         ; "--" for the blank slots
.InitPP:
    ; --- per-move current/max PP fractions at coord(14,10), stepping 2 rows ---
    mov dword [ss2_hl], wLoadedMonMoves
    mov dword [ss2_de], scoord(14, 10)
    mov dword [ss2_b], 0
.PrintPP:
    mov esi, [ss2_hl]
    movzx eax, byte [ebp + esi]                       ; move id
    inc dword [ss2_hl]                                ; hli
    test al, al
    jz .PPDone
    ; wCurrentMenuItem = b (save/restore around GetMaxPP)
    mov al, [ebp + wCurrentMenuItem]
    push eax
    mov al, [ss2_b]
    mov [ebp + wCurrentMenuItem], al
    call GetMaxPP                                     ; → wMaxPP
    pop eax
    mov [ebp + wCurrentMenuItem], al
    ; current PP = [ (post-inc move cursor) + (MON_PP-MON_MOVES-1) ] & PP_MASK
    mov esi, [ss2_hl]
    add esi, MON_PP - MON_MOVES - 1
    mov al, [ebp + esi]
    and al, PP_MASK
    mov [ebp + wStatusScreenCurrentPP], al
    ; print "cur/max" at the fraction coord
    mov esi, [ss2_de]
    mov edx, wStatusScreenCurrentPP
    mov bh, 1
    mov bl, 2
    call PrintNumber
    mov byte [ebp + esi], T_SLASH
    inc esi
    mov edx, wMaxPP
    mov bh, 1
    mov bl, 2
    call PrintNumber
    add dword [ss2_de], FW * 2                        ; next fraction row (2 down)
    inc byte [ss2_b]
    mov al, [ss2_b]
    cmp al, NUM_MOVES
    jne .PrintPP
.PPDone:
    ; --- EXP labels + "to L<next>" + EXP + EXP-to-next ---
    mov esi, scoord(9, 3)
    mov eax, StatusScreenExpText
    call PlaceString
    mov al, [ebp + wLoadedMonLevel]
    push eax                                          ; save real level
    cmp al, MAX_LEVEL
    jz .Level100
    inc al
    mov [ebp + wLoadedMonLevel], al                   ; temp +1 (level of next)
.Level100:
    mov byte [ebp + scoord(14, 6)], T_TO              ; "to"
    mov esi, scoord(16, 6)                            ; hl += 2
    call StatusScreen_PrintLevel
    pop eax
    mov [ebp + wLoadedMonLevel], al                   ; restore real level
    mov esi, scoord(12, 4)                            ; current EXP (3 bytes, big-endian)
    mov edx, wLoadedMonExp
    mov bh, 3
    mov bl, 7
    call PrintNumber
    call CalcExpToLevelUp                             ; wLoadedMonExp := exp to next level
    mov esi, scoord(7, 6)
    mov edx, wLoadedMonExp
    mov bh, 3
    mov bl, 7
    call PrintNumber

    ; --- redraw the name (clears JPN diacritics; harmless here) ---
    mov esi, scoord(9, 0)
    call StatusScreen_ClearName
    mov esi, scoord(9, 1)
    call StatusScreen_ClearName
    mov al, [ebp + wMonHIndex]
    mov [ebp + wNamedObjectIndex], al
    call GetMonName                                   ; → wNameBuffer
    mov eax, wNameBuffer
    lea eax, [ebp + eax]
    mov esi, scoord(9, 1)
    call PlaceString

    call Delay3
%ifdef DEBUG_STATUS_PAGE2
    call DelayFrame                                  ; render page 2
    call DumpBackbuffer                              ; FRAME.BIN + exit (never returns)
%endif
    call WaitForTextScrollButtonPress
    mov al, [ss_saved_tileanim]                       ; restore BG tile animations (pret: pop af)
    mov [ebp + hTileAnimations], al
    ; TODO-HW: rAUDVOL (audio HAL, Phase 3).
    and byte [ebp + W_STATUS_FLAGS_2], ~(1 << BIT_NO_AUDIO_FADE_OUT) & 0xFF
    call GBPalWhiteOut
    jmp ClearScreen                                   ; tail (pret jp ClearScreen)

; StatusScreen_PrintPP — write AL at [ESI] and [ESI+1], step down 2 rows, CL times.
; (pret's DE step is SCREEN_WIDTH*2; the only callers use that, so FW*2 is inlined.)
StatusScreen_PrintPP:
    mov [ebp + esi], al
    mov [ebp + esi + 1], al
    add esi, FW * 2
    dec cl
    jnz StatusScreen_PrintPP
    ret

; StatusScreen_ClearName — blank NAME_LENGTH-1 tiles at ESI (pret StatusScreen_ClearName).
StatusScreen_ClearName:
    mov al, T_SPACE
    mov bx, NAME_LENGTH - 1
    jmp FillMemory                                    ; tail (fills BX tiles at ESI with AL)

; ---------------------------------------------------------------------------
; CalcExpToLevelUp — pret status_screen.asm CalcExpToLevelUp. wLoadedMonExp :=
; (exp for next level) - (current exp), big-endian borrow chain. inc/dec on the
; pointer preserve CF, so the sub→sbb borrow survives (see CLAUDE.md "Preserve
; Flags"). Called by StatusScreen2 (page 2).
; ---------------------------------------------------------------------------
CalcExpToLevelUp:
    mov al, [ebp + wLoadedMonLevel]
    cmp al, MAX_LEVEL
    jz .atMaxLevel
    inc al
    mov dh, al
    call CalcExperience
    mov esi, wLoadedMonExp + 2
    mov al, [ebp + hExperience + 2]
    sub al, [ebp + esi]
    mov [ebp + esi], al
    dec esi
    mov al, [ebp + hExperience + 1]
    sbb al, [ebp + esi]
    mov [ebp + esi], al
    dec esi
    mov al, [ebp + hExperience]
    sbb al, [ebp + esi]
    mov [ebp + esi], al
    dec esi
    ret
.atMaxLevel:
    mov esi, wLoadedMonExp
    xor al, al
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    ret
