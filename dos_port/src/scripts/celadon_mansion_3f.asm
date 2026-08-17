; CeladonMansion3F.asm — translated from pret scripts/CeladonMansion3F.asm, scripts/CeladonMansion3F_2.asm by dos_port/tools/sm83xlat.
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


global CeladonMansion3FDevRoomSignText
global CeladonMansion3FGameDesignerText
global CeladonMansion3FGameProgramPCText
global CeladonMansion3FGameScriptPCText
global CeladonMansion3FGraphicArtistText
global CeladonMansion3FPlayingGamePCText
global CeladonMansion3FPrintDevRoomSignText
global CeladonMansion3FPrintGameProgramPCText
global CeladonMansion3FPrintGameScriptPCText
global CeladonMansion3FPrintPlayingGamePCText
global CeladonMansion3FProgrammerText
global CeladonMansion3F_Script
global CeladonMansion3F_TextPointers
global CeladonMansion3Text_486f0
global CeladonMansion3Text_486f5
global CeladonMansion3_PokedexCount

extern Bankswitch
extern CeladonMansion3FWriterText   ; NOT YET DEFINED IN THE PORT
extern CountSetBits
extern Delay3
extern DisplayDiploma   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing
extern GBPalNormal
extern GBPalWhiteOutWithDelay3
extern LoadScreenTilesFromBuffer2
extern PrintDiploma   ; NOT YET DEFINED IN THE PORT
extern PrintText
extern ReloadTilesetTilePatterns
extern RestoreScreenTilesAndReloadTilePatterns
extern SaveScreenTilesToBuffer2
extern TextScriptEnd
extern YesNoChoice
extern _CeladonMansion3FDevRoomSignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FGameDesignerCompletedDexText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FGameDesignerCompletedDexText2   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FGameDesignerText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FGameProgramPCText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FGameScriptPCText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FGraphicArtistText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FGraphicArtistText2   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FGraphicArtistText3   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FGraphicArtistText4   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FGraphicArtistText5   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FPlayingGamePCText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FProgrammerText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FProgrammerText2   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FWriterText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMansion3FWriterText2   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hCanceledPrinting                              equ 0xFFDB

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3F_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3_PokedexCount:
    mov esi, wPokedexOwned
    mov bh, wPokedexOwnedEnd - wPokedexOwned
    call CountSetBits
    mov al, [ebp + wNumSetBits]
    ret

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3F_TextPointers:
    dd CeladonMansion3FProgrammerText
    dd CeladonMansion3FGraphicArtistText
    dd CeladonMansion3FWriterText
    dd CeladonMansion3FGameDesignerText
    dd CeladonMansion3FGameProgramPCText
    dd CeladonMansion3FPlayingGamePCText
    dd CeladonMansion3FGameScriptPCText
    dd CeladonMansion3FDevRoomSignText

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3FProgrammerText:
    call CeladonMansion3_PokedexCount
    cmp al, 151 - 1
    mov esi, CeladonMansion3Text_486f5
    jae .print
    mov esi, CeladonMansion3Text_486f0
.print:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3Text_486f0:
    text_far _CeladonMansion3FProgrammerText
    text_end
CeladonMansion3Text_486f5:
    text_far _CeladonMansion3FProgrammerText2
    text_end

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3FGraphicArtistText:
    call CeladonMansion3_PokedexCount
    cmp al, 151 - 1
    jae .completed
    mov esi, .Text1
    jmp .print

%assign event_byte -1
%assign event_byte_a -1
.completed:
    mov esi, .Text2
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .declined_print
    call SaveScreenTilesToBuffer2
    xor al, al
    mov [ebp + wUpdateSpritesEnabled], al
    mov esi, wStatusFlags5
    or byte [ebp + esi], (1 << (BIT_NO_TEXT_DELAY))
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call PrintDiploma
    mov esi, wStatusFlags5
    and byte [ebp + esi], ~(1 << (BIT_NO_TEXT_DELAY)) & 0xFF
    call GBPalWhiteOutWithDelay3
    call ReloadTilesetTilePatterns
    call RestoreScreenTilesAndReloadTilePatterns
    call LoadScreenTilesFromBuffer2
    call Delay3
    call GBPalNormal
    mov esi, .Text5
    mov al, [ebp + hCanceledPrinting]
    test al, al
    jnz .print
    mov esi, .Text4
    jmp .print

%assign event_byte -1
%assign event_byte_a -1
.declined_print:
    mov esi, .Text3
.print:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text1:
    text_far _CeladonMansion3FGraphicArtistText
    text_end
.Text2:
    text_far _CeladonMansion3FGraphicArtistText2
    text_end
.Text3:
    text_far _CeladonMansion3FGraphicArtistText3
    text_end
.Text4:
    text_far _CeladonMansion3FGraphicArtistText4
    text_end
.Text5:
    text_far _CeladonMansion3FGraphicArtistText5
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonMansion3FWriterText (scripts/CeladonMansion3F.asm:106-113) — at scripts/CeladonMansion3F.asm:108: .Text2 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call CeladonMansion3_PokedexCount
; PRET| 	cp NUM_POKEMON - 1 ; discount Mew
; PRET| 	ld hl, .Text2
; PRET| 	jr nc, .print
; PRET| 	ld hl, .Text1
; PRET| .print
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] CeladonMansion3FWriterText.Text1 (scripts/CeladonMansion3F.asm:116-121)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonMansion3FWriterText
; PRET| 	text_end
; PRET| 
; PRET| .Text2:
; PRET| 	text_far _CeladonMansion3FWriterText2
; PRET| 	text_end

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3FGameDesignerText:
    call CeladonMansion3_PokedexCount
    cmp al, 151 - 1
    jae .completed_dex
    mov esi, .Text
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.completed_dex:
    mov esi, .CompletedDexText
    call PrintText
    call Delay3
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, .UnlockedDiplomaPrinting
.done:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _CeladonMansion3FGameDesignerText
    text_end
.CompletedDexText:
    text_far _CeladonMansion3FGameDesignerCompletedDexText
    text_promptbutton

%assign event_byte -1
%assign event_byte_a -1
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call DisplayDiploma
    mov al, 1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.UnlockedDiplomaPrinting:
    text_far _CeladonMansion3FGameDesignerCompletedDexText2
    text_end

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3FGameProgramPCText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CeladonMansion3FPrintGameProgramPCText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3FPlayingGamePCText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CeladonMansion3FPrintPlayingGamePCText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3FGameScriptPCText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CeladonMansion3FPrintGameScriptPCText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3FDevRoomSignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CeladonMansion3FPrintDevRoomSignText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3FPrintGameProgramPCText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _CeladonMansion3FGameProgramPCText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3FPrintPlayingGamePCText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _CeladonMansion3FPlayingGamePCText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3FPrintGameScriptPCText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _CeladonMansion3FGameScriptPCText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CeladonMansion3FPrintDevRoomSignText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _CeladonMansion3FDevRoomSignText
    text_end
