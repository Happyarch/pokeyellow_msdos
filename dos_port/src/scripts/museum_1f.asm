; Museum1F.asm — translated from pret scripts/Museum1F.asm, scripts/Museum1F_2.asm by dos_port/tools/sm83xlat.
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

global Museum1FDefaultScript
global Museum1FGamblerText
global Museum1FNoopScript
global Museum1FOldAmberText
global Museum1FPrintGamblerText
global Museum1FPrintOldAmberText
global Museum1FPrintScientist3Text
global Museum1FScientist1Text
global Museum1FScientist2Text
global Museum1FScientist3Text
global Museum1F_Script
global Museum1F_ScriptPointers
global Museum1F_TextPointers

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern DisplayTextBoxID   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern HasEnoughMoney   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern Museum1FPrintScientist1Text   ; NOT YET DEFINED IN THE PORT
extern Museum1FPrintScientist2Text   ; NOT YET DEFINED IN THE PORT
extern PlaySoundWaitForCurrent   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern SubBCDPredef   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _Museum1FGamblerText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FOldAmberText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1AmberIsFossilizedTreeSapText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1ComeAgainText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1DoYouKnowWhatAmberIsText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1DontHaveEnoughMoneyText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1GoToOtherSideText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1TakePlentyOfTimeText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1ThankYouText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1TheresALabSomewhereText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1WouldYouLikeToComeInText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist2ReceivedOldAmberText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist2TakeThisToAPokemonLabText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist3Text   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_MUSEUM1F_NOOP                           equ 1
TEXT_MUSEUM1F_SCIENTIST1                       equ 1

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wMuseum1FCurScript                             equ 0xD618
wPriceTemp                                     equ 0xCD3D

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Museum1F_Script:
    mov al, 1 << BIT_NO_AUTO_TEXT_BOX
    mov [ebp + wAutoTextBoxDrawingControl], al
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, Museum1F_ScriptPointers
    mov al, [ebp + wMuseum1FCurScript]
    call CallFunctionInTable
    ret

Museum1F_ScriptPointers:
    dd Museum1FDefaultScript
    dd Museum1FNoopScript

Museum1FDefaultScript:
    mov al, [ebp + wYCoord]
    cmp al, 4
    jz .nr_19
        ret
.nr_19:
    mov al, [ebp + wXCoord]
    cmp al, 9
    jz .continue
    mov al, [ebp + wXCoord]
    cmp al, 10
    jz .nr_25
        ret
.nr_25:
.continue:
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, TEXT_MUSEUM1F_SCIENTIST1
    mov [ebp + hTextID], al
    jmp DisplayTextID

Museum1FNoopScript:
    ret

Museum1F_TextPointers:
    dd Museum1FScientist1Text
    dd Museum1FGamblerText
    dd Museum1FScientist2Text
    dd Museum1FScientist3Text
    dd Museum1FOldAmberText

Museum1FScientist1Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Museum1FPrintScientist1Text
    jmp TextScriptEnd

Museum1FGamblerText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Museum1FPrintGamblerText
    jmp TextScriptEnd

Museum1FScientist2Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Museum1FPrintScientist2Text
    jmp TextScriptEnd

Museum1FScientist3Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Museum1FPrintScientist3Text
    jmp TextScriptEnd

Museum1FOldAmberText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Museum1FPrintOldAmberText
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Museum1FPrintScientist1Text (scripts/Museum1F_2.asm:2-8) — at scripts/Museum1F_2.asm:4: .not_right_of_scientist is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wYCoord]
; PRET| 	cp 4
; PRET| 	jr nz, .not_right_of_scientist
; PRET| 	ld a, [wXCoord]
; PRET| 	cp 13
; PRET| 	jp z, .behind_counter
; PRET| 	jr .check_ticket

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Museum1FPrintScientist1Text.not_right_of_scientist (scripts/Museum1F_2.asm:10-20) — at scripts/Museum1F_2.asm:11: .not_behind_counter is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	cp 3
; PRET| 	jr nz, .not_behind_counter
; PRET| 	ld a, [wXCoord]
; PRET| 	cp 12
; PRET| 	jp z, .behind_counter
; PRET| .not_behind_counter
; PRET| 	CheckEvent EVENT_BOUGHT_MUSEUM_TICKET
; PRET| 	jr nz, .already_bought_ticket
; PRET| 	ld hl, .GoToOtherSideText
; PRET| 	call PrintText
; PRET| 	jp .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Museum1FPrintScientist1Text.check_ticket (scripts/Museum1F_2.asm:22-27) — at scripts/Museum1F_2.asm:23: .no_ticket is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BOUGHT_MUSEUM_TICKET
; PRET| 	jr z, .no_ticket
; PRET| .already_bought_ticket
; PRET| 	ld hl, .TakePlentyOfTimeText
; PRET| 	call PrintText
; PRET| 	jp .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Museum1FPrintScientist1Text.no_ticket (scripts/Museum1F_2.asm:29-49) — at scripts/Museum1F_2.asm:39: .deny_entry is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, MONEY_BOX
; PRET| 	ld [wTextBoxID], a
; PRET| 	call DisplayTextBoxID
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld hl, .WouldYouLikeToComeInText
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jr nz, .deny_entry
; PRET| 	xor a
; PRET| 	ldh [hMoney], a
; PRET| 	ldh [hMoney + 1], a
; PRET| 	ld a, $50
; PRET| 	ldh [hMoney + 2], a
; PRET| 	call HasEnoughMoney
; PRET| 	jr nc, .buy_ticket
; PRET| 	ld hl, .DontHaveEnoughMoneyText
; PRET| 	call PrintText
; PRET| 	jp .deny_entry

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Museum1FPrintScientist1Text.buy_ticket (scripts/Museum1F_2.asm:51-69) — at scripts/Museum1F_2.asm:69: .allow_entry is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .ThankYouText
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_BOUGHT_MUSEUM_TICKET
; PRET| 	xor a
; PRET| 	ld [wPriceTemp], a
; PRET| 	ld [wPriceTemp + 1], a
; PRET| 	ld a, $50
; PRET| 	ld [wPriceTemp + 2], a
; PRET| 	ld hl, wPriceTemp + 2
; PRET| 	ld de, wPlayerMoney + 2
; PRET| 	ld c, $3
; PRET| 	predef SubBCDPredef
; PRET| 	ld a, MONEY_BOX
; PRET| 	ld [wTextBoxID], a
; PRET| 	call DisplayTextBoxID
; PRET| 	ld a, SFX_PURCHASE
; PRET| 	call PlaySoundWaitForCurrent
; PRET| 	call WaitForSoundToFinish
; PRET| 	jr .allow_entry

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Museum1FPrintScientist1Text.deny_entry (scripts/Museum1F_2.asm:71-79) — at scripts/Museum1F_2.asm:79: .done is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .ComeAgainText
; PRET| 	call PrintText
; PRET| 	ld a, $1
; PRET| 	ld [wSimulatedJoypadStatesIndex], a
; PRET| 	ld a, PAD_DOWN
; PRET| 	ld [wSimulatedJoypadStatesEnd], a
; PRET| 	call StartSimulatingJoypadStates
; PRET| 	call UpdateSprites
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Museum1FPrintScientist1Text.allow_entry (scripts/Museum1F_2.asm:81-83) — at scripts/Museum1F_2.asm:83: .done is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, SCRIPT_MUSEUM1F_NOOP
; PRET| 	ld [wMuseum1FCurScript], a
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Museum1FPrintScientist1Text.behind_counter (scripts/Museum1F_2.asm:86-94) — at scripts/Museum1F_2.asm:94: .done is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .DoYouKnowWhatAmberIsText
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	cp $0
; PRET| 	jr nz, .explain_amber
; PRET| 	ld hl, .TheresALabSomewhereText
; PRET| 	call PrintText
; PRET| 	jr .done

.explain_amber:
    mov esi, .AmberIsFossilizedTreeSapText
    call PrintText
.done:
    ret

.ComeAgainText:
    text_far _Museum1FScientist1ComeAgainText
    text_end
.WouldYouLikeToComeInText:
    text_far _Museum1FScientist1WouldYouLikeToComeInText
    text_end
.ThankYouText:
    text_far _Museum1FScientist1ThankYouText
    text_end
.DontHaveEnoughMoneyText:
    text_far _Museum1FScientist1DontHaveEnoughMoneyText
    text_end
.DoYouKnowWhatAmberIsText:
    text_far _Museum1FScientist1DoYouKnowWhatAmberIsText
    text_end
.TheresALabSomewhereText:
    text_far _Museum1FScientist1TheresALabSomewhereText
    text_end
.AmberIsFossilizedTreeSapText:
    text_far _Museum1FScientist1AmberIsFossilizedTreeSapText
    text_end
.GoToOtherSideText:
    text_far _Museum1FScientist1GoToOtherSideText
    text_end
.TakePlentyOfTimeText:
    text_far _Museum1FScientist1TakePlentyOfTimeText
    text_end

Museum1FPrintGamblerText:
    mov esi, .Text
    call PrintText
    ret

.Text:
    text_far _Museum1FGamblerText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Museum1FPrintScientist2Text (scripts/Museum1F_2.asm:147-159) — at scripts/Museum1F_2.asm:148: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_OLD_AMBER
; PRET| 	jr nz, .got_item
; PRET| 	ld hl, .TakeThisToAPokemonLabText
; PRET| 	call PrintText
; PRET| 	lb bc, OLD_AMBER, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	SetEvent EVENT_GOT_OLD_AMBER
; PRET| 	ld a, TOGGLE_OLD_AMBER
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	ld hl, .ReceivedOldAmberText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Museum1FPrintScientist2Text.bag_full (scripts/Museum1F_2.asm:161-162) — at scripts/Museum1F_2.asm:161: .YouDontHaveSpaceText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .YouDontHaveSpaceText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Museum1FPrintScientist2Text.got_item (scripts/Museum1F_2.asm:164-167) — at scripts/Museum1F_2.asm:164: .GetTheOldAmberCheckText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .GetTheOldAmberCheckText
; PRET| .done
; PRET| 	call PrintText
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] Museum1FPrintScientist2Text.TakeThisToAPokemonLabText (scripts/Museum1F_2.asm:170-184) — at scripts/Museum1F_2.asm:175: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Museum1FScientist2TakeThisToAPokemonLabText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedOldAmberText:
; PRET| 	text_far _Museum1FScientist2ReceivedOldAmberText
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .GetTheOldAmberCheckText:
; PRET| 	text_far _Museum1FScientist2GetTheOldAmberCheckText
; PRET| 	text_end
; PRET| 
; PRET| .YouDontHaveSpaceText:
; PRET| 	text_far _Museum1FScientist2YouDontHaveSpaceText
; PRET| 	text_end

Museum1FPrintScientist3Text:
    mov esi, .Text
    call PrintText
    ret

.Text:
    text_far _Museum1FScientist3Text
    text_end

Museum1FPrintOldAmberText:
    mov esi, .Text
    call PrintText
    ret

.Text:
    text_far _Museum1FOldAmberText
    text_end
