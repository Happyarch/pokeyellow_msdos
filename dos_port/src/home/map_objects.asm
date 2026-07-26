; map_objects.asm — pret mirror of home/map_objects.asm.
;
; The home-bank map-object grab-bag: the arrow-movement / RLE decoders that feed
; the simulated-joypad buffer, the TX_SCRIPT_* PC/prize-menu dispatch stubs, the
; coord-array predicates, the bag predicate, and the sprite movement-byte
; accessors. Consolidated here (mirror rule, CLAUDE.md) from five port files that
; had grown their own copies:
;
;   src/home/simulate_joypad.asm   DecodeArrowMovementRLE, DecodeRLEList,
;                                  StartSimulatingJoypadStates  — that file held
;                                  ONLY these three, so it is gone; its two
;                                  home/overworld.asm siblings (AreInputsSimulated,
;                                  GetSimulatedInput) are defined in
;                                  src/home/overworld.asm and were never here.
;   src/home/overworld_text.asm    TextScript_ItemStoragePC, TextScript_BillsPC,
;                                  TextScript_GameCornerPrizeMenu,
;                                  TextScript_PokemonCenterPC, BankswitchAndContinue
;                                  — that file's header attributed these to pret
;                                  home/text_script.asm, which is wrong: text_script.asm
;                                  only holds the `dict` dispatch entries that NAME them.
;   src/home/hidden_events.asm     ArePlayerCoordsInArray, CheckCoords, CheckBoulderCoords
;   src/home/pathfinding.asm       SetSpriteMovementBytesToFF,
;                                  GetSpriteMovementByte1Pointer,
;                                  GetSpriteMovementByte2Pointer
;   src/home/item_predicates.asm   IsItemInBag
;
; Routine order follows pret home/map_objects.asm. The remaining pret labels in
; that file (IsSurfingPikachuInParty — a stub; DisplayPokedex, SetSpriteFacingDirection
; and family, SpriteFunc_34a1, SetSpriteMovementBytesToFE, the
; GetPointerWithinSpriteStateData family) are not translated anywhere in the port
; and are deliberately NOT invented here.
;
; Register map (CLAUDE.md): A->AL, HL->ESI, BC->BX (B=BH,C=BL), DE->DX; SM83
; `swap a` = nibble swap. GB memory = [ebp + SYM] (gb_memmap.inc); flat data
; tables are addressed through a full 32-bit register (EDI/ESI).

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global DecodeArrowMovementRLE
global TextScript_ItemStoragePC
global TextScript_BillsPC
global TextScript_GameCornerPrizeMenu
global TextScript_PokemonCenterPC
global StartSimulatingJoypadStates
global IsItemInBag
global ArePlayerCoordsInArray
global CheckCoords
global CheckBoulderCoords
global DecodeRLEList
global SetSpriteMovementBytesToFF
global GetSpriteMovementByte1Pointer
global GetSpriteMovementByte2Pointer

extern FillMemory                 ; home/copy2.asm — ESI=dest, BX=count, AL=val (ESI preserved)
extern SaveScreenTilesToBuffer2         ; src/home/tilemap.asm
extern HoldTextDisplayOpen              ; home/text_script.asm
extern PlayerPC                         ; engine/menus/players_pc.asm
extern BillsPC_                         ; engine/menus/pc_stubs.asm
extern CeladonPrizeMenu                 ; engine/menus/main_menu_stubs.asm
extern ActivatePC                       ; engine/menus/pc.asm
extern GetQuantityOfItemInBag   ; src/engine/items/get_bag_item_quantity.asm (predef)
extern wMapSpriteData            ; map_sprites.asm — [movbyte2, textid] per slot (pret wMapSpriteData)

; ---------------------------------------------------------------------------
; Scaffold memmap symbol not yet in gb_memmap.inc (carried in with CheckCoords).
; ---------------------------------------------------------------------------
%ifndef W_COORD_INDEX
W_COORD_INDEX   equ 0xD152   ; wCoordIndex  — PLACEHOLDER, sym-verify vs pret Yellow
%endif

section .text

; ---------------------------------------------------------------------------
; DecodeArrowMovementRLE — if the player's coords match an arrow-movement tile,
; decode its RLE movement bytes into the simulated-joypad buffer.
;
; pret: home/map_objects.asm:DecodeArrowMovementRLE
; In:  ESI = flat pointer to the $ff-terminated arrow-movement-tile list
;      BH  = player Y (b), BL = player X (c)
; Out: on match, the simulated-joypad buffer is filled and the index set.
; Clobbers: AL, ESI, EDI, EBX, flags
;
; NOTE(port): a list entry is <Y> <X> <dd flat pointer to RLE data> (6-byte stride);
; pret stores the movement-data pointer as a GB 16-bit dw (4-byte stride). The
; producer arrow-movement tables are owned by map-script waves (deferred). This
; routine is CHECK-only until those tables exist.
; ---------------------------------------------------------------------------
DecodeArrowMovementRLE:
.scan:
    mov al, [esi]                             ; entry Y
    cmp al, 0xFF
    je .noMatch                               ; reached terminator: no match
    cmp al, bh
    jne .next
    mov al, [esi + 1]                         ; entry X
    cmp al, bl
    jne .next
    mov edi, [esi + 2]                        ; EDI = flat pointer to RLE movement data
    mov esi, W_SIMULATED_JOYPAD_STATES_END    ; output buffer offset
    call DecodeRLEList                        ; AL = bytes written incl. sentinel
    dec al
    mov [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], al
    ret
.next:
    add esi, 6                                ; skip Y, X, dd pointer
    jmp .scan
.noMatch:
    ret

; ---------------------------------------------------------------------------
; TextScript_* special cases — pret home/map_objects.asm (the dispatch targets
; home/text_script.asm's `dict` table names).
; Tier-2 dispatch stubs: they bankswitch (no-op under flat memory) and jump into a bank
; routine (PlayerPC / BillsPC_ / CeladonPrizeMenu / ActivatePC), then fall into
; HoldTextDisplayOpen. PlayerPC and ActivatePC are linked; BillsPC_ and
; CeladonPrizeMenu resolve through structured menu stubs until their real UIs land.
;
;   TextScript_ItemStoragePC   -> PlayerPC        (SaveScreenTilesToBuffer2 first)
;   TextScript_BillsPC         -> BillsPC_        (SaveScreenTilesToBuffer2 first)
;   TextScript_GameCornerPrizeMenu -> CeladonPrizeMenu
;   TextScript_PokemonCenterPC -> ActivatePC
; all converge on BankswitchAndContinue: Bankswitch + jp HoldTextDisplayOpen.
;
; NOTE(port): pret reaches BankswitchAndContinue from TextScript_PokemonCenterPC
; with a `jr`; the port already realized that edge as a FALLTHROUGH. The pair is
; kept adjacent and in that order here so the fallthrough survives the move.
; ---------------------------------------------------------------------------
TextScript_ItemStoragePC:
    call SaveScreenTilesToBuffer2
    mov esi, PlayerPC
    jmp BankswitchAndContinue

TextScript_BillsPC:
    call SaveScreenTilesToBuffer2
    mov esi, BillsPC_
    jmp BankswitchAndContinue

TextScript_GameCornerPrizeMenu:
    mov esi, CeladonPrizeMenu
    jmp BankswitchAndContinue

TextScript_PokemonCenterPC:
    mov esi, ActivatePC
BankswitchAndContinue:
    call esi                            ; Bankswitch is a no-op under flat memory
    jmp HoldTextDisplayOpen

; ---------------------------------------------------------------------------
; StartSimulatingJoypadStates — arm scripted-movement input simulation.
; Zeroes the override mask and the player's (slot-0) movement byte 1, and sets
; BIT_SCRIPTED_MOVEMENT_STATE so AreInputsSimulated begins injecting queued states.
;
; pret: home/map_objects.asm:StartSimulatingJoypadStates
; Clobbers: nothing meaningful (writes RAM only)
; ---------------------------------------------------------------------------
StartSimulatingJoypadStates:
    mov byte [ebp + W_OVERRIDE_SIMULATED_JOYPAD_STATES_MASK], 0
    ; wSpritePlayerStateData2MovementByte1 = slot 0 movement byte 1
    mov byte [ebp + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MOVEMENTBYTE1], 0
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    ret

; ---------------------------------------------------------------------------
; IsItemInBag — pret home/map_objects.asm:IsItemInBag.
; Zero flag SET if the item is NOT in the bag, RESET if it is.
; pret invokes `predef GetQuantityOfItemInBag` (b = item id). The port's
; GetQuantityOfItemInBag opens with GetPredefRegisters, which reloads BX from
; wPredefBC — so stash the item id there first. (The predef dispatcher is dead
; code in the port; the documented convention is to populate the wPredef*
; slots directly at the call site — see src/home/predef.asm header.)
; In:  BH = item id.   Out: ZF = 1 if not in bag; BH = quantity.  AL clobbered.
; ---------------------------------------------------------------------------
IsItemInBag:
    mov [ebp + wPredefBC], bh        ; b → wPredefBC high byte (GetPredefRegisters)
    mov [ebp + wPredefBC + 1], bl    ; c → low byte (unused by callee; kept faithful)
    call GetQuantityOfItemInBag      ; → BH = quantity of that item in the bag
    mov al, bh                       ; ld a, b
    and al, al                       ; and a  (ZF=1 ⇒ qty 0 ⇒ not in bag)
    ret

; ---------------------------------------------------------------------------
; ArePlayerCoordsInArray / CheckCoords — test whether coords are in a $ff-
; terminated (Y,X) array.
; Pret ref: home/map_objects.asm:ArePlayerCoordsInArray / CheckCoords
;
; ArePlayerCoordsInArray: loads BH=wYCoord, BL=wXCoord, falls through.
; CheckCoords:
;   In:  BH = Y, BL = X, ESI = flat ptr to a $ff-terminated array of (Y,X) pairs.
;   Out: CF=1 and [wCoordIndex] = matching 1-based index if found; CF=0 else.
;        [wCoordIndex] holds the count of entries examined either way (faithful).
; Clobbers EAX, ESI.  Preserves BX/DX.
; ---------------------------------------------------------------------------
ArePlayerCoordsInArray:
    mov bh, [ebp + W_Y_COORD]           ; b = wYCoord
    mov bl, [ebp + W_X_COORD]           ; c = wXCoord
    ; fallthrough
CheckCoords:
    mov byte [ebp + W_COORD_INDEX], 0
.loop:
    mov al, [esi]                       ; array Y (or $ff terminator)
    inc esi
    cmp al, 0xFF
    je .notInArray
    inc byte [ebp + W_COORD_INDEX]
    cmp al, bh                          ; compare Y
    jne .skipX
    mov al, [esi]                       ; array X
    inc esi
    cmp al, bl                          ; compare X
    je .inArray
    jmp .loop                           ; X mismatch, ESI at next entry
.skipX:
    inc esi                             ; skip X, ESI at next entry
    jmp .loop
.inArray:
    stc
    ret
.notInArray:
    clc
    ret

; ---------------------------------------------------------------------------
; CheckBoulderCoords — test a boulder sprite's coords against an array.
; Pret ref: home/map_objects.asm:CheckBoulderCoords
;
; In:  ESI = flat ptr to $ff-terminated (Y,X) array; [hSpriteIndex] = boulder slot.
; Out: as CheckCoords (CF + wCoordIndex).
; ---------------------------------------------------------------------------
CheckBoulderCoords:
    movzx eax, byte [ebp + H_SPRITE_INDEX]
    shl eax, 4                          ; slot * 16 (SPRITESTATEDATA2 stride)
    mov bh, [ebp + eax + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPY]
    sub bh, 4                           ; sprite coords are offset by 4
    mov bl, [ebp + eax + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPX]
    sub bl, 4
    jmp CheckCoords                     ; ESI already = array

; ---------------------------------------------------------------------------
; DecodeRLEList — expand a $ff-terminated run-length list into a byte buffer.
; Each source entry is <value> <count>; the final $ff is replicated to the output.
;
; pret: home/map_objects.asm:DecodeRLEList
; In:  EDI = flat pointer to the RLE source list
;      ESI = GB output offset (EBP-relative)
; Out: AL  = number of bytes written including the trailing $ff sentinel
;      ESI advanced to the sentinel; EDI advanced past the source terminator
; Clobbers: AL, EBX, ESI, EDI, flags
;
; NOTE(port): the port FillMemory *preserves* ESI (EDI is its scratch), so unlike
; pret — where FillMemory advances hl — we bump ESI by the run length manually.
; ---------------------------------------------------------------------------
DecodeRLEList:
    mov byte [ebp + W_RLE_BYTE_COUNT], 0      ; count written bytes here
.listLoop:
    mov al, [edi]
    cmp al, 0xFF
    je .endOfList
    mov [ebp + H_RLE_BYTE_VALUE], al          ; byte value to be written
    inc edi
    movzx ebx, byte [edi]                     ; BX = run length (C), BH=0
    add [ebp + W_RLE_BYTE_COUNT], bl          ; update total written bytes
    mov al, [ebp + H_RLE_BYTE_VALUE]
    call FillMemory                           ; write AL, BX times, at [ebp+ESI]
    add esi, ebx                              ; advance dest (port FillMemory keeps ESI)
    inc edi
    jmp .listLoop
.endOfList:
    mov byte [ebp + esi], 0xFF                ; write final $ff
    mov al, [ebp + W_RLE_BYTE_COUNT]
    inc al                                    ; include sentinel in the count
    ret

; ---------------------------------------------------------------------------
; SetSpriteMovementBytesToFF — movement byte 1 = STAY ($ff), byte 2 = NONE ($00),
; for sprite [hCurrentSpriteOffset].
; pret: home/map_objects.asm:SetSpriteMovementBytesToFF
; Clobbers: ESI, flags
; ---------------------------------------------------------------------------
SetSpriteMovementBytesToFF:
    call GetSpriteMovementByte1Pointer
    mov byte [ebp + esi], 0xFF                ; STAY
    call GetSpriteMovementByte2Pointer
    mov byte [esi], 0x00                      ; NONE (ESI = flat wMapSpriteData ptr, not EBP-relative)
    ret

; ---------------------------------------------------------------------------
; GetSpriteMovementByte1Pointer — ESI = EBP-rel offset of sprite [hCurrentSpriteOffset]
; movement byte 1 (wSpriteStateData2 + slot*0x10 + 6).
; pret: home/map_objects.asm:GetSpriteMovementByte1Pointer (swap a / add 6)
; Out: ESI = offset   Clobbers: ESI
; ---------------------------------------------------------------------------
GetSpriteMovementByte1Pointer:
    movzx esi, byte [ebp + H_CURRENT_SPRITE_OFFSET]
    add esi, W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MOVEMENTBYTE1
    ret

; ---------------------------------------------------------------------------
; GetSpriteMovementByte2Pointer — ESI = EBP-rel offset of the sprite's movement
; byte 2 (direction constraint).
; pret: home/map_objects.asm:GetSpriteMovementByte2Pointer.
;
; pret stores byte 2 in wMapSpriteData[(slot-1)*2]; OW-A.2 P2 relocated the port's copy
; there too (it had been stashed in SPRITESTATEDATA2 offset 0x1). Since wMapSpriteData is
; a flat .bss array, this returns ESI = flat address (NOT an EBP-relative offset like
; GetSpriteMovementByte1Pointer); callers write [esi], not [ebp+esi].
; Out: ESI = flat wMapSpriteData ptr   Clobbers: ESI, flags
; ---------------------------------------------------------------------------
GetSpriteMovementByte2Pointer:
    movzx esi, byte [ebp + H_CURRENT_SPRITE_OFFSET]  ; slot byte offset (slot*0x10)
    shr esi, 4                                        ; slot number (1-15)
    dec esi
    add esi, esi                                      ; (slot-1)*2 -> wMapSpriteData index
    add esi, wMapSpriteData                           ; flat address; flags dead (ret follows)
    ret
