; overworld.asm — home-bank overworld helpers, at their pret mirror.
;
; Source: home/overworld.asm (pret/pokeyellow). Started at the menu-intro review
; (2026-07-23) to retire relocations: CheckForUserInterruption (was a dedicated
; home/check_user_interruption.asm), IsSpriteInFrontOfPlayer/-2 (were in
; engine/overworld/overworld.asm), SwitchToMapRomBank (was in home/bankswitch.asm),
; and the complete IsSpriteOrSignInFrontOfPlayer (R-002 retirement, 2026-07-23 —
; sign branch + counter-range extension + fallthrough into the sprite scan;
; a sign-branch-only version previously lived in engine/overworld/overworld.asm).
; pret home/overworld.asm's REMAINING labels still live in
; engine/overworld/overworld.asm (the port's historical home for them — legacy
; relocation debt, see tools/pret_label_allowlist.json); move them here when
; touched.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI; GB mem = [ebp+SYM].
;
; Build: nasm -f coff -I include/ -o overworld.o overworld.asm

bits 32

%include "gb_memmap.inc"
%include "assets/script_constants.inc"; shared constants (%define: emits no COFF symbol)
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "assets/audio_constants.inc"   ; SFX_COLLISION / MUSIC_* (audio engine is live)
%include "assets/map_dims.inc"          ; map-id + tileset-id constants (OAKS_LAB/CINNABAR_GYM/SHIP_PORT, OW-A.6)
%include "assets/event_constants.inc"   ; EVENT_* bit indices (EVENT_2A7, OW-A.6)
%include "events.inc"                   ; CheckEvent/SetEvent/ResetEvent over wEventFlags

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's, read from
; pokeyellow.sym (00:d73b, 00:d365) - not inferred. Defined locally because the
; transpiled elevator scripts define wWarpedFromWhichMap bare, so a central
; definition in gb_memmap.inc would collide with them.

; file-local constants carried in with the routines that read them
MAP_ROCKET_HIDEOUT_B1F  equ 0xC7
MAP_ROCKET_HIDEOUT_B2F  equ 0xC8
MAP_ROCKET_HIDEOUT_B4F  equ 0xCA
MAP_ROCK_TUNNEL_1F      equ 0x52
MAP_SS_ANNE_3F          equ 0x61
PLAYER_HALF_BYTES equ PLAYER_HALF_TILES * TILE_SIZE   ; 192 bytes ($C0)
PLAYER_HALF_TILES equ 12                       ; 12 tiles per VRAM half
STANDING_TILE_OFF   equ wTileMap + PLAYER_STANDING_ROW * SCREEN_TILES_W + PLAYER_STANDING_COL
TILESET_PLATEAU     equ 23          ; Route 23 / Indigo Plateau
TILESET_SHIP        equ 13          ; S.S. Anne interior
TILESET_SHIP_PORT   equ 14          ; Vermilion Port
W_D472                      equ 0xE240   ; [WRAM-expansion shifted]
W_PIKACHU_SPAWN_STATE_FLAGS equ 0xE23F   ; [WRAM-expansion shifted]
OVERWORLD_DOOR_TILE         equ 0x0B   ; pret: door tile in tileset 0 (PlayMapChangeSound)

extern DelayFrame                    ; src/home/vblank.asm
extern LoadGBPal                     ; src/home/fade.asm — reload rBGP/rOBP0/rOBP1
                                     ; from FadePal4 - wMapPalOffset
extern JoypadLowSensitivity          ; src/home/joypad2.asm — writes hJoy5
extern BankswitchCommon              ; home/bankswitch2.asm — AL = bank (flat no-op)
extern GetTileAndCoordsInFrontOfPlayer ; engine/overworld/player_state.asm (predef
extern BikeRidingTilesets                    ; src/data/tilesets/bike_riding_tilesets.asm
extern DoBoulderDustAnimation       ; src/engine/overworld/push_boulder.asm
extern HandleLedges                    ; src/engine/overworld/ledges.asm
extern IsPlayerCharacterBeingControlledByGame ; src/home/npc_movement.asm (real, linked — OW-A.6)
extern IsPlayerFacingEdgeOfMap                    ; src/engine/overworld/player_state.asm
extern IsWarpTileInFrontOfPlayer                    ; src/engine/overworld/player_state.asm
extern MapScriptPointers                  ; assets/map_scripts.inc
extern TrainerMapScript                   ; src/scripts/trainer_map_script.asm (Stage 1b sight gate)
extern PlayDefaultMusic             ; src/home/audio.asm (real gateway)
extern RedBikeSprite                    ; src/home/player_gfx.asm
extern RunNPCMovementScript         ; src/home/npc_movement.asm
extern SeelSprite                    ; src/home/player_gfx.asm
extern SurfingPikachuSprite                    ; src/home/player_gfx.asm
extern TryPushingBoulder            ; src/engine/overworld/push_boulder.asm
extern _HandleMidJump                    ; src/engine/overworld/player_animations.asm
extern InitBattle                     ; engine/battle/init_battle.asm — opponent dispatch + full battle
extern g_tilecache_dirty            ; src/ppu/ppu.asm — arm tile-cache re-decode
extern player_sprite                ; == RedSprite (walking)

; --- relocated from src/engine/overworld/overworld.asm (unit 6a) ---
extern ApplyMapBorderOverrides            ; src/engine/overworld/overworld.asm
extern DisableLCD                         ; src/home/lcd.asm
extern EnableLCD                          ; src/home/lcd.asm
extern FarCopyData                        ; src/home/copy.asm
extern FillMemory                         ; src/home/copy2.asm
extern GBPalNormal                        ; src/home/palettes.asm
extern InitMapSprites                     ; src/home/palettes.asm
extern LoadTextBoxTilePatterns            ; src/home/load_font.asm
extern LoadTilesetHeader                  ; src/engine/overworld/tilesets.asm
extern StageIndoorMapBlk                  ; src/engine/overworld/overworld.asm
extern SafariZoneCheckSteps               ; src/engine/events/hidden_events/safari_game.asm
extern SafariZoneCheck                    ; src/engine/events/hidden_events/safari_game.asm
extern LoadWildData                       ; src/engine/overworld/wild_mons.asm
extern MapTextTablePointers               ; assets/npc_dialogs/all_dialogs.inc
extern PlayDefaultMusicFadeOutCurrent     ; src/home/audio.asm
extern PlaySound                          ; src/home/audio.asm
extern RefreshCollisionTileMap            ; src/engine/overworld/overworld.asm
extern ReloadMapSpriteTilePatterns         ; src/home/reload_sprites.asm
extern RunPaletteCommand                  ; src/home/palettes.asm
extern SetMapSpecificScriptFlagsOnMapReload ; src/engine/overworld/specific_script_flags.asm
extern UpdateMusic6Times                  ; src/home/audio.asm
extern SchedulePikachuSpawnForAfterText   ; src/engine/pikachu/pikachu_follow.asm
extern Func_fcc08                         ; src/engine/pikachu/pikachu_follow.asm
extern SetPikachuSpawnOutside             ; src/engine/pikachu/pikachu_follow.asm
extern SetPikachuSpawnWarpPad             ; src/engine/pikachu/pikachu_follow.asm
extern SetPikachuSpawnBackOutside         ; src/engine/pikachu/pikachu_follow.asm
extern IsPlayerStandingOnWarpPadOrHole     ; src/engine/overworld/player_animations.asm
extern IsPlayerStandingOnWarp              ; src/engine/overworld/player_state.asm (MapEntryAfterBattle)
extern GBFadeInFromWhite                   ; src/home/fade.asm (MapEntryAfterBattle)
extern h_load_sprite_temp1                ; src/engine/overworld/overworld.asm
extern h_load_sprite_temp2                ; src/engine/overworld/overworld.asm
extern hide_window                        ; src/ppu/ppu.asm
extern wMapSpriteData                     ; src/engine/overworld/map_sprites.asm
extern wMapSpriteExtraData                ; src/engine/overworld/map_sprites.asm
extern w_map_text_table_ptr               ; src/engine/overworld/map_sprites.asm
extern MapHeaderPointers            ; assets/map_headers.inc (map_headers.asm TU)
extern MapSongBanks                 ; src/data/maps/songs.asm (assets/map_songs.inc)
extern OVERWORLD_BLOCKS_SIZE        ; assets/overworld_blocks.inc (overworld.asm TU)

; --- relocated from src/engine/overworld/overworld.asm (unit 6b) ---
extern AnyPartyAlive                      ; src/engine/battle/core.asm
extern CheckForHiddenEventOrBookshelfOrCardKeyDoor ; src/home/hidden_events.asm
extern CheckForceBikeOrSurf               ; src/engine/overworld/player_state.asm
extern CheckNPCInteraction                ; src/engine/overworld/map_sprites.asm
extern CheckTrainerSight                  ; src/engine/overworld/map_sprites.asm
extern ClearVariablesOnEnterMap           ; src/engine/overworld/clear_variables.asm
extern DebugDumpMemory                    ; src/debug/debug_dump.asm
extern Delay3                             ; src/home/palettes.asm
extern DelayFrames                        ; src/home/delay.asm
extern DisplayStartMenu                   ; src/home/start_menu.asm
extern DoSignInteraction                  ; src/engine/overworld/overworld.asm
extern DumpBackbuffer                     ; src/debug/debug_dump.asm
%ifdef DEBUG_TRADE_GOLDEN
extern trade_golden_dump_armed            ; src/debug/debug_dump.asm — armed by Route2TradeHouse shim
%endif
%ifdef DEBUG_PRINT_SURF_CANCEL
extern print_surf_dump_armed              ; src/debug/debug_dump.asm — armed by SummerBeachHouse shim
%endif
%ifdef DEBUG_POKECENTER_HEAL
extern pokecenter_heal_dump_armed         ; src/debug/debug_dump.asm
%endif
%ifdef DEBUG_VENDING
extern vending_dump_armed                 ; src/debug/debug_dump.asm
%endif
%ifdef DEBUG_PRIZE_CORNER
extern prize_corner_dump_armed            ; src/debug/debug_dump.asm
%endif
%ifdef DEBUG_POKEMART
extern pokemart_dump_armed                ; src/debug/debug_dump.asm
%endif
extern DumpSeamLog                        ; src/debug/debug_dump.asm
extern EnterMapAnim                       ; src/engine/overworld/player_animations.asm
extern GBFadeOutToBlack                   ; src/home/fade.asm
extern _GetTileAndCoordsInFrontOfPlayer   ; src/engine/overworld/player_state.asm (non-predef entry)
extern CheckPikachuFollowingPlayer        ; src/home/pikachu.asm — ZF as bit 1,[hl] (ZF=1 => following)
extern IsNextTileShoreOrWater             ; src/engine/items/item_effects.asm
extern IsPlayerStandingOnDoorTileOrWarpTile ; src/engine/overworld/player_state.asm
extern IsPlayerTalkingToPikachu            ; src/engine/pikachu/pikachu_emotions.asm
extern LoadSpinnerArrowTiles               ; src/engine/overworld/spinners.asm (IsSpinning tail)
extern MarkTownVisitedAndLoadToggleableObjects ; src/engine/overworld/toggleable_objects.asm
extern LoadToggleableObjectData            ; src/engine/overworld/unused_load_toggleable_object_data.asm
extern IsSurfingPikachuInParty            ; src/home/map_objects.asm
extern IsTilePassable                     ; src/home/copy2.asm
extern LoadDestinationMapData                ; src/engine/overworld/overworld.asm
extern PrepareForSpecialWarp              ; src/engine/overworld/special_warps.asm
extern PrepareNewGameDebug                ; src/engine/debug/debug_party.asm
extern ResetStatusAndHalveMoneyOnBlackout ; src/engine/events/black_out.asm
extern RunAnimObjectTest                  ; src/engine/movie/intro_yellow.asm
extern RunBagMenuTest                     ; src/debug/debug_dump.asm
extern RunBattleTest                      ; src/debug/debug_dump.asm
extern RunChooseNameTest                  ; src/engine/movie/oak_speech/oak_speech2.asm
extern RunCinematicMarkersTest            ; src/debug/debug_dump.asm
extern RunContinueSeedTest                ; src/engine/menus/save.asm
extern RunDrawBadgesTest                  ; src/engine/menus/draw_badges.asm
extern RunRealSaveTest                    ; src/engine/menus/save.asm
extern RunBoxSaveTest                     ; src/engine/menus/save.asm
extern RunBillsPCTest                     ; src/engine/pokemon/bills_pc.asm
extern RunLeaguePCTest                    ; src/engine/menus/league_pc.asm
%ifdef DEBUG_HOF
extern RunHallOfFameTest                  ; src/engine/movie/hall_of_fame.asm
%endif
%ifdef DEBUG_CREDITS
extern RunCreditsTest                     ; src/engine/movie/credits.asm
%endif
extern RunLearnMoveTest                   ; src/debug/debug_dump.asm
extern RunLinkCupsTest                    ; src/engine/menus/link_menu.asm
%ifdef DEBUG_NETTEST
extern RunNetPipeTest                     ; src/net/net_test.asm
%endif
%ifdef DEBUG_LINKCHECK
extern RunLinkCheck                       ; src/engine/link/cable_club_npc.asm
%endif
%ifdef DEBUG_TRADECHECK
extern RunTradeCheck                      ; src/engine/link/cable_club_npc.asm
%endif
%ifdef DEBUG_BATTLECHECK
extern RunBattleCheck                     ; src/engine/link/cable_club_npc.asm
%endif
%ifdef DEBUG_LINKBOOKCHECK
extern RunLinkBookCheck                   ; src/engine/link/cable_club_npc.asm
%endif
%ifdef DEBUG_KBDNAMECHECK
extern RunKbdNameCheckTest                ; src/engine/menus/naming_screen.asm
%endif
extern RunLinkMenuTest                    ; src/engine/menus/link_menu.asm
extern RunListMenuTest                    ; src/debug/debug_dump.asm
extern RunMainMenuTest                    ; src/engine/menus/main_menu.asm
extern RunMapScriptSightTest              ; src/debug/debug_dump.asm
extern RunNameMenuTest                    ; src/engine/movie/oak_speech/oak_speech2.asm
extern RunNamingScreenTest                ; src/engine/menus/naming_screen.asm
extern RunOakIntroTest                    ; src/debug/debug_dump.asm
extern RunTransitionDemo                  ; src/debug/debug_dump.asm (DEBUG_TRANSITION_DEMO)
extern RunOakPicTest                      ; src/engine/movie/oak_speech/oak_speech.asm
extern RunOakSlideTest                    ; src/engine/movie/oak_speech/oak_speech2.asm
extern RunOakSpeechCheckpoint             ; src/engine/movie/oak_speech/oak_speech.asm
extern RunOaksPCTest                      ; src/engine/menus/oaks_pc.asm
extern RunOptionsTest                     ; src/engine/menus/options.asm
extern RunPCTest                          ; src/engine/menus/pc.asm
extern RunPartyMenuTest                   ; src/debug/debug_dump.asm
extern RunPlayersPCTest                   ; src/engine/menus/players_pc.asm
extern RunPokedexEntryTest                ; src/engine/menus/pokedex.asm
extern RunPPRestoreTest                   ; src/debug/debug_dump.asm
extern RunFishTestSeed                    ; src/debug/debug_dump.asm
extern RunLedgeTestSeed                   ; src/debug/debug_dump.asm
extern RunSurfTestSeed                    ; src/debug/debug_dump.asm
extern RunTrainerRouteTestSeed            ; src/debug/debug_dump.asm (Stage 1b continuous gate)
extern RunTrainerRoute17TestSeed          ; src/debug/debug_dump.asm (ROUTE_17/ForceBikeDown witness)
extern RunGhostBattleTestSeed             ; src/debug/debug_dump.asm (4c ghost witness)
extern RunSafariGameOverTestSeed          ; src/debug/debug_dump.asm (safari walker)
extern CheckForHiddenEventOrBookshelfOrCardKeyDoor ; src/home/hidden_events.asm
extern RunPikaPicTest                     ; src/debug/debug_dump.asm
extern RunPokedexTest                     ; src/engine/menus/pokedex.asm
extern RunSavePerfTest                    ; src/engine/menus/save.asm (DEBUG_SAVEPERF)
extern RunSaveTest                        ; src/engine/menus/save.asm
extern RunSplashTest                      ; src/engine/movie/splash.asm
extern RunStatusScreenTest                ; src/debug/debug_dump.asm
extern RunStoneTest                       ; src/debug/debug_dump.asm
extern RunSurfingPikachuTest              ; src/debug/debug_dump.asm
extern RunTMHMTest                        ; src/debug/debug_dump.asm
extern RunTextBoxIDTest                   ; src/debug/debug_dump.asm
extern RunTextTest                        ; src/debug/debug_dump.asm
extern RunTrainerCardTest                 ; src/engine/menus/start_sub_menus.asm
extern RunYellowIntroTest                 ; src/engine/movie/intro_yellow.asm
extern RunYesNoTest                       ; src/debug/debug_dump.asm
extern SeamLogRecord                      ; src/debug/debug_dump.asm
extern SeamReseatView                     ; src/engine/overworld/overworld.asm
extern SeedDeterministicPlayerIdentity    ; src/engine/debug/debug_party.asm
extern SpecialEnterMap                    ; src/engine/menus/main_menu.asm
extern StopAllMusic                       ; src/home/audio.asm
extern StopAllSounds                      ; src/home/init.asm
extern TilePairCollisionsWater            ; src/data/tilesets/pair_collision_tile_ids.asm
extern TrainerEncounterFlow               ; src/engine/overworld/map_sprites.asm
extern UpdateSprites                      ; src/home/update_sprites.asm
extern WalkSpeedSample                    ; src/engine/overworld/overworld.asm
extern _AdvancePlayerSprite               ; src/engine/overworld/advance_player_sprite.asm
extern _LeaveMapAnim                      ; src/engine/overworld/player_animations.asm
extern g_audio_engine_online              ; src/home/audio.asm
extern pad_noclip                         ; src/input/joypad.asm
extern seam_reseat                        ; src/engine/overworld/overworld.asm
extern seam_seeded                        ; src/engine/overworld/overworld.asm
%ifdef DEBUG_TRAINER_ROUTE
extern trroute_seeded                     ; src/engine/overworld/overworld.asm (one-shot spawn seed latch)
%endif
%ifdef DEBUG_SEED_PARTY
%ifndef DEBUG_TRAINER_ROUTE
extern seed_party_done                    ; src/engine/overworld/overworld.asm (one-shot party seed latch)
%endif
%endif
extern set_single_window                  ; src/ppu/ppu.asm

; ---------------------------------------------------------------------------
; EnterMap — faithful map (re-)entry. Pret ref: home/overworld.asm:1-41 (EnterMap).
; Sets wJoyIgnore, loads the map, clears per-map scratch, then runs the fly/warp/
; battle-return reset ladder before falling into OverworldLoop. Re-entered on every
; warp/battle-return (OW-A.4(b) routes those paths back here).
;
; Tripwire (OW-A.4): the DEBUG dump harnesses stay IMMEDIATELY after LoadMapData,
; BEFORE the resets. Every FRAME.BIN-baseline DEBUG build (DEBUG_BASELINE/
; DEBUG_TRANSITION/DEBUG_WALK_NORTH) dump-and-exits inside its harness, so the resets
; below NEVER run under those builds — the 3 baselines must stay byte-identical,
; proving the render/transition path is untouched. Resets run only in the real build.
; ---------------------------------------------------------------------------
EnterMap:
    ; ld a, PAD_BUTTONS | PAD_CTRL_PAD / ld [wJoyIgnore], a
    mov byte [ebp + wJoyIgnore], PAD_BUTTONS | PAD_CTRL_PAD
%ifdef DEBUG_SPAWN
    ; DEBUG SPAWN: start the game on an arbitrary map at arbitrary coordinates.
    ; Must seed wCurMap/coords BEFORE LoadMapData reads them.
    ;
    ; This began life as the Viridian City <-> Route 22 seam-trace harness and
    ; was named for it; the SPAWN is the generally useful half and is now its own
    ; flag. The seam-specific halves are DEBUG_SEAMWALK (the scripted walk across
    ; the connection) and DEBUG_SEAMLOG (the per-frame SEAMLOG.BIN trace), both
    ; opt-in. Renamed 2026-08-15: the old name meant every plain playable build
    ; advertised itself as a seam harness and silently inherited its behaviour.
    ;
    ; *** BATTLES ARE NOT SUPPRESSED HERE. *** They used to be, because the seam
    ; trace wants determinism, and every interactive build inherited that — so a
    ; maintainer hand-testing battles found none and reasonably suspected the
    ; battle engine. Suppression now belongs to DEBUG_SEAMWALK, which is the
    ; thing that actually needs it.
%ifndef DEBUG_SPAWN_MAP
%define DEBUG_SPAWN_MAP 0x01               ; VIRIDIAN_CITY
%endif
%ifndef DEBUG_SPAWN_X
%define DEBUG_SPAWN_X 3                    ; 3 tiles from the west edge
%endif
%ifndef DEBUG_SPAWN_Y
%define DEBUG_SPAWN_Y 16                   ; inside Route 22's strip (Viridian y 8..25)
%endif
%ifndef DEBUG_SEAM_STEPS
%define DEBUG_SEAM_STEPS 8                ; x: 3,2,1,0,255(cross),then 3 more in Route 22
%endif
%ifndef DEBUG_SEAM_DIR
%define DEBUG_SEAM_DIR 0                  ; 0 = walk west, 1 = walk east
%endif
%if DEBUG_SEAM_DIR
%define SEAM_XVEC 0x01
%define SEAM_PDIR PLAYER_DIR_RIGHT
%define SEAM_FACE SPRITE_FACING_RIGHT
%else
%define SEAM_XVEC 0xFF
%define SEAM_PDIR PLAYER_DIR_LEFT
%define SEAM_FACE SPRITE_FACING_LEFT
%endif
    ; ONE-SHOT: OverworldLoop re-enters EnterMap on every map transition, so the
    ; seed must only fire on the first entry — otherwise a crossing teleports the
    ; player straight back to the spawn and the seam can never be left.
    cmp byte [seam_seeded], 0
    jne .seam_no_seed
    mov byte [seam_seeded], 1
%ifdef DEBUG_SEAMWALK
    ; BIT_NO_BATTLES suppresses EVERY poll-driven battle — trainer and forced
    ; battles included (the documented harness trap,
    ; regression-harness-no-battles-flag-wedges-trainer-battle). A scenario that
    ; NEEDS its battle (e.g. the Pallet Oak Pikachu catch — whose script does
    ; not wait on the battle, so suppression SILENTLY skips it rather than
    ; wedging) simply must not use DEBUG_SEAMWALK. Measured 2026-08-06: a
    ; DEBUG_START_MAP Oak-intro run "completed" with the catch battle silently
    ; suppressed by this very bit — a false witness for battle behavior.
    or byte [ebp + wStatusFlags4], (1 << BIT_NO_BATTLES)
%endif
    mov byte [ebp + wCurMap],  DEBUG_SPAWN_MAP
    mov byte [ebp + wXCoord],  DEBUG_SPAWN_X
    mov byte [ebp + wYCoord],  DEBUG_SPAWN_Y
    ; $FF = "not a warp arrival": LoadTilesetHeader's faithful tail otherwise
    ; re-derives the coords from the stale wDestinationWarpID on any dungeon-
    ; tileset map (e.g. a seeded Viridian Forest spawned at warp 0's (1,0)).
    mov byte [ebp + wDestinationWarpID], 0xFF
    ; An INDOOR spawn needs its .blk staged into the shared window, exactly as a
    ; warp arrival does. Only LoadDestinationMapData did that, and this path does
    ; not go through it — so a debug-spawned interior loaded its header and its
    ; tileset correctly and then drew a blank room off an empty block window. The
    ; symptom reads as missing map data or a missing tileset and is neither.
    call StageIndoorMapBlk
    mov byte [seam_reseat], 1             ; hand-seeded coords need the view ptr derived
.seam_no_seed:
%endif
%ifdef DEBUG_NO_WILD
    ; Debug: suppress wild encounters via the game's own flag (wStatusFlags4
    ; BIT_NO_BATTLES — the same gate NewBattle already honours). Re-set on every
    ; EnterMap so it survives StartNewGame's WRAM clear on a fully normal boot
    ; (title screen intact).
    ;
    ; *** "Trainer/forced battles are unaffected" — THAT CLAIM WAS FALSE, measured
    ; 2026-08-05 and corrected here. *** NewBattle tests BIT_NO_BATTLES BEFORE it
    ; reaches InitBattle and without looking at wCurOpponent, so the flag suppresses
    ; EVERY battle the poll drives, trainer battles included. This is faithful —
    ; pret's NewBattle (home/overworld.asm) has the identical guard order — so the
    ; bug was the comment, not the code.
    ; The failure it produces is nasty because it does not look like a suppressed
    ; battle: the trainer script still seeds wCurOpponent, NewBattle bails, and the
    ; poll retries every frame forever. Repro — TRAINER_ROUTE_PILOT=1 DEBUG_NO_WILD=1
    ; wedges on Route 3 with wIsInBattle=00 / wCurOpponent=$CA, and the trainer's
    ; textbox renders as overworld character sprites. Any harness that sets this
    ; flag and then expects a trainer battle will hit it; that is why
    ; DEBUG_START_MAP (which pulls in DEBUG_SPAWN) no longer sets that bit, so it cannot
    ; pilot one.
    ;
    ; THE GARBLED TEXTBOX IS NOT A SECOND BUG. vFont is shared with the walk tiles,
    ; so the post-dialog reload (CheckNPCInteraction .dialog_done ->
    ; ReloadWalkingTilePatterns + LoadPlayerSpriteGraphics) correctly puts walk
    ; tiles back into GB_VFONT once the trainer's text closes. The arithmetic
    ; matches exactly: LoadPlayerSpriteGraphics writes the 12 player walking poses
    ; to vFont tiles 0-11 (player_gfx.asm), and 9 NPC sprite slots x 12 tiles
    ; (SpriteVRAMAddresses, 192 bytes each, + $800 into the vFont region) fill
    ; tiles 12-119 -- 12 + 108 = the 120 measured slots, 128..247, no more and no
    ; less. Normally the battle takes the screen over immediately and nobody sees
    ; it; with the battle suppressed the stale text box stays on the tilemap and
    ; its $80+ glyph ids now index walk tiles. Fix the suppressed battle and the
    ; textbox is fine -- there is nothing to repair in the tile loading.
    or byte [ebp + wStatusFlags4], (1 << BIT_NO_BATTLES)
%endif
%ifdef DEBUG_SIGNTEXT
    ; Streamed-text gate (fidelity plan Stage 1b): stand next to the Pallet Town town
    ; sign and face it. The sign is `bg_event 7, 9, TEXT_PALLETTOWN_SIGN`
    ; (data/maps/objects/PalletTown.asm), i.e. X=7 Y=9, so the tile in front of the
    ; player must be (9,7).
    ; THE READING TILE IS (Y=9, X=8) FACING LEFT, *not* (10,7) facing UP: the tile
    ; below the sign is a flower ($03, absent from Overworld_Coll) and the real game
    ; cannot stand there. Seeding coords bypasses collision, so the port happily read
    ; the sign from a tile no player can occupy — and the mGBA golden, which has to
    ; WALK there, could not reproduce it (it blocks stepping onto (10,7)). The gate now
    ; stands where the game lets you stand, so both sides see the same screen.
    ; Overridable (SIGNTEXT_MAP/Y/X/DIR) so any map's sign can be driven headlessly —
    ; used to prove F-10 on Route 5, whose sign was one of the 7 that id 0 swallowed.
    ; Seeded BEFORE LoadMapData, which reads the coords (same rule as DEBUG_SPAWN).
    mov byte [ebp + wCurMap], SIGNTEXT_MAP   ; default PALLET_TOWN
    mov byte [ebp + wYCoord], SIGNTEXT_Y
    mov byte [ebp + wXCoord], SIGNTEXT_X
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SPAWN)
    ; An INDOOR SIGNTEXT_MAP needs its .blk staged exactly like DEBUG_HIDDENOBJ
    ; below (no-op for outdoor maps — the routine early-outs). Without it the
    ; room draws off an empty block window (measured 2026-08-22 seeding a
    ; Pokecenter for the link-receptionist smoke: blank screen).
    call StageIndoorMapBlk
%endif
%ifdef DEBUG_CABLECLUB
    ; Link-receptionist no-link gate (cable_club_nolink golden — link cable plan
    ; Stage 2 step 4): spawn on the Pokecenter talk tile below the receptionist
    ; (`object_event 11, 2, SPRITE_LINK_RECEPTIONIST, STAY, DOWN` — the defaults
    ; put the player at y=3, x=11 in PEWTER_POKECENTER, open floor per
    ; PewterPokecenter.blk + Pokecenter_Coll). The talk itself is driven by
    ; AUTOKEY_APRESS through the real OverworldLoop dispatch — see the
    ; post-LoadMapData block at the end of EnterMap.
    ; Seeded BEFORE LoadMapData, which reads the coords (same rule as DEBUG_SPAWN).
    mov byte [ebp + wCurMap], CABLECLUB_MAP
    mov byte [ebp + wYCoord], CABLECLUB_Y
    mov byte [ebp + wXCoord], CABLECLUB_X
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SPAWN)
    ; Every Pokecenter is INDOORS: stage the .blk into the shared window (same
    ; call and reason as DEBUG_HIDDENOBJ above).
    call StageIndoorMapBlk
    ; The receptionist's gate: without the pokedex CableClubNPC takes the
    ; "making preparations" branch, not the 90-frame race under test. The mGBA
    ; side seeds the same flag (cable_club_nolink.lua, seed.set_event).
    SetEvent EVENT_GOT_POKEDEX
%endif
%ifdef DEBUG_TRADE_GOLDEN
    ; in_game_trade golden (link cable plan Stage 3 step 4): spawn in
    ; ROUTE_2_TRADE_HOUSE one tile south of the GAMEBOY_KID NPC
    ; (`object_event 4, 1, SPRITE_GAMEBOY_KID, STAY, DOWN` —
    ; data/maps/objects/Route2TradeHouse.asm), open floor per
    ; Route2TradeHouse.blk decoded through the HOUSE tileset's collision list
    ; (the standard shop-counter arrangement every Mart/PC clerk in the game
    ; uses — NPC facing DOWN into the customer tile below it).
    ; Seeded BEFORE LoadMapData, which reads the coords (same rule as DEBUG_SPAWN).
    mov byte [ebp + wCurMap], TRADE_GOLDEN_MAP
    mov byte [ebp + wYCoord], TRADE_GOLDEN_Y
    mov byte [ebp + wXCoord], TRADE_GOLDEN_X
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SPAWN)
    ; ROUTE_2_TRADE_HOUSE is INDOORS: stage the .blk into the shared window
    ; (same call and reason as DEBUG_CABLECLUB above).
    call StageIndoorMapBlk
%endif
%ifdef DEBUG_PRINT_SURF_CANCEL
    ; print_surf_cancel golden (printer plan Stage 3): spawn in Summer Beach House
    ; in front of the printer at (y=2, x=13).
    mov byte [ebp + wCurMap], SUMMER_BEACH_HOUSE
    mov byte [ebp + wYCoord], 2
    mov byte [ebp + wXCoord], 13
    mov byte [ebp + wDestinationWarpID], 0xFF
    call StageIndoorMapBlk
    or byte [ebp + wPikachuSpawnStateFlags], (1 << BIT_PIKACHU_SPAWN_SURFING)
    or byte [ebp + wPikachuMapScriptFlags], (1 << 1)
%endif
%ifdef DEBUG_POKECENTER_HEAL
    ; pokecenter_heal golden: spawn in Viridian Pokecenter at (y=3, x=3) facing nurse across counter
    mov byte [ebp + wCurMap], 0x29          ; VIRIDIAN_POKECENTER ($29, not $2A which is VIRIDIAN_MART)
    mov byte [ebp + wYCoord], 3
    mov byte [ebp + wXCoord], 3
    mov byte [ebp + wDestinationWarpID], 0xFF
    call StageIndoorMapBlk
%endif
%ifdef DEBUG_VENDING
    ; vending_machine golden: spawn in Celadon Mart Roof at (y=2, x=10) facing vending machine
    mov byte [ebp + wCurMap], 0x7E          ; CELADON_MART_ROOF
    mov byte [ebp + wYCoord], 2
    mov byte [ebp + wXCoord], 10
    mov byte [ebp + wDestinationWarpID], 0xFF
    call StageIndoorMapBlk
%endif
%ifdef DEBUG_PRIZE_CORNER
    ; prize_corner golden: spawn in Celadon Prize Room at (y=3, x=2) facing vendor 1
    mov byte [ebp + wCurMap], 0x89          ; GAME_CORNER_PRIZE_ROOM
    mov byte [ebp + wYCoord], 3
    mov byte [ebp + wXCoord], 2
    mov byte [ebp + wDestinationWarpID], 0xFF
    call StageIndoorMapBlk
%endif
%ifdef DEBUG_POKEMART
    ; pokemart_buy_sell golden: spawn in Pewter Mart at (y=5, x=1) facing clerk
    mov byte [ebp + wCurMap], 0x38          ; PEWTER_MART
    mov byte [ebp + wYCoord], 5
    mov byte [ebp + wXCoord], 1
    mov byte [ebp + wDestinationWarpID], 0xFF
    call StageIndoorMapBlk
%endif
%ifdef DEBUG_PREDEFTEXT
    ; Predef-text gate (predef-text plan Stage 2 acceptance). Stand ON the SNES tile
    ; in Red's bedroom. pret: `hidden_event 3, 5, PrintRedSNESText, ANY_FACING`
    ; (data/events/hidden_events.asm), which the port's generator emits as
    ; `db 5, 3` = y 5, x 3 (assets/hidden_events.inc, HiddenEventsFor_REDS_HOUSE_2F).
    ; ANY_FACING, so no facing is seeded.
    ; Seeded BEFORE LoadMapData, which reads the coords (same rule as DEBUG_SPAWN).
    mov byte [ebp + wCurMap], REDS_HOUSE_2F
    mov byte [ebp + wYCoord], 5
    mov byte [ebp + wXCoord], 3
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SPAWN)
%endif
%ifdef DEBUG_HIDDENOBJ
    ; Generic hidden-object gate. DEBUG_PREDEFTEXT above is the same shape welded to
    ; one prop (Red's SNES); this is the parameterised form, so a scenario that only
    ; differs by WHICH prop it reads does not need its own copy of the seed. Same
    ; convention as SIGNTEXT_MAP/Y/X/DIR.
    ;
    ; The scenario's own DEBUG_<X> flag still exists and is what selects
    ; GBSTATE_SCENARIO (assets/scenario_registry.inc dispatches on the gate symbol,
    ; so the id cannot be shared even though the seed can). Its Makefile block sets
    ; DEBUG_HIDDENOBJ plus these defines.
    ;
    ; This gate does NOT call the handler. It seeds the player onto the prop's tile
    ; and lets AUTOKEY_APRESS drive a real A press through OverworldLoop into the
    ; hidden-object dispatch, so the routine under test is REACHED BY PRODUCTION
    ; rather than reproduced here (bug-class-false-witness-scenario instance 3: a
    ; harness that rebuilds the sequence carries its own copy of the very omission
    ; it is meant to detect).
    ;
    ; Seeded BEFORE LoadMapData, which reads the coords (same rule as DEBUG_SPAWN).
    mov byte [ebp + wCurMap], HIDDENOBJ_MAP
    mov byte [ebp + wYCoord], HIDDENOBJ_Y
    mov byte [ebp + wXCoord], HIDDENOBJ_X
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SPAWN)
    ; Every prop this gate reaches is INDOORS, and an indoor spawn must stage its
    ; .blk into the shared INDOOR_BLK_GBADDR window itself: only
    ; LoadDestinationMapData (the warp path) does that, and a hand-seeded spawn does
    ; not go through it. Without this the room loads its header and tileset
    ; correctly and then draws off an EMPTY block window — measured here as a
    ; lilac checkerboard with the player alone on it, which reads as missing map
    ; data or a missing tileset and is neither. DEBUG_SPAWN carries the same call
    ; for the same reason (interior-maps-blocked-by-tileset-residency-not-blk).
    call StageIndoorMapBlk
    ; Optional event seeding. A prop handler that branches on an event flag (e.g.
    ; BillsHousePC's .doCellSeparator, gated on EVENT_BILL_SAID_USE_CELL_SEPARATOR)
    ; needs the branch selected before the dispatch runs. The mGBA side seeds the
    ; same flag through seed.set_event in the scenario's `before` hook, so both
    ; sides enter the handler on the same branch.
%ifdef HIDDENOBJ_EVENT
    SetEvent HIDDENOBJ_EVENT
%endif
%endif
%ifdef DEBUG_SAFARI_GAMEOVER
    ; Safari-Zone step-countdown gate (the safari_game_over golden). Unlike every
    ; gate above it, this one does not seed the player next to the thing under
    ; test — there is nothing to stand next to. The subject is a COMPLETED STEP,
    ; so the spawn only has to be somewhere the player can walk south from, and
    ; the walking is AUTOKEY_SAFARI_GAMEOVER's job.
    ;
    ; SAFARI_ZONE_CENTER (0xDC) at (y=1, x=4). DERIVED, not guessed, and the same
    ; tile the golden uses: decoding safari_zone_center_blk through forest_blocks
    ; and forest_coll, (1,4) and the three tiles below it are all passable. The
    ; golden's earlier (10,10) is blocked — the warp landed on the right map and
    ; the player never moved, so the counter never decremented and no game over
    ; fired. A spawn that cannot walk fails this scenario SILENTLY.
    ;
    ; Seeded BEFORE LoadMapData, which reads the coords (same rule as DEBUG_SPAWN).
    mov byte [ebp + wCurMap], SAFARI_GAMEOVER_MAP
    mov byte [ebp + wYCoord], SAFARI_GAMEOVER_Y
    mov byte [ebp + wXCoord], SAFARI_GAMEOVER_X
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SPAWN)
    ; 0xDC is at or above FIRST_INDOOR_MAP_ID (0x25), so its .blk lives in the
    ; shared INDOOR_BLK_GBADDR window and a hand-seeded spawn must stage it — only
    ; the warp path (LoadDestinationMapData) does that on its own. Same call and
    ; the same reason as DEBUG_SPAWN and DEBUG_HIDDENOBJ.
    call StageIndoorMapBlk
%endif
%ifdef DEBUG_MAPSCRIPT_SIGHT
    ; Map-script sight gate (map-script fidelity plan, Stage 3): spawn inside a
    ; trainer's view range on a driver-wired map, so the map's _Script engages on
    ; its own. Defaults are Route 3 (Y=6, X=12): ROUTE3_YOUNGSTER1 stands at
    ; (x=10, y=6) facing RIGHT with view range 2 (scripts/Route3.asm
    ; Route3TrainerHeader0), so the player is the second tile in its line of sight
    ; — far enough that TrainerWalkUpToPlayer has a step to take.
    ; Seeded BEFORE LoadMapData, which reads the coords (same rule as DEBUG_SPAWN).
    mov byte [ebp + wCurMap], MAPSCRIPT_MAP
    mov byte [ebp + wYCoord], MAPSCRIPT_Y
    mov byte [ebp + wXCoord], MAPSCRIPT_X
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SPAWN)
%endif
%ifdef DEBUG_TRAINER_ROUTE
    ; Continuous trainer-route gate (battle plan Stage 1b): the scenario that drives
    ; the REAL OverworldLoop all the way through sight -> battle -> return, which is
    ; exactly what 44/45/46 cannot do (they call StartTrainerBattle and InitBattle
    ; from a harness and never run the loop at all).
    ;
    ; Deliberately the SAME spawn as DEBUG_MAPSCRIPT_SIGHT above: Route 3 (Y=6,
    ; X=12), already inside ROUTE3_YOUNGSTER1's line of sight. Reusing a spawn that
    ; seven sight goldens already exercise keeps ENTRY out of the variable set — the
    ; loop choreography is what is under test. Walking in from an out-of-sight tile
    ; would additionally depend on the passability of Route 3 tiles nobody has
    ; measured, and a failure there would be indistinguishable from a choreography
    ; failure.
    ; Seeded BEFORE LoadMapData, which reads the coords (same rule as DEBUG_SPAWN).
    ;
    ; ONE-SHOT (same latch pattern and reason as DEBUG_SPAWN's seam_seeded above):
    ; the post-battle tail is `jmp EnterMap`, and pret's battle-return EnterMap
    ; deliberately does NOT rebuild sprite slots (LoadMapHeader skips InitSprites
    ; on BIT_BATTLE_OVER_OR_BLACKOUT — sprite data survives a battle because the
    ; player cannot have moved during one). An unguarded re-seed TELEPORTED the
    ; player inside exactly that window, desyncing every surviving NPC screen
    ; coordinate by the teleport delta; with the (separate) post-battle font
    ; freeze bug the desync then never healed, and no trainer could engage from
    ; his true sight line until a warp reload. Measured live + deterministically
    ; 2026-08-06 — regression-battle-second-trainer-wont-engage.
    cmp byte [trroute_seeded], 0
    jne .trroute_no_seed
    mov byte [trroute_seeded], 1
    mov byte [ebp + wCurMap], ROUTE_3
%ifdef PILOT_NEUTRAL
    ; Spawn OUT of every Route 3 sight line, so a hand-piloted session engages
    ; nobody until the player walks. Verified against ALL EIGHT Route 3 trainers
    ; (pret scripts/Route3.asm header ranges + data/maps/objects/Route3.asm,
    ; re-measured 2026-08-06): the only lines near the spawn row are trainer 0
    ; (10,6) RIGHT r2 -> x=11-12 at y=6 and trainer 1 (14,4) DOWN r3 -> x=14,
    ; y=5-7; trainer 2 (16,9) LEFT r2 -> x=14-15 at y=9; trainers 3-7 all sit at
    ; x>=19 (or x=33) and cannot reach x=13.
    ; WHY THIS EXISTS: with the normal spawn the player is ALREADY in trainer 0's
    ; sight, so engagement fires within a few hundred frames of boot — before an
    ; agent can attach the debugger and arm a breakpoint. The race is unwinnable;
    ; this removes it.
    ; (13,8) is MAINTAINER-CHOSEN (live, 2026-08-06): an arithmetic-picked (13,6)
    ; spawn put the player on the wrong spot when actually run, and the maintainer
    ; directed "two tiles down". Sight check for (13,8) against all eight headers:
    ; trainer 0 covers y=6 only, trainer 1 covers x=14 y=5-7, trainer 2 covers
    ; y=9 x=14-15 — all clear. Two prior tiles picked from map arithmetic ALONE
    ; were both wrong in different ways ((12,8): ledge in the walk path; (13,6):
    ; wrong spot live), so this tile is the measured one — do not "correct" it
    ; back from the pret data without a live run.
    mov byte [ebp + wYCoord], 8
    mov byte [ebp + wXCoord], 13
%else
    mov byte [ebp + wYCoord], 6
    mov byte [ebp + wXCoord], 12
%endif
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SPAWN)
.trroute_no_seed:
%endif
%ifdef DEBUG_TRAINER_ROUTE17
    ; ROUTE_17 / ForceBikeDown witness (map-script fidelity plan, third attempt).
    ;
    ; ForceBikeDown (src/home/overworld.asm, called from OverworldLoopLessDelay
    ; just before AreInputsSimulated) is faithful and faithdiff-clean, but a sight
    ; golden can NEVER witness it: RunMapScriptSightTest never enters
    ; OverworldLoopLessDelay, so it never reaches the joypad path the routine lives
    ; in (regression-overworld-forcebikedown-missing, measured twice). This gate is
    ; the third attempt, shaped like DEBUG_TRAINER_ROUTE: seed, then FALL THROUGH
    ; into the REAL OverworldLoop, which is the only loop that ever calls
    ; ForceBikeDown.
    ;
    ; Spawn tile is the ONE measured in both earlier route17_sight attempts:
    ; ROUTE17_BIKER10 (data/maps/objects/Route17.asm) stands at (x=10, y=118)
    ; facing DOWN with view range 4 (scripts/Route17.asm Route17TrainerHeader9),
    ; so (x=10, y=120) is two tiles inside its sight line — already visible the
    ; instant the map script runs, exactly as route17_sight seeded it. The
    ; divergence that killed both earlier attempts (wYCoord $79 vs $78,
    ; wTrainerScreenY $0C vs $1C — ground truth one tile further south by the time
    ; TrainerEngage locks the battle in) is ForceBikeDown drifting the player south
    ; every input-free frame while CheckFightingMapTrainers' approach sequence
    ; catches up; a harness that actually runs OverworldLoop should reproduce that
    ; drift instead of diverging from it. Reusing the measured tile keeps the
    ; comparison the mechanical "does this now match" check the map-script-tables
    ; note promised, not a fresh derivation.
    ; Seeded BEFORE LoadMapData, which reads the coords (same rule as DEBUG_SEAM).
    mov byte [ebp + wCurMap], ROUTE_17
    mov byte [ebp + wYCoord], 120
    mov byte [ebp + wXCoord], 10
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SEAM)
%endif
%ifdef DEBUG_SURF
    ; Surfboard gate (items-plan Stage 11): spawn on the Pallet Town shore tile that
    ; faces open water, so the scripted joypad can drive the REAL overworld loop
    ; through mount and dismount. Measured off the pret map data rather than guessed
    ; (maps/PalletTown.blk + gfx/blocksets/overworld.bst, OVERWORLD tileset):
    ;   (14,5) = $33  land, in Overworld_Coll  <- the player spawns here facing DOWN
    ;   (15,5) = $14  water                    <- mount target
    ;   (15,4) = $32  SHORE (in ShoreTiles)    <- surf LEFT onto it, still surfing
    ;   (15,3) = $2C  land, in Overworld_Coll  <- dismount target
    ; The shore tile is what makes a genuine dismount reachable at all:
    ; CollisionCheckOnWater auto-dismounts the moment the player moves toward
    ; passable LAND, so the only way to be surfing while FACING land is to be
    ; standing on a shore tile — IsNextTileShoreOrWater keeps the surf state on the
    ; way in. Seeded BEFORE LoadMapData, which reads the coords (same rule as
    ; DEBUG_SPAWN / DEBUG_MAPSCRIPT_SIGHT).
    mov byte [ebp + wCurMap], PALLET_TOWN
    mov byte [ebp + wYCoord], 14
    mov byte [ebp + wXCoord], 5
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SPAWN)
%endif
%ifdef DEBUG_FISH
    ; Fishing gate (items-plan Stage 11): the DEBUG_SURF spawn — Pallet (14,5),
    ; the $33 land tile facing the water tile (15,5) = $14 (see the measured
    ; tile map in the DEBUG_SURF block below). Nothing seeds
    ; wTileInFrontOfPlayer: the first USE runs against its boot value 0 (the
    ; FishingInit-failure branch), the bump before the second USE populates it
    ; with the water tile through the real collision check.
    mov byte [ebp + wCurMap], PALLET_TOWN
    mov byte [ebp + wYCoord], 14
    mov byte [ebp + wXCoord], 5
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SPAWN)
%endif
%ifdef DEBUG_LEDGE
    ; Ledge-hop gate (regression-overworld-ledge-hop-never-advanced): spawn on
    ; Route 1 one step above a south-facing ledge. Measured off the pret map data
    ; (maps/Route1.blk + gfx/blocksets/overworld.bst, OVERWORLD tileset):
    ;   (8,7)  = $2C  land, standing tile of the LedgeTiles ($2C,$37) row
    ;   (9,7)  = $37  the ledge tile itself (impassable on foot)
    ;   (10,7) = $2C  landing tile after the two-step hop
    ;   (11,7) = $2C  target of the post-teardown DOWN step
    ; Column 7 avoids both Route 1 NPCs (YOUNGSTER1 wanders UP_DOWN in column 5,
    ; YOUNGSTER2 LEFT_RIGHT on row 13) and the path has no grass tile, so no RNG
    ; can diverge the two sides. Seeded BEFORE LoadMapData (same rule as
    ; DEBUG_SPAWN / DEBUG_SURF).
    mov byte [ebp + wCurMap], ROUTE_1
    mov byte [ebp + wYCoord], 8
    mov byte [ebp + wXCoord], 7
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SPAWN)
%endif
%ifdef DEBUG_BATTLE_GHOST
    ; Ghost-battle gate (battle plan 4c's witness). Spawn on Route 1 column 7 —
    ; the SAME column the ledge block above already proves is free of both Route 1
    ; NPCs (YOUNGSTER1 wanders UP_DOWN in column 5, YOUNGSTER2 LEFT_RIGHT on row
    ; 13) and free of grass, so no wild-encounter roll can fire and diverge the
    ; two sides before the FORCED opponent does. (10,7) and (11,7) are both land
    ; ($2C) per that block's measurement off maps/Route1.blk, so the single DOWN
    ; step the autokey takes is legal and lands on plain ground.
    ; Seeded BEFORE LoadMapData (same rule as DEBUG_SPAWN / DEBUG_LEDGE).
    ;
    ; NOTE this deliberately does NOT reuse DEBUG_START_MAP: that pulls in
    ; DEBUG_SEAMWALK, which sets BIT_NO_BATTLES — the exact flag NewBattle tests
    ; before jumping to InitBattle, so it would suppress the battle under test.
    mov byte [ebp + wCurMap], ROUTE_1
    mov byte [ebp + wYCoord], 10
    mov byte [ebp + wXCoord], 7
    mov byte [ebp + wDestinationWarpID], 0xFF  ; "not a warp arrival" (see DEBUG_SPAWN)
%endif
%ifdef DEBUG_PALLET_OAK
    ; Oak-intro state gate: start on the Pallet north-exit tile that triggers
    ; PalletTownDefaultScript, then let RunOakIntroTest drive the stage boundary.
    mov byte [ebp + wCurMap], 0x00          ; PALLET_TOWN
    mov byte [ebp + wYCoord], 0
    mov byte [ebp + wXCoord], 10
    mov byte [ebp + wDestinationWarpID], 0xFF
%endif
    call LoadMapData
%ifdef DEBUG_SPAWN
    cmp byte [seam_reseat], 0
    je .seam_no_reseat
    mov byte [seam_reseat], 0
    call SeamReseatView                   ; LoadMapData does not derive the view ptr
.seam_no_reseat:
%ifndef DEBUG_SEAMWALK
    ; Default: no scripted walk. Fall through to the real OverworldLoop so the
    ; player drives with the keyboard and COLLISION IS LIVE (the scripted harness
    ; bypasses it, and its traces came back clean). Under DEBUG_SEAMLOG,
    ; vblank.asm samples every frame and pressing A writes SEAMLOG.BIN +
    ; FRAME.BIN and exits; without it, A stays an ordinary game button.
%else
    mov ecx, DEBUG_SEAM_STEPS
.seam_step:
    push ecx
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], SEAM_XVEC
    mov byte [ebp + wPlayerDirection],        SEAM_PDIR
    mov byte [ebp + wPlayerMovingDirection], SEAM_PDIR
    mov byte [ebp + W_SPRITE_PLAYER_FACING_DIR], SEAM_FACE
    mov byte [ebp + wWalkCounter], 8
.seam_frames:
    call UpdateSprites
    call AdvancePlayerSprite
    pushf                                 ; CF=1 => CheckMapConnections fired
    call DelayFrame
    call SeamLogRecord                    ; one sample per rendered frame
    popf
    jc .seam_crossed
    cmp byte [ebp + wWalkCounter], 0
    jne .seam_frames
    pop ecx
    dec ecx
    jnz .seam_step
    jmp .seam_done                        ; never reached the edge

.seam_crossed:
    ; Mimic OverworldLoop's .mapTransition: a crossing reloads the whole map.
    ; Keep walking afterwards so post-crossing oscillation is visible in the log.
    pop ecx
    call LoadMapData
    call SeamLogRecord                    ; marker: first sample on the new map
    mov ecx, DEBUG_SEAM_STEPS
.seam_after:
    push ecx
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], SEAM_XVEC
    mov byte [ebp + wPlayerDirection],        SEAM_PDIR
    mov byte [ebp + wPlayerMovingDirection], SEAM_PDIR
    mov byte [ebp + W_SPRITE_PLAYER_FACING_DIR], SEAM_FACE
    mov byte [ebp + wWalkCounter], 8
.seam_after_frames:
    call UpdateSprites
    call AdvancePlayerSprite
    call DelayFrame
    call SeamLogRecord
    cmp byte [ebp + wWalkCounter], 0
    jne .seam_after_frames
    pop ecx
    dec ecx
    jnz .seam_after
.seam_done:
    call DumpSeamLog                      ; SEAMLOG.BIN (returns)
    call DumpBackbuffer                   ; FRAME.BIN: the final screen — then exits
%endif ; DEBUG_SEAMWALK
%endif ; DEBUG_SPAWN
%ifdef DEBUG_PALLET_OAK
    call SeamReseatView
    call RunOakIntroTest                      ; dumps GBSTATE+FRAME and exits
%endif
%ifdef DEBUG_TRANSITION_DEMO
    call RunTransitionDemo                    ; cycles all 8 battle transitions forever
%endif
%ifdef DEBUG_DUMP
    call DebugDumpMemory     ; dump GB memory to DUMP.BIN, then exit (debug only)
%endif
%ifdef DEBUG_WALK_NORTH
    ; Walk-simulation harness: drive the REAL movement primitives north for
    ; DEBUG_WALK_STEPS steps (default 8: wYCoord 8 -> 0, the north edge), then
    ; dump the frame. Reveals where the player is VISUALLY when it reaches the
    ; map edge / when CheckMapConnections fires — i.e. whether the transition
    ; triggers at an appropriate point. Collision is skipped so the walk is
    ; unconditional. If a crossing fires mid-walk, we dump immediately.
    ;
    ; The spawn (tile 8,8 = Pallet block col 4) sits under a tree at block-row 0,
    ; so a blind straight-north walk drove the player THROUGH the tree and off the
    ; top edge into the OOB-clamped region (collision is skipped). Pre-walk east
    ; onto the passable north-exit column first so the northward walk stays on
    ; valid tiles and crosses into Route 1 legitimately.
%ifndef DEBUG_WALK_STEPS
%define DEBUG_WALK_STEPS 8
%endif
%ifndef DEBUG_WALK_EAST_STEPS
%define DEBUG_WALK_EAST_STEPS 2
%endif
    mov ecx, DEBUG_WALK_EAST_STEPS
.we_step:
    push ecx
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 1     ; +1 (east)
    mov byte [ebp + wPlayerDirection],        PLAYER_DIR_RIGHT
    mov byte [ebp + wPlayerMovingDirection], PLAYER_DIR_RIGHT
    mov byte [ebp + W_SPRITE_PLAYER_FACING_DIR], SPRITE_FACING_RIGHT
    mov byte [ebp + wWalkCounter], 8
.we_frames:
    call UpdateSprites
    call AdvancePlayerSprite
    call DelayFrame
    cmp byte [ebp + wWalkCounter], 0
    jne .we_frames
    pop ecx
    dec ecx
    jnz .we_step

    mov ecx, DEBUG_WALK_STEPS
.wn_step:
    push ecx
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0xFF   ; -1 (north)
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0
    mov byte [ebp + wPlayerDirection],        PLAYER_DIR_UP
    mov byte [ebp + wPlayerMovingDirection], PLAYER_DIR_UP
    mov byte [ebp + W_SPRITE_PLAYER_FACING_DIR], SPRITE_FACING_UP
    mov byte [ebp + wWalkCounter], 8
.wn_frames:
    call UpdateSprites
    call AdvancePlayerSprite
    jc .wn_crossed                ; CF=1 → CheckMapConnections fired this step
    call DelayFrame
    cmp byte [ebp + wWalkCounter], 0
    jne .wn_frames
    pop ecx
    dec ecx
    jnz .wn_step
    call DumpBackbuffer           ; reached edge without crossing — dump it
.wn_crossed:
    pop ecx                       ; (balance stack; ecx unused after)
    call DumpBackbuffer           ; dump the frame at the moment of crossing
%endif
%ifdef DEBUG_TRANSITION
    ; Deterministic transition test: simulate stepping off the north edge of
    ; Pallet Town (wYCoord wraps to 255), run the real CheckMapConnections, then
    ; the same reload .mapTransition does. Lets us screenshot the post-crossing
    ; render of Route 1's bottom without keyboard input.
%ifndef DEBUG_BASELINE
    mov byte [ebp + wXCoord], 8
    mov byte [ebp + wYCoord], 255
    call CheckMapConnections                  ; sets wCurMap + view ptr for Route 1
%endif
    ; Player identity = the golden spec ("RED" / id 0), as the DEBUG_STARTMENU gate
    ; below already does. Without this the overworld_pallet golden compares the build
    ; define (PLAYER_NAME, e.g. "NINTEN") against the golden's "RED", and — worse —
    ; wPlayerID is whatever InitPlayerData rolled from the RNG, so it is not even
    ; reproducible run to run. Only visible since the WRAM regions are compared (F-5).
    call SeedDeterministicPlayerIdentity
    mov byte [ebp + wWalkCounter], 0
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0
    mov byte [ebp + hSCY], 0
    mov byte [ebp + hSCX], 0
    mov word [ebp + wMapViewVRAMPointer], GB_TILEMAP0
    call LoadMapHeader
    ; OW-A.2 P3b: LoadMapHeader now runs the faithful InitSprites (pret :1892), which
    ; repopulates the NPC slots from the destination map's object binary but leaves
    ; IMAGEBASEOFFSET cleared (that is InitMapSprites' job). The real .mapTransition
    ; (:902/:913) pairs LoadMapHeader with InitMapSprites; this harness claimed to do
    ; "the same reload .mapTransition does" but had OMITTED that InitMapSprites call —
    ; harmless before P3b (LoadMapHeader was sprite-agnostic), required now so the
    ; slots are tile-loaded / IMAGEBASEOFFSET-assigned like the real crossing does.
    call InitMapSprites
    call LoadTileBlockMap
    call LoadCurrentMapView
    ; Render a few frames so GB_BACKBUF holds the post-transition image, then
    ; exfiltrate the exact rendered pixels to FRAME.BIN for host inspection.
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer        ; writes FRAME.BIN then exits (never returns)
%endif
%ifdef DEBUG_DIALOG
    ; Dialog-box position test: fill GB_TILEMAP1 rows 0-5 with a checkerboard of
    ; tile IDs 0x50/0x51 (visible non-blank), show the window at the centered-bottom
    ; position (WY=152, WX=87), render 3 frames, dump FRAME.BIN.
    ; Tests Bug 2 (window at bottom, centered) and that the window renders at all.
    lea edi, [ebp + GB_TILEMAP1]
    mov ecx, 6 * 32                        ; 6 rows × 32 tiles = 192 bytes
    xor eax, eax
.dd_fill:
    mov byte [edi], 0x50
    inc edi
    mov byte [edi], 0x51
    inc edi
    sub ecx, 2
    jnz .dd_fill
    mov eax, 87                            ; wx (centered dialog: WX-7=80)
    mov ebx, 152                           ; wy (bottom of viewport)
    mov ecx, SCREEN_W                      ; clip_w = 160px
    mov edx, RENDER_H                      ; max_y = 200
    mov esi, GB_TILEMAP1
    xor edi, edi
    call set_single_window
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer                    ; writes FRAME.BIN, exits
%endif
%ifdef DEBUG_SIGNTEXT
    ; The coords were seeded before LoadMapData (above); LoadMapData does not derive
    ; the view pointer for a hand-seeded spawn, so do that first.
    call SeedDeterministicPlayerIdentity    ; "RED" / id 0 — the golden's identity
    call SeamReseatView                     ; view ptr + block coords + collision mirror
    mov byte [ebp + W_SPRITE_PLAYER_FACING_DIR], SIGNTEXT_DIR  ; default SPRITE_FACING_LEFT
    ; Run the REAL A-press dispatch, not a bespoke "print this text" shortcut: the
    ; whole point of this scenario is that the sign's text reaches the screen through
    ; IsSpriteOrSignInFrontOfPlayer → SignLoop → DisplaySignText → ShowTextStream.
    call IsSpriteOrSignInFrontOfPlayer
    cmp byte [ebp + hTextID], 0             ; pret gate: found anything? (the
    je .signtext_nosign                     ; scenario faces a sign, so a hit
                                            ; here is the sign's text id)
    call DoSignInteraction                  ; never returns: ShowTextStream's DEBUG_SIGNTEXT
                                            ; hook dumps once the text is printed
.signtext_nosign:
    ; No sign in front of the player → dump anyway, with no dialog box on screen, so the
    ; golden diff FAILS LOUDLY instead of the harness silently walking into the game.
    call DumpBackbuffer
%endif
%ifdef DEBUG_STARTMENU
    call SeedDeterministicPlayerIdentity   ; menu's name row = "RED" (golden spec), not the build define
    call DisplayStartMenu                  ; draws menu, renders one frame, dumps FRAME.BIN, exits
%endif
%ifdef DEBUG_BAGMENU
    call RunBagMenuTest                    ; seed bag, open bag screen, render one frame, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_BAGMENU_LIVE
    ; Live, interactive: seed a full bag + money, then fall through to the normal
    ; OverworldLoop. Open the bag via START → ITEM (the real path) to exercise the
    ; list, TOSS quantity chooser, YES/NO confirm, and the "TOO IMPORTANT!" notice.
    mov byte [ebp + wPartyCount], 0             ; wPartyCount = 0
    mov byte [ebp + wPartySpecies], 0xFF          ; wPartySpecies sentinel
    mov byte [ebp + wNumBagItems], 0             ; wNumBagItems = 0
    mov byte [ebp + wBagItems], 0xFF          ; wBagItems sentinel
    call PrepareNewGameDebug               ; seed party + bag + money (returns)
%endif
%ifdef DEBUG_SEED_PARTY
%ifndef DEBUG_TRAINER_ROUTE
%ifndef DEBUG_TRAINER_ROUTE17
    ; Plain playable build with a seeded party: seed a full party + bag + money,
    ; then fall through to the normal OverworldLoop. No frame dump, no exit — reach
    ; the stats screen the real way (START → POKéMON → a mon → STATS), so the render
    ; runs through the faithful .choseStats path (ClearSprites etc.), not the harness.
    ;
    ; *** EXCLUDED under DEBUG_TRAINER_ROUTE (measured 2026-08-05). *** This block
    ; runs on EVERY EnterMap pass, and the trainer-route scenario's post-battle
    ; return IS an EnterMap (pret .battleOccurred ends `jp EnterMap`). With it
    ; active, PrepareNewGameDebug re-ran here after the battle and REBUILT the
    ; party — caught live via a D179 watchpoint: EnterMap+0x49 ->
    ; PrepareNewGameDebug -> SetDebugNewGameParty -> _AddPartyMon writing the
    ; seed EXP over the earned +335, which erased every reward the scenario
    ; compares (EXP, stat exp, PP) while the beaten flag stayed correctly set.
    ; That scenario's party seed is RunTrainerRouteTestSeed (debug_dump.asm),
    ; which runs ONCE under its own guard and calls PrepareNewGameDebug itself.
    ; *** ALSO EXCLUDED under DEBUG_TRAINER_ROUTE17, same reason. *** Its seed is
    ; RunTrainerRoute17TestSeed, guarded the same way.
    ;
    ; *** NOW LATCHED (2026-08-15). *** The paragraph above described the damage
    ; and then left it in place for every non-TRAINER_ROUTE build, which made
    ; DEBUG_START_MAP + DEBUG_SEED_PARTY — the obvious way to hand-test battles —
    ; silently broken: the trainer engages with the "!" and then never fights,
    ; because the post-battle EnterMap re-seed re-enters with wCurOpponent still
    ; set. Latching costs one byte and fixes the cause, so the seeded playable
    ; build is now usable for exactly what a human tester reaches for. The two
    ; %ifndef exclusions above are now belt-and-braces rather than the mechanism.
    cmp byte [seed_party_done], 0
    jne .seed_party_already
    mov byte [seed_party_done], 1
    mov byte [ebp + wPartyCount], 0             ; wPartyCount = 0
    mov byte [ebp + wPartySpecies], 0xFF          ; wPartySpecies sentinel
    mov byte [ebp + wNumBagItems], 0             ; wNumBagItems = 0
    mov byte [ebp + wBagItems], 0xFF          ; wBagItems sentinel
    call PrepareNewGameDebug               ; seed party + bag + money (returns)
.seed_party_already:
%endif
%endif
%endif
%ifdef DEBUG_ITEMUSE
    ; Item-USE gate (items-plan Stage 5): the seeded party is at full HP, so knock
    ; party mon 1 (Snorlax) down to 1 HP — that gives the seeded POTION (bag slot 1,
    ; qty 1) a visible effect while leaving the mon status-free, so the ANTIDOTE the
    ; scripted joypad tries next must refuse ("It won't have any effect!").
    ; Current HP is a big-endian word: hi byte first. (gb_constants.inc is not
    ; included here, so the struct offset is spelled out: wPartyMon1 + MON_HP.)
    mov byte [ebp + wPartyMon1 + 0x01], 0
    mov byte [ebp + wPartyMon1 + 0x02], 1
%endif
%ifdef DEBUG_ITEMTM
    call RunTMHMTest
%endif
%ifdef DEBUG_ITEMPP
    call RunPPRestoreTest                  ; items-plan Stage 11: use a PP item, dump, exit
%endif
%ifdef DEBUG_ITEMSTONE
    call RunStoneTest                       ; items-plan Stage 8: use a stone, dump, exit
%endif
%ifdef DEBUG_PARTYMENU
    call RunPartyMenuTest                  ; seed party, open party screen, render one frame, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_BATTLE
    call RunBattleTest                     ; seed party+enemy, enter battle, render one frame, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_TEXT
    call RunTextTest                       ; text-engine oracle: run one probe stream, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_TEXTBOXID
    call RunTextBoxIDTest                  ; canvas mode, draw text box id, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_LISTMENU
    call RunListMenuTest                   ; seed party+bag, drive generic list menu, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_YESNO
    call RunYesNoTest                      ; draw the two-option box, park in HandleMenuInput; AutoKeyDrive dumps
%endif
%ifdef DEBUG_DRAWBADGES
    call RunDrawBadgesTest                  ; seed badges, draw grid, window it, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_TRAINERCARD
    call RunTrainerCardTest                 ; draw full trainer card, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_CINEMATIC_MARKERS
    call RunCinematicMarkersTest            ; cinematic projection/clip/wrap markers, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_OAKSPC
    call RunOaksPCTest                      ; open Oak's PC, dump the dialog FRAME.BIN, exits
%endif
%ifdef DEBUG_PC
    call RunPCTest                          ; ActivatePC: dialog + SFX; AutoKeyDrive dumps
%endif
%ifdef DEBUG_LEAGUEPC
    call RunLeaguePCTest                    ; draw HoF-PC dialog (0 teams), dump FRAME.BIN, exits
%endif
%ifdef DEBUG_HOF
    call RunHallOfFameTest                  ; run the Hall of Fame ceremony; AutoKeyDrive dumps
%endif
%ifdef DEBUG_CREDITS
    call RunCreditsTest                     ; run the credits roll; AutoKeyDrive dumps
%endif
%ifdef DEBUG_OPTIONS
    call RunOptionsTest                     ; open OPTION menu, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_PLAYERSPC
    call RunPlayersPCTest                   ; seed+open PlayerPC, dump parent-menu FRAME.BIN, exits
%endif
%ifdef DEBUG_MAINMENU
    call RunMainMenuTest                    ; seed save, draw CONTINUE menu + info panel, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_SAVE
    call RunSaveTest                        ; seed party, run SaveGameData, dump "saved!" FRAME.BIN, exits
%endif
%ifdef DEBUG_SAVEPERF
    call RunSavePerfTest                    ; stage-7: 32 real save commits, DumpPerf writes PERF.BIN v3, exits
%endif
%ifdef DEBUG_CONTINUE_SEED
    call RunContinueSeedTest                ; A3: seed+save, clobber, CONTINUE-load, dump GBSTATE, exits
%endif
%ifdef DEBUG_REAL_SAVE
    call RunRealSaveTest                    ; clobber, load the staged real .sav, dump GBSTATE, exits
%endif
%ifdef DEBUG_BOX_SAVE
    call RunBoxSaveTest                     ; as above, with a full-boxes save; also dumps wBoxData
%endif
%ifdef DEBUG_BILLSPC
    call RunBillsPCTest                     ; sram stage 6: scripted joypad drives the real Bill's PC box UI; AutoKeyDrive dumps
%endif
%ifdef DEBUG_BILLSPC_CHANGEBOX
    call RunBillsPCTest                     ; as above, with the change-box round-trip script (banks 2/3)
%endif
%ifdef DEBUG_OAKPIC
    call RunOakPicTest                      ; A4.1: display Oak pic on the surface, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_OAKINTRO
    call RunOakSpeechCheckpoint             ; A4.3: oak_intro checkpoint (pic+fade+text), AutoKeyDrive dumps
%endif
%ifdef DEBUG_NAMEMENU
    call RunNameMenuTest                    ; A4.4: projected name-select menu, AutoKeyDrive dumps
%endif
%ifdef DEBUG_OAKSLIDE
    call RunOakSlideTest                    ; A4.4: slide the projected pic right, AutoKeyDrive dumps
%endif
%ifdef DEBUG_CHOOSENAME
    call RunChooseNameTest                  ; A4.5f: end-to-end default-name pick, AutoKeyDrive dumps
%endif
%ifdef DEBUG_CINEMATIC_SPLASH
    call RunSplashTest                      ; B2: Game Freak splash animation, AutoKeyDrive dumps
%endif
%ifdef DEBUG_CINEMATIC_ANIMOBJ
    call RunAnimObjectTest                  ; B1.3: animated-object engine lifecycle, AutoKeyDrive dumps
%endif
%ifdef DEBUG_CINEMATIC_YELLOW
    call RunYellowIntroTest                 ; B3.2d: full Yellow intro (PlayIntroScene), AutoKeyDrive dumps
%endif
%ifdef DEBUG_NAMINGSCREEN
    call RunNamingScreenTest                ; open PLAYER naming screen, draw grid, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_G1
    call RunPokedexTest                     ; seed seen/owned, draw pokédex CONTENTS list, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_G2
    call RunPokedexEntryTest                ; open RHYDON dex data page (pic+HT/WT), dump FRAME.BIN, exits
%endif
%ifdef DEBUG_I1
    call RunLinkMenuTest                    ; open link cup-select screen (serial stubbed), dump FRAME.BIN, exits
%endif
%ifdef DEBUG_I2
    call RunLinkCupsTest                    ; run cup validators (pass+gated fail), record codes, dump, exits
%endif
%ifdef DEBUG_NETTEST
    call RunNetPipeTest                     ; net_frame codec/ARQ RAM-pipe test, results -> wTileMap, dump, exits
%endif
%ifdef DEBUG_LINKCHECK
    call RunLinkCheck                       ; loop the real CableClubNPC against the nullmodem peer; parks in LinkMenu, AutoKeyDrive dumps
%endif
%ifdef DEBUG_TRADECHECK
    call RunTradeCheck                      ; loop the real CableClubNPC; success falls through LinkMenu into a real trade-center session
%endif
%ifdef DEBUG_BATTLECHECK
    call RunBattleCheck                     ; loop the real CableClubNPC; success falls through LinkMenu into a real Colosseum link battle
%endif
%ifdef DEBUG_LINKBOOKCHECK
    call RunLinkBookCheck                   ; single call to the real CableClubNPC; blocks in LinkTransportSelect's book UI, no peer
%endif
%ifdef DEBUG_KBDNAMECHECK
    call RunKbdNameCheckTest                ; open the REAL (blocking) PLAYER naming screen, KBD_NAMING path driven by AUTOKEY_KBDSCRIPT
%endif
%ifdef DEBUG_LEARNMOVE
    call RunLearnMoveTest                  ; force a level-up move-learn, render one frame, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_STATUS
    call RunStatusScreenTest               ; open status screen page 1, render one frame, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_SURFING_PIKACHU
    call RunSurfingPikachuTest             ; boot directly into SurfingPikachuMinigame
%endif
%ifdef DEBUG_PIKAPIC
    call RunPikaPicTest                    ; boot directly into the pikapic front-pic engine
%endif
%ifdef DEBUG_WALKSPEED
    ; Live walk-speed instrumentation: boots normally into OverworldLoop so you can
    ; WALK with the keyboard. WalkSpeedSample (called at each real tile completion)
    ; records ticks-per-tile into $D1E0; pressing Esc dumps DUMP.BIN via DelayFrame's
    ; quit hook. tick_count is the true 60 Hz PIT counter, so avg ticks/tile = 16 →
    ; faithful walk speed; notably < 16 → movement really is too fast.
    ;   $D1E0 first tick   $D1E4 last tick   $D1E8 tiles   $D1EC min Δ   $D1F0 init flag
    mov dword [ebp + (W_PORT_SCRATCH + 0x00)], 0
    mov dword [ebp + (W_PORT_SCRATCH + 0x04)], 0
    mov dword [ebp + (W_PORT_SCRATCH + 0x08)], 0
    mov dword [ebp + (W_PORT_SCRATCH + 0x0C)], 0xFFFFFFFF
    mov dword [ebp + (W_PORT_SCRATCH + 0x10)], 0
%endif

    ; --- faithful EnterMap reset ladder (pret home/overworld.asm:6-41) ----------
    ; Placed AFTER the DEBUG harnesses (tripwire): baseline DEBUG builds dump-and-exit
    ; before reaching here, so this only runs in the real build (and live-DEBUG builds
    ; that fall through, e.g. DEBUG_WALKSPEED / DEBUG_BAGMENU_LIVE).

    ; farcall ClearVariablesOnEnterMap
    call ClearVariablesOnEnterMap

    ; ld hl, wStatusFlags2 / bit BIT_WILD_ENCOUNTER_COOLDOWN, [hl]
    ; jr z, .skip / ld a, 3 / ld [wNumberOfNoRandomBattleStepsLeft], a
    test byte [ebp + wStatusFlags2], (1 << BIT_WILD_ENCOUNTER_COOLDOWN)
    jz .skipGivingThreeStepsOfNoRandomBattles
    mov byte [ebp + wNumberOfNoRandomBattleStepsLeft], 3   ; minimum steps between battles
.skipGivingThreeStepsOfNoRandomBattles:

    ; ld hl, wStatusFlags4 / bit BIT_BATTLE_OVER_OR_BLACKOUT, [hl]
    ; res BIT_BATTLE_OVER_OR_BLACKOUT, [hl]
    ; call z, ResetUsingStrengthOutOfBattleBit / call nz, MapEntryAfterBattle
    ; pret tests the bit, then `res`es it before the two conditional calls; in x86 the
    ; `res` (and [mem]) would clobber the ZF the calls read, so capture the tested bit
    ; into CL first, then res, then branch on CL.
    test byte [ebp + wStatusFlags4], (1 << BIT_BATTLE_OVER_OR_BLACKOUT)
    setnz cl                                               ; cl=1 if returning from a battle
    and byte [ebp + wStatusFlags4], ~(1 << BIT_BATTLE_OVER_OR_BLACKOUT)
    test cl, cl
    jnz .mapEntryAfterBattle
    call ResetUsingStrengthOutOfBattleBit                  ; z: normal (non-battle) entry
    jmp .afterBattleReturnCheck
.mapEntryAfterBattle:
    call MapEntryAfterBattle                               ; nz: post-battle re-entry
.afterBattleReturnCheck:

    ; ld hl, wStatusFlags6 / ld a, [hl] / and (1<<FLY_WARP)|(1<<DUNGEON_WARP)
    ; jr z, .didNot... / farcall EnterMapAnim / call UpdateSprites
    ; res FLY_WARP,[wStatusFlags6] / res NO_BATTLES,[wStatusFlags4]
    test byte [ebp + wStatusFlags6], (1 << BIT_FLY_WARP) | (1 << BIT_DUNGEON_WARP)
    jz .didNotEnterUsingFlyWarpOrDungeonWarp
    call EnterMapAnim
    call UpdateSprites
    and byte [ebp + wStatusFlags6], ~(1 << BIT_FLY_WARP)
    and byte [ebp + wStatusFlags4], ~(1 << BIT_NO_BATTLES)
.didNotEnterUsingFlyWarpOrDungeonWarp:

    ; call IsSurfingPikachuInParty
    call IsSurfingPikachuInParty
    ; farcall CheckForceBikeOrSurf (player_state.asm — LINKED as of the wild-live
    ; promotion; the PLAYER_STATE_LINKED gate is retired).
    call CheckForceBikeOrSurf ; handle SF-island currents / forced cycling-road bike

    ; ld hl, wStatusFlags6 / bit BIT_DUNGEON_WARP,[hl] / res BIT_DUNGEON_WARP,[hl]
    ; (pret's bit test result is unused here — just clear the bit)
    and byte [ebp + wStatusFlags6], ~(1 << BIT_DUNGEON_WARP)
    ; ld hl, wStatusFlags3 / res BIT_NO_NPC_FACE_PLAYER, [hl]
    and byte [ebp + wStatusFlags3], ~(1 << BIT_NO_NPC_FACE_PLAYER)

    ; call UpdateSprites
    call UpdateSprites

    ; ld hl, wCurrentMapScriptFlags / set CUR_MAP_LOADED_1,[hl] / set CUR_MAP_LOADED_2,[hl]
    or byte [ebp + wCurrentMapScriptFlags], (1 << BIT_CUR_MAP_LOADED_1) | (1 << BIT_CUR_MAP_LOADED_2)

    ; xor a / ld [wJoyIgnore], a
    mov byte [ebp + wJoyIgnore], 0
%ifdef DEBUG_MAPSCRIPT_SIGHT
    ; Map-script sight gate. Placed HERE, at the very end of EnterMap, not beside the
    ; other gates further up: everything above is part of entering a map, and the
    ; golden observes the map fully entered — in particular wJoyIgnore is $FF for the
    ; whole of EnterMap and cleared only on this line, so a gate that dumped earlier
    ; would compare a byte the real game never shows the player.
    ; The coords were seeded before LoadMapData; LoadMapData does not derive the view
    ; pointer for a hand-seeded spawn, so do that first.
    call SeedDeterministicPlayerIdentity     ; "RED" / id 0 — the golden's identity
    call SeamReseatView                      ; view ptr + block coords + collision mirror
    call RunMapScriptSightTest               ; dumps GBSTATE + FRAME and exits
%endif
%ifdef DEBUG_PREDEFTEXT
    ; The coords were seeded before LoadMapData; LoadMapData does not derive the view
    ; pointer for a hand-seeded spawn, so do that first.
    call SeedDeterministicPlayerIdentity     ; "RED" / id 0 — the golden's identity
    call SeamReseatView
    or byte [ebp + hJoyHeld], PAD_A
    ; Run the REAL A-press hidden-event dispatch, not a bespoke "print this predef"
    ; shortcut — the whole point is that the text reaches the screen through
    ; CheckForHiddenEventOrBookshelfOrCardKeyDoor -> PrintRedSNESText ->
    ; PrintPredefTextID -> DisplayTextID's TEXT_PREDEF branch -> the flat TextPredefs
    ; row -> the generated RedBedroomSNESText stream. That chain is the acceptance
    ; this plan owes for editing DisplayTextID.
    call CheckForHiddenEventOrBookshelfOrCardKeyDoor
    ; The dialog waits for A. AUTOKEY_QUIET presses nothing, so the message stays on
    ; screen and AutoKeyDrive photographs it at AUTOKEY_DUMP_FRAME.
.predeftext_wait:
    call DelayFrame
    jmp .predeftext_wait
%endif
%ifdef DEBUG_HIDDENOBJ
    ; Generic hidden-object / bookshelf gate — the parameterised form of
    ; DEBUG_PREDEFTEXT above (see the seed block earlier in EnterMap).
    ;
    ; The coords were seeded before LoadMapData; LoadMapData does not derive the view
    ; pointer for a hand-seeded spawn, so do that first.
    call SeedDeterministicPlayerIdentity      ; "RED" / id 0 — the golden's identity
    call SeamReseatView
    ; Facing is seeded HERE, not with the coords: InitSprites (from LoadMapData)
    ; rebuilds wSpriteStateData1 from the map's object binary, so a facing written
    ; before it does not survive. CheckForHiddenEvent compares this byte against the
    ; prop's `hidden_event` facing argument, and the mGBA side seeds the same address
    ; (seed.warp + write8 wSpritePlayerStateData1FacingDirection).
    ; HIDDENOBJ_DIR 0xFF means ANY_FACING — leave whatever the map gave us.
%if HIDDENOBJ_DIR != 0xFF
    mov byte [ebp + wSpritePlayerStateData1FacingDirection], HIDDENOBJ_DIR
%endif
    ; *** THE A PRESS IS LOAD-BEARING AND MUST BE SEEDED. ***
    ; CheckForHiddenEventOrBookshelfOrCardKeyDoor's FIRST act is
    ; `ldh a,[hJoyHeld] / and PAD_A / jr z,.nothingFound` (src/home/hidden_events.asm).
    ; Headless there is no keyboard, and AUTOKEY_QUIET injects nothing, so without
    ; this the call returns at once having dispatched NOTHING — a gate that runs,
    ; exits 0 and proves nothing (bug-class-false-witness-scenario, instance 1).
    ; DEBUG_PREDEFTEXT above has exactly that hole; it is unregistered, so no golden
    ; ever caught it.
    ; Optional map-script tick. A prop whose TEXT is spliced from WRAM the map script
    ; populates cannot be read straight after EnterMap: GymStatues' GymStatueText1 is
    ; `text_ram wGymCityName` + `text_ram wGymLeaderName`, and those are filled by the
    ; gym's own script calling LoadGymLeaderAndCityName. Without a script tick the port
    ; prints the statue text with a BLANK city line while the ROM — whose overworld
    ; loop has run the script — prints "PEWTER CITY" (measured: 10 diverging cells,
    ; all of them that line). Running the script once is what the real arrival does.
%ifdef HIDDENOBJ_RUNSCRIPT
    call RunMapScript
%endif
    or byte [ebp + hJoyHeld], PAD_A
    ; Run the REAL dispatch, not a bespoke "print this predef" shortcut: the text
    ; must reach the screen through CheckForHiddenEventOrBookshelfOrCardKeyDoor ->
    ; CheckForHiddenEvent -> the prop's handler (or, when no hidden event matches,
    ; GetTileAndCoordsInFrontOfPlayer -> PrintBookshelfText for the bookshelf-tile
    ; props such as IndigoPlateauStatues).
    call CheckForHiddenEventOrBookshelfOrCardKeyDoor
    ; The dialog waits for A. AUTOKEY_QUIET presses nothing, so the message stays on
    ; screen and AutoKeyDrive photographs it at AUTOKEY_DUMP_FRAME.
.hiddenobj_wait:
    call DelayFrame
    jmp .hiddenobj_wait
%endif
%ifdef DEBUG_SURF
    ; Placed at the end of EnterMap for the same reason DEBUG_MAPSCRIPT_SIGHT is:
    ; everything above is part of entering the map, and this gate then FALLS THROUGH
    ; into the real OverworldLoop rather than running a synthetic harness. The whole
    ; flow — the bump that populates wTileInFrontOfPlayer, the bag, both item uses,
    ; and the two simulated forward steps — is driven by AUTOKEY_SURF's scripted
    ; joypad through the live loop, with LIVE collision. AutoKeyDrive writes
    ; FRAME.BIN + GBSTATE.BIN at AUTOKEY_DUMP_FRAME.
    ; LoadMapData does not derive the view pointer for a hand-seeded spawn.
    call SeedDeterministicPlayerIdentity
    call SeamReseatView
    call RunSurfTestSeed                     ; party + bag + SURFBOARD; RETURNS
%endif
%ifdef DEBUG_CABLECLUB
    ; Same shape as DEBUG_SURF above: seed, then FALL THROUGH into the real
    ; OverworldLoop. AUTOKEY_APRESS's A press runs the production talk dispatch
    ; (IsSpriteOrSignInFrontOfPlayer -> CheckNPCInteraction -> the generated
    ; SCRIPT entry -> CableClubReceptionistScript -> CableClubNPC) and answers
    ; the failure text's two `cont` page waits; the dump hook lives in the shim
    ; (src/engine/link/cable_club_npc.asm).
    ; LoadMapData does not derive the view pointer for a hand-seeded spawn.
    call SeedDeterministicPlayerIdentity     ; "RED" / id 0 — the golden's identity
    call SeamReseatView
    ; Facing is seeded HERE, not with the coords: InitSprites (from LoadMapData)
    ; rebuilds wSpriteStateData1 (same rule as DEBUG_HIDDENOBJ).
    mov byte [ebp + wSpritePlayerStateData1FacingDirection], CABLECLUB_DIR
%endif
%ifdef DEBUG_TRADE_GOLDEN
    ; Same shape as DEBUG_CABLECLUB above: seed, then FALL THROUGH into the
    ; real OverworldLoop. AUTOKEY_TRADE_GOLDEN's A train + state-gated DOWN
    ; climb run the production talk dispatch (IsSpriteOrSignInFrontOfPlayer ->
    ; CheckNPCInteraction -> the generated SCRIPT entry ->
    ; Route2TradeHouseGameboyKidText -> DoInGameTradeDialogue) through the
    ; whole trade; the dump hook lives in the script glue
    ; (src/scripts/Route2TradeHouse.asm).
    ; LoadMapData does not derive the view pointer for a hand-seeded spawn.
    call SeedDeterministicPlayerIdentity     ; "RED" / id 0 — the golden's identity
    call SeamReseatView
    ; Facing is seeded HERE, not with the coords: InitSprites (from LoadMapData)
    ; rebuilds wSpriteStateData1 (same rule as DEBUG_CABLECLUB).
    mov byte [ebp + wSpritePlayerStateData1FacingDirection], TRADE_GOLDEN_DIR
%endif
%ifdef DEBUG_PRINT_SURF_CANCEL
    ; Same shape as DEBUG_CABLECLUB above: seed, then FALL THROUGH into the
    ; real OverworldLoop. AUTOKEY_APRESS drives the talk, YES choice, and final
    ; dialog dismissal.
    call SeedDeterministicPlayerIdentity
    call SeamReseatView
    mov byte [ebp + wSpritePlayerStateData1FacingDirection], SPRITE_FACING_UP
%endif
%ifdef DEBUG_POKECENTER_HEAL
    call SeedDeterministicPlayerIdentity
    call SeamReseatView
    mov byte [ebp + wSpritePlayerStateData1FacingDirection], SPRITE_FACING_UP
%endif
%ifdef DEBUG_VENDING
    call SeedDeterministicPlayerIdentity
    call SeamReseatView
    mov byte [ebp + wSpritePlayerStateData1FacingDirection], SPRITE_FACING_UP
%endif
%ifdef DEBUG_PRIZE_CORNER
    call SeedDeterministicPlayerIdentity
    call SeamReseatView
    mov byte [ebp + wSpritePlayerStateData1FacingDirection], SPRITE_FACING_UP
%endif
%ifdef DEBUG_POKEMART
    call SeedDeterministicPlayerIdentity
    call SeamReseatView
    mov byte [ebp + wSpritePlayerStateData1FacingDirection], SPRITE_FACING_LEFT
%endif
%ifdef DEBUG_LEDGE
    ; Same shape as DEBUG_SURF above: seed, then FALL THROUGH into the real
    ; OverworldLoop. AUTOKEY_LEDGE's scripted joypad arms the hop with a real
    ; DOWN press against live collision (CollisionCheckOnLand → HandleLedges),
    ; the two simulated steps run through AreInputsSimulated, HandleMidJump
    ; advances and tears the hop down, and a second DOWN takes a normal step —
    ; the byte that proves the teardown ran.
    call SeedDeterministicPlayerIdentity
    call SeamReseatView
    call RunLedgeTestSeed                    ; debug party, empty bag; RETURNS
%endif
%ifdef DEBUG_FISH
    ; Same shape as DEBUG_SURF above: seed, then FALL THROUGH into the real
    ; OverworldLoop. AUTOKEY_FISH drives both rod uses through the live bag UI.
    call SeedDeterministicPlayerIdentity
    call SeamReseatView
    call RunFishTestSeed                     ; party + bag + OLD ROD; RETURNS
%endif
%ifdef DEBUG_TRAINER_ROUTE
    ; Same shape as DEBUG_SURF/LEDGE/FISH above: seed, then FALL THROUGH into the
    ; real OverworldLoop. Nothing else drives this scenario — the loop does it all:
    ; RunMapScript reaches Route 3's TrainerMapScript, CheckFightingMapTrainers
    ; engages the youngster on its own, DisplayEnemyTrainerTextAndStartBattle runs
    ; StartTrainerBattle which seeds wCurOpponent, the loop's own battle-entry poll
    ; turns that into InitBattle, AUTOKEY_TRAINER_ROUTE answers the battle menus,
    ; and .battleOccurred returns to the map where the next RunMapScript dispatches
    ; EndTrainerBattle at script index 2. The bespoke sight hook cannot interfere:
    ; ROUTE_3 dispatches to TrainerMapScript, so the Stage 1b gate skips it.
    call SeedDeterministicPlayerIdentity
    call SeamReseatView
    call RunTrainerRouteTestSeed             ; debug party, empty bag; RETURNS
%endif
%ifdef DEBUG_TRAINER_ROUTE17
    ; Same shape as DEBUG_TRAINER_ROUTE above: seed, then FALL THROUGH into the real
    ; OverworldLoop — the only loop that ever calls ForceBikeDown. The player spawns
    ; already inside ROUTE17_BIKER10's sight line, so RunMapScript -> Route17's
    ; TrainerMapScript -> CheckFightingMapTrainers engages on its own; AUTOKEY_
    ; TRAINER_ROUTE17 only answers whatever pre-battle text appears, and the dump
    ; fires as soon as the battle is confirmed started (state-gated in AutoKeyDrive).
    call SeedDeterministicPlayerIdentity
    call SeamReseatView
    call RunTrainerRoute17TestSeed           ; debug party, empty bag; RETURNS
    ; The golden reaches this tile by REAL navigation down Cycling Road, so pret
    ; arrives with wPlayerLastStopDirection already DOWN and ForceBikeDown's first
    ; injected PAD_DOWN walks immediately. EnterMap's spawn reset
    ; (engine/overworld/overworld.asm: "player spawns stopped") clears it to 0, so
    ; a seeded spawn would spend that first frame TURNING instead of stepping and
    ; land one tile north of ground truth (wYCoord $78 vs $79).
    ; This matched by accident until 2026-08-19: wPlayerLastStopDirection was
    ; hand-placed at 0xCFAE, colliding with wLoadedMonSpeedExp, and the debug
    ; party's stat-exp byte happened to satisfy the compare. Retiring that
    ; collision exposed the real dependency, so the harness now states it.
    mov byte [ebp + wPlayerLastStopDirection], PLAYER_DIR_DOWN
    mov byte [ebp + W_CHECK_FOR_TURN], 0
%endif
%ifdef DEBUG_BATTLE_GHOST
    ; Same shape as DEBUG_LEDGE/FISH/TRAINER_ROUTE above: seed, then FALL THROUGH
    ; into the real OverworldLoop. One autokey DOWN takes a step, the loop's own
    ; battle-entry poll calls NewBattle, and the seeded wCurOpponent turns that
    ; into the forced Marowak battle that IS the ghost.
    call SeedDeterministicPlayerIdentity
    call SeamReseatView
    call RunGhostBattleTestSeed              ; debug party, empty bag, wCurOpponent; RETURNS
%endif
%ifdef DEBUG_SAFARI_GAMEOVER
    ; Same shape as DEBUG_LEDGE/FISH/TRAINER_ROUTE/BATTLE_GHOST above: seed, then
    ; FALL THROUGH into the real OverworldLoop. The loop does the rest and nothing
    ; here touches the subject — AUTOKEY_SAFARI_GAMEOVER's held PAD_DOWN walks two
    ; live steps against live collision, StepCountCheck's own arm calls
    ; SafariZoneCheckSteps once per completed step, the second call sees zero and
    ; falls into SafariZoneGameOver, and that prints TimesUpText through the real
    ; DisplayTextID. A gate that called SafariZoneCheckSteps itself would prove the
    ; routine works and say NOTHING about the loop arm, which is the half that was
    ; actually missing until 2077fdb3f (bug-class-false-witness-scenario).
    ; LoadMapData does not derive the view pointer for a hand-seeded spawn.
    call SeedDeterministicPlayerIdentity
    call SeamReseatView
    call RunSafariGameOverTestSeed           ; event, balls, wSafariSteps; RETURNS
%endif

    ; fall through to OverworldLoop

; ---------------------------------------------------------------------------
; OverworldLoop — player-movement frame loop.
; Pret ref: home/overworld.asm:OverworldLoop / OverworldLoopLessDelay (the
; movement-relevant subset; no menus, warps, NPCs, battles, or scripts yet).
;
; Cadence matches the original: two DelayFrame calls per iteration, then one
; AdvancePlayerSprite (2 px scroll) — so a 16 px step takes ~16 frames.
;
; State machine:
;   - mid-walk (wWalkCounter != 0): keep advancing the sprite.
;   - idle: read held D-pad; on a press, set the step vector + facing, run the
;     land collision check, and (if passable) start an 8-frame walk.
; ---------------------------------------------------------------------------
OverworldLoop:
    ; pret's OverworldLoop is `call DelayFrame` and nothing else. Two of the three
    ; things the port had here MOVED on 2026-08-22 to the positions pret gives
    ; them: the wCurOpponent battle-entry poll is now right after the
    ; fly/dungeon-warp test (pret :65-67), and JoypadOverworld (pret :49) took over
    ; the step-vector clears plus ForceBikeDown / AreInputsSimulated.
    ; UpdateSprites advance player facing + walk animation
    call UpdateSprites
    call DelayFrame
%ifdef DEBUG_TRADE_GOLDEN
    ; in_game_trade golden photograph (armed by the Route2TradeHouse script shim
    ; the instant DoInGameTradeDialogue returned): taken HERE, one full loop
    ; iteration later — UpdateSprites above has recomputed the image indices the
    ; dialog left at $FF (hidden) and the DelayFrame republished OAM, so the
    ; frame matches the mGBA golden's "closing box dismissed, stable idle
    ; overworld, sprites visible" dump point (measured 2026-08-23: dumping at
    ; the A-release point photographed wUpdateSpritesEnabled=1 but every
    ; state1 IMAGEINDEX still $FF and an empty $FE00).
    cmp byte [trade_golden_dump_armed], 1
    jne .noTradeGoldenDump
    call DumpBackbuffer                    ; FRAME.BIN + GBSTATE.BIN, then exits
.noTradeGoldenDump:
%endif
%ifdef DEBUG_PRINT_SURF_CANCEL
    cmp byte [print_surf_dump_armed], 1
    jne .noPrintSurfDump
    call DumpBackbuffer                    ; FRAME.BIN + GBSTATE.BIN, then exits
.noPrintSurfDump:
%endif

    ; --- OverworldLoop falls through into OverworldLoopLessDelay (pret) ---
OverworldLoopLessDelay:                      ; pret: home/overworld.asm:OverworldLoopLessDelay
    call DelayFrame
    ; pret: call IsSurfingPikachuInParty / call LoadGBPal / call HandleMidJump.
    ;
    ; LoadGBPal is RESTORED (2026-08-11). It reloads rBGP/rOBP0/rOBP1 from
    ; FadePal4 - wMapPalOffset every overworld frame, which is the ONLY thing that
    ; ever gives rOBP1 a non-zero value on this path (FadePal4 + 2 = dc 3,2,0,0 =
    ; $E0). Dropped as a "palette-fade path", it left IO_OBP1 at Init's zero for
    ; the whole run, so CGB OBJ palettes 4-7 -- the four base palettes mapped
    ; through OBP1 -- collapsed to white. Measured by the cgb_palettes golden
    ; region: ~229 divergences of the form `OBJ pal4-7 colour2/3: rom=(11,23,31)
    ; port=(31,31,31)` across 44 scenarios, all one missing call.
    ;
    ; IsSurfingPikachuInParty is still dropped (Pikachu-follower path), along with
    ; the other calls faithdiff reports on this routine -- untouched here.
    ;
    ; HandleMidJump advances the ledge-hop arc and, when it finishes, tears down
    ; BIT_LEDGE_OR_FISHING / BIT_SCRIPTED_MOVEMENT_STATE / wJoyIgnore. No live
    ; ZF/CF crosses these calls: the wWalkCounter cmp below produces its own flags.
    call LoadGBPal
    call HandleMidJump

    cmp byte [ebp + wWalkCounter], 0
    jne .moveAhead                           ; still mid-step → keep walking

    ; --- idle: pret :49, `call JoypadOverworld` ------------------------------
    ; Zeroes both player step vectors, runs the map script, and applies the
    ; Cycling Road / simulated-input overrides. Restored as a real routine on
    ; 2026-08-22; its five statements used to be scattered across this loop (the
    ; step-vector clears here, RunMapScript at the top of OverworldLoop, and
    ; ForceBikeDown + AreInputsSimulated further down past the trainer-sight hook).
    call JoypadOverworld

    ; A special warp was armed since the last idle iteration (Escape Rope / Dig / Fly /
    ; a dungeon warp-pad): leave the map now, before any input is acted on.
    ;   pret: ld a, [wStatusFlags6] / and (1 << BIT_FLY_WARP) | (1 << BIT_DUNGEON_WARP)
    ;         jp nz, HandleFlyWarpOrDungeonWarp        (home/overworld.asm:62-64)
    ; PLACEMENT DEVIATION: pret tests this AFTER JoypadOverworld + SafariZoneCheck + the
    ; script-warp check; the port's loop reads the joypad further down (both of those
    ; are now restored immediately above, in pret's order), so the test sits at the
    ; top of the idle branch instead. Equivalent: the bits are set by an item/script on a PREVIOUS
    ; iteration, never by this iteration's input, and we leave the map either way — so
    ; nothing between the two positions can observe the difference.
    ; --- Safari Zone: out of BALLS (pret home/overworld.asm:54-57) ------------
    ; RESTORED 2026-08-21, the companion to the out-of-STEPS branch further down.
    ; pret runs this right after JoypadOverworld; the port reads the joypad further
    ; down, so it sits here at the top of the idle branch — the same relocation, and
    ; for the same reason, as the fly/dungeon-warp test immediately below, and it
    ; keeps pret's ORDER relative to that test (pret: SafariZoneCheck, then the
    ; script-warp check, then the fly-warp test).
    ; Inert outside the Safari Zone by construction: SafariZoneCheck's own first act
    ; is CheckEventHL EVENT_IN_SAFARI_ZONE, and it falls through to
    ; SafariZoneGameStillGoing (which zeroes wSafariZoneGameOver) unless
    ; wNumSafariBalls has reached 0.
    call SafariZoneCheck                     ; pret: farcall SafariZoneCheck
    mov al, [ebp + wSafariZoneGameOver]
    test al, al                              ; pret: and a
    jnz WarpFound2                            ; pret: jp nz, WarpFound2

    ; --- pret :58-61, the SCRIPT WARP. Restored 2026-08-21; it had never been
    ; ported, so a map script could set the flag and nothing would ever act on it.
    ;     ld hl, wStatusFlags3
    ;     bit BIT_WARP_FROM_CUR_SCRIPT, [hl]
    ;     res BIT_WARP_FROM_CUR_SCRIPT, [hl]
    ;     jp nz, WarpFound2
    ; This is how a script warps the player without a warp tile — the mechanism
    ; behind the elevator, the S.S. Anne departure, Lorelei/Bruno/Agatha/Lance's
    ; room doors and every `warp_to` a script issues. It is also exactly what the
    ; mGBA harness drives to place the player on an arbitrary map, which is why
    ; the port had no equivalent entry and every port-side gate has to hand-seed
    ; a spawn instead.
    ;
    ; *** THE ORDER OF THE THREE INSTRUCTIONS IS LOAD-BEARING. *** pret reads the
    ; bit, clears it, and branches on the flags from the READ — `res` does not
    ; touch flags on SM83, so ZF survives it. On x86 `and` DOES set flags, so a
    ; literal transcription (test / and / jnz) would branch on the POST-clear
    ; value and the warp could never fire. Latch the pre-clear byte in AL first,
    ; clear, then test the latch. (asm-translation: "preserve the exact ZF/CF a
    ; jr z reads".)
    mov al, [ebp + wStatusFlags3]                                    ; ld hl, wStatusFlags3
    and byte [ebp + wStatusFlags3], ~(1 << BIT_WARP_FROM_CUR_SCRIPT) & 0xFF ; res (clobbers flags)
    test al, (1 << BIT_WARP_FROM_CUR_SCRIPT)                         ; bit — on the PRE-res value
    jnz WarpFound2                            ; pret: jp nz, WarpFound2

    test byte [ebp + wStatusFlags6], (1 << BIT_FLY_WARP) | (1 << BIT_DUNGEON_WARP)
    jnz HandleFlyWarpOrDungeonWarp           ; jp nz (tail — SpecialEnterMap re-enters the loop)

    ; --- Stage 1b: pret's battle-entry poll (home/overworld.asm:65-67) -------
    ;   ld a, [wCurOpponent] / and a / jp nz, .newBattle
    ; MOVED here 2026-08-22 from the top of OverworldLoop, where it had been put
    ; because the port called RunMapScript there. RunMapScript now runs inside
    ; JoypadOverworld at pret's position, so the poll can sit at pret's position
    ; too — immediately after the fly/dungeon-warp test.
    ;
    ; The trainer script chain (CheckFightingMapTrainers ->
    ; DisplayEnemyTrainerTextAndStartBattle -> StartTrainerBattle) does not run
    ; the battle itself: it SEEDS wCurOpponent and returns, and this poll is what
    ; turns that seed into a battle. NewBattle -> InitBattle -> InitOpponent
    ; (wCurOpponent >= OPP_ID_OFFSET = trainer), and EndOfBattle.resetVariables
    ; clears wCurOpponent on the way out, so this cannot re-enter. CF=1 means a
    ; battle ran: take pret's shared .battleOccurred tail.
    ;
    ; It REPLACED the old wIsInBattle==$ff scaffold, which existed only because
    ; StartTrainerBattle used to call InitBattle inline (the retired
    ; TRAINER_BATTLE_LIVE guard); blackout is now reached the way pret reaches
    ; it, through .battleOccurred's AnyPartyAlive.
    cmp byte [ebp + wCurOpponent], 0
    je .noPendingOpponent
    call NewBattle                           ; CF=1 → a battle occurred
    jc .battleOccurred                       ; pret: jp nz, .newBattle -> .battleOccurred
.noPendingOpponent:

    ; --- Stage 1b: the bespoke sight path is now GATED OFF where the faithful
    ; one is wired. pret has no CheckTrainerSight/TrainerEncounterFlow; its only
    ; trainer-sight mechanism is the map's own _Script -> CheckFightingMapTrainers,
    ; which the port reaches from RunMapScript (this file, OverworldLoop) and
    ; which seeds wCurOpponent for the battle-entry poll there. On a map wired to
    ; TrainerMapScript BOTH paths were armed, and the bespoke one won the race
    ; (its own distance<=4 test vs the header's view range), so the faithful path
    ; could never be observed in a continuous run. The predicate is DATA-DRIVEN
    ; against the generated dispatch table rather than a hand-kept map list, so
    ; each map the overworld-events rollout wires shrinks this hook's domain with
    ; no edit here. It keys on TrainerMapScript specifically, NOT merely
    ; "!= DefaultMapScript": PALLET_TOWN has a non-default _Script that is not a
    ; trainer script, and a "any non-default script" test would silently strip
    ; sight handling from any such map that did have trainers.
    ; DEVIATION{class=temporary; pret=home/overworld.asm:OverworldLoopLessDelay; behavior=on maps not yet wired to TrainerMapScript the port still runs the port-only CheckTrainerSight and TrainerEncounterFlow pair after the fly/dungeon-warp test, which pret has no counterpart for; evidence=MapScriptPointers in the generated assets/map_scripts.inc dispatches only a SUBSET of maps to TrainerMapScript, and that subset GROWS with the overworld-events rollout, so it is deliberately not enumerated here — measure it with grep -c 'dd TrainerMapScript' dos_port/assets/map_scripts.inc. On every map outside that subset MapScriptPointers[wCurMap] is DefaultMapScript or a non-trainer script, the faithful CheckFightingMapTrainers flow is unreachable, and deleting the hook outright would remove trainer engagement there entirely; lifetime=deleted when Stage 5a wiring completes and all standard trainer maps are wired, owned by docs/current_plan_overworld_realign.md Stage J (adopted from the retired overworld-events plan)}
    movzx ecx, byte [ebp + wCurMap]
    cmp dword [MapScriptPointers + ecx*4], TrainerMapScript
    je .noTrainerSight                       ; faithful map-script path owns this map
    ; Flags: the cmp above is consumed by the je; CheckTrainerSight sets its own
    ; CF after popad, so the jnc below still reads ITS result, not this test's.
    call CheckTrainerSight
    jnc .noTrainerSight
    call TrainerEncounterFlow
    jmp OverworldLoop
.noTrainerSight:

    ; ForceBikeDown (Cycling Road auto-scroll) and AreInputsSimulated used to sit
    ; HERE, at the seam where the port had unpacked JoypadOverworld. Both moved
    ; back inside JoypadOverworld on 2026-08-22, which is where pret has them —
    ; so they now run BEFORE the Safari / warp / fly-warp tests above rather than
    ; after them, matching pret's order.
    ;
    ; The notes that lived on them are still worth keeping:
    ; BIT_SCRIPTED_MOVEMENT_STATE is armed by StartSimulatingJoypadStates
    ; (PlayerStepOutFromDoor's single step, HandleLedges' two hop steps, …).
    ; AreInputsSimulated (this file) pops the next queued PAD_* byte into
    ; hJoyHeld while scripted movement is active and leaves real input
    ; untouched otherwise; the flag drains in its .doneSimulating when the
    ; queue empties (pret semantics — never consumed per-step). hJoyHeld is used for A (not
    ; hJoyPressed): joypad_update runs twice per OverworldLoop idle iteration (one
    ; per DelayFrame), so hJoyPressed is always cleared before we read it.
    ; Re-trigger after dialog dismiss is prevented by .waitAReleased below.
    ;
    ; The `call AreInputsSimulated` that stood HERE is gone — JoypadOverworld at the
    ; top of this branch makes it, once, where pret does. Leaving both in place ran
    ; it TWICE per idle iteration, and since each call POPS one entry off the
    ; simulated-joypad queue that silently ate every other scripted step: measured
    ; 2026-08-22 as ledge_hop, surf_round_trip and route17_trainer_battle each
    ; landing the player exactly one tile short of the golden, with ledge_hop's
    ; wSimulatedJoypadStatesEnd drained to 0 where the ROM still held PAD_DOWN.
    movzx eax, byte [ebp + hJoyHeld]
    test byte [ebp + wStatusFlags5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jnz .checkPADDown                               ; scripted step: skip START/A, go to D-pad
.checkJoyDisable:
    test byte [ebp + wStatusFlags5], (1 << BIT_DISABLE_JOYPAD)
    jnz .noDirection                            ; input suppressed during warp-arrival window

    ; START-press: open the start menu (pret: OverworldLoopLessDelay TEXT_START_MENU).
    ; Read from hJoyHeld like the A-press below; DisplayStartMenu's close path waits
    ; for START release before returning, so a held START can't re-open it next frame.
    test al, PAD_START
    jz .checkAPress
    call DisplayStartMenu
    jmp OverworldLoop
.checkAPress:

    ; A-press: check for NPC or sign. EAX = hJoyHeld (level-triggered, reliable).
    test al, PAD_A
    jz .checkPADDown
    ; pret order: on A-press CheckForHiddenEventOrBookshelfOrCardKeyDoor runs FIRST
    ; (home/overworld.asm:OverworldLoop). hItemAlreadyFound == 0 → a hidden event or
    ; bookshelf consumed the press: return to OverworldLoop without the sprite/sign
    ; scan. $ff → nothing found (or a card-key door), so fall through to the scan.
    call CheckForHiddenEventOrBookshelfOrCardKeyDoor
    cmp byte [ebp + hItemAlreadyFound], 0
    jz .interactionDone                        ; hidden event/bookshelf handled → skip scan
    ; pret order (OverworldLoop A-press): zero wd435, run the complete
    ; IsSpriteOrSignInFrontOfPlayer (sign branch, counter-range extension, then
    ; the sprite scan), gate on [hTextID] != 0 — pret home/overworld.asm:95-99.
    ; (pret then runs Func_0ffe / IsPlayerTalkingToPikachu and DisplayTextID;
    ; the port's display split below is the documented dispatcher deviation —
    ; see DoSignInteraction's DEVIATION{class=temporary}.)
    mov byte [ebp + wd435], 0                  ; xor a / ld [wd435], a
    call IsSpriteOrSignInFrontOfPlayer
    call Func_0ffe
    mov al, [ebp + hTextID]                    ; ldh a, [hTextID]
    test al, al                                ; and a
    jz .checkPADDown                           ; jp z, OverworldLoop — nothing found
    ; Route by id — pret DisplayTextID's sprite-vs-textID rule (cp wNumSprites:
    ; id <= wNumSprites → sprite slot, else a sign/board text id).
    cmp al, [ebp + wNumSprites]
    jbe .checkNPC
    call DoSignInteraction
    jmp .interactionDone
.checkNPC:
    call CheckNPCInteraction                   ; the port's display half (re-detects, then displays)
    test al, al
    jz .checkPADDown                           ; scan disagreement → fall to D-pad
.interactionDone:
%ifdef DEBUG_PRINT_SURF_CANCEL
    cmp byte [print_surf_dump_armed], 1
    jne .waitAReleased
    call UpdateSprites
    call DelayFrame
    call DumpBackbuffer
%endif
%ifdef DEBUG_POKECENTER_HEAL
    cmp byte [pokecenter_heal_dump_armed], 1
    jne .waitAReleased
    call UpdateSprites
    call DelayFrame
    call DumpBackbuffer
%endif
%ifdef DEBUG_VENDING
    cmp byte [vending_dump_armed], 1
    jne .waitAReleased
    call UpdateSprites
    call DelayFrame
    call DumpBackbuffer
%endif
%ifdef DEBUG_PRIZE_CORNER
    cmp byte [prize_corner_dump_armed], 1
    jne .waitAReleased
    call UpdateSprites
    call DelayFrame
    call DumpBackbuffer
%endif
%ifdef DEBUG_POKEMART
    cmp byte [pokemart_dump_armed], 1
    jne .waitAReleased
    call UpdateSprites
    call DelayFrame
    call DumpBackbuffer
%endif
    ; Interaction handled. Wait for A to be released before restarting to prevent
    ; the next OverworldLoop iteration from re-triggering while A is still held.
.waitAReleased:
    call DelayFrame
    test byte [ebp + hJoyHeld], PAD_A
    jnz .waitAReleased
    jmp OverworldLoop

.checkPADDown:                                  ; EAX = hJoyHeld from above
    test al, PAD_DOWN
    jz .checkUp
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 1
    mov dl, PLAYER_DIR_DOWN
    mov dh, SPRITE_FACING_DOWN
    jmp .handleDirection
.checkUp:
    test al, PAD_UP
    jz .checkLeft
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0xFF   ; -1
    mov dl, PLAYER_DIR_UP
    mov dh, SPRITE_FACING_UP
    jmp .handleDirection
.checkLeft:
    test al, PAD_LEFT
    jz .checkRight
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0xFF   ; -1
    mov dl, PLAYER_DIR_LEFT
    mov dh, SPRITE_FACING_LEFT
    jmp .handleDirection
.checkRight:
    test al, PAD_RIGHT
    jz .noDirection                          ; nothing held → idle (stop animating)
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 1
    mov dl, PLAYER_DIR_RIGHT
    mov dh, SPRITE_FACING_RIGHT

.handleDirection:
    ; Always commit the new direction/facing — this happens even on turn-only presses.
    mov [ebp + wPlayerDirection],         dl
    mov [ebp + wPlayerMovingDirection],  dl
    mov [ebp + W_SPRITE_PLAYER_FACING_DIR], dh

    ; pret: bit BIT_SCRIPTED_MOVEMENT_STATE, a / jr nz, .noDirectionChange
    ; Scripted movement bypasses the 180° turn-delay. The bit is NOT consumed
    ; here — pret clears it only in AreInputsSimulated's .doneSimulating (queue
    ; drained past 0) or in a flow's own teardown (_HandleMidJump). The port
    ; used to clear it here as a "one-step door buffer", which broke every
    ; multi-step simulation: the ledge hop queues TWO steps, and the early clear
    ; froze the second one in the queue (wSimulatedJoypadStatesIndex stuck at 1,
    ; measured by the DEBUG_LEDGE_TRACE ring; the ledge_hop golden catches it).
    ; The door's single step still drains naturally: its pop leaves index 0 and
    ; the next AreInputsSimulated call takes .doneSimulating.
    test byte [ebp + wStatusFlags5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jnz .walkStart

    ; Turn delay (pret: wCheckFor180DegreeTurn / wPlayerLastStopDirection).
    ; First press after idle with a NEW direction: update facing but don't walk.
    ; Second press (same direction, or same as last-stop dir): walk normally.
    cmp byte [ebp + W_CHECK_FOR_TURN], 0
    je .walkStart                             ; already committed to walking direction
    mov byte [ebp + W_CHECK_FOR_TURN], 0     ; consume the turn-check token
    cmp dl, [ebp + wPlayerLastStopDirection]
    je .walkStart                             ; same direction → walk normally
    ; Turn-only press (pret home/overworld.asm:186-199): facing was updated above;
    ; don't walk. OW-A.6 faithful turn tail: arm the Pikachu-collision grace
    ; counter, flag the in-place turn for this frame (.moveAhead clears it), and —
    ; pret :197 — roll a wild encounter on the turn itself (turning in grass can
    ; trigger a battle).
    mov byte [ebp + wPikachuCollisionCounter], 8
    or byte [ebp + wMiscFlags], (1 << BIT_TURNING)   ; set BIT_TURNING, [hl]
    call NewBattle                            ; CF=1 → a battle occurred on the turn
    jc .battleOccurred
    jmp OverworldLoop                         ; turn only — no step

.walkStart:
    ; OW-A.6 (pret .noDirectionChange, home/overworld.asm:203-226): while surfing
    ; (wWalkBikeSurfState == 2) collision routes through CollisionCheckOnWater;
    ; on land through CollisionCheckOnLand. Inert in today's live build — nothing
    ; sets state 2 until Surf item-use / ForceBikeOrSurf links (player_gfx.asm).
    cmp byte [ebp + wWalkBikeSurfState], 2 ; surfing?
    jne .collisionOnLand
    call CollisionCheckOnWater                ; CF=1 → blocked on water
    jc OverworldLoop                          ; pret .surfing: jp c, OverworldLoop
    jmp .startWalk                            ; water clear → begin the step
.collisionOnLand:
    call CollisionCheckOnLand                 ; CF=1 → blocked
    jnc .startWalk

    ; Blocked. Collision-exit path (pret: bit BIT_STANDING_ON_WARP / ExtraWarpCheck).
    ; Only attempt exit if player IS on a warp tile (set at spawn by LoadDestinationMapData
    ; or after a step by .moveAhead). BIT_EXITING_DOOR is NOT checked here — pret does
    ; not suppress collision-exit during the auto-walk window.
    test byte [ebp + wMovementFlags], (1 << BIT_STANDING_ON_WARP)
    jz OverworldLoop
    ; M7.4: faithful ExtraWarpCheck (pret home/overworld.asm:ExtraWarpCheck +
    ; jp c, CheckWarpsCollision). Replaces the hardcoded "facing DOWN" test with
    ; pret's per-map function-1 (IsPlayerFacingEdgeOfMap) / function-2
    ; (IsWarpTileInFrontOfPlayer) dispatch. Register-safe (returns only CF); DL
    ; is no longer consulted here. The scan that follows it is pret's own
    ; CheckWarpsCollision now (it was an inline `call CheckWarpTile` + `jmp
    ; WarpFound2` until 2026-08-22).
    call ExtraWarpCheck
    jc CheckWarpsCollision                    ; pret: jp c, CheckWarpsCollision
    jmp OverworldLoop                         ; pret: jp OverworldLoop

.startWalk:
    mov byte [ebp + wWalkCounter], 8        ; begin an 8-frame step
    call Func_fcc08                            ; callfar Func_fcc08 — push this step into Pikachu's follow FIFO
    jmp .moveAhead2                            ; pret: jr .moveAhead2 — advance immediately, no extra delay

.noDirection:
    ; Save the last-used moving direction so the next press can check for a turn.
    ; (Pret: .noDirectionButtonsPressed — saves wPlayerMovingDirection to
    ; wPlayerLastStopDirection, zeroes moving dir, sets wCheckFor180DegreeTurn=1.)
    mov al, [ebp + wPlayerMovingDirection]
    mov [ebp + wPlayerLastStopDirection], al
    mov byte [ebp + wPlayerMovingDirection], 0
    mov byte [ebp + W_CHECK_FOR_TURN], 1
    jmp OverworldLoop

.moveAhead:
    ; pret .moveAhead (home/overworld.asm:234-236) — the MID-WALK entry only. The
    ; fresh-step entry (.startWalk above, pret's .noCollision) jumps past it
    ; straight to .moveAhead2, which is why pret splits the two labels at all.
    ; The port had them merged into one until 2026-08-22, so IsSpinning — the
    ; spinner-tile blink that carries the player across a Rocket HQ / Viridian Gym
    ; floor — had nowhere to be called from and the translated LoadSpinnerArrowTiles
    ; sat with zero callers.
    ;
    ; pret's second call here, `call UpdateSprites`, is NOT restored: the port
    ; already runs UpdateSprites once per iteration at the top of OverworldLoop
    ; (a pre-existing placement deviation, not one introduced here), so calling it
    ; again would advance the walk animation twice on every mid-walk frame.
    call IsSpinning
.moveAhead2:
    ; pret .moveAhead2 head (home/overworld.asm:243-248): clear the in-place-turn
    ; flag + Pikachu-collision grace counter, then the bike double-step, then
    ; advance. DoBikeSpeedup is live but inert (wWalkBikeSurfState is never 1
    ; until Bicycle use / ForceBikeOrSurf links). OW-A.6.
    and byte [ebp + wMiscFlags], ~(1 << BIT_TURNING) & 0xFF  ; res BIT_TURNING, [hl]
    mov byte [ebp + wPikachuCollisionCounter], 0
    call DoBikeSpeedup
    call AdvancePlayerSprite
    jc .mapTransition
    cmp byte [ebp + wWalkCounter], 0
    jne OverworldLoop
%ifdef DEBUG_WALKSPEED
    call WalkSpeedSample                       ; tile just completed → record ticks/tile
%endif
    ; --- M7.1/OW-A.6: step count + wild-encounter gate (pret home/overworld.asm:249-268) ---
    ; The tile step just finished. pret runs StepCountCheck here, then (after
    ; poison/safari, deferred) NewBattle, taking the warp checks only when no battle
    ; occurred. StepCountCheck decrements the WRAM step counters — including
    ; wNumberOfNoRandomBattleStepsLeft, the post-battle 3-step encounter-free window
    ; that NewBattle's DetermineWildOpponent gate reads. Wild encounters are LIVE
    ; (the WILD_ENCOUNTERS_LIVE gate is retired).
    call StepCountCheck
    ; --- Safari Zone step countdown (pret home/overworld.asm:249-256) ----------
    ; RESTORED 2026-08-21. This branch was absent: the port went straight from
    ; StepCountCheck to NewBattle, so wSafariSteps never decremented while walking
    ; and the "PA: Ding-dong! / Time's up!" game over was UNREACHABLE — the Safari
    ; Zone was playable but could not time out. SafariZoneCheckSteps and
    ; SafariZoneGameOver were both translated with no caller in the tree.
    ; pret's `farcall` is a direct call here (flat model, no banking).
    ; pret's `jp nz, WarpFound2` reaches the real WarpFound2, hoisted out of this
    ; routine (2026-08-21) so it carries its pret name instead of the port-local
    ; `.warpTransition` it used to hide behind.
    CheckEvent EVENT_IN_SAFARI_ZONE
    jz .notSafariZone                         ; pret: jr z, .notSafariZone
    call SafariZoneCheckSteps                 ; pret: farcall SafariZoneCheckSteps
    mov al, [ebp + wSafariZoneGameOver]
    test al, al                               ; pret: and a
    jnz WarpFound2                            ; pret: jp nz, WarpFound2
.notSafariZone:
    call NewBattle                            ; CF=1 → a wild/forced battle occurred
    ; pret :265-268: the `res BIT_STANDING_ON_WARP` sits BETWEEN the call and the
    ; branch, so it runs on BOTH arms — SM83 `res` does not touch flags. On x86
    ; `and` does, so the carry NewBattle returned is banked across it. The port
    ; used to do the clear only on the no-battle arm (inside .noBattleOccurred),
    ; which left the bit set across a battle entered from a warp tile.
    pushf
    and byte [ebp + wMovementFlags], ~(1 << BIT_STANDING_ON_WARP) & 0xFF
    popf
    jnc CheckWarpsNoCollision                 ; pret: jp nc, CheckWarpsNoCollision
.battleOccurred:
    ; pret .battleOccurred (home/overworld.asm:269-296) — reached from the
    ; post-step NewBattle above and the on-turn NewBattle in .handleDirection.
    and byte [ebp + wStatusFlags3], ~(1 << BIT_TALKED_TO_TRAINER) & 0xFF
    and byte [ebp + wStatusFlags7], ~(1 << BIT_TRAINER_BATTLE) & 0xFF
    or  byte [ebp + wCurrentMapScriptFlags], (1 << BIT_CUR_MAP_LOADED_1) | (1 << BIT_CUR_MAP_LOADED_2)
    mov byte [ebp + hJoyHeld], 0            ; xor a / ldh [hJoyHeld], a
    mov al, [ebp + wCurMap]
    cmp al, CINNABAR_GYM
    jne .notCinnabarGym
    SetEvent EVENT_2A7
.notCinnabarGym:
    or byte [ebp + wStatusFlags4], (1 << BIT_BATTLE_OVER_OR_BLACKOUT)
    mov al, [ebp + wCurMap]
    cmp al, OAKS_LAB
    je .noFaintCheck                          ; no blackout after losing to the rival in Oak's lab
    call AnyPartyAlive                        ; DH = OR of every party mon's HP bytes
    test dh, dh                               ; ld a, d / and a
    jz .allFainted
.noFaintCheck:
    mov bl, 10                                ; ld c, 10 (DelayFrames: BL = frame count)
    call DelayFrames
    jmp EnterMap                              ; full map re-entry (reset ladder, OW-A.4)
.allFainted:
    jmp AllPokemonFainted                     ; wild_encounter_check.asm → HandleBlackOut
.mapTransition:
    ; A connection was crossed — reload everything for the new map.
    mov byte [ebp + wWalkCounter], 0
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0

    ; Reset scroll and VRAM pointer. During the walk, hSCY/hSCX accumulated
    ; 2 px/frame (e.g. −144 px over 9 north steps). CopyMapViewToVRAM always
    ; writes to GB_TILEMAP0 ($9800), so the PPU must start reading from row 0
    ; (SCY=0). wMapViewVRAMPointer must also reset so RedrawRowOrColumn
    ; uses the correct base address on subsequent frames.
    mov byte [ebp + hSCY], 0
    mov byte [ebp + hSCX], 0
    mov word [ebp + wMapViewVRAMPointer], GB_TILEMAP0

    ; pret home/overworld.asm:.loadNewMap (:648-651) — set the follower's
    ; "crossed a connection" flag and request spawn state 2 BEFORE LoadMapHeader,
    ; so the reloaded map re-places Pikachu beside the player. Deferred while the
    ; follow engine was unported; live now (follower phases 1-4).
    or byte [ebp + wPikachuOverworldStateFlags], (1 << 4) ; set 4, [hl]
    mov byte [ebp + wPikachuSpawnState], 2                ; ld a, $2 / ld [wPikachuSpawnState], a
    call LoadMapHeader
    ; pret home/overworld.asm:.loadNewMap (:652-654): LoadMapHeader (loads the new map's
    ; wMapMusicSoundID via the MapSongBanks load above) then fade in that music. Real now
    ; (OW-A.14); unconditional on a connection crossing (not a warp, so no warp gate).
    call PlayDefaultMusicFadeOutCurrent
    mov bh, SET_PAL_OVERWORLD
    call RunPaletteCommand
    call InitMapSprites                        ; populate NPC slots for the new map
    ; Update text table dispatch for the new map.
    movzx eax, byte [ebp + wCurMap]
    lea esi, [MapTextTablePointers]
    mov esi, [esi + eax*4]
    mov [w_map_text_table_ptr], esi
    call LoadTileBlockMap
    call LoadCurrentMapView

    jmp OverworldLoopLessDelay


; ---------------------------------------------------------------------------
; CheckWarpsNoCollision / ...Loop / ...Retry1 / ...Retry2 /
; ContinueCheckWarpsNoCollisionLoop / CheckWarpsCollision / WarpFound1
;   — pret home/overworld.asm:360-454, restored 2026-08-22.
;
; NAME FORK CLOSED. All seven labels reported `missing`: the port had merged both
; of pret's warp scans into one port-local helper, CheckWarpTile
; (src/engine/overworld/overworld.asm), which OverworldLoop called inline at the
; two seams where pret jumps to these routines. That helper is now DELETED — this
; is the same debt WarpFound2 carried until it was hoisted on 2026-08-21, and this
; is the other half of it.
;
; The merge also lost real behaviour, restored here with the names:
;   * pret's no-collision scan CONTINUES to the next warp entry when a coord match
;     fails its ExtraWarpCheck or its held-D-pad test (Retry2); the merged helper
;     stopped at the first coord match and gave up. Two warps on one tile is not a
;     thing, but a warp whose ExtraWarpCheck fails is, and pret keeps looking.
;   * pret's BIT_FORCED_WARP arm (wStatusFlags7) — a script-forced warp bypasses
;     the "must be holding a direction" test entirely. Never ported before.
;   * the tail is `jp CheckMapConnections`, not `jp OverworldLoop`. The port sent
;     an unmatched scan straight back to the loop, so the only thing that ever ran
;     CheckMapConnections was _AdvancePlayerSprite's own call.
;
; The one thing NOT restored is pret's `call Joypad` inside the scan; the port's
; hJoyHeld is already this frame's. It is annotated at that spot.
;
; Register map: pret b (warp number) -> BH, c (warps remaining) -> BL,
; d/e (player Y/X) -> DH/DL, hl (wWarpEntries cursor) -> ESI as a GB offset.
; BL is live all the way into WarpFound2, which subtracts it from wNumberOfWarps
; to recover the matched warp's index — so nothing between here and there may
; clobber it.
; ---------------------------------------------------------------------------
global CheckWarpsNoCollision
global CheckWarpsNoCollisionLoop
global CheckWarpsNoCollisionRetry1
global CheckWarpsNoCollisionRetry2
global ContinueCheckWarpsNoCollisionLoop
global CheckWarpsCollision
global WarpFound1

; check if the player has stepped onto a warp after having not collided
CheckWarpsNoCollision:
    cmp byte [ebp + wNumberOfWarps], 0         ; ld a,[wNumberOfWarps] / and a
    je WarpScanToMapConnections  ; jp z, CheckMapConnections
    mov bh, 0                                  ; ld b, 0 — warp number
    mov bl, [ebp + wNumberOfWarps]             ; ld c, a — warps remaining
    mov dh, [ebp + wYCoord]                    ; ld d, a
    mov dl, [ebp + wXCoord]                    ; ld e, a
    mov esi, wWarpEntries                      ; ld hl, wWarpEntries
CheckWarpsNoCollisionLoop:
    mov al, [ebp + esi]                        ; ld a, [hli] — warp Y
    inc esi
    cmp al, dh
    jne CheckWarpsNoCollisionRetry1
    mov al, [ebp + esi]                        ; ld a, [hli] — warp X
    inc esi
    cmp al, dl
    jne CheckWarpsNoCollisionRetry2
    ; --- coord match ------------------------------------------------- pret :377
    or byte [ebp + wMovementFlags], (1 << BIT_STANDING_ON_WARP)  ; set BIT_STANDING_ON_WARP,[hl]
    push esi
    push ebx
    call IsPlayerStandingOnDoorTileOrWarpTile  ; farcall — may `res` the bit for a warp carpet
    pop ebx
    pop esi
    jc WarpFound1                              ; jr c — standing on a door or warp tile
    push esi
    push ebx
    call ExtraWarpCheck                        ; CF=1 -> a warp is possible here
    pop ebx
    pop esi
    jnc CheckWarpsNoCollisionRetry2            ; jr nc — keep scanning
    ; --- the extra check passed -------------------------------------- pret :393
    test byte [ebp + wStatusFlags7], (1 << BIT_FORCED_WARP)
    jnz WarpFound1                             ; a forced warp ignores the input test
    ; pret: push de / push bc / call Joypad / pop bc / pop de.
    ; DEVIATION{class=HAL; pret=home/overworld.asm:CheckWarpsNoCollision; behavior=the `call Joypad` before the held-direction test is dropped; evidence=the port `Joypad` recomputes the edge layer from hJoyInput which only ReadJoypad_ writes and which nothing in the frame loop calls, while joypad_update already runs the same pret _Joypad edge layer once per DelayFrame from the live pad state - so the call would read a stale hJoyInput and ZERO hJoyHeld, making this test never pass, and hJoyHeld is already fresh without it - the same reason every other ported `call Joypad` site drops it, see JoypadLowSensitivity in src/home/joypad2.asm; lifetime=permanent while input is polled from the PIT/keyboard ISR rather than a joypad register}
    test byte [ebp + hJoyHeld], PAD_CTRL_PAD
    jz CheckWarpsNoCollisionRetry2             ; not pressing a direction -> don't warp
    jmp WarpFound1

; ---------------------------------------------------------------------------
; WarpScanToMapConnections — port-only. pret's `jp CheckMapConnections`,
; adapted to the port's callable CheckMapConnections.
;
; pret's CheckMapConnections is a JUMP TARGET: it ends `jp OverworldLoopLessDelay`
; when a connection was crossed and `jp OverworldLoop` when it was not, so pret can
; simply `jp` into it. The port's is a CALLABLE routine with a push/pop frame that
; returns CF and leaves the reload to its caller (see its .loadNewMap note), so
; jumping into it desynchronises the stack and its `ret` lands on garbage — which
; is exactly what it did for the ~90 seconds this file carried a literal `jmp`
; there (measured 2026-08-22: ledge_hop, surf_round_trip and safari_game_over all
; died before their dump frame).
;
; Re-running it here is harmless as well as faithful: _AdvancePlayerSprite already
; called it during the step, and if it had fired there the CF would have taken the
; loop to .mapTransition and never reached a warp scan — so by the time control is
; here the coords are inside the map and the second call cannot fire either.
;
; A port-only descriptive name, not a forked pret one: pret has no routine here at
; all, only two `jp CheckMapConnections` instructions.
; ---------------------------------------------------------------------------
WarpScanToMapConnections:
    call CheckMapConnections
    jc OverworldLoopLessDelay.mapTransition    ; pret: jp OverworldLoopLessDelay
    jmp OverworldLoop                          ; pret: jp OverworldLoop

CheckWarpsNoCollisionRetry1:
    inc esi                                    ; inc hl (skip the X byte too)
CheckWarpsNoCollisionRetry2:
    inc esi                                    ; inc hl
    inc esi                                    ; inc hl (past dest warp id + dest map)
ContinueCheckWarpsNoCollisionLoop:
    inc bh                                     ; inc b — warp number
    dec bl                                     ; dec c — warps remaining
    jnz CheckWarpsNoCollisionLoop              ; jp nz
    jmp WarpScanToMapConnections  ; jp CheckMapConnections

; check if the player has stepped onto a warp after having collided
CheckWarpsCollision:
    mov bl, [ebp + wNumberOfWarps]             ; ld a,[wNumberOfWarps] / ld c, a
    mov esi, wWarpEntries                      ; ld hl, wWarpEntries
.loop:
    mov bh, [ebp + esi]                        ; ld a,[hli] / ld b, a — warp Y
    inc esi
    mov al, [ebp + wYCoord]
    cmp al, bh                                 ; cp b
    jne .retry1
    mov bh, [ebp + esi]                        ; ld a,[hli] / ld b, a — warp X
    inc esi
    mov al, [ebp + wXCoord]
    cmp al, bh                                 ; cp b
    jne .retry2
    mov al, [ebp + esi]                        ; ld a, [hli]
    inc esi
    mov [ebp + wDestinationWarpID], al
    mov al, [ebp + esi]                        ; ld a, [hl] — NOT hli, pret leaves it here
    mov [ebp + hWarpDestinationMap], al
    jmp WarpFound2                             ; jr WarpFound2 — note: NOT WarpFound1
.retry1:
    inc esi
.retry2:
    inc esi
    inc esi
    dec bl                                     ; dec c
    jnz .loop
    jmp OverworldLoop                          ; jp OverworldLoop

WarpFound1:
    mov al, [ebp + esi]                        ; ld a, [hli]
    inc esi
    mov [ebp + wDestinationWarpID], al
    mov al, [ebp + esi]                        ; ld a, [hli]
    inc esi
    mov [ebp + hWarpDestinationMap], al
    ; falls through into WarpFound2 — pret has no jump either

; ---------------------------------------------------------------------------
; WarpFound2 — pret home/overworld.asm:455-517.
;
; HOISTED OUT OF OverworldLoopLessDelay so it can carry its pret name. It used to
; sit mid-routine as the local `.warpTransition`, which meant the pret label read
; `missing` and every caller jumped to a port-local name — the same NAME-FORK class
; as the IsObjectHidden one. A non-local label could not simply be written in place:
; NASM scopes `.local` to the most recent non-local label, so naming it there would
; have rescoped every following `.local` in the routine and silently redirected the
; jumps above it. Hoisting is what makes the name possible, and it also puts the
; body where pret puts it — after the loop, before CheckMapConnections.
;
; pret's WarpFound1 is immediately above and falls through into this, as in pret.
; (It used to have no port body at all: the port's merged CheckWarpTile helper
; carried that half. The helper is gone — see CheckWarpsNoCollision above.)
;
; Reached from five sites, all of them pret's own: the two Safari game-over arms
; (pret :57 and :256), the script warp (pret :61), CheckWarpsCollision's own
; `jr WarpFound2` (pret :439), and the fall-through from WarpFound1.
;
; In: EBP = GB base. hWarpDestinationMap = the RAW destination byte, which is what
; pret branches on and what this routine reads directly (it resolves LAST_MAP
; itself in .indoorMaps). BL = pret's `c`, the warps-remaining counter, live only
; on the two scan entries — see the DEVIATION below. Does not return — tail-jumps
; to EnterMap.
;
; DEVIATION{class=projection; pret=home/overworld.asm:WarpFound2; behavior=none on the wWarpedFromWhichWarp store itself, which is now pret's own `ld a,[wNumberOfWarps] / sub c` — but on the three entries that are not a warp scan, both Safari game-over arms and the script warp, BL holds whatever the port last left there rather than whatever pret last left in c, so the garbage value written differs from the ROM garbage value; evidence=pret reads c on those arms too and nothing sets it there, so the store is indeterminate in the ROM as well - the value's only readers are the Celadon Mart, Rocket Hideout and Silph Co elevator scripts and all three are entered through a warp TILE where the scan has run and both sides agree; lifetime=permanent, an artifact of pret reading an unset register}
; DEVIATION{class=projection; pret=home/overworld.asm:WarpFound2; behavior=.done additionally calls LoadDestinationMapData and InitMapSprites and resets wWalkCounter, both player step vectors, hSCX/hSCY and wMapViewVRAMPointer, none of which pret does here; evidence=pret reaches the destination load through the tail `jp EnterMap` -> LoadMapData, and the port must stage it before that tail because PlayMapChangeSound in every branch above reads the SOURCE map's tileset and door tile — loading the destination first makes it read the wrong tileset; lifetime=permanent, structural}
; ---------------------------------------------------------------------------
WarpFound2:
    ; pret WarpFound2 (home/overworld.asm:455-517), restored to its THREE
    ; branches. This used to be one collapsed path with a
    ; `wCurMap < FIRST_INDOOR_MAP_ID` heuristic standing in for
    ; CheckIfInOutsideMap, which dropped pret's per-branch behaviour wholesale:
    ; the wWarpedFromWhichWarp/Map stores (READ by the three elevator scripts,
    ; and never written), wUnusedLastMapWidth, the ROCK_TUNNEL_1F fade, the
    ; warp-pad/fly branch, and .goBackOutside's wMapPalOffset reset.
    ;
    ; hWarpDestinationMap = the RAW destination byte, which is what pret
    ; branches on; this routine resolves LAST_MAP itself in .indoorMaps.
    ; ---------------------------------------------------------------------
    ; ld a, [wNumberOfWarps] / sub c / ld [wWarpedFromWhichWarp], a  (pret :456-458)
    ; RESTORED 2026-08-22 with the warp scans; it had been displaced into the
    ; deleted CheckWarpTile helper. BL is pret's c — the warps-remaining counter,
    ; decremented only on a NON-match, so on a match it still counts the current
    ; entry and wNumberOfWarps - c is its 0-based index.
    mov al, [ebp + wNumberOfWarps]
    sub al, bl
    mov [ebp + wWarpedFromWhichWarp], al
    ; ld a, [wCurMap] / ld [wWarpedFromWhichMap], a   (pret :459-460)
    mov al, [ebp + wCurMap]
    mov [ebp + wWarpedFromWhichMap], al
    ; call CheckIfInOutsideMap / jr nz, .indoorMaps   (pret :461-462)
    call CheckIfInOutsideMap                   ; ZF=1 -> outside (tileset OVERWORLD/PLATEAU)
    jnz .indoorMaps

; --- outside maps: cannot have the $FF destination ------------------- pret :463
    mov al, [ebp + wCurMap]
    mov [ebp + wLastMap], al                   ; ld [wLastMap], a
    mov al, [ebp + wCurMapWidth]
    mov [ebp + wUnusedLastMapWidth], al        ; ld [wUnusedLastMapWidth], a
    mov al, [ebp + hWarpDestinationMap]        ; ldh a, [hWarpDestinationMap]
    mov [ebp + wCurMap], al                    ; ld [wCurMap], a
    cmp al, ROCK_TUNNEL_1F                     ; cp ROCK_TUNNEL_1F
    jne .notRockTunnel
    mov byte [ebp + wMapPalOffset], 6          ; ld a, $06 / ld [wMapPalOffset], a
    call GBFadeOutToBlack
.notRockTunnel:
    call SetPikachuSpawnOutside                ; callfar SetPikachuSpawnOutside
    call PlayMapChangeSound                    ; reads the SOURCE tileset - must precede
    jmp .done                              ;   LoadDestinationMapData (see .done)

; --- maps that can carry the $FF destination ------------------------- pret :482
.indoorMaps:
    mov al, [ebp + hWarpDestinationMap]        ; ldh a, [hWarpDestinationMap]
    cmp al, LAST_MAP                           ; cp LAST_MAP
    je .goBackOutside
    mov [ebp + wCurMap], al                    ; ld [wCurMap], a
    call IsPlayerStandingOnWarpPadOrHole        ; farcall IsPlayerStandingOnWarpPadOrHole
    mov al, [ebp + wStandingOnWarpPadOrHole]
    dec al                                     ; dec a - is the player on a warp pad?
    jnz .notWarpPad
    call LeaveMapAnim
    or byte [ebp + wStatusFlags6], (1 << BIT_FLY_WARP)   ; set BIT_FLY_WARP, [hl]
    jmp .skipMapChangeSound                    ; a warp pad plays NO map-change jingle
.notWarpPad:
    call PlayMapChangeSound
.skipMapChangeSound:
    ; res BIT_STANDING_ON_DOOR / res BIT_EXITING_DOOR   (pret :498-500)
    and byte [ebp + wMovementFlags], ~((1 << BIT_STANDING_ON_DOOR) | (1 << BIT_EXITING_DOOR)) & 0xFF
    call SetPikachuSpawnWarpPad                ; callfar SetPikachuSpawnWarpPad
    jmp .done

; --- $FF destination: return to the outside map we came from --------- pret :506
.goBackOutside:
    ; SetPikachuSpawnBackOutside runs BEFORE wCurMap is reassigned, so it reads the
    ; SOURCE map. The other two setters run after and read the DESTINATION. Ordering
    ; is load-bearing: all three switch on wCurMap.
    call SetPikachuSpawnBackOutside            ; callfar SetPikachuSpawnBackOutside
    mov al, [ebp + wLastMap]                   ; ld a, [wLastMap]
    mov [ebp + wCurMap], al                    ; ld [wCurMap], a
    call PlayMapChangeSound
    mov byte [ebp + wMapPalOffset], 0          ; xor a / ld [wMapPalOffset], a

; --- pret .done ------------------------------------------------------ pret :513
.done:
    ; Port-specific arrival work. pret reaches the destination load through
    ; EnterMap -> LoadMapData; the port stages part of it here. It sits AFTER the
    ; branches because every branch has already called PlayMapChangeSound, which
    ; must read the SOURCE map's tileset and door tile (OW-A.14) - loading the
    ; destination first would make it read the wrong tileset.
    movzx eax, byte [ebp + wCurMap]
    lea esi, [MapTextTablePointers]
    mov esi, [esi + eax*4]
    mov [w_map_text_table_ptr], esi
    mov byte [ebp + wWalkCounter], 0
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0
    mov byte [ebp + hSCY], 0
    mov byte [ebp + hSCX], 0
    mov word [ebp + wMapViewVRAMPointer], GB_TILEMAP0
    call LoadDestinationMapData
    call InitMapSprites                        ; populate NPC slots for the new map
    ; set BIT_STANDING_ON_DOOR - have the player step out from the door, if any.
    ; pret :513-514. The .indoorMaps branch cleared both door bits above; this set is
    ; unconditional in pret and drives RunNPCMovementScript -> PlayerStepOutFromDoor on
    ; the next idle frame. PlayerStepOutFromDoor re-sets BIT_EXITING_DOOR only when the
    ; arrival tile really is a door, so stair arrivals leave it clear.
    or byte [ebp + wMovementFlags], (1 << BIT_STANDING_ON_DOOR)
    call IgnoreInputForHalfSecond              ; call IgnoreInputForHalfSecond
    ; OW-A.4(b): pret WarpFound2.done ends `jp EnterMap`. EnterMap re-runs the full
    ; reset ladder - wJoyIgnore gate, LoadMapData, ClearVariablesOnEnterMap, the
    ; fly/dungeon-warp and battle-return resets, UpdateSprites, CUR_MAP_LOADED_1/2.
    ; InitMapSprites above is therefore partly redundant with LoadMapData's sprite
    ; load, and is a harmless idempotent slot repopulate (MCP live-warp confirmed).
    jmp EnterMap

section .text

; ---------------------------------------------------------------------------
; CheckForUserInterruption — return CF set if Up+Select+B, Start, or A are pressed
; within BL (pret C) frames; CF clear on timeout. The intro / title / Game Freak
; splash skip-check.
;
; DEVIATION{class=data-model; pret=home/overworld.asm:CheckForUserInterruption; behavior=the _DEBUG-only extra Select skip is dropped (release build); evidence=the port defines no _DEBUG, so pret's ELSE branch (Start|A) is the live one; lifetime=until a debug build defines _DEBUG}
;
; In:  BL = frame count (pret C). EBP = GB base.
; Out: CF = 1 if interrupted, 0 on timeout. Clobbers EAX; BL decremented to 0.
; ---------------------------------------------------------------------------
global CheckForUserInterruption

global StepCountCheck
global AllPokemonFainted
global NewBattle
global CheckIfInOutsideMap
global ExtraWarpCheck
global StopBikeSurf
global LoadPlayerSpriteGraphics
global IsBikeRidingAllowed
global SignLoop
global CheckForJumpingAndTilePairCollisions
global CheckForTilePairCollisions2
global CheckForTilePairCollisions
global AreInputsSimulated
global GetSimulatedInput
global RunMapScript
global LoadWalkingPlayerSpriteGraphics
global LoadSurfingPlayerSpriteGraphics2
global LoadSurfingPlayerSpriteGraphics
global LoadBikePlayerSpriteGraphics
global LoadPlayerSpriteGraphicsCommon
global CopySignData
global ForceBikeOrSurf
global HandleMidJump
global WarpFound2
global CheckMapConnections
global CopyMapConnectionHeader
global ScheduleNorthRowRedraw
global CopyToRedrawRowOrColumnSrcTiles
global ScheduleSouthRowRedraw
global ScheduleEastColumnRedraw
global ScheduleColumnRedrawHelper
global ScheduleWestColumnRedraw
global DrawTileBlock
global CopyMapViewToVRAM
global CopyMapViewToVRAM2
global FinishReloadingMap
global LoadCurrentMapView
global LoadDestinationWarpPosition
global LoadEastWestConnectionsTileMap
global LoadMapData
global LoadMapHeader
global LoadNorthSouthConnectionsTileMap
global LoadScreenRelatedData
global LoadTileBlockMap
global LoadTilesetTilePatternData
global PlayMapChangeSound
global ReloadMapAfterSurfingMinigame
global ResetMapVariables

; --------------------------------------------------------------------------
; StepCountCheck — decrement the per-step counters (pret home/overworld.asm:298).
; If simulated joypad input is active (scripted movement) it does nothing, so
; scripted door-exit steps don't count. Otherwise it decrements wStepCounter, and
; — only while the post-battle "no random battle" cooldown is armed — decrements
; wNumberOfNoRandomBattleStepsLeft, clearing the cooldown bit when it hits 0.
; Touches WRAM only; safe to call unconditionally.
; --------------------------------------------------------------------------
StepCountCheck:
    test byte [ebp + wStatusFlags5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jnz .doneStepCounting                     ; jr nz — inputs simulated, don't count
    dec byte [ebp + wStepCounter]             ; dec [hl] (wStepCounter)
    test byte [ebp + wStatusFlags2], (1 << BIT_WILD_ENCOUNTER_COOLDOWN)
    jz .doneStepCounting                      ; cooldown not armed
    dec byte [ebp + wNumberOfNoRandomBattleStepsLeft]
    jnz .doneStepCounting                     ; still counting down
    and byte [ebp + wStatusFlags2], (~(1 << BIT_WILD_ENCOUNTER_COOLDOWN)) & 0xFF
.doneStepCounting:
    ret
AllPokemonFainted:
    mov byte [ebp + wIsInBattle], 0xFF         ; wIsInBattle = $ff (lost)
    call RunMapScript
    jmp HandleBlackOut
NewBattle:
    test byte [ebp + wStatusFlags3], (1 << BIT_ON_DUNGEON_WARP)
    jnz .noBattle                             ; on a dungeon warp — no battle
    call IsPlayerCharacterBeingControlledByGame
    jnz .noBattle                             ; player under game control — no battle
    test byte [ebp + wStatusFlags4], (1 << BIT_NO_BATTLES)
    jnz .noBattle                             ; battles suppressed — no battle
    call InitBattle                            ; returns CF=1 only when a battle ran
    ; _InitBattleCommon's tail returns CF=1. The post-battle
    ; re-entry (pret .battleOccurred → AnyPartyAlive → EnterMap full map reload) is built
    ; into OverworldLoop (overworld.asm), which the CF=1 return below drives.
    ret
.noBattle:
    clc
    ret

; ---------------------------------------------------------------------------
; DoBikeSpeedup — bikes move twice as fast as walking (OW-A.6).
; Pret ref: home/overworld.asm:339 DoBikeSpeedup.
;
; Called once per .moveAhead frame; when riding a bike it advances the player
; sprite a second time (2 px/frame). On Cycling Road (ROUTE_17) the speedup is
; suppressed while UP/LEFT/RIGHT is held (the forced-southward drift stays at
; walking speed). Inert in today's live build — wWalkBikeSurfState is never 1
; until Bicycle item-use / ForceBikeOrSurf links.
;
; PORT NOTE: the port's AdvancePlayerSprite returns CF=1 on a map-connection
; crossing; this inner call's CF is discarded (pret drops it too — its crossing
; is caught by CheckMapConnections on the wWalkCounter path). Revisit the
; crossing-mid-speedup case when biking goes live.
; ---------------------------------------------------------------------------
DoBikeSpeedup:
    mov al, [ebp + wWalkBikeSurfState]
    dec al                                         ; riding a bike? (state == 1)
    jnz .done                                      ; ret nz
    test byte [ebp + wMovementFlags], (1 << BIT_LEDGE_OR_FISHING)
    jnz .done                                      ; ret nz — mid ledge-hop/fishing
    cmp byte [ebp + wNPCMovementScriptPointerTableNum], 0
    jne .done                                      ; ret nz — movement script active
    mov al, [ebp + wCurMap]
    cmp al, ROUTE_17                               ; Cycling Road
    jne .goFaster
    test byte [ebp + hJoyHeld], PAD_UP | PAD_LEFT | PAD_RIGHT
    jnz .done                                      ; ret nz — braking on Cycling Road
.goFaster:
    call AdvancePlayerSprite                       ; second advance → double speed
.done:
    ret

; ---------------------------------------------------------------------------
; CheckMapConnections — faithful translation.
; Pret ref: home/overworld.asm:CheckMapConnections
; ---------------------------------------------------------------------------
CheckMapConnections:
    push ebx
    push edx

    ; Edge thresholds
    mov al, [ebp + wCurMapHeight]
    add al, al
    mov [ebp + wCurrentMapHeight2], al
    mov al, [ebp + wCurMapWidth]
    add al, al
    mov [ebp + wCurrentMapWidth2], al

    ; East connection check
    mov al, [ebp + wXCoord]
    cmp al, [ebp + wCurrentMapWidth2]
    jne .checkWest
    mov al, [ebp + W_EAST_CONNECTED_MAP]
    cmp al, MAP_NO_CONNECTION
    je .checkWest
    mov ebx, W_EAST_CONNECTED_MAP
    
    mov [ebp + wCurMap], al
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_X_ALIGN]
    mov [ebp + wXCoord], al
    mov al, [ebp + wYCoord]
    mov cl, al
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_Y_ALIGN]
    add cl, al
    mov [ebp + wYCoord], cl
    
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_VIEW_PTR]
    mov dl, al
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_VIEW_PTR + 1]
    mov dh, al
    
    shr cl, 1
    jz .savePointer2
    
.pointerAdjustmentLoop2:
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_MAP_WIDTH]
    add al, MAP_BORDER * 2
    movzx eax, al
    add edx, eax
    dec cl
    jnz .pointerAdjustmentLoop2
.savePointer2:
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], dx
    jmp .loadNewMap

.checkWest:
    mov al, [ebp + wXCoord]
    cmp al, 255
    jne .checkSouth
    mov al, [ebp + W_WEST_CONNECTED_MAP]
    cmp al, MAP_NO_CONNECTION
    je .checkSouth
    mov ebx, W_WEST_CONNECTED_MAP
    
    mov [ebp + wCurMap], al
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_X_ALIGN]
    mov [ebp + wXCoord], al
    mov al, [ebp + wYCoord]
    mov cl, al
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_Y_ALIGN]
    add cl, al
    mov [ebp + wYCoord], cl
    
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_VIEW_PTR]
    mov dl, al
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_VIEW_PTR + 1]
    mov dh, al
    
    shr cl, 1
    jz .savePointer1
    
.pointerAdjustmentLoop1:
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_MAP_WIDTH]
    add al, MAP_BORDER * 2
    movzx eax, al
    add edx, eax
    dec cl
    jnz .pointerAdjustmentLoop1
.savePointer1:
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], dx
    jmp .loadNewMap

.checkSouth:
    mov al, [ebp + wYCoord]
    cmp al, [ebp + wCurrentMapHeight2]
    jne .checkNorth
    mov al, [ebp + W_SOUTH_CONNECTED_MAP]
    cmp al, MAP_NO_CONNECTION
    je .checkNorth
    mov ebx, W_SOUTH_CONNECTED_MAP
    
    mov [ebp + wCurMap], al
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_Y_ALIGN]
    mov [ebp + wYCoord], al
    mov al, [ebp + wXCoord]
    mov cl, al
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_X_ALIGN]
    add cl, al
    mov [ebp + wXCoord], cl
    
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_VIEW_PTR]
    mov dl, al
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_VIEW_PTR + 1]
    mov dh, al
    
    shr cl, 1
    jz .savePointer4
    movzx ecx, cl
    add edx, ecx
.savePointer4:
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], dx
    jmp .loadNewMap

.checkNorth:
    mov al, [ebp + wYCoord]
    cmp al, 255
    jne .done
    mov al, [ebp + wNorthConnectedMap]
    cmp al, MAP_NO_CONNECTION
    je .done
    mov ebx, wNorthConnectedMap
    
    mov [ebp + wCurMap], al
    mov al, [ebp + wNorthConnectedMap + CONN_Y_ALIGN]
    mov [ebp + wYCoord], al
    mov al, [ebp + wXCoord]
    mov cl, al
    mov al, [ebp + wNorthConnectedMap + CONN_X_ALIGN]
    add cl, al
    mov [ebp + wXCoord], cl
    
    mov al, [ebp + wNorthConnectedMap + CONN_VIEW_PTR]
    mov dl, al
    mov al, [ebp + wNorthConnectedMap + CONN_VIEW_PTR + 1]
    mov dh, al
    
    shr cl, 1
    jz .savePointer3
    movzx ecx, cl
    add edx, ecx
.savePointer3:
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], dx
    jmp .loadNewMap

.done:
    pop edx
    pop ebx
    clc                                        ; CF=0 → no transition
    ret

.loadNewMap:
    ; A connection was crossed. pret home/overworld.asm:.loadNewMap inlines the whole
    ; reload here — Pikachu spawn set, LoadMapHeader, PlayDefaultMusicFadeOutCurrent,
    ; RunPaletteCommand(SET_PAL_OVERWORLD), InitMapSprites, LoadTileBlockMap, then
    ; jp OverworldLoopLessDelay. The port instead returns CF=1 and the caller performs
    ; that reload at OverworldLoop.mapTransition, which now does LoadMapHeader +
    ; PlayDefaultMusicFadeOutCurrent (OW-A.14, real); palette reload still deferred.
    ; Only the coordinate/block sync stays inline here.
    ; First, synchronize block coordinates with the new tile coordinates.
    mov al, [ebp + wXCoord]
    and al, 1
    mov [ebp + wXBlockCoord], al
    mov al, [ebp + wYCoord]
    and al, 1
    mov [ebp + wYBlockCoord], al

    pop edx
    pop ebx
    stc                                        ; CF=1 → transition occurred
    ret

; ---------------------------------------------------------------------------
; PlayMapChangeSound — on a warp, play the "go inside" jingle if the player
; walked through an overworld door tile, else "go outside".
; Pret ref: home/overworld.asm:PlayMapChangeSound (:666). Called from WarpFound2
; (the port's WarpFound2) before EnterMap, so it reads the SOURCE map's
; tilemap (the door the player stepped on), not the destination.
; Preserves nothing pret doesn't (AL used); the caller has no live regs here.
; ---------------------------------------------------------------------------
PlayMapChangeSound:
    mov al, [ebp + wCurMapTileset]
    cmp al, FACILITY
    je .didNotGoThroughDoor
    cmp al, CEMETERY
    je .didNotGoThroughDoor
    ; pret lda_coord 8, 8 = upper-left tile of the player's block, one row above the
    ; standing tile (lda_coord 8, 9 → port PLAYER_STANDING). Port row scaling is 1:1
    ; (fronts are ±2 rows), so project to (PLAYER_STANDING_ROW - 1, PLAYER_STANDING_COL).
    ; ; PROJ: this door-tile row projection + the pre-EnterMap tilemap timing are
    ; unverified (no golden warp scenario) — the go-inside/go-outside SFX selection
    ; needs MCP live-warp verification. Wrong projection only mis-picks the jingle.
    movzx eax, byte [ebp + wTileMap + (PLAYER_STANDING_ROW - 1) * SCREEN_TILES_W + PLAYER_STANDING_COL]
    cmp al, OVERWORLD_DOOR_TILE                  ; pret: cp $0b (door tile in tileset 0)
    jne .didNotGoThroughDoor
    mov al, SFX_GO_INSIDE
    jmp .playSound
.didNotGoThroughDoor:
    mov al, SFX_GO_OUTSIDE
.playSound:
    call PlaySound
    ; --- pret :681-684. RESTORED 2026-08-21. ***THIS TAIL IS THE DOOR/STAIR/LADDER
    ; TRANSITION.*** Gen 1 has no door-opening animation: walking into a door, up or
    ; down stairs, or up or down a ladder fades the screen to black here, loads the
    ; destination while it is black, and the first LoadGBPal of the next
    ; OverworldLoopLessDelay iteration snaps the palette back. Without this tail the
    ; map simply cut, which is what "the transitions do not work" looked like.
    ;
    ; It was stubbed as "TODO-HW: palette/fade (Phase 5) — deferred (DMG-green debug
    ; palette)". THAT PREMISE EXPIRED with the colorization plan (2026-07-13): there
    ; is no DMG-green ramp any more, and these fades never needed Phase-5 colour in
    ; the first place. GBFadeOutToBlack only walks the three DMG palette REGISTERS
    ; down the FadePal shade ramps (src/home/fade.asm's own header says so), and
    ; commit_palette re-maps whatever those registers hold through the live CGB slot
    ; palettes every DelayFrame. The routine was already translated AND already called
    ; from ROCK_TUNNEL_1F's arm above, HandleBlackOut, and a dozen map scripts — this
    ; one call site was the only thing still missing.
    ;
    ; The wMapPalOffset guard is pret's and is load-bearing, not defensive: the
    ; ROCK_TUNNEL_1F branch in WarpFound2 sets the offset to 6 and fades ITSELF before
    ; calling here, so without the guard that warp would fade twice.
    mov al, [ebp + wMapPalOffset]
    test al, al                                  ; pret: and a
    jnz .noFade                                  ; pret: ret nz
    jmp GBFadeOutToBlack                         ; pret: jp GBFadeOutToBlack
.noFade:
    ret

CheckIfInOutsideMap:
    mov al, [ebp + wCurMapTileset]
    test al, al                     ; OVERWORLD → ZF=1
    jz .ret
    cmp al, TILESET_PLATEAU         ; PLATEAU  → ZF=1
.ret:
    ret

; ---------------------------------------------------------------------------
; ExtraWarpCheck — pret home/overworld.asm:ExtraWarpCheck
;
; An extra check that sometimes must pass to warp, beyond standing on a warp.
; Depending on the map, either "function 1" or "function 2" is selected:
;   function 1 (IsPlayerFacingEdgeOfMap):    pass if the player is at the edge
;              of the map and facing outward  — used by interior maps (the
;              default) and, exceptionally, SS_ANNE_3F.
;   function 2 (IsWarpTileInFrontOfPlayer):  pass if the tile in front of the
;              player is a warp-carpet tile   — used by the OVERWORLD / SHIP /
;              SHIP_PORT / PLATEAU tilesets and the Rocket Hideout / Rock Tunnel
;              dungeon floors.
;
; Out: CF=1 if the check passes (a warp is possible), CF=0 otherwise.
; Register-safe: preserves EAX/EBX/ECX/EDX/ESI; returns only CF.
;
; NOTE (working-warps preservation): every interior map the port currently
; supports (Red's House, Blue's House, Oak's Lab, Marts, Poké Centers, …) puts
; its exit-door warp on the bottom tile row, i.e. wYCoord == wCurMapHeight*2-1.
; With the player facing DOWN there, function 1 returns carry exactly where the
; old hardcoded "facing DOWN" test did — so the live door exits keep working,
; while side/top-edge and warp-carpet warps now behave faithfully too. The data
; function 1 needs (height/width/coords/facing) is fully populated, and function
; 2 reads the already-populated wTileInFrontOfPlayer (see below), so no
; fallback to the old behavior is required.
; ---------------------------------------------------------------------------
ExtraWarpCheck:
    push eax
    push ebx
    push ecx
    push edx
    push esi

    mov al, [ebp + wCurMap]
    cmp al, MAP_SS_ANNE_3F
    je .useFunction1
    cmp al, MAP_ROCKET_HIDEOUT_B1F
    je .useFunction2
    cmp al, MAP_ROCKET_HIDEOUT_B2F
    je .useFunction2
    cmp al, MAP_ROCKET_HIDEOUT_B4F
    je .useFunction2
    cmp al, MAP_ROCK_TUNNEL_1F
    je .useFunction2

    mov al, [ebp + wCurMapTileset]
    test al, al                     ; OVERWORLD (0) → function 2
    jz .useFunction2
    cmp al, TILESET_SHIP
    je .useFunction2
    cmp al, TILESET_SHIP_PORT
    je .useFunction2
    cmp al, TILESET_PLATEAU
    je .useFunction2

.useFunction1:
    call IsPlayerFacingEdgeOfMap    ; sets CF
    jmp .done
.useFunction2:
    call IsWarpTileInFrontOfPlayer  ; sets CF
.done:
    ; POP does not affect CF, so the helper's CF is returned intact.
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; MapEntryAfterBattle — pret home/overworld.asm:MapEntryAfterBattle (:730-735).
;
;     farcall IsPlayerStandingOnWarp   ; for enabling warp testing after collisions
;     ld a, [wMapPalOffset] / and a
;     jp z, GBFadeInFromWhite
;     jp LoadGBPal
;
; Called from EnterMap's `call nz` on the post-battle re-entry path. Retired the
; ret-stub in overworld_stubs.asm (2026-08-22). The stub was NOT behaviour-neutral:
; without the IsPlayerStandingOnWarp call, BIT_STANDING_ON_WARP is left cleared when
; the player returns from a battle fought while standing on a warp tile, and the
; collision-exit path in OverworldLoop then refuses to fire — the player is stuck
; on a doorway until they step off and back on.
;
; Both tails are jumps, not calls: pret ends on `jp`.
; ---------------------------------------------------------------------------
global MapEntryAfterBattle
MapEntryAfterBattle:
    call IsPlayerStandingOnWarp             ; farcall — flat model, direct call
    cmp byte [ebp + wMapPalOffset], 0       ; ld a,[wMapPalOffset] / and a
    jne .loadPal
    jmp GBFadeInFromWhite                   ; jp z, GBFadeInFromWhite
.loadPal:
    jmp LoadGBPal                           ; jp LoadGBPal

; ---------------------------------------------------------------------------
; HandleBlackOut — the whole party fainted: fade out, kill the music, halve the
; money / heal the party, and warp the player to their last Pokémon Center.
; Pret ref: home/overworld.asm:737 (HandleBlackOut, bank 00 — golden 00:0762).
; Does NOT print the "blacked out" message (its caller does).
; Reached from AllPokemonFainted (engine/overworld/wild_encounter_check.asm).
; ---------------------------------------------------------------------------
global HandleBlackOut
HandleBlackOut:
    call GBFadeOutToBlack
    mov al, 0x08                        ; ld a, $08 — fade-out control value
    call StopMusic
    ; ld hl, wStatusFlags4 / res BIT_BATTLE_OVER_OR_BLACKOUT, [hl]
    and byte [ebp + wStatusFlags4], (~(1 << BIT_BATTLE_OVER_OR_BLACKOUT)) & 0xFF
    mov al, 0x01                        ; ld a, BANK(PrepareForSpecialWarp) — golden 01:6042
    call BankswitchCommon               ; flat: records hLoadedROMBank (no MBC write)
    call ResetStatusAndHalveMoneyOnBlackout   ; callfar (flat: direct call)
    call PrepareForSpecialWarp
    call PlayDefaultMusicFadeOutCurrent
    jmp SpecialEnterMap                 ; jp SpecialEnterMap (tail)

; ---------------------------------------------------------------------------
; StopMusic — arm the audio fade-out (AL = wAudioFadeOutControl), stop the music
; engine, wait for the fade to finish, then silence every channel.
; Pret ref: home/overworld.asm:752 (StopMusic, golden 00:0785).
; In: AL = fade-out control value.
;
; DIVERGENCE 1 (audio tick location): on the GB the VBlank ISR advances the audio
; engine, so pret's bare `jr nz, .wait` spin sees wAudioFadeOutControl reach 0.
; The port has no VBlank audio ISR — the tick lives in DelayFrame (→ audio_tick →
; FadeOutAudio, which is what decrements the counter). A bare spin here would
; hang forever, so the wait pumps DelayFrame. Same idiom and same reason as
; home/audio.asm:WaitForSoundToFinish. (engine/overworld/healing_machine.asm
; bounds its copy of this spin instead; pumping is the correct form.)
;
; DIVERGENCE 2 (engine-offline guard): the port has a state the GB does not — the
; audio engine can be OFFLINE (`/NOSOUND`, or any build before audio_init runs;
; audio_tick self-gates on g_audio_engine_online). Offline, FadeOutAudio never
; runs, so nothing would ever clear the byte we just wrote and the wait above
; would spin forever. PlaySound already carries the mirror-image scaffold — it
; swallows requests while offline so WaitForSoundToFinish's spin exits at once —
; but StopMusic writes wAudioFadeOutControl directly, bypassing that. So: offline,
; skip the fade and clear the byte, preserving pret's post-condition
; (wAudioFadeOutControl == 0 on return) for whoever brings the engine online later.
; ---------------------------------------------------------------------------
global StopMusic
StopMusic:
    mov [ebp + wAudioFadeOutControl], al    ; ld [wAudioFadeOutControl], a
    call StopAllMusic
    cmp byte [g_audio_engine_online], 0     ; PORT GUARD — see DIVERGENCE 2
    jz .offline
.wait:
    mov al, [ebp + wAudioFadeOutControl]
    test al, al                             ; and a — fade-out finished?
    jz .done
    call DelayFrame                         ; pump the audio tick (see DIVERGENCE 1)
    jmp .wait
.offline:
    mov byte [ebp + wAudioFadeOutControl], 0 ; no tick will ever clear it
.done:
    jmp StopAllSounds                       ; jp StopAllSounds (tail)

; ---------------------------------------------------------------------------
; HandleFlyWarpOrDungeonWarp — leave the current map by a SPECIAL warp (Fly, Dig,
; Escape Rope, or a dungeon warp-pad/hole), rather than by stepping on a warp tile.
; Pret ref: home/overworld.asm:761 (HandleFlyWarpOrDungeonWarp, bank 00).
;
; The producers (ItemUseEscapeRope / ItemUseFly / the warp-pad script) only SET the
; wStatusFlags6 FLY_WARP / DUNGEON_WARP bits; this is the consumer that acts on them.
; OverworldLoopLessDelay tests those bits every idle iteration and tail-jumps here.
;
; PrepareForSpecialWarp reads the same two bits to pick the destination (last Pokémon
; Center for a fly/escape warp, the dungeon's paired warp for a dungeon warp), so they
; must still be set on entry — this routine does NOT clear them. EnterMap clears them
; on arrival (see .didNotEnterUsingFlyWarpOrDungeonWarp above), after EnterMapAnim has
; consumed them for the arrival animation.
;
; PORT NOTE: `ld a, BANK(PrepareForSpecialWarp) / call BankswitchCommon` is kept (it
; records hLoadedROMBank; no MBC write in the flat model), same as HandleBlackOut.
; ---------------------------------------------------------------------------
global HandleFlyWarpOrDungeonWarp
HandleFlyWarpOrDungeonWarp:
    call UpdateSprites
    call Delay3
    xor al, al
    mov [ebp + wBattleResult], al
    mov [ebp + wIsInBattle], al
    mov [ebp + wMapPalOffset], al
    ; ld hl, wStatusFlags6 / set BIT_FLY_OR_DUNGEON_WARP, [hl] / res BIT_ALWAYS_ON_BIKE, [hl]
    or  byte [ebp + wStatusFlags6], (1 << BIT_FLY_OR_DUNGEON_WARP)
    and byte [ebp + wStatusFlags6], (~(1 << BIT_ALWAYS_ON_BIKE)) & 0xFF
    call LeaveMapAnim
    call StopBikeSurf
    mov al, 0x01                        ; ld a, BANK(PrepareForSpecialWarp)
    call BankswitchCommon               ; flat: records hLoadedROMBank (no MBC write)
    call PrepareForSpecialWarp
    jmp SpecialEnterMap                 ; jp SpecialEnterMap (tail)

; ---------------------------------------------------------------------------
; LeaveMapAnim — pret home/overworld.asm:778 (`farjp _LeaveMapAnim`). The bank
; switch is a no-op in the flat model, so the wrapper is a bare tail-jump; it is
; kept as its own pret-named symbol rather than inlined, so callers keep matching
; pret line-for-line.
; ---------------------------------------------------------------------------
global LeaveMapAnim
LeaveMapAnim:
    jmp _LeaveMapAnim                   ; engine/overworld/player_animations.asm

StopBikeSurf:
    mov al, [ebp + wWalkBikeSurfState]
    test al, al
    jz .done                                ; ret z (already walking)
    mov byte [ebp + wWalkBikeSurfState], 0
    test byte [ebp + wStatusFlags6], (1 << BIT_DUNGEON_WARP)
    jz .done                                ; ret z
    call PlayDefaultMusic                    ; pret: call PlayDefaultMusic
.done:
    ret

; ---------------------------------------------------------------------------
; LoadPlayerSpriteGraphics — dispatcher.
; Pret ref: home/overworld.asm:LoadPlayerSpriteGraphics
; Loads standing/biking/surfing tiles based on wWalkBikeSurfState
; (0=standing, 1=biking, 2=surfing). If biking is not currently allowed the
; state is reset to standing first.
; ---------------------------------------------------------------------------
LoadPlayerSpriteGraphics:
    mov al, [ebp + wWalkBikeSurfState]
    dec al
    jz .ridingBike                          ; state == 1

    ; standing (or surfing): honor hTileAnimations gate as pret does
    mov al, [ebp + hTileAnimations]
    test al, al
    jnz .determineGraphics
    jmp .startWalking

.ridingBike:
    ; If the bike can't be used here, start walking instead.
    call IsBikeRidingAllowed                ; CF = biking allowed
    jc .determineGraphics

.startWalking:
    xor al, al
    mov [ebp + wWalkBikeSurfState],      al
    mov [ebp + wWalkBikeSurfStateCopy], al
    jmp LoadWalkingPlayerSpriteGraphics

.determineGraphics:
    mov al, [ebp + wWalkBikeSurfState]
    test al, al
    jz LoadWalkingPlayerSpriteGraphics       ; 0 → walking
    dec al
    jz LoadBikePlayerSpriteGraphics          ; 1 → biking
    dec al
    jz LoadSurfingPlayerSpriteGraphics2      ; 2 → surfing
    jmp LoadWalkingPlayerSpriteGraphics      ; fallback
IsBikeRidingAllowed:
    mov al, [ebp + wCurMap]
    cmp al, ROUTE_23
    je .allowed
    cmp al, INDIGO_PLATEAU
    je .allowed

    mov bh, [ebp + wCurMapTileset]       ; B = BH
    mov esi, BikeRidingTilesets             ; HL → table
.loop:
    mov al, [esi]                           ; ld a,[hli]
    inc esi
    cmp al, bh
    je .allowed
    inc al                                  ; $FF terminator → 0 (ZF)
    jnz .loop
    clc                                     ; pret: `and a` → CF=0 (not allowed)
    ret
.allowed:
    stc
    ret

; ---------------------------------------------------------------------------
; LoadTilesetTilePatternData — faithful translation.
; Pret ref: home/overworld.asm:LoadTilesetTilePatternData
;
; Reads wTilesetGfxPtr (16-bit GB address) and copies $600 bytes (1536) from
; that ROM-window address to vTileset ($9000 = GB_VCHARS2).
; In the flat model wTilesetBank (FarCopyData bank arg) is ignored.
; ---------------------------------------------------------------------------
LoadTilesetTilePatternData:
    mov byte [g_tilecache_dirty], 1     ; VRAM tile data changes → rebuild decode cache
    ; ESI = wTilesetGfxPtr (16-bit GB address, LE word)
    movzx esi, word [ebp + wTilesetGfxPtr]    ; ESI = HL = 0x4000
    mov edx, GB_VCHARS2                            ; EDX = DE = 0x9000 (vTileset)
    mov bx,  0x0600                                ; BX = BC = $600 bytes
    movzx eax, byte [ebp + wTilesetBank]         ; AL = bank (ignored)
    jmp FarCopyData                                ; tail call

; ---------------------------------------------------------------------------
; LoadTileBlockMap — faithful translation.
; Pret ref: home/overworld.asm:LoadTileBlockMap
;
; 1. Fills wOverworldMap with wMapBackgroundTile (border block).
; 2. Copies PalletTown.blk data (from wCurMapDataPtr) into wOverworldMap,
;    offset by MAP_BORDER rows and MAP_BORDER columns.
; 3. Processes N/S/W/E connection strips (all $FF = none for Phase 2).
; ---------------------------------------------------------------------------
LoadTileBlockMap:
    push esi
    push edi
    push ebx
    push ecx

    ; Fill wOverworldMap..wOverworldMapEnd with wMapBackgroundTile
    mov esi, wOverworldMap
    mov bx,  W_OVERWORLD_MAP_SIZE & 0xFFFF
    movzx eax, byte [ebp + wMapBackgroundTile]
    call FillMemory

    ; HL = ESI = wOverworldMap
    mov esi, wOverworldMap

    ; hMapWidth = wCurMapWidth; hMapStride = width + MAP_BORDER*2
    movzx ecx, byte [ebp + wCurMapWidth]       ; ECX = width (= 10)
    mov byte [ebp + hMapWidth], cl
    add cl, MAP_BORDER * 2                         ; CL = stride (= 16)
    mov byte [ebp + hMapStride], cl

    ; Skip MAP_BORDER rows: ESI += stride * MAP_BORDER
    movzx eax, cl                                  ; EAX = stride
    imul eax, MAP_BORDER                           ; EAX = stride * 3
    add esi, eax                                   ; ESI = row MAP_BORDER start

    ; Skip MAP_BORDER cols: ESI += MAP_BORDER
    add esi, MAP_BORDER                            ; ESI = first cell of map data

    ; DE = wCurMapDataPtr (source: .blk data in ROM window)
    movzx edx, word [ebp + wCurMapDataPtr]    ; EDX = map .blk GB addr (rom_window.inc)

    ; B (BH) = wCurMapHeight (row count)
    movzx eax, byte [ebp + wCurMapHeight]
    mov bh, al

.row_loop:
    push esi                                       ; save row-start write ptr
    movzx ecx, byte [ebp + hMapWidth]            ; CL = map width (without border)
.row_inner_loop:
    mov al, byte [ebp + edx]                       ; read block ID from .blk
    inc edx
    mov byte [ebp + esi], al                       ; write block ID to wOverworldMap
    inc esi
    dec cl
    jnz .row_inner_loop
    pop esi                                        ; restore row-start ptr
    movzx eax, byte [ebp + hMapStride]           ; EAX = stride
    add esi, eax                                   ; advance ESI to next row
    dec bh
    jnz .row_loop

    ; --- Border overrides (map-tool C3): hand-authored blocks for the border
    ;     ring, painted in tools/map_editor/editor.py and generated into
    ;     assets/map_border_overrides.inc. Applied BEFORE the connection
    ;     strips so connections always win (the generator also rejects any
    ;     cell inside a strip or the real map area).
    call ApplyMapBorderOverrides

    ; --- Connection strips: copy each connected map's edge into the wOverworldMap
    ;     border. SwitchToMapRomBank is a no-op in the flat model. The strip src
    ;     pointers (CONN_STRIP_SRC) index into the connected maps' block data
    ;     loaded at OW_ROUTE*_BLK_GBADDR. hNorthSouthConnectionStripWidth and the
    ;     connected-map width reuse hMapStride/hMapWidth (they are HRAM unions).

.north_connection:
    cmp byte [ebp + wNorthConnectedMap], MAP_NO_CONNECTION
    je  .south_connection
    movzx esi, word [ebp + wNorthConnectedMap + CONN_STRIP_SRC]   ; HL = strip src
    movzx edx, word [ebp + wNorthConnectedMap + CONN_STRIP_DEST]  ; DE = strip dest
    mov al, [ebp + wNorthConnectedMap + CONN_STRIP_LENGTH]
    mov [ebp + hMapStride], al                                     ; hNSConnectionStripWidth
    mov al, [ebp + wNorthConnectedMap + CONN_MAP_WIDTH]
    mov [ebp + hMapWidth], al                                      ; hNSConnectedMapWidth
    call LoadNorthSouthConnectionsTileMap

.south_connection:
    cmp byte [ebp + W_SOUTH_CONNECTED_MAP], MAP_NO_CONNECTION
    je  .west_connection
    movzx esi, word [ebp + W_SOUTH_CONNECTED_MAP + CONN_STRIP_SRC]
    movzx edx, word [ebp + W_SOUTH_CONNECTED_MAP + CONN_STRIP_DEST]
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_STRIP_LENGTH]
    mov [ebp + hMapStride], al
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_MAP_WIDTH]
    mov [ebp + hMapWidth], al
    call LoadNorthSouthConnectionsTileMap

.west_connection:
    cmp byte [ebp + W_WEST_CONNECTED_MAP], MAP_NO_CONNECTION
    je  .east_connection
    movzx esi, word [ebp + W_WEST_CONNECTED_MAP + CONN_STRIP_SRC]
    movzx edx, word [ebp + W_WEST_CONNECTED_MAP + CONN_STRIP_DEST]
    movzx ebx, byte [ebp + W_WEST_CONNECTED_MAP + CONN_STRIP_LENGTH] ; B = row count
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_MAP_WIDTH]
    mov [ebp + hMapWidth], al                                      ; hEWConnectedMapWidth
    call LoadEastWestConnectionsTileMap

.east_connection:
    cmp byte [ebp + W_EAST_CONNECTED_MAP], MAP_NO_CONNECTION
    je  .done
    movzx esi, word [ebp + W_EAST_CONNECTED_MAP + CONN_STRIP_SRC]
    movzx edx, word [ebp + W_EAST_CONNECTED_MAP + CONN_STRIP_DEST]
    movzx ebx, byte [ebp + W_EAST_CONNECTED_MAP + CONN_STRIP_LENGTH]
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_MAP_WIDTH]
    mov [ebp + hMapWidth], al
    call LoadEastWestConnectionsTileMap

.done:
    pop ecx
    pop ebx
    pop edi
    pop esi
    ret

; ---------------------------------------------------------------------------
; LoadNorthSouthConnectionsTileMap — faithful translation.
; Pret ref: home/overworld.asm:LoadNorthSouthConnectionsTileMap
;
; Copies MAP_BORDER (3) rows of the connected map's edge into the wOverworldMap
; border. Each row copies hNorthSouthConnectionStripWidth (=hMapStride) bytes;
; src advances by hNorthSouthConnectedMapWidth (=hMapWidth), dest by the
; wOverworldMap stride (wCurMapWidth + 2*MAP_BORDER).
;
; In:  ESI = HL = strip src, EDX = DE = strip dest, [hMapStride] = strip width,
;      [hMapWidth] = connected-map width. EBP = GB base.
; Clobbers: EAX, EBX, ECX, ESI, EDX.
; ---------------------------------------------------------------------------
LoadNorthSouthConnectionsTileMap:
    mov ecx, MAP_BORDER                  ; C = 3 rows
.row:
    push esi
    push edx
    movzx ebx, byte [ebp + hMapStride] ; B = strip width
.inner:
    mov al, [ebp + esi]
    mov [ebp + edx], al
    inc esi
    inc edx
    dec bl
    jnz .inner
    pop edx
    pop esi
    movzx eax, byte [ebp + hMapWidth]  ; src += connected-map width
    add esi, eax
    movzx eax, byte [ebp + wCurMapWidth]
    add eax, MAP_BORDER * 2
    add edx, eax                         ; dest += wOverworldMap stride
    dec ecx
    jnz .row
    ret

; ---------------------------------------------------------------------------
; LoadEastWestConnectionsTileMap — faithful translation.
; Pret ref: home/overworld.asm:LoadEastWestConnectionsTileMap
;
; Copies MAP_BORDER (3) columns of the connected map's edge into the
; wOverworldMap border, for B (strip length) rows. Each row copies 3 bytes; src
; advances by hEastWestConnectedMapWidth (=hMapWidth), dest by the wOverworldMap
; stride. (Pallet Town has no E/W connection, but kept faithful for completeness.)
;
; In:  ESI = HL = strip src, EDX = DE = strip dest, BL = row count,
;      [hMapWidth] = connected-map width. EBP = GB base.
; Clobbers: EAX, EBX(bl=counter), ECX, ESI, EDX.
; ---------------------------------------------------------------------------
LoadEastWestConnectionsTileMap:
.row:
    push esi
    push edx
    mov ecx, MAP_BORDER                  ; 3 columns
.inner:
    mov al, [ebp + esi]
    mov [ebp + edx], al
    inc esi
    inc edx
    dec ecx
    jnz .inner
    pop edx
    pop esi
    movzx eax, byte [ebp + hMapWidth]  ; src += connected-map width
    add esi, eax
    movzx eax, byte [ebp + wCurMapWidth]
    add eax, MAP_BORDER * 2
    add edx, eax                         ; dest += wOverworldMap stride
    dec bl
    jnz .row
    ret

IsSpriteOrSignInFrontOfPlayer:
    mov byte [ebp + hTextID], 0      ; xor a / ldh [hTextID], a
    mov al, [ebp + wNumSigns]      ; ld a, [wNumSigns]
    test al, al                      ; and a
    jz .extendRangeOverCounter       ; jr z, .extendRangeOverCounter
; if there are signs
    call GetTileAndCoordsInFrontOfPlayer ; predef — front map coords in DH/DL
    call SignLoop                    ; CF=1 + [hTextID]=sign id on a match
    jnc .extendRangeOverCounter      ; ┐ pret `ret c`: return only when a sign
    ret                              ; ┘ matched (CF stays set for the caller)
.extendRangeOverCounter:
; counter tile in front? then extend the range at which the player can talk
    call GetTileAndCoordsInFrontOfPlayer ; predef — front tile id in CL
    mov esi, wTilesetTalkingOverTiles ; ld hl, wTilesetTalkingOverTiles
    mov bh, 3                        ; ld b, 3 — the list is 3 bytes
    mov dh, 0x20                     ; ld d, $20 — long talking range, in pixels
.counterTilesLoop:
    mov al, [ebp + esi]              ; ld a, [hli]
    inc esi
    cmp al, cl                       ; cp c — is the front tile a counter tile?
    je IsSpriteInFrontOfPlayer2      ; jr z — long-range scan (DH = $20 survives)
    dec bh                           ; dec b
    jnz .counterTilesLoop            ; jr nz
    ; fall through into IsSpriteInFrontOfPlayer (which presets DH = $10)

IsSpriteInFrontOfPlayer:
    mov dh, 0x10                     ; ld d, $10 — normal talking range, in pixels
IsSpriteInFrontOfPlayer2:
    mov bh, 0x3c                     ; lb bc, $3c, $40 — the player sprite's fixed
    mov bl, 0x40                     ; screen Y ($3c) and X ($40)
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
.checkIfPlayerFacingUp:
    cmp al, SPRITE_FACING_UP
    jne .checkIfPlayerFacingDown
    sub bh, dh                       ; ld a,b / sub d / ld b,a
    mov al, PLAYER_DIR_UP
    jmp .doneCheckingDirection
.checkIfPlayerFacingDown:
    cmp al, SPRITE_FACING_DOWN
    jne .checkIfPlayerFacingRight
    add bh, dh
    mov al, PLAYER_DIR_DOWN
    jmp .doneCheckingDirection
.checkIfPlayerFacingRight:
    cmp al, SPRITE_FACING_RIGHT
    jne .playerFacingLeft
    add bl, dh
    mov al, PLAYER_DIR_RIGHT
    jmp .doneCheckingDirection
.playerFacingLeft:
    sub bl, dh
    mov al, PLAYER_DIR_LEFT
.doneCheckingDirection:
    mov [ebp + wPlayerDirection], al
    mov esi, wSprite01StateData1     ; slot 1 (slot 0 is the player)
    mov dl, 0x01                     ; e = slot index, 1-based
    mov dh, 0x0f                     ; d = 15 slots to scan (range is dead from here)
; Yellow does not have Red's "if sprites are existent" check.
.spriteLoop:
    push esi
    mov al, [ebp + esi + SPRITESTATEDATA1_PICTUREID]
    test al, al
    jz .nextSprite                   ; 0 = no sprite in this slot
    mov al, [ebp + esi + SPRITESTATEDATA1_IMAGEINDEX]
    inc al
    jz .nextSprite                   ; $ff = sprite hidden (pret: inc a / jr z)
    mov al, [ebp + esi + SPRITESTATEDATA1_YPIXELS]
    cmp al, bh
    jne .nextSprite
    mov al, [ebp + esi + SPRITESTATEDATA1_XPIXELS]
    cmp al, bl
    je .foundSpriteInFrontOfPlayer
.nextSprite:
    pop esi
    ; pret does this as `ld a,l / add SPRITESTATEDATA1_LENGTH / ld l,a` — 8-bit math
    ; on L ALONE, and the wrap on the LAST iteration is load-bearing, so it is
    ; reproduced literally here (`add al, imm` leaves the upper 24 bits of EAX alone,
    ; exactly as `ld l,a` leaves H alone).
    ;
    ; The scan walks slots 1-15, $C110..$C1F0, and the add fires once more after slot
    ; 15: L goes $F0 + $10 = $00, so the NOT-FOUND exit returns hl = $C100 — the
    ; PLAYER's slot base — not $C200. A flat `add esi, SPRITESTATEDATA1_LENGTH`
    ; returns $C200 (wSpriteStateData2) instead, and that is not a harmless
    ; difference: pret's ItemUseSurfboard dereferences hl on BOTH exits
    ; (`res BIT_FACE_PLAYER, [hl]` immediately after the call), so the flat form
    ; would clear a bit in the wrong byte on every "no sprite in the way" dismount.
    ; The previous comment here claimed "L never wraps before the counter ends the
    ; loop"; it wraps precisely on the exit that matters. Neither existing caller
    ; (IsSpriteInFrontOfPlayer, IsSpriteOrSignInFrontOfPlayer) reads hl, so this
    ; repair changes no live behaviour — it makes the new consumer correct.
    mov eax, esi
    add al, SPRITESTATEDATA1_LENGTH  ; 8-bit: wraps within L, keeps H
    mov esi, eax
    inc dl
    dec dh                           ; sets the ZF the loop branch reads
    jnz .spriteLoop
    xor al, al                       ; also clears CF: no sprite in front
    ret
.foundSpriteInFrontOfPlayer:
    pop esi
    ; pret: ld a,l / and $f0 / inc a / ld l,a — mask back to the slot base, then +1.
    ; ESI is already the slot base (16-aligned), so the mask is a no-op here.
    add esi, SPRITESTATEDATA1_MOVEMENTSTATUS
    or byte [ebp + esi], (1 << BIT_FACE_PLAYER)  ; set BIT_FACE_PLAYER, [hl]
    mov al, dl
    mov [ebp + hSpriteIndex], al
    ; pret re-reads hSpriteIndex here ("possible useless read because a already has
    ; the value") — elided; AL already holds it.
    cmp al, PIKACHU_SPRITE_INDEX
    jne .dontwritetowd436            ; pret's label typo (.dontwritetowd436 → wd435) kept
    mov byte [ebp + wd435], 0xFF
.dontwritetowd436:
    stc                              ; scf: found
    ret

SignLoop:
    lea esi, [ebp + wSignCoords]      ; hl = wSignCoords
    mov cl, [ebp + wNumSigns]         ; CL = remaining count (b)
    xor ch, ch                          ; CH = 1-based index (c)
.signLoop:
    inc ch                              ; c++
    mov al, [esi]                       ; sign Y
    inc esi
    cmp al, dh
    je .yMatched
    inc esi                             ; skip X
    jmp .retry
.yMatched:
    mov al, [esi]                       ; sign X
    inc esi
    cmp al, dl
    jne .retry
    ; matched: text ID at wSignTextIDs[c-1]
    movzx eax, ch
    dec eax
    mov al, [ebp + eax + wSignTextIDs]
    mov [ebp + hTextID], al
    stc
    ret
.retry:
    dec cl
    jnz .signLoop
    clc
    ret

; ---------------------------------------------------------------------------
; CollisionCheckOnLand — tile passability + sprite collision check.
; Pret ref: home/overworld.asm:CollisionCheckOnLand (:1215-1268).
;
; Instruction-for-instruction translation. Order and flag consumption match
; pret: BIT_LEDGE_OR_FISHING allow, wSimulatedJoypadStatesIndex allow,
; quick reject (one-frame stale COLLISIONDATA), IsSpriteInFrontOfPlayer
; scan with hTextID/hSpriteIndex alias, Pikachu B/counter exemption,
; TilePairCollisionsLand, CheckTilePassable, SFX guard.
; ---------------------------------------------------------------------------
CollisionCheckOnLand:
    extern TilePairCollisionsLand          ; src/data/tilesets/pair_collision_tile_ids.asm
%ifdef DEBUG_NOCLIP
    cmp byte [pad_noclip], 0
    jne .passable
%endif
    push eax
    push ecx
    push esi
    ; :1216 ld a,[wMovementFlags] / bit BIT_LEDGE_OR_FISHING,a / jr nz,.noCollision
    test byte [ebp + wMovementFlags], (1 << BIT_LEDGE_OR_FISHING)
    jnz .noCollision
    ; :1220 ld a,[wSimulatedJoypadStatesIndex] / and a / jr nz,.noCollision
    cmp byte [ebp + wSimulatedJoypadStatesIndex], 0
    jne .noCollision
    ; :1223 ld a,[wPlayerDirection] / ld d,a / ld a,[wSpritePlayerStateData1CollisionData] / and d / nop / jr nz,.collision
    mov dl, [ebp + wPlayerDirection]               ; d = wPlayerDirection
    mov al, [ebp + wSpriteStateData1 + SPRITESTATEDATA1_COLLISIONDATA] ; ld a,[wSpritePlayerStateData1CollisionData]
    and al, dl                                     ; and d — one-frame stale COLLISIONDATA, faithful
    nop                                            ; pret nop — "??? why is this in the code"
    jnz .collision
    ; :1229 xor a / ldh [hTextID],a
    xor al, al
    mov [ebp + hTextID], al                        ; hTextID aliases hSpriteIndex (same HRAM byte 0xFF8C)
    ; :1231 call IsSpriteInFrontOfPlayer / jr nc,.noSpriteCollision
    call IsSpriteInFrontOfPlayer
    jnc .noSpriteCollision
    ; :1233 res BIT_FACE_PLAYER,[hl] — HL is movement-status byte returned by IsSpriteInFrontOfPlayer (ESI)
    and byte [ebp + esi], ~(1 << BIT_FACE_PLAYER)
    ; :1234 ldh a,[hTextID] / and a / jr z,.noSpriteCollision
    mov al, [ebp + hTextID]
    test al, al
    jz .noSpriteCollision
    ; :1237 cp PIKACHU_SPRITE_INDEX / jr nz,.collision
    cmp al, PIKACHU_SPRITE_INDEX
    jne .collision
    ; :1239 call CheckPikachuFollowingPlayer / jr nz,.collision — ZF from bit 1,[hl]; ZF=1 => following
    call CheckPikachuFollowingPlayer
    jnz .collision
    ; :1241 ldh a,[hJoyHeld] / and PAD_B / jr nz,.noSpriteCollision
    mov al, [ebp + hJoyHeld]
    and al, PAD_B
    jnz .noSpriteCollision
    ; :1244 ld hl,wPikachuCollisionCounter / ld a,[hl] / and a / jr z,.noSpriteCollision / dec [hl] / jr nz,.collision
    mov esi, wPikachuCollisionCounter
    mov al, [ebp + esi]
    test al, al
    jz .noSpriteCollision
    dec byte [ebp + esi]
    jnz .collision
.noSpriteCollision:
    ; :1251 ld hl,TilePairCollisionsLand / call CheckForJumpingAndTilePairCollisions / jr c,.collision
    ; LoadCurrentMapView refresh is a port constraint (wTileMap stale within a block); not in pret but required so _GetTileAndCoordsInFrontOfPlayer reads correct coords.
    call LoadCurrentMapView
    push edx                                       ; preserve DH (tile player stands on) across _GetTile
    call _GetTileAndCoordsInFrontOfPlayer          ; CL = tile in front (direct entry, avoids GetPredefRegisters clobber)
    pop edx
    push ebx
    push edx
    mov esi, TilePairCollisionsLand
    call CheckForJumpingAndTilePairCollisions
    pop edx
    pop ebx
    jc .collision
    ; :1254 call CheckTilePassable / jr nc,.noCollision
    call CheckTilePassable
    jnc .noCollision
.collision:
    ; :1256 ld a,[wChannelSoundIDs+CHAN5] / cp SFX_COLLISION / jr z,.setCarry / ld a,SFX_COLLISION / call PlaySound
    mov al, [ebp + wChannelSoundIDs + CHAN5]
    cmp al, SFX_COLLISION
    je .setCarry
    mov al, SFX_COLLISION
    call PlaySound
.setCarry:
    pop esi
    pop ecx
    pop eax
    stc
    ret
.noCollision:
    pop esi
    pop ecx
    pop eax
    clc
    ret
.blocked:
    ; compat alias for old bespoke caller label — now same as .collision
    jmp .collision
%ifdef DEBUG_NOCLIP
.passable:
    clc
    ret
%endif
    ; pret home/overworld.asm:1259-1264 (.collision): play SFX_COLLISION on the bump,
    ; unless it's already playing on CHAN5. Done before the pops so PlaySound's clobber
    ; of eax/ecx/esi is undone by the restores; stc lands after (pop doesn't touch CF).
    mov al, [ebp + wChannelSoundIDs + CHAN5]        ; sound currently on CHAN5
    cmp al, SFX_COLLISION                            ; already playing?
    je .blockedSetCarry                              ; yes → don't retrigger
    mov al, SFX_COLLISION
    call PlaySound
.blockedSetCarry:
    pop esi
    pop ecx
    pop eax
    stc
    ret
%ifdef DEBUG_NOCLIP
.passable:
    clc
    ret
%endif

; ---------------------------------------------------------------------------
; CheckTilePassable — pret home/overworld.asm:CheckTilePassable (:1271-1276).
;
; "function that checks if the tile in front of the player is passable —
;  clears carry if it is, sets carry if not."
;
; Was INLINED into CollisionCheckOnLand (a `movzx ecx, byte [wTileInFrontOfPlayer]`
; + `call IsTilePassable` pair) until 2026-08-22, which left the pret label reading
; `missing` — the same NAME-FORK class as WarpFound2. Extracted here so the label
; exists and the call site reads as pret's does.
;
; pret re-derives the front tile with `predef GetTileAndCoordsInFrontOfPlayer`
; rather than trusting the value the caller already stored, and that is
; load-bearing rather than redundant: CollisionCheckOnLand's preceding
; CheckForJumpingAndTilePairCollisions runs HandleLedges, which clobbers ECX.
; The port calls the direct entry `_GetTileAndCoordsInFrontOfPlayer` instead of
; the predef wrapper, per the established pattern (the wrapper's
; GetPredefRegisters would restore ESI/EBX from stale wPredefHL/wPredefBC — see
; memory flagactionpredef-clobbers-regs).
;
; In:  EBP = GB base; W_SPRITE_PLAYER_FACING_DIR / wYCoord / wXCoord.
; Out: CF = 0 passable, CF = 1 blocked. Clobbers AL, ECX, EDX, ESI (as pret
;      clobbers a/c/de/hl).
; ---------------------------------------------------------------------------
CheckTilePassable:
    call _GetTileAndCoordsInFrontOfPlayer          ; predef GetTileAndCoordsInFrontOfPlayer
    movzx ecx, byte [ebp + wTileInFrontOfPlayer]   ; ld a, [wTileInFrontOfPlayer] / ld c, a
    call IsTilePassable
    ret

; ---------------------------------------------------------------------------
; CheckForJumpingAndTilePairCollisions — pret home/overworld.asm.
;
; In:  ESI = flat host ptr to the directional tile-pair table (TilePairCollisionsLand
;            or ...Water); wTileInFrontOfPlayer already set by the caller.
;            (pret re-runs GetTileAndCoordsInFrontOfPlayer here; both of the
;            port's callers, CollisionCheckOnLand and CollisionCheckOnWater, set
;            it via _GetTileAndCoordsInFrontOfPlayer immediately before — so
;            this port keeps the value rather than re-deriving it. See
;            regression-overworld-watercollision-stale-tile for why
;            CollisionCheckOnWater's call order had to move to match.)
; Out: CF = 1 if an illegal tile-pair boundary is crossed (movement blocked).
;      May arm a ledge hop (HandleLedges sets BIT_LEDGE_OR_FISHING + simulated joypad);
;      in that case CF = 0 (no tile-pair collision) and the caller allows the move.
; Clobbers: AL, BL, CL, DH, ESI, flags.
;
; SM83:
;   push hl / predef GetTileAndCoordsInFrontOfPlayer / farcall HandleLedges
;   and a / ld a,[wMovementFlags] / bit BIT_LEDGE_OR_FISHING,a / ret nz
;   (falls into CheckForTilePairCollisions2)
; ---------------------------------------------------------------------------
CheckForJumpingAndTilePairCollisions:
    push esi                                       ; preserve the table ptr across HandleLedges
    call HandleLedges                              ; may arm a ledge hop
    pop esi
    test byte [ebp + wMovementFlags], (1 << BIT_LEDGE_OR_FISHING)
    jz  CheckForTilePairCollisions2               ; not jumping a ledge → run the tile-pair scan
    clc                                            ; jumping a ledge → no tile-pair collision
    ret
CheckForTilePairCollisions2:
    mov dh, [ebp + STANDING_TILE_OFF]              ; DH = tile the player stands on (pret wTilePlayerStandingOn)
CheckForTilePairCollisions:
    mov cl, [ebp + wTileInFrontOfPlayer]      ; c = tile in front
.loop:
    mov bl, [ebp + wCurMapTileset]              ; b = current tileset (pret re-reads each iter)
    mov al, [esi]                                  ; entry tileset (hl→tile1)
    inc esi
    cmp al, 0xFF
    je  .noMatch
    cmp al, bl
    je  .tilesetMatches
    inc esi                                        ; skip tile1 (hl→tile2)
.retry:
    inc esi                                        ; skip tile2 (hl→next entry)
    jmp .loop
.tilesetMatches:
    mov al, [esi]                                  ; tile1
    cmp al, dh
    je  .firstInPair
    inc esi                                        ; hl→tile2
    mov al, [esi]                                  ; tile2
    cmp al, dh
    je  .secondInPair
    jmp .retry
.firstInPair:
    inc esi                                        ; hl→tile2
    mov al, [esi]                                  ; tile2
    cmp al, cl
    je  .foundMatch
    jmp .loop                                      ; (faithful: ESI left at tile2)
.secondInPair:
    dec esi                                        ; hl→tile1
    mov al, [esi]                                  ; a = tile1 (hli)
    inc esi                                        ; hl→tile2
    cmp al, cl                                     ; compare tile1 vs front tile → sets ZF
    lea esi, [esi + 1]                             ; hl→next entry (flag-preserving inc)
    jne .loop
.foundMatch:
    stc
    ret
.noMatch:
    clc
    ret

; ---------------------------------------------------------------------------
; LoadCurrentMapView — faithful translation.
; Pret ref: home/overworld.asm:LoadCurrentMapView
;
; Reads SCREEN_BLOCK_HEIGHT×SCREEN_BLOCK_WIDTH blocks from wOverworldMap
; (starting at wCurrentTileBlockMapViewPointer) and expands each via
; DrawTileBlock into wSurroundingTiles (SURROUNDING_WIDTH×SURROUNDING_HEIGHT).
; Then adjusts for wYBlockCoord/wXBlockCoord and copies the 20×18 view to
; wTileMap.
;
; The bank-switch (BankswitchCommon) is a no-op in the flat model.
; ---------------------------------------------------------------------------
LoadCurrentMapView:
    push esi
    push edi
    push ebx
    push ecx

    ; ; TODO-HW: BankswitchCommon (flat model — no-op)

    ; DE = wCurrentTileBlockMapViewPointer (block map source ptr)
    movzx edx, word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]

    ; HL = ESI = wSurroundingTiles (tile write destination)
    mov esi, wSurroundingTiles

    ; B (BH) = SCREEN_BLOCK_HEIGHT outer loop count
    mov bh, SCREEN_BLOCK_HEIGHT

.row_loop:
    push esi                                       ; save row-start of wSurroundingTiles
    push edx                                       ; save row-start of block map

    mov cl, SCREEN_BLOCK_WIDTH                     ; CL = C = inner block count

.row_inner_loop:
    push ecx                                       ; push bc (saves CL=inner count)
    push edx                                       ; push de
    push esi                                       ; push hl

    ; STOPGAP (no GB equivalent — remove once map data is extended): the 40×25
    ; viewport is larger than the GB's 20×18, so a player-centered camera near a
    ; map edge reaches past wOverworldMap. wOverworldMap ($E580) sits directly
    ; above wSurroundingTiles ($E000) in WRAM, so reads above its top border land
    ; in the tile buffer and decode tile IDs as block IDs → a garbage band. Any
    ; read outside [wOverworldMap, wOverworldMapEnd) instead yields the map's
    ; border block, so the extended/out-of-map area renders as clean dummy tiles
    ; (matching the in-bounds border) rather than garbage. See CLAUDE.md and
    ; docs/current_plan_backlog.md:
    ; the real fix is to extend map data to fill the larger viewport.
    cmp edx, wOverworldMap
    jb  .oobBlock
    cmp edx, wOverworldMap + W_OVERWORLD_MAP_SIZE
    jae .oobBlock
    movzx eax, byte [ebp + edx]                   ; A = block ID from wOverworldMap
    jmp .haveBlock
.oobBlock:
    movzx eax, byte [ebp + wMapBackgroundTile] ; dummy = map border block
.haveBlock:
    mov bl, al                                     ; BL = block ID arg to DrawTileBlock (C)
    call DrawTileBlock                             ; writes 4×4 tiles to [EBP+ESI..]
                                                   ; ECX preserved by DrawTileBlock

    pop esi                                        ; pop hl (restore wSurroundingTiles ptr)
    pop edx                                        ; pop de (restore block map ptr)
    pop ecx                                        ; pop bc (restores CL=inner count)

    add esi, BLOCK_WIDTH                           ; HL += 4 (next block column in wSurroundingTiles)
    inc edx                                        ; DE++ (next block in block-map row)
    dec cl                                         ; dec C (inner count, not block ID)
    jnz .row_inner_loop

    ; Advance block-map pointer to next row
    pop edx                                        ; restore row-start of block map
    movzx eax, byte [ebp + wCurMapWidth]
    add al, MAP_BORDER * 2                         ; stride = width + 6
    add edx, eax                                   ; EDX += stride (next block-map row)

    ; Advance wSurroundingTiles pointer to next block row (4 tile rows down)
    pop esi                                        ; restore row-start of wSurroundingTiles
    add esi, SURROUNDING_WIDTH * BLOCK_HEIGHT      ; ESI += 96 (= 24 * 4)

    dec bh                                         ; dec B (outer row count)
    jnz .row_loop

    ; Copy the sub-block window of wSurroundingTiles into wTileMap (the collision
    ; grid). Factored out so AdvancePlayerSprite can refresh it every step.
    call RefreshCollisionTileMap

    ; ; TODO-HW: BankswitchCommon restore (flat model — no-op)

    pop ecx
    pop ebx
    pop edi
    pop esi
    ret

; ---------------------------------------------------------------------------
; AdvancePlayerSprite — home wrapper.
; pret: home/overworld.asm:AdvancePlayerSprite.
;
; Forces wUpdateSpritesEnabled = $FF for the duration of the sprite advance (so the
; OAM/sprite update runs while the player steps), then restores the prior value. This
; is pret's home-bank wrapper around _AdvancePlayerSprite; OW-A.3 de-folded it back out
; of the engine body it had been merged into (the save/restore was previously a
; documented Phase-2 omission). Register-safe.
; ---------------------------------------------------------------------------
AdvancePlayerSprite:
    push eax                                          ; keep caller EAX (wrapper clobbers AL)
    mov al, [ebp + wUpdateSpritesEnabled]          ; pret: ld a,[wUpdateSpritesEnabled] / push af
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF   ; pret: ld a,$FF / ld [wUpdateSpritesEnabled],a
    push eax
    call _AdvancePlayerSprite                         ; pret: callfar _AdvancePlayerSprite
    pop eax
    mov [ebp + wUpdateSpritesEnabled], al          ; pret: pop af / ld [wUpdateSpritesEnabled],a
    pop eax
    ret


; ═══════════════════════════════════════════════════════════════════════════
; THE VRAM-TORUS REDRAW RING — six faithful mirrors, deliberately UNREACHED.
;
; pret home/overworld.asm:1450-1538. These six stage one 2-tile-wide strip of the
; screen into wRedrawRowOrColumnSrcTiles and point hRedrawRowOrColumnDest at the
; place in the GB's 256x256 vBGMap0 tilemap torus where RedrawRowOrColumn should
; DMA it during the next VBlank. That is how the GB scrolls the overworld: the
; camera walks a sampling window over a wrapping 32x32 tilemap, and only the
; column or row entering view is rewritten.
;
; The port does not scroll that way. render_bg (src/ppu/ppu.asm) decodes
; wSurroundingTiles into a 48x36-tile surface through tile_cache and blits a
; 320x200 window out of it at a signed pixel offset, so the strip these would
; stage is already on screen the moment LoadCurrentMapView rebuilds it. Every
; pret CALL to them is therefore dropped, each drop annotated at its own site
; (_AdvancePlayerSprite, ShakeElevatorRedrawRow, RedrawMapView, VermilionDock).
;
; They are mirrored here anyway, per the maintainer's 2026-08-23 direction that
; genuinely portable pret routines are ported for completeness even when they
; stay unlinked. Uncalled code does not run, so this carries no runtime risk.
; Their consumer RedrawRowOrColumn (src/home/vcopy.asm) was already ported on the
; same basis and is what these are written to interoperate with.
;
; *** GEOMETRY: GB, NOT THE PORT CANVAS — and that is load-bearing. ***
; SCREEN_WIDTH/SCREEN_HEIGHT are 40/25 in this port (the extended viewport);
; on the GB they are 20/18. These routines are written against the GB values,
; hardcoded and named below, for two reasons:
;   1. Their OUTPUT contract is GB-shaped. wRedrawRowOrColumnSrcTiles is 40 bytes
;      (pret's `ds SCREEN_WIDTH * 2` at GB width), and RedrawRowOrColumn consumes
;      exactly 18 column entries or two 20-wide half-rows. Substituting the port's
;      25 into ScheduleColumnRedrawHelper would write 50 bytes into that 40-byte
;      buffer — a WRAM overrun, not a wider redraw.
;   2. Their DESTINATION is the GB tilemap torus ($9800, 32 wide, wrapping via
;      `and $03 / or $98`), which the port's canvas size does not change.
; src/home/vcopy.asm:RedrawRowOrColumn hardcodes the same GB values for the same
; reason; these match it deliberately.
;
; CONSEQUENCE FOR ANY FUTURE WIRING: reading a GB-geometry 20-wide row out of the
; port's 40-stride wTileMap does not address the cells a caller would mean. That
; is inherent to the mechanism, not a translation defect — the GB strip and the
; port canvas are different shapes. Wiring these up is therefore a geometry
; decision to be taken deliberately, not a matter of restoring the dropped calls.
; ═══════════════════════════════════════════════════════════════════════════

GB_SCREEN_WIDTH   equ 20      ; pret SCREEN_WIDTH  (this port's is 40)
GB_SCREEN_HEIGHT  equ 18      ; pret SCREEN_HEIGHT (this port's is 25)
HIGH_VBGMAP0      equ (vBGMap0 >> 8)   ; $98 — pret's literal `or $98`

; ---------------------------------------------------------------------------
; ScheduleNorthRowRedraw — pret home/overworld.asm:ScheduleNorthRowRedraw.
; Stages screen row 0 (2 rows) and aims it at the current map-view VRAM pointer.
; ---------------------------------------------------------------------------
ScheduleNorthRowRedraw:
    mov esi, wTileMap                            ; hlcoord 0, 0
    call CopyToRedrawRowOrColumnSrcTiles
    mov al, [ebp + wMapViewVRAMPointer]          ; ld a, [wMapViewVRAMPointer]
    mov [ebp + hRedrawRowOrColumnDest], al
    mov al, [ebp + wMapViewVRAMPointer + 1]      ; ld a, [wMapViewVRAMPointer + 1]
    mov [ebp + hRedrawRowOrColumnDest + 1], al
    mov al, REDRAW_ROW                            ; ld a, REDRAW_ROW
    mov [ebp + hRedrawRowOrColumnMode], al       ; ldh [hRedrawRowOrColumnMode], a
    ret

; ---------------------------------------------------------------------------
; CopyToRedrawRowOrColumnSrcTiles — pret home/overworld.asm:1461.
; Copies 2 * SCREEN_WIDTH contiguous tiles from [HL] into the staging buffer.
;
; In: ESI = source (HL). Out: ESI advanced by 40. Clobbers AL, BL(c), EDX(de).
; ---------------------------------------------------------------------------
CopyToRedrawRowOrColumnSrcTiles:
    mov edx, wRedrawRowOrColumnSrcTiles          ; ld de, wRedrawRowOrColumnSrcTiles
    mov bl, 2 * GB_SCREEN_WIDTH                  ; ld c, 2 * SCREEN_WIDTH (= 40)
.loop:
    mov al, [ebp + esi]                          ; ld a, [hli]
    inc esi
    mov [ebp + edx], al                          ; ld [de], a
    inc edx                                      ; inc de
    dec bl                                       ; dec c — 8-bit, as on the GB
    jnz .loop                                    ; jr nz, .loop
    ret

; ---------------------------------------------------------------------------
; ScheduleSouthRowRedraw — pret home/overworld.asm:ScheduleSouthRowRedraw.
; Stages screen rows 16-17 and aims them $200 bytes past the map-view pointer,
; wrapped back inside the 1 KiB tilemap by pret's `and $03 / or $98`.
; ---------------------------------------------------------------------------
ScheduleSouthRowRedraw:
    mov esi, wTileMap + 16 * GB_SCREEN_WIDTH     ; hlcoord 0, 16
    call CopyToRedrawRowOrColumnSrcTiles
    ; pret: ld l,[wMapViewVRAMPointer] / ld h,[+1] — the pointer is stored low
    ; byte first, so the pair is one 16-bit load into HL (= ESI).
    movzx esi, word [ebp + wMapViewVRAMPointer]
    add si, 0x200                                ; ld bc, $200 / add hl, bc (wraps at 16 bits)
    mov ax, si                                   ; AH = h, AL = l
    and ah, 0x03                                 ; ld a,h / and $03 — stay inside TILEMAP_AREA
    or  ah, HIGH_VBGMAP0                         ; or $98 — HIGH(vBGMap0)
    mov [ebp + hRedrawRowOrColumnDest + 1], ah
    mov [ebp + hRedrawRowOrColumnDest], al       ; ld a, l
    mov al, REDRAW_ROW                            ; ld a, REDRAW_ROW
    mov [ebp + hRedrawRowOrColumnMode], al       ; ldh [hRedrawRowOrColumnMode], a
    ret

; ---------------------------------------------------------------------------
; ScheduleEastColumnRedraw — pret home/overworld.asm:ScheduleEastColumnRedraw.
; Stages screen columns 18-19 and aims them 18 tiles right of the map-view
; pointer, wrapped inside the tilemap ROW by pret's `and $e0` / `and $1f` split.
; ---------------------------------------------------------------------------
ScheduleEastColumnRedraw:
    mov esi, wTileMap + 18                       ; hlcoord 18, 0
    call ScheduleColumnRedrawHelper
    mov al, [ebp + wMapViewVRAMPointer]          ; ld a, [wMapViewVRAMPointer]
    mov bl, al                                   ; ld c, a
    and al, 0xE0                                 ; and $e0 — keep the row bits
    mov bh, al                                   ; ld b, a
    mov al, bl                                   ; ld a, c
    add al, 18                                   ; add 18
    and al, 0x1F                                 ; and $1f — wrap within the row
    or  al, bh                                   ; or b
    mov [ebp + hRedrawRowOrColumnDest], al
    mov al, [ebp + wMapViewVRAMPointer + 1]
    mov [ebp + hRedrawRowOrColumnDest + 1], al
    mov al, REDRAW_COL                            ; ld a, REDRAW_COL
    mov [ebp + hRedrawRowOrColumnMode], al       ; ldh [hRedrawRowOrColumnMode], a
    ret

; ---------------------------------------------------------------------------
; ScheduleColumnRedrawHelper — pret home/overworld.asm:1509.
; Gathers a 2-wide, SCREEN_HEIGHT-tall column out of [HL] into the staging
; buffer, stepping one screen row per iteration.
;
; In: ESI = source (HL). Clobbers AL, BL(c), EDX(de), ESI.
; ---------------------------------------------------------------------------
ScheduleColumnRedrawHelper:
    mov edx, wRedrawRowOrColumnSrcTiles          ; ld de, wRedrawRowOrColumnSrcTiles
    mov bl, GB_SCREEN_HEIGHT                     ; ld c, SCREEN_HEIGHT (= 18)
.loop:
    mov al, [ebp + esi]                          ; ld a, [hli]
    inc esi
    mov [ebp + edx], al                          ; ld [de], a
    inc edx
    mov al, [ebp + esi]                          ; ld a, [hl]
    mov [ebp + edx], al                          ; ld [de], a
    inc edx
    ; pret: ld a, SCREEN_WIDTH - 1 / add l / ld l, a / jr nc / inc h — a 16-bit
    ; add done as low byte plus explicit carry, i.e. hl += 19. Combined with the
    ; single `hli` above, the net step is one full screen row.
    add esi, GB_SCREEN_WIDTH - 1
    dec bl                                       ; dec c — 8-bit, as on the GB
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; ScheduleWestColumnRedraw — pret home/overworld.asm:ScheduleWestColumnRedraw.
; Stages screen columns 0-1 straight at the map-view pointer.
; ---------------------------------------------------------------------------
ScheduleWestColumnRedraw:
    mov esi, wTileMap                            ; hlcoord 0, 0
    call ScheduleColumnRedrawHelper
    mov al, [ebp + wMapViewVRAMPointer]
    mov [ebp + hRedrawRowOrColumnDest], al
    mov al, [ebp + wMapViewVRAMPointer + 1]
    mov [ebp + hRedrawRowOrColumnDest + 1], al
    mov al, REDRAW_COL                            ; ld a, REDRAW_COL
    mov [ebp + hRedrawRowOrColumnMode], al       ; ldh [hRedrawRowOrColumnMode], a
    ret

; ---------------------------------------------------------------------------
; DrawTileBlock — faithful translation.
; Pret ref: home/overworld.asm:DrawTileBlock
;
; Expands one 4×4 map block into tile IDs in wSurroundingTiles.
;
; In:  ESI = write ptr in wSurroundingTiles (HL)
;      BL  = block ID (C)
; Out: ESI advanced by 4*SURROUNDING_WIDTH (past all 4 tile rows of this block)
;      BL unchanged (saved/restored by caller via push/pop ecx before call)
; Clobbers: AL, ECX (internal row counter), EDX (tile data source ptr)
; ---------------------------------------------------------------------------
DrawTileBlock:
    push ecx
    push edx

    ; Compute tile data source: [EBP + wTilesetBlocksPtr + blockID*16]
    movzx edx, word [ebp + wTilesetBlocksPtr]  ; EDX = OW_BLOCKS_GBADDR (DE in SM83)
    movzx eax, bl                                  ; EAX = blockID (C in SM83)
    shl eax, 4                                     ; EAX = blockID * 16
    add edx, eax                                   ; EDX = pointer into blockset

    ; TEMPORARY (no GB equivalent — remove once map data is extended): clamp
    ; out-of-range block IDs to block 0 (the black/border tile). The extended
    ; 40×25-tile draw can pull the camera viewport into uninitialized
    ; wOverworldMap padding, handing us a block ID past the embedded blockset;
    ; without this the tile read walks off the blockset and paints garbage. This
    ; is a stopgap: the plan is to extend the map data so those regions hold real
    ; blocks (no blank area exists), at which point this clamp is dead code and
    ; should be deleted. See docs/current_plan_backlog.md and CLAUDE.md.
    cmp edx, OW_BLOCKS_GBADDR + OVERWORLD_BLOCKS_SIZE
    jb  .block_in_range
    mov edx, OW_BLOCKS_GBADDR
.block_in_range:

    mov cl, BLOCK_HEIGHT                           ; CL = 4 (row count)

.draw_row:
    push ecx
    ; Tiles 0–2: write to [ESI] with post-increment
    mov al, byte [ebp + edx]
    mov byte [ebp + esi], al
    inc esi
    inc edx
    mov al, byte [ebp + edx]
    mov byte [ebp + esi], al
    inc esi
    inc edx
    mov al, byte [ebp + edx]
    mov byte [ebp + esi], al
    inc esi
    inc edx
    ; Tile 3: write to [ESI] without incrementing ESI (SM83: ld [hl], a)
    mov al, byte [ebp + edx]
    mov byte [ebp + esi], al
    inc edx
    ; Advance ESI to start of next tile row: +45 = SURROUNDING_WIDTH - (BLOCK_WIDTH-1)
    add esi, SURROUNDING_WIDTH - BLOCK_WIDTH + 1   ; = 48 - 4 + 1 = 45
    pop ecx
    dec cl
    jnz .draw_row

    pop edx
    pop ecx
    ret

; ---------------------------------------------------------------------------
; ForceBikeDown — on Cycling Road, simulate a DOWN press when the player is not
; pressing anything and no trainer battle is flagged. This is what makes ROUTE_17
; auto-scroll south.
;
; DESPITE THE NAME, NO BIKE IS REQUIRED. The routine tests only wStatusFlags7,
; wCurMap and hJoyHeld — it never reads wWalkBikeSurfState. The bike-gated
; Cycling Road path is a DIFFERENT routine (pret home/overworld.asm ~line 350,
; the bike-speed extra-step, guarded by wWalkBikeSurfState == 1). Grepping
; ROUTE_17 in pret finds both; this is the one called from JoypadOverworld.
;
; pret: home/overworld.asm:ForceBikeDown
; In:  wStatusFlags7, wCurMap, hJoyHeld
; Out: hJoyHeld = PAD_DOWN when all three guards pass; otherwise untouched
; Clobbers: AL, flags
; ---------------------------------------------------------------------------
; JoypadOverworld — pret home/overworld.asm:JoypadOverworld (:1579-1587).
;
;     xor a
;     ld [wSpritePlayerStateData1YStepVector], a
;     ld [wSpritePlayerStateData1XStepVector], a
;     call RunMapScript
;     call Joypad
;     call ForceBikeDown
;     call AreInputsSimulated
;     ret
;
; "function to update joypad state and simulate button presses."
;
; RESTORED 2026-08-22. Every one of these statements already existed in the port,
; but scattered across OverworldLoop / OverworldLoopLessDelay at three different
; seams, so the pret label read `missing` and — more than a bookkeeping problem —
; RunMapScript ran on EVERY loop iteration rather than only when wWalkCounter is
; 0, and ForceBikeDown / AreInputsSimulated ran AFTER the Safari, script-warp and
; fly-warp tests instead of before them.
;
; DEVIATION{class=HAL; pret=home/overworld.asm:JoypadOverworld; behavior=pret's `call Joypad` is dropped; evidence=the port `Joypad` recomputes the edge layer from hJoyInput which only ReadJoypad_ writes and which nothing in the frame loop calls, while joypad_update runs that same pret _Joypad edge layer once per DelayFrame from the live pad state - calling it here would zero hJoyHeld and hJoyPressed for the rest of the iteration - and this is the established treatment of `call Joypad` across the port, see JoypadLowSensitivity in src/home/joypad2.asm; lifetime=permanent while input is polled from the PIT and keyboard ISR rather than a joypad register}
; ---------------------------------------------------------------------------
global JoypadOverworld
JoypadOverworld:
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0  ; wSpritePlayerStateData1YStepVector
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0  ; wSpritePlayerStateData1XStepVector
    call RunMapScript                                  ; pret: call RunMapScript (runs only when wWalkCounter == 0)
    ; call Joypad — dropped (port reads joypad in main loop)
    ; Order matters: ForceBikeDown must not clobber a simulated step, and pret
    ; guarantees that by running it first.
    call ForceBikeDown
    call AreInputsSimulated
    ret

; ---------------------------------------------------------------------------
ForceBikeDown:
    test byte [ebp + wStatusFlags7], (1 << BIT_TRAINER_BATTLE)
    jnz .ret                                  ; ld a,[wStatusFlags7] / bit BIT_TRAINER_BATTLE,a / ret nz
    cmp byte [ebp + wCurMap], ROUTE_17        ; ld a,[wCurMap] / cp ROUTE_17
    jne .ret                                  ; ret nz
    ; pret: ldh a,[hJoyHeld] / and PAD_CTRL_PAD | PAD_B | PAD_A / ret nz
    ; Any D-pad direction or A/B held means the player is steering — leave input
    ; alone. SELECT and START are deliberately NOT in the mask, so they do not
    ; suppress the auto-scroll; that is pret's behaviour, not an oversight.
    test byte [ebp + hJoyHeld], (PAD_CTRL_PAD | PAD_B | PAD_A)
    jnz .ret
    mov byte [ebp + hJoyHeld], PAD_DOWN     ; ld a,PAD_DOWN / ldh [hJoyHeld],a
.ret:
    ret

; ---------------------------------------------------------------------------
; AreInputsSimulated — if scripted movement is active, overwrite hJoyHeld with the
; next simulated button state; otherwise leave the real joypad state untouched.
; When the simulated buffer drains, tear down all scripted-movement state.
;
; pret: home/overworld.asm:AreInputsSimulated
; In:  (BIT_SCRIPTED_MOVEMENT_STATE of wStatusFlags5), hJoyHeld, override mask
; Out: hJoyHeld (and hJoyPressed/hJoyReleased on the zero-input edge) possibly rewritten
; Clobbers: AL, BL, ESI, flags
; ---------------------------------------------------------------------------
AreInputsSimulated:
    test byte [ebp + wStatusFlags5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jz .ret                                   ; pret: bit .../ ret z — not simulating

    ; if simulating: real presses in the override mask cancel the simulation this frame
    mov bl, [ebp + hJoyHeld]                ; b = hJoyHeld
    mov al, [ebp + wOverrideSimulatedJoypadStatesMask]
    and al, bl
    jnz .ret                                  ; overridden -> keep real input

    call GetSimulatedInput                    ; CF=1 -> AL = next simulated state
    jnc .doneSimulating                       ; CF=0 -> buffer drained

    mov [ebp + hJoyHeld], al                ; inject simulated press
    test al, al
    jnz .ret                                  ; nonzero press: leave pressed/released alone
    ; a == 0 (a queued "no buttons" frame): also clear pressed/released
    mov byte [ebp + hJoyPressed], 0
    mov byte [ebp + hJoyReleased], 0
.ret:
    ret

; if done simulating button presses (pret: .doneSimulating)
.doneSimulating:
    mov byte [ebp + wUnusedOverrideSimulatedJoypadStatesIndex], 0
    mov byte [ebp + wSimulatedJoypadStatesIndex], 0
    mov byte [ebp + wSimulatedJoypadStatesEnd], 0
    mov byte [ebp + wJoyIgnore], 0
    mov byte [ebp + hJoyHeld], 0
    ; preserve only movement-flag bits 7,6,5,4,3 (SPINNING|LEDGE_OR_FISHING|5|4|3),
    ; clearing STANDING_ON_DOOR|EXITING_DOOR|STANDING_ON_WARP (bits 2,1,0). pret mask 0xF8.
    and byte [ebp + wMovementFlags], (1 << BIT_SPINNING) | (1 << BIT_LEDGE_OR_FISHING) | (1 << 5) | (1 << 4) | (1 << 3)
    and byte [ebp + wStatusFlags5], ~(1 << BIT_SCRIPTED_MOVEMENT_STATE)
    ret
GetSimulatedInput:
    dec byte [ebp + wSimulatedJoypadStatesIndex]
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    cmp al, 0xFF                              ; wrapped past 0 -> end of simulated input
    je .endofsimulatedinputs
    movzx esi, al                             ; e = index (d = 0)
    add esi, wSimulatedJoypadStatesEnd
    mov al, [ebp + esi]                       ; a = [wSimulatedJoypadStatesEnd + index]
    stc
    ret
.endofsimulatedinputs:
    xor al, al                               ; pret: and a — AL=0, CF=0
    ret

; ---------------------------------------------------------------------------
; CollisionCheckOnWater — collision check while surfing (OW-A.6).
; Pret ref: home/overworld.asm:1665 CollisionCheckOnWater.
;
; CF=1 → blocked on water; CF=0 → move allowed. The "passable land tile ahead"
; case disembarks (.stopSurfing): clears wWalkBikeSurfState, reloads the walking
; sprite, restores the map music, and returns CF=0 so the step onto land runs.
; Reachable in today's live build: ItemUseSurfboard sets wWalkBikeSurfState = 2
; at src/engine/items/item_effects.asm:644, wired live through UseItem's
; ItemUsePtrTable dispatch, called from the Start-menu SURF handler at
; src/engine/menus/start_sub_menus.asm:465.
;
; PORT (established divergence, same as CollisionCheckOnLand): pret's
; `predef GetTileAndCoordsInFrontOfPlayer` is realized as LoadCurrentMapView +
; a direct call to the non-predef entry _GetTileAndCoordsInFrontOfPlayer (the
; predef wrapper would clobber ESI/EBX via GetPredefRegisters).
; Register safety mirrors CollisionCheckOnLand: EAX/ECX/ESI saved; DL is
; (re)written with wPlayerDirection, the same value callers already hold.
; ---------------------------------------------------------------------------
CollisionCheckOnWater:
    push eax
    push ecx
    push esi
    ; pret: bit BIT_SCRIPTED_MOVEMENT_STATE → never collide under simulated input
    test byte [ebp + wStatusFlags5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jnz .noCollision
    ; pret :1669-1672 — quick sprite reject in the travel direction (same
    ; collision-direction bit layout as CollisionCheckOnLand's reject).
    mov dl, [ebp + wPlayerDirection]
    mov al, [ebp + wSpriteStateData1 + SPRITESTATEDATA1_COLLISIONDATA]
    and al, dl
    jnz .collision
    ; regression-overworld-watercollision-stale-tile: the port's
    ; CheckForJumpingAndTilePairCollisions requires wTileInFrontOfPlayer
    ; preset by the caller -- unlike pret, which re-derives the front tile
    ; itself via an internal `predef GetTileAndCoordsInFrontOfPlayer` (root
    ; home/overworld.asm:1284), so pret's own call ordering (tile-pair check
    ; first, tile fetch after) doesn't matter there. The port deleted that
    ; internal re-derivation, so the fetch must run BEFORE the tile-pair call
    ; here too, matching CollisionCheckOnLand -- rebuild the viewport (stale
    ; within a block) and read the front tile first.
    call LoadCurrentMapView
    ; Non-predef entry on purpose (predef wrapper would clobber ESI/EBX via
    ; GetPredefRegisters).
    call _GetTileAndCoordsInFrontOfPlayer          ; CL = tile → wTileInFrontOfPlayer
    ; pret :1673-1675 — water-seam tile pairs block (and may arm a ledge state);
    ; same save set as CollisionCheckOnLand's land hook.
    push ebx
    push edx
    mov esi, TilePairCollisionsWater               ; flat host ptr (src/data/tilesets/pair_collision_tile_ids.asm)
    call CheckForJumpingAndTilePairCollisions
    pop edx
    pop ebx
    jc .collision
    ; pret :1676 predef GetTileAndCoordsInFrontOfPlayer — pret's own SECOND,
    ; explicit call (the first ran inside CheckForJumpingAndTilePairCollisions
    ; above). Not redundant: CheckForJumpingAndTilePairCollisions clobbers CL
    ; (documented in its header), and IsNextTileShoreOrWater below needs a
    ; freshly derived wTileInFrontOfPlayer. EDX is dead from here to the
    ; end of the routine, so the faithful routine's DH/DL front-coord writes
    ; are harmless -- and match pret, whose predef call clobbers DE here too.
    call _GetTileAndCoordsInFrontOfPlayer          ; CL = tile → wTileInFrontOfPlayer
    call IsNextTileShoreOrWater                    ; CF=1 → shore/water ahead
    jc .noCollision                                ; keep surfing
    movzx ecx, byte [ebp + wTileInFrontOfPlayer] ; ld a,[wTileInFrontOfPlayer] / ld c,a
    call IsTilePassable                            ; CF=1 → not passable
    jnc .stopSurfing                               ; passable land ahead → disembark
.collision:
    ; pret :1685-1690 — bump SFX unless already playing on CHAN5.
    mov al, [ebp + wChannelSoundIDs + CHAN5]
    cmp al, SFX_COLLISION
    je .setCarry
    mov al, SFX_COLLISION
    call PlaySound
.setCarry:
    pop esi
    pop ecx
    pop eax
    stc
    ret
.checkIfVermilionDockTileset:
    ; UNREFERENCED in pret Yellow (no jump targets this label — Red-era remnant
    ; kept for label fidelity, like Func_5288 set 3).
    mov al, [ebp + wCurMapTileset]
    cmp al, SHIP_PORT                              ; Vermilion Dock tileset?
    jne .noCollision                               ; keep surfing if not
    jmp .stopSurfing
.stopSurfing:
    ; pret :1699-1708 ("based game freak") — disembark onto the passable tile.
    mov byte [ebp + wPikachuSpawnState], 3
    or byte [ebp + wPikachuOverworldStateFlags], (1 << 5) ; set 5, [hl] (hide)
    mov byte [ebp + wWalkBikeSurfState], 0
    call LoadPlayerSpriteGraphics
    call PlayDefaultMusic
    ; fall through — pret: jr .noCollision
.noCollision:
    pop esi
    pop ecx
    pop eax
    clc                                            ; and a — CF=0
    ret

RunMapScript:
    ; pret: push hl / push de / push bc around the boulder step, restored before
    ; RunNPCMovementScript. TryPushingBoulder and the dust animation clobber freely.
    push esi
    push edx
    push ebx
    call TryPushingBoulder                   ; pret: farcall (banking elided)
    mov al, [ebp + wMiscFlags]
    test al, (1 << BIT_BOULDER_DUST)
    jz .afterBoulderEffect                   ; jr z — no push happened this frame
    call DoBoulderDustAnimation              ; pret: farcall (banking elided)
.afterBoulderEffect:
    pop ebx
    pop edx
    pop esi
    call RunNPCMovementScript                ; pret home/overworld.asm:1725
    ; TODO-HW: SwitchToMapRomBank — no-op under the flat address model.
    movzx ecx, byte [ebp + wCurMap]
    call dword [MapScriptPointers + ecx*4]   ; run this map's _Script (flat ptr)
    ret
LoadWalkingPlayerSpriteGraphics:
    mov byte [ebp + W_D472], 0
    mov esi, player_sprite                  ; RedSprite (walking) — DE in pret
    jmp LoadPlayerSpriteGraphicsCommon
LoadSurfingPlayerSpriteGraphics2:
    mov al, [ebp + W_D472]
    test al, al
    jz .checkPikachu                        ; d472 == 0
    dec al
    jz LoadSurfingPlayerSpriteGraphics      ; d472 == 1
    dec al
    jz .surfPikachu                         ; d472 == 2
.checkPikachu:
    test byte [ebp + W_PIKACHU_SPAWN_STATE_FLAGS], (1 << BIT_PIKACHU_SPAWN_SURFING)
    jz LoadSurfingPlayerSpriteGraphics
.surfPikachu:
    mov esi, SurfingPikachuSprite
    jmp LoadPlayerSpriteGraphicsCommon
LoadSurfingPlayerSpriteGraphics:
    mov esi, SeelSprite
    jmp LoadPlayerSpriteGraphicsCommon
LoadBikePlayerSpriteGraphics:
    mov esi, RedBikeSprite
LoadPlayerSpriteGraphicsCommon:
    mov byte [g_tilecache_dirty], 1         ; VRAM tile data changes → re-decode cache

    ; standing tiles (0-11) → OBJ $00-$0B at $8000 (vNPCSprites)
    lea edi, [ebp + GB_VCHARS0]
    mov ecx, PLAYER_HALF_BYTES
    rep movsb

    ; walking tiles (12-23) → OBJ $80-$8B at $8800 (vChars1; shares vFont)
    ; ESI is already at source+$C0 after the first copy (pret: add e,$C0).
    lea edi, [ebp + GB_VFONT]
    mov ecx, PLAYER_HALF_BYTES
    rep movsb
    ret

; (IsTilePassable moved to its pret mirror home/copy2.asm as the trampoline to
;  _IsTilePassable, whose body now lives at ITS pret mirror
;  engine/gfx/sprite_oam.asm — relocated-labels grind, 2026-07-24.)

; ---------------------------------------------------------------------------
; LoadMapHeader — faithful translation.
; Pret ref: home/overworld.asm:LoadMapHeader
; ---------------------------------------------------------------------------
LoadMapHeader:
    push eax
    push ebx
    push ecx
    push esi
    push edi

    ; pret: farcall MarkTownVisitedAndLoadToggleableObjects / jr asm_0dbd.
    ; RESTORED 2026-08-22. The comment that stood here claimed the routine was "not
    ; ported — the town-map visited-flag set and the hidden/toggleable object show-flag
    ; load aren't implemented yet"; that was measurably false (label_status reports it
    ; translated in src/engine/overworld/toggleable_objects.asm), so LoadMapHeader was
    ; silently skipping the wTownVisitedFlag set on every map load.
    call MarkTownVisitedAndLoadToggleableObjects
    jmp asm_0dbd                            ; pret: jr asm_0dbd

; ---------------------------------------------------------------------------
; Func_0db5 — pret home/overworld.asm:1797, marked `; unreferenced` there and
; unreferenced here too. It is LoadMapHeader's alternate head: instead of
; MarkTownVisitedAndLoadToggleableObjects it runs LoadToggleableObjectData (pret's
; own unused loader, engine/overworld/unused_load_toggleable_object_data.asm),
; then joins the shared body at asm_0dbd.
;
; The port cannot simply fall through into LoadMapHeader's asm_0dbd the way pret
; does, because the port's LoadMapHeader opens with a five-register save that pret
; has no counterpart for; entering below it would leave the epilogue popping a
; frame that was never pushed. So the prologue is repeated here and the entry
; joins at exactly pret's join point.
; ---------------------------------------------------------------------------
global Func_0db5
Func_0db5:
    push eax
    push ebx
    push ecx
    push esi
    push edi
    call LoadToggleableObjectData           ; pret: farcall LoadToggleableObjectData
    ; falls through — pret has no jump either
global asm_0dbd
asm_0dbd:
    ; pret :1800-1801 — `ld a,[wCurMapTileset] / ld [wUnusedCurMapTilesetCopy], a`,
    ; the first two instructions of the shared body. Restored 2026-08-22 with the
    ; label: the port wrote wUnusedCurMapTilesetCopy only from ResetMapVariables
    ; (which zeroes it), so the copy never held a tileset. Nothing reads it on
    ; either side — pret's own name says so — but it is two instructions and its
    ; absence was invisible only because the whole body sat under LoadMapHeader's
    ; label, where faithdiff had a 3-line pret routine to compare against.
    mov al, [ebp + wCurMapTileset]
    mov [ebp + wUnusedCurMapTilesetCopy], al
    ; pret: ld a,[wCurMapTileset] / ld b,a / res BIT_NO_PREVIOUS_MAP,a /
    ;       ld [wCurMapTileset],a / ldh [hPreviousTileset],a.
    ; Snapshot the previous map's tileset into hPreviousTileset BEFORE the header copy
    ; below overwrites wCurMapTileset (= wCurMapHeader first byte, 0xD366) with the new
    ; map's tileset. LoadTilesetHeader (tail of this routine) compares the two to decide
    ; whether to run the warp-arrival block-coord alignment: without this snapshot its
    ; "tileset unchanged" gate reads a stale value and the alignment fires on every load,
    ; shifting the sub-block viewport.
    ; BIT_NO_PREVIOUS_MAP (bit 7) is set by the save-load path (save.asm) to mean "this
    ; map is already loaded". pret res's it here and snapshots the CLEARED value; the
    ; res is zero-behavior on the current paths (the header copy below already overwrites
    ; wCurMapTileset), but keeping it faithful avoids a stale bit-7 leaking into
    ; hPreviousTileset. The 0xFF8B HRAM byte is a union with hMapStride/
    ; hNSConnectionStripWidth, written only later during LoadCurrentMapView / connection-
    ; strip drawing — never between here and the LoadTilesetHeader read — so it is safe.
    mov al, [ebp + wCurMapTileset]
    mov bl, al                              ; b = full tileset (incl. BIT_NO_PREVIOUS_MAP)
    and al, ~(1 << BIT_NO_PREVIOUS_MAP)     ; res BIT_NO_PREVIOUS_MAP
    mov [ebp + wCurMapTileset], al
    mov [ebp + hPreviousTileset], al
    ; pret: bit BIT_NO_PREVIOUS_MAP,b / ret nz — if the map is already loaded (bit was
    ; set), skip the whole header reload.
    ; TODO(OW-A.5/verify): the early return is DEFERRED. All 3 FRAME.BIN baselines exercise
    ; this routine with the bit CLEAR, so they cannot prove the bit-set path; that path is
    ; only reached after a continue-from-save, and skipping the header reload there would
    ; break the map if the port's .dsv restore does not repopulate wCurMapHeader (it does
    ; not today). Restore the `ret nz` once the save/continue flow can be driven live
    ; (MCP) and verified — same conservatism as OW-A.4(b). Faithful code:
    ;     test bl, (1 << BIT_NO_PREVIOUS_MAP)
    ;     jnz .noPreviousMapReturn   ; pop edi/esi/ecx/ebx/eax ; ret

    ; wCurMapHeader is a 10-byte buffer: tileset(1), h(1), w(1), blkptr(2), txtptr(2), scrptr(2), conn(1)
    ; pret :1811 — `call GetMapHeaderPointer`. The table lookup was inlined here
    ; until 2026-08-22, which left the pret label reading `missing`; it is now the
    ; routine below and this is its only caller, as in pret.
    call GetMapHeaderPointer                ; ESI = flat address of wCurMap's header

    ; Copy 10 bytes to wCurMapHeader
    lea edi, [ebp + wCurMapHeader]
    mov ecx, W_CUR_MAP_HEADER_SIZE
    rep movsb
    
    ; Initialize all 4 connected maps to $FF (disabled) before loading actual values.
    ; Faithful to pret: home/overworld.asm line 1820-1825.
    ; Without this, stale connection data from the previous map persists.
    mov byte [ebp + wNorthConnectedMap], MAP_NO_CONNECTION
    mov byte [ebp + W_SOUTH_CONNECTED_MAP], MAP_NO_CONNECTION
    mov byte [ebp + W_WEST_CONNECTED_MAP],  MAP_NO_CONNECTION
    mov byte [ebp + W_EAST_CONNECTED_MAP],  MAP_NO_CONNECTION
    
    ; ESI now points past the 10-byte header. Check connections bitmask.
    mov al, [ebp + wCurMapConnections]
    test al, CONNECTION_NORTH
    jz .noNorth
    mov edi, wNorthConnectedMap
    call CopyMapConnectionHeader
.noNorth:
    mov al, [ebp + wCurMapConnections]
    test al, CONNECTION_SOUTH
    jz .noSouth
    mov edi, W_SOUTH_CONNECTED_MAP
    call CopyMapConnectionHeader
.noSouth:
    mov al, [ebp + wCurMapConnections]
    test al, CONNECTION_WEST
    jz .noWest
    mov edi, W_WEST_CONNECTED_MAP
    call CopyMapConnectionHeader
.noWest:
    mov al, [ebp + wCurMapConnections]
    test al, CONNECTION_EAST
    jz .noEast
    mov edi, W_EAST_CONNECTED_MAP
    call CopyMapConnectionHeader
.noEast:

    ; ESI now points to object_data_ptr
    movzx eax, word [esi]
    add eax, ebp ; EAX = object data flat address
    
    ; Read border block
    mov bl, [eax]
    mov [ebp + wMapBackgroundTile], bl
    inc eax
    
    ; Copy warps to wWarpEntries
    mov bl, [eax]
    mov [ebp + wNumberOfWarps], bl
    inc eax
    movzx ecx, bl
    shl ecx, 2                          ; * 4 bytes per warp entry
    mov esi, eax
    lea edi, [ebp + wWarpEntries]
    rep movsb                           ; copy all warp entries to WRAM
    mov eax, esi                        ; advance EAX past copied warp bytes
    
    ; Signs: store the count, then copy the sign block into WRAM.
    ; Pret ref: home/overworld.asm:LoadMapHeader (.loadSignData) + CopySignData.
    ; Per sign (3 bytes): Y, X, textID.  Y/X -> wSignCoords (interleaved pairs),
    ; textID -> wSignTextIDs.  When wNumSigns == 0 the copy is skipped and the
    ; cursor advance adds 0, so a sign-less map is byte-identical to before.
    mov bl, [eax]
    mov [ebp + wNumSigns], bl
    inc eax                             ; EAX -> first sign entry (flat address)
    test bl, bl
    jz .noSigns
    mov esi, eax                        ; ESI = flat src of the sign block
    call CopySignData                   ; copies wNumSigns*3 bytes; preserves EAX
.noSigns:
    movzx ebx, byte [ebp + wNumSigns]
    lea ebx, [ebx + ebx * 2]           ; * 3 bytes per sign
    add eax, ebx                        ; advance cursor past the sign block
    
    ; Save object data pointer temp
    sub eax, ebp
    mov [ebp + W_OBJECT_DATA_PTR_TEMP], ax

    ; pret home/overworld.asm:1888-1892 (.loadSpriteData): populate the NPC sprite
    ; slots from the map-object binary, UNLESS returning from a battle/blackout
    ; (that data survives a battle, so it isn't rebuilt). W_OBJECT_DATA_PTR_TEMP
    ; (just set above) points at the sprite_count byte = pret's HL on InitSprites entry.
    ; OW-A.2 P3b: this is the faithful home object-loader; the bespoke InitMapSprites
    ; (still the driver until P3c) clears+repopulates the same slots afterward in
    ; LoadMapData, so this is currently redundant-but-harmless (byte-identical).
    mov al, [ebp + wStatusFlags4]
    test al, (1 << BIT_BATTLE_OVER_OR_BLACKOUT)
    jnz .skipInitSprites
    call InitSprites
.skipInitSprites:

    call LoadTilesetHeader

    mov al, [ebp + wStatusFlags4]
    test al, (1 << BIT_BATTLE_OVER_OR_BLACKOUT)
    jnz .skipPikachuSpawn
    call SchedulePikachuSpawnForAfterText
.skipPikachuSpawn:

    ; Load this map's wild-encounter data (pret home/overworld.asm:LoadMapHeader:1900,
    ; callfar LoadWildData). Populates wGrassRate/wGrassMons + wWaterRate/wWaterMons from
    ; WildDataPointers[wCurMap] for TryDoWildEncounter. OW-A.5: previously LoadWildData had
    ; ZERO call sites, so every map's wild slots were stale. LoadWildData clobbers only
    ; EAX/ECX/EDX/ESI (no banking, no I/O), all of which the pops below restore, so it is
    ; safe here.
    call LoadWildData

    ; pret next doubles wCurMapHeight/Width -> wCurrentMapHeight2/Width2 (:1902-1907).
    ; DIVERGENCE (verified safe): the port derives those in CheckMapConnections (its ONLY
    ; consumer), at the top of that routine (set-before-use) — every read of
    ; wCurrentMapHeight2/WIDTH_2 is inside CheckMapConnections, after the set — so
    ; LoadMapHeader does not need to compute them here.
    ; pret LoadMapHeader:1908-1923: load this map's default music (id, ROM bank) from
    ; MapSongBanks[wCurMap] into wMapMusicSoundID/wMapMusicROMBank. PlayDefaultMusic (the
    ; LoadMapData tail + connection crossing) plays it. Real now (OW-A.14); the pops below
    ; restore eax/esi. Flat model: MapSongBanks is a host-address label, stride 2.
    movzx eax, byte [ebp + wCurMap]
    lea esi, [MapSongBanks + eax*2]
    mov al, [esi]
    mov [ebp + wMapMusicSoundID], al            ; music 1
    mov al, [esi + 1]
    mov [ebp + wMapMusicROMBank], al            ; music 2

    pop edi
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret

CopyMapConnectionHeader:
    push ecx
    push edi
    add edi, ebp
    mov ecx, CONN_HEADER_SIZE
    rep movsb
    pop edi
    pop ecx
    ret

; ---------------------------------------------------------------------------
; CopySignData — copy the map header's sign block into WRAM.
; Pret ref: home/overworld.asm:CopySignData
;
; In:  ESI = flat (ebp-relative absolute) pointer to the sign block; each sign is
;            3 bytes: Y, X, textID.
;      [wNumSigns] = number of signs (caller guarantees >= 1).
; Out: wSignCoords   <- interleaved (Y, X) pairs.
;      wSignTextIDs  <- one textID per sign.
;      ESI advanced past the block.
; Preserves EAX (LoadMapHeader keeps its header cursor there) + EBX/ECX/EDI.
; ---------------------------------------------------------------------------
CopySignData:
    push eax
    push ebx
    push ecx
    push edi
    lea edi, [ebp + wSignCoords]      ; de = wSignCoords
    lea ebx, [ebp + wSignTextIDs]    ; bc = wSignTextIDs
    movzx ecx, byte [ebp + wNumSigns]
.loop:
    mov al, [esi]                       ; sign Y
    inc esi
    mov [edi], al
    inc edi
    mov al, [esi]                       ; sign X
    inc esi
    mov [edi], al
    inc edi
    mov al, [esi]                       ; sign textID
    inc esi
    mov [ebx], al
    inc ebx
    dec ecx
    jnz .loop
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; LoadMapData — faithful translation.
; Pret ref: home/overworld.asm:LoadMapData
; ---------------------------------------------------------------------------
LoadMapData:
    call DisableLCD
    call ResetMapVariables
    call LoadTextBoxTilePatterns
    call LoadMapHeader
    ; Dispatch per-map text table: MapTextTablePointers[wCurMap] → w_map_text_table_ptr.
    movzx eax, byte [ebp + wCurMap]
    lea esi, [MapTextTablePointers]
    mov esi, [esi + eax*4]
    mov [w_map_text_table_ptr], esi
    call InitMapSprites                 ; pret: InitMapSprites (load sprite tile patterns)
    ; DEVIATION{class=HAL; pret=home/overworld.asm:LoadMapData; behavior=pret's `call CopyMapViewToVRAM` after LoadScreenRelatedData is dropped, so the map view is never copied into the GB tilemap, though CopyMapViewToVRAM and its CopyMapViewToVRAM2 entry point both have faithful port bodies in this file which nothing reaches; evidence=the routine copies the 20x18 wTileMap into the vBGMap0 tilemap for the hardware PPU to scan, and the port has no such scan - render_bg in src/ppu/ppu.asm decodes wSurroundingTiles into a 48x36-tile surface through tile_cache and blits a 320x200 window out of it every frame, so the tilemap the copy would fill is never read, see CLAUDE.md on render_bg and the removal of the 256x256 VRAM torus - the other drop site is ReloadMapAfterSurfingMinigame in this file which carries its own annotation; lifetime=permanent, structural to the surface renderer}
    ; OW-A.5: pret calls LoadScreenRelatedData ONCE (home/overworld.asm:1967) then
    ; CopyMapViewToVRAM. The port's LoadScreenRelatedData (LoadTileBlockMap +
    ; LoadTilesetTilePatternData + LoadCurrentMapView) is idempotent and its
    ; LoadCurrentMapView is the native-render equivalent of pret's trailing
    ; CopyMapViewToVRAM, so one call covers both. (Removed a redundant second call.)
    call LoadScreenRelatedData

    mov byte [ebp + wUpdateSpritesEnabled], 1
    call EnableLCD
    call GBPalNormal
    mov bh, SET_PAL_OVERWORLD
    call RunPaletteCommand
    call LoadPlayerSpriteGraphics       ; pret: LoadPlayerSpriteGraphics (:1972)
    ; pret tail (:1975-1985): play this map's default music unless we entered via a
    ; dungeon/fly warp (DUNGEON_WARP|FLY_WARP) or the map suppresses it (NO_MAP_MUSIC).
    ; Bank save/restore around it is a no-op in the flat model. Real now (OW-A.14).
    test byte [ebp + wStatusFlags6], (1 << BIT_DUNGEON_WARP) | (1 << BIT_FLY_WARP)
    jnz .noMapMusic
    test byte [ebp + wStatusFlags7], (1 << BIT_NO_MAP_MUSIC)
    jnz .noMapMusic
    call UpdateMusic6Times
    call PlayDefaultMusicFadeOutCurrent
.noMapMusic:
    ret

; ---------------------------------------------------------------------------
; LoadScreenRelatedData — faithful translation.
; Pret ref: home/overworld.asm:LoadScreenRelatedData
; ---------------------------------------------------------------------------
LoadScreenRelatedData:
    call LoadTileBlockMap
    call LoadTilesetTilePatternData
    call LoadCurrentMapView
    ret

; ---------------------------------------------------------------------------
; ReloadMapAfterSurfingMinigame — faithful translation.
; Pret ref: home/overworld.asm:ReloadMapAfterSurfingMinigame (:1991-2007)
; ---------------------------------------------------------------------------
; DEVIATION{class=HAL; pret=home/overworld.asm:ReloadMapAfterSurfingMinigame; behavior=drops the CopyMapViewToVRAM and CopyMapViewToVRAM2 calls and flattens ROM banking, the two routines themselves being mirrored earlier in this file but unreached; evidence=native-width renderer renders wSurroundingTiles directly so VRAM tilemap copies are obsolete (OW-A.5), and the port uses a flat 32-bit address space; lifetime=permanent}
ReloadMapAfterSurfingMinigame:
    mov al, [ebp + hLoadedROMBank]
    push eax
    call DisableLCD
    call ResetMapVariables
    mov al, [ebp + wCurMap]
    call SwitchToMapRomBank
    call LoadScreenRelatedData
    ; CopyMapViewToVRAM and CopyMapViewToVRAM2 dropped (native renderer OW-A.5)
    call EnableLCD
    call ReloadMapSpriteTilePatterns
    pop eax
    call BankswitchCommon
    jmp FinishReloadingMap

; ---------------------------------------------------------------------------
; ReloadMapAfterPrinter — pret home/overworld.asm:ReloadMapAfterPrinter (:2008-2015).
;
; Rebuilds the block map after the Game Boy Printer has taken over the screen, then
; falls through into FinishReloadingMap exactly as pret does. Its five callers all
; live in pret engine/printer/printer.asm, which the port has not reached yet
; (docs/current_plan_printer.md) — so this has no port caller today and is here
; because the printer tier will need it and because the label was reading `missing`.
;
; The hLoadedROMBank save/restore and SwitchToMapRomBank are kept: they are the
; port's flat no-op MBC bookkeeping, matching every other translated site in this
; file (ReloadMapAfterSurfingMinigame does the same).
; ---------------------------------------------------------------------------
global ReloadMapAfterPrinter
ReloadMapAfterPrinter:
    mov al, [ebp + hLoadedROMBank]
    push eax
    mov al, [ebp + wCurMap]
    call SwitchToMapRomBank
    call LoadTileBlockMap
    pop eax
    call BankswitchCommon
    ; falls through — pret has no jump either

; ---------------------------------------------------------------------------
; FinishReloadingMap — faithful translation.
; Pret ref: home/overworld.asm:FinishReloadingMap (:2016-2019)
; ---------------------------------------------------------------------------
FinishReloadingMap:
    call SetMapSpecificScriptFlagsOnMapReload
    ret

; LoadPlayerSpriteGraphics — RETIRED from this file (wild-live promotion).
; The Phase-2 scaffold that lived here (walking-only, standing tiles → $8000 /
; walking tiles → $8800, plus a `call ClearSprites`) is superseded by the
; faithful pret dispatcher now linked from engine/overworld/player_gfx.asm
; (LoadPlayerSpriteGraphics → Walking/Bike/Surfing → LoadPlayerSpriteGraphicsCommon).
; Same VRAM layout; the scaffold's extra ClearSprites is intentionally NOT carried
; over — pret's LoadPlayerSpriteGraphicsCommon (home/overworld.asm:1775) does not
; clear OAM, and neither does pret's LoadMapData. `player_sprite` (pret RedSprite)
; stays defined here and is exported for player_gfx.asm.

; ---------------------------------------------------------------------------
; ResetMapVariables — faithful translation.
; Pret ref: home/overworld.asm:ResetMapVariables
;
; Sets wMapViewVRAMPointer = vBGMap0 ($9800 → port GB_TILEMAP0), zeroes SCX/SCY
; and walk state.
; ---------------------------------------------------------------------------
ResetMapVariables:
    ; pret home/overworld.asm:2024-2027 — wMapViewVRAMPointer = vBGMap0. Vestigial under
    ; the native-width renderer (dropped/unused; the torus rings are gone), but kept in
    ; lockstep with the other reset sites (EnterMapBoot etc. write GB_TILEMAP0) so the
    ; pointer is never left stale, matching pret's byte-for-byte reset here.
    mov word [ebp + wMapViewVRAMPointer], GB_TILEMAP0
    xor al, al
    mov byte [ebp + hSCY],                       al
    mov byte [ebp + hSCX],                       al
    mov byte [ebp + wWalkCounter],              al
    mov byte [ebp + wUnusedCurMapTilesetCopy], al
    mov byte [ebp + wSpriteSetID],             al
    mov byte [ebp + wWalkBikeSurfStateCopy], al
    ; Empty the window list on map entry: visibility is count-driven now, so this
    ; guarantees no stale box leaks over the overworld (e.g. the title's
    ; go_to_main_menu path). Dialog/menu code re-populates the list when it opens a
    ; box. The rWY/rWX shadows are parked off-screen for faithfulness.
    call hide_window                    ; count=0; sets hWY = RENDER_H
    mov byte [ebp + IO_WY], RENDER_H
    mov byte [ebp + IO_WX], 7
    ret

; ---------------------------------------------------------------------------
; CopyMapViewToVRAM / CopyMapViewToVRAM2 — pret home/overworld.asm:2033.
; Copies the 20x18 wTileMap screen into a 32-wide GB tilemap, skipping the 12
; off-screen tiles at the end of each tilemap row. CopyMapViewToVRAM2 is pret's
; second entry point, used when the caller wants a destination other than
; vBGMap0 already in DE.
;
; In:  (CopyMapViewToVRAM2) EDX = destination GB tilemap address (DE).
; Out: EDX/ESI advanced. Clobbers AL, EBX(bc), EDX, ESI, EDI.
;
; UNREACHED, like the six redraw routines above, and for the same reason: the
; port has no hardware PPU scanning a GB tilemap. render_bg composites from
; wSurroundingTiles / wTileMap directly, so vBGMap0 is written by nothing that
; reads it back on the overworld path. Both pret call sites drop it, each
; annotated at its own site (LoadMapData, ReloadMapAfterSurfingMinigame).
; Geometry is GB's throughout — see the header on the redraw ring above.
;
; NOTE — `inc e`, NOT `inc de`. pret advances only the LOW byte inside the inner
; loop and carries into D only on the row step, which is the 8-bit wrap the GB
; hardware gives for free. Translating it as a 16-bit increment would silently
; change the addressing at a page boundary, so the port keeps `inc dl`.
; ---------------------------------------------------------------------------
CopyMapViewToVRAM:
    mov edx, vBGMap0                             ; ld de, vBGMap0
CopyMapViewToVRAM2:
    mov esi, wTileMap                            ; ld hl, wTileMap
    mov bh, GB_SCREEN_HEIGHT                     ; ld b, SCREEN_HEIGHT (= 18)
.vramCopyLoop:
    mov bl, GB_SCREEN_WIDTH                      ; ld c, SCREEN_WIDTH (= 20)
.vramCopyInnerLoop:
    mov al, [ebp + esi]                          ; ld a, [hli]
    inc esi
    movzx edi, dx                                ; ld [de], a
    mov [ebp + edi], al
    inc dl                                       ; inc e — low byte only, as on the GB
    dec bl                                       ; dec c — 8-bit
    jnz .vramCopyInnerLoop
    add dl, TILEMAP_WIDTH - GB_SCREEN_WIDTH      ; ld a, TILEMAP_WIDTH - SCREEN_WIDTH / add e / ld e, a
    jnc .noCarry                                 ; jr nc, .noCarry
    inc dh                                       ; inc d
.noCarry:
    dec bh                                       ; dec b — 8-bit
    jnz .vramCopyLoop
    ret

SwitchToMapRomBank:
    call BankswitchCommon                        ; record AL in hLoadedROMBank (flat no-op MBC)
    ret

; ---------------------------------------------------------------------------
; GetMapHeaderPointer — pret home/overworld.asm:GetMapHeaderPointer (:2077-2093).
;
; Returns the address of wCurMap's entry in MapHeaderPointers. pret brackets the
; lookup with a BankswitchCommon pair for BANK(MapHeaderPointers); the port is
; flat, so the bank save/restore has no counterpart and is dropped.
;
; MapHeaderPointers is a table of GB (16-bit) addresses, so the port biases the
; entry by EBP to make it a flat pointer — pret's HL is already a bank-relative
; address that its callers dereference directly.
;
; In:  EBP = GB base, wCurMap.
; Out: ESI = flat address of the map header (pret: HL). Clobbers EAX.
;      pret preserves DE across the lookup (`push de` / `pop de`); the port's DX
;      is untouched here, so no save is needed.
; ---------------------------------------------------------------------------
global GetMapHeaderPointer
GetMapHeaderPointer:
    movzx eax, byte [ebp + wCurMap]         ; ld a,[wCurMap] / ld e,a / ld d,0
    add eax, eax                            ; add hl,de / add hl,de — 2 bytes per entry
    mov esi, MapHeaderPointers
    movzx esi, word [esi + eax]             ; ld a,[hli] / ld h,[hl] / ld l,a
    add esi, ebp                            ; GB address -> flat pointer
    ret

; ---------------------------------------------------------------------------
; IgnoreInputForHalfSecond — suppress player input for ~30 frames after a warp.
; Sets wIgnoreInputCounter=30 and BIT_DISABLE_JOYPAD in wStatusFlags5.
; The countdown runs at the top of OverworldLoop; joypad is re-enabled when it
; reaches 0. OverworldLoop's idle path skips direction reads while the bit is set.
; Pret ref: home/overworld.asm:IgnoreInputForHalfSecond
; ---------------------------------------------------------------------------
IgnoreInputForHalfSecond:
    mov byte [ebp + wIgnoreInputCounter], 30
    or byte [ebp + wStatusFlags5], (1 << BIT_DISABLE_JOYPAD) | (1 << 2) | (1 << 1)
    ret

; ---------------------------------------------------------------------------
; ResetUsingStrengthOutOfBattleBit — pret home/overworld.asm:2105-2108.
;
;     ld hl, wStatusFlags1 / res BIT_STRENGTH_ACTIVE, [hl] / ret
;
; Called from EnterMap on the non-battle-return path. Retired the ret-stub in
; overworld_stubs.asm (2026-08-22): the stub was behaviour-equivalent only while
; nothing ever SET the bit, and that is not a property to keep leaning on — the
; field-move Strength path sets it, and a stub here would silently leave Strength
; active across a map change.
; ---------------------------------------------------------------------------
global ResetUsingStrengthOutOfBattleBit
ResetUsingStrengthOutOfBattleBit:
    and byte [ebp + wStatusFlags1], ~(1 << BIT_STRENGTH_ACTIVE) & 0xFF
    ret

global IsSpriteOrSignInFrontOfPlayer         ; A-press dispatch head (overworld.asm)
global IsSpriteInFrontOfPlayer               ; sprite scan — TryPushingBoulder (push_boulder.asm)
global IsSpriteInFrontOfPlayer2              ; long-range entry — counter branch above; Surf open

; ---------------------------------------------------------------------------
; IsSpriteInFrontOfPlayer / IsSpriteInFrontOfPlayer2 — detect-only sprite scan.
; Pret ref: home/overworld.asm:IsSpriteInFrontOfPlayer (:1084-1175)
;
; Finds the sprite (if any) standing at the pixel position the player faces, sets
; BIT_FACE_PLAYER on it, and reports its SLOT in [hSpriteIndex]. pret's two labels
; are one routine with two entry points: IsSpriteInFrontOfPlayer presets the normal
; $10-pixel talking range, IsSpriteInFrontOfPlayer2 expects the caller to have set
; DH (the long $20 range used over pokécenter/mart counter tiles). Both labels are
; kept, per CLAUDE.md's rule on structural splits.
;
; This pixel scan is now the SOLE collision/talk scan. The former bespoke
; MAPY/MAPX block scan IsNPCAtTargetBlock (map_sprites.asm, retired
; 2026-08-27) was a port-only helper used by CollisionCheckOnLand; literal
; IsSpriteInFrontOfPlayer now serves that caller, and CheckNPCInteraction
; consumes its result via [hSpriteIndex].
;
; CONSUMERS: TryPushingBoulder (push_boulder.asm), and the
; IsSpriteOrSignInFrontOfPlayer head (counter branch → the -2 entry,
; no-counter fallthrough → the normal entry). ItemUseSurfboard's -2 check at
; pret engine/items/item_effects.asm:725 is still open (Stage 4 Surf bullet,
; which lists "supply IsSpriteInFrontOfPlayer2" as its dependency).
;
; Register map: a=AL, b=BH (player Y), c=BL (player X), d=DH, e=DL, hl=ESI.
; pret reuses D: it is the talking RANGE until .doneCheckingDirection, then the
; loop COUNTER. That reuse is preserved here rather than tidied away.
;
; Out: CF=1 and [hSpriteIndex] = slot (1-15) if a sprite faces the player;
;      CF=0 and AL=0 otherwise ([hSpriteIndex] is left alone — pret makes the
;      CALLER zero it first, and TryPushingBoulder does exactly that).
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; IsSpriteOrSignInFrontOfPlayer — pret home/overworld.asm:IsSpriteOrSignInFrontOfPlayer.
; The A-press interaction head: sign lookup first, then the counter-tile
; talking-range extension, then FALLS THROUGH into the sprite scan —
; pret has no ret between the counter loop and IsSpriteInFrontOfPlayer, and
; that fallthrough is load-bearing: do not insert anything between them.
;
; Leaves the found id in [hTextID] (== [hSpriteIndex] — same HRAM byte, the
; linchpin of pret's contract): SignLoop stores the sign's text id, the sprite
; scan stores the slot number. Out: CF=1 if a sign or sprite faces the player;
; CF=0 and [hTextID]=0 otherwise. The caller distinguishes sign vs sprite by
; id <= [wNumSprites] (pret DisplayTextID's rule) and zeroes wd435 first
; (pret OverworldLoop does both).
;
; A counter-tile match enters the scan at IsSpriteInFrontOfPlayer2 with
; DH = $20 (two-tile range) still live — that is the entire effect of the
; counter branch: at a mart/center counter you can talk to the clerk one tile
; behind it. wTilesetTalkingOverTiles is loaded per-map by LoadTilesetHeader.
; ---------------------------------------------------------------------------
ForceBikeOrSurf:
    call LoadPlayerSpriteGraphics
    jmp PlayDefaultMusic                     ; pret: jp PlayDefaultMusic (tail call)
; HandleMidJump — pret home/overworld.asm:HandleMidJump. Called once per
; OverworldLoopLessDelay iteration; no-op unless a ledge hop (or fishing
; sequence) armed BIT_LEDGE_OR_FISHING.
HandleMidJump:
%ifdef DEBUG_LEDGE_TRACE
    ; Per-call trace ring in SRAM bank 3 ($26000, untouched by this scenario):
    ; [26000] = LE16 write index, entries of 8 bytes from $26010.
    ; Debug aid for the ledge_hop harness only — never in a golden build.
    push eax
    push esi
    movzx esi, word [ebp + 0x26000]
    cmp esi, 0x3F0
    jae .trace_done
    inc word [ebp + 0x26000]
    shl esi, 3
    add esi, 0x26010
    mov al, [ebp + wWalkCounter]
    mov [ebp + esi + 0], al
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    mov [ebp + esi + 1], al
    mov al, [ebp + wMovementFlags]
    mov [ebp + esi + 2], al
    mov al, [ebp + wYCoord]
    mov [ebp + esi + 3], al
    mov al, [ebp + wJoyIgnore]
    mov [ebp + esi + 4], al
    mov al, [ebp + wStatusFlags5]
    mov [ebp + esi + 5], al
    mov al, [ebp + hJoyHeld]
    mov [ebp + esi + 6], al
    mov byte [ebp + esi + 7], 0
.trace_done:
    pop esi
    pop eax
%endif
    test byte [ebp + wMovementFlags], (1 << BIT_LEDGE_OR_FISHING)
    jz  .ret
    call _HandleMidJump
.ret:
    ret

; ---------------------------------------------------------------------------
; IsSpinning — pret home/overworld.asm:IsSpinning (:2125-2129).
;
;     ld a, [wMovementFlags] / bit BIT_SPINNING, a / ret z
;     farjp LoadSpinnerArrowTiles          ; spin while moving
;
; Called once per mid-walk OverworldLoopLessDelay iteration (pret's .moveAhead,
; :234-235). The port had the spinner TILE loader (LoadSpinnerArrowTiles,
; engine/overworld/spinners.asm) translated with no caller, so the spinner-tile
; blink that pushes the player across a Team Rocket HQ / Viridian Gym floor could
; never run. The `farjp` is a plain tail jump in the flat model.
; ---------------------------------------------------------------------------
global IsSpinning
IsSpinning:
    test byte [ebp + wMovementFlags], (1 << BIT_SPINNING)
    jz .ret                                  ; ret z — not spinning
    jmp LoadSpinnerArrowTiles                ; farjp LoadSpinnerArrowTiles
.ret:
    ret

; ---------------------------------------------------------------------------
; Func_0ffe — pret home/overworld.asm:2131 (jpfar IsPlayerTalkingToPikachu)
; ---------------------------------------------------------------------------
global Func_0ffe
Func_0ffe:
    jmp IsPlayerTalkingToPikachu

global InitSprites
global ZeroSpriteStateData
global DisableRegularSprites
global LoadSprite

InitSprites:
    pushad
    ; A = [wNumSprites source] = sprite_count byte; ESI advances past it.
    ; W_OBJECT_DATA_PTR_TEMP holds the GB offset of the sprite_count byte.
    movzx esi, word [ebp + W_OBJECT_DATA_PTR_TEMP]   ; ESI = GB addr of sprite_count
    movzx eax, byte [ebp + esi]
    mov [ebp + wNumSprites], al                       ; wNumSprites = count
    inc esi                                            ; past the count byte
    call ZeroSpriteStateData
    call DisableRegularSprites
    ; zero wMapSpriteData ($20 bytes) — pret: ld hl,wMapSpriteData; ld bc,$20; FillMemory
    mov edi, wMapSpriteData
    xor al, al
    mov ecx, 0x20
    rep stosb
    ; any sprites?
    movzx eax, byte [ebp + wNumSprites]
    test al, al
    jz .done
    mov ebx, eax                                       ; EBX = count remaining (pret B)
    mov edx, 0x10                                       ; EDX = slot byte offset (slot 1)
    xor edi, edi                                        ; EDI = wMapSpriteData index (pret C): 0,2,4,...
.loadSpriteLoop:
    ; picture id -> x#SPRITESTATEDATA1_PICTUREID
    movzx eax, byte [ebp + esi]
    inc esi
    mov [ebp + edx + wSpriteStateData1 + SPRITESTATEDATA1_PICTUREID], al
    ; mapy -> x#SPRITESTATEDATA2_MAPY
    movzx eax, byte [ebp + esi]
    inc esi
    mov [ebp + edx + wSpriteStateData2 + SPRITESTATEDATA2_MAPY], al
    ; mapx -> x#SPRITESTATEDATA2_MAPX
    movzx eax, byte [ebp + esi]
    inc esi
    mov [ebp + edx + wSpriteStateData2 + SPRITESTATEDATA2_MAPX], al
    ; movement byte 1 -> x#SPRITESTATEDATA2_MOVEMENTBYTE1
    movzx eax, byte [ebp + esi]
    inc esi
    mov [ebp + edx + wSpriteStateData2 + SPRITESTATEDATA2_MOVEMENTBYTE1], al
    ; movement byte 2 -> temp1
    movzx eax, byte [ebp + esi]
    inc esi
    mov [h_load_sprite_temp1], al
    ; text id + flags -> temp2
    movzx eax, byte [ebp + esi]
    inc esi
    mov [h_load_sprite_temp2], al
    ; DIVERGENCE (port ext): set the per-slot ISTRAINER flag (SPRITESTATEDATA2 0x0A)
    ; that the port interaction stack (CheckNPCInteraction / CheckTrainerSight /
    ; TrainerEncounterFlow) reads. pret has no such field — it re-derives trainer-ness
    ; from the text-id flags at interaction time, in the SPRITE branch of
    ; IsSpriteOrSignInFrontOfPlayer (the branch the port realizes as CheckNPCInteraction;
    ; the sign branch itself is ported, below).
    ; The bespoke InitMapSprites used to set this; it is retired in P3c, so InitSprites
    ; (the slot populator) carries it. ZeroSpriteStateData already cleared the slot.
    test al, TRAINER_FLAG
    jz .not_trainer_slot
    mov byte [ebp + edx + wSpriteStateData2 + SPRITESTATEDATA2_ISTRAINER], 1
.not_trainer_slot:
    ; LoadSprite: ECX = wMapSpriteData index; ESI = read ptr (advanced past any
    ; trainer/item extra bytes on return). It preserves EBX/EDX/EDI and clobbers EAX.
    mov ecx, edi
    call LoadSprite
    ; advance to next sprite: slot offset += $10, wMapSpriteData index += 2, count--
    add edx, 0x10
    add edi, 2
    dec ebx
    jnz .loadSpriteLoop
.done:
    popad
    ret

; Zero sprite state data for slots 1-14 (slot 15 is Pikachu, left intact — pret).
ZeroSpriteStateData:
    push eax
    push ecx
    push edi
    xor al, al
    lea edi, [ebp + wSpriteStateData1 + 0x10]      ; slot 1
    mov ecx, 14 * 0x10
    rep stosb
    lea edi, [ebp + wSpriteStateData2 + 0x10]
    mov ecx, 14 * 0x10
    rep stosb
    pop edi
    pop ecx
    pop eax
    ret

; Disable regular sprites: SPRITESTATEDATA1_IMAGEINDEX for slots 1-14.
; DIVERGENCE (harness-only; zero real-game effect): pret writes $ff here — a
; "hidden until initialized" marker. This seed is IRRELEVANT to the running game:
; the first UpdateSprites frame calls InitializeSpriteStatus (movement.asm:727),
; which unconditionally overwrites IMAGEINDEX with $ff; the second frame's
; CheckSpriteAvailability → UpdateSpriteImage then computes the real facing index.
; So under the live game (EnterMap + OverworldLoop both run UpdateSprites) a $ff or
; a 0 seed here behave identically. The seed ONLY changes the STATIC pre-UpdateSprites
; DEBUG-harness snapshot (DEBUG_BASELINE etc. render without running UpdateSprites):
; $ff hides the NPCs there, 0 (the ZeroSpriteStateData value → facing-down anim-0)
; shows them. We keep 0 so that regression snapshot still exercises NPC rendering.
; Restoring the faithful $ff needs the DEBUG harness to run UpdateSprites like EnterMap
; — but on frame 2 the port's random-movement path makes a WALK NPC try to move
; immediately (no initial move-delay), so it also needs pret's move-delay/probability
; ported (movement-engine work, OW-A.7 territory) to keep the snapshot deterministic.
DisableRegularSprites:
    push ecx
    push esi
    mov esi, 0x10                                       ; slot 1
    mov ecx, 14
.loop:
    mov byte [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_IMAGEINDEX], 0
    add esi, 0x10
    dec ecx
    jnz .loop
    pop esi
    pop ecx
    ret

; LoadSprite (pret home/overworld.asm:2218). In: ECX = wMapSpriteData/ExtraData byte
; index ((slot-1)*2); ESI = GB read ptr just past the text-id byte; temp1 = movement
; byte 2, temp2 = text id + flags. Out: ESI advanced past trainer/item extra bytes.
; Preserves EBX/ECX/EDX/EDI; clobbers EAX.
LoadSprite:
    push eax
    ; wMapSpriteData[C] = movement byte 2
    mov al, [h_load_sprite_temp1]
    mov [wMapSpriteData + ecx], al
    ; pret writes text id+flags to [C+1] here then immediately overwrites it with the
    ; masked value — kept for faithfulness ("this appears pointless").
    mov al, [h_load_sprite_temp2]
    mov [wMapSpriteData + ecx + 1], al
    mov al, [h_load_sprite_temp2]
    mov [h_load_sprite_temp1], al                       ; temp1 = text id+flags (save for flag test)
    and al, 0x3f
    mov [wMapSpriteData + ecx + 1], al                  ; wMapSpriteData[C+1] = masked text id
    ; branch on the raw (unmasked) text-id+flags byte
    mov al, [h_load_sprite_temp1]
    test al, TRAINER_FLAG
    jnz .trainerSprite
    test al, ITEM_FLAG
    jnz .itemBallSprite
    ; regular sprite: zero both wMapSpriteExtraData bytes
    mov word [wMapSpriteExtraData + ecx], 0
    pop eax
    ret
.trainerSprite:
    movzx eax, byte [ebp + esi]                         ; trainer class
    inc esi
    mov [h_load_sprite_temp1], al
    movzx eax, byte [ebp + esi]                         ; trainer number
    inc esi
    mov [h_load_sprite_temp2], al
    mov al, [h_load_sprite_temp1]
    mov [wMapSpriteExtraData + ecx], al                 ; ExtraData[C] = trainer class
    mov al, [h_load_sprite_temp2]
    mov [wMapSpriteExtraData + ecx + 1], al             ; ExtraData[C+1] = trainer number
    pop eax
    ret
.itemBallSprite:
    movzx eax, byte [ebp + esi]                         ; item number
    inc esi
    mov [h_load_sprite_temp1], al
    mov al, [h_load_sprite_temp1]
    mov [wMapSpriteExtraData + ecx], al                 ; ExtraData[C] = item number
    mov byte [wMapSpriteExtraData + ecx + 1], 0         ; ExtraData[C+1] = 0
    pop eax
    ret

CheckForUserInterruption:
    call DelayFrame
    push ebx                          ; pret push bc — preserve the frame counter
    call JoypadLowSensitivity
    pop ebx
    mov al, [ebp + hJoyHeld]        ; ldh a, [hJoyHeld]
    cmp al, PAD_UP + PAD_SELECT + PAD_B   ; exactly Up+Select+B (the skip combo)
    je .input
    mov al, [ebp + hJoy5]            ; ldh a, [hJoy5]
    and al, PAD_START | PAD_A         ; release build (pret _DEBUG also allows Select)
    jnz .input
    dec bl                            ; dec c
    jnz CheckForUserInterruption      ; jr nz — loop for the remaining frames
    and al, al                        ; pret `and a` — clear CF (no interruption)
    ret
.input:
    stc                               ; scf
    ret

; ---------------------------------------------------------------------------
; SwitchToMapRomBank — set the ROM bank for the current map's data/scripts.
; pret home/overworld.asm:SwitchToMapRomBank: reads the map's bank from
; MapHeaderBanks and BankswitchCommon-s to it. Flat-model: record the requested
; bank (bookkeeping); the physical MBC write is a no-op. Consumers (reload_tiles,
; text_script, run_map_script) keep the pret call structure.
; In: AL = map bank id. All other registers preserved.
; ---------------------------------------------------------------------------
global SwitchToMapRomBank
global AdvancePlayerSprite
global CollisionCheckOnLand
global CollisionCheckOnWater
global DoBikeSpeedup
global EnterMap
global IgnoreInputForHalfSecond
global OverworldLoop
global OverworldLoopLessDelay

; ---------------------------------------------------------------------------
; LoadDestinationWarpPosition — load spawn Y/X from the destination map's warp
; table entry selected by wDestinationWarpID.
; Pret ref: home/overworld.asm:LoadDestinationWarpPosition
; PROJ divergence: pret's predef version copies a 4-byte (block-view-pointer,
; Y, X) struct from an hl-indexed ROM table straight into
; wCurrentTileBlockMapViewPointer/wYCoord/wXCoord. The port has no parallel
; per-map view-pointer table; it reads Y/X directly out of the already-loaded
; wWarpEntries (Y, X, dest_warp_id, dest_map_id per entry — see the
; `warp_event` macro / the CheckWarps* scans), and leaves wCurrentTileBlockMapViewPointer
; to LoadDestinationMapData's explicit stride-math recompute, which replaces
; pret's ROM view-pointer lookup with an equivalent runtime computation.
; In:  wDestinationWarpID = 0-based warp index (destination map's table)
; Out: wYCoord, wXCoord set. Preserves all other registers/flags.
; ---------------------------------------------------------------------------
LoadDestinationWarpPosition:
    push eax
    push esi

    movzx eax, byte [ebp + wDestinationWarpID]
    shl eax, 2                          ; * 4 bytes per warp entry
    lea esi, [ebp + wWarpEntries]
    add esi, eax
    mov al, [esi]                       ; spawn Y tile
    mov [ebp + wYCoord], al
    mov al, [esi+1]                     ; spawn X tile
    mov [ebp + wXCoord], al

    pop esi
    pop eax
    ret


