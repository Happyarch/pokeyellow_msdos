; fade.asm — gradual palette fades + Flash dimming + HP-bar color.
;
; Intended path: dos_port/src/home/fade.asm
;
; Source (faithful translation):
;   home/fade.asm       — LoadGBPal, GBFadeInFromBlack/OutToWhite/OutToBlack/
;                         InFromWhite, GBFadeInc/DecCommon, FadePal1..8
;   home/palettes.asm   — GBPalWhiteOut, GBPalWhiteOutWithDelay3,
;                         RestoreScreenTilesAndReloadTilePatterns, GetHealthBarColor
;
; NATURE OF THIS CODE — palette REGISTER plumbing, NOT Phase-5 CGB color.
;   The GB fade routines step the DMG palette REGISTERS (rBGP / rOBP0 / rOBP1)
;   through the FadePal tables over frames. Each FadePal byte is a DMG BGP-format
;   value: four 2-bit shade indices (bits 7-6 = color 3 … bits 1-0 = color 0).
;   Fading = walking those shade ramps 3->2->1->0 (or the reverse). The port's
;   commit_palette (src/video/frame.asm -> video.asm) maps the shade index a
;   pixel resolves to through whichever of BGP/OBP0/OBP1 applies, every frame in
;   DelayFrame. So writing IO_BGP/IO_OBP0/IO_OBP1 + DelayFrame reproduces the GB
;   fade exactly, on the current DMG-green debug ramp. This is INDEPENDENT of the
;   Phase-5 work of translating the true CGB color values into the VGA DAC:
;   these routines only choose shade indices, never RGB. Hence "implementable now".
;   The GB's UpdateCGBPal_{BGP,OBP0,OBP1} calls (which push CGB RGB) are the only
;   Phase-5-blocked part; they are elided here with ; TODO-HW: comments, exactly as
;   the existing GBPalWhiteOut scaffold in src/movie/title.asm does.
;
; Register mapping used (SM83 -> x86): A->AL, HL->(flat data ptr in EDI here,
;   since the FadePal tables live in the port's own .data, not GB address space),
;   B(loop count)->BH, C(DelayFrames arg)->BL, D->DL, E->DL(input to health bar).
;
; Build: nasm -f coff -I include/ -o fade.o fade.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "data_macros.inc"

; ---------------------------------------------------------------------------
; Externs (all resolved globals in the current tree)
; ---------------------------------------------------------------------------
extern DelayFrames                  ; src/video/frame.asm  (In: BL = frame count)
extern Delay3                       ; src/video/frame.asm
extern ClearSprites                 ; src/gfx/sprites.asm
extern LoadTextBoxTilePatterns      ; src/gfx/load_font.asm
extern ReloadMapSpriteTilePatterns  ; src/home/reload_sprites.asm

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global LoadGBPal
global GBFadeInFromBlack
global GBFadeOutToWhite
global GBFadeOutToBlack
global GBFadeInFromWhite
global GBPalWhiteOut
global GBPalWhiteOutWithDelay3
global RestoreScreenTilesAndReloadTilePatterns
global GetHealthBarColor
global FadePal1
global FadePal2
global FadePal3
global FadePal4
global FadePal5
global FadePal6
global FadePal7
global FadePal8

section .text

; ===========================================================================
; LoadGBPal — load the (possibly Flash-dimmed) map palette.
; Source: home/fade.asm:LoadGBPal
;   wMapPalOffset selects how dim the map is (0 = normal); the palette used is
;   FadePal4 - wMapPalOffset. pret does an 8-bit  ld a,l / sub b / ld l,a  with
;   dec h on borrow, i.e. a full 16-bit  hl = FadePal4 - b. In the flat port the
;   offset is a small non-negative byte, so a straight pointer subtract matches.
; ===========================================================================
LoadGBPal:
    movzx eax, byte [ebp + wMapPalOffset] ; b = dimming offset (0 = normal)
    lea edi, [FadePal4]
    sub edi, eax                          ; hl = FadePal4 - b
    mov al, [edi]                         ; ld a,[hli] -> rBGP
    mov [ebp + IO_BGP], al
    inc edi
    mov al, [edi]                         ; ld a,[hli] -> rOBP0
    mov [ebp + IO_OBP0], al
    inc edi
    mov al, [edi]                         ; ld a,[hli] -> rOBP1
    mov [ebp + IO_OBP1], al
    ; TODO-HW: UpdateCGBPal_{BGP,OBP0,OBP1} — CGB RGB commit (Phase 5)
    ret

; ===========================================================================
; GBFade* — step the palette registers through the FadePal ramp over frames.
; Source: home/fade.asm
;   Increasing (brighter) fades read FadePalN..N+b forward (BGP,OBP0,OBP1 order);
;   decreasing (darker) fades read backward from FadePalN+2. 8 frames per step.
; ===========================================================================
GBFadeInFromBlack:
    lea edi, [FadePal1]
    mov bh, 4
    jmp GBFadeIncCommon

GBFadeOutToWhite:
    lea edi, [FadePal6]
    mov bh, 3
    ; fall through

GBFadeIncCommon:
    mov al, [edi]                         ; ld a,[hli] -> rBGP
    mov [ebp + IO_BGP], al
    inc edi
    mov al, [edi]                         ; ld a,[hli] -> rOBP0
    mov [ebp + IO_OBP0], al
    inc edi
    mov al, [edi]                         ; ld a,[hli] -> rOBP1
    mov [ebp + IO_OBP1], al
    inc edi
    ; TODO-HW: UpdateCGBPal_{BGP,OBP0,OBP1} — CGB RGB commit (Phase 5)
    mov bl, 8                             ; ld c, 8
    call DelayFrames                      ; (preserves EDI/BH; clobbers BL)
    dec bh                                ; dec b
    jnz GBFadeIncCommon
    ret

GBFadeOutToBlack:
    lea edi, [FadePal4 + 2]
    mov bh, 4
    jmp GBFadeDecCommon

GBFadeInFromWhite:
    lea edi, [FadePal7 + 2]
    mov bh, 3
    ; fall through

GBFadeDecCommon:
    mov al, [edi]                         ; ld a,[hld] -> rOBP1
    mov [ebp + IO_OBP1], al
    dec edi
    mov al, [edi]                         ; ld a,[hld] -> rOBP0
    mov [ebp + IO_OBP0], al
    dec edi
    mov al, [edi]                         ; ld a,[hld] -> rBGP
    mov [ebp + IO_BGP], al
    dec edi
    ; TODO-HW: UpdateCGBPal_{BGP,OBP0,OBP1} — CGB RGB commit (Phase 5)
    mov bl, 8                             ; ld c, 8
    call DelayFrames
    dec bh                                ; dec b
    jnz GBFadeDecCommon
    ret

; ===========================================================================
; GBPalWhiteOut / GBPalWhiteOutWithDelay3 — white out all palettes.
; Source: home/palettes.asm:GBPalWhiteOut, GBPalWhiteOutWithDelay3
;   NOTE: src/movie/title.asm carries a FILE-LOCAL GBPalWhiteOut scaffold (M0.4,
;   not `global`). This is the faithful home-located, exported copy; a future
;   cleanup should drop title.asm's private copy and extern this one. A file-local
;   symbol does not collide with this global at link.
; ===========================================================================
GBPalWhiteOut:
    mov byte [ebp + IO_BGP],  0x00        ; xor a / ldh [rBGP],  a
    mov byte [ebp + IO_OBP0], 0x00        ;         ldh [rOBP0], a
    mov byte [ebp + IO_OBP1], 0x00        ;         ldh [rOBP1], a
    ; TODO-HW: UpdateCGBPal_{BGP,OBP0,OBP1} — CGB RGB commit (Phase 5)
    ret

GBPalWhiteOutWithDelay3:
    call GBPalWhiteOut
    jmp Delay3                            ; pret: call GBPalWhiteOut then falls into Delay3

; ===========================================================================
; RestoreScreenTilesAndReloadTilePatterns
; Source: home/palettes.asm:RestoreScreenTilesAndReloadTilePatterns
;   Restores the saved screen (Buffer2) and reloads sprite/text tile patterns
;   after a menu/overlay, then reasserts the default palette and waits 3 frames.
; ===========================================================================
RestoreScreenTilesAndReloadTilePatterns:
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 1  ; ld a,$1 / ld [wUpdateSpritesEnabled],a
    ; Load-bearing since the party icons became OAM: they live in vSprites
    ; ($8000-$87FF), i.e. exactly the map-sprite tiles this reloads. Every port
    ; caller is an overworld-context exit, so the reload is in-context here.
    call ReloadMapSpriteTilePatterns
    ; TODO(unimplemented): call LoadScreenTilesFromBuffer2
    ;   (file-local scaffold in src/movie/title.asm; not yet a linkable global)
    call LoadTextBoxTilePatterns
    ; TODO(unimplemented): call RunDefaultPaletteCommand
    ;   (SGB/CGB palette command dispatch — Phase 5; town_map.asm stubs it too)
    jmp Delay3                            ; jr Delay3 (tail-call)

; ===========================================================================
; GetHealthBarColor
; Source: home/palettes.asm:GetHealthBarColor
;   In:  DL (E) = current HP-bar length in pixels (0..48 for a 6-tile bar).
;        ESI (HL) = flat GB address to store the color into.
;   Out: byte at [ebp+esi] = 0 green / 1 yellow / 2 red.
;   Faithful pixel thresholds: >=27 px green, >=10 px yellow, else red
;   (27/48 ~ 56%, 10/48 ~ 21%; pure gameplay logic, NOT color-blocked).
; ===========================================================================
GetHealthBarColor:
    xor dh, dh                            ; ld d, 0  (green)
    cmp dl, 27                            ; cp 27
    jae .gotColor                         ; jr nc, .gotColor
    inc dh                                ; inc d  (yellow)
    cmp dl, 10                            ; cp 10
    jae .gotColor                         ; jr nc, .gotColor
    inc dh                                ; inc d  (red)
.gotColor:
    mov [ebp + esi], dh                   ; ld [hl], d
    ret

; ===========================================================================
; FadePal tables — DMG palette-register ramps (BGP, OBP0, OBP1 per entry).
; Source: home/fade.asm  (rgbds `dc a,b,c,d` = db (a<<6)|(b<<4)|(c<<2)|d)
;   Emitted into .data per link.ld's data-folding rule (see CLAUDE.md).
; ===========================================================================
section .data

; rgbds `dc` ("crumbs") provided by data_macros.inc

FadePal1:  dc 3,3,3,3
           dc 3,3,3,3
           dc 3,3,3,3
FadePal2:  dc 3,3,3,2
           dc 3,3,3,2
           dc 3,3,2,0
FadePal3:  dc 3,3,2,1
           dc 3,2,1,0
           dc 3,2,1,0
FadePal4:  dc 3,2,1,0
           dc 3,1,0,0
           dc 3,2,0,0
;              rBGP      rOBP0     rOBP1
FadePal5:  dc 3,2,1,0
           dc 3,1,0,0
           dc 3,2,0,0
FadePal6:  dc 2,1,0,0
           dc 2,0,0,0
           dc 2,1,0,0
FadePal7:  dc 1,0,0,0
           dc 1,0,0,0
           dc 1,0,0,0
FadePal8:  dc 0,0,0,0
           dc 0,0,0,0
           dc 0,0,0,0
