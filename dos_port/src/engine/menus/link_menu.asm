; ===========================================================================
; link_menu.asm — the link (cable club) MENU/DISPATCH half of pret
; engine/menus/link_menu.asm.  menus-port Session 8, package I1.
;
; SCOPE (this file): the two link menus and their scaffolding —
;   * LinkMenu            — TRADE CENTER / COLOSSEUM / COLOSSEUM2 / CANCEL select
;   * Func_f531b          — the Colosseum cup-select screen (View/Rules + cup
;                           list + rules panel) and Func_f56bd (rules redraw)
;   * Func_f59ec          — the LinkMenu locked-in cursor-arrow blit
;   * the menu/rules text tables + the Colosseum*Text message wrappers
;   * Func_f5476 / asm_f547c / asm_f547f dispatch tails
;   * PointerTable_f5488 (dd PokeCup/PikaCup/PetitCup — SEAM to package I2)
;   * PointerTable_f56ee (dd Text_f56f4/5728/575b)
; The cup-eligibility routines PokeCup/PikaCup/PetitCup + their result routines
; (NotThreeMonsInParty, MewInParty, LevelAbove55, ...) are package I2
; (link_cups.asm); I2 externs the Colosseum*Text text_far wrappers FROM this file
; and prints them itself, the way pret does (ld hl, X / call PrintText).
;
; ---------------------------------------------------------------------------
; PORT MODEL (CLAUDE.md + translation_log "menus-port S2..S7"):
;  * SM83->x86: A=AL, BC=BX (B=BH,C=BL), DE=DX, HL=ESI, EBP = GB base; GB memory
;    at [EBP+sym] (gb_memmap.inc).  FLAGS ARE NOT THE GB'S — every ZF/CF branch is
;    re-derived on the flag set by the SAME op pret used.
;  * WINDOW/CANVAS model (S4-S7): menus are drawn into the 20-wide stride-20
;    W_TILEMAP scratch (hlcoord X,Y = W_TILEMAP + Y*20 + X), mirrored to a GB
;    tilemap canvas (GB_TILEMAP0 menu / GB_TILEMAP1 messages), and shown as a
;    ppu window (add_window / set_single_window).  HandleMenuInput draws the ▶
;    cursor into the scratch (text_row_stride row multiply, menu_item_step per
;    item) and re-runs menu_redraw_cb each frame to re-mirror it.
;      - LinkMenu   — small box overlaid on the overworld → a SUB-RECT window at
;                     UI_LINK_MENU, drawn BOX-RELATIVE (box origin = scratch 0,0).
;      - Func_f531b — 3 boxes filling the screen → a FULL-TAKEOVER window at
;                     UI_LINK_CUP_MENU (g_bg_whiteout=1), drawn GB-ABSOLUTE into
;                     the stride-20 scratch (options.asm / naming_screen refs).
;  * TEXT: PlaceString wants EAX = FLAT src ptr (a .data label, or lea eax,[ebp+n]
;    for GB memory), NOT pret's DE.  <NEXT> ($4E) double-spaces by default (as
;    pret's 2*SCREEN_WIDTH), which is what the two menus and the rules panel want.
;  * MESSAGES (Colosseum*Text): pret's own text_far streams (data/text/text_3.asm),
;    printed by PrintText through the msgbox_dialog projection — pret's shape,
;    call for call (row 20 part 1, M-109).  Until then this file claimed PrintText
;    was unusable here and reimplemented it: each message line was a hand-encoded
;    charmap `db` run, the twenty pret text DATA labels were redefined as print
;    ROUTINES (`call ColosseumMewText`), and a private lm_msg_* engine drew the box,
;    typed the lines, blinked the ▼ and waited.  It is usable — save.asm / pc.asm /
;    players_pc.asm / oaks_pc.asm / league_pc.asm / main_menu.asm all print with it,
;    and the three name-splicing streams (_Colosseum{Height,Weight,Evolved}Text are
;    `text_ram wNameBuffer` texts) are only expressible through it.
;      ; DEVIATION(window-compositor): the msgbox_dialog projection presents the box
;      with set_single_window, so a message REPLACES the screen behind it for as long
;      as it is up (pret overlays the box on the live tilemap).  Each caller's next
;      act is the redraw that restores it — Func_f531b's `jp Func_f531b` retry, or
;      LinkMenu's .choseCancel window-stack drop.  Same trade as save.asm's dialogs.
;  * SERIAL IS ALL STUBS (no port serial hardware).  Every Serial_* /
;    CloseLinkConnection / hSerial* / rSC access is ; TODO-HW: network HAL, and the
;    stubs are tuned so the single-player (no-partner) collapse drives each menu to
;    pret's terminal path (LinkMenu -> .choseCancel; Func_f531b -> retry / cancel)
;    and NEVER a bare ret that skips CloseLinkConnection / the cancel dialog.  The
;    exact return contract is documented at each stub below.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/link_menu.asm
;   (canonical: make -C dos_port check)
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "gb_text.inc"                  ; text_far / text_end
%include "msgbox.inc"                   ; the msgbox projection record

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

; ---------------------------------------------------------------------------
; externs — window compositor / text / menu driver / frame timing
; ---------------------------------------------------------------------------
extern TextBoxBorder            ; text/text.asm — ESI=top-left, BL=int_w, BH=int_h
extern PlaceString              ; text/text.asm — EAX=flat src, ESI=dest (<NEXT> aware)
extern PrintText                ; home/window.asm — In: ESI = text stream
extern text_msgbox              ; home/text.asm — the active msgbox projection
extern msgbox_dialog            ; home/text.asm — the dialog projection record
extern text_row_stride          ; text/text.asm — active W_TILEMAP row stride
extern add_window               ; ppu/ppu.asm — EAX=wx EBX=wy ECX=clip EDX=maxy ESI=tm EDI=row
extern set_single_window        ; ppu/ppu.asm — count:=1 then add (full takeover)
extern g_window_count           ; ppu/ppu.asm — active window count (window stack top)
extern g_bg_whiteout            ; ppu/ppu.asm — 1 = full-screen takeover (no BG behind)
extern menu_item_step           ; home/window.asm — per-item cursor row step
extern menu_redraw_cb           ; home/window.asm — per-frame redraw cb (0=none)
extern PlaceMenuCursor          ; home/window.asm — draw ▶ at wTopMenuItem{X,Y}
extern HandleMenuInput          ; home/window.asm — Out: AL = watched keys pressed
extern DelayFrame               ; video/frame.asm
extern DelayFrames              ; video/frame.asm — In: BL = frame count
extern Delay3                   ; video/frame.asm
extern UpdateSprites            ; engine/overworld/movement.asm

; --- dispatch seam (ROOT-WIRED, Session 9 spine) ---------------------------
extern PrepareForSpecialWarp    ; engine/overworld/special_warps.asm (callfar target)
extern SpecialEnterMap          ; engine/menus/main_menu.asm       (jpfar target)

; --- SEAM to package I2 (link_cups.asm): PointerTable_f5488 targets ---------
extern PokeCup                  ; link_cups.asm — POKé Cup eligibility check
extern PikaCup                  ; link_cups.asm — Pika Cup eligibility check
extern PetitCup                 ; link_cups.asm — Petit Cup eligibility check

; ---------------------------------------------------------------------------
; globals — the pret-named routines / data (I2 + root reference these)
; ---------------------------------------------------------------------------
global Func_f531b
global Func_f56bd
global Func_f59ec
global Func_f5476
global asm_f547c
global asm_f547f
global LinkMenu
global PointerTable_f5488
global PointerTable_f56ee
global Text_f56f4
global Text_f5728
global Text_f575b
global Text_f5791
global Text_f579c
global TradeCenterText
global TextTerminator_f5a16
; --- Colosseum*Text — pret's text_far WRAPPERS (data). I2 prints these. -----
global Colosseum3MonsText
global ColosseumMewText
global ColosseumDifferentMonsText
global ColosseumMaxL55Text
global ColosseumMinL50Text
global ColosseumTotalL155Text
global ColosseumMaxL30Text
global ColosseumMinL25Text
global ColosseumTotalL80Text
global ColosseumMaxL20Text
global ColosseumMinL15Text
global ColosseumTotalL50Text
global ColosseumHeightText
global ColosseumWeightText
global ColosseumEvolvedText
global ColosseumIneligibleText
global ColosseumWhereToText
global ColosseumPleaseWaitText
global ColosseumCanceledText
global ColosseumVersionText

; ---------------------------------------------------------------------------
; local fallback WRAM equates — REPORTED to root for gb_memmap.inc (rule 4).
; pret ram/wram.asm addresses derived from the wEnteringCableClub=0xCC47 anchor
; (main_menu.asm, sym 00:cc47) + the two UNION members at wram.asm:424-446:
;   member A: wLinkMenuSelectionReceiveBuffer(dw) ds3 wLinkMenuSelectionSendBuffer(dw)
;             ds3 wEnteringCableClub  ->  0xCC3D / 0xCC42 / 0xCC47
;   member B: wSerialSyncAndExchangeNybbleReceiveData(=recv buf, 0xCC3D)
;             wSerialExchangeNybbleReceiveData(0xCC3E) ds3
;             wSerialExchangeNybbleSendData(0xCC42) ds4 wUnknownSerialCounter(dw,0xCC47)
; NOTE the deliberate pret union aliases used by this code:
;   wLinkMenuSelectionReceiveBuffer == wSerialSyncAndExchangeNybbleReceiveData (0xCC3D)
;   wLinkMenuSelectionSendBuffer    == wSerialExchangeNybbleSendData          (0xCC42)
;   wEnteringCableClub              == wUnknownSerialCounter                  (0xCC47)
; ---------------------------------------------------------------------------
; The link-menu / serial-exchange WRAM + HRAM symbols
; (wLinkMenuSelection{Send,Receive}Buffer, wSerial*NybbleData, wUnknownSerialCounter,
; wEnteringCableClub, wUnusedLinkMenuByte, hSerial{Send,Receive}Data) are defined
; authoritatively in gb_memmap.inc (sym-verified, S8). NASM %ifndef does not see
; `equ` labels, so no local fallback block here — gb_memmap is the single source.

; --- constants not (yet) in the port includes ------------------------------
%ifndef BIT_DEBUG_MODE
BIT_DEBUG_MODE          equ 1              ; wStatusFlags6 (constants/ram_constants.asm)
%endif
%ifndef TRADE_CENTER
TRADE_CENTER            equ 0xEF           ; constants/map_constants.asm
%endif
%ifndef COLOSSEUM
COLOSSEUM               equ 0xF0           ; constants/map_constants.asm
%endif
LINK_STATE_IN_CABLE_CLUB equ 0x01          ; constants/serial_constants.asm
USING_INTERNAL_CLOCK     equ 0x02          ; constants/serial_constants.asm
CONNECTION_NOT_ESTABLISHED equ 0xFF        ; constants/serial_constants.asm

; --- charmap tiles (constants/charmap.asm; NOT GB-memory symbols) ----------
CHAR_SPACE  equ 0x7F            ; ' '  blank tile
CHAR_RARROW equ 0xEC            ; '▷'  unfilled right arrow

; --- stride-20 scratch geometry --------------------------------------------
LM_STRIDE   equ 20
%define CUP(X,Y)  (W_TILEMAP + (Y) * LM_STRIDE + (X))   ; cup screen GB-absolute
%define LMB(X,Y)  (W_TILEMAP + (Y) * LM_STRIDE + (X))   ; LinkMenu box-relative

; ===========================================================================
section .bss
align 4
lm_link_wc:  resd 1             ; g_window_count baseline at LinkMenu entry

; ===========================================================================
section .data
align 4

; --- PointerTable_f5488 — cup eligibility dispatch (SEAM to I2) -------------
; pret dw -> port dd (flat 32-bit; COFF rejects 16-bit relocations).
PointerTable_f5488:
    dd PokeCup
    dd PikaCup
    dd PetitCup

; --- PointerTable_f56ee — rules-panel text for currentMenuItem 0/1/2 --------
PointerTable_f56ee:
    dd Text_f56f4
    dd Text_f5728
    dd Text_f575b

; --- Tier-1 DATA: every rendered string of pret engine/menus/link_menu.asm ---
; The six `db` strings pret writes inline in the code file (Text_f56f4 / Text_f5728 /
; Text_f575b — the cup rules panels; Text_f5791 View/Rules; Text_f579c the cup list;
; TradeCenterText) AND the twenty text_far message bodies (_Colosseum*Text,
; data/text/text_3.asm), all generated by tools/gen_menu_strings.py.
; Hand-encoded charmap `db` runs until row 20 part 1 (M-109); the six generated db
; strings are byte-identical to the literals they replace, and the message streams
; are pret's own — the three `text_ram wNameBuffer` ones (Height/Weight/Evolved)
; could not be expressed as glyph runs at all.
%include "assets/link_text.inc"

; ===========================================================================
section .text

; ###########################################################################
; # SERIAL STUBS — ; TODO-HW: network HAL (Phase 4). No port serial hardware.
; #
; # No-partner (single-player) return CONTRACT — tuned so each menu reaches its
; # pret terminal path with no bare ret:
; #   hSerialConnectionStatus := CONNECTION_NOT_ESTABLISHED ($ff) at each menu
; #     entry (below).  $ff != USING_INTERNAL_CLOCK, so every "who clocks the
; #     connection wins" / "start the transfer" branch takes the not-internal
; #     path deterministically.
; #   Serial_ExchangeByte          -> AL := $C0 (Func_f531b only): high nybble
; #     $C0 satisfies `and $f0 / cp $c0`, low nybble 0 = "enemy present, idle,
; #     no A/B" -> the "enemy didn't press A/B" branch, player's own selection
; #     used.  Fixed value => the double-read `cp b` is always equal.
; #   Serial_ExchangeLinkMenuSelection -> receive buffer[0..1] := $D0 (LinkMenu):
; #     high nybble $D0 satisfies `and $f0 / cp $d0` (loop exits), low nybble 0 =
; #     "enemy didn't press A/B" -> player's selection used.
; #   Serial_ExchangeNybble        -> wSerialExchangeNybbleReceiveData := $ff
; #     ("no response"); LinkMenu .asm_f5963's `inc a / jr z` keeps looping until
; #     the b=$78 frame counter expires -> the .asm_f59b2 timeout -> .choseCancel.
; #   Serial_SyncAndExchangeNybble -> wSerialSyncAndExchangeNybbleReceiveData
; #     (== wLinkMenuSelectionReceiveBuffer, 0xCC3D) := $ff (remote "ineligible"/
; #     no response) -> Func_f531b takes Func_f5476 (ColosseumIneligibleText) ->
; #     asm_f547c (jp Func_f531b, retry).  Never a bare ret.
; #   Serial_SendZeroByte / CloseLinkConnection -> no-op (flag-preserving).
; ###########################################################################

Serial_ExchangeByte:
    ; TODO-HW: network HAL — exchange one byte with the link partner.
    mov al, 0xC0                    ; fixed "idle partner" byte (see CONTRACT)
    ret

Serial_ExchangeLinkMenuSelection:
    ; TODO-HW: network HAL — Serial_ExchangeByte the 2-byte send/receive buffers.
    mov byte [ebp + wLinkMenuSelectionReceiveBuffer], 0xD0
    mov byte [ebp + wLinkMenuSelectionReceiveBuffer + 1], 0xD0
    ret

Serial_ExchangeNybble:
    ; TODO-HW: network HAL — exchange one nybble; leaves "no response".
    mov byte [ebp + wSerialExchangeNybbleReceiveData], 0xFF
    ret

Serial_SyncAndExchangeNybble:
    ; TODO-HW: network HAL — sync + nybble exchange; leaves remote "no response".
    ; 0xCC3D is BOTH wSerialSyncAndExchangeNybbleReceiveData and (union-aliased)
    ; wLinkMenuSelectionReceiveBuffer, which Func_f531b reads next.
    mov byte [ebp + wSerialSyncAndExchangeNybbleReceiveData], 0xFF
    ret

Serial_SendZeroByte:
    ; TODO-HW: network HAL — send $00; no-op stub.
    ret

CloseLinkConnection:
    ; TODO-HW: network HAL — tear down the serial link; no-op stub.
    ret

; ###########################################################################
; # Colosseum*Text — pret's text_far WRAPPERS (engine/menus/link_menu.asm:571-633).
; # These are DATA, not routines: `ld hl, ColosseumMewText / call PrintText` is how
; # pret prints one, and link_cups.asm's result routines do exactly that.  The
; # Tier-1 stream bodies live in assets/link_text.inc.
; ###########################################################################
Colosseum3MonsText:
    text_far _Colosseum3MonsText
    text_end

ColosseumMewText:
    text_far _ColosseumMewText
    text_end

ColosseumDifferentMonsText:
    text_far _ColosseumDifferentMonsText
    text_end

ColosseumMaxL55Text:
    text_far _ColosseumMaxL55Text
    text_end

ColosseumMinL50Text:
    text_far _ColosseumMinL50Text
    text_end

ColosseumTotalL155Text:
    text_far _ColosseumTotalL155Text
    text_end

ColosseumMaxL30Text:
    text_far _ColosseumMaxL30Text
    text_end

ColosseumMinL25Text:
    text_far _ColosseumMinL25Text
    text_end

ColosseumTotalL80Text:
    text_far _ColosseumTotalL80Text
    text_end

ColosseumMaxL20Text:
    text_far _ColosseumMaxL20Text
    text_end

ColosseumMinL15Text:
    text_far _ColosseumMinL15Text
    text_end

ColosseumTotalL50Text:
    text_far _ColosseumTotalL50Text
    text_end

; The three name-splicing streams: each begins `text_ram wNameBuffer`, so the mon
; name link_cups.asm just fetched with GetMonName is spliced in by the text engine.
ColosseumHeightText:
    text_far _ColosseumHeightText
    text_end

ColosseumWeightText:
    text_far _ColosseumWeightText
    text_end

ColosseumEvolvedText:
    text_far _ColosseumEvolvedText
    text_end

ColosseumIneligibleText:
    text_far _ColosseumIneligibleText
    text_end

; ###########################################################################
; # Func_f531b — the Colosseum cup-select screen
; ###########################################################################

; --- cup_mirror — blit the stride-20 scratch rows 0-17 -> GB_TILEMAP0 rows 0-17
; (the full-takeover window source). Preserves all registers (menu_redraw_cb).
cup_mirror:
    pushad
    xor ebx, ebx
.row:
    imul esi, ebx, LM_STRIDE
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                      ; ×32 tilemap stride
    lea edi, [ebp + edi + GB_TILEMAP0]
    mov ecx, LM_STRIDE
    rep movsb
    inc ebx
    cmp ebx, UI_LINK_CUP_MENU_GBH   ; 18 rows
    jb .row
    popad
    ret

; cup_show_window — expose the finished scratch as the full-takeover window.
cup_show_window:
    mov dword [g_bg_whiteout], 1
    call cup_mirror
    mov eax, UI_LINK_CUP_MENU_WX
    mov ebx, UI_LINK_CUP_MENU_WY
    mov ecx, UI_LINK_CUP_MENU_CLIP
    mov edx, UI_LINK_CUP_MENU_MAXY
    mov esi, GB_TILEMAP0
    xor edi, edi
    call set_single_window
    ret

; lm_cup_setup — draw the 3 boxes + labels, init the vertical menu, show the
; window.  (Func_f531b body up to the .asm_f5377 loop; also used by the harness.)
lm_cup_setup:
    ; ld a,$1 / ld [wBuffer],a ; xor a / ld [wUnknownSerialFlag_d499],a
    mov byte [ebp + wBuffer], 1
    mov byte [ebp + wUnknownSerialFlag_d499], 0
    mov dword [text_row_stride], LM_STRIDE
    ; hlcoord 0,0 / lb bc,4,5 / TextBoxBorder — View/Rules box (interior 5x4)
    mov esi, CUP(0, 0)
    mov bl, 5
    mov bh, 4
    call TextBoxBorder
    ; ld de,Text_f5791 / hlcoord 1,2 / PlaceString
    mov eax, Text_f5791
    mov esi, CUP(1, 2)
    call PlaceString
    ; hlcoord 8,0 / lb bc,8,10 / TextBoxBorder — cup list box (interior 10x8)
    mov esi, CUP(8, 0)
    mov bl, 10
    mov bh, 8
    call TextBoxBorder
    ; hlcoord 10,2 / ld de,Text_f579c / PlaceString
    mov eax, Text_f579c
    mov esi, CUP(10, 2)
    call PlaceString
    ; hlcoord 0,10 / lb bc,6,18 / TextBoxBorder — rules panel (interior 18x6)
    mov esi, CUP(0, 10)
    mov bl, 18
    mov bh, 6
    call TextBoxBorder
    call UpdateSprites
    ; xor a -> wUnusedLinkMenuByte / wCableClubDestinationMap / wNamedObjectIndex
    mov byte [ebp + wUnusedLinkMenuByte], 0
    mov byte [ebp + wCableClubDestinationMap], 0
    mov byte [ebp + wNamedObjectIndex], 0
    ; menu state: wTopMenuItemY=2, X=9, cur=0, max=3, watched=A|B, last=0
    mov byte [ebp + wTopMenuItemY], 2
    mov byte [ebp + wTopMenuItemX], 9
    mov byte [ebp + wCurrentMenuItem], 0
    mov byte [ebp + wMaxMenuItem], 3
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    mov byte [ebp + wLastMenuItem], 0
    ; cursor stepping: double-spaced (2 rows/item) on the stride-20 scratch
    mov dword [menu_item_step], 2 * LM_STRIDE
    mov dword [menu_redraw_cb], cup_mirror
    call cup_show_window
    ret

Func_f531b:
    ; ld c,$14 / call DelayFrames
    mov bl, 0x14
    call DelayFrames
    call lm_cup_setup
.asm_f5377:
    call Func_f56bd                 ; redraw the rules panel for the current cup
    call HandleMenuInput            ; Out: AL = watched keys (A|B) pressed
    ; and $3 / add a / add a / ld b,a
    and al, 3
    add al, al
    add al, al
    mov bh, al                      ; B = shifted keys (bit2=A, bit3=B)
    ; ld a,[wCurrentMenuItem] / cp $3 / jr nz .asm_f5390
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 3
    jne .asm_f5390
    ; bit 2, b / jr z .asm_f5390  (A pressed on CANCEL -> treat as B)
    test bh, 1 << 2
    jz .asm_f5390
    dec al
    mov bh, 0x8
.asm_f5390:
    ; add b / add $c0 -> send buffer[0..1]
    add al, bh
    add al, 0xC0
    mov [ebp + wLinkMenuSelectionSendBuffer], al
    mov [ebp + wLinkMenuSelectionSendBuffer + 1], al
.asm_f5399:
    ; send/receive the byte twice, require two equal reads whose hi nybble = $c0.
    ; TODO-HW: network HAL — hSerialSendData is written but the stub ignores it.
    mov al, [ebp + wLinkMenuSelectionSendBuffer]
    mov [ebp + hSerialSendData], al
    call Serial_ExchangeByte
    mov cl, al                      ; C = first received byte (pret: push af)
    mov al, [ebp + wLinkMenuSelectionSendBuffer]
    mov [ebp + hSerialSendData], al
    call Serial_ExchangeByte
    ; pop bc / cp b  (compare 2nd read AL with 1st read, held in CL)
    cmp al, cl
    jne .asm_f5399
    ; and $f0 / cp $c0 / jr nz .asm_f5399
    and al, 0xF0
    cmp al, 0xC0
    jne .asm_f5399
    ; ld a,b / and $c / jr nz .asm_f53c4   (did the enemy press A or B?)
    mov al, cl
    and al, 0x0C
    jnz .asm_f53c4
    ; the enemy didn't press A/B
    mov al, [ebp + wLinkMenuSelectionSendBuffer]
    and al, 0x0C
    jz .asm_f5377                   ; neither pressed A/B -> keep waiting
    jmp .asm_f53df                  ; player pressed A/B -> use player's selection
.asm_f53c4:
    ; the enemy pressed A or B
    mov al, [ebp + wLinkMenuSelectionSendBuffer]
    and al, 0x0C
    jz .asm_f53d1                   ; player didn't press -> use enemy's selection
    ; both pressed: the gameboy clocking the connection wins.
    mov al, [ebp + H_SERIAL_CONN_STATUS]  ; TODO-HW: network HAL
    cmp al, USING_INTERNAL_CLOCK
    je .asm_f53df
.asm_f53d1:
    mov byte [ebp + wNamedObjectIndex], 1
    mov al, cl                      ; ld a,b
    mov [ebp + wLinkMenuSelectionSendBuffer], al
    and al, 3
    mov [ebp + wCurrentMenuItem], al
.asm_f53df:
    call DelayFrame
    call DelayFrame
    mov al, [ebp + wLinkMenuSelectionSendBuffer]
    mov [ebp + hSerialSendData], al ; TODO-HW: network HAL
    call Serial_ExchangeByte
    call Serial_ExchangeByte
    mov bh, 0x14                    ; ld b,$14 — drain 20 zero bytes
.loop:
    call DelayFrame
    call Serial_SendZeroByte        ; TODO-HW: network HAL
    dec bh
    jnz .loop
    ; --- lock in the ▷ cursor arrows (single-player: the chosen cup) ----------
    ; b=' ' c=' ' d=' ' e='▷'  (BH/BL/DH/DL); pret distributes ▷ per selection.
    mov bh, CHAR_SPACE
    mov bl, CHAR_SPACE
    mov dh, CHAR_SPACE
    mov dl, CHAR_RARROW
    mov al, [ebp + wLinkMenuSelectionSendBuffer]
    test al, 1 << 3                 ; bit 3 = B pressed?
    jnz .asm_f541a
    ; A pressed: move ▷ up the list to the chosen item
    mov bh, dl                      ; ld b,e
    mov dl, bl                      ; ld e,c
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jz .asm_f541a
    mov bl, bh                      ; ld c,b
    mov bh, dh                      ; ld b,d
    dec al
    jz .asm_f541a
    mov dh, bl                      ; ld d,c
    mov bl, bh                      ; ld c,b
.asm_f541a:
    mov al, bh
    mov [ebp + CUP(9, 2)], al
    mov al, bl
    mov [ebp + CUP(9, 4)], al
    mov al, dh
    mov [ebp + CUP(9, 6)], al
    mov al, dl
    mov [ebp + CUP(9, 8)], al
    call cup_mirror
    mov bl, 40
    call DelayFrames
    ; --- dispatch: B -> cancel; A -> eligibility check for the chosen cup ------
    mov al, [ebp + wLinkMenuSelectionSendBuffer]
    test al, 1 << 3                 ; bit 3 = B pressed?
    jnz asm_f547f
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 3                       ; CANCEL?
    je asm_f547f
    inc al
    mov [ebp + wUnknownSerialFlag_d499], al
    ; hl = PointerTable_f5488[currentMenuItem]; call it (returns eligibility in AL).
    ; SEAM: PokeCup/PikaCup/PetitCup live in package I2 (link_cups.asm).
    movzx ecx, byte [ebp + wCurrentMenuItem]
    mov esi, PointerTable_f5488
    mov esi, [esi + ecx * 4]        ; port dd table (pret dw -> dd)
    call esi                        ; -> pret .returnaddress
.returnaddress:
    mov [ebp + wLinkMenuSelectionSendBuffer], al ; local eligibility result
    mov word [ebp + wUnknownSerialCounter], 0
    call Serial_SyncAndExchangeNybble           ; TODO-HW: network HAL
    ; local ineligible? (send buffer != 0)
    mov al, [ebp + wLinkMenuSelectionSendBuffer]
    and al, al
    jnz asm_f547c
    ; remote ineligible? (receive buffer != 0; union-aliased to the nybble recv)
    mov al, [ebp + wLinkMenuSelectionReceiveBuffer]
    and al, al
    jnz Func_f5476
    ; both eligible -> return CF=0 (proceed).
    mov word [ebp + wUnknownSerialCounter], 0
    xor al, al                      ; and a -> CF=0
    ret

Func_f5476:
    ; ld hl, ColosseumIneligibleText / call PrintText — the REMOTE player's team
    ; failed his cup check.  The stream ends in `prompt`; asm_f547c then redraws.
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumIneligibleText
    call PrintText
asm_f547c:
    jmp Func_f531b

asm_f547f:
    mov word [ebp + wUnknownSerialCounter], 0
    stc                             ; scf -> CF=1 (cancel)
    ret

; ###########################################################################
; # Func_f56bd — redraw the rules panel for the current cup selection
; ###########################################################################
Func_f56bd:
    ; xor a / ldh [hAutoBGTransferEnabled],a — window model; manual mirror below.
    mov byte [ebp + hAutoBGTransferEnabled], 0
    mov dword [text_row_stride], LM_STRIDE
    ; hlcoord 1,11 / lb bc,6,18 / ClearScreenArea (interior of the rules panel)
    ; ; DEVIATION(stride): the port ClearScreenArea is baked to SCREEN_WIDTH(40);
    ; this scratch is stride-20, so clear inline (6 rows x 18 cols from (1,11)).
    xor ebx, ebx
.clr_row:
    mov edi, ebx
    imul edi, edi, LM_STRIDE
    lea edi, [ebp + edi + CUP(1, 11)]
    mov al, CHAR_SPACE
    mov ecx, 18
    rep stosb
    inc ebx
    cmp ebx, 6
    jb .clr_row
    ; ld a,[wCurrentMenuItem] / cp $3 / jr nc .asm_f56e6  (CANCEL -> no rules)
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 3
    jnc .asm_f56e6
    ; de = PointerTable_f56ee[currentMenuItem]; hlcoord 1,12 / PlaceString
    movzx ecx, al
    mov esi, PointerTable_f56ee
    mov eax, [esi + ecx * 4]        ; flat string ptr
    mov esi, CUP(1, 12)
    call PlaceString
.asm_f56e6:
    call cup_mirror                 ; expose the redrawn rules in the window
    call Delay3
    mov byte [ebp + hAutoBGTransferEnabled], 1
    ret

; ###########################################################################
; # LinkMenu — TRADE CENTER / COLOSSEUM / COLOSSEUM2 / CANCEL
; ###########################################################################

; lm_link_mirror — blit the LinkMenu box (scratch rows 0-9, cols 0-14) ->
; GB_TILEMAP0 rows 0-9.  Sub-rect (no whiteout).  Preserves all regs.
lm_link_mirror:
    pushad
    xor ebx, ebx
.row:
    imul esi, ebx, LM_STRIDE
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5
    lea edi, [ebp + edi + GB_TILEMAP0]
    mov ecx, 15                     ; box width (cols 0-14)
    rep movsb
    inc ebx
    cmp ebx, 10                     ; box height (rows 0-9)
    jb .row
    popad
    ret

; lm_link_show_window — append the LinkMenu box as a sub-rect window (overlay).
lm_link_show_window:
    call lm_link_mirror
    mov eax, UI_LINK_MENU_WX
    mov ebx, UI_LINK_MENU_WY
    mov ecx, UI_LINK_MENU_CLIP
    mov edx, UI_LINK_MENU_MAXY
    mov esi, GB_TILEMAP0
    xor edi, edi
    call add_window
    ret

; lm_link_setup — draw the box + items, init the menu.  (LinkMenu body up to the
; .waitForInputLoop; also used by the harness.)  ; DEVIATION(geometry): the box
; is drawn BOX-RELATIVE (origin scratch 0,0) and shown at UI_LINK_MENU, so pret's
; GB-absolute coords are shifted by (-5,-3): text (7,5)->(2,2), cursor (6,5)->(1,2).
lm_link_setup:
    mov dword [text_row_stride], LM_STRIDE
    mov eax, [g_window_count]
    mov [lm_link_wc], eax           ; ; DEVIATION: SaveScreenTilesToBuffer1 modeled
                                    ; as the window-stack baseline (restored on exit)
    ; ld hl, ColosseumWhereToText / call PrintText — ends in `done`, so the box
    ; stays up as the bottom dialog while the menu box is drawn over it.
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumWhereToText
    call PrintText
    ; hlcoord 5,3 / lb bc,8,13 -> box-relative interior 13x8 at scratch (0,0)
    mov esi, LMB(0, 0)
    mov bl, 13
    mov bh, 8
    call TextBoxBorder
    call UpdateSprites
    ; ld de,TradeCenterText / hlcoord 7,5 -> box-rel (2,2)
    mov eax, TradeCenterText
    mov esi, LMB(2, 2)
    call PlaceString
    ; xor a -> wUnusedLinkMenuByte / wCableClubDestinationMap / wNamedObjectIndex
    mov byte [ebp + wUnusedLinkMenuByte], 0
    mov byte [ebp + wCableClubDestinationMap], 0
    mov byte [ebp + wNamedObjectIndex], 0
    ; menu state: pret Y=5,X=6 -> box-rel Y=2,X=1; cur=0, max=3, watched=A|B, last=0
    mov byte [ebp + wTopMenuItemY], 2
    mov byte [ebp + wTopMenuItemX], 1
    mov byte [ebp + wCurrentMenuItem], 0
    mov byte [ebp + wMaxMenuItem], 3
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    mov byte [ebp + wLastMenuItem], 0
    mov dword [menu_item_step], 2 * LM_STRIDE
    mov dword [menu_redraw_cb], lm_link_mirror
    call lm_link_show_window
    ret

LinkMenu:
    ; TODO-HW: network HAL — no serial handshake precedes this menu in the port;
    ; pin the connection status to "not established" so every not-internal-clock
    ; branch is deterministic (see the SERIAL STUBS contract).
    mov byte [ebp + H_SERIAL_CONN_STATUS], CONNECTION_NOT_ESTABLISHED
    ; xor a / ld [wLetterPrintingDelayFlags],a
    mov byte [ebp + wLetterPrintingDelayFlags], 0
    ; ld hl,wStatusFlags4 / set BIT_LINK_CONNECTED,[hl]
    or byte [ebp + W_STATUS_FLAGS_4], 1 << BIT_LINK_CONNECTED
    ; ld hl,TextTerminator_f5a16 / call PrintText — an EMPTY stream: it draws the
    ; message box and types nothing, so the dialog is open (and the screen it saves
    ; below includes it) before the menu goes up.  Was elided as "a no-op under the
    ; drawn-whole window model" (row 20 part 1, M-110); it is not a no-op, and with
    ; PrintText back it is one call.
    mov dword [text_msgbox], msgbox_dialog
    mov esi, TextTerminator_f5a16
    call PrintText
    call lm_link_setup
.waitForInputLoop:
    call HandleMenuInput            ; Out: AL = watched keys
    ; and PAD_A|PAD_B / add a / add a / ld b,a
    and al, PAD_A | PAD_B
    add al, al
    add al, al
    mov bh, al
    ; ld a,[wCurrentMenuItem] / cp $3 / jr nz .asm_f586b
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 3
    jne .asm_f586b
    test bh, 1 << 2                 ; A pressed on CANCEL -> treat as B
    jz .asm_f586b
    dec al
    mov bh, 0x8
.asm_f586b:
    add al, bh
    add al, 0xD0
    mov [ebp + wLinkMenuSelectionSendBuffer], al
    mov [ebp + wLinkMenuSelectionSendBuffer + 1], al
.exchangeMenuSelectionLoop:
    call Serial_ExchangeLinkMenuSelection   ; TODO-HW: network HAL
    ; ld a,[recv[0]] / ld b,a / and $f0 / cp $d0 / jr z .checkEnemy
    mov al, [ebp + wLinkMenuSelectionReceiveBuffer]
    mov bh, al
    and al, 0xF0
    cmp al, 0xD0
    je .checkEnemyMenuSelection
    ; ld a,[recv[1]] / ld b,a / and $f0 / cp $d0 / jr nz loop
    mov al, [ebp + wLinkMenuSelectionReceiveBuffer + 1]
    mov bh, al
    and al, 0xF0
    cmp al, 0xD0
    jne .exchangeMenuSelectionLoop
.checkEnemyMenuSelection:
    ; ld a,b / and $c / jr nz .enemyPressedAOrB
    mov al, bh
    and al, 0x0C
    jnz .enemyPressedAOrB
    ; the enemy didn't press A or B
    mov al, [ebp + wLinkMenuSelectionSendBuffer]
    and al, 0x0C
    jz .waitForInputLoop            ; neither pressed -> keep waiting
    jmp .doneChoosingMenuSelection  ; player pressed -> use player's selection
.enemyPressedAOrB:
    mov al, [ebp + wLinkMenuSelectionSendBuffer]
    and al, 0x0C
    jz .useEnemyMenuSelection       ; only enemy pressed -> use enemy's selection
    ; both pressed: the gameboy clocking the connection wins.
    mov al, [ebp + H_SERIAL_CONN_STATUS]        ; TODO-HW: network HAL
    cmp al, USING_INTERNAL_CLOCK
    je .doneChoosingMenuSelection
.useEnemyMenuSelection:
    mov byte [ebp + wNamedObjectIndex], 1
    mov al, bh
    mov [ebp + wLinkMenuSelectionSendBuffer], al
    and al, 3
    mov [ebp + wCurrentMenuItem], al
.doneChoosingMenuSelection:
    ; ldh a,[hSerialConnectionStatus] / cp USING_INTERNAL_CLOCK / jr nz skip
    mov al, [ebp + H_SERIAL_CONN_STATUS]        ; TODO-HW: network HAL
    cmp al, USING_INTERNAL_CLOCK
    jne .skipStartingTransfer
    call DelayFrame
    call DelayFrame
    ; ld a,SC_START|SC_INTERNAL / ldh [rSC],a
    ; TODO-HW: network HAL — start the internally-clocked serial transfer.
.skipStartingTransfer:
    ; b=' ' c=' ' d=' ' e='▷'
    mov bh, CHAR_SPACE
    mov bl, CHAR_SPACE
    mov dh, CHAR_SPACE
    mov dl, CHAR_RARROW
    mov al, [ebp + wLinkMenuSelectionSendBuffer]
    and al, PAD_B << 2              ; B pressed?
    jnz .updateCursorPosition
    ; A was pressed
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 2                       ; COLOSSEUM2?
    je .asm_f5963
    mov bh, dl                      ; ld b,e
    mov dl, bl                      ; ld e,c
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jz .updateCursorPosition
    mov bl, bh                      ; ld c,b
    mov bh, dh                      ; ld b,d
    dec al
    jz .updateCursorPosition
    mov dh, bl                      ; ld d,c
    mov bl, bh                      ; ld c,b
.updateCursorPosition:
    call Func_f59ec
    ; ld ...LoadScreenTilesFromBuffer1 — ; DEVIATION: window model; the visible
    ; restore happens via the window-stack drop at .choseCancel / dispatch.
    mov al, [ebp + wLinkMenuSelectionSendBuffer]
    and al, PAD_B << 2
    jnz .choseCancel                ; cancel if B pressed
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 2
    je .choseCancel
    ; --- selected TRADE CENTER (0) or COLOSSEUM (1): warp to the cable club -----
    xor al, al
    mov [ebp + W_WALK_BIKE_SURF_STATE], al   ; start walking
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    mov al, COLOSSEUM
    jnz .next
    mov al, TRADE_CENTER
.next:
    mov [ebp + wCableClubDestinationMap], al
    ; ld hl, ColosseumPleaseWaitText / call PrintText (ends in `done` — stays up)
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumPleaseWaitText
    call PrintText
    mov bl, 50
    call DelayFrames
    ; ld hl,wStatusFlags6 / res BIT_DEBUG_MODE,[hl]
    and byte [ebp + W_STATUS_FLAGS_6], ~(1 << BIT_DEBUG_MODE) & 0xFF
    mov al, [ebp + wDefaultMap]
    mov [ebp + wDestinationMap], al
    ; callfar PrepareForSpecialWarp — ROOT-WIRED (Session 9 spine).
    call PrepareForSpecialWarp      ; ; DEVIATION: warp seam = Session 9
    mov bl, 20
    call DelayFrames
    xor al, al
    mov [ebp + wMenuJoypadPollCount], al
    mov [ebp + wSerialExchangeNybbleSendData], al
    inc al                          ; LINK_STATE_IN_CABLE_CLUB
    mov [ebp + wLinkState], al
    mov [ebp + wEnteringCableClub], al
    ; jpfar SpecialEnterMap — ROOT-WIRED (Session 9 spine).
    jmp SpecialEnterMap             ; ; DEVIATION: warp seam = Session 9
.choseCancel:
    xor al, al
    mov [ebp + wMenuJoypadPollCount], al
    call Delay3
    ; callfar CloseLinkConnection
    call CloseLinkConnection        ; TODO-HW: network HAL
    ; drop the whole LinkMenu window stack back to the entry baseline, then show
    ; the "link canceled" dialog. ; DEVIATION: window-stack restore for the pret
    ; LoadScreenTilesFromBuffer1 screen restore.
    mov eax, [lm_link_wc]
    mov [g_window_count], eax
    ; ld hl, ColosseumCanceledText / call PrintText (ends in `done` — stays up)
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumCanceledText
    call PrintText
    ; ld hl,wStatusFlags4 / res BIT_LINK_CONNECTED,[hl]
    and byte [ebp + W_STATUS_FLAGS_4], ~(1 << BIT_LINK_CONNECTED) & 0xFF
    ret

; --- .asm_f5963 — COLOSSEUM2 branch (A on item 2): drive the nybble exchange,
; then hand off to the cup-select screen Func_f531b.
.asm_f5963:
    ; ld a,[wNamedObjectIndex] / and a / jr nz .asm_f5974
    mov al, [ebp + wNamedObjectIndex]
    and al, al
    jnz .asm_f5974
    ; b=' ' c=' ' d='▷' e=' ' / Func_f59ec  (grey the cursor to item 2)
    mov bh, CHAR_SPACE
    mov bl, CHAR_SPACE
    mov dh, CHAR_RARROW
    mov dl, CHAR_SPACE
    call Func_f59ec
.asm_f5974:
    ; xor a / ld [wBuffer],a
    mov byte [ebp + wBuffer], 0
    ; ld a,$ff / ld [wSerialExchangeNybbleReceiveData],a
    mov byte [ebp + wSerialExchangeNybbleReceiveData], 0xFF
    ; ld a,$b / ld [wLinkMenuSelectionSendBuffer],a
    mov byte [ebp + wLinkMenuSelectionSendBuffer], 0x0B
    mov bh, 0x78                    ; ld b,$78 — 120-frame timeout
.loop2:                             ; pret .loop
    mov al, [ebp + H_SERIAL_CONN_STATUS]        ; TODO-HW: network HAL
    cmp al, USING_INTERNAL_CLOCK
    jne .noDelay
    call DelayFrame                 ; call z,DelayFrame
.noDelay:
    dec bh
    jz .asm_f59b2                    ; timeout -> the no-partner branch
    push ebx
    call Serial_ExchangeNybble      ; TODO-HW: network HAL
    call DelayFrame
    pop ebx
    ; ld a,[wSerialExchangeNybbleReceiveData] / inc a / jr z .loop
    mov al, [ebp + wSerialExchangeNybbleReceiveData]
    inc al
    jz .loop2                       ; $ff -> no response -> keep looping
    ; (partner responded — drain, then re-enter the cup screen)
    mov bh, 0x0F
.drain1:                            ; pret .loop2
    push ebx
    call DelayFrame
    call Serial_ExchangeNybble
    pop ebx
    dec bh
    jnz .drain1
    mov bh, 0x0F
.drain2:                            ; pret .loop3
    push ebx
    call DelayFrame
    call Serial_SendZeroByte
    pop ebx
    dec bh
    jnz .drain2
    jmp .asm_f59d6
.asm_f59b2:
    mov word [ebp + wUnknownSerialCounter], 0
    mov al, [ebp + wNamedObjectIndex]
    and al, al
    jz .asm_f59cd
    ; b=' ' c=' ' d=' ' e='▷' / Func_f59ec / jp .choseCancel
    mov bh, CHAR_SPACE
    mov bl, CHAR_SPACE
    mov dh, CHAR_SPACE
    mov dl, CHAR_RARROW
    call Func_f59ec
    jmp .choseCancel
.asm_f59cd:
    ; ld hl, ColosseumVersionText / call PrintText (ends in `prompt`)
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumVersionText
    call PrintText
    jmp .choseCancel
.asm_f59d6:
    ; b=' ' c=' ' d='▷' e=' ' / Func_f59ec
    mov bh, CHAR_SPACE
    mov bl, CHAR_SPACE
    mov dh, CHAR_RARROW
    mov dl, CHAR_SPACE
    call Func_f59ec
    call Func_f531b
    jc .choseCancel                 ; jp c,.choseCancel
    mov al, 0xF0
    jmp .next                       ; jp .next (with a=$f0 -> COLOSSEUM warp path)

; ###########################################################################
; # Func_f59ec — blit the LinkMenu locked-in cursor arrows (box-relative)
; ###########################################################################
; In: BH,BL,DH,DL = the four cursor tiles (pret b,c,d,e).  pret writes them at
; ldcoord_a 6,5 / 6,7 / 6,9 / 6,11 (GB-absolute) -> box-rel col 1, rows 2,4,6,8.
Func_f59ec:
    mov al, bh
    mov [ebp + LMB(1, 2)], al
    mov al, bl
    mov [ebp + LMB(1, 4)], al
    mov al, dh
    mov [ebp + LMB(1, 6)], al
    mov al, dl
    mov [ebp + LMB(1, 8)], al
    call lm_link_mirror             ; expose the arrows in the box window
    push ebx
    push edx
    mov bl, 40
    call DelayFrames
    pop edx
    pop ebx
    ret

; --- LinkMenu's own text_far wrappers (pret ref: engine/menus/link_menu.asm:895-912,
; same position, same order).  TextTerminator_f5a16 is pret's EMPTY stream — a bare
; text_end, printed to open the message box with no text in it.
ColosseumWhereToText:
    text_far _ColosseumWhereToText
    text_end

ColosseumPleaseWaitText:
    text_far _ColosseumPleaseWaitText
    text_end

ColosseumCanceledText:
    text_far _ColosseumCanceledText
    text_end

ColosseumVersionText:
    text_far _ColosseumVersionText
    text_end

TextTerminator_f5a16:
    text_end

; ###########################################################################
; # RunLinkMenuTest — %ifdef DEBUG_I1 FRAME.BIN gate (static open state).
; # Opens the cup-select screen (Func_f531b's static draw + rules + ▶ cursor),
; # mirrors, settles, and dumps.  The serial exchange loops need a partner (or an
; # A/B press) to progress, so — like RunOptionsTest — the harness draws the open
; # state rather than running HandleMenuInput (which would block without input).
; ###########################################################################
%ifdef DEBUG_I1
global RunLinkMenuTest
extern LoadFontTilePatterns         ; gfx/load_font.asm
extern LoadTextBoxTilePatterns      ; gfx/load_font.asm
extern ClearSprites                 ; gfx/sprites.asm
extern DumpBackbuffer               ; debug/debug_dump.asm — writes FRAME.BIN + exits

RunLinkMenuTest:
    mov byte [ebp + H_SERIAL_CONN_STATUS], CONNECTION_NOT_ESTABLISHED
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0
    call lm_cup_setup               ; 3 boxes + labels + window
    call Func_f56bd                 ; rules panel for cup 0
    call PlaceMenuCursor            ; ▶ on the first cup
    call cup_mirror
    call DelayFrame
    call DelayFrame
    call DelayFrame
%ifdef DEBUG_I1_MSG
    ; Message variant (row 20 part 1): print one of the cup-eligibility messages the
    ; way link_cups.asm's result routines do, on top of the cup screen.  The stream
    ; ends in `prompt`, so PrintText parks on the ▼ wait — AUTOKEY_DUMP_FRAME snaps
    ; the frame from the ISR while it waits, which is exactly the state to look at.
    mov dword [text_msgbox], msgbox_dialog
    mov esi, Colosseum3MonsText
    call PrintText
.hang:
    call DelayFrame                 ; keep the frame counter running for AUTOKEY
    jmp .hang
%endif
    call DumpBackbuffer             ; writes FRAME.BIN + exits
    ret
%endif
