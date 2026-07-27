; ===========================================================================
; hidden_events.asm — mirror of pret home/hidden_events.asm.
;
; Holds BOTH of that pret file's labels:
;   CheckForHiddenEventOrBookshelfOrCardKeyDoor, UpdateCinnabarGymGateTileBlocks
; Both are LINKED (overworld-events Stage 3). Their deps resolve: the Tier-2
; handler stubs + PrintBookshelfText / UpdateCinnabarGymGateTileBlocks_
; (src/engine/overworld/hidden_object_stubs.asm), JumpToAddress
; (src/home/bankswitch2.asm), and the linked GetTileAndCoordsInFrontOfPlayer
; predef (src/engine/overworld/player_state.asm).
;
; TWO FAMILIES THIS FILE USED TO CARRY, BOTH NOW IN THEIR OWN MIRRORS:
;   * CheckForHiddenEvent + CheckIfCoordsInFrontOfPlayerMatch are pret
;     engine/overworld/hidden_events.asm labels and moved to
;     src/engine/overworld/hidden_events.asm (s16 mirror repair). This file
;     externs CheckForHiddenEvent from there.
;   * ArePlayerCoordsInArray / CheckCoords / CheckBoulderCoords are pret
;     home/map_objects.asm labels and moved to src/home/map_objects.asm.
;
; The header also used to claim this file held CopySignData and SignLoop. It did
; not: those are pret home/overworld.asm labels living in src/home/overworld.asm,
; and only their orphaned comment banners were still here. Both banners are gone.
;
; Register map (SM83->x86): A->AL, HL->ESI, BC->BX (B=BH,C=BL), DE->DX (D=DH,E=DL).
; GB memory = [ebp + SYM] with SYM from gb_memmap.inc.
; ===========================================================================

%include "gb_memmap.inc"
%include "gb_macros.inc"

section .text

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
%ifndef W_HIDDEN_EVENT_FUNCTION_ROM_BANK
W_HIDDEN_EVENT_FUNCTION_ROM_BANK equ 0xCD3E ; wHiddenEventFunctionRomBank (golden 00:cd3e)
%endif
%ifndef W_SPRITE_PLAYER_FACING_DIR
W_SPRITE_PLAYER_FACING_DIR equ 0xC109   ; wSpritePlayerStateData1FacingDirection
%endif

extern CheckForHiddenEvent               ; src/engine/overworld/hidden_events.asm

global CheckForHiddenEventOrBookshelfOrCardKeyDoor
global UpdateCinnabarGymGateTileBlocks

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
