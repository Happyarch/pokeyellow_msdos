; ===========================================================================
; hidden_events.asm — signs + hidden-event / coord-array helpers (Wave 7, M7.2)
;
; Faithful translations of pret home/overworld.asm (SignLoop, CopySignData) and
; pret home/map_objects.asm / home/hidden_events.asm (CheckCoords family,
; CheckForHiddenEventOrBookshelfOrCardKeyDoor, UpdateCinnabarGymGateTileBlocks).
;
; TWO BUILD TIERS in this one file:
;   * LINKABLE (default assembly): CopySignData, SignLoop, ArePlayerCoordsInArray,
;     CheckCoords.  These are fully self-contained (memmap symbols only) and are
;     linked so LoadMapHeader can call CopySignData live.  They have no live
;     interaction caller yet (SignLoop is wired later — see overworld_text.asm),
;     but an unused global links cleanly.
;   * DEEP (guarded by %ifdef M72_HIDDEN_EVENTS_DEEP — NOT in the default build):
;     CheckBoulderCoords, CheckForHiddenEventOrBookshelfOrCardKeyDoor,
;     UpdateCinnabarGymGateTileBlocks.  These depend on NI pret routines
;     (CheckForHiddenEvent, PrintBookshelfText, JumpToAddress,
;     GetTileAndCoordsInFrontOfPlayer predef, UpdateCinnabarGymGateTileBlocks_)
;     and on the not-yet-ported boulder/strength subsystem, so they are excluded
;     from the linked image and only assembled under `make check` with the define.
;
; Register map (SM83->x86): A->AL, HL->ESI, BC->BX (B=BH,C=BL), DE->DX (D=DH,E=DL).
; GB memory = [ebp + SYM] with SYM from gb_memmap.inc.
; ===========================================================================

%include "gb_memmap.inc"
%include "gb_macros.inc"

section .text

global CopySignData
global SignLoop
global ArePlayerCoordsInArray
global CheckCoords

; ---------------------------------------------------------------------------
; Scaffold memmap symbols not yet in gb_memmap.inc.
; TODO(M7.2): root must add these to gb_memmap.inc with sym-verified pret
; addresses before any of these routines is wired to a live caller.  They are
; guarded so this file assembles standalone; the placeholder addresses are inert
; today because no linked caller reads/writes them.
; ---------------------------------------------------------------------------
%ifndef W_COORD_INDEX
W_COORD_INDEX   equ 0xD152   ; wCoordIndex  — PLACEHOLDER, sym-verify vs pret Yellow
%endif

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
CopySignData:
    push eax
    push ebx
    push ecx
    push edi
    lea edi, [ebp + W_SIGN_COORDS]      ; de = wSignCoords
    lea ebx, [ebp + W_SIGN_TEXT_IDS]    ; bc = wSignTextIDs
    movzx ecx, byte [ebp + W_NUM_SIGNS]
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
; SignLoop — search for a sign at the coords the player is facing.
; Pret ref: home/overworld.asm:SignLoop
;
; In:  DH = Y, DL = X  (the 0-based map-block coords directly in front of the
;      player, i.e. pret's GetTileAndCoordsInFrontOfPlayer output d,e).
; Out: CF=1 and [hTextID] = the sign's text ID if a sign is at (DH,DL);
;      CF=0 otherwise.
; Clobbers EAX, ECX, ESI.  Preserves DX/EBX.
;
; INTEGRATION (future wire — this routine has no live caller yet):
;   the A-press interaction path (an IsSpriteOrSignInFrontOfPlayer equivalent,
;   called from OverworldLoop before/alongside CheckNPCInteraction) should:
;     1. skip if [W_NUM_SIGNS] == 0,
;     2. compute the facing coords into DH/DL,
;     3. call SignLoop; if CF=1, set up the font/freeze exactly like
;        CheckNPCInteraction, then call DisplaySignText (overworld_text.asm).
; ---------------------------------------------------------------------------
SignLoop:
    lea esi, [ebp + W_SIGN_COORDS]      ; hl = wSignCoords
    mov cl, [ebp + W_NUM_SIGNS]         ; CL = remaining count (b)
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
    mov al, [ebp + eax + W_SIGN_TEXT_IDS]
    mov [ebp + hTextID], al
    stc
    ret
.retry:
    dec cl
    jnz .signLoop
    clc
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

; ===========================================================================
; DEEP tier — excluded from the linked image (unported deps).  Assembled only
; under `make check` with -DM72_HIDDEN_EVENTS_DEEP.
; ===========================================================================
%ifdef M72_HIDDEN_EVENTS_DEEP

extern BankswitchCommon                 ; ported (Wave 0)
extern CheckForHiddenEvent              ; NI — hidden-object scan
extern PrintBookshelfText               ; NI — bookshelf / interactable BG dialog
extern JumpToAddress                    ; NI — indirect JP for hidden-event fn ptr
extern GetTileAndCoordsInFrontOfPlayer  ; NI — predef (front tile+coords)
extern UpdateCinnabarGymGateTileBlocks_ ; NI — Cinnabar gym gate tile flip

; --- Scaffold memmap symbols for the deep tier (TODO: sym-verify + add to memmap) ---
%ifndef H_SPRITE_INDEX
H_SPRITE_INDEX              equ 0xFF8F   ; hSpriteIndex — PLACEHOLDER, sym-verify
%endif
%ifndef H_ITEM_ALREADY_FOUND
H_ITEM_ALREADY_FOUND       equ 0xFFA0   ; hItemAlreadyFound — PLACEHOLDER
%endif
%ifndef H_DIDNT_FIND_ANY_HIDDEN_EVENT
H_DIDNT_FIND_ANY_HIDDEN_EVENT equ 0xFFA1 ; hDidntFindAnyHiddenEvent — PLACEHOLDER
%endif
%ifndef H_INTERACTED_WITH_BOOKSHELF
H_INTERACTED_WITH_BOOKSHELF equ 0xFFA2  ; hInteractedWithBookshelf — PLACEHOLDER
%endif
%ifndef W_HIDDEN_EVENT_FUNCTION_ROM_BANK
W_HIDDEN_EVENT_FUNCTION_ROM_BANK equ 0xD3A5 ; wHiddenEventFunctionRomBank — PLACEHOLDER
%endif

global CheckBoulderCoords
global CheckForHiddenEventOrBookshelfOrCardKeyDoor
global UpdateCinnabarGymGateTileBlocks

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

%endif ; M72_HIDDEN_EVENTS_DEEP
