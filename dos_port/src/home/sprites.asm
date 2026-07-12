; sprites.asm — ClearSprites / HideSprites translated from SM83 to x86.
;
; Source: home/clear_sprites.asm:ClearSprites, HideSprites
;
; Operate on shadow OAM (wShadowOAM, $C300, 40 sprites × 4 bytes each).
; ClearSprites zeroes it; HideSprites sets each sprite's Y to 160 (off-screen).
;
; PORT: both also publish `spr_oam_valid = 0`, the compositor's live-entry count.
; On the GB these routines are self-completing: the VBlank OAM DMA is
; unconditional, so a cleared/parked shadow OAM reaches $FE00 next frame and
; nothing is drawn. In the port that DMA (video/frame.asm update_oam) is gated on
; wUpdateSpritesEnabled, which every full-takeover screen zeroes on entry — so the
; clear never reached the compositor, and render_sprites (which positions from
; spr_dos_sx/sy and counts spr_oam_valid, NOT the OAM Y byte) kept drawing the
; overworld's stale entries. Publishing the count here restores the GB semantics at
; the primitive, which is what lets render_sprites drop its old blanket "skip all
; OBJ while g_bg_whiteout is set" (docs/plans/party_icons_oam.md, Stage 1). A screen
; that wants its own OBJ afterwards republishes: PrepareOAMData (overworld),
; PrepareStaticOAM (battle pokéballs), WriteMonPartySpriteOAM (party/naming icons).
;
; Build: nasm -f coff -I include/ -o sprites.o sprites.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

OBJ_SIZE         equ 4
SCREEN_HEIGHT_PX equ 144
OAM_Y_OFS        equ 16

extern spr_oam_valid            ; ppu/ppu.asm — render_sprites' live-entry count
extern g_obj_over_window        ; ppu/ppu.asm — OBJ-over-window z-order (party/naming icons)

global ClearSprites
global HideSprites

section .text

; ---------------------------------------------------------------------------
; ClearSprites — zero the entire shadow OAM buffer. All registers preserved.
; ---------------------------------------------------------------------------
ClearSprites:
    push eax
    push ecx
    push edi
    mov dword [spr_oam_valid], 0    ; PORT: no live OBJ until someone republishes
    mov dword [g_obj_over_window], 0 ; …and the OBJ-over-window order dies with them
    lea edi, [ebp + W_SHADOW_OAM]
    mov ecx, W_SHADOW_OAM_SIZE
    xor eax, eax
    rep stosb
    pop edi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; HideSprites — set every sprite's Y to SCREEN_HEIGHT_PX + OAM_Y_OFS (= 160).
; All registers preserved.
; ---------------------------------------------------------------------------
HideSprites:
    push eax
    push ecx
    push edi
    mov dword [spr_oam_valid], 0    ; PORT: parked off-screen == not drawn (see header)
    mov dword [g_obj_over_window], 0 ; …and the OBJ-over-window order dies with them
    lea edi, [ebp + W_SHADOW_OAM]
    mov al, SCREEN_HEIGHT_PX + OAM_Y_OFS
    mov ecx, OAM_COUNT
.loop:
    mov [edi], al
    add edi, OBJ_SIZE
    dec ecx
    jnz .loop
    pop edi
    pop ecx
    pop eax
    ret
