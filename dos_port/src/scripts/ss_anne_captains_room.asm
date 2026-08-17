; SSAnneCaptainsRoom.asm — translated from pret scripts/SSAnneCaptainsRoom.asm by dos_port/tools/sm83xlat.
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

%include "assets/audio_constants.inc"

global SSAnneCaptainsRoomCaptainText
global SSAnneCaptainsRoomEventScript
global SSAnneCaptainsRoomRubCaptainsBackText
global SSAnneCaptainsRoom_Script
global SSAnneCaptainsRoom_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic   ; NOT YET DEFINED IN THE PORT
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SSAnneCaptainsRoomCaptainHM01NoRoomText   ; NOT YET DEFINED IN THE PORT
extern SSAnneCaptainsRoomCaptainIFeelMuchBetterText   ; NOT YET DEFINED IN THE PORT
extern SSAnneCaptainsRoomCaptainNotSickAnymoreText   ; NOT YET DEFINED IN THE PORT
extern SSAnneCaptainsRoomCaptainReceivedHM01Text   ; NOT YET DEFINED IN THE PORT
extern SSAnneCaptainsRoomSeasickBookText   ; NOT YET DEFINED IN THE PORT
extern SSAnneCaptainsRoomTrashText   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SSAnneCaptainsRoomCaptainIFeelMuchBetterText   ; NOT YET DEFINED IN THE PORT
extern _SSAnneCaptainsRoomCaptainReceivedHM01Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnneCaptainsRoomRubCaptainsBackText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
SSAnneCaptainsRoom_Script:
    call SSAnneCaptainsRoomEventScript
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
SSAnneCaptainsRoomEventScript:
    CheckEvent EVENT_GOT_HM01
    jz .nr_7
        ret
.nr_7:
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_NO_NPC_FACE_PLAYER))
    ret

%assign event_byte -1
SSAnneCaptainsRoom_TextPointers:
    dd SSAnneCaptainsRoomCaptainText
    dd SSAnneCaptainsRoomTrashText
    dd SSAnneCaptainsRoomSeasickBookText

%assign event_byte -1
SSAnneCaptainsRoomCaptainText:
    CheckEvent EVENT_GOT_HM01
    jnz .got_item
    mov esi, SSAnneCaptainsRoomRubCaptainsBackText
    call PrintText
    mov esi, SSAnneCaptainsRoomCaptainIFeelMuchBetterText
    call PrintText
    mov bx, ((197) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov esi, SSAnneCaptainsRoomCaptainReceivedHM01Text
    call PrintText
    SetEvent EVENT_GOT_HM01
    mov esi, wStatusFlags3
    and byte [ebp + esi], ~(1 << (BIT_NO_NPC_FACE_PLAYER)) & 0xFF
    jmp .done

%assign event_byte -1
.bag_full:
    mov esi, SSAnneCaptainsRoomCaptainHM01NoRoomText
    call PrintText
    jmp .done

%assign event_byte -1
.got_item:
    mov esi, SSAnneCaptainsRoomCaptainNotSickAnymoreText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
SSAnneCaptainsRoomRubCaptainsBackText:
    text_far _SSAnneCaptainsRoomRubCaptainsBackText

; ---------------------------------------------------------------------------
; BAIL[bank-expression] scripts/SSAnneCaptainsRoom.asm:anon (scripts/SSAnneCaptainsRoom.asm:48-67) — at scripts/SSAnneCaptainsRoom.asm:49: BANK("Audio Engine 3")
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wAudioROMBank]
; PRET| 	cp BANK("Audio Engine 3")
; PRET| 	ld [wAudioSavedROMBank], a
; PRET| 	jr nz, .not_audio_engine_3
; PRET| 	call StopAllMusic
; PRET| 	ld a, BANK(Music_PkmnHealed)
; PRET| 	ld [wAudioROMBank], a
; PRET| .not_audio_engine_3
; PRET| 	ld a, MUSIC_PKMN_HEALED
; PRET| 	ld [wNewSoundID], a
; PRET| 	call PlaySound
; PRET| .loop
; PRET| 	ld a, [wChannelSoundIDs]
; PRET| 	cp MUSIC_PKMN_HEALED
; PRET| 	jr z, .loop
; PRET| 	call PlayDefaultMusic
; PRET| 	SetEvent EVENT_RUBBED_CAPTAINS_BACK
; PRET| 	ld hl, wStatusFlags3
; PRET| 	res BIT_NO_NPC_FACE_PLAYER, [hl]
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] SSAnneCaptainsRoomCaptainIFeelMuchBetterText (scripts/SSAnneCaptainsRoom.asm:70-92) — at scripts/SSAnneCaptainsRoom.asm:75: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SSAnneCaptainsRoomCaptainIFeelMuchBetterText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneCaptainsRoomCaptainReceivedHM01Text:
; PRET| 	text_far _SSAnneCaptainsRoomCaptainReceivedHM01Text
; PRET| 	sound_get_key_item
; PRET| 	text_end
; PRET| 
; PRET| SSAnneCaptainsRoomCaptainNotSickAnymoreText:
; PRET| 	text_far _SSAnneCaptainsRoomCaptainNotSickAnymoreText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneCaptainsRoomCaptainHM01NoRoomText:
; PRET| 	text_far _SSAnneCaptainsRoomCaptainHM01NoRoomText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneCaptainsRoomTrashText:
; PRET| 	text_far _SSAnneCaptainsRoomTrashText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneCaptainsRoomSeasickBookText:
; PRET| 	text_far _SSAnneCaptainsRoomSeasickBookText
; PRET| 	text_end
