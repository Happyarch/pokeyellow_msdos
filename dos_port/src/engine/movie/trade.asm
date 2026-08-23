; trade.asm — mirror of pret engine/movie/trade.asm (link plan Stage 3 step 3,
; docs/current_plan_link_cable.md). All 50 top-level pret labels, pret order,
; pret names; local `.foo` labels keep pret's names too.
;
; Retires the InternalClockTradeAnim / ExternalClockTradeAnim stubs in
; src/engine/movie/evolution_stubs.asm.
;
; PROJECTION MODEL — the trade animation runs on the shared movie-projection
; surface (engine/movie/movie_projection.asm), the SAME model as
; src/engine/link/cable_club.asm (its header carries the sibling DEVIATION for
; the identical CC(X,Y) transform). See the single DEVIATION on TradeAnimCommon
; below for the whole file's projection story: the port-only surface prelude
; and teardown, the CC(X,Y) coordinate projection, the MovieSyncScroll/
; MovieSyncWindow calls that follow every hSCX/hSCY/hWY/rWX write, and the
; PublishProjectedOAM calls that follow every shadow-OAM mutation.
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH, C=BL), DE=DX, HL=ESI,
; EBP = GB base. Flags re-derived on the same ops pret used.
;
; Idioms copied from existing translated cinematics (cited at each site):
;   - src/engine/link/cable_club.asm: CC(X,Y) macro, the MovieBeginSurface/
;     ClearSprites prelude, the ui_layout_intro.inc include shape.
;   - src/engine/movie/title.asm: the "modify hSCX/hSCY -> MovieSyncScroll ->
;     DelayFrame" per-frame slide-loop pattern.
;   - src/engine/movie/intro.asm: IntroClearScreen's "clear the WHOLE wTileMap
;     canvas from offset 0" idiom for a pret "clear the tilemap" call whose
;     hlcoord happens to be (0,0) — SCREEN_AREA (1000) already matches the
;     40x25 canvas exactly, so no CC()/rectangle is needed.
;   - src/engine/minigame/surfing_pikachu.asm / src/engine/gfx/sprite_oam.asm:
;     the PublishProjectedOAM(ESI=wShadowOAM, ECX=count, EAX=80, EBX=24)
;     "publish-in-frame-loop" pattern for cinematic OAM.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/engine/movie/trade.asm
; ============================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"                  ; text_far / text_end
%include "assets/battle_anim_constants.inc"   ; TILEMAP_GAME_BOY/LINK_CABLE, TRADE_BALL_*
%include "assets/audio_constants.inc"   ; SFX_HEAL_HP, SFX_TINK

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_intro.inc"   ; UI_TITLE_COL/ROW — the cinematic origin (cable_club.asm)

; CC(X,Y) — pret hlcoord/decoord/bccoord projection. Copied verbatim from
; src/engine/link/cable_club.asm (same movie-projection surface).
%define CC(X, Y) (wTileMap + ((Y) + UI_TITLE_ROW) * SCREEN_WIDTH + ((X) + UI_TITLE_COL))

; --- file-local constants (port convention: small assembly-time constants
; sourced from elsewhere, re-declared locally rather than %included whole —
; see cable_club.asm's "constants/serial_constants.asm (file-local)" note). ---
OBJ_SIZE         equ OAM_ENTRY_SIZE   ; 4 — pret's name for it (gb_memmap.inc)
SET_PAL_GENERIC  equ 8                ; constants/palette_constants.asm
ICON_TRADEBUBBLE equ 0x0E             ; constants/icon_constants.asm (assets/mon_icons.inc)
ICONOFFSET       equ 0x40             ; assets/mon_icons.inc — frame-2 tile delta

; --- presentation (movie projection) ---------------------------------------
extern MovieBeginSurface        ; engine/movie/movie_projection.asm
extern MovieEndSurface
extern MovieSyncScroll          ; hSCX/hSCY -> WIN_SRC_X/Y
extern MovieSyncWindow          ; hWY/rWX/rLCDC -> the second window descriptor
extern g_surface_redraw_cb      ; ppu.asm — nonzero iff a surface is already armed
extern ClearSprites             ; src/home/clear_sprites.asm — zero shadow OAM
extern PublishProjectedOAM      ; src/engine/gfx/sprite_oam.asm — ESI/ECX/EAX/EBX

; --- home / shared routines --------------------------------------------------
extern DelayFrame               ; src/home/vblank.asm
extern DelayFrames              ; src/home/delay.asm — BL = frame count
extern Delay3                   ; src/home/palettes.asm
extern FillMemory               ; src/home/copy2.asm — ESI dest, BX count, AL value
extern ClearScreen              ; src/home/copy2.asm
extern ClearScreenArea          ; src/home/copy2.asm — ESI, BH=rows, BL=cols
extern CopyScreenTileBufferToVRAM ; src/home/copy2.asm — BH ignored (native renderer)
extern CopyVideoData            ; src/home/copy2.asm — ESI dest VRAM, EDX flat src, BL tiles
extern CopyData                 ; src/home/copy.asm — ESI src, EDX dst, BX count
extern TextBoxBorder            ; src/home/text.asm — ESI, BH=rows, BL=cols
extern PlaceString              ; src/home/text.asm — EAX=flat src, ESI=dest
extern PrintText                ; src/home/window.asm — ESI=flat text stream
extern GetMonName                ; src/home/names.asm — wNamedObjectIndex -> wNameBuffer
extern PlayCry                  ; src/home/pokemon.asm — AL=species
extern PlaySound                ; src/home/audio.asm — AL=sound
extern RunPaletteCommand        ; src/home/palettes.asm — BH = command
extern UpdateCGBPal_OBP0        ; src/home/cgb_palettes.asm
extern UpdateCGBPal_OBP1        ; src/home/cgb_palettes.asm
extern UpdateCGBPal_BGP         ; src/home/cgb_palettes.asm
extern LoadGBPal                ; src/home/fade.asm
extern DisableLCD               ; src/home/lcd.asm
extern EnableLCD                ; src/home/lcd.asm
extern WriteOAMBlock            ; src/home/oam.asm — AL=block idx, BH=Y, BL=X, EDX=flat ptr
extern GetMonHeader              ; src/home/pokemon.asm — reads wCurSpecies
extern LoadFlippedFrontSpriteByMonIndex ; src/home/pokemon.asm — ESI=dest, reads wCurPartySpecies
extern CopyTileIDsFromList      ; src/engine/battle/animations.asm — BH=list idx, BL=base tile
extern CopyTileIDsFromList_ZeroBaseTileID ; src/engine/movie/intro.asm — BH=list idx
extern CopyToRedrawRowOrColumnSrcTiles    ; src/home/overworld.asm — ESI=src
extern MoveAnimation            ; src/engine/battle/animations.asm — reads wAnimationID
extern LoadMonPartySpriteGfx    ; src/engine/gfx/mon_icons.asm
extern WriteMonPartySpriteOAMBySpecies ; src/engine/gfx/mon_icons.asm — reads wMonPartySpriteSpecies
extern text_row_stride          ; src/home/text.asm — active wTileMap row stride
extern Trade_PrintPlayerMonInfoText  ; src/engine/movie/trade2.asm
extern Trade_PrintEnemyMonInfoText   ; src/engine/movie/trade2.asm

section .data

; TradingAnimationGraphics{,2} — Tier-1 generated 2bpp tile blobs
; (tools/generators/gen_trade_tiles.py; pret gfx/trade.asm).
%include "assets/trade_tiles.inc"

; The 8 far text bodies behind trade.asm's Print* helpers (pret data/text/
; text_2.asm), flattened by tools/generators/gen_menu_strings.py's
; TRADE_ANIM_FAR list.
%include "assets/trade_text.inc"

section .text

global InternalClockTradeAnim
global ExternalClockTradeAnim
global TradeAnimCommon
global InternalClockTradeFuncSequence
global ExternalClockTradeFuncSequence
global TradeFuncPointerTable
global Trade_Delay100
global Trade_CopyTileMapToVRAM
global Trade_Delay80
global Trade_ClearTileMap
global LoadTradingGFXAndMonNames
global Trade_LoadMonPartySpriteGfx
global Trade_SwapNames
global Trade_Cleanup
global Trade_ShowPlayerMon
global Trade_DrawOpenEndOfLinkCable
global Trade_AnimateBallEnteringLinkCable
global Trade_BallInsideLinkCableOAMBlock
global Trade_ShowEnemyMon
global Trade_AnimLeftToRight
global Trade_AnimRightToLeft
global Trade_InitGameboyTransferGfx
global Trade_DrawLeftGameboy
global Trade_DrawRightGameboy
global Trade_DrawCableAcrossScreen
global Trade_CopyCableTilesOffScreen
global Trade_AnimMonMoveHorizontal
global Trade_AnimCircledMon
global Trade_WriteCircledMonOAM
global Trade_AddOffsetsToOAMCoords
global Trade_AnimMonMoveVertical
global Trade_WriteCircleOAMBlock
global Trade_CircleOAMBlocks
global Trade_LoadMonSprite
global Trade_ShowClearedWindow
global Trade_SlideTextBoxOffScreen
global PrintTradeWentToText
global TradeWentToText
global PrintTradeForSendsText
global TradeForText
global TradeSendsText
global PrintTradeFarewellText
global TradeWavesFarewellText
global TradeTransferredText
global PrintTradeTakeCareText
global TradeTakeCareText
global PrintTradeWillTradeText
global TradeWillTradeText
global TradeforText
global Trade_ShowAnimation

section .bss
; PORT-only: did THIS call begin the movie surface (see the projection
; annotation on TradeAnimCommon below), so the matching MovieEndSurface at exit
; runs only when we own it (the cable-club caller already armed the surface;
; the in-game-trade caller never does).
trade_began_surface: resb 1

section .text

; ---------------------------------------------------------------------------
; InternalClockTradeAnim — pret engine/movie/trade.asm:1. Do the trading
; animation with the player's gameboy on the left. In-game trades and
; internally clocked link cable trades use this.
; ---------------------------------------------------------------------------
InternalClockTradeAnim:
    mov al, [ebp + wTradedPlayerMonSpecies]
    mov [ebp + wLeftGBMonSpecies], al
    mov al, [ebp + wTradedEnemyMonSpecies]
    mov [ebp + wRightGBMonSpecies], al
    mov edx, InternalClockTradeFuncSequence   ; ld de, InternalClockTradeFuncSequence (flat)
    jmp TradeAnimCommon

; ---------------------------------------------------------------------------
; ExternalClockTradeAnim — pret engine/movie/trade.asm:11. Do the trading
; animation with the player's gameboy on the right. Externally clocked link
; cable trades use this.
; ---------------------------------------------------------------------------
ExternalClockTradeAnim:
    mov al, [ebp + wTradedEnemyMonSpecies]
    mov [ebp + wLeftGBMonSpecies], al
    mov al, [ebp + wTradedPlayerMonSpecies]
    mov [ebp + wRightGBMonSpecies], al
    mov edx, ExternalClockTradeFuncSequence
    ; fall through

; ---------------------------------------------------------------------------
; TradeAnimCommon — pret engine/movie/trade.asm:20. The byte-code interpreter
; that runs a TradeFunc index list (EDX = flat pointer to the list).
;
; pret's `ld a,[de] / inc de / cp -1 / push de / ld hl,TradeFuncPointerTable /
; add a / ld c,a / ld b,0 / add hl,bc / ld a,[hli] / ld h,[hl] / ld l,a /
; ld de,.loop / push de / jp hl` (call trade func, which RETURNS to the top of
; the loop via the pushed .loop address) becomes a plain `call [table+eax*4]`
; inside a loop — same semantics (a trade func always returns to .loop either
; way), no DEVIATION needed since behaviour is identical and faithdiff has no
; edge model for `jp hl` through a dd table.
;
; DEVIATION{class=projection; pret=engine/movie/trade.asm:TradeAnimCommon; behavior=a port-only prelude begins the movie-projection cinematic surface (MovieBeginSurface plus ClearSprites) only if no surface is already armed, remembering locally whether it began it so the matching teardown (MovieEndSurface) at exit runs only when this routine owns the surface, plus every pret hlcoord decoord bccoord in this file and trade2.asm is projected through the CC(X,Y) macro, every hSCX hSCY write is mirrored to the compositor via MovieSyncScroll, every hWY rWX write via MovieSyncWindow, and every shadow-OAM mutation is republished via PublishProjectedOAM at the fixed 80,24 surface offset; evidence=the in-game-trade caller InGameTrade_DoTrade never arms the movie surface while the cable-club caller CableClub_DoBattleOrTrade already does, and the port's software compositor has no hardware VBlank OAM DMA and no independently scrollable BG plus window planes so it must be told explicitly what is visible every frame - movie_projection.asm and engine/gfx/sprite_oam.asm own the primitives reused here, and cable_club.asm's header carries the identical CC(X,Y) transform for the same surface; lifetime=permanent widescreen projection, the cinematic presentation boundary documented once in movie_projection.asm}
; ---------------------------------------------------------------------------
TradeAnimCommon:
    ; --- port prelude: take over the screen as the cinematic surface, unless
    ; the caller (cable club) already has. ---
    mov byte [trade_began_surface], 0
    cmp dword [g_surface_redraw_cb], 0
    jne .surfaceAlready
    call MovieBeginSurface
    call ClearSprites
    mov byte [trade_began_surface], 1
.surfaceAlready:
    mov dword [text_row_stride], SCREEN_WIDTH   ; canvas stride (cable_club.asm idiom)

    ; --- pret body ---
    mov al, [ebp + wOptions]
    push eax                        ; push af
    and al, SOUND_MASK              ; preserve speaker options
    mov [ebp + wOptions], al
    mov al, [ebp + hSCY]
    push eax                        ; push af
    mov al, [ebp + hSCX]
    push eax                        ; push af
    xor al, al
    mov [ebp + hSCY], al
    mov [ebp + hSCX], al
    call MovieSyncScroll
.loop:
    mov al, [edx]                   ; ld a, [de]
    cmp al, 0xFF
    je .done
    inc edx
    movzx eax, al
    call [dword TradeFuncPointerTable + eax * 4]   ; call trade func; returns here
    jmp .loop
.done:
    pop eax
    mov [ebp + hSCX], al
    pop eax
    mov [ebp + hSCY], al
    call MovieSyncScroll
    pop eax
    mov [ebp + wOptions], al
    cmp byte [trade_began_surface], 1
    jne .noTeardown
    call MovieEndSurface
.noTeardown:
    ret

; port form of pret's `addtradefunc`/`tradefunc` macros (macros/scripts/
; trade_center.asm equivalent, inlined in pret's own trade.asm): pret's table
; row is 2 bytes (dw), so its index divides the label delta by 2; the port's
; row is 4 bytes (dd flat pointer), so this divides by 4 instead. Both compute
; the same thing — "this trade func's 0-based row in TradeFuncPointerTable" —
; at assembly time, entirely within this one file.
%macro addtradefunc 1
global %1TradeFunc
%1TradeFunc:
    dd %1
%endmacro

%macro tradefunc 1
    db (%1TradeFunc - TradeFuncPointerTable) / 4
%endmacro

; The functions in the sequences below are executed in order by TradeAnimCommon.
; They are from opposite perspectives. The external clock one makes use of
; Trade_SwapNames to swap the player and enemy names for some functions.

section .data

InternalClockTradeFuncSequence:
    tradefunc LoadTradingGFXAndMonNames
    tradefunc Trade_ShowPlayerMon
    tradefunc Trade_DrawOpenEndOfLinkCable
    tradefunc Trade_AnimateBallEnteringLinkCable
    tradefunc Trade_AnimLeftToRight
    tradefunc Trade_Delay100
    tradefunc Trade_ShowClearedWindow
    tradefunc PrintTradeWentToText
    tradefunc PrintTradeForSendsText
    tradefunc PrintTradeFarewellText
    tradefunc Trade_AnimRightToLeft
    tradefunc Trade_ShowClearedWindow
    tradefunc Trade_DrawOpenEndOfLinkCable
    tradefunc Trade_ShowEnemyMon
    tradefunc Trade_Delay100
    tradefunc Trade_Cleanup
    db -1 ; end

ExternalClockTradeFuncSequence:
    tradefunc LoadTradingGFXAndMonNames
    tradefunc Trade_ShowClearedWindow
    tradefunc PrintTradeWillTradeText
    tradefunc PrintTradeFarewellText
    tradefunc Trade_SwapNames
    tradefunc Trade_AnimLeftToRight
    tradefunc Trade_SwapNames
    tradefunc Trade_ShowClearedWindow
    tradefunc Trade_DrawOpenEndOfLinkCable
    tradefunc Trade_ShowEnemyMon
    tradefunc Trade_SlideTextBoxOffScreen
    tradefunc Trade_ShowPlayerMon
    tradefunc Trade_DrawOpenEndOfLinkCable
    tradefunc Trade_AnimateBallEnteringLinkCable
    tradefunc Trade_SwapNames
    tradefunc Trade_AnimRightToLeft
    tradefunc Trade_SwapNames
    tradefunc Trade_Delay100
    tradefunc Trade_ShowClearedWindow
    tradefunc PrintTradeWentToText
    tradefunc Trade_Cleanup
    db -1 ; end

TradeFuncPointerTable:
    addtradefunc LoadTradingGFXAndMonNames
    addtradefunc Trade_ShowPlayerMon
    addtradefunc Trade_DrawOpenEndOfLinkCable
    addtradefunc Trade_AnimateBallEnteringLinkCable
    addtradefunc Trade_ShowEnemyMon
    addtradefunc Trade_AnimLeftToRight
    addtradefunc Trade_AnimRightToLeft
    addtradefunc Trade_Delay100
    addtradefunc Trade_ShowClearedWindow
    addtradefunc PrintTradeWentToText
    addtradefunc PrintTradeForSendsText
    addtradefunc PrintTradeFarewellText
    addtradefunc PrintTradeTakeCareText
    addtradefunc PrintTradeWillTradeText
    addtradefunc Trade_Cleanup
    addtradefunc Trade_SlideTextBoxOffScreen
    addtradefunc Trade_SwapNames

section .text

Trade_Delay100:
    mov bl, 100                     ; ld c, 100
    jmp DelayFrames

; Trade_CopyTileMapToVRAM — the vestigial hAutoBGTransferEnabled toggle. In the
; port the per-frame MovieMirrorSurface callback (armed by MovieBeginSurface)
; is what actually makes staging visible; this stays a faithful toggle + Delay3
; with no extra code, per the port hAutoBGTransferEnabled convention.
Trade_CopyTileMapToVRAM:
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call Delay3
    mov byte [ebp + hAutoBGTransferEnabled], 0
    ret

Trade_Delay80:
    mov bl, 80                      ; ld c, 80
    jmp DelayFrames

; Trade_ClearTileMap — pret: hlcoord 0,0 / ld bc,SCREEN_AREA / ld a,' ' /
; jp FillMemory (clear the whole wTileMap). PORT: fill the WHOLE 40x25 canvas
; from offset 0, matching the established cinematic idiom in
; engine/movie/intro.asm:IntroClearScreen ("the port clears all of wTileMap,
; which covers the visible window") rather than CC(0,0) + a 20x18 rectangle —
; the port's SCREEN_AREA (1000) already matches the canvas exactly, so a
; straight fill needs no stride handling.
Trade_ClearTileMap:
    mov esi, wTileMap
    mov bx, SCREEN_AREA & 0xFFFF
    mov al, ' '
    jmp FillMemory

; ---------------------------------------------------------------------------
; LoadTradingGFXAndMonNames — pret engine/movie/trade.asm:157.
; ---------------------------------------------------------------------------
LoadTradingGFXAndMonNames:
    call Trade_ClearTileMap
    call DisableLCD
    ; pret: two FarCopyData loads of TILE DATA into vChars -> CopyVideoData
    ; (hard rule: VRAM tile writes go through CopyVideoData or arm
    ; g_tilecache_dirty explicitly; CopyVideoData does the latter itself).
    mov edx, TradingAnimationGraphics
    mov esi, vChars2 + TILE_SIZE * 0x31       ; vChars2 tile $31
    mov bl, TRADING_ANIM_GFX_TILE_COUNT       ; game_boy.2bpp + link_cable.2bpp, contiguous
    call CopyVideoData
    mov edx, TradingAnimationGraphics2
    mov esi, vSprites + TILE_SIZE * 0x7C      ; vSprites tile $7c
    mov bl, TRADING_ANIM_GFX2_TILE_COUNT      ; cable_ball.2bpp
    call CopyVideoData
    ; pret: ld hl, vBGMap0 / ld bc, 2*TILEMAP_AREA / ld a,' ' / call FillMemory —
    ; a raw fill of the emulated GB VRAM tilemap bytes ($9800-$9FFF), not the
    ; wTileMap canvas: vBGMap0/vBGMap1 are literal EBP-relative hardware
    ; addresses here (gb_memmap.inc), same category as the IO_LCDC/rWX writes
    ; below, so this is a literal translation, not a CC()-projected one.
    mov esi, vBGMap0
    mov bx, (2 * TILEMAP_AREA) & 0xFFFF
    mov al, ' '
    call FillMemory
    call ClearSprites
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF
    or byte [ebp + wStatusFlags5], (1 << BIT_NO_TEXT_DELAY)   ; set BIT_NO_TEXT_DELAY, [hl]
    mov al, [ebp + wOnSGB]
    test al, al
    mov al, 0xE4                    ; non-SGB OBP0
    jz .next
    mov al, 0xF0                    ; SGB OBP0
.next:
    mov [ebp + IO_OBP0], al
    call UpdateCGBPal_OBP0
    call EnableLCD
    mov byte [ebp + hAutoBGTransferEnabled], 0
    mov al, [ebp + wTradedPlayerMonSpecies]
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    mov esi, wNameBuffer
    mov edx, wStringBuffer
    mov bx, NAME_LENGTH
    call CopyData
    mov al, [ebp + wTradedEnemyMonSpecies]
    mov [ebp + wNamedObjectIndex], al
    jmp GetMonName

; ---------------------------------------------------------------------------
; Trade_LoadMonPartySpriteGfx — pret engine/movie/trade.asm:201.
; ---------------------------------------------------------------------------
Trade_LoadMonPartySpriteGfx:
    mov al, 0b11010000
    mov [ebp + IO_OBP1], al
    call UpdateCGBPal_OBP1
    jmp LoadMonPartySpriteGfx        ; pret: farjp LoadMonPartySpriteGfx

; ---------------------------------------------------------------------------
; Trade_SwapNames — pret engine/movie/trade.asm:207. 3-way CopyData swap
; through wBuffer, NAME_LENGTH bytes each.
; ---------------------------------------------------------------------------
Trade_SwapNames:
    mov esi, wPlayerName
    mov edx, wBuffer
    mov bx, NAME_LENGTH
    call CopyData
    mov esi, wLinkEnemyTrainerName
    mov edx, wPlayerName
    mov bx, NAME_LENGTH
    call CopyData
    mov esi, wBuffer
    mov edx, wLinkEnemyTrainerName
    mov bx, NAME_LENGTH
    jmp CopyData

; ---------------------------------------------------------------------------
; Trade_Cleanup — pret engine/movie/trade.asm:221.
; ---------------------------------------------------------------------------
Trade_Cleanup:
    xor al, al                      ; pret: xor a — LoadGBPal itself reads
                                     ; wMapPalOffset, not A; kept faithfully
    call LoadGBPal
    and byte [ebp + wStatusFlags5], ~(1 << BIT_NO_TEXT_DELAY) & 0xFF  ; res BIT_NO_TEXT_DELAY, [hl]
    ret

; ---------------------------------------------------------------------------
; Trade_ShowPlayerMon — pret engine/movie/trade.asm:228.
; ---------------------------------------------------------------------------
Trade_ShowPlayerMon:
    mov byte [ebp + IO_LCDC], 0xAB  ; LCDC_ON|WIN_9800|WIN_ON|BLOCK21|BG_9C00|OBJ_8|OBJ_ON|BG_ON
    mov al, 0x50
    mov [ebp + hWY], al
    call MovieSyncWindow
    mov al, 0x86
    mov [ebp + IO_WX], al
    mov [ebp + hSCX], al
    call MovieSyncWindow
    call MovieSyncScroll
    mov byte [ebp + hAutoBGTransferEnabled], 0
    mov esi, CC(4, 0)
    mov bh, 6
    mov bl, 10
    call TextBoxBorder
    call Trade_PrintPlayerMonInfoText
    mov bh, 0x98                    ; HIGH(vBGMap0), ignored by the port's CopyScreenTileBufferToVRAM
    call CopyScreenTileBufferToVRAM
    call ClearScreen
    mov al, [ebp + wTradedPlayerMonSpecies]
    call Trade_LoadMonSprite
    mov al, 0x7E
.slideScreenLoop:
    push eax
    call DelayFrame
    pop eax
    mov [ebp + IO_WX], al
    mov [ebp + hSCX], al
    call MovieSyncWindow
    call MovieSyncScroll
    sub al, 2
    test al, al
    jnz .slideScreenLoop
    call Trade_Delay80
    mov al, TRADE_BALL_POOF_ANIM
    call Trade_ShowAnimation
    mov al, TRADE_BALL_DROP_ANIM
    call Trade_ShowAnimation        ; clears mon pic
    mov al, [ebp + wTradedPlayerMonSpecies]
    call PlayCry
    mov byte [ebp + hAutoBGTransferEnabled], 0
    ret

; ---------------------------------------------------------------------------
; Trade_DrawOpenEndOfLinkCable — pret engine/movie/trade.asm:269.
; ---------------------------------------------------------------------------
Trade_DrawOpenEndOfLinkCable:
    call Trade_ClearTileMap
    mov bh, 0x98                    ; HIGH(vBGMap0), ignored by the port
    call CopyScreenTileBufferToVRAM
    mov bh, SET_PAL_GENERIC
    call RunPaletteCommand

; This function call is pointless. It just copies blank tiles to VRAM that was
; already filled with blank tiles.
    mov esi, vBGMap1 + 0x8C
    call Trade_CopyCableTilesOffScreen

    mov al, 0xA0
    mov [ebp + hSCX], al
    call MovieSyncScroll
    call DelayFrame
    mov byte [ebp + IO_LCDC], 0x8B  ; LCDC_ON|WIN_9800|WIN_OFF|BLOCK21|BG_9C00|OBJ_8|OBJ_ON|BG_ON
    mov esi, CC(6, 2)
    mov bh, TILEMAP_LINK_CABLE
    call CopyTileIDsFromList_ZeroBaseTileID
    call Trade_CopyTileMapToVRAM
    mov al, SFX_HEAL_HP
    call PlaySound
    mov cl, 20
.loop:
    mov al, [ebp + hSCX]
    add al, 4
    mov [ebp + hSCX], al
    call MovieSyncScroll
    dec cl
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; Trade_AnimateBallEnteringLinkCable — pret engine/movie/trade.asm:301.
; ---------------------------------------------------------------------------
Trade_AnimateBallEnteringLinkCable:
    mov al, TRADE_BALL_SHAKE_ANIM
    call Trade_ShowAnimation
    mov bl, 10
    call DelayFrames
    mov al, 0b11100100
    mov [ebp + IO_OBP0], al
    call UpdateCGBPal_OBP0
    xor al, al
    mov [ebp + wLinkCableAnimBulgeToggle], al
    mov bh, 0x20                    ; lb bc, $20, $60 -> B(Y)=$20
    mov bl, 0x60                    ; C(X)=$60
.moveBallInsideLinkCableLoop:
    push ebx
    xor al, al
    mov edx, Trade_BallInsideLinkCableOAMBlock
    call WriteOAMBlock
    mov al, [ebp + wLinkCableAnimBulgeToggle]
    xor al, 1
    mov [ebp + wLinkCableAnimBulgeToggle], al
    add al, 0x7E
    mov esi, wShadowOAMSprite00TileID
    mov cl, OBJ_SIZE                 ; ld de,OBJ_SIZE / ld c,e — loop count == OBJ_SIZE (4)
.cycleLinkCableBulgeTile:
    mov [ebp + esi], al
    add esi, OBJ_SIZE
    dec cl
    jnz .cycleLinkCableBulgeTile
    ; PORT: republish — WriteOAMBlock's own self-publish above targets the
    ; overworld camera-centre projection (GBScreenToCanvasXY), not this
    ; cinematic's (80,24) surface offset, and the raw tile-id cycle just above
    ; never publishes at all. One PublishProjectedOAM re-derives all 4 entries
    ; fresh from wShadowOAM with the correct offset, superseding both.
    push eax
    push ecx
    mov esi, wShadowOAM
    mov ecx, 4
    mov eax, 80
    mov ebx, 24
    call PublishProjectedOAM
    pop ecx
    pop eax
    call Delay3
    pop ebx
    mov al, bl
    add al, 4
    mov bl, al
    cmp al, 0xA0
    jae .ballSpriteReachedEdgeOfScreen   ; jr nc (unsigned)
    mov al, SFX_TINK
    call PlaySound
    jmp .moveBallInsideLinkCableLoop
.ballSpriteReachedEdgeOfScreen:
    call ClearSprites
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call ClearScreen
    mov bh, 0x98                    ; HIGH(vBGMap0), ignored by the port
    call CopyScreenTileBufferToVRAM
    call Delay3
    mov byte [ebp + hAutoBGTransferEnabled], 0
    ret

Trade_BallInsideLinkCableOAMBlock:
    db 0x7E, 0
    db 0x7E, OAM_XFLIP
    db 0x7E, OAM_YFLIP
    db 0x7E, OAM_XFLIP | OAM_YFLIP

; ---------------------------------------------------------------------------
; Trade_ShowEnemyMon — pret engine/movie/trade.asm:357.
; ---------------------------------------------------------------------------
Trade_ShowEnemyMon:
    mov al, TRADE_BALL_TILT_ANIM
    call Trade_ShowAnimation
    call Trade_ShowClearedWindow
    mov esi, CC(4, 10)
    mov bh, 6
    mov bl, 10
    call TextBoxBorder
    call Trade_PrintEnemyMonInfoText
    call Trade_CopyTileMapToVRAM
    mov byte [ebp + hAutoBGTransferEnabled], 1
    mov al, [ebp + wTradedEnemyMonSpecies]
    call Trade_LoadMonSprite
    mov al, TRADE_BALL_POOF_ANIM
    call Trade_ShowAnimation
    mov byte [ebp + hAutoBGTransferEnabled], 1
    mov al, [ebp + wTradedEnemyMonSpecies]
    call PlayCry
    call Trade_Delay100
    mov esi, CC(4, 10)
    mov bh, 8
    mov bl, 12
    call ClearScreenArea
    jmp PrintTradeTakeCareText

; ---------------------------------------------------------------------------
; Trade_AnimLeftToRight — pret engine/movie/trade.asm:382. Animates the mon
; moving from the left GB to the right one.
; ---------------------------------------------------------------------------
Trade_AnimLeftToRight:
    call Trade_InitGameboyTransferGfx
    mov byte [ebp + wTradedMonMovingRight], 1
    mov al, 0b11100100
    mov [ebp + IO_OBP0], al
    call UpdateCGBPal_OBP0
    mov al, 0x54
    mov [ebp + wBaseCoordX], al
    mov al, 0x1C
    mov [ebp + wBaseCoordY], al
    mov al, [ebp + wLeftGBMonSpecies]
    mov [ebp + wMonPartySpriteSpecies], al
    call Trade_WriteCircledMonOAM
    call Trade_DrawLeftGameboy
    call Trade_CopyTileMapToVRAM
    call Trade_DrawCableAcrossScreen
    mov esi, vBGMap1 + 0x8C
    call Trade_CopyCableTilesOffScreen
    mov bh, 6
    call Trade_AnimMonMoveHorizontal
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call Trade_DrawCableAcrossScreen
    mov bh, 4
    call Trade_AnimMonMoveHorizontal
    call Trade_DrawRightGameboy
    mov bh, 6
    call Trade_AnimMonMoveHorizontal
    mov byte [ebp + hAutoBGTransferEnabled], 0
    call Trade_AnimMonMoveVertical
    jmp ClearSprites

; ---------------------------------------------------------------------------
; Trade_AnimRightToLeft — pret engine/movie/trade.asm:417. Animates the mon
; moving from the right GB to the left one.
; ---------------------------------------------------------------------------
Trade_AnimRightToLeft:
    call Trade_InitGameboyTransferGfx
    mov byte [ebp + wTradedMonMovingRight], 0
    mov al, 0x64
    mov [ebp + wBaseCoordX], al
    mov al, 0x44
    mov [ebp + wBaseCoordY], al
    mov al, [ebp + wRightGBMonSpecies]
    mov [ebp + wMonPartySpriteSpecies], al
    call Trade_WriteCircledMonOAM
    call Trade_DrawRightGameboy
    call Trade_CopyTileMapToVRAM
    call Trade_DrawCableAcrossScreen
    mov esi, vBGMap1 + 0x94
    call Trade_CopyCableTilesOffScreen
    call Trade_AnimMonMoveVertical
    mov bh, 6
    call Trade_AnimMonMoveHorizontal
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call Trade_DrawCableAcrossScreen
    mov bh, 4
    call Trade_AnimMonMoveHorizontal
    call Trade_DrawLeftGameboy
    mov bh, 6
    call Trade_AnimMonMoveHorizontal
    mov byte [ebp + hAutoBGTransferEnabled], 0
    jmp ClearSprites

; ---------------------------------------------------------------------------
; Trade_InitGameboyTransferGfx — pret engine/movie/trade.asm:449. Initialises
; the graphics for showing a mon moving between gameboys.
; ---------------------------------------------------------------------------
Trade_InitGameboyTransferGfx:
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call ClearScreen
    mov bh, SET_PAL_GENERIC
    call RunPaletteCommand
    mov byte [ebp + hAutoBGTransferEnabled], 0
    call Trade_LoadMonPartySpriteGfx
    call DelayFrame
    mov byte [ebp + IO_LCDC], 0xAB  ; LCDC_ON|WIN_9800|WIN_ON|BLOCK21|BG_9C00|OBJ_8|OBJ_ON|BG_ON
    mov byte [ebp + hSCX], 0
    call MovieSyncScroll
    mov al, 0x90
    mov [ebp + hWY], al
    call MovieSyncWindow
    ret

; ---------------------------------------------------------------------------
; Trade_DrawLeftGameboy — pret engine/movie/trade.asm:468.
; ---------------------------------------------------------------------------
Trade_DrawLeftGameboy:
    call Trade_ClearTileMap

; draw link cable
    mov esi, CC(11, 4)
    mov byte [ebp + esi], 0x5D
    inc esi
    mov al, 0x5E
    mov cl, 8
.loop:
    mov [ebp + esi], al
    inc esi
    dec cl
    jnz .loop

; draw gameboy pic
    mov esi, CC(5, 3)
    mov bh, TILEMAP_GAME_BOY
    call CopyTileIDsFromList_ZeroBaseTileID

; draw text box with player name below gameboy pic
    mov esi, CC(4, 12)
    mov bh, 2
    mov bl, 7
    call TextBoxBorder
    mov esi, CC(5, 14)
    lea eax, [ebp + wPlayerName]
    call PlaceString

    jmp DelayFrame

; ---------------------------------------------------------------------------
; Trade_DrawRightGameboy — pret engine/movie/trade.asm:497.
; ---------------------------------------------------------------------------
Trade_DrawRightGameboy:
    call Trade_ClearTileMap

; draw horizontal segment of link cable
    mov esi, CC(0, 4)
    mov al, 0x5E
    mov cl, 0x0E
.loop:
    mov [ebp + esi], al
    inc esi
    dec cl
    jnz .loop

; draw vertical segment of link cable
    mov byte [ebp + esi], 0x5F
    add esi, SCREEN_WIDTH            ; row-stride role — port's SCREEN_WIDTH (40) is correct here
    mov al, 0x61
    mov [ebp + esi], al
    add esi, SCREEN_WIDTH
    mov [ebp + esi], al
    add esi, SCREEN_WIDTH
    mov [ebp + esi], al
    add esi, SCREEN_WIDTH
    mov [ebp + esi], al
    add esi, SCREEN_WIDTH
    mov byte [ebp + esi], 0x60
    dec esi
    mov byte [ebp + esi], 0x5D

; draw gameboy pic
    mov esi, CC(7, 8)
    mov bh, TILEMAP_GAME_BOY
    call CopyTileIDsFromList_ZeroBaseTileID

; draw text box with enemy name above link cable
    mov esi, CC(6, 0)
    mov bh, 2
    mov bl, 7
    call TextBoxBorder
    mov esi, CC(7, 2)
    lea eax, [ebp + wLinkEnemyTrainerName]
    call PlaceString

    jmp DelayFrame

; ---------------------------------------------------------------------------
; Trade_DrawCableAcrossScreen — pret engine/movie/trade.asm:543. Draws the
; link cable across the screen.
; ---------------------------------------------------------------------------
Trade_DrawCableAcrossScreen:
    call Trade_ClearTileMap
    mov esi, CC(0, 4)
    mov al, 0x5E
    mov cl, 20                       ; pret's own SCREEN_WIDTH: the GB's real
                                      ; 20-column screen width, NOT the port's
                                      ; redefined 40-wide canvas stride — this
                                      ; fills exactly one visible screen row
.loop:
    mov [ebp + esi], al
    inc esi
    dec cl
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; Trade_CopyCableTilesOffScreen — pret engine/movie/trade.asm:555. Used to
; copy the link cable tiles off screen so that the cable continues when the
; screen is scrolled.
;
; In: ESI = the raw GB VRAM tilemap address the caller wants seeded
; (vBGMap1 + $8c / $94 — see the two callers above). hRedrawRowOrColumnDest
; is a genuine emulated-VRAM address, taken here exactly as pret's H/L split
; leaves it: the port's cinematic window sources GB_TILEMAP0 only, so this
; RedrawRowOrColumn target (GB_TILEMAP1) is not currently drawn by any window
; descriptor in trade.asm's own LCDC configuration (window map select bit is
; always 0 here) — same presentation limit as pret's own first caller comment
; just below ("this function call is pointless"). Translated literally rather
; than reinterpreted; see the implementer report for the open finding.
; ---------------------------------------------------------------------------
Trade_CopyCableTilesOffScreen:
    push esi                          ; preserve the caller's raw VRAM dest address
    mov esi, CC(0, 4)                 ; hlcoord 0, 4 -> source row in the canvas
    call CopyToRedrawRowOrColumnSrcTiles
    pop esi
    mov ax, si                        ; ld a,h / ldh[+1],a / ld a,l / ldh[+0],a —
    mov [ebp + hRedrawRowOrColumnDest], ax  ; one little-endian 16-bit store (L,H)
    mov byte [ebp + hRedrawRowOrColumnMode], REDRAW_ROW
    mov bl, 10
    jmp DelayFrames

; ---------------------------------------------------------------------------
; Trade_AnimMonMoveHorizontal — pret engine/movie/trade.asm:571. Animates the
; mon going through the link cable horizontally over a distance of BH 16-pixel
; units. Recursion on BH — kept 8-bit, as pret's `dec b`.
; ---------------------------------------------------------------------------
Trade_AnimMonMoveHorizontal:
    mov al, [ebp + wTradedMonMovingRight]
    mov dl, al                        ; ld e, a
    mov dh, 8                         ; ld d, $8
.scrollLoop:
    mov al, dl
    dec al
    jz .movingRight
; moving left
    mov al, [ebp + hSCX]
    sub al, 2
    jmp .next
.movingRight:
    mov al, [ebp + hSCX]
    add al, 2
.next:
    mov [ebp + hSCX], al
    call MovieSyncScroll
    call DelayFrame
    dec dh
    jnz .scrollLoop
    call Trade_AnimCircledMon
    dec bh
    jnz Trade_AnimMonMoveHorizontal
    ret

; ---------------------------------------------------------------------------
; Trade_AnimCircledMon — pret engine/movie/trade.asm:598. Cycles between the
; two animation frames of the mon party sprite, cycles between a circle and an
; oval around the mon sprite, and makes the cable flash.
; ---------------------------------------------------------------------------
Trade_AnimCircledMon:
    push edx
    push ebx
    push esi
    mov al, [ebp + IO_BGP]
    xor al, 0x3C                     ; make link cable flash
    mov [ebp + IO_BGP], al
    call UpdateCGBPal_BGP
    mov esi, wShadowOAMSprite00TileID
    mov cl, 0x14
.loop:
    mov al, [ebp + esi]
    xor al, ICONOFFSET
    mov [ebp + esi], al
    add esi, OBJ_SIZE
    dec cl
    jnz .loop
    ; PORT: republish so the tile-id flip reaches the compositor (see
    ; Trade_AddOffsetsToOAMCoords' identical footer for the coordinate half of
    ; this same 20-entry group).
    push eax
    push ecx
    mov esi, wShadowOAM
    mov ecx, 0x14
    mov eax, 80
    mov ebx, 24
    call PublishProjectedOAM
    pop ecx
    pop eax
    pop esi
    pop ebx
    pop edx
    ret

; ---------------------------------------------------------------------------
; Trade_WriteCircledMonOAM — pret engine/movie/trade.asm:623. Falls through
; into Trade_AddOffsetsToOAMCoords exactly as pret does (no ret between them —
; the two labels share one body; Trade_AddOffsetsToOAMCoords is also called
; standalone from Trade_AnimMonMoveVertical below).
; ---------------------------------------------------------------------------
Trade_WriteCircledMonOAM:
    call WriteMonPartySpriteOAMBySpecies   ; pret: farcall (banking DEVIATION, header)
    call Trade_WriteCircleOAMBlock

; ---------------------------------------------------------------------------
; Trade_AddOffsetsToOAMCoords — pret engine/movie/trade.asm:627. Adds
; wBaseCoordY/X to 20 shadow-OAM entries (4-byte stride).
; ---------------------------------------------------------------------------
Trade_AddOffsetsToOAMCoords:
    mov esi, wShadowOAM
    mov cl, 0x14
.loop:
    mov al, [ebp + wBaseCoordY]
    add al, [ebp + esi]
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + wBaseCoordX]
    add al, [ebp + esi]
    mov [ebp + esi], al
    inc esi
    inc esi
    inc esi
    dec cl
    jnz .loop
    ; PORT: final republish of this 20-entry group (mon icon + 4 circle
    ; blocks) at the cinematic surface offset. This is the ONE site that has
    ; to run whether we got here via Trade_WriteCircledMonOAM's fallthrough
    ; (first-time OAM build: the mon-icon writer's own internal publish used
    ; the wrong, overworld-camera offset, and WriteOAMBlock's four self
    ; publishes did too) or via a direct call from Trade_AnimMonMoveVertical
    ; below (coordinate update only) — either way, re-deriving all 20 entries
    ; fresh from wShadowOAM is correct and idempotent.
    push eax
    push ecx
    push ebx
    mov esi, wShadowOAM
    mov ecx, 0x14
    mov eax, 80
    mov ebx, 24
    call PublishProjectedOAM
    pop ebx
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; Trade_AnimMonMoveVertical — pret engine/movie/trade.asm:643. Animates the
; mon going through the link cable vertically as well as horizontally for a
; bit. See pret's own comment for why: the sprite itself is moved here rather
; than the screen scrolled, because the vertical cable segment sits to the
; right of the screen position Trade_AnimMonMoveHorizontal scrolls around.
; ---------------------------------------------------------------------------
Trade_AnimMonMoveVertical:
    mov al, [ebp + wTradedMonMovingRight]
    test al, al
    jz .movingLeft
; moving right
    mov bh, 4                        ; lb bc, 4, 0 -- move right
    mov bl, 0
    call .doAnim
    mov bh, 0                        ; lb bc, 0, 10 -- move down
    mov bl, 10
    jmp .doAnim
.movingLeft:
    mov bh, 0                        ; lb bc, 0, -10 -- move up
    mov bl, -10
    call .doAnim
    mov bh, -4                       ; lb bc, -4, 0 -- move left
    mov bl, 0
.doAnim:
    mov al, bh
    mov [ebp + wBaseCoordX], al
    mov al, bl
    mov [ebp + wBaseCoordY], al
    mov dh, 4
.loop:
    call Trade_AddOffsetsToOAMCoords
    call Trade_AnimCircledMon
    mov bl, 8
    call DelayFrames
    dec dh
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; Trade_WriteCircleOAMBlock — pret engine/movie/trade.asm:679. Writes the OAM
; blocks for the circle around the traded mon as it passes the link cable.
; ---------------------------------------------------------------------------
Trade_WriteCircleOAMBlock:
    mov esi, Trade_CircleOAMBlocks
    mov cl, 4
    xor al, al
.loop:
    push ecx
    mov edx, [esi]                    ; ld e,[hl]/inc hl/ld d,[hl]/inc hl -> flat ptr (port: dd)
    add esi, 4
    mov bl, [esi]                     ; ld c,[hl]
    inc esi
    mov bh, [esi]                     ; ld b,[hl]
    inc esi
    push esi
    inc al
    push eax
    call WriteOAMBlock
    pop eax
    pop esi
    pop ecx
    dec cl
    jnz .loop
    ret

section .data

; port form of pret's `trade_circle_oam_block` macro: pointer, upper-left x
; coord, upper-left y coord. pret's `dw \1` (16-bit ROM pointer) becomes `dd \1`
; (32-bit flat address) — the flat-pointer-table convention used throughout
; this codebase (e.g. src/data/tilemaps.asm's `tile_ids` macro).
%macro trade_circle_oam_block 3
    dd %1
    db %2, %3
%endmacro

Trade_CircleOAMBlocks:
    trade_circle_oam_block .OAMBlock0,  8,  8
    trade_circle_oam_block .OAMBlock1, 24,  8
    trade_circle_oam_block .OAMBlock2,  8, 24
    trade_circle_oam_block .OAMBlock3, 24, 24

; Tile ids verified against the actual compiled ROM (pokeyellow.gbc,
; Trade_CircleOAMBlocks.OAMBlock0-3): 0x38,0x39,0x3A,0x3B — i.e. RGBDS binds
; `<<` tighter than `+` in pret's `ICON_TRADEBUBBLE << 2 + n`, so the value is
; (ICON_TRADEBUBBLE << 2) + n, not ICON_TRADEBUBBLE << (2 + n). Parenthesized
; explicitly here so NASM's own precedence can't reintroduce the ambiguity.
.OAMBlock0:
    db (ICON_TRADEBUBBLE << 2) + 0, OAM_PAL1
    db (ICON_TRADEBUBBLE << 2) + 1, OAM_PAL1
    db (ICON_TRADEBUBBLE << 2) + 2, OAM_PAL1
    db (ICON_TRADEBUBBLE << 2) + 3, OAM_PAL1

.OAMBlock1:
    db (ICON_TRADEBUBBLE << 2) + 1, OAM_PAL1 | OAM_XFLIP
    db (ICON_TRADEBUBBLE << 2) + 0, OAM_PAL1 | OAM_XFLIP
    db (ICON_TRADEBUBBLE << 2) + 3, OAM_PAL1 | OAM_XFLIP
    db (ICON_TRADEBUBBLE << 2) + 2, OAM_PAL1 | OAM_XFLIP

.OAMBlock2:
    db (ICON_TRADEBUBBLE << 2) + 2, OAM_PAL1 | OAM_YFLIP
    db (ICON_TRADEBUBBLE << 2) + 3, OAM_PAL1 | OAM_YFLIP
    db (ICON_TRADEBUBBLE << 2) + 0, OAM_PAL1 | OAM_YFLIP
    db (ICON_TRADEBUBBLE << 2) + 1, OAM_PAL1 | OAM_YFLIP

.OAMBlock3:
    db (ICON_TRADEBUBBLE << 2) + 3, OAM_PAL1 | OAM_XFLIP | OAM_YFLIP
    db (ICON_TRADEBUBBLE << 2) + 2, OAM_PAL1 | OAM_XFLIP | OAM_YFLIP
    db (ICON_TRADEBUBBLE << 2) + 1, OAM_PAL1 | OAM_XFLIP | OAM_YFLIP
    db (ICON_TRADEBUBBLE << 2) + 0, OAM_PAL1 | OAM_XFLIP | OAM_YFLIP

section .text

; ---------------------------------------------------------------------------
; Trade_LoadMonSprite — pret engine/movie/trade.asm:743. In: AL = species.
; ---------------------------------------------------------------------------
Trade_LoadMonSprite:
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wCurSpecies], al
    mov [ebp + wWholeScreenPaletteMonSpecies], al
    mov bh, SET_PAL_POKEMON_WHOLE_SCREEN
    mov bl, 0
    call RunPaletteCommand
    mov al, [ebp + hAutoBGTransferEnabled]
    xor al, 1
    mov [ebp + hAutoBGTransferEnabled], al
    call GetMonHeader
    mov esi, CC(7, 2)
    call LoadFlippedFrontSpriteByMonIndex
    mov bl, 10
    jmp DelayFrames

; ---------------------------------------------------------------------------
; Trade_ShowClearedWindow — pret engine/movie/trade.asm:759. Clears the window
; and covers the BG entirely with the window.
; ---------------------------------------------------------------------------
Trade_ShowClearedWindow:
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call ClearScreen
    mov byte [ebp + IO_LCDC], 0xE3   ; LCDC_DEFAULT (matches PlayShootingStar's own comment)
    mov al, 7
    mov [ebp + IO_WX], al
    xor al, al
    mov [ebp + hWY], al
    call MovieSyncWindow
    mov al, 0x90
    mov [ebp + hSCX], al
    call MovieSyncScroll
    ret

; ---------------------------------------------------------------------------
; Trade_SlideTextBoxOffScreen — pret engine/movie/trade.asm:774. Slides the
; window right until it's off screen.
; ---------------------------------------------------------------------------
Trade_SlideTextBoxOffScreen:
    mov bl, 50
    call DelayFrames
.loop:
    call DelayFrame
    mov al, [ebp + IO_WX]
    inc al
    inc al
    mov [ebp + IO_WX], al
    call MovieSyncWindow
    cmp al, 0xA1
    jnz .loop
    call Trade_ClearTileMap
    mov bl, 10
    call DelayFrames
    mov al, 7
    mov [ebp + IO_WX], al
    call MovieSyncWindow
    ret

PrintTradeWentToText:
    mov esi, TradeWentToText
    call PrintText
    mov bl, 200
    call DelayFrames
    jmp Trade_SlideTextBoxOffScreen

TradeWentToText:
    text_far _TradeWentToText
    text_end

PrintTradeForSendsText:
    mov esi, TradeForText
    call PrintText
    call Trade_Delay80
    mov esi, TradeSendsText
    call PrintText
    jmp Trade_Delay80

TradeForText:
    text_far _TradeForText
    text_end

TradeSendsText:
    text_far _TradeSendsText
    text_end

PrintTradeFarewellText:
    mov esi, TradeWavesFarewellText
    call PrintText
    call Trade_Delay80
    mov esi, TradeTransferredText
    call PrintText
    call Trade_Delay80
    jmp Trade_SlideTextBoxOffScreen

TradeWavesFarewellText:
    text_far _TradeWavesFarewellText
    text_end

TradeTransferredText:
    text_far _TradeTransferredText
    text_end

PrintTradeTakeCareText:
    mov esi, TradeTakeCareText
    call PrintText
    jmp Trade_Delay80

TradeTakeCareText:
    text_far _TradeTakeCareText
    text_end

PrintTradeWillTradeText:
    mov esi, TradeWillTradeText
    call PrintText
    call Trade_Delay80
    mov esi, TradeforText
    call PrintText
    jmp Trade_Delay80

TradeWillTradeText:
    text_far _TradeWillTradeText
    text_end

TradeforText:
    text_far _TradeforText
    text_end

; ---------------------------------------------------------------------------
; Trade_ShowAnimation — pret engine/movie/trade.asm:865. In: AL = animation id.
; ---------------------------------------------------------------------------
Trade_ShowAnimation:
    mov [ebp + wAnimationID], al
    mov byte [ebp + wAnimationType], 0
    jmp MoveAnimation                ; pret: predef_jump MoveAnimation
