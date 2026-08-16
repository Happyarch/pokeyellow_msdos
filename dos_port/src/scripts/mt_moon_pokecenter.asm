; MtMoonPokecenter.asm — translated from pret scripts/MtMoonPokecenter.asm, scripts/MtMoonPokecenter_2.asm by dos_port/tools/sm83xlat.
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


global MtMoonPokecenterChanseyText
global MtMoonPokecenterMagikarpSalesmanText
global MtMoonPokecenter_Script

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern DisplayTextBoxID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GivePokemon   ; NOT YET DEFINED IN THE PORT
extern HasEnoughMoney   ; NOT YET DEFINED IN THE PORT
extern MagikarpSalesman   ; NOT YET DEFINED IN THE PORT
extern MtMoonPokecenterClipboardText   ; NOT YET DEFINED IN THE PORT
extern MtMoonPokecenterGentlemanText   ; NOT YET DEFINED IN THE PORT
extern MtMoonPokecenterLinkReceptionistText   ; NOT YET DEFINED IN THE PORT
extern MtMoonPokecenterNurseText   ; NOT YET DEFINED IN THE PORT
extern MtMoonPokecenterYoungsterText   ; NOT YET DEFINED IN THE PORT
extern MtMoonPokecenter_TextPointers   ; NOT YET DEFINED IN THE PORT
extern PokecenterChanseyText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern Serial_TryEstablishingExternallyClockedConnection   ; NOT YET DEFINED IN THE PORT
extern SubBCDPredef   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _MtMoonPokecenterClipboardText   ; NOT YET DEFINED IN THE PORT
extern _MtMoonPokecenterMagikarpSalesmanIGotADealText   ; NOT YET DEFINED IN THE PORT
extern _MtMoonPokecenterMagikarpSalesmanNoMoneyText   ; NOT YET DEFINED IN THE PORT
extern _MtMoonPokecenterMagikarpSalesmanNoRefundsText   ; NOT YET DEFINED IN THE PORT
extern _MtMoonPokecenterMagikarpSalesmanNoText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
TEXT_MTMOONPOKECENTER_NURSE                    equ 1
TEXT_MTMOONPOKECENTER_YOUNGSTER                equ 2
TEXT_MTMOONPOKECENTER_GENTLEMAN                equ 3
TEXT_MTMOONPOKECENTER_MAGIKARP_SALESMAN        equ 4
TEXT_MTMOONPOKECENTER_CLIPBOARD                equ 5
TEXT_MTMOONPOKECENTER_LINK_RECEPTIONIST        equ 6
TEXT_MTMOONPOKECENTER_CHANSEY                  equ 7

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPriceTemp                                     equ 0xCD3D

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

MtMoonPokecenter_Script:
    call Serial_TryEstablishingExternallyClockedConnection
    jmp EnableAutoTextBoxDrawing

; ---------------------------------------------------------------------------
; BAIL[text-script-command-unported] MtMoonPokecenter_TextPointers (scripts/MtMoonPokecenter.asm:6-24) — at scripts/MtMoonPokecenter.asm:16: script_pokecenter_nurse
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const MtMoonPokecenterNurseText,            TEXT_MTMOONPOKECENTER_NURSE
; PRET| 	dw_const MtMoonPokecenterYoungsterText,        TEXT_MTMOONPOKECENTER_YOUNGSTER
; PRET| 	dw_const MtMoonPokecenterGentlemanText,        TEXT_MTMOONPOKECENTER_GENTLEMAN
; PRET| 	dw_const MtMoonPokecenterMagikarpSalesmanText, TEXT_MTMOONPOKECENTER_MAGIKARP_SALESMAN
; PRET| 	dw_const MtMoonPokecenterClipboardText,        TEXT_MTMOONPOKECENTER_CLIPBOARD
; PRET| 	dw_const MtMoonPokecenterLinkReceptionistText, TEXT_MTMOONPOKECENTER_LINK_RECEPTIONIST
; PRET| 	dw_const MtMoonPokecenterChanseyText,          TEXT_MTMOONPOKECENTER_CHANSEY
; PRET| 
; PRET| MtMoonPokecenterNurseText:
; PRET| 	script_pokecenter_nurse
; PRET| 
; PRET| MtMoonPokecenterYoungsterText:
; PRET| 	text_far _MtMoonPokecenterYoungsterText
; PRET| 	text_end
; PRET| 
; PRET| MtMoonPokecenterGentlemanText:
; PRET| 	text_far _MtMoonPokecenterGentlemanText
; PRET| 	text_end

MtMoonPokecenterMagikarpSalesmanText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call MagikarpSalesman
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-script-command-unported] MtMoonPokecenterClipboardText (scripts/MtMoonPokecenter.asm:32-36) — at scripts/MtMoonPokecenter.asm:36: script_cable_club_receptionist
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _MtMoonPokecenterClipboardText
; PRET| 	text_end
; PRET| 
; PRET| MtMoonPokecenterLinkReceptionistText:
; PRET| 	script_cable_club_receptionist

MtMoonPokecenterChanseyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call PokecenterChanseyText
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[checkevent-carry-form] MagikarpSalesman (scripts/MtMoonPokecenter_2.asm:2-21) — at scripts/MtMoonPokecenter_2.asm:2: CheckEvent EVENT_BOUGHT_MAGIKARP, 1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BOUGHT_MAGIKARP, 1
; PRET| 	jp c, .alreadyBoughtMagikarp
; PRET| 	ld hl, .IGotADealText
; PRET| 	call PrintText
; PRET| 	ld a, MONEY_BOX
; PRET| 	ld [wTextBoxID], a
; PRET| 	call DisplayTextBoxID
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jp nz, .choseNo
; PRET| 	xor a
; PRET| 	ldh [hMoney], a
; PRET| 	ldh [hMoney + 2], a
; PRET| 	ld a, $5
; PRET| 	ldh [hMoney + 1], a
; PRET| 	call HasEnoughMoney
; PRET| 	jr nc, .enoughMoney
; PRET| 	ld hl, .NoMoneyText
; PRET| 	jr .printText

.enoughMoney:
    mov bx, ((MAGIKARP) << 8) | (5)
    call GivePokemon
    jae .done
    xor al, al
    mov [ebp + wPriceTemp], al
    mov [ebp + wPriceTemp + 2], al
    mov al, 0x5
    mov [ebp + wPriceTemp + 1], al
    mov esi, wPriceTemp + 2
    mov dx, wPlayerMoney + 2
    mov bl, 0x3
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call SubBCDPredef
    mov al, MONEY_BOX
    mov [ebp + wTextBoxID], al
    call DisplayTextBoxID
    SetEvent EVENT_BOUGHT_MAGIKARP
    jmp .done

.choseNo:
    mov esi, .NoText
    jmp .printText

.alreadyBoughtMagikarp:
    mov esi, .NoRefundsText
.printText:
    call PrintText
.done:
    ret

.IGotADealText:
    text_far _MtMoonPokecenterMagikarpSalesmanIGotADealText
    text_end
.NoText:
    text_far _MtMoonPokecenterMagikarpSalesmanNoText
    text_end
.NoMoneyText:
    text_far _MtMoonPokecenterMagikarpSalesmanNoMoneyText
    text_end
.NoRefundsText:
    text_far _MtMoonPokecenterMagikarpSalesmanNoRefundsText
    text_end
