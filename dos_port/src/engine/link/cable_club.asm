; ============================================================================
; cable_club.asm — mirror of pret engine/link/cable_club.asm (all 23 labels).
; Link plan Stage 3 (docs/current_plan_link_cable.md): the Trade Center engine
; (block build/patch/exchange/unpatch, RNG list election, the two-column
; select-mon UI, the trade itself) and the Colosseum entry branch (goes live
; in Stage 4's link battle).
;
; PRESENTATION — the movie-projection surface (port-only):
; DEVIATION{class=projection; pret=engine/link/cable_club.asm:CableClub_DoBattleOrTrade; behavior=the whole cable-club session from CableClub_DoBattleOrTrade to ReturnToCableClubRoom or the index-ff title reset runs on the shared 160x144 cinematic surface (MovieBeginSurface slash MovieEndSurface) with every pret hlcoord projected by the uniform X+10 Y+3 transform and the per-frame surface mirror providing visibility through delays and exchange waits, and pret stride-20 linear tilemap runs that wrap rows are decomposed into per-row fills of the same cells; evidence=the trade-center screens and the Stage-3 trade cinematic are authored against the GB 20x18 viewport like every cinematic (movie_projection.asm header) and the battle projection BCOORD uses the numerically identical transform so PrintWaitingText serves both contexts unchanged; lifetime=permanent widescreen projection}
;
; BANKING — flat-model call boundaries (port-only):
; DEVIATION{class=banking; pret=engine/link/cable_club.asm:CableClub_DoBattleOrTradeAgain; behavior=every predef and callfar and farcall site in this file is a direct near call - InitList, StatusScreen, StatusScreen2, InitOpponent, HealParty, InternalClockTradeAnim, ExternalClockTradeAnim, SavePartyAndDexData, EmptyFunc, TryEvolvingMon, ClearVariablesOnEnterMap, ModifyPikachuHappiness - and the TradeCenterPointerTable holds dd flat pointers instead of dw; evidence=the flat single-address-space port has no ROM banking and no predef dispatch table for code predefs (same boundary as cable_club_npc.asm's LinkMenu callfar); lifetime=permanent flat-code boundary}
;
; The pret vc_hook lines (Wireless_ExchangeBytes_*, Trade_save_game_end) are
; Virtual-Console scaffolding and are omitted, per port convention.
;
; Strings are Tier-1 generated data: assets/cable_club_text.inc (carrier =
; THIS file; see the generator note in gen_menu_strings.py). pret's local
; .statsTrade string is the generated CableClub_StatsTradeText.
;
; TILE NOTE: the $76-$7D border tiles are the TrainerInfoTextBoxTileGraphics
; set, loaded to vChars2 tile $76 by LoadTrainerInfoTextBoxTiles (below) from
; the generated tc_box_tiles blob (assets/trainer_card_tiles.inc, whose
; tc_box_tiles+tc_bg_tile adjacency is asserted 9 tiles by its generator).
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH, C=BL), DE=DX, HL=ESI,
; EBP = GB base. Flags re-derived on the same ops pret used.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/engine/link/cable_club.asm
; ============================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"                  ; text_far / text_end
%include "assets/audio_constants.inc"   ; MUSIC_GAME_CORNER/SAFARI_ZONE/CELADON
%include "assets/map_dims.inc"          ; (map ids; CLUB tileset index is below)

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_intro.inc"   ; UI_TITLE_COL/ROW — the cinematic origin

extern text_row_stride          ; text.asm — active wTileMap row stride

; --- presentation (movie projection; header DEVIATION) ----------------------
extern MovieBeginSurface        ; engine/movie/movie_projection.asm
extern MovieEndSurface
extern ClearSprites             ; src/home/clear_sprites.asm — zero shadow OAM

; --- home / shared routines -------------------------------------------------
extern DelayFrame               ; src/home/vblank.asm
extern DelayFrames              ; src/home/delay.asm — BL = frames
extern Delay3                   ; src/home/palettes.asm
extern ClearScreen              ; src/home/copy2.asm
extern ClearScreenArea          ; src/home/copy2.asm — ESI, BH=rows, BL=cols
extern FillMemory               ; src/home/copy2.asm — ESI, BX=count, AL=value
extern CopyData                 ; src/home/copy.asm — ESI src, EDX dst, BX
extern CopyVideoData            ; src/home/copy2.asm — ESI dest VRAM, EDX flat src, BL tiles
extern UpdateSprites            ; src/home/update_sprites.asm
extern LoadFontTilePatterns     ; src/home/load_font.asm
extern LoadHpBarAndStatusTilePatterns ; src/home/load_font.asm
extern PlaceString              ; src/home/text.asm — EAX=flat src, ESI=dest
extern TextCommandProcessor     ; src/home/text.asm — ESI=stream, EBX=cursor
extern TextBoxBorder            ; src/home/text.asm (Diploma path shares iface)
extern HandleMenuInput          ; src/home/window.asm — AL = watched keys out
extern PlaceUnfilledArrowMenuCursor ; src/home/window.asm
extern menu_item_step           ; src/home/window.asm — cursor row step (bytes)
extern JoypadLowSensitivity     ; src/home/joypad2.asm — out [hJoy5]
extern SaveScreenTilesToBuffer1     ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer1   ; src/home/tilemap.asm
extern GetMonName               ; src/home/names.asm — wNamedObjectIndex -> wNameBuffer
extern SkipFixedLengthTextEntries   ; src/home/array.asm — ESI += NAME_LENGTH*AL
extern AddNTimes                ; src/home/array.asm — ESI += BX*AL
extern Random                   ; src/home/random.asm — AL out
extern PlayMusic                ; src/home/audio.asm — AL=song, BL=bank
extern PlaySound                ; src/home/audio.asm — AL=sound
extern StopAllMusic             ; src/home/audio.asm
extern RunPaletteCommand        ; src/home/palettes.asm — BH = command
extern GBPalNormal              ; src/home/palettes.asm
extern GBPalWhiteOutWithDelay3  ; src/home/palettes.asm
extern GBFadeInFromWhite        ; src/home/fade.asm
extern LoadMapData              ; src/home/overworld.asm
extern DisplayTextBoxID         ; src/home/textbox.asm — [wTextBoxID]
extern GetPredefRegisters       ; src/home/predef.asm
extern Init                     ; src/home/init.asm — soft reset
extern RemovePokemon            ; src/home/move_mon.asm
extern AddEnemyMonToPlayerParty ; src/home/move_mon.asm (Stage 3 wrapper)
extern g_tilecache_dirty        ; src/ppu/ppu.asm

; --- serial primitives (src/home/serial.asm, the HAL line) ------------------
extern Serial_ExchangeBytes
extern Serial_SyncAndExchangeNybble
extern Serial_PrintWaitingTextAndSyncAndExchangeNybble
extern NetHAL_StartTransfer     ; src/net/net_hal.asm — the rSC-write HAL site
extern NetHAL_LinkAlive         ; src/net/net_hal.asm — ZF=1: no link session (escape hatch)

; --- engine callees (pret callfar/predef targets; header banking DEVIATION) -
extern InitList                 ; src/engine/battle/misc.asm — [wInitListType]
extern StatusScreen             ; src/engine/pokemon/status_screen.asm
extern StatusScreen2            ; src/engine/pokemon/status_screen.asm
extern InitOpponent             ; src/engine/battle/init_battle.asm
extern HealParty                ; src/engine/events/heal_party.asm
extern InternalClockTradeAnim   ; src/engine/movie/evolution_stubs.asm (stub;
                                ; Stage 3 step 3 moves it to engine/movie/trade.asm)
extern ExternalClockTradeAnim   ; src/engine/movie/evolution_stubs.asm (stub;
                                ; Stage 3 step 3 moves it to engine/movie/trade.asm)
extern TryEvolvingMon           ; src/engine/pokemon/evos_moves.asm
extern SavePartyAndDexData      ; src/engine/menus/save.asm
extern SramStoreImage           ; src/save/dsv_io.asm — .dsv commit (HAL DEVIATION at the TradeCenter_Trade call site)
extern ClearVariablesOnEnterMap ; src/engine/overworld/clear_variables.asm
extern ModifyPikachuHappiness   ; src/engine/events/pikachu_happiness.asm — DH = kind
extern DisplayTitleScreen       ; src/engine/movie/title.asm
; generated tileset pointer tables (assets/map_headers.inc; carrier overworld.asm)
extern TilesetGfxPtrs
extern TilesetGfxSizes
extern TilesetCollPtrs
; generated trainer-card tile blob (assets/trainer_card_tiles.inc; carrier
; start_sub_menus.asm; tc_box_tiles..tc_bg_tile = the 9-tile trainer_info set)
extern tc_box_tiles

global CableClub_DoBattleOrTrade
global CableClub_DoBattleOrTradeAgain
global CallCurrentTradeCenterFunction
global TradeCenter_SelectMon
global ReturnToCableClubRoom
global TradeCenter_DrawCancelBox
global TradeCenter_PlaceSelectedEnemyMonMenuCursor
global TradeCenter_DisplayStats
global TradeCenter_DrawPartyLists
global TradeCenter_PrintPartyListNames
global TradeCenter_Trade
global WillBeTradedText
global TradeCenterPointerTable
global CableClub_Run
global EmptyFunc
global Diploma_TextBoxBorder
global CableClub_TextBoxBorder
global CableClub_DrawHorizontalLine
global LoadTrainerInfoTextBoxTiles

; --- constants/serial_constants.asm (file-local, port convention) -----------
SERIAL_PREAMBLE_BYTE        equ 0xFD
SERIAL_NO_DATA_BYTE         equ 0xFE
SERIAL_PATCH_LIST_PART_TERMINATOR equ 0xFF
SERIAL_PREAMBLE_LENGTH      equ 6
SERIAL_RN_PREAMBLE_LENGTH   equ 7
SERIAL_RNS_LENGTH           equ 10
USING_EXTERNAL_CLOCK        equ 0x01
USING_INTERNAL_CLOCK        equ 0x02
LINK_STATE_START_TRADE      equ 0x02
LINK_STATE_START_BATTLE     equ 0x03
LINK_STATE_RESET            equ 0x05
; LINK_STATE_TRADING (0x32) comes from gb_constants.inc
SC_START                    equ 0x80    ; hardware.inc B_SC_START
SC_INTERNAL                 equ 0x01    ; hardware.inc B_SC_SOURCE
IE_VBLANK                   equ 0x01    ; hardware.inc interrupt-enable bits
IE_TIMER                    equ 0x04
IE_SERIAL                   equ 0x08

; constants/tileset_constants.asm: CLUB is tileset 21 (the tilesets.asm data
; tables in src/engine/overworld/tilesets.asm carry it as row "21 CLUB").
CLUB_TILESET                equ 21

; charmap tiles (constants/charmap.asm; same values as home/window.asm)
CHAR_SPACE                  equ 0x7F    ; ' '
CHAR_CURSOR                 equ 0xED    ; '▶'
CHAR_UNFILLED_ARROW         equ 0xEC    ; '▷'

; hUILayoutFlags bit (constants/gfx_constants.asm). SET means SINGLE-spaced
; menu cursor stepping — the name reads backwards; pret's PlaceMenuCursor
; default step is 40 (2 rows) and drops to SCREEN_WIDTH (1 row) when set
; (pret home/window.asm:140-145). The port's operative step is menu_item_step.
BIT_DOUBLE_SPACED_MENU      equ 1

; The projected coordinate — pret hlcoord X,Y on the cinematic surface
; (numerically the battle BCOORD transform; header projection DEVIATION).
%define CC(X, Y) (wTileMap + ((Y) + UI_TITLE_ROW) * SCREEN_WIDTH + ((X) + UI_TITLE_COL))

section .data
align 4

; Tier-1 generated strings + the _WillBeTradedText stream (carrier = this file)
%include "assets/cable_club_text.inc"

; --- TradeCenterPointerTable — pret cable_club.asm:895 (dw -> dd flat) ------
TradeCenterPointerTable:
    dd TradeCenter_SelectMon
    dd TradeCenter_Trade

section .text

; ---------------------------------------------------------------------------
; CableClub_DoBattleOrTrade — pret engine/link/cable_club.asm:4.
; Entry from CableClub_Run: draw PLEASE WAIT!, then fall into the exchange.
; ---------------------------------------------------------------------------
CableClub_DoBattleOrTrade:
    mov bl, 80                      ; ld c, 80
    call DelayFrames
    ; --- port prelude (projection DEVIATION in the header): take over the
    ; screen as the cinematic surface for the whole cable-club session. The
    ; per-frame mirror it arms is what keeps every draw below visible through
    ; the exchange waits. ClearSprites zeroes shadow OAM — the room's NPC
    ; sprites must not ride over the surface (GB OBJ-over-window order);
    ; pret's own UpdateSprites call just below gates on wUpdateSpritesEnabled.
    call MovieBeginSurface
    call ClearSprites
    mov dword [text_row_stride], SCREEN_WIDTH   ; canvas stride (default)
    ; --- pret body ---
    call ClearScreen
    call UpdateSprites
    call LoadFontTilePatterns
    call LoadHpBarAndStatusTilePatterns
    call LoadTrainerInfoTextBoxTiles
    mov esi, CC(3, 8)               ; hlcoord 3, 8
    mov bh, 2                       ; lb bc, 2, 12
    mov bl, 12
    call CableClub_TextBoxBorder
    mov eax, PleaseWaitString       ; ld de, PleaseWaitString
    mov esi, CC(4, 10)              ; hlcoord 4, 10
    call PlaceString
    ; ld hl, wPlayerNumHits / xor a / ld [hli], a / ld [hl], $50
    mov byte [ebp + wPlayerNumHits], 0
    mov byte [ebp + wPlayerNumHits + 1], 0x50
    ; fall through

; ---------------------------------------------------------------------------
; CableClub_DoBattleOrTradeAgain — pret engine/link/cable_club.asm:25.
; Build the send blocks, exchange them, unpatch, then branch battle vs trade.
; Re-entered after each completed trade.
; ---------------------------------------------------------------------------
CableClub_DoBattleOrTradeAgain:
    ; 6 preamble bytes into wSerialPlayerDataBlock
    mov esi, wSerialPlayerDataBlock
    mov al, SERIAL_PREAMBLE_BYTE
    mov bh, 6                       ; ld b, 6
.writePlayerDataBlockPreambleLoop:
    mov [ebp + esi], al             ; ld [hli], a
    inc esi
    dec bh                          ; 8-bit, as pret (Preserve Counter WIDTH)
    jnz .writePlayerDataBlockPreambleLoop
    ; 7 preamble bytes into wSerialRandomNumberListBlock
    mov esi, wSerialRandomNumberListBlock
    mov al, SERIAL_PREAMBLE_BYTE
    mov bh, 7
.writeRandomNumberListPreambleLoop:
    mov [ebp + esi], al
    inc esi
    dec bh
    jnz .writeRandomNumberListPreambleLoop
    ; 10 random bytes, each < $FD
    mov bh, 10
.generateRandomNumberListLoop:
    call Random
    cmp al, SERIAL_PREAMBLE_BYTE    ; cp / jr nc — unsigned
    jae .generateRandomNumberListLoop
    mov [ebp + esi], al
    inc esi
    dec bh
    jnz .generateRandomNumberListLoop
    ; patch-list head: 3 preamble bytes then 200 zero bytes. FAITHFUL ODDITY:
    ; 3 + 200 = 203 bytes into the 200-byte wSerialPartyMonsPatchList — the
    ; zero fill runs 3 bytes into wSerialEnemyMonsPatchList, exactly as pret's
    ; does; the exchange below overwrites the enemy list anyway.
    mov esi, wSerialPartyMonsPatchList
    mov al, SERIAL_PREAMBLE_BYTE
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    inc esi
    mov bh, 0xC8                    ; ld b, $c8 (200)
    xor al, al
.zeroPlayerDataPatchListLoop:
    mov [ebp + esi], al
    inc esi
    dec bh
    jnz .zeroPlayerDataPatchListLoop
    ; zero wLinkEnemyTrainerName .. wTrainerHeaderPtr (425 bytes, 16-bit count)
    mov esi, wLinkEnemyTrainerName
    mov bx, wTrainerHeaderPtr - wLinkEnemyTrainerName
.zeroEnemyPartyLoop:
    xor al, al
    mov [ebp + esi], al
    inc esi
    dec bx                          ; dec bc / ld a,b / or c — 16-bit as pret
    mov al, bh
    or al, bl
    jnz .zeroEnemyPartyLoop
    ; build the two-part patch list: record 1-based offsets of every $FE byte
    ; in the party data, replacing each with $FF
    mov esi, wPartyMons - 1         ; ld hl, wPartyMons - 1
    mov edx, wSerialPartyMonsPatchList + 10  ; entries at +10 (3-byte preamble
                                    ; + 7 zeroed bytes — pret's own layout)
    xor bx, bx                      ; ld bc, 0
.patchPartyMonsLoop:
    inc bl                          ; inc c
    mov al, bl
    cmp al, SERIAL_PREAMBLE_BYTE
    je .startPatchListPart2
    mov al, bh                      ; ld a, b / dec a — in part 2?
    dec al
    jnz .checkPlayerDataByte        ; jump if in part 1
    ; part 2: done at offset (wPartyMonOT - (wPartyMons-1)) - (FD-1) = 13
    mov al, bl
    cmp al, (wPartyMonOT - (wPartyMons - 1)) - (SERIAL_PREAMBLE_BYTE - 1)
    je .finishedPatchingPlayerData
.checkPlayerDataByte:
    inc esi                         ; inc hl
    mov al, [ebp + esi]
    cmp al, SERIAL_NO_DATA_BYTE
    jne .patchPartyMonsLoop
    ; record the offset, patch the byte with $FF
    mov al, bl                      ; ld a, c
    mov [ebp + edx], al             ; ld [de], a
    inc edx
    mov byte [ebp + esi], 0xFF      ; ld [hl], $ff
    jmp .patchPartyMonsLoop
.startPatchListPart2:
    mov byte [ebp + edx], SERIAL_PATCH_LIST_PART_TERMINATOR ; end of part 1
    inc edx
    mov bh, 1                       ; lb bc, 1, 0
    mov bl, 0
    jmp .patchPartyMonsLoop
.finishedPatchingPlayerData:
    mov byte [ebp + edx], SERIAL_PATCH_LIST_PART_TERMINATOR ; end of part 2
    call Serial_SyncAndExchangeNybble
    ; port: peer died at the rendezvous — without this the block exchanges
    ; below all return immediately, leaving wSerialEnemyDataBlock stale, and
    ; the FE-skip scans would parse garbage (hatch DEVIATION at its label)
    call NetHAL_LinkAlive
    jz cable_club_link_down
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, USING_INTERNAL_CLOCK
    jne .skipSendingTwoZeroBytes
    ; internal clock: send two zero bytes for syncing
    call Delay3
    xor al, al
    mov [ebp + hSerialSendData], al
    mov byte [ebp + IO_SC], SC_START | SC_INTERNAL  ; ldh [rSC], a
    call NetHAL_StartTransfer       ; the rSC HAL site (serial.asm header)
    call DelayFrame
    xor al, al
    mov [ebp + hSerialSendData], al
    mov byte [ebp + IO_SC], SC_START | SC_INTERNAL
    call NetHAL_StartTransfer
.skipSendingTwoZeroBytes:
    call Delay3
    call StopAllMusic
    ; ld a, IE_SERIAL / ldh [rIE], a — virtual IE byte (GB_IE): the pump keeps
    ; running either way; Serial_ExchangeByte's block-mode watchdog reads it
    mov byte [ebp + GB_IE], IE_SERIAL
    ; --- the three block exchanges (one NF_BLK each way per block; the HAL
    ; cut is inside Serial_ExchangeBytes — see serial.asm's DEVIATION) ---
    mov esi, wSerialRandomNumberListBlock
    mov edx, wSerialOtherGameboyRandomNumberListBlock
    mov bx, SERIAL_RN_PREAMBLE_LENGTH + SERIAL_RNS_LENGTH
    call Serial_ExchangeBytes
    mov byte [ebp + edx], SERIAL_NO_DATA_BYTE   ; terminator after the block
    mov esi, wSerialPlayerDataBlock
    mov edx, wSerialEnemyDataBlock
    mov bx, SERIAL_PREAMBLE_LENGTH + NAME_LENGTH + 1 + PARTY_LENGTH + 1 + (PARTYMON_STRUCT_LENGTH + NAME_LENGTH * 2) * PARTY_LENGTH + 3
    call Serial_ExchangeBytes
    mov byte [ebp + edx], SERIAL_NO_DATA_BYTE
    mov esi, wSerialPartyMonsPatchList
    mov edx, wSerialEnemyMonsPatchList
    mov bx, 200
    call Serial_ExchangeBytes
    mov byte [ebp + GB_IE], IE_SERIAL | IE_TIMER | IE_VBLANK
    ; port: peer died during a block exchange — the dead exchanges returned
    ; without filling the receive buffers, and the preamble-hunt loop below
    ; scans unboundedly through the stale zeroes (hatch DEVIATION at its label)
    call NetHAL_LinkAlive
    jz cable_club_link_down
    ; the RNG list of the clocking GB is used by both sides
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, USING_INTERNAL_CLOCK
    je .skipCopyingRandomNumberList
    mov esi, wSerialOtherGameboyRandomNumberListBlock
.findStartOfRandomNumberListLoop:
    mov al, [ebp + esi]             ; ld a, [hli]
    inc esi
    test al, al                     ; and a
    jz .findStartOfRandomNumberListLoop
    cmp al, SERIAL_PREAMBLE_BYTE
    je .findStartOfRandomNumberListLoop
    cmp al, SERIAL_NO_DATA_BYTE
    je .findStartOfRandomNumberListLoop
    dec esi                         ; dec hl
    mov edx, wLinkBattleRandomNumberList
    mov bl, 10                      ; ld c, 10
.copyRandomNumberListLoop:
    mov al, [ebp + esi]
    inc esi
    cmp al, SERIAL_NO_DATA_BYTE
    je .copyRandomNumberListLoop
    mov [ebp + edx], al
    inc edx
    dec bl                          ; 8-bit, as pret
    jnz .copyRandomNumberListLoop
.skipCopyingRandomNumberList:
    ; enemy trainer name (scan past preamble, copy skipping $FE)
    mov esi, wSerialEnemyDataBlock + 3
.findStartOfEnemyNameLoop:
    mov al, [ebp + esi]
    inc esi
    test al, al
    jz .findStartOfEnemyNameLoop
    cmp al, SERIAL_PREAMBLE_BYTE
    je .findStartOfEnemyNameLoop
    cmp al, SERIAL_NO_DATA_BYTE
    je .findStartOfEnemyNameLoop
    dec esi
    mov edx, wLinkEnemyTrainerName
    mov bl, NAME_LENGTH
.copyEnemyNameLoop:
    mov al, [ebp + esi]
    inc esi
    cmp al, SERIAL_NO_DATA_BYTE
    je .copyEnemyNameLoop
    mov [ebp + edx], al
    inc edx
    dec bl
    jnz .copyEnemyNameLoop
    ; enemy party (404 bytes, HL continues from the name scan; 16-bit count)
    mov edx, wEnemyPartyCount
    mov bx, wTrainerHeaderPtr - wEnemyPartyCount
.copyEnemyPartyLoop:
    mov al, [ebp + esi]
    inc esi
    cmp al, SERIAL_NO_DATA_BYTE
    je .copyEnemyPartyLoop
    mov [ebp + edx], al
    inc edx
    dec bx
    mov al, bh
    or al, bl
    jnz .copyEnemyPartyLoop
    ; unpatch the player party via our own patch list (2 parts)
    mov edx, wSerialPartyMonsPatchList
    mov esi, wPartyMons
    mov bl, 2                       ; ld c, 2 — patch list has 2 parts
.unpatchPartyMonsLoop:
    mov al, [ebp + edx]             ; ld a, [de]
    inc edx
    test al, al
    jz .unpatchPartyMonsLoop
    cmp al, SERIAL_PREAMBLE_BYTE
    je .unpatchPartyMonsLoop
    cmp al, SERIAL_NO_DATA_BYTE
    je .unpatchPartyMonsLoop
    cmp al, SERIAL_PATCH_LIST_PART_TERMINATOR
    je .finishedPartyMonsPatchListPart
    ; pret push hl / push bc / b=0, c=a-1 / add hl,bc / ld [hl],$fe / pops —
    ; ECX is the push-bracketed bc scratch (BL, the part counter, survives)
    push esi
    movzx ecx, al
    lea esi, [esi + ecx - 1]        ; target = base + (offset - 1)
    mov byte [ebp + esi], SERIAL_NO_DATA_BYTE
    pop esi
    jmp .unpatchPartyMonsLoop
.finishedPartyMonsPatchListPart:
    mov esi, wPartyMons + (SERIAL_PREAMBLE_BYTE - 1)  ; part-2 base (+252)
    dec bl
    jnz .unpatchPartyMonsLoop
    ; unpatch the enemy party via the received patch list (2 parts)
    mov edx, wSerialEnemyMonsPatchList
    mov esi, wEnemyMons
    mov bl, 2
.unpatchEnemyMonsLoop:
    mov al, [ebp + edx]
    inc edx
    test al, al
    jz .unpatchEnemyMonsLoop
    cmp al, SERIAL_PREAMBLE_BYTE
    je .unpatchEnemyMonsLoop
    cmp al, SERIAL_NO_DATA_BYTE
    je .unpatchEnemyMonsLoop
    cmp al, SERIAL_PATCH_LIST_PART_TERMINATOR
    je .finishedEnemyMonsPatchListPart
    push esi
    movzx ecx, al
    lea esi, [esi + ecx - 1]
    mov byte [ebp + esi], SERIAL_NO_DATA_BYTE
    pop esi
    jmp .unpatchEnemyMonsLoop
.finishedEnemyMonsPatchListPart:
    mov esi, wEnemyMons + (SERIAL_PREAMBLE_BYTE - 1)
    dec bl
    jnz .unpatchEnemyMonsLoop
    ; ld a, LOW(wEnemyMonOT) / HIGH — the GB 16-bit address, little-endian
    mov word [ebp + wUnusedNamePointer], wEnemyMonOT & 0xFFFF
    xor al, al
    mov [ebp + wTradeCenterPointerTableIndex], al
    call StopAllMusic
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, USING_INTERNAL_CLOCK
    jne .noInternalClockDelay       ; call z, DelayFrames (c=66)
    mov bl, 66
    call DelayFrames
.noInternalClockDelay:
    ; cp LINK_STATE_START_BATTLE sets the branch flag; the two ld a / ld
    ; stores are flag-preserving movs, exactly pret's flag dance
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_START_BATTLE
    mov al, LINK_STATE_TRADING      ; flag-preserving (ld a, n)
    mov [ebp + wLinkState], al
    jne .trading
    ; --- Colosseum: link battle (goes live in Stage 4) ---
    mov al, LINK_STATE_BATTLING
    mov [ebp + wLinkState], al
    mov al, OPP_RIVAL1
    mov [ebp + wCurOpponent], al
    call ClearScreen
    call Delay3
    mov bh, SET_PAL_OVERWORLD       ; ld b, SET_PAL_OVERWORLD
    call RunPaletteCommand
    and byte [ebp + wOptions], ~(1 << BIT_BATTLE_ANIMATION) & 0xFF
    mov al, [ebp + wLetterPrintingDelayFlags]
    push eax                        ; push af
    xor al, al
    mov [ebp + wLetterPrintingDelayFlags], al
    ; port: the battle engine owns its own canvas — end the surface before it
    call MovieEndSurface
    call InitOpponent               ; pret predef (header banking DEVIATION)
    pop eax                         ; pop af
    mov [ebp + wLetterPrintingDelayFlags], al
    call HealParty                  ; pret predef
    jmp ReturnToCableClubRoom
.trading:
    mov bl, MUSIC_GAME_CORNER_BANK  ; ld c, BANK(Music_GameCorner)
    mov al, MUSIC_GAME_CORNER
    call PlayMusic
    jmp CallCurrentTradeCenterFunction  ; jr

; PleaseWaitString — Tier-1 data (assets/cable_club_text.inc, included above)

; ---------------------------------------------------------------------------
; CallCurrentTradeCenterFunction — pret engine/link/cable_club.asm:302.
; Jumptable dispatch on wTradeCenterPointerTableIndex; $ff = title reset.
; ---------------------------------------------------------------------------
CallCurrentTradeCenterFunction:
    mov al, [ebp + wTradeCenterPointerTableIndex]
    cmp al, 0xFF
    je .titleReset                  ; jp z, DisplayTitleScreen
    movzx eax, al                   ; add a / ld c,a / add hl,bc — dw index
    jmp [TradeCenterPointerTable + eax * 4]   ; dd table (jp hl)
.titleReset:
    ; port: the title screen owns its own presentation — end the surface
    call MovieEndSurface
    jmp DisplayTitleScreen

; ---------------------------------------------------------------------------
; cable_club_link_down — port-only disconnect escape hatch.
; DEVIATION{class=HAL; pret=engine/link/cable_club.asm:CallCurrentTradeCenterFunction; behavior=when the net session dies mid-trade-center the nybble consumers jump here and reset via pret's own index-ff DisplayTitleScreen path instead of consuming the death-hatch ff value as data; evidence=a GB with a pulled cable hangs in the serial wait loops which the port's primitives cannot do (serial.asm publishes ff and returns) so ff would flow onward - the choseTrade consumer would index enemy mon ff and the tradeConfirmed dec-al test reads ff as confirm, executing a one-sided trade against stale block data; lifetime=permanent, the no-partner hatch is the port's substitute for the GB hang}
; ---------------------------------------------------------------------------
cable_club_link_down:
    mov al, 0xFF
    mov [ebp + wTradeCenterPointerTableIndex], al
    jmp CallCurrentTradeCenterFunction

; ---------------------------------------------------------------------------
; TradeCenter_SelectMon — pret engine/link/cable_club.asm:316.
; Trade-center stage 0: the two-column party menu + CANCEL.
; Menu coords carry the +10/+3 surface projection (header DEVIATION); the
; single-spaced cursor stepping pret selects with BIT_DOUBLE_SPACED_MENU
; (set = SINGLE, the name reads backwards) is menu_item_step = SCREEN_WIDTH.
; ---------------------------------------------------------------------------
TradeCenter_SelectMon:
    call ClearScreen
    call Delay3
    mov bh, SET_PAL_OVERWORLD
    call RunPaletteCommand
    call LoadTrainerInfoTextBoxTiles
    call TradeCenter_DrawPartyLists
    call TradeCenter_DrawCancelBox
    ; xor a into the 4 contiguous nybble-exchange bytes + menu state
    xor al, al
    mov [ebp + wSerialSyncAndExchangeNybbleReceiveData], al
    mov [ebp + wSerialSyncAndExchangeNybbleReceiveData + 1], al
    mov [ebp + wSerialSyncAndExchangeNybbleReceiveData + 2], al
    mov [ebp + wSerialSyncAndExchangeNybbleReceiveData + 3], al
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al
    mov [ebp + wMenuJoypadPollCount], al
    inc al
    mov [ebp + wSerialExchangeNybbleSendData], al
    jmp .playerMonMenu
.enemyMonMenu:
    xor al, al
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    inc al
    mov [ebp + wWhichTradeMonSelectionMenu], al
    mov byte [ebp + wMenuWatchedKeys], PAD_DOWN | PAD_LEFT | PAD_A
    mov al, [ebp + wEnemyPartyCount]
    mov [ebp + wMaxMenuItem], al
    mov byte [ebp + wTopMenuItemY], 9 + UI_TITLE_ROW     ; pret 9 (projected)
    mov byte [ebp + wTopMenuItemX], 1 + UI_TITLE_COL     ; pret 1 (projected)
.enemyMonMenu_HandleInput:
    ; ld hl, hUILayoutFlags / set BIT_DOUBLE_SPACED_MENU — single-spaced
    or byte [ebp + hUILayoutFlags], 1 << BIT_DOUBLE_SPACED_MENU
    mov dword [menu_item_step], SCREEN_WIDTH             ; the operative step
    call HandleMenuInput
    and byte [ebp + hUILayoutFlags], ~(1 << BIT_DOUBLE_SPACED_MENU) & 0xFF
    mov dword [menu_item_step], 2 * SCREEN_WIDTH         ; pret's default step
    test al, al                     ; and a
    jz .getNewInput
    test al, PAD_A                  ; bit B_PAD_A, a
    jz .enemyMonMenu_ANotPressed
    ; A pressed: clamp to the last real mon, show its stats
    mov al, [ebp + wMaxMenuItem]
    mov bl, al                      ; ld c, a
    mov al, [ebp + wCurrentMenuItem]
    cmp al, bl
    jb .displayEnemyMonStats        ; jr c — unsigned
    mov al, [ebp + wMaxMenuItem]
    dec al
    mov [ebp + wCurrentMenuItem], al
.displayEnemyMonStats:
    mov byte [ebp + wInitListType], INIT_ENEMYOT_LIST
    call InitList                   ; callfar — the list isn't used
    mov esi, wEnemyMons             ; ld hl, wEnemyMons (vestigial, as pret)
    call TradeCenter_DisplayStats
    jmp .getNewInput
.enemyMonMenu_ANotPressed:
    test al, PAD_LEFT               ; bit B_PAD_LEFT, a
    jz .enemyMonMenu_LeftNotPressed
    ; Left: back to the player mon menu (restore the tile under the cursor)
    xor al, al
    mov [ebp + wWhichTradeMonSelectionMenu], al
    movzx eax, word [ebp + wMenuCursorLocation]  ; pret ld l,a / ld h,a pair
    mov cl, [ebp + wTileBehindCursor]
    mov [ebp + eax], cl
    mov al, [ebp + wCurrentMenuItem]
    mov bh, al                      ; ld b, a
    mov al, [ebp + wPartyCount]
    dec al
    cmp al, bh
    jae .playerMonMenu              ; jr nc
    mov [ebp + wCurrentMenuItem], al
    jmp .playerMonMenu
.enemyMonMenu_LeftNotPressed:
    test al, PAD_DOWN               ; bit B_PAD_DOWN, a
    jz .getNewInput
    jmp .selectedCancelMenuItem     ; Down pressed
.playerMonMenu:
    xor al, al                      ; player mon menu
    mov [ebp + wWhichTradeMonSelectionMenu], al
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    mov byte [ebp + wMenuWatchedKeys], PAD_DOWN | PAD_RIGHT | PAD_A
    mov al, [ebp + wPartyCount]
    mov [ebp + wMaxMenuItem], al
    mov byte [ebp + wTopMenuItemY], 1 + UI_TITLE_ROW     ; pret 1 (projected)
    mov byte [ebp + wTopMenuItemX], 1 + UI_TITLE_COL     ; pret 1 (projected)
    mov esi, CC(1, 1)               ; hlcoord 1, 1
    mov bh, 6                       ; lb bc, 6, 1 — 6 rows x 1 col cursor strip
    mov bl, 1
    call ClearScreenArea
.playerMonMenu_HandleInput:
    or byte [ebp + hUILayoutFlags], 1 << BIT_DOUBLE_SPACED_MENU
    mov dword [menu_item_step], SCREEN_WIDTH
    call HandleMenuInput
    and byte [ebp + hUILayoutFlags], ~(1 << BIT_DOUBLE_SPACED_MENU) & 0xFF
    mov dword [menu_item_step], 2 * SCREEN_WIDTH
    test al, al                     ; and a — was anything pressed?
    jnz .playerMonMenu_SomethingPressed
    jmp .getNewInput
.playerMonMenu_SomethingPressed:
    test al, PAD_A                  ; bit B_PAD_A, a
    jz .playerMonMenu_ANotPressed
    jmp .chosePlayerMon             ; jump if A button pressed
    ; unreachable code (pret cable_club.asm:428-433, kept verbatim)
    mov byte [ebp + wInitListType], INIT_PLAYEROT_LIST
    call InitList                   ; the list isn't used
    call TradeCenter_DisplayStats
    jmp .getNewInput
.playerMonMenu_ANotPressed:
    test al, PAD_RIGHT              ; bit B_PAD_RIGHT, a
    jz .playerMonMenu_RightNotPressed
    ; Right: switch to the enemy mon menu
    mov al, 1                       ; enemy mon menu
    mov [ebp + wWhichTradeMonSelectionMenu], al
    movzx eax, word [ebp + wMenuCursorLocation]
    mov cl, [ebp + wTileBehindCursor]
    mov [ebp + eax], cl
    mov al, [ebp + wCurrentMenuItem]
    mov bh, al
    mov al, [ebp + wEnemyPartyCount]
    dec al
    cmp al, bh
    jae .notPastLastEnemyMon        ; jr nc
    ; selection would be past the last enemy mon: select the last one
    mov [ebp + wCurrentMenuItem], al
.notPastLastEnemyMon:
    jmp .enemyMonMenu
.playerMonMenu_RightNotPressed:
    test al, PAD_DOWN
    jz .getNewInput
    jmp .selectedCancelMenuItem     ; Down pressed
.getNewInput:
    mov al, [ebp + wWhichTradeMonSelectionMenu]
    test al, al
    jz .playerMonMenu_HandleInput
    jmp .enemyMonMenu_HandleInput
.chosePlayerMon:
    call SaveScreenTilesToBuffer1
    call PlaceUnfilledArrowMenuCursor
    mov al, [ebp + wMaxMenuItem]
    mov bl, al
    mov al, [ebp + wCurrentMenuItem]
    cmp al, bl
    jb .displayStatsTradeMenu       ; jr c
    mov al, [ebp + wMaxMenuItem]
    dec al
.displayStatsTradeMenu:
    push eax                        ; push af (AL = the chosen item)
    mov esi, CC(0, 14)              ; hlcoord 0, 14
    mov bh, 2                       ; lb bc, 2, 18
    mov bl, 18
    call CableClub_TextBoxBorder
    mov eax, CableClub_StatsTradeText   ; pret local .statsTrade (generated)
    mov esi, CC(2, 16)              ; hlcoord 2, 16
    call PlaceString
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al
    mov [ebp + wMenuJoypadPollCount], al
    mov [ebp + wMaxMenuItem], al
    mov byte [ebp + wTopMenuItemY], 16 + UI_TITLE_ROW    ; pret 16 (projected)
.selectStatsMenuItem:
    mov byte [ebp + CC(11, 16)], CHAR_SPACE   ; ldcoord_a 11, 16
    mov byte [ebp + wMenuWatchedKeys], PAD_RIGHT | PAD_B | PAD_A
    mov byte [ebp + wTopMenuItemX], 1 + UI_TITLE_COL     ; pret 1 (projected)
    call HandleMenuInput
    test al, PAD_RIGHT              ; bit B_PAD_RIGHT
    jnz .selectTradeMenuItem
    test al, PAD_B                  ; bit B_PAD_B / jr z, .displayPlayerMonStats
    jz .displayPlayerMonStats
.cancelPlayerMonChoice:
    pop eax                         ; pop af
    mov [ebp + wCurrentMenuItem], al
    call LoadScreenTilesFromBuffer1
    jmp .playerMonMenu
.selectTradeMenuItem:
    mov byte [ebp + CC(1, 16)], CHAR_SPACE    ; ldcoord_a 1, 16
    mov byte [ebp + wMenuWatchedKeys], PAD_LEFT | PAD_B | PAD_A
    mov byte [ebp + wTopMenuItemX], 11 + UI_TITLE_COL    ; pret 11 (projected)
    call HandleMenuInput
    test al, PAD_LEFT
    jnz .selectStatsMenuItem
    test al, PAD_B
    jnz .cancelPlayerMonChoice
    jmp .choseTrade                 ; jr
.displayPlayerMonStats:
    pop eax                         ; pop af
    mov [ebp + wCurrentMenuItem], al
    mov byte [ebp + wInitListType], INIT_PLAYEROT_LIST
    call InitList                   ; the list isn't used
    call TradeCenter_DisplayStats
    call LoadScreenTilesFromBuffer1
    jmp .playerMonMenu
.choseTrade:
    call PlaceUnfilledArrowMenuCursor
    pop eax                         ; pop af
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wTradingWhichPlayerMon], al
    mov [ebp + wSerialExchangeNybbleSendData], al
    call Serial_PrintWaitingTextAndSyncAndExchangeNybble
    mov al, [ebp + wSerialSyncAndExchangeNybbleReceiveData]
    cmp al, 0xFF                        ; port: link died (serial.asm death hatch)
    je cable_club_link_down
    cmp al, 0xF
    je CallCurrentTradeCenterFunction   ; other side cancelled: restart stage 0
    mov [ebp + wTradingWhichEnemyMon], al
    call TradeCenter_PlaceSelectedEnemyMonMenuCursor
    mov al, 1                       ; TradeCenter_Trade
    mov [ebp + wTradeCenterPointerTableIndex], al
    jmp CallCurrentTradeCenterFunction
; .statsTrade — Tier-1 data (CableClub_StatsTradeText, cable_club_text.inc)
.selectedCancelMenuItem:
    mov al, [ebp + wCurrentMenuItem]
    mov bh, al                      ; ld b, a
    mov al, [ebp + wMaxMenuItem]
    cmp al, bh
    jne .getNewInput                ; jp nz — only when ON the cancel slot
    movzx eax, word [ebp + wMenuCursorLocation]
    mov byte [ebp + eax], CHAR_SPACE
.cancelMenuItem_Loop:
    mov byte [ebp + CC(1, 16)], CHAR_CURSOR   ; '▶' at (1,16)
.cancelMenuItem_JoypadLoop:
    call JoypadLowSensitivity
    mov al, [ebp + hJoy5]
    test al, al                     ; and a — pressed anything?
    jz .cancelMenuItem_JoypadLoop
    test al, PAD_A                  ; bit B_PAD_A
    jnz .cancelMenuItem_APressed
    test al, PAD_UP                 ; bit B_PAD_UP
    jz .cancelMenuItem_JoypadLoop
    ; Up: back onto the party list
    mov byte [ebp + CC(1, 16)], CHAR_SPACE
    mov al, [ebp + wPartyCount]
    dec al
    mov [ebp + wCurrentMenuItem], al
    jmp .playerMonMenu
.cancelMenuItem_APressed:
    mov byte [ebp + CC(1, 16)], CHAR_UNFILLED_ARROW   ; '▷'
    mov al, 0xF
    mov [ebp + wSerialExchangeNybbleSendData], al
    call Serial_PrintWaitingTextAndSyncAndExchangeNybble
    mov al, [ebp + wSerialSyncAndExchangeNybbleReceiveData]
    cmp al, 0xFF                    ; port: link died (serial.asm death hatch)
    je cable_club_link_down
    cmp al, 0xF                     ; did the other person choose Cancel too?
    jne .cancelMenuItem_Loop
    ; fall through

; ---------------------------------------------------------------------------
; ReturnToCableClubRoom — pret engine/link/cable_club.asm:588.
; Fade white, reload the club room, fade back in.
; ---------------------------------------------------------------------------
ReturnToCableClubRoom:
    call GBPalWhiteOutWithDelay3
    mov al, [ebp + wFontLoaded]     ; push af (value; pret also pushes hl,
    push eax                        ; the pointer — direct addressing here)
    and byte [ebp + wFontLoaded], ~(1 << BIT_FONT_LOADED) & 0xFF
    xor al, al
    mov [ebp + wStatusFlags3], al   ; clears BIT_INIT_TRADE_CENTER_FACING
    dec al
    mov [ebp + wDestinationWarpID], al   ; $ff
    ; port: back to the overworld presentation before the map reload draws it
    call MovieEndSurface
    call LoadMapData
    call ClearVariablesOnEnterMap   ; farcall (header banking DEVIATION)
    pop eax                         ; pop hl / pop af / ld [hl], a
    mov [ebp + wFontLoaded], al
    call GBFadeInFromWhite
    ret

; ---------------------------------------------------------------------------
; TradeCenter_DrawCancelBox — pret engine/link/cable_club.asm:607.
; ---------------------------------------------------------------------------
TradeCenter_DrawCancelBox:
    ; pret: hlcoord 11,15 / ld bc, 2*SCREEN_WIDTH+9 / FillMemory $7e — ONE
    ; linear 49-byte run in the stride-20 GB tilemap: (11..19,15) + all of
    ; rows 16 and 17. The canvas is stride-40, so the same CELLS are three
    ; per-row fills (header projection DEVIATION, "linear runs decomposed").
    mov al, 0x7E
    mov esi, CC(11, 15)
    mov bx, 9                       ; (11..19,15)
    call FillMemory
    mov al, 0x7E
    mov esi, CC(0, 16)
    mov bx, 20                      ; all of row 16
    call FillMemory
    mov al, 0x7E
    mov esi, CC(0, 17)
    mov bx, 20                      ; all of row 17
    call FillMemory
    mov esi, CC(0, 15)              ; hlcoord 0, 15
    mov bh, 1                       ; lb bc, 1, 9
    mov bl, 9
    call CableClub_TextBoxBorder
    mov eax, CancelTextString
    mov esi, CC(2, 16)              ; hlcoord 2, 16
    jmp PlaceString                 ; jp

; CancelTextString — Tier-1 data (assets/cable_club_text.inc, included above)

; ---------------------------------------------------------------------------
; TradeCenter_PlaceSelectedEnemyMonMenuCursor — pret cable_club.asm:622.
; Mark the enemy mon the peer picked with the unfilled cursor.
; ---------------------------------------------------------------------------
TradeCenter_PlaceSelectedEnemyMonMenuCursor:
    mov al, [ebp + wSerialSyncAndExchangeNybbleReceiveData]
    mov esi, CC(1, 9)               ; hlcoord 1, 9
    mov bx, SCREEN_WIDTH            ; ld bc, SCREEN_WIDTH — one row per entry
    call AddNTimes                  ; (the constant carries the port's 40)
    mov byte [ebp + esi], CHAR_UNFILLED_ARROW   ; ld [hl], '▷'
    ret

; ---------------------------------------------------------------------------
; TradeCenter_DisplayStats — pret engine/link/cable_club.asm:630.
; StatusScreen for the selected mon, then redraw the whole select screen.
; ---------------------------------------------------------------------------
TradeCenter_DisplayStats:
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wWhichPokemon], al
    call StatusScreen               ; pret predef (header banking DEVIATION)
    call StatusScreen2              ; pret predef
    ; port: the status screen ran its own presentation — re-arm the surface;
    ; pret redraws everything below anyway, so the fresh blank canvas is the
    ; same state its redraw expects
    call MovieBeginSurface
    call ClearSprites
    call Delay3
    mov bh, SET_PAL_OVERWORLD
    call RunPaletteCommand
    call GBPalNormal
    call LoadTrainerInfoTextBoxTiles
    call TradeCenter_DrawPartyLists
    jmp TradeCenter_DrawCancelBox   ; jp

; ---------------------------------------------------------------------------
; TradeCenter_DrawPartyLists — pret engine/link/cable_club.asm:643.
; ---------------------------------------------------------------------------
TradeCenter_DrawPartyLists:
    mov esi, CC(0, 0)               ; hlcoord 0, 0
    mov bh, 6                       ; lb bc, 6, 18
    mov bl, 18
    call CableClub_TextBoxBorder
    mov esi, CC(0, 8)               ; hlcoord 0, 8
    mov bh, 6
    mov bl, 18
    call CableClub_TextBoxBorder
    lea eax, [ebp + wPlayerName]    ; ld de, wPlayerName (GB memory -> flat)
    mov esi, CC(5, 0)
    call PlaceString
    lea eax, [ebp + wLinkEnemyTrainerName]
    mov esi, CC(5, 8)
    call PlaceString
    mov edx, wPartySpecies          ; ld de, wPartySpecies
    mov esi, CC(2, 1)               ; hlcoord 2, 1
    call TradeCenter_PrintPartyListNames
    mov edx, wEnemyPartySpecies
    mov esi, CC(2, 9)               ; hlcoord 2, 9
    ; fall through

; ---------------------------------------------------------------------------
; TradeCenter_PrintPartyListNames — pret engine/link/cable_club.asm:663.
; In: EDX = species list ($FF-terminated), ESI = first row's tile offset.
; ---------------------------------------------------------------------------
TradeCenter_PrintPartyListNames:
    mov bl, 0                       ; ld c, 0
.loop:
    mov al, [ebp + edx]             ; ld a, [de]
    cmp al, 0xFF
    je .done                        ; ret z
    mov [ebp + wNamedObjectIndex], al
    push ebx                        ; push bc
    push esi                        ; push hl
    push edx                        ; push de
    mov al, bl                      ; ld a, c
    mov [ebp + hPastLeadingZeros], al
    call GetMonName
    lea eax, [ebp + wNameBuffer]    ; GetMonName's output (pret leaves DE)
    call PlaceString                ; ESI = the row's tile offset
    pop edx
    inc edx                         ; inc de
    pop esi
    add esi, SCREEN_WIDTH           ; ld bc, SCREEN_WIDTH / add hl, bc —
                                    ; one row per name (single-spaced list)
    pop ebx                         ; pop bc
    inc bl                          ; inc c
    jmp .loop
.done:
    ret

; ---------------------------------------------------------------------------
; TradeCenter_Trade — pret engine/link/cable_club.asm:688.
; Trade-center stage 1: confirm, nybble-confirm exchange, the swap itself,
; the animation, evolution, save, loop back.
; ---------------------------------------------------------------------------
TradeCenter_Trade:
    mov bl, 100                     ; ld c, 100
    call DelayFrames
    xor al, al
    mov [ebp + wSerialExchangeNybbleSendData + 1], al   ; unnecessary (pret)
    mov [ebp + wSerialExchangeNybbleReceiveData], al
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    mov [ebp + wMenuJoypadPollCount], al
    mov esi, CC(0, 12)              ; hlcoord 0, 12
    mov bh, 4                       ; lb bc, 4, 18
    mov bl, 18
    call CableClub_TextBoxBorder
    ; player mon name -> wNameOfPlayerMonToBeTraded
    mov al, [ebp + wTradingWhichPlayerMon]
    mov esi, wPartySpecies          ; ld hl, wPartySpecies / add hl, bc
    movzx ecx, al
    add esi, ecx
    mov al, [ebp + esi]
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    mov esi, wNameBuffer            ; ld hl, wNameBuffer
    mov edx, wNameOfPlayerMonToBeTraded
    mov bx, NAME_LENGTH
    call CopyData
    ; enemy mon name -> wNameBuffer (the stream splices both)
    mov al, [ebp + wTradingWhichEnemyMon]
    mov esi, wEnemyPartySpecies
    movzx ecx, al
    add esi, ecx
    mov al, [ebp + esi]
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    mov esi, WillBeTradedText       ; ld hl, WillBeTradedText (flat stream)
    mov ebx, CC(1, 14)              ; bccoord 1, 14
    call TextCommandProcessor
    call SaveScreenTilesToBuffer1
    mov esi, CC(10, 7)              ; hlcoord 10, 7 (pret's box position;
    mov bh, 8                       ; lb bc, 8, 11 — the port two-option
    mov bl, 11                      ; path projects from its descriptor)
    mov byte [ebp + wTwoOptionMenuID], TRADE_CANCEL_MENU
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    call DisplayTextBoxID
    call LoadScreenTilesFromBuffer1
    mov al, [ebp + wCurrentMenuItem]
    test al, al                     ; and a
    jz .tradeConfirmed
    ; trade cancelled by us: send $1
    mov al, 1
    mov [ebp + wSerialExchangeNybbleSendData], al
    mov esi, CC(0, 12)
    mov bh, 4
    mov bl, 18
    call CableClub_TextBoxBorder
    mov eax, TradeCanceled
    mov esi, CC(1, 14)
    call PlaceString
    call Serial_PrintWaitingTextAndSyncAndExchangeNybble
    jmp .tradeCancelled
.tradeConfirmed:
    mov al, 2
    mov [ebp + wSerialExchangeNybbleSendData], al
    call Serial_PrintWaitingTextAndSyncAndExchangeNybble
    mov al, [ebp + wSerialSyncAndExchangeNybbleReceiveData]
    cmp al, 0xFF                    ; port: link died (serial.asm death hatch) —
    je cable_club_link_down         ; ff would pass the dec-al confirm test below
    dec al                          ; did the other person cancel ($1)?
    jnz .doTrade
    ; the other person cancelled
    mov esi, CC(0, 12)
    mov bh, 4
    mov bl, 18
    call CableClub_TextBoxBorder
    mov eax, TradeCanceled
    mov esi, CC(1, 14)
    call PlaceString
    jmp .tradeCancelled
.doTrade:
    ; player mon OT name -> wTradedPlayerMonOT
    mov al, [ebp + wTradingWhichPlayerMon]
    mov esi, wPartyMonOT            ; ld hl, wPartyMonOT
    call SkipFixedLengthTextEntries
    mov edx, wTradedPlayerMonOT
    mov bx, NAME_LENGTH
    call CopyData
    ; player mon OT id (big-endian, byte-by-byte as pret)
    mov esi, wPartyMon1Species      ; ld hl, wPartyMon1Species
    mov al, [ebp + wTradingWhichPlayerMon]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    add esi, MON_OTID               ; ld bc, MON_OTID / add hl, bc
    mov al, [ebp + esi]             ; ld a, [hli]
    mov [ebp + wTradedPlayerMonOTID], al
    inc esi
    mov al, [ebp + esi]
    mov [ebp + wTradedPlayerMonOTID + 1], al
    ; enemy mon OT name + id
    mov al, [ebp + wTradingWhichEnemyMon]
    mov esi, wEnemyMonOT
    call SkipFixedLengthTextEntries
    mov edx, wTradedEnemyMonOT
    mov bx, NAME_LENGTH
    call CopyData
    mov esi, wEnemyMons
    mov al, [ebp + wTradingWhichEnemyMon]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    add esi, MON_OTID
    mov al, [ebp + esi]
    mov [ebp + wTradedEnemyMonOTID], al
    inc esi
    mov al, [ebp + esi]
    mov [ebp + wTradedEnemyMonOTID + 1], al
    ; species bookkeeping + the swap
    mov al, [ebp + wTradingWhichPlayerMon]
    mov [ebp + wWhichPokemon], al
    mov esi, wPartySpecies
    movzx ecx, al                   ; ld b, 0 / ld c, a / add hl, bc
    add esi, ecx
    mov al, [ebp + esi]
    mov [ebp + wTradedPlayerMonSpecies], al
    mov dh, PIKAHAPPY_TRADE         ; farcall_ModifyPikachuHappiness: ld d, kind
    call ModifyPikachuHappiness
    xor al, al
    mov [ebp + wRemoveMonFromBox], al
    call RemovePokemon
    mov al, [ebp + wTradingWhichEnemyMon]
    mov bl, al                      ; ld c, a (reused below for the struct copy)
    mov [ebp + wWhichPokemon], al
    mov esi, wEnemyPartySpecies
    movzx ecx, al                   ; ld d, 0 / ld e, a / add hl, de
    add esi, ecx
    mov al, [ebp + esi]
    mov [ebp + wCurPartySpecies], al
    mov esi, wEnemyMons
    mov al, bl                      ; ld a, c
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov edx, wLoadedMon
    mov bx, PARTYMON_STRUCT_LENGTH
    call CopyData                   ; the 44-byte struct verbatim (offset 7 incl.)
    call AddEnemyMonToPlayerParty
    mov al, [ebp + wPartyCount]
    dec al
    mov [ebp + wWhichPokemon], al   ; the newly added slot
    mov al, 1                       ; ld a, TRUE
    mov [ebp + wForceEvolution], al
    mov al, [ebp + wTradingWhichEnemyMon]
    mov esi, wEnemyPartySpecies
    movzx ecx, al
    add esi, ecx
    mov al, [ebp + esi]
    mov [ebp + wTradedEnemyMonSpecies], al
    ; fade into the trade jingle (both sides play the full track locally)
    mov al, 10
    mov [ebp + wAudioFadeOutControl], al
    mov al, MUSIC_SAFARI_ZONE_BANK  ; ld a, BANK(Music_SafariZone)
    mov [ebp + wAudioSavedROMBank], al
    mov al, MUSIC_SAFARI_ZONE
    mov [ebp + wNewSoundID], al
    call PlaySound
    mov bl, 100
    call DelayFrames
    call ClearScreen
    call LoadHpBarAndStatusTilePatterns
    xor al, al
    mov [ebp + wUnusedFlag], al
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, USING_EXTERNAL_CLOCK
    je .usingExternalClock
    call InternalClockTradeAnim     ; pret predef (header banking DEVIATION)
    jmp .tradeCompleted
.usingExternalClock:
    call ExternalClockTradeAnim     ; pret predef
.tradeCompleted:
    call TryEvolvingMon             ; callfar
    call ClearScreen
    call LoadTrainerInfoTextBoxTiles
    call Serial_PrintWaitingTextAndSyncAndExchangeNybble   ; post-anim resync
    mov bl, 40
    call DelayFrames
    call Delay3
    mov bh, SET_PAL_OVERWORLD
    call RunPaletteCommand
    mov esi, CC(0, 12)
    mov bh, 4
    mov bl, 18
    call CableClub_TextBoxBorder
    mov eax, TradeCompleted
    mov esi, CC(1, 14)
    call PlaceString
    call SavePartyAndDexData        ; pret predef — allows reset into Pokecenter
    ; DEVIATION{class=HAL; pret=engine/link/cable_club.asm:TradeCenter_Trade; behavior=call SramStoreImage after SavePartyAndDexData so the traded party reaches the .dsv file; evidence=on GB hardware SavePartyAndDexData's SRAM writes are instantly durable but the port's SavePartyAndDexData only updates the resident image - SramStoreImage is the declared disk-boundary seam and only SaveGameData calls it (src/engine/menus/save.asm:738), so without this call a reset after a link trade loses the traded mon; lifetime=permanent flat SRAM model, same seam contract as SaveGameData}
    call SramStoreImage
    mov bl, 50
    call DelayFrames
    xor al, al
    mov [ebp + wTradeCenterPointerTableIndex], al
    jmp CableClub_DoBattleOrTradeAgain
.tradeCancelled:
    mov bl, 100
    call DelayFrames
    xor al, al                      ; TradeCenter_SelectMon
    mov [ebp + wTradeCenterPointerTableIndex], al
    jmp CallCurrentTradeCenterFunction

; ---------------------------------------------------------------------------
; WillBeTradedText — pret's text_far wrapper (data; stream body is the
; generated _WillBeTradedText in assets/cable_club_text.inc).
; TradeCompleted / TradeCanceled are Tier-1 data in the same .inc.
; ---------------------------------------------------------------------------
WillBeTradedText:
    text_far _WillBeTradedText
    text_end

; TradeCenterPointerTable — in section .data above (dd flat pointers)

; ---------------------------------------------------------------------------
; CableClub_Run — pret engine/link/cable_club.asm:899. The predef hook
; polled by WaitForTextScrollButtonPress (src/home/joypad2.asm) every
; scroll-wait frame; dispatches when a table gameboy armed wLinkState.
; ---------------------------------------------------------------------------
CableClub_Run:
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_START_TRADE
    je .doBattleOrTrade
    cmp al, LINK_STATE_START_BATTLE
    je .doBattleOrTrade
    cmp al, LINK_STATE_RESET        ; this is never used (pret comment)
    jne .ret                        ; ret nz
    call EmptyFunc                  ; pret predef
    jmp Init
.ret:
    ret
.doBattleOrTrade:
    call CableClub_DoBattleOrTrade
    ; --- repoint the current tileset to Club_GFX / Club_Coll ---
    ; pret writes ROM pointers into wTilesetGfxPtr/wTilesetCollisionPtr; the
    ; port keeps the current tileset's data in fixed EBP slots (OW_GFX_GBADDR/
    ; OW_COLL_GBADDR — src/engine/overworld/tilesets.asm), so the pointer
    ; writes become a slot-content refresh for tileset CLUB from the same
    ; generated tables LoadTilesetHeader reads, plus the tile-cache arm.
    ; The pointer bytes themselves are re-written with the (constant) slot
    ; addresses, exactly as LoadTilesetHeader leaves them.
    push esi
    push edi
    push ecx
    mov esi, [TilesetGfxPtrs + CLUB_TILESET * 4]
    lea edi, [ebp + OW_GFX_GBADDR]
    mov ecx, [TilesetGfxSizes + CLUB_TILESET * 4]
    rep movsb
    mov esi, [TilesetCollPtrs + CLUB_TILESET * 4]
    lea edi, [ebp + OW_COLL_GBADDR]
    mov ecx, 64
    rep movsb
    mov byte [g_tilecache_dirty], 1
    pop ecx
    pop edi
    pop esi
    mov byte [ebp + wTilesetBank], 0x01   ; TODO-HW: banking no-op (flat model)
    mov word [ebp + wTilesetGfxPtr], OW_GFX_GBADDR
    mov word [ebp + wTilesetCollisionPtr], OW_COLL_GBADDR
    xor al, al
    mov [ebp + wGrassRate], al
    inc al                          ; LINK_STATE_IN_CABLE_CLUB
    mov [ebp + wLinkState], al
    mov [ebp + hJoy5], al
    mov al, 10
    mov [ebp + wAudioFadeOutControl], al
    mov al, MUSIC_CELADON_BANK      ; ld a, BANK(Music_Celadon)
    mov [ebp + wAudioSavedROMBank], al
    mov al, MUSIC_CELADON
    mov [ebp + wNewSoundID], al
    jmp PlaySound                   ; jp

; ---------------------------------------------------------------------------
; EmptyFunc — pret engine/link/cable_club.asm:936 (a predef table row).
; ---------------------------------------------------------------------------
EmptyFunc:
    ret

; ---------------------------------------------------------------------------
; Diploma_TextBoxBorder — pret engine/link/cable_club.asm:939 (predef
; wrapper): load the staged predef registers, fall into the border drawer.
; ---------------------------------------------------------------------------
Diploma_TextBoxBorder:
    call GetPredefRegisters
    ; fall through

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
    mov al, CHAR_SPACE
    call CableClub_DrawHorizontalLine
    mov byte [edi + ecx + 1], 0x77  ; border right vertical line tile
    add edi, [text_row_stride]
    ; 8-BIT counter: pret is `dec b / jr nz` (engine/link/cable_club.asm:965), so a
    ; zero height draws 256 rows and STOPS. See the "Preserve Counter WIDTH" rule.
    ; Not a live defect — every caller passes a literal (lb bc, 2, 12 / 2, 18) — but
    ; the bound belongs in the code, not in the call sites. Same shape as
    ; TextBoxBorder, which DID fault (dd68f32d).
    dec dl
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
    ; 8-BIT counter — pret's CableClub_DrawHorizontalLine counts in an 8-bit
    ; register, so a zero width places 256 and stops rather than running ~4 billion
    ; times off the end of the allocation. See "Preserve Counter WIDTH".
    dec cl
    jnz .dl_loop
    pop edi
    pop ecx
    ret

; ---------------------------------------------------------------------------
; LoadTrainerInfoTextBoxTiles — pret engine/link/cable_club.asm:983.
; The 9-tile trainer_info.2bpp set -> vChars2 $76 ($76-$7E: the cable-club
; border tiles). Source: tc_box_tiles (+ the adjacent tc_bg_tile, asserted
; contiguous 9 tiles by gen_trainer_card_tiles.py — the count is pret's
; (End - Start) / TILE_SIZE = 9, generator-asserted).
; ---------------------------------------------------------------------------
LoadTrainerInfoTextBoxTiles:
    mov edx, tc_box_tiles           ; ld de, TrainerInfoTextBoxTileGraphics
    mov esi, GB_VCHARS2 + 0x76 * TILE_SIZE   ; ld hl, vChars2 tile $76
    mov bh, 0                       ; lb bc, BANK(...) — no-op (flat)
    mov bl, 9                       ; 9 tiles (generator-asserted count)
    jmp CopyVideoData               ; jp — arms g_tilecache_dirty itself
