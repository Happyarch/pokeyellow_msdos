; m1_3_pending_symbols.inc — TEMPORARY scaffold for M1.3 (home/text_script +
; home/predef_text) so the new sources assemble CHECK-ONLY *before* the root
; migrates these into the real includes.
;
; ROOT INTEGRATION: move every symbol below into gb_memmap.inc (WRAM/HRAM) or
; gb_constants.inc (constants), then DELETE this include and its %include line
; from text_script.asm / predef_text.asm. Nothing here is authoritative once the
; symbols live in the canonical includes.
;
; ─────────────────────────────────────────────────────────────────────────────
; Derivation of the WRAM addresses (clean-pret, matching the port memmap scheme):
;   The working-tree pret build (rgbasm 1.0.1) links WRAM uniformly shifted
;   +0x2EC vs upstream/clean pret (the branch's WRAM is ~748 bytes over budget in
;   the "Main Data"/"WRAM" region, so `make compare` fails at the Stack org).
;   The port's gb_memmap.inc uses CLEAN pret addresses (e.g. wCurMap=0xD35D,
;   wDoNotWait=0xCC3C, wFontLoaded=0xCFC3, wStatusFlags6=0xD731 — all verified).
;   I linked a trimmed ram.o (dropping the over-budget tail sections) and applied
;   clean = link − 0x2EC. The correction was cross-checked against FOUR symbols
;   already present in the port memmap (wDoNotWait, wFontLoaded, wCurMap,
;   wStatusFlags6, wCurMapTextPtr) — all matched exactly. See SUMMARY.md.
; ─────────────────────────────────────────────────────────────────────────────

; ---- WRAM vars MISSING from gb_memmap.inc (clean-pret addresses) ----
%ifndef wTextPredefFlag
wTextPredefFlag                         equ 0xCF11 ; pret ram/wram.asm:1194 (db)
%endif
%ifndef wSpriteIndex
wSpriteIndex                            equ 0xCF13 ; pret ram/wram.asm:1198 (db)
%endif
%ifndef wEnteringCableClub
wEnteringCableClub                      equ 0xCC47 ; pret ram/wram.asm:430  (db)
%endif
%ifndef wNextSafariZoneGateScript
wNextSafariZoneGateScript               equ 0xCF0D ; pret ram/wram.asm:1181 (db)
%endif
%ifndef wItemList
wItemList                               equ 0xCF7A ; pret ram/wram.asm:1265 (ds 16)
%endif
%ifndef wListMenuID
wListMenuID                             equ 0xCF93 ; pret ram/wram.asm:1291 (db)
%endif
%ifndef wUpdateSpritesEnabled
wUpdateSpritesEnabled                   equ 0xCFCA ; pret ram/wram.asm:1351 (db)
%endif
%ifndef wItemListPointer
wItemListPointer                        equ 0xD127 ; pret ram/wram.asm:1804 (dw)
%endif
%ifndef wNumSprites
wNumSprites                             equ 0xD4E0 ; pret ram/wram.asm:2097 (db)
%endif
%ifndef wMapSpriteData
wMapSpriteData                          equ 0xD4E3 ; pret ram/wram.asm:2104 (ds MAX_OBJECT_EVENTS*2)
%endif
%ifndef wSafariZoneGateCurScript
wSafariZoneGateCurScript                equ 0xD61E ; pret ram/wram.asm:2222 (db)
%endif
%ifndef wSafariSteps
wSafariSteps                            equ 0xD70C ; pret ram/wram.asm:2314 (dw)
%endif
%ifndef wNumSafariBalls
wNumSafariBalls                         equ 0xDA46 ; pret ram/wram.asm:2468 (db)
%endif
%ifndef wSprite01StateData2OrigFacingDirection
; fixed-org section ($C200 base), NO +0x2EC shift — matches port W_SPRITE_STATE_DATA_2
wSprite01StateData2OrigFacingDirection  equ 0xC219 ; pret: wSprite01StateData2 ($C210)+9
%endif

; ---- WRAM vars already in gb_memmap.inc, referenced by pret lowercase name ----
%ifndef wCurMap
wCurMap                                 equ 0xD35D ; = W_CUR_MAP (already aliased in memmap)
%endif
%ifndef wCurMapTextPtr
wCurMapTextPtr                          equ 0xD36B ; = W_CUR_MAP_TEXT_PTR
%endif
%ifndef wStatusFlags6
wStatusFlags6                           equ 0xD731 ; = W_STATUS_FLAGS_6
%endif
%ifndef wFontLoaded
wFontLoaded                             equ 0xCFC3 ; = W_FONT_LOADED
%endif
%ifndef wDoNotWaitForButtonPressAfterDisplayingText
wDoNotWaitForButtonPressAfterDisplayingText equ 0xCC3C
%endif

; ---- HRAM: port REMAPS HRAM to its own scheme (hTextID=0xFF8C != pret 0xff82). ----
; Aliases onto existing port H_* equs; the one genuinely-missing slot
; (hSavedMapTextPtr) needs a root-assigned free HRAM byte-pair in the PORT scheme.
%ifndef hTextID
hTextID                                 equ 0xFF8C ; already in memmap
%endif
%ifndef hSpriteIndex
hSpriteIndex                            equ 0xFF8C ; ASSERT hSpriteIndex == hTextID (same slot)
%endif
%ifndef hItemPrice
hItemPrice                              equ 0xFF8B ; = H_ITEM_PRICE (3 bytes)
%endif
%ifndef hLoadedROMBank
hLoadedROMBank                          equ 0xFFB8 ; = H_LOADED_ROM_BANK
%endif
%ifndef hFrameCounter
hFrameCounter                           equ 0xFFD5 ; = H_FRAME_COUNTER
%endif
%ifndef hAutoBGTransferEnabled
hAutoBGTransferEnabled                  equ 0xFFBA ; = H_AUTO_BG_TRANSFER_EN
%endif
%ifndef hWY
hWY                                     equ 0xFFB0 ; = H_WY
%endif
%ifndef hJoyHeld
hJoyHeld                                equ 0xFFB4 ; = H_JOY_HELD
%endif
; MISSING slot — ROOT must allocate a free 2-byte HRAM pair in the port scheme:
%ifndef hSavedMapTextPtr
hSavedMapTextPtr                        equ 0xFF8E ; PLACEHOLDER (2 bytes); pret hram.asm:380 (dw)
%endif

; ---- Constants MISSING from gb_constants.inc ----
%ifndef BIT_TEXT_PREDEF
BIT_TEXT_PREDEF                         equ 0      ; pret constants/ram_constants.asm:21
%endif
%ifndef TEXT_START_MENU
TEXT_START_MENU                         equ 0x00   ; pret constants/text_constants.asm:29
%endif
%ifndef TEXT_MON_FAINTED
TEXT_MON_FAINTED                        equ 0xD0
%endif
%ifndef TEXT_BLACKED_OUT
TEXT_BLACKED_OUT                        equ 0xD1
%endif
; TEXT_REPEL_WORE_OFF (0xD2) already in gb_constants.inc
%ifndef TEXT_SAFARI_GAME_OVER
TEXT_SAFARI_GAME_OVER                   equ 0xD3
%endif
%ifndef TEXT_PIKACHU_ANIM
TEXT_PIKACHU_ANIM                       equ 0xD4
%endif
; TX_SCRIPT_* — pret macros/scripts/text.asm:185-236
%ifndef TX_SCRIPT_POKECENTER_NURSE
TX_SCRIPT_POKECENTER_NURSE              equ 0xFF
%endif
%ifndef TX_SCRIPT_MART
TX_SCRIPT_MART                          equ 0xFE
%endif
%ifndef TX_SCRIPT_BILLS_PC
TX_SCRIPT_BILLS_PC                      equ 0xFD
%endif
%ifndef TX_SCRIPT_PLAYERS_PC
TX_SCRIPT_PLAYERS_PC                    equ 0xFC
%endif
%ifndef TX_SCRIPT_POKECENTER_PC
TX_SCRIPT_POKECENTER_PC                 equ 0xF9
%endif
%ifndef TX_SCRIPT_PRIZE_VENDOR
TX_SCRIPT_PRIZE_VENDOR                  equ 0xF7
%endif
%ifndef TX_SCRIPT_CABLE_CLUB_RECEPTIONIST
TX_SCRIPT_CABLE_CLUB_RECEPTIONIST       equ 0xF6
%endif
%ifndef TX_SCRIPT_VENDING_MACHINE
TX_SCRIPT_VENDING_MACHINE               equ 0xF5
%endif
%ifndef BIT_FLY_WARP
BIT_FLY_WARP                            equ 3      ; wStatusFlags6 bit (ram_constants.asm)
%endif
%ifndef BIT_ALWAYS_ON_BIKE
BIT_ALWAYS_ON_BIKE                      equ 5      ; wStatusFlags6 bit
%endif
%ifndef PRICEDITEMLISTMENU
PRICEDITEMLISTMENU                      equ 0x02   ; constants/list_constants.asm:5
%endif
%ifndef NUM_SPRITESTATEDATA_STRUCTS
NUM_SPRITESTATEDATA_STRUCTS             equ 16     ; constants/map_object_constants.asm:41
%endif
%ifndef SPRITESTATEDATA1_LENGTH
SPRITESTATEDATA1_LENGTH                 equ 0x10   ; = SPRITESTATEDATA_STRUCT_SIZE
%endif
