; hp_bar.asm — HPBarLength / GetHPBarLength (menus-port Session 5).
;
; Source: engine/gfx/hp_bar.asm (pret/pokeyellow), the "bc * 48 / de" HP-bar
; pixel-length predef consumed by DrawHP_ (party menu / status screen).
;
; pret does the math through the hMultiplicand/hDivisor scratch: 48 * bc via
; Multiply, then — when the max HP doesn't fit in one byte — it truncating-
; right-shifts BOTH the divisor (de >> 2, low byte kept) and the low 16 bits of
; the product (>> 2) before the byte Divide. Those truncations are observable
; (the result can differ by a pixel from exact 48*cur/max), so the port keeps
; the exact same sequence in native arithmetic: the product is ≤ 47952 (HP is
; capped at 999), so the 16-bit product lane pret shifts is the whole product.
;
; The rest of pret's UpdateHPBar/UpdateHPBar2 (the animated drain loop) is
; already ported in engine/battle/battle_hud.asm:AnimateHPBar.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/gfx/hp_bar.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global HPBarLength
global GetHPBarLength

section .text

; ---------------------------------------------------------------------------
; HPBarLength / GetHPBarLength — pret ref: engine/gfx/hp_bar.asm:GetHPBarLength.
; calculates bc * 48 / de, the number of pixels the HP bar has
; the result is always at least 1
; In:  BX (bc) = current HP, DX (de) = max HP.
; Out: DL (e) = pixels (1..48). ZF as pret's final `and a` (set when the raw
;      quotient was 0). Clobbers EAX/ECX/DH. EBX/ESI/EDI preserved (pret
;      preserves hl via push/pop; bc is untouched).
; ---------------------------------------------------------------------------
HPBarLength:
    ; call GetPredefRegisters — predef plumbing, collapsed in the flat port
GetHPBarLength:
    movzx eax, bx                       ; 48 * bc (hp bar is 48 pixels long)
    imul eax, eax, 48                   ; ld hl,hMultiplicand … call Multiply
    movzx ecx, dx
    cmp ecx, 0x100                      ; ld a,d / and a
    jb .maxHPSmaller256
    ; make HP in de fit into 1 byte by dividing by 4 (truncating), and divide
    ; the multiplication result as well (pret shifts the 16-bit product lane;
    ; the product always fits 16 bits, see header)
    shr eax, 2                          ; srl b / rr a ×2 on hMultiplicand+1/+2
    shr ecx, 2                          ; srl d / rr e ×2
    and ecx, 0xFF                       ; ld a,e / ldh [hDivisor],a — byte divisor
.maxHPSmaller256:
    ; DEVIATION{class=data-model; pret=engine/gfx/hp_bar.asm:GetHPBarLength; behavior=zero max HP clamps to a full bar instead of executing native DIV by zero; evidence=pret byte Divide behavior versus x86 DIV fault semantics; lifetime=permanent native safety boundary}
    ; Pret's byte Divide with divisor 0 spins its subtract loop
    ; harmlessly; a native DIV would fault under DPMI. Max HP 0 is unreachable
    ; from real mon data — clamp to a full bar instead of crashing.
    test ecx, ecx
    jnz .divide
    mov eax, 48
    jmp .gotQuotient
.divide:
    xor edx, edx
    div ecx                             ; ld b,$4 / call Divide
.gotQuotient:
    mov dl, al                          ; ldh a,[hMultiplicand+2] / ld e,a
    test al, al                         ; and a
    jnz .done                           ; ret nz
    mov dl, 1                           ; ld e,$1 — make result at least 1
.done:
    ret
