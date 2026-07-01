; ===========================================================================
; item_predicates.asm — HM / key-item / bag predicates.
;
; Intended path: dos_port/src/home/item_predicates.asm
;
; Faithful translation of the pret HM/key-item helpers, gathered here because
; they share the HM-id range test and the KeyItemFlags bit array:
;
;   IsItemHM     — pret home/names.asm:IsItemHM        (item id → CF = is HM)
;   IsMoveHM     — pret home/names.asm:IsMoveHM        (move id → CF = is HM)
;   HMMoves      — pret data/moves/hm_moves.asm        (Tier-2 db list; see below)
;   IsItemInBag  — pret home/map_objects.asm:IsItemInBag (BH=id → ZF = not in bag)
;   IsKeyItem    — pret home/item.asm:IsKeyItem        (thin save-regs wrapper)
;   IsKeyItem_   — pret engine/items/item_effects.asm:IsKeyItem_
;                                                      ([wCurItem] → [wIsKeyItem])
;
; TWO-TIER NOTE (per CLAUDE.md): HMMoves is *code*, not generated data — a
; small hand-authored `db` list of HM move ids. pret INCLUDEs
; data/moves/hm_moves.asm here (and again for HMMoveArray in bills_pc.asm); we
; inline the five ids directly as a Tier-2 table. It is NOT emitted by any
; tools/gen_*.py and `make assets` must never touch it.
;
; Register map: A=AL, HL=ESI, BC=EBX (B=BH,C=BL), DE=EDX. GB memory = [ebp+SYM].
;
; Build: nasm -f coff -I dos_port/include -I dos_port -o /dev/null \
;            dos_port/src/home/item_predicates.asm
; ===========================================================================

bits 32

%include "gb_constants.inc"     ; HM01, TM01, FLAG_TEST, CUT/FLY/SURF/STRENGTH/FLASH
%include "gb_memmap.inc"        ; wCurItem, wIsKeyItem, wBuffer, wPredefBC

global IsItemHM
global IsMoveHM
global HMMoves
global IsItemInBag
global IsKeyItem
global IsKeyItem_

extern IsInArray                ; src/home/array.asm — flat $FF-terminated search
extern GetQuantityOfItemInBag   ; src/engine/items/get_bag_item_quantity.asm (predef)
extern FlagAction               ; src/engine/flag_action.asm — ESI=base, CL=bit, BH=act
extern KeyItemFlags             ; src/data/item_data.asm — flat LSB-first bit array

section .text

; ---------------------------------------------------------------------------
; IsItemHM — pret home/names.asm:IsItemHM.
; Sets CF if the item id is an HM (HM01..TM01-1, i.e. $C4..$C8), else clears CF.
; Faithful: pret `cp HM01 / jr c,.notHM / cp TM01 / ret` — after the second
; compare CF = (A < TM01), and since A >= HM01 here that is exactly "is HM".
; In:  AL = item id.   Out: CF = 1 if HM.   Clobbers nothing but flags.
; ---------------------------------------------------------------------------
IsItemHM:
    cmp al, HM01                ; cp HM01
    jb .notHM                   ; jr c  (unsigned A < HM01 → below HMs)
    cmp al, TM01                ; cp TM01 → CF = (A < TM01)  [A >= HM01 here]
    ret
.notHM:
    clc                         ; and a  (clears carry)
    ret

; ---------------------------------------------------------------------------
; IsMoveHM — pret home/names.asm:IsMoveHM.
; Sets CF if the move id is one of the five HM moves.
; Faithful: `ld hl, HMMoves / ld de, 1 / jp IsInArray`. HMMoves is a flat
; .data table; IsInArray reads it with flat [ESI] addressing (matches the
; other HM/effect-category arrays), so pass the flat label directly.
; In:  AL = move id.   Out: CF = 1 if HM move, BH = index.  (tail call)
; ---------------------------------------------------------------------------
IsMoveHM:
    mov esi, HMMoves            ; ld hl, HMMoves (flat label)
    mov edx, 1                  ; ld de, 1  (entry stride)
    jmp IsInArray              ; jp IsInArray → returns CF

; ---------------------------------------------------------------------------
; IsItemInBag — pret home/map_objects.asm:IsItemInBag.
; Zero flag SET if the item is NOT in the bag, RESET if it is.
; pret invokes `predef GetQuantityOfItemInBag` (b = item id). The port's
; GetQuantityOfItemInBag opens with GetPredefRegisters, which reloads BX from
; wPredefBC — so stash the item id there first. (The predef dispatcher is dead
; code in the port; the documented convention is to populate the wPredef*
; slots directly at the call site — see src/home/predef.asm header.)
; In:  BH = item id.   Out: ZF = 1 if not in bag; BH = quantity.  AL clobbered.
; ---------------------------------------------------------------------------
IsItemInBag:
    mov [ebp + wPredefBC], bh        ; b → wPredefBC high byte (GetPredefRegisters)
    mov [ebp + wPredefBC + 1], bl    ; c → low byte (unused by callee; kept faithful)
    call GetQuantityOfItemInBag      ; → BH = quantity of that item in the bag
    mov al, bh                       ; ld a, b
    and al, al                       ; and a  (ZF=1 ⇒ qty 0 ⇒ not in bag)
    ret

; ---------------------------------------------------------------------------
; IsKeyItem — pret home/item.asm:IsKeyItem.
; Thin wrapper: preserve HL/DE/BC and run IsKeyItem_ (a farcall in pret; a plain
; call under the flat model). Result left in [wIsKeyItem].
; In:  [wCurItem] = item id.   Out: [wIsKeyItem] = 0/1.
; ---------------------------------------------------------------------------
IsKeyItem:
    push esi                    ; push hl
    push edx                    ; push de
    push ebx                    ; push bc
    call IsKeyItem_             ; farcall IsKeyItem_
    pop ebx                     ; pop bc
    pop edx                     ; pop de
    pop esi                     ; pop hl
    ret

; ---------------------------------------------------------------------------
; IsKeyItem_ — pret engine/items/item_effects.asm:IsKeyItem_.
; Decides whether [wCurItem] is a "key" (untossable/unsellable) item and writes
; the 0/1 result to [wIsKeyItem].
;   * HMs ($C4..$C8)          → key.
;   * TMs ($C9+)              → not key.
;   * everything below $C4    → key iff KeyItemFlags bit (id-1) is set.
;
; Faithful structure. Two port-specific substitutions, both behavior-preserving:
;  1) pret copies KeyItemFlags into wBuffer with `CopyData` (a ROM→WRAM copy).
;     The port's CopyData is GB→GB only and KeyItemFlags is a FLAT .data table,
;     so we inline the flat→GB copy. FlagAction reads its array with [ebp+ESI],
;     hence the bit array must live in GB WRAM (wBuffer) first — same reason
;     pret stages it there.
;  2) pret does `predef FlagActionPredef`; we `call FlagAction` directly.
;     FlagActionPredef begins with GetPredefRegisters, which would clobber the
;     ESI/BH/CL we set up (no predef-slot setup here) — so, per the established
;     port pattern (see experience.asm "FIX: was FlagActionPredef"), the direct
;     FlagAction leaf is the faithful equivalent when registers are set by hand.
;
; In:  [wCurItem] = item id.   Out: [wIsKeyItem] = 0/1.  Clobbers AL, ECX (CL).
; ---------------------------------------------------------------------------
IsKeyItem_:
    mov al, 1
    mov [ebp + wIsKeyItem], al       ; ld [wIsKeyItem], 1  (assume key)
    mov al, [ebp + wCurItem]         ; ld a, [wCurItem]
    cmp al, HM01                     ; cp HM01
    jae .checkIfItemIsHM             ; jr nc  (HM/TM range → skip bit array)

    ; --- not an HM/TM: consult KeyItemFlags bit (id-1) --------------------
    push eax                         ; push af  (save item id)
    push esi
    push edi
    mov esi, KeyItemFlags            ; flat source (pret: ld hl, KeyItemFlags)
    lea edi, [ebp + wBuffer]         ; GB dest  (pret: ld de, wBuffer)
    mov ecx, 15                      ; ld bc, 15  (ASSERT 15 >= (NUM_ITEMS+7)/8)
    rep movsb                        ; CopyData (flat→GB inline)
    pop edi
    pop esi
    pop eax                          ; pop af   (restore item id)

    dec al                           ; dec a
    mov cl, al                       ; ld c, a   (bit index = id-1)
    mov esi, wBuffer                 ; ld hl, wBuffer (GB offset; FlagAction adds ebp)
    mov bh, FLAG_TEST                ; ld b, FLAG_TEST
    call FlagAction                 ; predef FlagActionPredef → direct FlagAction
    mov al, cl                       ; ld a, c   (FlagAction returns result in CL)
    and al, al                       ; and a
    jnz .ret                         ; ret nz    (bit set → key; wIsKeyItem stays 1)

.checkIfItemIsHM:
    mov al, [ebp + wCurItem]         ; ld a, [wCurItem]
    call IsItemHM                    ; CF = is HM
    jc .ret                          ; ret c     (HM → key; wIsKeyItem stays 1)
    xor al, al
    mov [ebp + wIsKeyItem], al       ; ld [wIsKeyItem], 0  (not a key item)
.ret:
    ret

; ===========================================================================
; Tier-2 data (hand-authored code table, NOT generated — see header note).
; pret: data/moves/hm_moves.asm. Flat .data so IsInArray's [ESI] reads reach it.
; ===========================================================================
section .data

HMMoves:
    db CUT                       ; $0F
    db FLY                       ; $13
    db SURF                      ; $39
    db STRENGTH                  ; $46
    db FLASH                     ; $94
    db 0xFF                      ; db -1 ; end (IsInArray terminator)
