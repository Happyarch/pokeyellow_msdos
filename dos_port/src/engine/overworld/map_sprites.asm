; map_sprites.asm — faithful pret engine/overworld/map_sprites.asm (sprite tile loader)
; plus the port's overworld NPC interaction stack.
;
; Split of responsibilities (mirrors pret's file layout — OW-A.2 P3c de-bespoke):
;   * Slot population (PICTUREID/MAPY/MAPX/MOVEMENTBYTE1/2 + wMapSpriteData +
;     wMapSpriteExtraData) is the home object-loader InitSprites, in overworld.asm
;     (called from LoadMapHeader). NOT here.
;   * This file is the sprite-set tile loader, entered via InitMapSprites (wrapper)
;     -> _InitMapSprites (from LoadMapData / .mapTransition / post-text reload):
;       InitOutsideMapSprites (fixed set per outdoor map, via GetSplitMapSpriteSetID)
;       / LoadSpriteSetFromMapHeader (indoor set from the slots' picture IDs) ->
;       LoadMapSpriteTilePatterns (SpriteSheetPointerTable -> VRAM) ->
;       LoadMapSpritesImageBaseOffset (per-slot IMAGEBASEOFFSET = set index + 2).
;   * wFontLoaded gates the upper-half (walk-tile) reload: LoadStillTilePattern skips
;     the lower half while text is loaded; ReloadWalkingTilePatterns reloads only the
;     walk tiles after a menu/dialog overwrites the shared vFont region.
;
; Port extensions kept here (; DIVERGENCE): the toggleable-hidden object gate and the
; overworld interaction stack (CheckNPCInteraction / IsNPCAtTargetBlock /
; CheckTrainerSight / TrainerEncounterFlow / ShowTextStream); pret's
; IsSpriteOrSignInFrontOfPlayer path is unported.
;
; Build: nasm -f coff -I include/ -I . -o map_sprites.o src/engine/overworld/map_sprites.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "assets/event_constants.inc"
%include "events.inc"

extern msgbox_dialog                    ; src/home/text.asm — overworld dialog projection
extern text_msgbox                      ; src/home/text.asm — active msgbox projection (msgbox.inc)
extern g_tilecache_dirty
extern set_single_window     ; src/ppu/ppu.asm — define g_windows[] as one descriptor
extern hide_window           ; src/ppu/ppu.asm — empty the window list (count=0)
extern PrintTextStaged
extern DelayFrame
extern LoadCurrentMapView
extern MakeNPCFacePlayer
extern LoadFontTilePatterns
extern LoadPlayerSpriteGraphics
extern HandleDownArrowBlinkTiming

global InitMapSprites            ; home wrapper (pret name kept); reload sprite tiles after text
; Faithful pret engine/overworld/map_sprites.asm routines (OW-A.2 P3c de-bespoke):
global _InitMapSprites
global InitOutsideMapSprites
global GetSplitMapSpriteSetID
global LoadSpriteSetFromMapHeader
global CheckIfPictureIDAlreadyLoaded
global CheckForFourTileSprite
global LoadMapSpriteTilePatterns
global ReloadWalkingTilePatterns  ; also the post-menu/post-text walk-tile reload
global LoadStillTilePattern
global LoadWalkingTilePattern
global GetSpriteVRAMAddress
global ReadSpriteSheetData
global LoadMapSpritesImageBaseOffset
global GetSpriteImageBaseOffset
global ResetMapTrainerState        ; port-ext per-map-load trainer state (called by wrapper)
global g_toggleable_flags          ; flat .bss event flags — toggleable_objects.asm Show/HideObject bts/btr it (OW-7.2)
global CheckNPCInteraction
global ShowTextStream
global IsNPCAtTargetBlock
global w_map_text_table_ptr
global MapTextTablePointers
global CheckTrainerSight
global TrainerEncounterFlow
global InitToggleableObjectFlags
global IsToggleableHidden
global wMapSpriteExtraData       ; M8.1: per-NPC [class,set] cache (pret wMapSpriteExtraData)
global wMapSpriteData            ; OW-A.2: [movement byte 2, masked text id] per slot (pret wMapSpriteData)

; M8.1 sight->battle wiring — the trainer battle-entry these overworld routines call.
; StartTrainerBattle seeds wCurOpponent/wTrainerClass/wTrainerNo from the engaged
; trainer's cached class/set (and, under -D TRAINER_BATTLE_LIVE, calls InitBattle).
extern StartTrainerBattle
%ifdef TRAINER_BATTLE_LIVE
extern EndTrainerBattle
%endif

; ---------------------------------------------------------------------------
; Constants
; ---------------------------------------------------------------------------
TILE_SPC        equ 0x7F               ; blank/space tile (shared with text.asm)
NPC_SLOTS_MAX   equ 15                  ; max NPC slots (sizes wMapSpriteExtraData)

; ---------------------------------------------------------------------------
; BSS — per-map sprite deduplication table (reset at each InitMapSprites call)
; ---------------------------------------------------------------------------
section .bss
; OW-A.2 P3c: the bespoke dedup tables (npc_sprite_set / npc_vram_slots) are retired —
; the faithful loader uses wSpriteSet (WRAM) + the SpriteSheetPointerTable instead.
h_vram_slot:          resb 1                 ; pret hVRAMSlot (HRAM loop temp): current VRAM tile-pattern slot
w_map_text_table_ptr: resd 1                 ; flat ptr to current map's TextTable (set by EnterMap)
; TODO-GLOBAL-EVENTS: npc_beaten_flags resets per InitMapSprites (per map load).
; Replace with a persistent global wEventFlags bit array when the event system is
; implemented so trainers stay beaten across map warps.
npc_beaten_flags:     resw 1   ; bit N-1 = NPC slot N beaten; cleared in InitMapSprites
w_trainer_enc_slot:   resb 1   ; engaging trainer slot byte-offset (0xFF = none)
w_player_frozen:      resb 1   ; 1 = block player input during encounter flow

; wMapSpriteExtraData — port equivalent of pret wMapSpriteExtraData
; (ram/wram.asm: "trainer class/item ID, trainer set ID", MAX_OBJECT_EVENTS*2).
; Two bytes per NPC slot 1-15: [class, set].  For a trainer NPC, class holds the
; OPP_* value (>= OPP_ID_OFFSET) and set holds the trainer party set index; both
; are copied straight from the map-object binary by InitMapSprites (which used to
; DISCARD them).  Index for slot N (1-15) = (N-1)*2.  Cleared per map load.
; TODO(M8.2): pret's EngageMapTrainer reads this array via wSpriteIndex; the M8.1
; inline engage in TrainerEncounterFlow reads it directly until EngageMapTrainer lands.
wMapSpriteExtraData:  resb NPC_SLOTS_MAX * 2

; wMapSpriteData — pret wMapSpriteData (home/overworld.asm:LoadSprite).  Two bytes per
; slot: [movement byte 2 (dir constraint), masked text id].  Index for slot N (1-15) =
; (N-1)*2.  OW-A.2 P2 relocated these off the pret-unused SPRITESTATEDATA2 struct bytes
; 0x1/0x0A (where the bespoke loader had stashed them) into this faithful array.
wMapSpriteData:       resb MAX_OBJECT_EVENTS * 2

; Global toggleable-object (event) flags — pret's wToggleableObjectFlags.  Bit g set
; (LSB-first) => toggleable object g is hidden.  Persistent across map loads; seeded
; once from toggleable_default_flags by InitToggleableObjectFlags at game start.
; Sized 64 B (TOGGLEABLE_FLAG_BYTES is ~30) so a dword-width `bt` near the end never
; reads past the array.
g_toggleable_flags:   resb 64

; ---------------------------------------------------------------------------
; Sprite-set tables, sprite tile sheets, and dialog text tables (section .data so
; the flat DS-relative pointers in SpriteSheetPointerTable resolve correctly).
; ---------------------------------------------------------------------------
section .data

; OW-A.2 P3c: the faithful sprite-set machinery replaces the bespoke
; npc_sprite_data_table (sprite_id-indexed) with pret's two-level lookup:
;   sprite_sets.inc           — MapSpriteSets / SplitMapSpriteSets / SpriteSets
;                               (which fixed sprite set an outdoor map uses).
;   sprite_sheet_pointers.inc — SpriteSheetPointerTable, indexed (sprite_id-1):
;                               dd flat_ptr, dd tilecount; %includes its own sheets.
; Both generated by tools/gen_all_assets.py / gen_sprite_sets.py — do NOT hand-edit.
%include "assets/sprite_sets.inc"
%include "assets/sprite_sheet_pointers.inc"

; SpriteVRAMAddresses — GB VRAM tile-pattern-slot offsets, indexed by hVRAMSlot (0-10).
; Faithful to pret data/sprites (SpriteVRAMAddresses): slot i (i<10) = vChars0 +
; (i+1)*12 tiles; the two 4-tile "still" slots (9,10) share the 10th 12-tile block.
; Geometry is arithmetically identical to the port renderer: VRAM for imageBaseOffset
; N = $8000 + (N-1)*192, and imageBaseOffset = set index + 2. Walk tiles go to the
; same offset + $800 (= GB_VFONT region), as pret's `set 3, h`.
SpriteVRAMAddresses:
    dw GB_VCHARS0 + 1 * 192
    dw GB_VCHARS0 + 2 * 192
    dw GB_VCHARS0 + 3 * 192
    dw GB_VCHARS0 + 4 * 192
    dw GB_VCHARS0 + 5 * 192
    dw GB_VCHARS0 + 6 * 192
    dw GB_VCHARS0 + 7 * 192
    dw GB_VCHARS0 + 8 * 192
    dw GB_VCHARS0 + 9 * 192
    dw GB_VCHARS0 + 10 * 192          ; 4-tile sprite slot 9
    dw GB_VCHARS0 + 10 * 192 + 4 * 16 ; 4-tile sprite slot 10

; NPC dialog streams — per-map text tables + MapTextTablePointers dispatch.
; Generated by tools/gen_npc_dialogs.py — do NOT edit these files.
%include "assets/npc_dialogs/all_dialogs.inc"

; Toggleable-object (event) flag defaults + per-map gating lists.
; Defines toggleable_default_flags, TOGGLEABLE_FLAG_BYTES, toggle_list_*,
; and ToggleableMapPointers.  Generated by tools/gen_toggleable_objects.py.
%include "assets/toggleable_objects.inc"

; ---------------------------------------------------------------------------
; Code
; ---------------------------------------------------------------------------
section .text

; ---------------------------------------------------------------------------
; OW-A.2 P3c — faithful sprite-set tile loader (pret engine/overworld/map_sprites.asm).
;
; The bespoke InitMapSprites (which FUSED slot-population, dynamic VRAM-slot
; assignment via FindOrAssignVramSlot, and tile-load) is retired. Slot population
; is now the home object-loader InitSprites (overworld.asm, from LoadMapHeader);
; this file provides the tile-pattern loader (from LoadMapData / .mapTransition /
; post-text reload), which mirrors pret's file split exactly.
;
; pret has FIRST_INDOOR_MAP; the port's gb_memmap.inc names it FIRST_INDOOR_MAP_ID.
%ifndef FIRST_INDOOR_MAP
FIRST_INDOOR_MAP equ FIRST_INDOOR_MAP_ID
%endif
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; InitMapSprites — home wrapper (pret name; extern'd by overworld.asm + text_script.asm).
; Runs the port-extension per-map bookkeeping, then the faithful _InitMapSprites.
; All registers preserved (pushad/popad).
; ---------------------------------------------------------------------------
InitMapSprites:
    pushad
    ; DIVERGENCE (port ext): reset the per-map trainer/interaction state. Kept here
    ; (not in InitSprites) so it fires on exactly the paths the bespoke reset did —
    ; map load + .mapTransition + post-text InitMapSprites — but NOT on the interaction
    ; stack's post-dialog reload (that path calls ReloadWalkingTilePatterns, not this).
    call ResetMapTrainerState
    ; DIVERGENCE (port ext): hide toggleable-hidden objects before the sprite-set /
    ; imageBaseOffset passes read PICTUREIDs, so a hidden object never gets a VRAM slot.
    call ApplyToggleableHiddenGate
    call _InitMapSprites
    popad
    ret

; ResetMapTrainerState (port ext) — zero the per-map interaction bookkeeping.
; Also called by InitSprites is NOT done; only the InitMapSprites wrapper calls it.
ResetMapTrainerState:
    mov word [npc_beaten_flags], 0
    mov byte [w_trainer_enc_slot], 0xFF
    mov byte [w_player_frozen], 0
    ret

; ApplyToggleableHiddenGate (port ext) — for each populated NPC slot (1-14) whose
; toggleable object is currently hidden, zero its PICTUREID so _InitMapSprites skips
; it. Mirrors the bespoke loader's inline gate. IsToggleableHidden clobbers AL only.
ApplyToggleableHiddenGate:
    push eax
    push esi
    mov esi, 0x10                       ; slot 1
.loop:
    cmp esi, 0xF0                       ; stop after slot 14 (slot 15 = Pikachu)
    jae .done
    movzx eax, byte [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_PICTUREID]
    test al, al
    jz .next                           ; unused slot
    mov eax, esi
    shr eax, 4                          ; slot number (1-14)
    dec eax                             ; local object id (0-based)
    call IsToggleableHidden            ; CF=1 if hidden; preserves ESI
    jnc .next
    mov byte [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_PICTUREID], 0
.next:
    add esi, 0x10
    jmp .loop
.done:
    pop esi
    pop eax
    ret

; ---------------------------------------------------------------------------
; _InitMapSprites — pret engine/overworld/map_sprites.asm:_InitMapSprites.
; Outside maps are fully handled by InitOutsideMapSprites (fixed sprite set); inside
; maps build the set from the map header's sprites, then load tiles + imageBaseOffset.
; ---------------------------------------------------------------------------
_InitMapSprites:
    call InitOutsideMapSprites
    jc .done                           ; outside map handled (CF=1)
    call LoadSpriteSetFromMapHeader
    call LoadMapSpriteTilePatterns
    call LoadMapSpritesImageBaseOffset
.done:
    ret

; ---------------------------------------------------------------------------
; InitOutsideMapSprites — pret. For cities/routes, choose the fixed sprite set and
; load it. Out: CF=1 if the map is a city/route (handled here), CF=0 if indoor.
; ---------------------------------------------------------------------------
InitOutsideMapSprites:
    mov al, [ebp + W_CUR_MAP]
    cmp al, FIRST_INDOOR_MAP
    jae .inside                        ; indoor map → not handled here (CF=0)
    call GetSplitMapSpriteSetID         ; AL = spriteSetID (input AL = wCurMap)
    mov bl, al                          ; B = spriteSetID
    test byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    jnz .loadSet                        ; reloading upper half after text → force reload
    mov al, [ebp + W_SPRITE_SET_ID]
    cmp al, bl
    je .skipLoad                        ; sprite set unchanged → don't reload it
.loadSet:
    mov [ebp + W_SPRITE_SET_ID], bl
    ; wSpriteSet = SpriteSets[spriteSetID - 1] (SPRITE_SET_LENGTH bytes).
    ; pret: AddNTimes + CopyData; flat port equivalent is imul + rep movsb.
    movzx eax, bl
    dec eax
    imul eax, eax, SPRITE_SET_LENGTH
    lea esi, [SpriteSets + eax]
    lea edi, [ebp + W_SPRITE_SET]
    mov ecx, SPRITE_SET_LENGTH
    rep movsb
    call LoadMapSpriteTilePatterns
.skipLoad:
    call LoadMapSpritesImageBaseOffset
    stc                                 ; city/route handled
    ret
.inside:
    clc
    ret

; ---------------------------------------------------------------------------
; GetSplitMapSpriteSetID — pret. In: AL = wCurMap. Out: AL = spriteSetID, resolving
; two-set (split) maps by the player's position. Preserves nothing needed by caller.
; ---------------------------------------------------------------------------
GetSplitMapSpriteSetID:
    movzx eax, al
    mov al, [MapSpriteSets + eax]       ; sprite set id, or a split-set marker
    cmp al, FIRST_SPLIT_SET - 1         ; single set?
    jb .single                          ; AL < 0xF0 → single (CF=1)
    cmp al, SPLITSET_ROUTE_20
    je .route20                         ; Route 20 is a special-shaped split
    ; row = SplitMapSpriteSets + ((setmarker & 0x0f) - 1) * 4
    and al, 0x0F
    dec al
    add al, al
    add al, al                          ; * 4
    movzx eax, al
    lea edx, [SplitMapSpriteSets + eax]
    mov al, [edx]                       ; #1 divide direction (EAST_WEST / NORTH_SOUTH)
    mov ah, [edx + 1]                   ; #2 dividing-line coordinate
    cmp al, EAST_WEST
    je .eastWest
.northSouth:
    mov al, [ebp + W_Y_COORD]
    jmp .compare
.eastWest:
    mov al, [ebp + W_X_COORD]
.compare:
    cmp al, ah                          ; coord < divide → west/north side
    jb .westNorth
    mov al, [edx + 3]                   ; #4 east/south side sprite set
    ret
.westNorth:
    mov al, [edx + 2]                   ; #3 west/north side sprite set
    ret
.route20:
    mov al, [ebp + W_X_COORD]
    cmp al, 43
    jb .r20_pv                          ; X < 43 → PALLET_VIRIDIAN
    cmp al, 62
    jae .r20_fu                         ; X >= 62 → FUCHSIA
    cmp al, 55
    jae .r20_y8                         ; 55 <= X < 62 → split Y at 8
    mov ah, 13                          ; 43 <= X < 55 → split Y at 13
    jmp .r20_ycmp
.r20_y8:
    mov ah, 8
.r20_ycmp:
    mov al, [ebp + W_Y_COORD]
    cmp al, ah
    jb .r20_fu                          ; Y < split → FUCHSIA
.r20_pv:
    mov al, SPRITESET_PALLET_VIRIDIAN
    ret
.r20_fu:
    mov al, SPRITESET_FUCHSIA
    ret
.single:
    ret                                 ; AL already = spriteSetID

; ---------------------------------------------------------------------------
; LoadSpriteSetFromMapHeader — pret. For indoor maps: build wSpriteSet from the
; picture IDs in the populated sprite slots (Pikachu reserved in slot 0). Each
; slot's VRAM tile-pattern slot is its picture ID's index within wSpriteSet.
; ---------------------------------------------------------------------------
LoadSpriteSetFromMapHeader:
    lea edi, [ebp + W_SPRITE_SET]
    xor al, al
    mov ecx, SPRITE_SET_LENGTH
    rep stosb                           ; zero wSpriteSet
    mov byte [ebp + W_SPRITE_SET], SPRITE_PIKACHU   ; Pikachu loaded separately (slot 0)
    mov esi, 0x10                       ; slot 1
    mov ebx, 14
.loop:
    movzx eax, byte [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_PICTUREID]
    test al, al
    jz .continue                        ; slot not used
    mov cl, al                          ; C = picture id
    call CheckForFourTileSprite         ; CF=1 if four-tile sprite; preserves CL/ESI/EBX
    jnc .notFourTile
    mov edi, W_SPRITE_SET + 9            ; four-tile picture IDs live in the last 2 entries
    mov edx, 2
    call CheckIfPictureIDAlreadyLoaded
    jmp .continue
.notFourTile:
    mov edi, W_SPRITE_SET               ; regular picture IDs use the first 9 entries
    mov edx, 9
    call CheckIfPictureIDAlreadyLoaded
.continue:
    add esi, 0x10
    dec ebx
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; CheckIfPictureIDAlreadyLoaded — pret. Scan a region of wSpriteSet for picture id
; CL; if absent, store it in the first empty entry. In: EDI = GB offset of the
; scan start, EDX = max entries, CL = picture id. Clobbers EAX/EDX/EDI. (The pret
; scf/carry return is vestigial — callers ignore it — so it is dropped here.)
; ---------------------------------------------------------------------------
CheckIfPictureIDAlreadyLoaded:
.loop:
    mov al, [ebp + edi]
    test al, al
    jz .notTaken                        ; empty entry → end of set → store here
    cmp al, cl
    je .done                            ; already loaded → don't duplicate
    dec edx
    jz .done                            ; reached end of the reserved region
    inc edi
    jmp .loop
.notTaken:
    mov [ebp + edi], cl
.done:
    ret

; ---------------------------------------------------------------------------
; CheckForFourTileSprite — pret. In: AL = picture id. Out: CF=1 if the sprite uses
; 4 tiles (a Yellow "still" sprite); CF=0 for a regular sprite OR Pikachu (Pikachu
; is loaded separately). Preserves AL/CL/ESI/EBX (cmp only).
; ---------------------------------------------------------------------------
CheckForFourTileSprite:
    cmp al, SPRITE_PIKACHU
    je .pikachu                         ; Pikachu → CF=0 (handled separately)
    cmp al, FIRST_STILL_SPRITE
    jae .fourTile                       ; >= FIRST_STILL_SPRITE → four-tile
    clc                                 ; regular sprite
    ret
.fourTile:
    stc
    ret
.pikachu:
    clc
    ret

; ---------------------------------------------------------------------------
; LoadMapSpriteTilePatterns — pret. Load tiles for each of the 11 wSpriteSet slots:
; slots 0-8 load still + walking tiles; the two 4-tile slots (9,10) load still only.
; ---------------------------------------------------------------------------
LoadMapSpriteTilePatterns:
    mov byte [h_vram_slot], 0
.loop:
    cmp byte [h_vram_slot], 9
    jae .fourTile
    call LoadStillTilePattern
    call LoadWalkingTilePattern
    jmp .cont
.fourTile:
    call LoadStillTilePattern
.cont:
    inc byte [h_vram_slot]
    cmp byte [h_vram_slot], 11
    jne .loop
    ret

; ---------------------------------------------------------------------------
; ReloadWalkingTilePatterns — pret. Reload just the walking tiles for slots 0-8.
; Also the port's post-menu / post-dialog walk-tile reload (the font/menu overwrites
; the vFont upper half that the walk tiles share).
; ---------------------------------------------------------------------------
ReloadWalkingTilePatterns:
    mov byte [h_vram_slot], 0
.loop:
    cmp byte [h_vram_slot], 9
    jae .skip
    call LoadWalkingTilePattern
.skip:
    inc byte [h_vram_slot]
    cmp byte [h_vram_slot], 11
    jne .loop
    ret

; ---------------------------------------------------------------------------
; LoadStillTilePattern — pret. Copy the 12 (or 4) still tiles for the current
; wSpriteSet slot into vChars0. Skipped when the font is loaded (that only clobbers
; the upper/walk half, so the lower/still half must not be reloaded over live text).
; ---------------------------------------------------------------------------
LoadStillTilePattern:
    test byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    jnz .skip                          ; font loaded → don't reload the lower half
    call ReadSpriteSheetData            ; EDX = flat src, ECX = tile count, CF=1 if used
    jnc .skip
    push esi
    push edi
    push ecx
    call GetSpriteVRAMAddress           ; EAX = VRAM tile-pattern offset
    mov esi, edx                        ; still tiles are at src + 0
    lea edi, [ebp + eax]
    shl ecx, 4                          ; tiles → bytes (* TILE_SIZE)
    rep movsb                           ; DIVERGENCE: flat copy replaces CopyVideoDataAlternate
    mov byte [g_tilecache_dirty], 1
    pop ecx
    pop edi
    pop esi
.skip:
    ret

; ---------------------------------------------------------------------------
; LoadWalkingTilePattern — pret. Copy the 12 walking tiles (source + $c0) for the
; current slot into the vFont upper half (VRAM offset + $800 = pret `set 3, h`).
; ---------------------------------------------------------------------------
LoadWalkingTilePattern:
    call ReadSpriteSheetData            ; EDX = flat src, ECX = tile count, CF=1 if used
    jnc .skip
    push esi
    push edi
    push ecx
    call GetSpriteVRAMAddress           ; EAX = VRAM tile-pattern offset
    lea esi, [edx + 0xC0]               ; walking tiles are at src + $c0
    lea edi, [ebp + eax + 0x800]        ; + $800 → vFont upper half
    shl ecx, 4
    rep movsb
    mov byte [g_tilecache_dirty], 1
    pop ecx
    pop edi
    pop esi
.skip:
    ret

; ---------------------------------------------------------------------------
; GetSpriteVRAMAddress — pret. Out: EAX = SpriteVRAMAddresses[hVRAMSlot] (a GB VRAM
; offset; use as [EBP + EAX]). Preserves other registers.
; ---------------------------------------------------------------------------
GetSpriteVRAMAddress:
    push edx
    movzx edx, byte [h_vram_slot]
    movzx eax, word [SpriteVRAMAddresses + edx * 2]
    pop edx
    ret

; ---------------------------------------------------------------------------
; ReadSpriteSheetData — pret. Look up the sheet for the current wSpriteSet slot.
; Out: CF=0 if the slot is unused; else CF=1, EDX = flat sheet pointer, ECX = tile
; count. Index into SpriteSheetPointerTable is (picture id - 1) (pret `dec a`).
; ---------------------------------------------------------------------------
ReadSpriteSheetData:
    movzx eax, byte [h_vram_slot]
    movzx eax, byte [ebp + W_SPRITE_SET + eax]   ; picture id in this VRAM slot
    test al, al
    jz .none
    dec eax                             ; (picture id - 1)
    mov edx, eax
    shl edx, 3                          ; * 8 bytes per SpriteSheetPointerTable entry
    mov ecx, [SpriteSheetPointerTable + edx + 4] ; tile count
    mov edx, [SpriteSheetPointerTable + edx]     ; flat sheet pointer
    stc
    ret
.none:
    clc
    ret

; ---------------------------------------------------------------------------
; LoadMapSpritesImageBaseOffset — pret. Assign each sprite slot's IMAGEBASEOFFSET:
; player = 1, Pikachu (slot 15) = 2, and each NPC slot = its picture id's index
; within wSpriteSet + 2 (via GetSpriteImageBaseOffset).
; ---------------------------------------------------------------------------
LoadMapSpritesImageBaseOffset:
    mov byte [ebp + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_IMAGEBASEOFFSET], 1        ; player (slot 0)
    mov byte [ebp + 0xF0 + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_IMAGEBASEOFFSET], 2 ; Pikachu (slot 15)
    mov esi, 0x10                       ; slot 1
    mov ecx, 14
.loop:
    movzx eax, byte [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_PICTUREID]
    test al, al
    jz .skip                            ; unused slot
    call GetSpriteImageBaseOffset       ; AL = imageBaseOffset; preserves ESI/ECX
    mov [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_IMAGEBASEOFFSET], al
.skip:
    add esi, 0x10
    dec ecx
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; GetSpriteImageBaseOffset — pret. In: AL = picture id. Out: AL = its index within
; wSpriteSet + 2 (imageBaseOffset), or 1 if not found. Preserves EBX/ECX/EDI/ESI.
; ---------------------------------------------------------------------------
GetSpriteImageBaseOffset:
    push ebx
    push ecx
    push edi
    mov cl, al                          ; C = picture id
    mov ebx, 11                         ; B = number of wSpriteSet entries
    mov edi, W_SPRITE_SET
.find:
    mov al, [ebp + edi]
    cmp al, cl
    je .found
    inc edi
    dec ebx
    jnz .find
    mov al, 1                           ; not found → assume slot one
    jmp .done
.found:
    mov al, 13
    sub al, bl                          ; imageBaseOffset = 13 - B
.done:
    pop edi
    pop ecx
    pop ebx
    ret


; ---------------------------------------------------------------------------
; InitToggleableObjectFlags — seed global event/visibility flags to defaults.
; Pret ref: engine/overworld/toggleable_objects.asm:InitializeToggleableObjectsFlags.
;
; Called once at game start (EnterMap, before the first LoadMapData) so default-
; hidden objects (e.g. Oak in Pallet Town) do not spawn.  Also clears the general
; wEventFlags region — its new-game default is all-zero; explicit so a non-zeroed
; DPMI allocation can't leak stale event bits.
;
; TODO-GLOBAL-EVENTS: when the save / script engine lands, move this to the real
; new-game init and let scripts toggle g_toggleable_flags / wEventFlags at runtime.
; All registers preserved.
; ---------------------------------------------------------------------------
InitToggleableObjectFlags:
    push eax
    push ecx
    push esi
    push edi

    ; Copy default-hidden bitmap into the persistent flag array.
    mov esi, toggleable_default_flags   ; flat .data source
    mov edi, g_toggleable_flags         ; flat .bss dest
    mov ecx, TOGGLEABLE_FLAG_BYTES
    rep movsb

    ; Clear the general event-flag region (wEventFlags, NUM_EVENTS bits ≈ 0x140 B).
    lea edi, [ebp + W_EVENT_FLAGS]
    xor al, al
    mov ecx, 0x140
    rep stosb

%ifdef DEBUG_OAK_EVENT
    ; Test harness: force the event that PalletTownOakText gates on so the "set"
    ; branch ("OAK: That was close!") shows instead of the default "Hey! Wait!".
    SetEvent EVENT_GOT_POKEBALLS_FROM_OAK
%endif

    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; IsToggleableHidden — is the given object on the current map hidden by default?
; Pret ref: engine/overworld/toggleable_objects.asm:IsObjectHidden.
;
; In:  AL = local object id (0-based slot index, = text_id).
;      [EBP + W_CUR_MAP] = current map id.
; Out: CF = 1 if the object is a toggleable that is currently flagged hidden.
; Clobbers: AL only (EBX/ECX/EDX/ESI preserved for the InitMapSprites caller).
; ---------------------------------------------------------------------------
IsToggleableHidden:
    push ebx
    push ecx
    push edx
    push esi

    movzx ebx, al                       ; BL = local object id to find
    movzx eax, byte [ebp + W_CUR_MAP]
    mov esi, [ToggleableMapPointers + eax*4]  ; flat ptr to this map's list (0 = none)
    test esi, esi
    jz .not_hidden

.scan:
    movzx eax, byte [esi]               ; runtime_slot (0xFF = end of list)
    cmp al, 0xFF
    je .not_hidden
    cmp al, bl
    je .match
    add esi, 2                          ; next (slot, global_index) pair
    jmp .scan

.match:
    movzx ecx, byte [esi + 1]           ; global toggleable index
    bt [g_toggleable_flags], ecx        ; CF = hidden bit
    jc .hidden

.not_hidden:
    pop esi
    pop edx
    pop ecx
    pop ebx
    clc
    ret

.hidden:
    pop esi
    pop edx
    pop ecx
    pop ebx
    stc
    ret

; ---------------------------------------------------------------------------
; IsNPCAtTargetBlock — test if any NPC occupies the block directly in front of the player.
;
; Pret ref: home/overworld.asm:IsSpriteOrSignInFrontOfPlayer (scan loop only).
;
; Same MAPY/MAPX scan as CheckNPCInteraction.  Used by CollisionCheckOnLand to
; block the player from walking into an NPC's tile.
;
; In:  EBP = GB memory base; reads W_Y_COORD, W_X_COORD, W_SPRITE_PLAYER_FACING_DIR.
; Out: CF=1 if an NPC was found in the facing tile; CF=0 if the tile is clear.
; Preserves: all registers (push/pops EAX, EBX, ECX, ESI internally).
; ---------------------------------------------------------------------------
IsNPCAtTargetBlock:
    push eax
    push ebx
    push ecx
    push esi

    movzx ebx, byte [ebp + W_Y_COORD]
    add bl, 4                               ; BL = target MAPY (player block + MAPY bias)
    movzx ecx, byte [ebp + W_X_COORD]
    add cl, 4                               ; CL = target MAPX

    movzx eax, byte [ebp + W_SPRITE_PLAYER_FACING_DIR]
    cmp al, SPRITE_FACING_UP
    je .face_up
    cmp al, SPRITE_FACING_DOWN
    je .face_down
    cmp al, SPRITE_FACING_LEFT
    je .face_left
    inc cl                                  ; right: MAPX + 1
    jmp .scan
.face_up:
    dec bl                                  ; up:    MAPY - 1
    jmp .scan
.face_down:
    inc bl                                  ; down:  MAPY + 1
    jmp .scan
.face_left:
    dec cl                                  ; left:  MAPX - 1

.scan:
    mov esi, 0x10                           ; start at NPC slot 1
.slot_loop:
    cmp esi, 0x100
    jge .not_found
    movzx eax, byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_IMAGEBASEOFFSET]
    test al, al
    jz .next_slot                           ; inactive slot
    movzx eax, byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPY]
    cmp al, bl
    jne .next_slot
    movzx eax, byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPX]
    cmp al, cl
    je .found
.next_slot:
    add esi, 0x10
    jmp .slot_loop
.found:
    pop esi
    pop ecx
    pop ebx
    pop eax
    stc
    ret
.not_found:
    pop esi
    pop ecx
    pop ebx
    pop eax
    clc
    ret

; ---------------------------------------------------------------------------
; CheckNPCInteraction — check if an NPC is one block in front of the player;
; if so, make it face the player, copy its dialog to WRAM, and run PrintText.
;
; Pret ref: home/overworld.asm:IsSpriteOrSignInFrontOfPlayer (block-coord variant).
; Called from OverworldLoop when A is pressed and W_WALK_COUNTER == 0.
;
; Detection: NPC in front iff (MAPY - 4) == W_Y_COORD + dy
;                         AND (MAPX - 4) == W_X_COORD + dx
; where (dy,dx) = (-1,0) SPRITE_FACING_UP, (+1,0) DOWN, (0,-1) LEFT, (0,+1) RIGHT.
;
; Text data from PalletTownTextTable (flat .data ptr + size) is copied to
; NPC_DIALOG_BUF in WRAM (EBP-relative). PrintText reads the TX stream from there.
;
; After PrintText (or on CHAR_DONE within PrintText), the window is already shown
; at H_WY=152 by manual_text_scroll. This function hides the window (H_WY=200),
; restores the BG, and returns AL=1 (NPC found) or AL=0 (nothing found).
;
; All registers preserved (pushad/popad). Returns AL in EAX after popad.
; ---------------------------------------------------------------------------
; Dialog-box Y constants (wTileMap rows 12-17 → GB_TILEMAP1 rows 0-5, WY=152 in 320×200).
DIALOG_TILEMAP_ROW      equ 12
DIALOG_TILEMAP_ROWS     equ 6

CheckNPCInteraction:
    pushad

    ; Compute target block coordinates from player facing direction.
    ; W_Y_COORD and W_X_COORD are raw block coords; MAPY/MAPX are raw+4.
    ; Target MAPY = W_Y_COORD + 4 + dy; target MAPX = W_X_COORD + 4 + dx.
    movzx ebx, byte [ebp + W_Y_COORD]
    add bl, 4                               ; adjust for MAPY offset (+4)
    movzx ecx, byte [ebp + W_X_COORD]
    add cl, 4                               ; adjust for MAPX offset (+4)

    movzx eax, byte [ebp + W_SPRITE_PLAYER_FACING_DIR]
    cmp al, SPRITE_FACING_UP
    je .face_up
    cmp al, SPRITE_FACING_DOWN
    je .face_down
    cmp al, SPRITE_FACING_LEFT
    je .face_left
    ; SPRITE_FACING_RIGHT (0x0C) or default
    inc cl                                  ; MAPX + 1 (block to the right)
    jmp .scan
.face_up:
    dec bl                                  ; MAPY - 1 (block to the north)
    jmp .scan
.face_down:
    inc bl                                  ; MAPY + 1 (block to the south)
    jmp .scan
.face_left:
    dec cl                                  ; MAPX - 1 (block to the west)

.scan:
    ; BL = target_mapy, CL = target_mapx
    ; Scan NPC slots 1-15 (slot 0 = player).
    mov esi, 0x10                           ; slot byte offset starts at slot 1

.slot_loop:
    cmp esi, 0x100
    jge .not_found

    ; Skip inactive slots (IMAGEBASEOFFSET == 0 means slot is unused).
    movzx eax, byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_IMAGEBASEOFFSET]
    test al, al
    jz .next_slot

    ; Compare MAPY and MAPX.
    movzx eax, byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPY]
    cmp al, bl
    jne .next_slot
    movzx eax, byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPX]
    cmp al, cl
    je .found_npc
.next_slot:
    add esi, 0x10
    jmp .slot_loop

.found_npc:
    ; ── Found: NPC at target block ──────────────────────────────────────────

    ; Beaten-trainer gate: if this is a trainer whose beaten bit is set, return 0.
    cmp byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_ISTRAINER], 0
    je .not_beaten_trainer
    mov edx, esi
    shr dl, 4                           ; slot number (1-15)
    dec dl                              ; bit index (0-14)
    bt word [npc_beaten_flags], dx      ; CF=1 if beaten
    jc .not_found                       ; beaten → no re-talk
.not_beaten_trainer:

    ; Set H_TILE_PLAYER_STANDING_ON so UpdateSpriteImage picks this NPC's VRAM slot.
    ; UpdateSprites leaves H_TILE_PLAYER_STANDING_ON = last-slot value after the loop;
    ; that would cause the wrong sprite tiles (e.g. Fisher's) for any earlier NPC.
    movzx eax, byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_IMAGEBASEOFFSET]
    dec al
    ror al, 4                           ; (imageBaseOffset-1)*16 → high nibble for UpdateSpriteImage
    mov [ebp + H_TILE_PLAYER_STANDING_ON], al

    ; Make NPC face player (sets facing, clears BIT_FACE_PLAYER, refreshes image).
    call MakeNPCFacePlayer

    ; Freeze NPC movement during dialog.
    or byte [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_MOVEMENTSTATUS], (1 << BIT_FACE_PLAYER)

    ; Look up text_id → table entry: flat ptr + (byte count | SCRIPT sentinel).
    ; text id lives in wMapSpriteData[(slot-1)*2 + 1] (OW-A.2 P2 relocation).
    mov eax, esi
    shr eax, 4                             ; slot number (1-15)
    dec eax
    add eax, eax                           ; (slot-1)*2 -> wMapSpriteData index
    movzx eax, byte [wMapSpriteData + eax + 1]  ; masked text id
    lea edx, [eax * 8]                      ; 8 bytes per entry (dd ptr + dd size)
    mov ecx, [w_map_text_table_ptr]         ; flat ptr to current map's TextTable (0 if none)
    test ecx, ecx
    jz .dialog_done                         ; null table: no text for this map

    mov edi, [ecx + edx]                    ; flat ptr: TX stream OR text_asm routine
    test edi, edi
    jz .dialog_done                         ; null entry: no text for this id
    mov ebx, [ecx + edx + 4]               ; byte count, or 0xFFFFFFFF = SCRIPT entry

    ; Force the player into a STANDING pose before the font load. If A was pressed
    ; while the player was walk-animating in place (e.g. pushing into this NPC), its
    ; IMAGEINDEX points at walk tiles $80+, which live in GB_VFONT ($8800) — the very
    ; region LoadFontTilePatterns is about to overwrite. The overworld loop (and thus
    ; UpdatePlayerSprite's "treat as standing while font loaded" path) is suspended
    ; during the dialog, so the frozen walk index would render the font glyphs as the
    ; player (e.g. facing-up walk tiles $84-$87 = font "EFGH"). Standing tiles $00-$0F
    ; live at $8000 and are untouched by the font. Image index == facing dir (0/4/8/C)
    ; selects the matching Standing* OAM block (anim frame 0).
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
    mov [ebp + W_SPRITE_PLAYER_IMAGE_INDEX], al
    mov byte [ebp + W_SPRITE_PLAYER_ANIM_FRAME], 0
    mov byte [ebp + W_SPRITE_PLAYER_INTRA_ANIM], 0

    ; Set W_FONT_LOADED to freeze UpdateSprites NPC movement during dialog.
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)

    ; Restore font glyphs to GB_VFONT before text rendering (walk tiles share it).
    call LoadFontTilePatterns

    ; Dispatch: SCRIPT entry (sentinel size) → CALL the flat text_asm routine, which
    ; runs its own logic + ShowTextStream. Plain entry → display the TX stream.
    cmp ebx, 0xFFFFFFFF
    je .run_script
    cmp ebx, 256
    jge .dialog_done                        ; safety: never copy more than 256 bytes
    mov esi, edi                            ; flat src ptr
    mov ecx, ebx                            ; byte count
    call ShowTextStream
    jmp .dialog_done
.run_script:
    call edi                                ; flat text_asm routine (does its own ShowTextStream)

.dialog_done:
    ; Hide window and clear font-loaded flag.
    call hide_window                    ; count=0 (nothing drawn); parks H_WY off-screen
    and byte [ebp + W_FONT_LOADED], ~(1 << BIT_FONT_LOADED)

    ; Reload NPC and player walk tiles into GB_VFONT (font was loaded for dialog).
    call ReloadWalkingTilePatterns      ; OW-A.2 P3c: faithful post-dialog walk-tile reload
    call LoadPlayerSpriteGraphics

    ; Restore the BG: rebuild wSurroundingTiles for current player position.
    call LoadCurrentMapView
    call DelayFrame

    ; Signal caller that NPC interaction occurred.
    mov dword [esp + 28], 1                 ; overwrite saved EAX slot in pushad frame
    popad
    ret

.not_found:
    xor eax, eax
    mov dword [esp + 28], 0
    popad
    ret

; ── ShowTextStream — copy a flat TX stream into NPC_DIALOG_BUF and display it ──
; In: ESI = flat (program-image) ptr to a TX command stream; ECX = byte count (<256).
; Copies to NPC_DIALOG_BUF (WRAM), runs PrintText, then waits via npc_dialog_wait_impl.
; Assumes the font is already loaded and the player is frozen in a standing pose
; (CheckNPCInteraction does this before dispatch; text_asm scripts rely on it too).
; Shared by the plain-dialog path and hand-written text_asm scripts (e.g.
; src/scripts/pallet_town.asm). Clobbers caller-saved regs.
ShowTextStream:
    lea edi, [ebp + NPC_DIALOG_BUF]         ; EBP-relative WRAM dest
    rep movsb                                ; flat src ESI → WRAM (both flat selectors)
    mov esi, NPC_DIALOG_BUF                  ; EBP-relative ptr for PrintText
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    call PrintTextStaged
    call npc_dialog_wait_impl
    ret

; ── shared helper: copy current wTileMap dialog rows to window layer, wait A/B ──
; Called by CheckNPCInteraction and TrainerEncounterFlow. Not a dot-local label so
; both callers can reach it. Preserves ECX, ESI, EDI (push/pop).
npc_dialog_wait_impl:
    ; Copy wTileMap rows 12-17 to GB_TILEMAP1 rows 0-5 (window layer source).
    push ecx
    push esi
    push edi
    mov ecx, DIALOG_TILEMAP_ROWS
    lea esi, [ebp + W_TILEMAP + DIALOG_TILEMAP_ROW * 20]
    lea edi, [ebp + GB_TILEMAP1]
.sdw_row:
    push ecx
    push edi
    mov ecx, 20                             ; 20 tiles from wTileMap
    rep movsb
    mov al, TILE_SPC
    mov ecx, 12                             ; pad cols 20-31 with space
    rep stosb
    pop edi
    pop ecx
    add edi, 32                             ; next GB_TILEMAP1 row (32 wide)
    dec ecx
    jnz .sdw_row
    ; Show the dialog box via the window descriptor list.
    ; PROJ overworld-ui: GB(0,19) 20x6 --(dialog, X+0/centered, WX-7=80)--> wx=87 wy=152 clip=160 max_y=200
    mov eax, 87                            ; wx (WX-7=80 → center 160px dialog in 320px)
    mov ebx, 152                           ; wy (bottom of 320×200 viewport)
    mov ecx, SCREEN_W                      ; clip_w = 160px
    mov edx, RENDER_H                      ; max_y = 200
    mov esi, GB_TILEMAP1                   ; dialog box source tilemap
    xor edi, edi                           ; start_row = 0
    call set_single_window                 ; count=1; mirrors wy→H_WY, wx→IO_WX
    ; Place ▼ arrow and init blink counters; save existing state to restore after.
    movzx ecx, byte [ebp + H_DOWN_ARROW_COUNT1]
    push ecx
    movzx ecx, byte [ebp + H_DOWN_ARROW_COUNT2]
    push ecx
    mov byte [ebp + H_DOWN_ARROW_COUNT1], ARROW_ON_FRAMES
    mov byte [ebp + H_DOWN_ARROW_COUNT2], 1
    mov esi, GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET
    mov byte [ebp + esi], CHAR_DOWN_ARROW
    ; Release: wait until A/B not held.
.sdw_release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .sdw_release
    ; Press: wait for A or B; blink ▼ each frame.
.sdw_press:
    call DelayFrame
    call HandleDownArrowBlinkTiming
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jz .sdw_press
    ; Clear arrow, restore blink state.
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], TILE_SPC
    pop ecx
    mov [ebp + H_DOWN_ARROW_COUNT2], cl
    pop ecx
    mov [ebp + H_DOWN_ARROW_COUNT1], cl
    pop edi
    pop esi
    pop ecx
    ret

; ---------------------------------------------------------------------------
; CheckTrainerSight — scan NPC slots 1-15 for an unbeaten trainer with the
; player in their line-of-sight (facing direction, distance ≤ 4 blocks).
;
; Sets w_trainer_enc_slot to the matching slot's byte offset if found.
; Out: CF=1 if a trainer spotted the player, CF=0 otherwise.
; All registers preserved (pushad/popad; CF set after popad).
; ---------------------------------------------------------------------------
CheckTrainerSight:
    pushad

    ; Player block coords: SPRITESTATEDATA2 slot 0 MAPY/MAPX
    movzx ebx, byte [ebp + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPY]   ; BL = player_mapy
    movzx ecx, byte [ebp + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPX]   ; CL = player_mapx

    mov esi, 0x10                          ; start at NPC slot 1
.cts_loop:
    cmp esi, 0x100
    jge .cts_none

    ; Skip inactive slot
    cmp byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_IMAGEBASEOFFSET], 0
    je .cts_next

    ; Skip non-trainer
    cmp byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_ISTRAINER], 0
    je .cts_next

    ; Skip if already beaten (bit_index = slot/0x10 - 1, i.e. 0-14)
    mov edx, esi
    shr dl, 4                              ; slot number (1-15) in DL
    dec dl                                 ; bit index (0-14)
    bt word [npc_beaten_flags], dx         ; CF = beaten bit
    jc .cts_next

    ; Load trainer position
    movzx eax, byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPY]  ; AL = trainer_mapy
    movzx edx, byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPX]  ; DL = trainer_mapx

    ; Check facing direction → sight line (BL=player_mapy, CL=player_mapx)
    movzx edi, byte [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_FACINGDIRECTION]

    cmp edi, SPRITE_FACING_DOWN
    jne .cts_try_up
    ; DOWN: same MAPX, player south of trainer, dist ≤ 4
    cmp cl, dl                             ; player_mapx == trainer_mapx?
    jne .cts_next
    cmp bl, al                             ; player_mapy > trainer_mapy?
    jle .cts_next
    mov ah, bl
    sub ah, al                             ; dist = player_mapy - trainer_mapy
    cmp ah, 4
    ja .cts_next
    jmp .cts_found

.cts_try_up:
    cmp edi, SPRITE_FACING_UP
    jne .cts_try_left
    ; UP: same MAPX, player north of trainer, dist ≤ 4
    cmp cl, dl
    jne .cts_next
    cmp bl, al                             ; player_mapy < trainer_mapy?
    jge .cts_next
    mov ah, al
    sub ah, bl                             ; dist = trainer_mapy - player_mapy
    cmp ah, 4
    ja .cts_next
    jmp .cts_found

.cts_try_left:
    cmp edi, SPRITE_FACING_LEFT
    jne .cts_try_right
    ; LEFT: same MAPY, player west of trainer, dist ≤ 4
    cmp bl, al                             ; player_mapy == trainer_mapy?
    jne .cts_next
    cmp cl, dl                             ; player_mapx < trainer_mapx?
    jge .cts_next
    mov ah, dl
    sub ah, cl                             ; dist = trainer_mapx - player_mapx
    cmp ah, 4
    ja .cts_next
    jmp .cts_found

.cts_try_right:
    ; RIGHT: same MAPY, player east of trainer, dist ≤ 4
    cmp bl, al
    jne .cts_next
    cmp cl, dl                             ; player_mapx > trainer_mapx?
    jle .cts_next
    mov ah, cl
    sub ah, dl                             ; dist = player_mapx - trainer_mapx
    cmp ah, 4
    ja .cts_next

.cts_found:
    mov eax, esi                           ; ESI = slot offset (0x10-0xF0); AL = low byte
    mov [w_trainer_enc_slot], al           ; save slot offset (fits in a byte)
    popad
    stc
    ret

.cts_next:
    add esi, 0x10
    jmp .cts_loop

.cts_none:
    popad
    clc
    ret

; ---------------------------------------------------------------------------
; TrainerEncounterFlow — trainer encounter stub (no battle engine).
; Pret ref: home/overworld.asm:TrainerEncounter (stub).
;
; Flow: brief freeze → face trainer → show pre-battle text →
;       mark trainer beaten → clear encounter state.
;
; Reads w_trainer_enc_slot for the engaging trainer's slot offset.
; All registers preserved (pushad/popad).
; ---------------------------------------------------------------------------
TrainerEncounterFlow:
    pushad

    mov byte [w_player_frozen], 1

    ; --- Brief freeze before text (~45 frames) ---
    ; TODO: Add ! bubble over trainer's head here.
    mov ecx, 45
.tef_freeze:
    call DelayFrame
    dec ecx
    jnz .tef_freeze

    ; --- Make trainer face player and freeze NPC movement during text ---
    movzx esi, byte [w_trainer_enc_slot]   ; ESI = slot byte offset (0x10-0xF0)
    movzx eax, byte [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_IMAGEBASEOFFSET]
    dec al
    ror al, 4
    mov [ebp + H_TILE_PLAYER_STANDING_ON], al
    call MakeNPCFacePlayer
    or byte [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_MOVEMENTSTATUS], (1 << BIT_FACE_PLAYER)

    ; --- Look up and show pre-battle text ---
    ; text id lives in wMapSpriteData[(slot-1)*2 + 1] (OW-A.2 P2 relocation).
    mov eax, esi
    shr eax, 4
    dec eax
    add eax, eax
    movzx eax, byte [wMapSpriteData + eax + 1]  ; masked text id
    lea edx, [eax * 8]                     ; 8 bytes per entry (dd ptr + dd size)
    mov ecx, [w_map_text_table_ptr]        ; flat ptr to current map's TextTable (0 if none)
    test ecx, ecx
    jz .tef_text_done

    mov edi, [ecx + edx]                   ; flat DS ptr to text stream
    test edi, edi
    jz .tef_text_done

    mov ecx, [ecx + edx + 4]              ; byte count
    cmp ecx, 256
    jge .tef_text_done

    ; ESI (slot offset) is consumed; save it around the rep movsb.
    push esi
    mov esi, edi                            ; text src ptr
    lea edi, [ebp + NPC_DIALOG_BUF]
    rep movsb
    pop esi                                 ; restore slot offset (not needed further, but balanced)

    ; Force the player to a standing pose before the font overwrites the walk tiles
    ; at $8800 — see the matching note in CheckNPCInteraction (avoids the player
    ; rendering font glyphs while the dialog freezes the overworld loop).
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
    mov [ebp + W_SPRITE_PLAYER_IMAGE_INDEX], al
    mov byte [ebp + W_SPRITE_PLAYER_ANIM_FRAME], 0
    mov byte [ebp + W_SPRITE_PLAYER_INTRA_ANIM], 0

    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    mov esi, NPC_DIALOG_BUF
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    call PrintTextStaged
    call npc_dialog_wait_impl

.tef_text_done:
    ; --- M8.1 sight->battle wiring -------------------------------------------
    ; Seed the engaged-trainer globals from this slot's cached class/set, then hand
    ; off to StartTrainerBattle (the pret home/trainers.asm battle-entry).  This
    ; inline read of wMapSpriteExtraData is a stopgap for pret EngageMapTrainer,
    ; which M8.2 (trainer-header engine) will provide via wSpriteIndex.
    ; StartTrainerBattle only SEEDS parameters by default (wCurOpponent /
    ; wTrainerClass / wTrainerNo); the live `call InitBattle` is gated behind
    ; -D TRAINER_BATTLE_LIVE because the port InitBattle is still wild-only
    ; (no ReadTrainer / trainer-party / trainer-pic path yet — see SUMMARY).
    movzx eax, byte [w_trainer_enc_slot]   ; slot byte offset (0x10-0xF0)
    shr al, 4                              ; slot number (1-15)
    dec al                                 ; 0-based slot index
    movzx eax, al
    add eax, eax                           ; *2 -> wMapSpriteExtraData index
    mov cl, [wMapSpriteExtraData + eax]     ; trainer class (OPP_* value)
    mov [ebp + wEngagedTrainerClass], cl
    mov cl, [wMapSpriteExtraData + eax + 1] ; trainer set
    mov [ebp + wEngagedTrainerSet], cl
    call StartTrainerBattle
%ifdef TRAINER_BATTLE_LIVE
    call EndTrainerBattle
%endif
    ; -------------------------------------------------------------------------
    call hide_window                    ; count=0 (nothing drawn); parks H_WY off-screen
    and byte [ebp + W_FONT_LOADED], ~(1 << BIT_FONT_LOADED)
    call ReloadWalkingTilePatterns      ; OW-A.2 P3c: faithful post-dialog walk-tile reload
    call LoadPlayerSpriteGraphics
    call LoadCurrentMapView
    call DelayFrame

    ; --- Mark trainer beaten (bit_index = slot/0x10 - 1) ---
    movzx edx, byte [w_trainer_enc_slot]
    shr dl, 4                              ; slot number (1-15)
    dec dl                                 ; bit index (0-14)
    bts word [npc_beaten_flags], dx        ; set beaten bit

    ; --- Clear encounter state ---
    mov byte [w_trainer_enc_slot], 0xFF
    mov byte [w_player_frozen], 0

    popad
    ret
