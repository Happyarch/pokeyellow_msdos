; pick_up_item.asm — faithful port of engine/events/pick_up_item.asm (pret).
;
; PickUpItem is the VISIBLE item-ball handler (overworld-events Stage 3 bullet 3).
; It runs as the `predef` inside PickUpItemText (a text_asm handler reached from
; the map text table via DisplayTextID). It reads the item id the map object
; carries in wMapSpriteExtraData, hands it to GiveItem, and on success hides the
; ball object and prints "<PLAYER> found <ITEM>!"; on a full bag it prints
; "No more room for items!". Distinct from the Red/Blue-style HiddenItems pickup.
;
; Register map (SM83 -> x86): a=AL, b=BH, c=BL, hl=ESI, de=EDX; GB memory is
; EBP-relative ([ebp+SYM]); HRAM ($FFxx) is reached the same way.
;
; PORT DEVIATIONS (both structural, no behaviour change):
;  * pret `predef HideObject` -> direct `call HideObject`. The port has no predef
;    dispatcher (src/engine/predefs.asm is dead); HideObject is a linked global
;    (src/engine/overworld/toggleable_objects.asm). Same trap noted in
;    itemfinder.asm / experience.asm — a predef call here would reload stale regs.
;  * pret prints via `call PrintText` with the message stream already the active
;    text box. The port's text_asm dispatch (text_script.asm) has NOT set the
;    msgbox projection before `call esi`, so PickUpItem points text_msgbox at the
;    overworld dialog itself (as trainer_engine / field_move_messages tails do)
;    before PrintText. FoundItemText/NoMoreRoomForItemText are generated flat
;    streams (assets/pickup_text.inc); their `_ref` gives the flat pointer.
;    (The pret `sound_get_item_1` jingle rides in that stream but sits past the
;    far text's TX_END, so — like every other port text-stream sound — it is not
;    played; TODO-HW audio-in-text-streams.)
;
; Build: nasm -f coff -I include/ -I . -o pick_up_item.o src/engine/events/pick_up_item.asm

bits 32

%include "gb_memmap.inc"
%include "m8_2_pending_symbols.inc"   ; wToggleableObjectList/Index, wMapSpriteExtraData

section .text

global PickUpItem

extern EnableAutoTextBoxDrawing        ; home/window.asm
extern GiveItem                        ; home/give.asm — b=item, c=qty; CF=success
extern HideObject                      ; overworld/toggleable_objects.asm (predef in pret)
extern PrintText                       ; home/window.asm — ESI = flat TX stream
extern text_msgbox                     ; home/text.asm — active msgbox projection
extern msgbox_dialog                   ; home/text.asm — overworld dialog projection
extern FoundItemText_ref               ; assets/pickup_text.inc — {ptr, len}
extern NoMoreRoomForItemText_ref       ; assets/pickup_text.inc — {ptr, len}

; ---------------------------------------------------------------------------
; PickUpItem — pret engine/events/pick_up_item.asm:PickUpItem.
; ---------------------------------------------------------------------------
PickUpItem:
    call EnableAutoTextBoxDrawing

    mov al, [ebp + hSpriteIndex]         ; ldh a, [hSpriteIndex]
    mov bh, al                           ; ld b, a
    mov esi, wToggleableObjectList       ; ld hl, wToggleableObjectList
.toggleableObjectsListLoop:
    mov al, [ebp + esi]                  ; ld a, [hli]
    inc esi
    cmp al, 0xFF                         ; cp $ff
    je .done                             ; ret z
    cmp al, bh                           ; cp b
    je .isToggleable                     ; jr z
    inc esi                              ; inc hl
    jmp .toggleableObjectsListLoop

.isToggleable:
    mov al, [ebp + esi]                  ; ld a, [hl]  (toggleable-object index)
    mov [ebp + hToggleableObjectIndex], al   ; ldh [hToggleableObjectIndex], a

    mov esi, wMapSpriteExtraData         ; ld hl, wMapSpriteExtraData
    mov al, [ebp + hSpriteIndex]         ; ldh a, [hSpriteIndex]
    dec al                               ; dec a
    add al, al                           ; add a  (index * 2)
    movzx edx, al                        ; ld d, 0 ; ld e, a
    add esi, edx                         ; add hl, de
    mov al, [ebp + esi]                  ; ld a, [hl]
    mov bh, al                           ; ld b, a  (item)
    mov bl, 1                            ; ld c, 1  (quantity)
    call GiveItem
    jnc .BagFull                         ; jr nc

    mov al, [ebp + hToggleableObjectIndex]      ; ldh a, [hToggleableObjectIndex]
    mov [ebp + wToggleableObjectIndex], al      ; ld [wToggleableObjectIndex], a
    call HideObject                              ; predef HideObject
    mov byte [ebp + wDoNotWaitForButtonPressAfterDisplayingText], 1
    mov esi, [FoundItemText_ref]                ; ld hl, FoundItemText
    jmp .print

.BagFull:
    mov esi, [NoMoreRoomForItemText_ref]        ; ld hl, NoMoreRoomForItemText
.print:
    mov dword [text_msgbox], msgbox_dialog      ; overworld dialog projection
    call PrintText
.done:
    ret
