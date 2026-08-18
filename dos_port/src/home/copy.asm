; copy.asm — mirror of pret home/copy.asm.
;
; Holds three of that file's four pret labels: CopyData, FarCopyData and
; CopyVideoDataDoubleAlternate. The fourth, CopyVideoDataAlternate, is unported
; (status `missing`) — the port's usual VRAM-write primitive is CopyVideoData, a
; home/vcopy.asm label in src/home/vcopy.asm, and nothing calls it.
; CopyVideoDataDoubleAlternate landed when LoadPikachuShadowIntoVRAM
; (src/engine/pikachu/pikachu_movement.asm) was ported — that routine tail-jumps
; to it, so it is a real caller, not a speculative addition.
;
; NOT in pret order, and deliberately left that way: pret puts FarCopyData first
; (home/copy.asm:1) and CopyData second (:13), while the port has them the other
; way round with FarCopyData ending in `jmp CopyData`. Swapping them would turn
; that jump into a fallthrough, which is a shape change, not a relocation — so it
; is a separate piece of work, recorded here rather than smuggled into this move.
;
; Was src/home/copy_data.asm until the mirror repair; CopyDataUntil, which that
; file also carried, is a home/move_mon.asm label and moved to src/home/move_mon.asm.
;
; CopyData    — copy BC bytes from HL to DE.
; FarCopyData — copy BC bytes from a:HL to DE (A = source ROM bank).
;
; The SM83 16-bit-count double-loop (can't branch on `dec bc`) collapses to
; `rep movsb`, as in FillMemory. Semantics match pret for all counts 1..65535;
; they DIVERGE only at BC=0 — pret CopyData(BC=0) copies 256 bytes (B=0 falls
; straight into .copybytes, C=0 underflows the loop 256×), the port copies 0.
; Safe: no caller passes BC=0 expecting 256 (callers that want 256 pass $100).
; Intentionally NOT emulated (pret's 256 is an underflow artifact, not a feature).
; FarCopyData's ROM-bank switch is a flat no-op
; under our unified address space. ; TODO-HW: model ROM banking when needed.
;
; Register map: HL→ESI (src, EBP-relative), DE→EDX (dst, EBP-relative),
; BC→BX (count), A→AL (bank for FarCopyData).
;
; Build: nasm -f coff -I include/ -o copy.o copy.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global CopyData
global FarCopyData
global CopyVideoDataDoubleAlternate
global CopyVideoDataAlternate

extern CopyVideoDataDouble          ; src/home/copy2.asm
extern FarCopyDataDouble            ; src/home/copy2.asm
extern CopyVideoData                ; src/home/copy2.asm

LCDC_ON_BIT equ 7                   ; B_LCDC_ENABLE (same spelling as src/home/lcd.asm)

section .text

; ---------------------------------------------------------------------------
; CopyData — copy BX bytes from [EBP+ESI] to [EBP+EDX]
;
; In:  ESI = source GB offset (HL), EDX = dest GB offset (DE), BX = count
; Out: ESI, EDX advanced past the copied range (matches SM83 hl/de on return).
;      ECX clobbered. EBX preserved.
; ---------------------------------------------------------------------------
CopyData:
    push edi

    movzx ecx, bx                    ; count; BX=0 → 0 bytes (pret would copy 256 — see header)
    lea esi, [ebp + esi]
    movzx edi, dx
    lea edi, [ebp + edi]
    rep movsb

    sub esi, ebp
    mov edx, edi
    sub edx, ebp

    pop edi
    ret

; ---------------------------------------------------------------------------
; FarCopyData — copy BC bytes from a:HL to DE.
; Under the flat model the bank (AL) is irrelevant. Forwards to CopyData.
; ; TODO-HW: resolve (AL:HL) to a linear offset when ROM banking is modelled.
; ---------------------------------------------------------------------------
FarCopyData:
    jmp CopyData

; ---------------------------------------------------------------------------
; CopyVideoDataDoubleAlternate — pret home/copy.asm:CopyVideoDataDoubleAlternate.
;
;   ldh a, [rLCDC] / bit B_LCDC_ENABLE, a
;   jp nz, CopyVideoDataDouble        ; LCD on: go through the VBlank-safe copier
;   push de / ld d,h / ld e,l         ; swap: DE := dest VRAM
;   ld a,b / push af                  ; save bank
;   ld h,$0 / ld l,c / add hl,hl x3   ; HL := c * 8 = raw byte length
;   ld b,h / ld c,l
;   pop af / pop hl                   ; A := bank, HL := original DE (source)
;   jp FarCopyDataDouble
;
; So the LCD-off arm just re-shuffles the arguments from CopyVideoDataDouble's
; (dest, src, bank, TILE count) shape into FarCopyDataDouble's (src, dest, bank,
; BYTE count) shape and tail-jumps. Both destinations arm `g_tilecache_dirty`
; themselves, so no VRAM-cache handling is owed here.
;
; IO_LCDC is a live emulated GB memory byte in the port (src/home/lcd.asm,
; src/home/init.asm write it), so the `bit B_LCDC_ENABLE` test is a literal
; translation, not a HAL boundary.
;
; In:  ESI = destination GB VRAM offset (HL)
;      EDX = source FLAT pointer (DE)
;      BH  = source bank (NO-OP under the flat model)
;      BL  = 1bpp tile count
; ---------------------------------------------------------------------------
CopyVideoDataDoubleAlternate:
    test byte [ebp + IO_LCDC], 1 << LCDC_ON_BIT  ; ldh a,[rLCDC] / bit B_LCDC_ENABLE,a
    jnz CopyVideoDataDouble                      ; jp nz, CopyVideoDataDouble
    mov al, bh                                   ; ld a, b / push af (bank)
    movzx ebx, bl                                ; ld h, $0 / ld l, c
    shl ebx, 3                                   ; add hl,hl / add hl,hl / add hl,hl
                                                 ;   → BX = tiles * 8 raw bytes.
                                                 ;   16-bit-wide exactly as pret's HL:
                                                 ;   BL=$FF → $7F8, no wrap either side.
    xchg esi, edx                                ; push de / ld d,h / ld e,l / pop hl
    jmp FarCopyDataDouble                        ; jp FarCopyDataDouble

; ---------------------------------------------------------------------------
; CopyVideoDataAlternate — pret home/copy.asm:CopyVideoDataAlternate.
;
; In:  ESI = destination GB VRAM offset (HL)
;      EDX = source FLAT pointer (DE)
;      BH  = source bank (NO-OP under the flat model)
;      BL  = 2bpp tile count
; ---------------------------------------------------------------------------
CopyVideoDataAlternate:
    test byte [ebp + IO_LCDC], 1 << LCDC_ON_BIT  ; ldh a,[rLCDC] / bit B_LCDC_ENABLE,a
    jnz CopyVideoData                            ; jp nz, CopyVideoData
    jmp CopyVideoData                            ; flat model: same copy + tilecache dirty

