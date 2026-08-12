; palettes.asm — CGB/SGB palette-command realization for the native renderer.
bits 32
%include "gb_memmap.inc"

%define SET_PAL_BATTLE_BLACK             0
%define SET_PAL_BATTLE                   1
%define SET_PAL_TOWN_MAP                 2
%define SET_PAL_STATUS_SCREEN            3
%define SET_PAL_POKEDEX                  4
%define SET_PAL_SLOTS                    5
%define SET_PAL_TITLE_SCREEN             6
%define SET_PAL_NIDORINO_INTRO           7
%define SET_PAL_GENERIC                  8
%define SET_PAL_OVERWORLD                9
%define SET_PAL_PARTY_MENU               10
%define SET_PAL_POKEMON_WHOLE_SCREEN     11
%define SET_PAL_GAME_FREAK_INTRO         12
%define SET_PAL_TRAINER_CARD             13
%define SET_PAL_SURFING_PIKACHU_TITLE    14
%define SET_PAL_SURFING_PIKACHU_MINIGAME 15
%define SET_PAL_DEFAULT                  0xff

; pret constants not otherwise needed by the DOS map loader.
; NUM_ACTIVE_PALS (constants/palette_constants.asm) is how many palettes an SGB
; PAL_SET packet carries, and therefore how many slots InitCGBPalettes writes.
%define NUM_ACTIVE_PALS     4
%define NUM_CITY_MAPS       11
%define FIRST_INDOOR_MAP    0x25
%define CERULEAN_CAVE_2F    0xe2
%define CERULEAN_CAVE_1F    0xe4
%define LORELEIS_ROOM       0xf5
%define BRUNOS_ROOM         0xf6
%define TRADE_CENTER        0xef
%define COLOSSEUM           0xf0
%define CEMETERY            15
%define CAVERN              17
%define PAL_ROUTE           0
%define PAL_GRAYMON         25
%define PAL_BLACK           30
%define PAL_GREENBAR        31
%define PAL_CAVE            35
%define PAL_MEWMON          16
%define PAL_PIKACHUS_BEACH  37
; pret writes `ld bc, wPartyMon2 - wPartyMon1`; this file defines its constants
; locally rather than including gb_constants.inc (same style as the PAL_* above).
%define PARTYMON_STRUCT_LENGTH 0x2C

global _RunPaletteCommand
global SetPalFunctions, SetPal_BattleBlack, SetPal_Battle, DeterminePaletteID
global SetPal_TownMap, SetPal_StatusScreen, SetPal_Pokedex, SetPal_Slots
global SetPal_TitleScreen, SetPal_NidorinoIntro, SetPal_Generic, SetPal_Overworld
global SetPal_PartyMenu, SetPal_PokemonWholeScreen, SetPal_GameFreakIntro
global SetPal_TrainerCard, SetPal_PikachusBeach, SetPal_PikachusBeachTitle
global YellowIntroPaletteAction

extern IndexToPokedex               ; engine/menus/pokedex.asm — predef, wPokedexNum in place
extern AddNTimes                    ; src/home/array.asm — ESI += BX * AL
extern tile_pal, g_tilecache_dirty
extern g_pal_dirty, bg_slot_pal, obj_slot_pal
extern mon_pal_table, battle_slot_pal, battle_tile_pal, command_pal_table
extern RefreshMonFrontRepaintPalette
extern LoadBGMapAttributes, g_bg_attr_table  ; engine/gfx/bg_map_attributes.asm

section .text

; Native equivalent of the SGB packet dispatcher.  Palette colors live in the
; generated RGB table; this only selects their runtime slots and cache bands.
_RunPaletteCommand:
    ; pret engine/gfx/palettes.asm:_RunPaletteCommand — SET_PAL_DEFAULT is not a
    ; palette of its own: it means "whatever screen owns the default", which
    ; SetPal_Overworld / SetPal_Battle / SetPal_GameFreakIntro publish into
    ; wDefaultPaletteCommand. Resolving it to SetPal_Generic instead (as this did
    ; until 2026-08-05) meant every RunDefaultPaletteCommand caller returning to
    ; the overworld — the trainer card, the pokédex, the naming screen, the main
    ; menu — repainted the map in the generic palette instead of the map's own.
    cmp al, SET_PAL_DEFAULT
    jne .not_default
    mov al, [ebp + wDefaultPaletteCommand]  ; ld a, [wDefaultPaletteCommand]
.not_default:
    ; pret: ld l,a / ld h,0 / add hl,hl / ld de,SetPalFunctions / add hl,de /
    ; ld a,[hli] / ld h,[hl] / ld l,a / jp hl — an INDIRECT dispatch through the
    ; table, which is what this now does (dd entries, so *4 rather than *2).
    ;
    ; It used to be a cmp chain that special-cased SET_PAL_BATTLE and
    ; SET_PAL_OVERWORLD and sent EVERY other command straight to SetPal_Screen.
    ; That skipped the per-command SetPal_* labels entirely, and one of them does
    ; more than name a table row: SetPal_GameFreakIntro publishes
    ; wDefaultPaletteCommand = SET_PAL_GENERIC. Bypassing it made that publish
    ; dead code, and it is the ONLY thing on the boot path that ever seeds the
    ; default — so wDefaultPaletteCommand stayed at its cold-boot 0 and MainMenu's
    ; RunDefaultPaletteCommand resolved SET_PAL_DEFAULT to SET_PAL_BATTLE_BLACK,
    ; painting the new-game Oak / rival / player screens in PAL_BLACK. Measured
    ; 2026-08-10 against the oak_palette_trace mGBA capture, which has PAL_MEWMON
    ; in BG slot 0 and PAL_ROUTE in 1-3 at that checkpoint.
    ;
    ; Latent since the port was written, but only OBSERVABLE from 62286cb7
    ; (2026-08-05), which stopped hardcoding SET_PAL_DEFAULT -> SetPal_Generic and
    ; started honouring wDefaultPaletteCommand. Before that the missing publish was
    ; masked because the hardcoded answer happened to be the right one here.
    cmp al, SET_PAL_SURFING_PIKACHU_MINIGAME
    ja .done                                ; SET_PAL_PARTY_MENU_HP_BARS ($fc) and any
                                            ; out-of-range id: no port handler, as before
    movzx eax, al
    jmp [SetPalFunctions + eax*4]
.done:
    ret

SetPal_BattleBlack:
    pushad
    ; FOUR slots, not eight. pret hands PalPacket_Black (PAL_SET PAL_BLACK x4) to
    ; InitCGBPalettes, which writes BG palettes 0-3 and OBJ palettes 0-3/4-7 from
    ; those four entries -- BG 4-7 are never written by any packet. Flooding all
    ; eight left PAL_BLACK in BG 4-7 permanently, since nothing else writes them.
    mov al, PAL_BLACK
    mov ecx, NUM_ACTIVE_PALS
    mov edi, bg_slot_pal
    rep stosb
    mov ecx, NUM_ACTIVE_PALS
    mov edi, obj_slot_pal
    rep stosb
    mov byte [g_pal_dirty], 1
    popad
    ret

; Live slots: player HP, enemy HP, player pic, enemy pic.
SetPal_Battle:
    pushad
    mov esi, battle_slot_pal
    mov edi, bg_slot_pal
    mov ecx, 4
    rep movsb
    ; pret (engine/gfx/palettes.asm:33-46) picks the PLAYER's species through a
    ; pointer, not from a flat copy: HL = wBattleMonSpecies, and when that byte is
    ; non-zero HL is retargeted at &wPartyMon1[wPlayerMonNumber] so the id comes
    ; from the PARTY struct. The port read wBattleMonSpecies2 ($CFD8) — a
    ; different address from pret's wBattleMonSpecies ($D013), both of which exist
    ; here and match pokeyellow.sym — and never consulted the party mon. It
    ; happened to agree in an ordinary battle, which is why the battle scenarios
    ; report 0 palette divergences either way; this is the faithful shape.
    mov esi, wBattleMonSpecies          ; ld hl, wBattleMonSpecies
    mov al, [ebp + esi]                 ; ld a, [hl]
    test al, al                         ; and a
    jz .playerPalFromBattleMon          ; jr z, .asm_71ef9
    mov esi, wPartyMon1                 ; ld hl, wPartyMon1
    mov al, [ebp + wPlayerMonNumber]    ; ld a, [wPlayerMonNumber]
    mov bx, PARTYMON_STRUCT_LENGTH      ; ld bc, wPartyMon2 - wPartyMon1
    call AddNTimes                      ; hl = &partyMon[n] (species at +0)
.playerPalFromBattleMon:
    call DeterminePaletteID             ; pret's HL-reading entry
    mov [bg_slot_pal + 2], al
    mov esi, wEnemyMonSpecies2          ; ld hl, wEnemyMonSpecies2
    call DeterminePaletteID
    mov [bg_slot_pal + 3], al
    movzx eax, byte [ebp + wPlayerHPBarColor]
    add al, PAL_GREENBAR
    mov [bg_slot_pal], al
    movzx eax, byte [ebp + wEnemyHPBarColor]
    add al, PAL_GREENBAR
    mov [bg_slot_pal + 1], al
    ; Mirror the four battle base palettes into the OBJ slots. pret's
    ; InitCGBPalettes converts the SAME four packet palettes into BG pals AND
    ; OBP0/OBP1 pals (engine/gfx/palettes.asm:736 — one GetCGBBasePalAddress,
    ; then CONVERT_BGP + CONVERT_OBP0 + CONVERT_OBP1 from it), and SetPal_Screen
    ; here already mirrors its row into both tables. SetPal_Battle was the one
    ; handler that filled only bg_slot_pal, so the OBJ slots kept whatever the
    ; previous screen left — after the battle transition that is SetPal_BattleBlack's
    ; PAL_BLACK flood, which rendered every battle-animation particle (colors 1-3
    ; of the anim tiles) as a solid black silhouette (maintainer-observed:
    ; black GUST tornado, black stars; production-path confirmed via
    ; TRAINER_ROUTE_PILOT, so not a harness phantom).
    mov esi, bg_slot_pal
    mov edi, obj_slot_pal
    mov ecx, 4
    rep movsb
    mov dword [g_bg_attr_table], 0   ; battle publishes battle_tile_pal itself
    mov esi, battle_tile_pal
    mov edi, tile_pal
    mov ecx, 384
    rep movsb
    call RefreshMonFrontRepaintPalette   ; R2 overlay survives the baseline copy
    mov byte [ebp + wDefaultPaletteCommand], SET_PAL_BATTLE ; ld a,SET_PAL_BATTLE / ld [wDefaultPaletteCommand],a
    mov byte [g_tilecache_dirty], 1
    mov byte [g_pal_dirty], 1
    popad
    ret

; Generated SGB packet rows for every non-battle command.  Resetting tile_pal
; makes slot 0 the default layer color, while screens that already publish slot
; bands (battle/repaint) retain their dedicated handlers above.
SetPal_Screen:
    pushad
    movzx eax, al
    mov edx, eax                            ; keep the command id; EDX survives the
                                            ; rep movsb/stosb below (they use ESI/EDI/ECX/AL)
    shl eax, 2
    mov esi, command_pal_table
    add esi, eax
    mov edi, bg_slot_pal
    mov ecx, 4
    rep movsb
    mov esi, command_pal_table
    add esi, eax
    mov edi, obj_slot_pal
    mov ecx, 4
    rep movsb
    xor al, al
    mov edi, tile_pal
    mov ecx, 384
    rep stosb
    ; The zero-flood above already IS BlkPacket_WholeScreen's attribute plane,
    ; which is all zeroes — so every command pret pairs with BlkPacket_WholeScreen
    ; (GENERIC, TOWN_MAP, OVERWORLD, POKEMON_WHOLE_SCREEN, both Pikachu's Beach
    ; commands) is complete here and maps to 0 in the table below. The rest carry
    ; a real per-cell plane and overlay it on top of the flood.
    cmp edx, SET_PAL_ATTR_TABLE_LEN
    jae .clear_attributes
    movzx ebx, byte [set_pal_attr_table + edx]
    test bl, bl
    jz .clear_attributes
    mov bh, bl
    and bh, SET_PAL_ATTR_CANVAS             ; bit 7: screen lives on the projected canvas
    and bl, ~SET_PAL_ATTR_CANVAS & 0xff     ; low bits: packet index
    call LoadBGMapAttributes
    jmp .attributes_done
.clear_attributes:
    ; No plane for this command (or an out-of-range id): drop the previous
    ; screen's, so ApplyBGMapAttributes stops re-resolving it. The zero-flood
    ; above already left tile_pal in the all-palette-0 state this implies.
    mov dword [g_bg_attr_table], 0
.attributes_done:
    mov byte [g_tilecache_dirty], 1
    mov byte [g_pal_dirty], 1
    popad
    ret

; SET_PAL_* command id → BGMapAttributesPointers index (pret's `c`, 1-based;
; 0 = no attribute plane). pret reaches these through
; TranslatePalPacketToBGMapAttributes, which matches the BLK packet pointer each
; SetPal_* hands to RunPaletteCommand; this table is that match resolved ahead of
; time, since the port's SetPal_Screen dispatches on the command id directly.
; Derived from pret engine/gfx/palettes.asm's SetPal_* bodies:
;   SET_PAL_BATTLE(1)->BlkPacket_Battle is handled by SetPal_Battle's own
;   battle_tile_pal path and is deliberately absent here.
; Bit 7 marks a screen the port draws on its 40x25 canvas under the uniform
; +10 col / +3 row GB-centered projection (docs/ui_projection.md), rather than
; through a window over GB_TILEMAP0/1. The title screen renders through the
; window path and so does NOT set it; the copyright/Oak cinematics draw onto the
; canvas and do. Screens with per-element anchoring must never set it — there is
; no cell-for-cell mapping to read them at.
SET_PAL_ATTR_CANVAS equ 0x80

section .data
set_pal_attr_table:
    db 0                                    ; 0  SET_PAL_BATTLE_BLACK  — SetPal_BattleBlack owns it
    db 0                                    ; 1  SET_PAL_BATTLE        — SetPal_Battle owns it
    db 0                                    ; 2  SET_PAL_TOWN_MAP      → WholeScreen (= the flood)
    db 10 | SET_PAL_ATTR_CANVAS             ; 3  SET_PAL_STATUS_SCREEN → StatusScreen (canvas +10/+3)
    db 9 | SET_PAL_ATTR_CANVAS              ; 4  SET_PAL_POKEDEX       → Pokedex (stride-20 scratch)
    db 8                                    ; 5  SET_PAL_SLOTS         → Slots
    db 7                                    ; 6  SET_PAL_TITLE_SCREEN  → TitleScreen
    db 6 | SET_PAL_ATTR_CANVAS              ; 7  SET_PAL_NIDORINO_INTRO→ NidorinoIntro (canvas)
    db 0                                    ; 8  SET_PAL_GENERIC       → WholeScreen (= the flood)
    db 0                                    ; 9  SET_PAL_OVERWORLD     → WholeScreen (= the flood)
    db 5                                    ; 10 SET_PAL_PARTY_MENU    → PartyMenu
    db 0                                    ; 11 SET_PAL_POKEMON_WHOLE_SCREEN → WholeScreen (= the flood)
    db 3 | SET_PAL_ATTR_CANVAS              ; 12 SET_PAL_GAME_FREAK_INTRO → GameFreakIntro (canvas)
    db 4 | SET_PAL_ATTR_CANVAS              ; 13 SET_PAL_TRAINER_CARD  → TrainerCard (stride-20 scratch)
    db 0                                    ; 14 SET_PAL_SURFING_PIKACHU_TITLE → WholeScreen (= the flood)
    db 0                                    ; 15 SET_PAL_SURFING_PIKACHU_MINIGAME → WholeScreen (= the flood)
SET_PAL_ATTR_TABLE_LEN equ $ - set_pal_attr_table
section .text

; ---------------------------------------------------------------------------
; YellowIntroPaletteAction — pret engine/gfx/palettes.asm:YellowIntroPaletteAction
;
; In: DL = pret's E, the scene's palette variant.
;
; E == 0 is the plain Generic packet. E != 0 is the one the Yellow intro spends
; almost all its time in: PalPacket_PikachusBeach in all four slots, then base
; palette 1 overridden with PalPacket_Generic's first palette (PAL_MEWMON).
;
; *** SLOT 1 IS OVERRIDDEN ON **BOTH** PLANES, NOT BG-ONLY. *** This comment used
; to claim "it touches the BG palette ONLY — the OBJ slots keep
; PAL_PIKACHUS_BEACH ... getting that asymmetry wrong is the whole difference
; between the intro's real look and a flat wash", and the code matched that
; claim. It is wrong, and it is what left Pikachu with BLUE CHEEKS on the surfing
; and balloon scenes.
;
; pret writes the override into wCGBBasePalPointers + 2 — the BASE palette table
; that feeds BOTH planes — and only then calls TransferCurBGPData with a = 1. The
; BG-only step is momentary: YellowIntroPaletteAction's SOLE caller is
; intro_yellow.asm:Func_f9e9a, which unconditionally calls UpdateCGBPal_OBP0 and
; UpdateCGBPal_OBP1 a few instructions later, and _UpdateCGBPal_OBP
; (engine/gfx/palettes.asm:991) rebuilds ALL FOUR OBJ palettes by re-reading
; wCGBBasePalPointers. So PAL_MEWMON lands in OBJ palette 1 too.
;
; That is exactly what the cheeks need: PAL_PIKACHUS_BEACH has NO red at all
; (white, yellow, blue, black), while PAL_MEWMON's colour 2 IS red. The surfing
; hook Func_f98a2 and the flying/balloon hook Func_f98cb OR $1 into the cheek
; sprites' OAM attribute bytes, i.e. CGB OBJ palette 0 -> 1, and palette 1 is the
; one slot carrying red.
;
; This is why the intro used to render entirely in Mew's red/blue: the port
; dropped this routine, so every scene fell back to SET_PAL_GENERIC = PAL_MEWMON
; in all four slots.
;
; DEVIATION{class=HAL; pret=engine/gfx/palettes.asm:YellowIntroPaletteAction; behavior=publishes palette IDs into bg_slot_pal and obj_slot_pal instead of calling InitCGBPalettes, GetCGBBasePalAddress, DMGPalToCGBPal, TransferCurBGPData and SendSGBPacket to build palette RAM and SGB packets; evidence=commit_palette in boot/video.asm already reproduces that whole chain once per frame from the slot tables, so those five routines have no port counterpart by design and the port has never needed them; lifetime=permanent, this is the port's palette-HAL boundary}
; ---------------------------------------------------------------------------
YellowIntroPaletteAction:
    pushad
    test dl, dl                          ; ld a, e / and a
    jnz .pikachusBeach
    ; popad FIRST. This was `mov al, SET_PAL_GENERIC / popad / jmp SetPal_Screen`,
    ; and popad restores EAX — so the command byte was destroyed before it was ever
    ; used and SetPal_Screen ran with the caller's AL, which at this call site is
    ; the palette variant itself, i.e. 0 = SET_PAL_BATTLE_BLACK. Every E == 0 scene
    ; of the Yellow intro therefore loaded command_pal_table[0] = PAL_BLACK in all
    ; four BG and OBJ slots instead of PalPacket_Generic's PAL_MEWMON + PAL_ROUTE x3:
    ; the running Pikachu rendered as a solid black silhouette, and Scene 15's
    ; thunderbolt strobe was invisible because XOR-ing rOBP0/rBGP only reshuffles
    ; colour indices within a palette whose four entries are all black.
    popad
    mov al, SET_PAL_GENERIC              ; ld hl, PalPacket_Generic
    jmp SetPal_Screen
.pikachusBeach:
    ; PalPacket_PikachusBeach is PAL_PIKACHUS_BEACH in all four entries, and
    ; InitCGBPalettes converts each into the BG pal AND both OBJ pals.
    mov al, PAL_PIKACHUS_BEACH
    mov ecx, 4
    mov edi, bg_slot_pal
    rep stosb
    mov ecx, 4
    mov edi, obj_slot_pal
    rep stosb
    ; …then slot 1 takes PalPacket_Generic's palette on BOTH planes, because pret
    ; overrides the shared BASE table (wCGBBasePalPointers + 2) and Func_f9e9a's
    ; UpdateCGBPal_OBP0/OBP1 immediately rebuild the OBJ palettes from it. The OBJ
    ; half is what gives the surfing and balloon Pikachu red cheeks — see the
    ; header for the full chain.
    mov byte [bg_slot_pal + 1], PAL_MEWMON
    mov byte [obj_slot_pal + 1], PAL_MEWMON
    ; No BLK packet is involved, so there is no attribute plane for this scene —
    ; drop any the previous screen left, or it would keep re-resolving.
    mov dword [g_bg_attr_table], 0
    mov byte [g_pal_dirty], 1
    popad
    ret

; Faithful SetPal_Overworld palette choice from pret engine/gfx/palettes.asm.
; The port has no SGB attribute packets, so slot 0 becomes the whole-map band;
; its 2bpp cache remains unchanged except for the normal dirty rebuild.
SetPal_Overworld:
    pushad
    mov al, [ebp + W_CUR_MAP_TILESET]
    cmp al, CEMETERY
    je .gray
    cmp al, CAVERN
    je .cave
    mov al, [ebp + W_CUR_MAP]
    cmp al, FIRST_INDOOR_MAP
    jb .townOrRoute
    cmp al, CERULEAN_CAVE_2F
    jb .lastMap
    cmp al, CERULEAN_CAVE_1F + 1
    jb .cave
    cmp al, LORELEIS_ROOM
    je .route
    cmp al, BRUNOS_ROOM
    je .cave
    cmp al, TRADE_CENTER
    je .gray
    cmp al, COLOSSEUM
    je .gray
.lastMap:
    mov al, [ebp + W_LAST_MAP]
.townOrRoute:
    cmp al, NUM_CITY_MAPS
    jae .route
    inc al                         ; city map id -> PAL_PALLET..PAL_SAFFRON
    jmp .apply
.gray:
    mov al, PAL_GRAYMON
    jmp .apply
.cave:
    mov al, PAL_CAVE
    jmp .apply
.route:
    mov al, PAL_ROUTE
.apply:
    mov dword [g_bg_attr_table], 0   ; the overworld has no attribute plane
    ; pret: CopyData(PalPacket_Empty -> wPalPacket), then `ld hl, wPalPacket + 1 /
    ; ld [hld], a` -- the map's palette goes into ENTRY 0 ONLY. PalPacket_Empty is
    ; PAL_SET 0, 0, 0, 0, so entries 1-3 keep palette id 0 (PAL_ROUTE), and BG
    ; palettes 4-7 are not written by any packet at all.
    ;
    ; This used to flood the map's palette into all eight slots of both tables.
    ; Invisible on screen (tile_pal is all-zero here, so every tile renders
    ; through slot 0) but measurably wrong, and it is what the cgb_palettes
    ; golden region caught first: slots 1-3 read the town palette where hardware
    ; has PAL_ROUTE, and 4-7 kept it forever.
    mov [bg_slot_pal], al
    mov [obj_slot_pal], al
    mov al, PAL_ROUTE                ; PalPacket_Empty's remaining three entries
    mov ecx, NUM_ACTIVE_PALS - 1
    lea edi, [bg_slot_pal + 1]
    rep stosb
    mov ecx, NUM_ACTIVE_PALS - 1
    lea edi, [obj_slot_pal + 1]
    rep stosb
    xor al, al
    mov edi, tile_pal
    mov ecx, 384
    rep stosb
    ; ld a, SET_PAL_OVERWORLD / ld [wDefaultPaletteCommand], a — this is what makes
    ; a later RunDefaultPaletteCommand come back to the MAP's palette.
    mov byte [ebp + wDefaultPaletteCommand], SET_PAL_OVERWORLD
    mov byte [g_tilecache_dirty], 1
    mov byte [g_pal_dirty], 1
    popad
    ret

; Exact pret labels for command-table entries.  They preserve AL's command id
; when reached through _RunPaletteCommand; direct callers receive the proper id.
SetPal_TownMap:                 mov al, SET_PAL_TOWN_MAP                 ; fall through
                                jmp SetPal_Screen
; ---------------------------------------------------------------------------
; SetPal_StatusScreen — pret engine/gfx/palettes.asm:73. NOT a plain screen
; command: pret copies PalPacket_Empty and then overwrites TWO of its four
; palette ids at run time —
;     entry 0 (wPalPacket + 1) = wStatusScreenHPBarColor + PAL_GREENBAR
;     entry 1 (wPalPacket + 3) = DeterminePaletteIDOutOfBattle(wCurPartySpecies)
; so the status screen shows the mon's OWN colours and an HP bar tinted
; green/yellow/red by its remaining HP.
;
; The port used to be `mov al, SET_PAL_STATUS_SCREEN / jmp SetPal_Screen`, i.e.
; the static row only — measured as `faithdiff SetPal_StatusScreen`
; 2 pret / 1 port with ZERO matched, and visible as status_p1 / status_p2's 6
; divergences each (BG pal0/1 and OBJ pal0/1 colour1-2 holding PAL_ROUTE where
; hardware has the HP-bar and species colours). The port already COMPUTED the
; input — status_screen.asm:229 fills wStatusScreenHPBarColor via
; GetHealthBarColor — and then never used it.
;
; SetPal_Screen still runs first: it loads the static row into both slot tables
; AND installs the command's per-cell attribute plane, which pret gets from
; BlkPacket_StatusScreen. Only the two ids are then overridden, matching pret's
; packet exactly. It ends in popad/ret and already arms g_pal_dirty.
;
; NUM_POKEMON_INDEXES is $BE: VICTREEBEL is the last `const` in pret
; constants/pokemon_constants.asm ($BE) and the DEF is `const_value - 1`.
;
; DEVIATION{class=projection; pret=engine/gfx/palettes.asm:SetPal_StatusScreen; behavior=builds the two live palette ids directly into bg_slot_pal and obj_slot_pal after SetPal_Screen instead of copying PalPacket_Empty into wPalPacket and returning HL-DE for the SGB-packet path, so faithdiff shows DROPPED CopyData and ADDED SetPal_Screen; evidence=the port has no wPalPacket-plus-SendSGBPackets stage at all - SetPal_Screen IS the port's realization of a PAL_SET packet plus its BlkPacket attribute plane, and every other SetPal_ command in this file already goes through it, so a wPalPacket copy would write a buffer nothing reads; lifetime=permanent, the port's palette-command boundary}
;
; The DeterminePaletteIDOutOfBattle call is pret's exactly: pret's
; SetPal_StatusScreen calls that entry with the species already in A. Both pret
; entry points now exist in this file (they did not before — see the note at
; DeterminePaletteID), so this no longer reaches the right code under the wrong
; name.
; ---------------------------------------------------------------------------
%define NUM_POKEMON_INDEXES 0xBE
SetPal_StatusScreen:
    mov al, SET_PAL_STATUS_SCREEN
    call SetPal_Screen                  ; static row + attribute plane
    mov al, [ebp + wCurPartySpecies]    ; ld a, [wCurPartySpecies]
    cmp al, NUM_POKEMON_INDEXES + 1     ; cp NUM_POKEMON_INDEXES + 1
    jb .pokemon                         ; jr c, .pokemon
    mov al, 1                           ; ld a, $1 ; not pokemon
.pokemon:
    call DeterminePaletteIDOutOfBattle  ; pret's A-holds-the-species entry
    push eax                            ; pret: push af
    movzx eax, byte [ebp + wStatusScreenHPBarColor]
    add al, PAL_GREENBAR                ; entry 0 = HP-bar tint
    mov [bg_slot_pal + 0], al
    mov [obj_slot_pal + 0], al
    pop eax                             ; pret: pop af
    mov [bg_slot_pal + 1], al           ; entry 1 = the mon's palette
    mov [obj_slot_pal + 1], al
    mov byte [g_pal_dirty], 1
    ret
SetPal_Pokedex:                 mov al, SET_PAL_POKEDEX
                                jmp SetPal_Screen
SetPal_Slots:                   mov al, SET_PAL_SLOTS
                                jmp SetPal_Screen
SetPal_TitleScreen:             mov al, SET_PAL_TITLE_SCREEN
                                jmp SetPal_Screen
SetPal_NidorinoIntro:           mov al, SET_PAL_NIDORINO_INTRO
                                jmp SetPal_Screen
SetPal_Generic:                 mov al, SET_PAL_GENERIC
                                jmp SetPal_Screen
SetPal_PartyMenu:               mov al, SET_PAL_PARTY_MENU
                                jmp SetPal_Screen
SetPal_PokemonWholeScreen:      mov al, SET_PAL_POKEMON_WHOLE_SCREEN
                                jmp SetPal_Screen
                                ; pret SetPal_GameFreakIntro also publishes the
                                ; default as SET_PAL_GENERIC.
SetPal_GameFreakIntro:          mov byte [ebp + wDefaultPaletteCommand], SET_PAL_GENERIC
                                mov al, SET_PAL_GAME_FREAK_INTRO
                                jmp SetPal_Screen
SetPal_TrainerCard:             mov al, SET_PAL_TRAINER_CARD
                                jmp SetPal_Screen
SetPal_PikachusBeach:           mov al, SET_PAL_SURFING_PIKACHU_TITLE
                                jmp SetPal_Screen
SetPal_PikachusBeachTitle:      mov al, SET_PAL_SURFING_PIKACHU_MINIGAME
                                jmp SetPal_Screen

; DeterminePaletteIDOutOfBattle flow (pret palettes.asm): store the index,
; convert via predef IndexToPokedex, then the MonsterPalettes lookup.
; pret has TWO entry points here, two lines apart (engine/gfx/palettes.asm:297):
;     DeterminePaletteID:            ld a, [hl]      <- species FROM MEMORY at HL
;     DeterminePaletteIDOutOfBattle: ld [wPokedexNum], a   <- species already in A
; The port previously had only the second body, carrying the FIRST name — so
; `label_status DeterminePaletteIDOutOfBattle` read `missing` and every caller
; reached the right code under the wrong name. Both pret names now exist with
; pret's structure; callers pick the entry that matches what they hold.
global DeterminePaletteIDOutOfBattle
DeterminePaletteID:
    mov al, [ebp + esi]                 ; ld a, [hl]
DeterminePaletteIDOutOfBattle:
    mov [ebp + wPokedexNum], al         ; ld [wPokedexNum], a
    test al, al                         ; and a — is the mon index 0?
    jz .skipDexNumConversion
    push ebx                            ; push bc
    call IndexToPokedex                 ; predef IndexToPokedex
    pop ebx                             ; pop bc
    mov al, [ebp + wPokedexNum]         ; ld a, [wPokedexNum]
.skipDexNumConversion:
    movzx eax, al                       ; ld e, a / ld d, 0
    mov al, [mon_pal_table + eax]
    ret

section .data
SetPalFunctions:
    dd SetPal_BattleBlack, SetPal_Battle, SetPal_TownMap, SetPal_StatusScreen
    dd SetPal_Pokedex, SetPal_Slots, SetPal_TitleScreen, SetPal_NidorinoIntro
    dd SetPal_Generic, SetPal_Overworld, SetPal_PartyMenu, SetPal_PokemonWholeScreen
    dd SetPal_GameFreakIntro, SetPal_TrainerCard, SetPal_PikachusBeach, SetPal_PikachusBeachTitle
