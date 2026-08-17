; CopycatsHouse2F.asm — translated from pret scripts/CopycatsHouse2F.asm by dos_port/tools/sm83xlat.
;
; ONE-SHOT OUTPUT, NOW HAND-MAINTAINED. The transpiler ran once at the SHA
; recorded in dos_port/tools/sm83xlat/README.md and is not re-run; this file is
; ordinary Tier-2 source and editing it is the normal way it changes. There is
; deliberately no DO NOT EDIT header.
;
; Every pret label is preserved verbatim so the file stays line-for-line
; cross-referenceable against the disassembly.
;
; Regions the tool could not lower WITH CERTAINTY are reproduced below as
; commented pret source under a `; BAIL[reason]` banner, and define NO symbol —
; so a reference to one is a link error rather than a plausible wrong lowering.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "events.inc"
%include "assets/event_constants.inc"


global CopycatsHouse2FCopycatText
global CopycatsHouse2FDoduoText
global CopycatsHouse2FPCText
global CopycatsHouse2FRareDollText
global CopycatsHouse2FSNESText
global CopycatsHouse2F_Script
global CopycatsHouse2F_TextPointers

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern IsItemInBag   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern RemoveItemByID   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FCopycatDoYouLikePokemonText   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FCopycatReceivedTM31Text   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FCopycatTM31Explanation1Text   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FCopycatTM31Explanation2Text   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FCopycatTM31NoRoomText   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FCopycatTM31PreReceiveText   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FDoduoText   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FPCCantSeeText   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FPCMySecretsText   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FRareDollText   ; NOT YET DEFINED IN THE PORT
extern _CopycatsHouse2FSNESText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
CopycatsHouse2F_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
CopycatsHouse2F_TextPointers:
    dd CopycatsHouse2FCopycatText
    dd CopycatsHouse2FDoduoText
    dd CopycatsHouse2FRareDollText
    dd CopycatsHouse2FRareDollText
    dd CopycatsHouse2FRareDollText
    dd CopycatsHouse2FSNESText
    dd CopycatsHouse2FPCText

%assign event_byte -1
%assign event_byte_a -1
CopycatsHouse2FCopycatText:
    CheckEvent EVENT_GOT_TM31
    jnz .got_item
    mov al, 1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, .DoYouLikePokemonText
    call PrintText
    mov bh, 51
    call IsItemInBag
    jz .done
    mov esi, .TM31PreReceiveText
    call PrintText
    mov bx, ((233) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov esi, .ReceivedTM31Text
    call PrintText
    mov al, 51
    mov [ebp + hItemToRemoveID], al
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call RemoveItemByID
    SetEvent EVENT_GOT_TM31
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov esi, .TM31NoRoomText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.got_item:
    mov esi, .TM31Explanation2Text
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.DoYouLikePokemonText:
    text_far _CopycatsHouse2FCopycatDoYouLikePokemonText
    text_end
.TM31PreReceiveText:
    text_far _CopycatsHouse2FCopycatTM31PreReceiveText
    text_end
.ReceivedTM31Text:
    text_far _CopycatsHouse2FCopycatReceivedTM31Text
    sound_get_item_1
.TM31Explanation1Text:
    text_far _CopycatsHouse2FCopycatTM31Explanation1Text
    text_waitbutton
    text_end
.TM31Explanation2Text:
    text_far _CopycatsHouse2FCopycatTM31Explanation2Text
    text_end
.TM31NoRoomText:
    text_far _CopycatsHouse2FCopycatTM31NoRoomText
    text_waitbutton
    text_end
CopycatsHouse2FDoduoText:
    text_far _CopycatsHouse2FDoduoText
    text_end
CopycatsHouse2FRareDollText:
    text_far _CopycatsHouse2FRareDollText
    text_end
CopycatsHouse2FSNESText:
    text_far _CopycatsHouse2FSNESText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CopycatsHouse2FPCText:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    mov esi, .CantSeeText
    jnz .notUp
    mov esi, .MySecretsText
.notUp:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.MySecretsText:
    text_far _CopycatsHouse2FPCMySecretsText
    text_end
.CantSeeText:
    text_far _CopycatsHouse2FPCCantSeeText
    text_end
