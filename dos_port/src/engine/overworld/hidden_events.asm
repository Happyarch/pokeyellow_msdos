; hidden_events.asm — mirror of pret engine/overworld/hidden_events.asm.
;
; Holds BOTH of that pret file's labels, in pret order:
;   CheckForHiddenEvent (:2), CheckIfCoordsInFrontOfPlayerMatch (:63)
;
; Arrived in the s16 mirror repair from src/home/hidden_events.asm, which keeps
; its own two pret home/hidden_events.asm labels
; (CheckForHiddenEventOrBookshelfOrCardKeyDoor, UpdateCinnabarGymGateTileBlocks)
; and now externs CheckForHiddenEvent from here.
;
; Register map (SM83->x86): A->AL, HL->ESI, BC->BX (B=BH,C=BL), DE->DX (D=DH,E=DL).
; GB memory = [ebp + SYM] with SYM from gb_memmap.inc.
;
; Build: nasm -f coff -I include/ -I . -o hidden_events.o \
;              src/engine/overworld/hidden_events.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

extern IsInArray                        ; src/home/array2.asm (map-id search, stride DE)
extern HiddenEventMaps                  ; assets/hidden_events.inc, %included by
                                        ; src/data/hidden_events_data.asm — generated flat
                                        ; {db map, dd HiddenEventsFor_<map>} table
                                        ; (gen_hidden_events.py). Per-map lists point at the
                                        ; Tier-2 handlers in hidden_object_stubs.asm.

; --- Deep-tier memmap symbols — golden sym-verified. The three guarded blocks
; that src/home/hidden_events.asm ALSO needs are copied, not moved; the rest came
; across whole because nothing left there reads them. All are %ifndef-guarded, so
; the duplicate definitions are inert if the shared includes ever gain them.
%ifndef H_ITEM_ALREADY_FOUND
H_ITEM_ALREADY_FOUND       equ 0xFFEB   ; hItemAlreadyFound (golden 00:ffeb)
%endif
%ifndef H_DIDNT_FIND_ANY_HIDDEN_EVENT
H_DIDNT_FIND_ANY_HIDDEN_EVENT equ 0xFFEE ; hDidntFindAnyHiddenEvent (golden 00:ffee)
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

global CheckForHiddenEvent
global CheckIfCoordsInFrontOfPlayerMatch

section .text

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
