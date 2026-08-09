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

%define TILE_BLANK 0x7F                  ; charmap " " (same define as src/home/copy2.asm)

extern DrawHPBar                         ; src/home/pokemon.asm — ESI coord, DH tiles, DL pixels
extern DelayFrames                       ; src/home/delay.asm — BL = frame count
extern DelayFrame                        ; src/home/vblank.asm
extern Delay3                            ; src/home/palettes.asm
extern PrintNumber                       ; src/home/print_num.asm — ESI dest, EDX src, BH flags|bytes, BL digits
extern text_row_stride                   ; src/home/text.asm — live tilemap row stride (20 / 40)

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

; ===========================================================================
; UpdateHPBar / UpdateHPBar2 and the UpdateHPBar_* helpers — pret
; engine/gfx/hp_bar.asm. The animated HP-bar sweep: walk the bar one HP at a
; time from wHPBarOldHP to wHPBarNewHP, redrawing and delaying, and reprint the
; HP number as it goes.
;
; This is what makes a potion "animate": Gen 1 has NO sprite animation for
; medicine items (pret's 669-line ItemUseMedicine contains no MoveAnimation /
; PlayBattleAnimation / *_ANIM call at all) — the heal SFX plus this bar sweep
; IS the animation. It was previously unported, and item_effects.asm carried an
; annotation recording that the bar snapped to its final length instead of
; sweeping. (Do not start that line with the annotation keyword — a prose
; cross-reference in the annotation position parses as a malformed one and
; lint_pret_labels --strict-claims flags it, which is how this comment got
; rewritten.)
;
; NOTE ON ENDIANNESS — this scratch really is LITTLE-endian, and that is not a
; violation of the project's big-endian rule. The rule governs GB *game data*
; (party/box structs); wHPBarMaxHP / wHPBarOldHP / wHPBarNewHP are engine
; scratch that pret loads low-byte-first (`ld a,[hli] / ld c,a` into bc), and
; pret's own UpdateHPBar_PrintHPNumber comments the conversion "from
; little-endian to big-endian for PrintNumber". Byte order is preserved as pret
; has it, which is the actual rule.
;
; DEVIATION{class=HAL; pret=engine/gfx/hp_bar.asm:UpdateHPBar2; behavior=the call to GetPredefRegisters is dropped and the tilemap position arrives in ESI from a direct call; evidence=the port has no predef dispatcher so wPredefRegisters is never staged and GetPredefRegisters would load garbage over the live registers, the same convention CopyDownscaledMonTiles and ReadTrainer to AddBCD already use; lifetime=permanent, the port calls predef targets directly}
; In: ESI (hl) = HP bar tilemap position; wHPBarMaxHP / wHPBarOldHP /
;     wHPBarNewHP staged by the caller; wHPBarType selects the number print.
; ===========================================================================
global UpdateHPBar
global UpdateHPBar2
UpdateHPBar:
UpdateHPBar2:
    push esi
    mov bl, [ebp + wHPBarOldHP]              ; old HP into bc (little-endian)
    mov bh, [ebp + wHPBarOldHP + 1]
    mov dl, [ebp + wHPBarNewHP]              ; new HP into de
    mov dh, [ebp + wHPBarNewHP + 1]
    pop esi
    push edx
    push ebx
    call UpdateHPBar_CalcHPDifference        ; de = |old - new|
    mov al, dl
    mov [ebp + wHPBarHPDifference + 1], al   ; stored BIG-endian (PrintNumber reads BE)
    mov al, dh
    mov [ebp + wHPBarHPDifference], al
    pop ebx
    pop edx
    call UpdateHPBar_CompareNewHPToOldHP
    jz .ret                                  ; ret z — nothing to animate
    mov al, 0xFF
    jb .HPdecrease                           ; jr c
    mov al, 1
.HPdecrease:
    mov [ebp + wHPBarDelta], al
    ; call GetPredefRegisters — dropped, see the DEVIATION above
    mov dl, [ebp + wHPBarNewHP]              ; de = target HP
    mov dh, [ebp + wHPBarNewHP + 1]
.animateHPBarLoop:
    push edx
    mov bl, [ebp + wHPBarOldHP]              ; bc = the HP walked so far
    mov bh, [ebp + wHPBarOldHP + 1]
    call UpdateHPBar_CompareNewHPToOldHP
    jz .animateHPBarDone
    jae .HPIncrease                          ; jr nc
; HP decrease
    dec bx                                   ; subtract 1 HP (16-bit, as pret)
    mov al, bl
    mov [ebp + wHPBarNewHP], al
    mov al, bh
    mov [ebp + wHPBarNewHP + 1], al
    call UpdateHPBar_CalcOldNewHPBarPixels   ; DH = new px, DL = old px
    mov al, dl
    sub al, dh                               ; pixel difference
    jmp short .ok
.HPIncrease:
    inc bx                                   ; add 1 HP
    mov al, bl
    mov [ebp + wHPBarNewHP], al
    mov al, bh
    mov [ebp + wHPBarNewHP + 1], al
    call UpdateHPBar_CalcOldNewHPBarPixels
    mov al, dh
    sub al, dl
.ok:
    call UpdateHPBar_PrintHPNumber           ; preserves AL (pret push af/pop af)
    and al, al
    jz .noPixelDifference
    call UpdateHPBar_AnimateHPBar
.noPixelDifference:
    mov al, [ebp + wHPBarNewHP]
    mov [ebp + wHPBarOldHP], al
    mov al, [ebp + wHPBarNewHP + 1]
    mov [ebp + wHPBarOldHP + 1], al
    pop edx
    jmp .animateHPBarLoop
.animateHPBarDone:
    pop edx
    mov al, dl
    mov [ebp + wHPBarOldHP], al
    mov al, dh
    mov [ebp + wHPBarOldHP + 1], al
    or al, dl                                ; d | e — zero only if the mon fainted
    jz .monFainted
    call UpdateHPBar_CalcOldNewHPBarPixels
    mov dh, dl                               ; ld d, e
.monFainted:
    call UpdateHPBar_PrintHPNumber
    mov al, 1
    call UpdateHPBar_AnimateHPBar
    jmp Delay3
.ret:
    ret

; Animates the HP bar going up or down for AL ticks (two waiting frames each),
; stopping early if the bar fills up. DL (e) = current health in pixels.
global UpdateHPBar_AnimateHPBar
UpdateHPBar_AnimateHPBar:
    push esi
.barAnimationLoop:
    push eax
    push edx
    mov dh, 6                                ; ld d, $6 — bar is 6 tiles
    call DrawHPBar
    mov bl, 2                                ; ld c, 2
    call DelayFrames
    pop edx
    mov al, [ebp + wHPBarDelta]              ; +1 or -1
    add al, dl                               ; add e
    cmp al, 0x31
    jae .barFilledUp                         ; jr nc
    mov dl, al
    pop eax
    dec al
    jnz .barAnimationLoop
    pop esi
    ret
.barFilledUp:
    pop eax
    pop esi
    ret

; Compares new HP (DE) to old HP (BC), setting CF/ZF as pret does. `ret` does
; not disturb flags on x86, so the caller's jz/jb read them intact.
global UpdateHPBar_CompareNewHPToOldHP
UpdateHPBar_CompareNewHPToOldHP:
    mov al, dh
    sub al, bh
    jnz .ret                                 ; ret nz
    mov al, dl
    sub al, bl
.ret:
    ret

; Calcs the HP difference between BC and DE, into DE.
global UpdateHPBar_CalcHPDifference
UpdateHPBar_CalcHPDifference:
    mov al, dh
    sub al, bh
    jb .oldHPGreater                         ; jr c
    jz .testLowerByte
.newHPGreater:
    mov al, dl
    sub al, bl
    mov dl, al                               ; mov does not disturb CF
    mov al, dh
    sbb al, bh
    mov dh, al
    ret
.oldHPGreater:
    mov al, bl
    sub al, dl
    mov dl, al
    mov al, bh
    sbb al, dh
    mov dh, al
    ret
.testLowerByte:
    mov al, dl
    sub al, bl
    jb .oldHPGreater
    jnz .newHPGreater
    xor edx, edx                             ; ld de, $0
    ret

global UpdateHPBar_PrintHPNumber
UpdateHPBar_PrintHPNumber:
    push eax                                 ; push af — the pixel difference
    push edx
    mov al, [ebp + wHPBarType]
    and al, al
    jz .done                                 ; don't print the number in the enemy HUD
; convert from little-endian to big-endian for PrintNumber
    mov al, [ebp + wHPBarOldHP]
    mov [ebp + wHPBarTempHP + 1], al
    mov al, [ebp + wHPBarOldHP + 1]
    mov [ebp + wHPBarTempHP], al
    push esi
; pret `ld de, $15` is SCREEN_WIDTH + 1 — a COORDINATE offset, so it takes the
; port's live [text_row_stride] (20 menu scratch / 40 flat canvas), exactly as
; status_screen.asm:DrawHP_ already does for the same pret expression. The $9
; party-menu case is a pure horizontal offset and carries verbatim.
    mov ecx, [text_row_stride]
    inc ecx
    test byte [ebp + H_UI_LAYOUT_FLAGS], 1 << BIT_PARTY_MENU_HP_BAR
    jz .hpBelowBar
    mov ecx, 9                               ; ld de, $9 — right of the bar
.hpBelowBar:
    add esi, ecx                             ; add hl, de
    push esi
    mov al, TILE_BLANK                       ; ld a, ' ' — blank the 3 digit cells
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    pop esi
    mov edx, wHPBarTempHP                    ; ld de, wHPBarTempHP
    mov bh, 2                                ; lb bc, 2, 3 — 2 bytes, 3 digits
    mov bl, 3
    call PrintNumber
    call DelayFrame
    pop esi
.done:
    pop edx
    pop eax
    ret

; Calcs the number of HP bar pixels for the old and new HP values.
; Out: DH (d) = new pixels, DL (e) = old pixels.
global UpdateHPBar_CalcOldNewHPBarPixels
UpdateHPBar_CalcOldNewHPBarPixels:
    push esi
    mov dl, [ebp + wHPBarMaxHP]              ; max HP into de (little-endian)
    mov dh, [ebp + wHPBarMaxHP + 1]
    mov bl, [ebp + wHPBarOldHP]              ; old HP into bc
    mov bh, [ebp + wHPBarOldHP + 1]
    mov cl, [ebp + wHPBarNewHP]              ; new HP into hl (pret uses hl as a VALUE here)
    mov ch, [ebp + wHPBarNewHP + 1]
    push ecx                                 ; push hl — the new HP value
    push edx                                 ; push de — max HP
    call GetHPBarLength                      ; bc = old HP, de = max HP -> DL = pixels
    mov al, dl
    pop edx                                  ; max HP back
    pop ebx                                  ; pop bc — the NEW HP becomes the operand
    push eax                                 ; push af — old pixels
    call GetHPBarLength                      ; -> DL = new pixels
    pop eax
    mov dh, dl                               ; d = new pixels
    mov dl, al                               ; e = old pixels
    pop esi
    ret
