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
;   src/home/item_predicates.asm   IsItemInBag — that bucket file has since been
;                                  deleted entirely (its remaining labels went to
;                                  src/home/names.asm and src/home/item.asm).
;
; Routine order follows pret home/map_objects.asm. SetSpriteFacingDirection and
; family and the GetPointerWithinSpriteStateData family landed 2026-08-17.
; DisplayPokedex (-> _DisplayPokedex, src/engine/events/display_pokedex.asm)
; landed 2026-08-19 (fossil/pokedex spec). The remaining pret labels in that
; file (IsSurfingPikachuInParty — a stub; SetSpriteMovementBytesToFE;
; SpriteFunc_34a1, whose HRAM-union question is documented at its site below) are
; not translated anywhere in the port and are deliberately NOT invented here.
;
; Register map (CLAUDE.md): A->AL, HL->ESI, BC->BX (B=BH,C=BL), DE->DX; SM83
; `swap a` = nibble swap. GB memory = [ebp + SYM] (gb_memmap.inc); flat data
; tables are addressed through a full 32-bit register (EDI/ESI).

bits 32

%include "gb_memmap.inc"
%include "assets/script_constants.inc"; shared constants (%define: emits no COFF symbol)
%include "gb_macros.inc"
%include "gb_constants.inc"

global DecodeArrowMovementRLE
global TextScript_ItemStoragePC
global TextScript_BillsPC
global TextScript_GameCornerPrizeMenu
global TextScript_PokemonCenterPC
global StartSimulatingJoypadStates
global IsItemInBag
global IsSurfingPikachuInParty
global ArePlayerCoordsInArray
global CheckCoords
global CheckBoulderCoords
global DecodeRLEList
global SetSpriteMovementBytesToFE
global SetSpriteMovementBytesToFF
global GetSpriteMovementByte1Pointer
global GetSpriteMovementByte2Pointer
global GetPointerWithinSpriteStateData1
global GetPointerWithinSpriteStateData2
global SetSpriteImageIndexAfterSettingFacingDirection
global SetSpriteFacingDirection
global SetSpriteFacingDirectionAndDelay
global SpriteFunc_34a1
global DisplayPokedex

extern FillMemory                 ; home/copy2.asm — ESI=dest, BX=count, AL=val (ESI preserved)
extern SaveScreenTilesToBuffer2         ; src/home/tilemap.asm
extern HoldTextDisplayOpen              ; home/text_script.asm
extern PlayerPC                         ; engine/menus/players_pc.asm
extern BillsPC_                         ; engine/pokemon/bills_pc.asm (real box UI)
extern CeladonPrizeMenu                 ; src/engine/events/prize_menu.asm
extern ActivatePC                       ; engine/menus/pc.asm
extern GetQuantityOfItemInBag   ; src/engine/items/get_bag_item_quantity.asm (predef)
extern DelayFrames               ; src/home/delay.asm (BL = frame count)
extern wMapSpriteData            ; map_sprites.asm — [movbyte2, textid] per slot (pret wMapSpriteData)
extern IsStarterPikachuAliveInOurParty ; src/engine/pikachu/pikachu_status.asm
extern _DisplayPokedex                 ; src/engine/events/display_pokedex.asm

; ---------------------------------------------------------------------------
; Scaffold memmap symbol not yet in gb_memmap.inc (carried in with CheckCoords).
; ---------------------------------------------------------------------------
%ifndef W_COORD_INDEX
W_COORD_INDEX   equ 0xD88B   ; wCoordIndex  — PLACEHOLDER, sym-verify vs pret Yellow
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
    mov esi, wSimulatedJoypadStatesEnd    ; output buffer offset
    call DecodeRLEList                        ; AL = bytes written incl. sentinel
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
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
; HoldTextDisplayOpen. PlayerPC, ActivatePC and BillsPC_ are linked -- BillsPC_ has
; had a real body in src/engine/pokemon/bills_pc.asm since 0c9afce5 (2026-07-31),
; gated by the bills_pc_ops and box_change_roundtrip goldens; this comment called it
; a stub until 2026-08-02. CeladonPrizeMenu still resolves through a structured menu
; stub until its real UI lands.
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
    mov byte [ebp + wOverrideSimulatedJoypadStatesMask], 0
    ; wSpritePlayerStateData2MovementByte1 = slot 0 movement byte 1
    mov byte [ebp + wSpriteStateData2 + SPRITESTATEDATA2_MOVEMENTBYTE1], 0
    or byte [ebp + wStatusFlags5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
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
; IsSurfingPikachuInParty — pret home/map_objects.asm:IsSurfingPikachuInParty.
; Sets BIT_PIKACHU_SPAWN_SURFING in wPikachuSpawnStateFlags if any Pikachu with
; Surf is in party. Sets BIT_PIKACHU_SPAWN_STARTER if starter Pikachu is in party.
; ---------------------------------------------------------------------------
IsSurfingPikachuInParty:
    and byte [ebp + wPikachuSpawnStateFlags], ~((1 << BIT_PIKACHU_SPAWN_STARTER) | (1 << BIT_PIKACHU_SPAWN_SURFING)) & 0xFF
    mov esi, wPartyMon1
    mov cl, PARTY_LENGTH
    mov bh, SURF
.loop:
    mov al, [ebp + esi]                                 ; ld a, [hl]
    cmp al, STARTER_PIKACHU                             ; cp STARTER_PIKACHU
    jne .notPikachu
    ; check if pikachu has surf as one of its moves (moves at offset 8..11)
    cmp byte [ebp + esi + 8], bh
    je .hasSurf
    cmp byte [ebp + esi + 9], bh
    je .hasSurf
    cmp byte [ebp + esi + 10], bh
    je .hasSurf
    cmp byte [ebp + esi + 11], bh
    jne .noSurf
.hasSurf:
    or byte [ebp + wPikachuSpawnStateFlags], (1 << BIT_PIKACHU_SPAWN_SURFING)
.noSurf:
.notPikachu:
    add esi, wPartyMon2 - wPartyMon1
    dec cl
    jnz .loop
    call .checkForStarter
    ret

.checkForStarter:
    push esi
    push ebx
    push ecx
    call IsStarterPikachuAliveInOurParty
    pop ecx
    pop ebx
    pop esi
    jnc .doneStarter
    or byte [ebp + wPikachuSpawnStateFlags], (1 << BIT_PIKACHU_SPAWN_STARTER)
.doneStarter:
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
    mov bh, [ebp + wYCoord]           ; b = wYCoord
    mov bl, [ebp + wXCoord]           ; c = wXCoord
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
    movzx eax, byte [ebp + hSpriteIndex]
    shl eax, 4                          ; slot * 16 (SPRITESTATEDATA2 stride)
    mov bh, [ebp + eax + wSpriteStateData2 + SPRITESTATEDATA2_MAPY]
    sub bh, 4                           ; sprite coords are offset by 4
    mov bl, [ebp + eax + wSpriteStateData2 + SPRITESTATEDATA2_MAPX]
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
    mov byte [ebp + wRLEByteCount], 0      ; count written bytes here
.listLoop:
    mov al, [edi]
    cmp al, 0xFF
    je .endOfList
    mov [ebp + hRLEByteValue], al          ; byte value to be written
    inc edi
    movzx ebx, byte [edi]                     ; BX = run length (C), BH=0
    add [ebp + wRLEByteCount], bl          ; update total written bytes
    mov al, [ebp + hRLEByteValue]
    call FillMemory                           ; write AL, BX times, at [ebp+ESI]
    add esi, ebx                              ; advance dest (port FillMemory keeps ESI)
    inc edi
    jmp .listLoop
.endOfList:
    mov byte [ebp + esi], 0xFF                ; write final $ff
    mov al, [ebp + wRLEByteCount]
    inc al                                    ; include sentinel in the count
    ret

; ---------------------------------------------------------------------------
; SetSpriteMovementBytesToFE — movement byte 1 = $FE, byte 2 = [hSpriteMovementByte2],
; for sprite [hSpriteIndex]. pret: home/map_objects.asm:281.
;
; NOTE THE TWO POINTER FLAVOURS, which is why this cannot be copy-edited from the
; ...ToFF routine below without reading it: GetSpriteMovementByte1Pointer returns an
; EBP-RELATIVE offset (written [ebp+esi]) and GetSpriteMovementByte2Pointer returns a
; FLAT wMapSpriteData address (written [esi]). That asymmetry is the port's, recorded
; at those two routines.
;
; pret brackets the body with push hl / pop hl; ESI is HL, so the same bracket.
; UNREACHED, and so it is in pret — nothing calls it there either.
; Clobbers: AL, flags. ESI preserved.
; ---------------------------------------------------------------------------
SetSpriteMovementBytesToFE:
    push esi                                  ; push hl
    call GetSpriteMovementByte1Pointer
    mov byte [ebp + esi], 0xFE                ; ld [hl], $fe
    call GetSpriteMovementByte2Pointer
    mov al, [ebp + hSpriteMovementByte2]      ; ldh a, [hSpriteMovementByte2]
    mov [esi], al                             ; ld [hl], a  (flat — see above)
    pop esi                                   ; pop hl
    ret

; ---------------------------------------------------------------------------
; SetSpriteMovementBytesToFF — movement byte 1 = STAY ($ff), byte 2 = NONE ($00),
; for sprite [hSpriteIndex].
; pret: home/map_objects.asm:SetSpriteMovementBytesToFF
; Clobbers: AL, ESI, flags
; ---------------------------------------------------------------------------
SetSpriteMovementBytesToFF:
    call GetSpriteMovementByte1Pointer
    mov byte [ebp + esi], 0xFF                ; STAY
    call GetSpriteMovementByte2Pointer
    mov byte [esi], 0x00                      ; NONE (ESI = flat wMapSpriteData ptr, not EBP-relative)
    ret

; ---------------------------------------------------------------------------
; GetSpriteMovementByte1Pointer — ESI = EBP-rel offset of sprite [hSpriteIndex]
; movement byte 1 (wSpriteStateData2 + slot*0x10 + 6).
; pret: home/map_objects.asm:GetSpriteMovementByte1Pointer (swap a / add 6)
;
; SELECTOR (2026-08-17): this family reads hSpriteIndex — a raw SLOT number — not
; hCurrentSpriteOffset. The two are distinct, simultaneously-live HRAM bytes in
; pret (ram/hram.asm:65 vs :290): hCurrentSpriteOffset is the _UpdateSprites loop
; cursor, rewritten every iteration of the per-frame sprite walk, while
; hSpriteIndex is the caller-set selector every user of this family supplies.
; The offset cannot simply be baked into hSpriteIndex, because that byte IS
; hTextID (pret ASSERTs it at home/text_script.asm:8; gb_memmap.inc:625 encodes
; it) and must keep holding a small raw id for DisplayTextID.
; Out: ESI = offset   Clobbers: AL, ESI, flags
; ---------------------------------------------------------------------------
GetSpriteMovementByte1Pointer:
    mov al, [ebp + hSpriteIndex]              ; ldh a, [hSpriteIndex] — raw slot
    rol al, 4                                 ; swap a (rol-by-4 IS SM83 swap, wrap included)
    add al, SPRITESTATEDATA2_MOVEMENTBYTE1    ; add 6
    movzx esi, al                             ; ld l, a
    add esi, wSpriteStateData2                ; ld h, HIGH(wSpriteStateData2) (low byte is 0)
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
; Selector: [hSpriteIndex], as GetSpriteMovementByte1Pointer above — see the note
; there. This routine is the clearest evidence the offset encoding was wrong: it
; wants pret's RAW slot, so under the old hCurrentSpriteOffset selector it had to
; `shr esi, 4` to undo the port's own encoding before doing pret's arithmetic.
; Out: ESI = flat wMapSpriteData ptr   Clobbers: AL, ESI, flags
; ---------------------------------------------------------------------------
GetSpriteMovementByte2Pointer:
    mov al, [ebp + hSpriteIndex]                      ; ldh a, [hSpriteIndex] — raw slot
    dec al                                            ; dec a  (8-bit: slot 0 wraps to $ff, as pret)
    add al, al                                        ; add a  -> (slot-1)*2
    movzx esi, al                                     ; ld e, a / ld d, 0
    add esi, wMapSpriteData                           ; flat address; flags dead (ret follows)
    ret

; ---------------------------------------------------------------------------
; GetPointerWithinSpriteStateData{1,2} — pret home/map_objects.asm.
; ESI = EBP-relative offset of member [hSpriteDataOffset] of sprite
; [hSpriteIndex]. pret builds it as H = HIGH(wSpriteStateData\{1,2}) and
; L = (slot swapped) + member, which works because both tables are page-aligned
; ($C100/$C200) and slot*$10 + member never leaves the page.
;
; Selector is [hSpriteIndex], the RAW slot — same family, and same reasoning, as
; GetSpriteMovementByte1Pointer above.
; Out: ESI = offset   Clobbers: AL, ESI, flags
; ---------------------------------------------------------------------------
GetPointerWithinSpriteStateData1:
    mov esi, wSpriteStateData1          ; ld h, HIGH(wSpriteStateData1)
    jmp _GetPointerWithinSpriteStateData

GetPointerWithinSpriteStateData2:
    mov esi, wSpriteStateData2          ; ld h, HIGH(wSpriteStateData2)
    ; fallthrough — pret's own structure
_GetPointerWithinSpriteStateData:
    mov al, [ebp + hSpriteIndex]        ; ldh a, [hSpriteIndex]
    rol al, 4                           ; swap a  (rol-by-4 IS SM83 swap)
    add al, [ebp + hSpriteDataOffset]   ; add b   (b = member offset)
    movzx eax, al                       ; ld l, a — 8-bit, so it wraps in-page as pret does
    add esi, eax
    ret

; ---------------------------------------------------------------------------
; DisplayPokedex — pret home/map_objects.asm:126-128.
; In: AL = pokédex number (1-based). Out: farjp into _DisplayPokedex
; (engine/events/display_pokedex.asm) after stashing it in wPokedexNum.
; ---------------------------------------------------------------------------
DisplayPokedex:
    mov [ebp + wPokedexNum], al         ; ld [wPokedexNum], a
; DEVIATION{class=banking; pret=home/map_objects.asm:DisplayPokedex; behavior=jmp directly to _DisplayPokedex instead of the pret farjp; evidence=the DPMI model is flat so every routine is always addressable and Bankswitch has no port counterpart, same convention every other farjp site in this tree uses; lifetime=permanent flat-memory boundary}
    jmp _DisplayPokedex                 ; farjp _DisplayPokedex

; ---------------------------------------------------------------------------
; SetSpriteFacingDirection / SetSpriteFacingDirectionAndDelay — pret
; home/map_objects.asm. Write [hSpriteFacingDirection] into sprite
; [hSpriteIndex]'s facing-direction member; the ...AndDelay form then waits 6
; frames. Used by the map scripts to turn an NPC before it speaks or moves.
; ---------------------------------------------------------------------------
SetSpriteFacingDirectionAndDelay:
    call SetSpriteFacingDirection
    mov bl, 6                           ; ld c, 6 — 8-bit, DelayFrames' own counter
    jmp DelayFrames                     ; jp DelayFrames (tail call)

SetSpriteFacingDirection:
    mov byte [ebp + hSpriteDataOffset], SPRITESTATEDATA1_FACINGDIRECTION
    call GetPointerWithinSpriteStateData1
    mov al, [ebp + hSpriteFacingDirection]
    mov [ebp + esi], al                 ; ld [hl], a
    ret

; ---------------------------------------------------------------------------
; SetSpriteImageIndexAfterSettingFacingDirection — pret home/map_objects.asm:143.
; A CONTINUATION of SetSpriteFacingDirection, not a routine you call cold: it
; expects ESI (HL) still pointing at the facing-direction byte that routine just
; wrote, and steps it to the image-index byte in the same slot. Hence the
; difference-of-two-constants offset — pret writes exactly that expression.
;
; UNREACHED, and so it is in pret: nothing in the disassembly calls it. Ported
; because it is trivially portable, under the same rule as GetwMoves.
; In:  ESI = slot's facing-direction offset, AL = image index. Out: ESI advanced.
; ---------------------------------------------------------------------------
SetSpriteImageIndexAfterSettingFacingDirection:
    add esi, SPRITESTATEDATA1_IMAGEINDEX - SPRITESTATEDATA1_FACINGDIRECTION
    mov [ebp + esi], al                 ; ld [hl], a
    ret

; ---------------------------------------------------------------------------
; SpriteFunc_34a1 — pret home/map_objects.asm:SpriteFunc_34a1
; Computes sprite VRAM/image index offset based on sprite's image base offset
; in wSpriteStateData2 and stores into wSpriteStateData1 image index.
; Reads [hSpriteIndex] ($FF8C, aliased as hSpriteHeight in pret union) and
; [hSpriteImageIndex] ($FF8D, aliased as hSpriteOffset in pret union).
; ---------------------------------------------------------------------------
SpriteFunc_34a1:
    mov al, [ebp + hSpriteIndex]        ; ldh a, [hSpriteIndex]
    rol al, 4                           ; swap a
    add al, SPRITESTATEDATA2_IMAGEBASEOFFSET ; add $e
    movzx esi, al                       ; ld l, a / ld h, $c2
    add esi, wSpriteStateData2
    mov cl, [ebp + esi]                 ; ld c, [hl]
    dec cl                              ; dec c
    rol cl, 4                           ; swap c
    mov al, [ebp + hSpriteImageIndex]   ; ldh a, [hSpriteOffset]
    add cl, al                          ; add c / ld c, a
    mov al, [ebp + hSpriteIndex]        ; ldh a, [hSpriteHeight]
    rol al, 4                           ; swap a
    add al, SPRITESTATEDATA1_IMAGEINDEX ; add $2
    movzx esi, al                       ; ld l, a / dec h ($c1)
    add esi, wSpriteStateData1
    mov [ebp + esi], cl                 ; ld [hl], c
    ret
