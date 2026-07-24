; title.asm — legacy title module, now holding only ClearScreen.
;
; The title screen itself (PrepareTitleScreen / DisplayTitleScreen /
; TitleScreenCopyTileMapToVRAM / DoTitleScreenFunction / IncrementResetCounter)
; moved to its pret mirror src/engine/movie/title.asm, and the Yellow
; graphics/placement half (LoadYellowTitleScreenGFX / TitleScreen_Place* /
; TitleScreenPikachuEyesOAMData + the generated tile/tilemap assets) to
; src/engine/movie/title_yellow.asm (relocated-labels grind, 2026-07-24).
;
; What remains is ClearScreen (pret home/copy2.asm) — a REGISTERED legacy
; relocation (tools/pret_label_allowlist.json relocated_labels:ClearScreen,
; "pret home/copy2.asm split across port files"). Move it to src/home/copy2.asm
; when touched; it stays here for now because this session's cluster covered
; only the title labels, and CopyVideoData's home file split is its own audited
; debt item.
;
; Build: nasm -f coff -I include/ -I . -o title.o title.asm

bits 32

%include "gb_memmap.inc"

extern FillMemory
extern Delay3

global ClearScreen

section .text

; ---------------------------------------------------------------------------
; ClearScreen — fill wTileMap with $7F (space), enable auto-BG-transfer,
; wait 3 frames.
; Source: home/copy2.asm:ClearScreen
; ---------------------------------------------------------------------------
ClearScreen:
    push esi
    push ebx
    push eax
    mov esi, W_TILEMAP
    mov bx,  SCREEN_AREA & 0xFFFF
    mov al,  0x7F
    call FillMemory
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1
    pop eax
    pop ebx
    pop esi
    jmp Delay3    ; tail call
