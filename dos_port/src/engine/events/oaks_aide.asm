; ===========================================================================
; oaks_aide.asm — pret mirror of engine/events/oaks_aide.asm.
;
; OaksAideScript: the generic "Oak's Aide" NPC handler shared by every Route
; gate aide. Asks YES/NO, and if YES, checks the caller-supplied requirement
; (hOaksAideRequirement, aliased to hOaksAideResult — pret writes the
; requirement in before the call and the routine overwrites it with the
; result) against CountSetBits on wPokedexOwned; on success calls GiveItem
; with the caller-supplied hOaksAideRewardItem.
;
; TWO-TIER RULE (CLAUDE.md): the six text streams are Tier-1 DATA, generated
; by tools/generators/gen_overworld_strings.py into
; assets/oaks_aide_text.inc (%included below, section .data). This file is
; the Tier-2 code: OaksAideScript plus pret's six text_far wrappers.
;
; Register map (CLAUDE.md): A->AL, B->BH, C->BL, HL->ESI; GB memory is
; [ebp + SYM]. Text stream labels are FLAT .data pointers in this port, so
; pret's `ld hl, OaksAideHiText` becomes `mov esi, OaksAideHiText` directly
; (no ebp bias — see asm-translation skill, "A FLAT program-image pointer").
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "assets/script_constants.inc"   ; OAKS_AIDE_* (constants/script_constants.asm:49-52)
%include "gb_text.inc"                  ; text_far / text_end / sound_get_item_1

global OaksAideScript

extern PrintText                        ; src/home/window.asm
extern YesNoChoice                      ; src/home/yes_no.asm
extern CountSetBits                     ; src/home/count_set_bits.asm
extern GiveItem                         ; src/home/give.asm

section .text

; ---------------------------------------------------------------------------
; OaksAideScript — pret engine/events/oaks_aide.asm.
;
; hOaksAideRequirement/hOaksAideResult alias one HRAM byte (gb_memmap.inc):
; caller writes the requirement in, this routine overwrites it with the
; result out. The OAKS_AIDE_* result constants are not defined anywhere in
; this tree (grepped include/ and assets/ — the only other reference is a
; bare comment in src/scripts/route_11_gate_2f.asm); per pret ram/hram.asm
; they are $01 (got item), $80 (not enough owned mons), $FF (refused), and
; 0/xor a (bag full). Left as numeric literals with a comment naming the
; pret constant, per the task's explicit instruction not to invent names in
; a .asm — the root agent should centralize these if/when other callers need
; them.
; ---------------------------------------------------------------------------
OaksAideScript:
    mov esi, OaksAideHiText              ; ld hl, OaksAideHiText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]     ; ld a, [wCurrentMenuItem]
    test al, al                          ; and a
    jnz .choseNo

    mov esi, wPokedexOwned               ; ld hl, wPokedexOwned  (EBP-relative offset value)
    mov bh, wPokedexOwnedEnd - wPokedexOwned ; ld b, wPokedexOwnedEnd - wPokedexOwned
    call CountSetBits

    mov al, [ebp + wNumSetBits]          ; ld a, [wNumSetBits]
    mov [ebp + hOaksAideNumMonsOwned], al ; ldh [hOaksAideNumMonsOwned], a
    mov bh, al                           ; ld b, a
    mov al, [ebp + hOaksAideRequirement] ; ldh a, [hOaksAideRequirement]
    cmp al, bh                           ; cp b
    jz .giveItem
    jae .notEnoughOwnedMons              ; jr nc, .notEnoughOwnedMons (unsigned: A > B here, == already handled by jz)

.giveItem:
    mov esi, OaksAideHereYouGoText       ; ld hl, OaksAideHereYouGoText
    call PrintText
    mov al, [ebp + hOaksAideRewardItem]  ; ldh a, [hOaksAideRewardItem]
    mov bh, al                           ; ld b, a
    mov bl, 1                            ; ld c, 1
    call GiveItem                        ; CF: set = success, clear = bag full
    jae .bagFull                         ; jr nc, .bagFull (nothing between call and here disturbs CF)
    mov esi, OaksAideGotItemText         ; ld hl, OaksAideGotItemText
    call PrintText
    mov al, OAKS_AIDE_GOT_ITEM           ; ld a, OAKS_AIDE_GOT_ITEM
    jmp .done

.bagFull:
    mov esi, OaksAideNoRoomText          ; ld hl, OaksAideNoRoomText
    call PrintText
    xor al, al                           ; xor a ; OAKS_AIDE_BAG_FULL is 0, and pret
                                         ; writes it as `xor a` — kept, it also clears flags as pret does
    jmp .done

.notEnoughOwnedMons:
    mov esi, OaksAideUhOhText            ; ld hl, OaksAideUhOhText
    call PrintText
    mov al, OAKS_AIDE_NOT_ENOUGH_MONS    ; ld a, OAKS_AIDE_NOT_ENOUGH_MONS
    jmp .done

.choseNo:
    mov esi, OaksAideComeBackText        ; ld hl, OaksAideComeBackText
    call PrintText
    mov al, OAKS_AIDE_REFUSED            ; ld a, OAKS_AIDE_REFUSED

.done:
    mov [ebp + hOaksAideResult], al      ; ldh [hOaksAideResult], a
    ret

; ---------------------------------------------------------------------------
section .data

%include "assets/oaks_aide_text.inc"

OaksAideHiText:
    text_far _OaksAideHiText
    text_end

OaksAideUhOhText:
    text_far _OaksAideUhOhText
    text_end

OaksAideComeBackText:
    text_far _OaksAideComeBackText
    text_end

OaksAideHereYouGoText:
    text_far _OaksAideHereYouGoText
    text_end

OaksAideGotItemText:
    text_far _OaksAideGotItemText
    sound_get_item_1
    text_end

OaksAideNoRoomText:
    text_far _OaksAideNoRoomText
    text_end
