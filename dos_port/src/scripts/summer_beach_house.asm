; SummerBeachHouse.asm — translated from pret scripts/SummerBeachHouse.asm, scripts/SummerBeachHouse_2.asm by dos_port/tools/sm83xlat.
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


global Func_f23d0
global SummerBeachHousePikachuText
global SummerBeachHousePrinterText
global SummerBeachHouse_Script
global SummerBeachHouse_TextPointers
global Text_f240c
global Text_f2412

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GBPalNormal   ; NOT YET DEFINED IN THE PORT
extern GBPalWhiteOutWithDelay3   ; NOT YET DEFINED IN THE PORT
extern LoadScreenTilesFromBuffer2   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern PrintSurfingMinigameHighScore   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern Printer_PrepareSurfingMinigameHighScoreTileMap   ; NOT YET DEFINED IN THE PORT
extern ReloadTilesetTilePatterns   ; NOT YET DEFINED IN THE PORT
extern RestoreScreenTilesAndReloadTilePatterns   ; NOT YET DEFINED IN THE PORT
extern SaveScreenTilesToBuffer2   ; NOT YET DEFINED IN THE PORT
extern SummerBeachHousePoster1Text   ; NOT YET DEFINED IN THE PORT
extern SummerBeachHousePoster2Text   ; NOT YET DEFINED IN THE PORT
extern SummerBeachHousePoster3Text   ; NOT YET DEFINED IN THE PORT
extern SummerBeachHouseSurfinDudeText   ; NOT YET DEFINED IN THE PORT
extern SurfingPikachuMinigame   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT
extern WaitForTextScrollButtonPress   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePikachuText   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePoster1Text1   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePoster1Text2   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePoster2Text1   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePoster2Text2   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePoster3Text1   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePoster3Text2   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePrinterText1   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePrinterText2   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePrinterText3   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePrinterText4   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePrinterText5   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHousePrinterText6   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHouseSurfinDudeText1   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHouseSurfinDudeText2   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHouseSurfinDudeText3   ; NOT YET DEFINED IN THE PORT
extern _SummerBeachHouseSurfinDudeText4   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hOaksAideResult                                equ 0xFFDB
wPikachuMapScriptFlags                         equ 0xD492
wPikachuSpawnStateFlags                        equ 0xD471

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SummerBeachHouse_Script:
    call EnableAutoTextBoxDrawing
    ret

SummerBeachHouse_TextPointers:
    dd SummerBeachHouseSurfinDudeText
    dd SummerBeachHousePikachuText
    dd SummerBeachHousePoster1Text
    dd SummerBeachHousePoster2Text
    dd SummerBeachHousePoster3Text
    dd SummerBeachHousePrinterText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SummerBeachHouseSurfinDudeText (scripts/SummerBeachHouse.asm:16-27) — at scripts/SummerBeachHouse.asm:24: .next is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wPikachuSpawnStateFlags]
; PRET| 	vc_patch Bypass_need_Pikachu_with_Surf_for_minigame
; PRET| IF DEF (_YELLOW_VC)
; PRET| 	bit BIT_PIKACHU_SPAWN_STARTER, a
; PRET| ELSE
; PRET| 	bit BIT_PIKACHU_SPAWN_SURFING, a
; PRET| ENDC
; PRET| 	vc_patch_end
; PRET| 	jr nz, .next
; PRET| 	ld hl, .SurfinDudeText4
; PRET| 	call PrintText
; PRET| 	jr .done

.next:
    mov esi, wPikachuMapScriptFlags
    test byte [ebp + esi], (1 << (0))
    pushfd    ; SM83 form writes no flags
        or byte [ebp + esi], (1 << (0))
    popfd
    jnz .next2
    mov esi, .SurfinDudeText1
    jmp .next3

.next2:
    mov esi, .SurfinDudeText3
.next3:
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .asm_f226b
    mov al, 1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SurfingPikachuMinigame
    mov esi, wPikachuMapScriptFlags
    or byte [ebp + esi], (1 << (1))
    jmp .done

.asm_f226b:
    mov esi, .SurfinDudeText2
    call PrintText
.done:
    jmp TextScriptEnd

.SurfinDudeText1:
    text_far _SummerBeachHouseSurfinDudeText1
    text_end
.SurfinDudeText2:
    text_far _SummerBeachHouseSurfinDudeText2
    text_end
.SurfinDudeText3:
    text_far _SummerBeachHouseSurfinDudeText3
    text_end
.SurfinDudeText4:
    text_far _SummerBeachHouseSurfinDudeText4
    text_end

SummerBeachHousePikachuText:
    mov esi, .SummerBeachHousePikachuText
    call PrintText
    mov al, 84
    call PlayCry
    call WaitForSoundToFinish
    jmp TextScriptEnd

.SummerBeachHousePikachuText:
    text_far _SummerBeachHousePikachuText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SummerBeachHousePoster1Text (scripts/SummerBeachHouse.asm:83-90) — at scripts/SummerBeachHouse.asm:86: .next is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .SummerBeachHousePoster1Text2
; PRET| 	ld a, [wPikachuSpawnStateFlags]
; PRET| 	bit BIT_PIKACHU_SPAWN_SURFING, a
; PRET| 	jr z, .next
; PRET| 	ld hl, .SummerBeachHousePoster1Text1
; PRET| .next
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

.SummerBeachHousePoster1Text1:
    text_far _SummerBeachHousePoster1Text1
    text_end
.SummerBeachHousePoster1Text2:
    text_far _SummerBeachHousePoster1Text2
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SummerBeachHousePoster2Text (scripts/SummerBeachHouse.asm:101-108) — at scripts/SummerBeachHouse.asm:104: .next is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .SummerBeachHousePoster2Text2
; PRET| 	ld a, [wPikachuSpawnStateFlags]
; PRET| 	bit BIT_PIKACHU_SPAWN_SURFING, a
; PRET| 	jr z, .next
; PRET| 	ld hl, .SummerBeachHousePoster2Text1
; PRET| .next
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

.SummerBeachHousePoster2Text1:
    text_far _SummerBeachHousePoster2Text1
    text_end
.SummerBeachHousePoster2Text2:
    text_far _SummerBeachHousePoster2Text2
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SummerBeachHousePoster3Text (scripts/SummerBeachHouse.asm:119-126) — at scripts/SummerBeachHouse.asm:122: .next is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .SummerBeachHousePoster3Text2
; PRET| 	ld a, [wPikachuSpawnStateFlags]
; PRET| 	bit BIT_PIKACHU_SPAWN_SURFING, a
; PRET| 	jr z, .next
; PRET| 	ld hl, .SummerBeachHousePoster3Text1
; PRET| .next
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

.SummerBeachHousePoster3Text1:
    text_far _SummerBeachHousePoster3Text1
    text_end
.SummerBeachHousePoster3Text2:
    text_far _SummerBeachHousePoster3Text2
    text_end

SummerBeachHousePrinterText:
    mov al, 1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov al, [ebp + wPikachuSpawnStateFlags]
    test al, (1 << (6))
    jz .asm_f2369
    mov esi, wPikachuMapScriptFlags
    test byte [ebp + esi], (1 << (1))
    jz .next2
    mov al, 0
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
.next2:
    mov esi, .SummerBeachHousePrinterText2
    call PrintText
    mov al, [ebp + wPikachuMapScriptFlags]
    test al, (1 << (1))
    jz .asm_f236f
    mov al, 1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, .SummerBeachHousePrinterText3
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jz Func_f23d0
    call SaveScreenTilesToBuffer2
    mov esi, wStatusFlags5
    or byte [ebp + esi], (1 << (BIT_NO_TEXT_DELAY))
    xor al, al
    mov [ebp + wUpdateSpritesEnabled], al
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Printer_PrepareSurfingMinigameHighScoreTileMap
    call WaitForTextScrollButtonPress
    mov esi, wStatusFlags5
    and byte [ebp + esi], ~(1 << (BIT_NO_TEXT_DELAY)) & 0xFF
    call GBPalWhiteOutWithDelay3
    call ReloadTilesetTilePatterns
    call RestoreScreenTilesAndReloadTilePatterns
    call LoadScreenTilesFromBuffer2
    call Delay3
    call GBPalNormal
    mov al, 1
    mov [ebp + wUpdateSpritesEnabled], al
    jmp .asm_f236f

.asm_f2369:
    mov esi, .SummerBeachHousePrinterText1
    call PrintText
.asm_f236f:
    jmp TextScriptEnd

.SummerBeachHousePrinterText1:
    text_far _SummerBeachHousePrinterText1
    text_waitbutton
    text_end
.SummerBeachHousePrinterText2:
    text_far _SummerBeachHousePrinterText2
    text_waitbutton
    text_end
.SummerBeachHousePrinterText3:
    text_far _SummerBeachHousePrinterText3
    text_end
.SummerBeachHousePrinterText4:
    text_far _SummerBeachHousePrinterText4
    text_end

Func_f23d0:
    call SaveScreenTilesToBuffer2
    xor al, al
    mov [ebp + wUpdateSpritesEnabled], al
    mov esi, wStatusFlags5
    or byte [ebp + esi], (1 << (BIT_NO_TEXT_DELAY))
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call PrintSurfingMinigameHighScore
    mov esi, wStatusFlags5
    and byte [ebp + esi], ~(1 << (BIT_NO_TEXT_DELAY)) & 0xFF
    call GBPalWhiteOutWithDelay3
    call ReloadTilesetTilePatterns
    call RestoreScreenTilesAndReloadTilePatterns
    call LoadScreenTilesFromBuffer2
    call Delay3
    call GBPalNormal
    mov esi, Text_f2412
    mov al, [ebp + hOaksAideResult]
    test al, al
    jnz .asm_f2406
    mov esi, Text_f240c
.asm_f2406:
    call PrintText
    jmp TextScriptEnd

Text_f240c:
    text_far _SummerBeachHousePrinterText5
    text_waitbutton
    text_end
Text_f2412:
    text_far _SummerBeachHousePrinterText6
    text_waitbutton
    text_end
