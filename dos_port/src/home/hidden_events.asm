; ===========================================================================
; hidden_events.asm — signs + hidden-event / coord-array helpers (Wave 7, M7.2)
;
; Faithful translations of pret home/overworld.asm (SignLoop, CopySignData) and
; pret engine/overworld/hidden_events.asm + home/hidden_events.asm
; (CheckForHiddenEvent, CheckIfCoordsInFrontOfPlayerMatch,
; CheckForHiddenEventOrBookshelfOrCardKeyDoor, UpdateCinnabarGymGateTileBlocks).
;
; The pret home/map_objects.asm coord-array family this file used to carry
; (ArePlayerCoordsInArray, CheckCoords, CheckBoulderCoords) MOVED to its mirror,
; src/home/map_objects.asm, per the mirror rule.
;
; Both tiers are LINKED as of overworld-events Stage 3 (bullet 1):
;   * Sign helpers: CopySignData, SignLoop.  Self-contained (memmap symbols only);
;     LoadMapHeader calls CopySignData live and the A-press path calls SignLoop.
;   * Hidden-event dispatch: CheckForHiddenEvent, CheckIfCoordsInFrontOfPlayerMatch,
;     CheckForHiddenEventOrBookshelfOrCardKeyDoor,
;     UpdateCinnabarGymGateTileBlocks.  Their deps now resolve: the generated
;     HiddenEventMaps data (src/data/hidden_events_data.asm), the Tier-2 handler
;     stubs + PrintBookshelfText/UpdateCinnabarGymGateTileBlocks_ stubs
;     (src/engine/overworld/hidden_object_stubs.asm), JumpToAddress
;     (src/home/bankswitch.asm), and the linked GetTileAndCoordsInFrontOfPlayer
;     predef (src/engine/overworld/player_state.asm).
;
; Register map (SM83->x86): A->AL, HL->ESI, BC->BX (B=BH,C=BL), DE->DX (D=DH,E=DL).
; GB memory = [ebp + SYM] with SYM from gb_memmap.inc.
; ===========================================================================

%include "gb_memmap.inc"
%include "gb_macros.inc"

section .text

; ---------------------------------------------------------------------------
; CopySignData — copy the map header's sign block into WRAM.
; Pret ref: home/overworld.asm:CopySignData
;
; In:  ESI = flat (ebp-relative absolute) pointer to the sign block; each sign is
;            3 bytes: Y, X, textID.
;      [W_NUM_SIGNS] = number of signs (caller guarantees >= 1).
; Out: wSignCoords   <- interleaved (Y, X) pairs.
;      wSignTextIDs  <- one textID per sign.
;      ESI advanced past the block.
; Preserves EAX (LoadMapHeader keeps its header cursor there) + EBX/ECX/EDI.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; SignLoop — search for a sign at the coords the player is facing.
; Pret ref: home/overworld.asm:SignLoop
;
; In:  DH = Y, DL = X  (the 0-based map-block coords directly in front of the
;      player, i.e. pret's GetTileAndCoordsInFrontOfPlayer output d,e).
; Out: CF=1 and [hTextID] = the sign's text ID if a sign is at (DH,DL);
;      CF=0 otherwise.
; Clobbers EAX, ECX, ESI.  Preserves DX/EBX.
;
; CALLER (wired, fidelity Stage 1b): IsSpriteOrSignInFrontOfPlayer's sign branch
;   (engine/overworld/overworld.asm), reached from OverworldLoop's A-press dispatch
;   BEFORE the sprite scan (pret's order). It skips if [W_NUM_SIGNS] == 0, computes the
;   facing coords into DH/DL, calls here, and on CF=1 hands [hTextID] to
;   DoSignInteraction → DisplaySignText (overworld_text.asm).
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; ArePlayerCoordsInArray / CheckCoords / CheckBoulderCoords — MOVED to their
; mirror, src/home/map_objects.asm (mirror rule). They are pret
; home/map_objects.asm labels; the W_COORD_INDEX scaffold equ went with them, and
; nothing left in this file calls them.
; ---------------------------------------------------------------------------

; ===========================================================================
; DEEP tier — LINKED as of overworld-events Stage 3 (bullet 1). The generated
; HiddenEventMaps data + Tier-2 handler stubs landed, so the guard is retired.
; ===========================================================================

extern BankswitchCommon                 ; src/home/bankswitch2.asm (flat no-op)
extern PrintBookshelfText               ; src/engine/overworld/hidden_object_stubs.asm (stub → $ff)
extern JumpToAddress                    ; src/home/bankswitch2.asm
extern GetTileAndCoordsInFrontOfPlayer  ; src/engine/overworld/player_state.asm (linked predef)
extern UpdateCinnabarGymGateTileBlocks_ ; src/engine/overworld/hidden_object_stubs.asm (stub)
extern IsInArray                        ; src/home/array2.asm (map-id search, stride DE)
extern HiddenEventMaps                  ; assets/hidden_events.inc, %included by
                                        ; src/data/hidden_events_data.asm — generated flat
                                        ; {db map, dd HiddenEventsFor_<map>} table
                                        ; (gen_hidden_events.py). Per-map lists point at the
                                        ; Tier-2 handlers in hidden_object_stubs.asm.

; --- Deep-tier memmap symbols — golden sym-verified (were PLACEHOLDER) ---
%ifndef H_SPRITE_INDEX
H_SPRITE_INDEX              equ 0xFF8C   ; hSpriteIndex (golden 00:ff8c)
%endif
%ifndef H_ITEM_ALREADY_FOUND
H_ITEM_ALREADY_FOUND       equ 0xFFEB   ; hItemAlreadyFound (golden 00:ffeb)
%endif
%ifndef H_DIDNT_FIND_ANY_HIDDEN_EVENT
H_DIDNT_FIND_ANY_HIDDEN_EVENT equ 0xFFEE ; hDidntFindAnyHiddenEvent (golden 00:ffee)
%endif
%ifndef H_INTERACTED_WITH_BOOKSHELF
H_INTERACTED_WITH_BOOKSHELF equ 0xFFDB  ; hInteractedWithBookshelf (golden 00:ffdb)
%endif
%ifndef H_COORDS_IN_FRONT_OF_PLAYER_MATCH
H_COORDS_IN_FRONT_OF_PLAYER_MATCH equ 0xFFEA ; hCoordsInFrontOfPlayerMatch (golden 00:ffea)
%endif
%ifndef W_HIDDEN_EVENT_FUNCTION_ARGUMENT
W_HIDDEN_EVENT_FUNCTION_ARGUMENT equ 0xCD3D ; wHiddenEventFunctionArgument (golden 00:cd3d)
%endif
%ifndef W_HIDDEN_EVENT_FUNCTION_ROM_BANK
W_HIDDEN_EVENT_FUNCTION_ROM_BANK equ 0xCD3E ; wHiddenEventFunctionRomBank (golden 00:cd3e)
%endif
%ifndef W_HIDDEN_EVENT_INDEX
W_HIDDEN_EVENT_INDEX       equ 0xCD3F   ; wHiddenEventIndex (golden 00:cd3f)
%endif
%ifndef W_HIDDEN_EVENT_Y
W_HIDDEN_EVENT_Y           equ 0xCD40   ; wHiddenEventY (golden 00:cd40)
%endif
%ifndef W_HIDDEN_EVENT_X
W_HIDDEN_EVENT_X           equ 0xCD41   ; wHiddenEventX (golden 00:cd41)
%endif
%ifndef W_SPRITE_PLAYER_FACING_DIR
W_SPRITE_PLAYER_FACING_DIR equ 0xC109   ; wSpritePlayerStateData1FacingDirection
%endif

global CheckForHiddenEvent
global CheckIfCoordsInFrontOfPlayerMatch
global CheckForHiddenEventOrBookshelfOrCardKeyDoor
global UpdateCinnabarGymGateTileBlocks

; ---------------------------------------------------------------------------
; CheckForHiddenEvent (OW-3.3) — scan the current map's hidden-event list.
; Pret ref: engine/overworld/hidden_events.asm:CheckForHiddenEvent
; Stores $00 in [hDidntFindAnyHiddenEvent] on a match, else $ff; on a match
; returns ESI = handler pointer (and wHiddenEventFunctionArgument/RomBank set).
; DATA: HiddenEventMaps is externed and unresolved (deferred generator — see the
; extern note); until it lands this routine can't link — it stays under the M72
; guard. It is faithful and check-verified here.
; ---------------------------------------------------------------------------
CheckForHiddenEvent:
    ; zero the four consecutive HRAM cells hItemAlreadyFound..hDidntFindAnyHiddenEvent
    mov esi, H_ITEM_ALREADY_FOUND       ; ld hl, hItemAlreadyFound
    xor al, al
    mov [ebp + esi], al                 ; [hItemAlreadyFound]
    mov [ebp + esi + 1], al             ; [hSavedMapTextPtr]
    mov [ebp + esi + 2], al             ; [hSavedMapTextPtr + 1]
    mov [ebp + esi + 3], al             ; [hDidntFindAnyHiddenEvent]
    mov esi, HiddenEventMaps            ; ld hl, HiddenEventMaps (flat data ptr)
    ; pret stride is 3 (db map + dw same-bank ptr); the flat port has no banks, so
    ; the per-map pointer is a dd (see gen_hidden_events.py) → stride 5.
    mov edx, 5                          ; ld de, 5 (entry stride: db map + dd ptr)
    mov al, [ebp + W_CUR_MAP]
    call IsInArray                      ; CF=1 if wCurMap is in the array (ESI→match)
    jnc .noMatch                        ; jr nc
    ; ESI points at the matched map-id byte; the dw pointer follows.
    ; PROJ/flat: pret's `dw HiddenEventsFor_<map>` GB pointer is a flat `dd` in the
    ; generated data, so advance 1 byte then load a 4-byte flat pointer.
    inc esi                             ; inc hl (skip map id)
    mov esi, [esi]                      ; hl = [hl] (flat dd pointer to this map's list)
    push esi                            ; push hl
    mov esi, W_HIDDEN_EVENT_FUNCTION_ARGUMENT ; zero arg/rombank/index (3 consecutive)
    xor al, al
    mov [ebp + esi], al                 ; wHiddenEventFunctionArgument
    mov [ebp + esi + 1], al             ; wHiddenEventFunctionRomBank
    mov [ebp + esi + 2], al             ; wHiddenEventIndex
    pop esi                             ; pop hl (list ptr)
.hiddenEventLoop:
    mov al, [esi]                       ; ld a,[hli] — entry Y (flat data read)
    inc esi
    cmp al, 0xFF
    je .noMatch                         ; jr z (end of list)
    mov [ebp + W_HIDDEN_EVENT_Y], al
    mov bh, al                          ; ld b, a
    mov al, [esi]                       ; ld a,[hli] — entry X
    inc esi
    mov [ebp + W_HIDDEN_EVENT_X], al
    mov bl, al                          ; ld c, a
    call CheckIfCoordsInFrontOfPlayerMatch
    mov al, [ebp + H_COORDS_IN_FRONT_OF_PLAYER_MATCH]
    test al, al
    jz .foundMatchingEvent              ; jr z ($00 = match)
    ; skip this entry's arg/rombank/dd-handler (pret: 4 inc hl over arg,bank,dw;
    ; flat dd handler makes it arg + bank + 4 = 6 bytes).
    add esi, 6
    inc byte [ebp + W_HIDDEN_EVENT_INDEX]
    jmp .hiddenEventLoop
.foundMatchingEvent:
    mov al, [esi]                       ; ld a,[hli] — argument
    inc esi
    mov [ebp + W_HIDDEN_EVENT_FUNCTION_ARGUMENT], al
    mov al, [esi]                       ; ld a,[hli] — rom bank
    inc esi
    mov [ebp + W_HIDDEN_EVENT_FUNCTION_ROM_BANK], al
    mov esi, [esi]                      ; hl = [hl] flat dd handler pointer
    ret
.noMatch:
    mov byte [ebp + H_DIDNT_FIND_ANY_HIDDEN_EVENT], 0xFF
    ret

; ---------------------------------------------------------------------------
; CheckIfCoordsInFrontOfPlayerMatch (OW-3.3) — does the tile in front of the
; player match Y in B (BH) and X in C (BL)?
; Pret ref: engine/overworld/hidden_events.asm:CheckIfCoordsInFrontOfPlayerMatch
; [hCoordsInFrontOfPlayerMatch] = $00 match / $ff no match.
; ---------------------------------------------------------------------------
CheckIfCoordsInFrontOfPlayerMatch:
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
    cmp al, SPRITE_FACING_UP
    je .facingUp
    cmp al, SPRITE_FACING_LEFT
    je .facingLeft
    cmp al, SPRITE_FACING_RIGHT
    je .facingRight
; facing down
    mov al, [ebp + W_Y_COORD]
    inc al
    jmp .upDownCommon
.facingUp:
    mov al, [ebp + W_Y_COORD]
    dec al
.upDownCommon:
    cmp al, bh                          ; cp b
    jne .didNotMatch
    mov al, [ebp + W_X_COORD]
    cmp al, bl                          ; cp c
    jne .didNotMatch
    jmp .matched
.facingLeft:
    mov al, [ebp + W_X_COORD]
    dec al
    jmp .leftRightCommon
.facingRight:
    mov al, [ebp + W_X_COORD]
    inc al
.leftRightCommon:
    cmp al, bl                          ; cp c
    jne .didNotMatch
    mov al, [ebp + W_Y_COORD]
    cmp al, bh                          ; cp b
    jne .didNotMatch
.matched:
    xor al, al
    jmp .storeMatch
.didNotMatch:
    mov al, 0xFF
.storeMatch:
    mov [ebp + H_COORDS_IN_FRONT_OF_PLAYER_MATCH], al
    ret

; ---------------------------------------------------------------------------
; CheckForHiddenEventOrBookshelfOrCardKeyDoor — A-press hidden-object dispatch.
; Pret ref: home/hidden_events.asm:CheckForHiddenEventOrBookshelfOrCardKeyDoor
;
; Faithful structure; deep deps are extern NI stubs.  Bankswitch is a no-op under
; the flat memory model (kept for call fidelity).
; Out: AL / [hItemAlreadyFound] per pret.
; ---------------------------------------------------------------------------
CheckForHiddenEventOrBookshelfOrCardKeyDoor:
    mov al, [ebp + H_LOADED_ROM_BANK]
    push eax                            ; ldh a,[hLoadedROMBank] / push af
    mov al, [ebp + H_JOY_HELD]
    test al, PAD_A
    jz .nothingFound
    ; A button is pressed
    mov al, 0                           ; BANK(CheckForHiddenEvent) — no-op under flat mem
    call BankswitchCommon
    call CheckForHiddenEvent
    mov al, [ebp + H_DIDNT_FIND_ANY_HIDDEN_EVENT]
    test al, al
    jnz .hiddenEventNotFound
    mov byte [ebp + H_ITEM_ALREADY_FOUND], 0
    mov al, [ebp + W_HIDDEN_EVENT_FUNCTION_ROM_BANK]
    call BankswitchCommon
    call JumpToAddress
    mov al, [ebp + H_ITEM_ALREADY_FOUND]
    jmp .done
.hiddenEventNotFound:
    call GetTileAndCoordsInFrontOfPlayer ; predef in pret
    call PrintBookshelfText
    mov al, [ebp + H_INTERACTED_WITH_BOOKSHELF]
    test al, al
    jz .done
.nothingFound:
    mov al, 0xFF
.done:
    mov [ebp + H_ITEM_ALREADY_FOUND], al
    pop eax                             ; pop af (restore loaded bank)
    call BankswitchCommon
    ret

; ---------------------------------------------------------------------------
; UpdateCinnabarGymGateTileBlocks — thin wrapper over the (NI) _ variant.
; Pret ref: home/hidden_events.asm:UpdateCinnabarGymGateTileBlocks
; ---------------------------------------------------------------------------
UpdateCinnabarGymGateTileBlocks:
    call UpdateCinnabarGymGateTileBlocks_
    ret
