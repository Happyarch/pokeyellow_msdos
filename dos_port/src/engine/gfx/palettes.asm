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

global _RunPaletteCommand
global SetPalFunctions, SetPal_BattleBlack, SetPal_Battle, DeterminePaletteID
global SetPal_TownMap, SetPal_StatusScreen, SetPal_Pokedex, SetPal_Slots
global SetPal_TitleScreen, SetPal_NidorinoIntro, SetPal_Generic, SetPal_Overworld
global SetPal_PartyMenu, SetPal_PokemonWholeScreen, SetPal_GameFreakIntro
global SetPal_TrainerCard, SetPal_PikachusBeach, SetPal_PikachusBeachTitle

extern IndexToPokedex               ; engine/menus/pokedex.asm — predef, wPokedexNum in place
extern tile_pal, g_tilecache_dirty
extern g_pal_dirty, bg_slot_pal, obj_slot_pal
extern mon_pal_table, battle_slot_pal, battle_tile_pal, command_pal_table
extern RefreshMonFrontRepaintPalette

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
    cmp al, SET_PAL_BATTLE                  ; pret dispatches through SetPalFunctions;
    je SetPal_Battle                        ; SetPal_Battle builds live slots, not a row
    cmp al, SET_PAL_OVERWORLD
    je SetPal_Overworld
    cmp al, SET_PAL_SURFING_PIKACHU_MINIGAME
    ja .done
    jmp SetPal_Screen
.done:
    ret

SetPal_BattleBlack:
    pushad
    mov al, PAL_BLACK
    mov ecx, 8
    mov edi, bg_slot_pal
    rep stosb
    mov ecx, 8
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
    mov al, [ebp + wBattleMonSpecies2]
    call DeterminePaletteID
    mov [bg_slot_pal + 2], al
    mov al, [ebp + wEnemyMonSpecies2]
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
    mov byte [g_tilecache_dirty], 1
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
    mov ecx, 8
    mov edi, bg_slot_pal
    rep stosb
    mov ecx, 8
    mov edi, obj_slot_pal
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
SetPal_StatusScreen:            mov al, SET_PAL_STATUS_SCREEN
                                jmp SetPal_Screen
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
DeterminePaletteID:
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
