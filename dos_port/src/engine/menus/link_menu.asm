; ===========================================================================
; link_menu.asm — the link (cable club) MENU/DISPATCH half of pret
; engine/menus/link_menu.asm.  menus-port Session 8, package I1.
;
; SCOPE (this file): the COMPLETE pret file —
;   * LinkMenu            — TRADE CENTER / COLOSSEUM / COLOSSEUM2 / CANCEL select
;   * Func_f531b          — the Colosseum cup-select screen (View/Rules + cup
;                           list + rules panel) and Func_f56bd (rules redraw)
;   * Func_f59ec          — the LinkMenu locked-in cursor-arrow blit
;   * the menu/rules text tables + the Colosseum*Text message wrappers
;   * Func_f5476 / asm_f547c / asm_f547f dispatch tails
;   * PointerTable_f5488 (dd PokeCup/PikaCup/PetitCup)
;   * PointerTable_f56ee (dd Text_f56f4/5728/575b)
;   * PokeCup / PikaCup / PetitCup + their result routines (NotThreeMonsInParty,
;     MewInParty, LevelAbove55, ..., asm_f5689/asm_f569b/asm_f56ad) — the
;     COLOSSEUM cup-eligibility rules.  Formerly split out as link_cups.asm
;     (menus swarm Session 8 package I2); merged back into this mirror 2026-07-24
;     (relocated-labels grind — the split was registered legacy debt in
;     pret_label_allowlist.json, now retired).
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
;      ; DEVIATION{class=projection; pret=engine/menus/link_menu.asm:LinkMenu; behavior=message dialogs temporarily replace rather than overlay the underlying link screen; evidence=pret PrintText calls preserve BG tilemap while port msgbox_dialog uses set_single_window; lifetime=until dialog projection composes with existing windows}
;      ; The msgbox_dialog projection presents the box
;      with set_single_window, so a message REPLACES the screen behind it for as long
;      as it is up (pret overlays the box on the live tilemap).  Each caller's next
;      act is the redraw that restores it — Func_f531b's `jp Func_f531b` retry, or
;      LinkMenu's .choseCancel window-stack drop.  Same trade as save.asm's dialogs.
;  * SERIAL IS ALL STUBS (no port serial hardware).  Every Serial_* /
;    CloseLinkConnection / hSerial* / rSC access is ; TODO-HW: network HAL.  The
;    stubs themselves are pret home/serial.asm's, so they live in
;    src/home/serial_stubs.asm — NOT here; this file is a CALLER, and a stub in a
;    caller's mirror file is the shadow class the stub convention forbids (row 20
;    part 2, M-112).  The no-partner return contract they are tuned to (which drives
;    each menu to a pret terminal path rather than a bare ret) is documented in full
;    at the top of that file.
;  * NO LIVE CALLER (M-111): pret reaches LinkMenu from CableClubNPC
;    (engine/link/cable_club_npc.asm), which the port has not translated — every
;    label of that file is `missing` in translation.db.  LinkMenu and Func_f531b are
;    therefore reachable today only from the DEBUG_I1* harness at the bottom of this
;    file; that harness calls the real routines (it draws nothing itself), so what it
;    photographs IS this code.
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
extern HandleMenuInput          ; home/window.asm — Out: AL = watched keys pressed
extern DelayFrame               ; src/home/vblank.asm
extern DelayFrames              ; src/home/delay.asm — In: BL = frame count
extern Delay3                   ; src/home/palettes.asm
extern UpdateSprites            ; src/home/update_sprites.asm
extern SaveScreenTilesToBuffer1     ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer1   ; src/home/tilemap.asm (pret home/tilemap.asm)

; --- serial: ; TODO-HW: network HAL — stubs in src/home/serial_stubs.asm ----
extern Serial_ExchangeByte
extern Serial_ExchangeLinkMenuSelection
extern Serial_ExchangeNybble
extern Serial_SyncAndExchangeNybble
extern Serial_SendZeroByte
extern CloseLinkConnection

; --- dispatch seam (ROOT-WIRED, Session 9 spine) ---------------------------
extern PrepareForSpecialWarp    ; engine/overworld/special_warps.asm (callfar target)
extern SpecialEnterMap          ; engine/menus/main_menu.asm       (jpfar target)

; --- cup-eligibility dependencies (PokeCup/PikaCup/PetitCup, below) ----------
extern GetMonName               ; home/names.asm — in: wNamedObjectIndex -> wNameBuffer
; PokedexEntryPointers — assets/dex_entries.inc (DO NOT %include the data file
; here: engine/menus/pokedex.asm owns the %include/embed; duplicate-including it
; would double-define every DexEntry label at link time). `dd` flat 32-bit .data
; pointers, index = internal_species_index - 1 (dex_entries.inc header).
extern PokedexEntryPointers

; ---------------------------------------------------------------------------
; globals — the pret-named routines / data (I2 + root reference these)
; ---------------------------------------------------------------------------
global Func_f531b
global Func_f56bd
global PokeCup
global PikaCup
global PetitCup
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
MEW                      equ 0x15          ; constants/pokemon_constants.asm (=21)
; (TX_END — the '@' string terminator PetitCup scans for — comes from
; gb_text.inc's %define, already included above.)

; wPartyMon2Level/3Level: gb_memmap.inc only pins wPartyMon1Level (lead-mon
; sym anchor); the other two party slots are +N*PARTYMON_STRUCT_LENGTH from
; it, same as wPartyMon{d:n} in pret's ram/wram.asm. Local equ, not touching
; gb_memmap.inc — root may want to promote these if another package needs them.
wPartyMon2Level equ wPartyMon1Level + PARTYMON_STRUCT_LENGTH
wPartyMon3Level equ wPartyMon2Level + PARTYMON_STRUCT_LENGTH

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
; data/text/text_3.asm), all generated by tools/generators/gen_menu_strings.py.
; Hand-encoded charmap `db` runs until row 20 part 1 (M-109); the six generated db
; strings are byte-identical to the literals they replace, and the message streams
; are pret's own — the three `text_ram wNameBuffer` ones (Height/Weight/Evolved)
; could not be expressed as glyph runs at all.
%include "assets/link_text.inc"

; ===========================================================================
section .text

; ###########################################################################
; # Colosseum*Text — pret's text_far WRAPPERS (engine/menus/link_menu.asm:571-633).
; # These are DATA, not routines: `ld hl, ColosseumMewText / call PrintText` is how
; # pret prints one, and the cup result routines below do exactly that.  The
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
; name asm_f5689/asm_f569b/asm_f56ad just fetched with GetMonName is spliced in
; by the text engine.
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

Func_f531b:
    ; ld c,$14 / call DelayFrames
    mov bl, 0x14
    call DelayFrames
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
; # PokeCup / PikaCup / PetitCup — the COLOSSEUM cup-eligibility rules
; # (pret engine/menus/link_menu.asm:197-511, in pret's in-file order: the
; # three cups, then the fifteen shared result routines).  Reached only as
; # data through PointerTable_f5488 (.data above — pret places the dw table
; # immediately before PokeCup).  Pure logic — no window, tilemap or
; # menu-driver state; the result routines print their Colosseum*Text (defined
; # above) exactly as pret does (ld hl, X / call PrintText).
; #
; # FLAGS: every `cp NN / jr nc / jr c / jr z` here is ported onto the x86
; # flag set by the *same* logical op pret used (cmp -> jc/jnc/jz map 1:1 onto
; # GB cp's C/Z, both unsigned-subtract semantics).  The two-byte weight
; # compare in PetitCup (sub $b9 / sbc $1) is a real 16-bit borrow chain —
; # ported as sub/mov/sbb with the `mov` (no EFLAGS side effect, same as GB
; # LD) sitting between them so CF survives untouched, exactly as on hardware.
; ###########################################################################

; ===========================================================================
; PokeCup — pret ref: engine/menus/link_menu.asm:PokeCup.
; Team-shape (3 mons, no MEW, no duplicate species) + level gate 50-55 each,
; combined <=155. a=0 on a valid team; else the fail routine's error code.
; ===========================================================================
PokeCup:
    mov esi, wPartyCount
    mov al, [ebp + esi]
    inc esi                             ; esi -> wPartySpecies (mon1)
    cmp al, 3
    jnz NotThreeMonsInParty
    mov bh, 3
.loop:
    mov al, [ebp + esi]                 ; wPartySpecies
    inc esi
    cmp al, MEW
    jz MewInParty
    dec bh
    jnz .loop
    dec esi
    dec esi                             ; esi -> mon2 address
    cmp al, [ebp + esi]                 ; is third mon second mon?
    jz DuplicateSpecies
    dec esi                             ; esi -> mon1 address (wPartySpecies)
    cmp al, [ebp + esi]                 ; is third mon first mon?
    jz DuplicateSpecies
    mov al, [ebp + esi]
    inc esi
    cmp al, [ebp + esi]                 ; is first mon second mon?
    jz DuplicateSpecies

    mov al, [ebp + wPartyMon1Level]
    cmp al, 56
    jnc LevelAbove55
    cmp al, 50
    jc LevelUnder50
    mov bh, al
    mov al, [ebp + wPartyMon2Level]
    cmp al, 56
    jnc LevelAbove55
    cmp al, 50
    jc LevelUnder50
    mov bl, al
    mov al, [ebp + wPartyMon3Level]
    cmp al, 56
    jnc LevelAbove55
    cmp al, 50
    jc LevelUnder50
    add al, bh
    add al, bl
    cmp al, 156
    jnc CombinedLevelsGreaterThan155
    xor al, al
    ret

; ===========================================================================
; PikaCup — pret ref: engine/menus/link_menu.asm:PikaCup.
; Same team-shape gate; level gate 15-20 each, combined <=50.
; ===========================================================================
PikaCup:
    mov esi, wPartyCount
    mov al, [ebp + esi]
    inc esi
    cmp al, 3
    jnz NotThreeMonsInParty
    mov bh, 3
.loop:
    mov al, [ebp + esi]                 ; wPartySpecies
    inc esi
    cmp al, MEW
    jz MewInParty
    dec bh
    jnz .loop
    dec esi
    dec esi
    cmp al, [ebp + esi]                 ; is third mon second mon?
    jz DuplicateSpecies
    dec esi
    cmp al, [ebp + esi]                 ; is third mon first mon?
    jz DuplicateSpecies
    mov al, [ebp + esi]
    inc esi
    cmp al, [ebp + esi]                 ; is first mon second mon?
    jz DuplicateSpecies

    mov al, [ebp + wPartyMon1Level]
    cmp al, 21
    jnc LevelAbove20
    cmp al, 15
    jc LevelUnder15
    mov bh, al
    mov al, [ebp + wPartyMon2Level]
    cmp al, 21
    jnc LevelAbove20
    cmp al, 15
    jc LevelUnder15
    mov bl, al
    mov al, [ebp + wPartyMon3Level]
    cmp al, 21
    jnc LevelAbove20
    cmp al, 15
    jc LevelUnder15
    add al, bh
    add al, bl
    cmp al, 51
    jnc CombinedLevelsAbove50
    xor al, al
    ret

; ===========================================================================
; PetitCup — pret ref: engine/menus/link_menu.asm:PetitCup.
; Same team-shape gate; per-mon evolution-stage check (Func_3b10f — stubbed,
; see below); per-mon dex-entry height (<6'8") + weight (<=44lb) check;
; level gate 25-30 each, combined <=80.
; ===========================================================================
PetitCup:
    mov esi, wPartyCount
    mov al, [ebp + esi]
    inc esi
    cmp al, 3
    jnz NotThreeMonsInParty
    mov bh, 3
.loop:
    mov al, [ebp + esi]                 ; wPartySpecies
    inc esi
    cmp al, MEW
    jz MewInParty
    dec bh
    jnz .loop
    dec esi
    dec esi
    cmp al, [ebp + esi]                 ; is third mon second mon?
    jz DuplicateSpecies
    dec esi
    cmp al, [ebp + esi]                 ; is third mon first mon?
    jz DuplicateSpecies
    mov al, [ebp + esi]
    inc esi
    cmp al, [ebp + esi]                 ; is first mon second mon?
    jz DuplicateSpecies                 ; esi -> mon2 address here

    ; --- per-mon evolution-stage check (x3) ---
    ; pret: `ld a,[hl] / ld [wCurPartySpecies],a / push hl / callfar Func_3b10f
    ; / pop hl / jp c, asm_f56ad` for mon1, mon2, mon3 in turn.
    ; DEVIATION{class=temporary; pret=engine/menus/link_menu.asm:PetitCup; behavior=treat all three party species as basic forms instead of calling Func_3b10f; evidence=pret PetitCup callfar sequence and project_state reports Func_3b10f missing; lifetime=until Func_3b10f is ported and wired}
    ; Func_3b10f (engine/pokemon/evos_moves.asm — "does some species
    ; evolve into wCurPartySpecies") is not yet ported (pokemon_behavior plan).
    ; Stubbed to the "basic form" result (CF clear -> jc NOT taken) for every
    ; mon. TODO once ported: extern Func_3b10f, preserve esi across the call
    ; (pret wraps it in push/pop hl since callfar clobbers registers), replace
    ; each `clc` stub below with `mov [ebp+wCurPartySpecies], al` / real call.
    dec esi                             ; esi -> mon1 address
    mov al, [ebp + esi]
    mov [ebp + wCurPartySpecies], al
    clc                                 ; structured temporary deviation above: basic path
    jc asm_f56ad
    inc esi                             ; esi -> mon2 address
    mov al, [ebp + esi]
    mov [ebp + wCurPartySpecies], al
    clc                                 ; structured temporary deviation above: basic path
    jc asm_f56ad
    inc esi                             ; esi -> mon3 address
    mov al, [ebp + esi]
    mov [ebp + wCurPartySpecies], al
    clc                                 ; structured temporary deviation above: basic path
    jc asm_f56ad
    dec esi
    dec esi                             ; esi -> mon1 address (wPartySpecies)

    ; --- per-mon dex-entry height/weight check (x3) ---
    mov bh, 3
.bigloop:
    mov al, [ebp + esi]                 ; wPartySpecies[i]
    inc esi
    push esi
    push ebx
    push eax
    ; DEVIATION{class=data-model; pret=engine/menus/link_menu.asm:PetitCup; behavior=read each flat PokedexEntryPointers dd directly instead of two banked FarCopyData operations; evidence=pret PetitCup pointer and entry copies plus generated dex_entries.inc flat-pointer contract; lifetime=permanent flat-memory boundary}
    ; FarCopyData bank read -> flat read. pret does two FarCopyData
    ; calls (fetch the far pointer, then 20 bytes of the entry) because
    ; PokedexEntryPointers is bank-switched `dw` data on hardware; the port's
    ; PokedexEntryPointers is already a flat `dd` pointer (dex_entries.inc
    ; contract), so one direct load replaces both banked copies.
    movzx ecx, al
    dec ecx                             ; pret: dec a; ld c,a (species-1 index)
    mov esi, [PokedexEntryPointers + ecx*4]   ; flat dex-entry ptr (pret: hl = table+bc*2, FarCopyData)
.scanAt:
    mov al, [esi]
    inc esi
    cmp al, TX_END                      ; '@' name terminator
    jne .scanAt
    mov al, [esi]                       ; feet
    inc esi
    cmp al, 7
    jnc asm_f5689
    add al, al                          ; a = 2*feet
    add al, al                          ; a = 4*feet
    mov bh, al                          ; b = 4*feet
    add al, al                          ; a = 8*feet
    add al, bh                          ; a = 8*feet + 4*feet = 12*feet
    mov bh, al                          ; b = 12*feet
    mov al, [esi]                       ; inches
    inc esi
    add al, bh                          ; a = inches + 12*feet (total inches)
    cmp al, 0x51                        ; 81 = 6'8" + 1"
    jnc asm_f5689
    mov al, [esi]                       ; weight low byte
    inc esi
    sub al, 0xb9
    mov al, [esi]                       ; weight high byte (esi NOT advanced — mirrors pret `ld a,[hl]`)
    sbb al, 1                           ; 16-bit borrow chain: weight - 0x1b9 (441 tenths = 44.1 lb)
    jnc asm_f569b
    pop eax
    pop ebx
    pop esi
    dec bh
    jnz .bigloop

    mov al, [ebp + wPartyMon1Level]
    cmp al, 31
    jnc LevelAbove30
    cmp al, 25
    jc LevelUnder25
    mov bh, al
    mov al, [ebp + wPartyMon2Level]
    cmp al, 31
    jnc LevelAbove30
    cmp al, 25
    jc LevelUnder25
    mov bl, al
    mov al, [ebp + wPartyMon3Level]
    cmp al, 31
    jnc LevelAbove30
    cmp al, 25
    jc LevelUnder25
    add al, bh
    add al, bl
    cmp al, 81
    jnc CombinedLevelsAbove80
    xor al, al
    ret

; ===========================================================================
; Result routines — pret ref: engine/menus/link_menu.asm:410-511. Shared
; `jp z`/`jp nc`/`jp c` targets reached from all three cups (and, for
; asm_f5689/asm_f569b/asm_f56ad, only from PetitCup). Each prints its
; Colosseum*Text and returns its fixed error code in AL; not `global` — only
; reached via internal jumps within this file.
; ===========================================================================
NotThreeMonsInParty:
    mov dword [text_msgbox], msgbox_dialog
    mov esi, Colosseum3MonsText                 ; ld hl, Colosseum3MonsText
    call PrintText
    mov al, 0x1
    ret

MewInParty:
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumMewText                 ; ld hl, ColosseumMewText
    call PrintText
    mov al, 0x2
    ret

DuplicateSpecies:
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumDifferentMonsText                 ; ld hl, ColosseumDifferentMonsText
    call PrintText
    mov al, 0x3
    ret

LevelAbove55:
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumMaxL55Text                 ; ld hl, ColosseumMaxL55Text
    call PrintText
    mov al, 0x4
    ret

LevelUnder50:
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumMinL50Text                 ; ld hl, ColosseumMinL50Text
    call PrintText
    mov al, 0x5
    ret

CombinedLevelsGreaterThan155:
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumTotalL155Text                 ; ld hl, ColosseumTotalL155Text
    call PrintText
    mov al, 0x6
    ret

LevelAbove30:
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumMaxL30Text                 ; ld hl, ColosseumMaxL30Text
    call PrintText
    mov al, 0x7
    ret

LevelUnder25:
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumMinL25Text                 ; ld hl, ColosseumMinL25Text
    call PrintText
    mov al, 0x8
    ret

CombinedLevelsAbove80:
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumTotalL80Text                 ; ld hl, ColosseumTotalL80Text
    call PrintText
    mov al, 0x9
    ret

LevelAbove20:
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumMaxL20Text                 ; ld hl, ColosseumMaxL20Text
    call PrintText
    mov al, 0xa
    ret

LevelUnder15:
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumMinL15Text                 ; ld hl, ColosseumMinL15Text
    call PrintText
    mov al, 0xb
    ret

CombinedLevelsAbove50:
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumTotalL50Text                 ; ld hl, ColosseumTotalL50Text
    call PrintText
    mov al, 0xc
    ret

; asm_f5689 — pret ref: engine/menus/link_menu.asm:asm_f5689. Height-over-limit
; fail. Reached via `jnc asm_f5689` from PetitCup's .bigloop with (esi, ebx,
; eax) still pushed (pret: `pop af / pop bc / pop hl` happen HERE, not before
; the jump — mirrored exactly: PetitCup does not pop before jumping in).
asm_f5689:
    pop eax
    pop ebx
    pop esi
    mov [ebp + wNamedObjectIndex], al   ; al = species internal index (pret: a from popped af)
    call GetMonName
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumHeightText                 ; ld hl, ColosseumHeightText
    call PrintText
    mov al, 0xd
    ret

; asm_f569b — pret ref: engine/menus/link_menu.asm:asm_f569b. Weight-over-limit
; fail. Same stack-popping contract as asm_f5689.
asm_f569b:
    pop eax
    pop ebx
    pop esi
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumWeightText                 ; ld hl, ColosseumWeightText
    call PrintText
    mov al, 0xe
    ret

; asm_f56ad — pret ref: engine/menus/link_menu.asm:asm_f56ad. Evolved-mon fail
; (Func_3b10f's `jp c`). Currently unreachable while Func_3b10f is stubbed to
; the basic-form path (see PetitCup) — kept live so the seam is a one-line
; flip (`clc` -> real call) once Func_3b10f lands. pret: `ld a,[hl]` — esi
; still points at the current mon's species byte at the jc site.
asm_f56ad:
    mov al, [ebp + esi]
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ColosseumEvolvedText                 ; ld hl, ColosseumEvolvedText
    call PrintText
    mov al, 0xf
    ret

; ###########################################################################
; # Func_f56bd — redraw the rules panel for the current cup selection
; ###########################################################################
Func_f56bd:
    ; xor a / ldh [hAutoBGTransferEnabled],a — window model; manual mirror below.
    mov byte [ebp + hAutoBGTransferEnabled], 0
    mov dword [text_row_stride], LM_STRIDE
    ; hlcoord 1,11 / lb bc,6,18 / ClearScreenArea (interior of the rules panel)
    ; DEVIATION{class=projection; pret=engine/menus/link_menu.asm:Func_f56bd; behavior=clear the stride-20 cup-rules scratch inline instead of calling the stride-40 ClearScreenArea; evidence=pret Func_f56bd hlcoord and ClearScreenArea call plus port LM_STRIDE scratch contract; lifetime=until ClearScreenArea accepts an explicit stride}
    ; The port ClearScreenArea is baked to SCREEN_WIDTH(40);
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

; DEVIATION{class=projection; pret=engine/menus/link_menu.asm:LinkMenu; behavior=draw the LinkMenu box and cursor relative to its projected window origin; evidence=pret absolute hlcoord positions and port UI_LINK_MENU descriptor geometry; lifetime=permanent widescreen projection}
; The LinkMenu box is drawn BOX-RELATIVE (origin = scratch
; 0,0) and shown at UI_LINK_MENU, so pret's GB-absolute coords are shifted by
; (-5,-3): text (7,5)->(2,2), cursor (6,5)->(1,2).
LinkMenu:
    ; TODO-HW: network HAL — no serial handshake precedes this menu in the port;
    ; pin the connection status to "not established" so every not-internal-clock
    ; branch is deterministic (see the serial_stubs.asm contract).
    mov byte [ebp + H_SERIAL_CONN_STATUS], CONNECTION_NOT_ESTABLISHED
    ; xor a / ld [wLetterPrintingDelayFlags],a
    mov byte [ebp + wLetterPrintingDelayFlags], 0
    ; ld hl,wStatusFlags4 / set BIT_LINK_CONNECTED,[hl]
    or byte [ebp + W_STATUS_FLAGS_4], 1 << BIT_LINK_CONNECTED
    mov dword [text_row_stride], LM_STRIDE
    ; ld hl,TextTerminator_f5a16 / call PrintText — an EMPTY stream: it draws the
    ; message box and types nothing, so the dialog is open (and the screen saved
    ; below includes it) before the menu goes up.
    mov dword [text_msgbox], msgbox_dialog
    mov esi, TextTerminator_f5a16
    call PrintText
    ; call SaveScreenTilesToBuffer1 — the real routine (battle_menu.asm holds the
    ; port's body under pret's name); it snapshots W_TILEMAP, which is where this
    ; menu's stride-20 scratch lives, so the save is meaningful here.
    call SaveScreenTilesToBuffer1
    ; DEVIATION{class=projection; pret=engine/menus/link_menu.asm:LinkMenu; behavior=restore the caller by dropping the projected window stack rather than relying only on Buffer1 tilemap restore; evidence=pret SaveScreenTilesToBuffer1 and LoadScreenTilesFromBuffer1 pairing plus port lm_link_wc ownership; lifetime=permanent window-compositor boundary}
    ; The SCREEN restore is the window stack, not the
    ; tilemap — the menu is a window over the caller's windows, so LoadScreenTiles-
    ; FromBuffer1 alone would not un-draw it.  Record the caller's window count and
    ; drop back to it at .choseCancel.
    mov eax, [g_window_count]
    mov [lm_link_wc], eax
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
    ; call LoadScreenTilesFromBuffer1 — restores the W_TILEMAP snapshot taken at
    ; entry (the real routine, battle_menu.asm). The structured window-compositor
    ; on the GB this is also what un-draws the menu; here the menu is a WINDOW, so
    ; the visible restore is the window-stack drop at .choseCancel.
    call LoadScreenTilesFromBuffer1
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
    ; DEVIATION{class=banking; pret=engine/menus/link_menu.asm:LinkMenu; behavior=call the linked PrepareForSpecialWarp directly across the former bank seam; evidence=pret callfar PrepareForSpecialWarp and project_state linked provider; lifetime=permanent flat-code boundary}
    call PrepareForSpecialWarp
    mov bl, 20
    call DelayFrames
    xor al, al
    mov [ebp + wMenuJoypadPollCount], al
    mov [ebp + wSerialExchangeNybbleSendData], al
    inc al                          ; LINK_STATE_IN_CABLE_CLUB
    mov [ebp + wLinkState], al
    mov [ebp + wEnteringCableClub], al
    ; jpfar SpecialEnterMap — ROOT-WIRED (Session 9 spine).
    ; DEVIATION{class=banking; pret=engine/menus/link_menu.asm:LinkMenu; behavior=jump directly to linked SpecialEnterMap across the former bank seam; evidence=pret jpfar SpecialEnterMap and project_state linked provider; lifetime=permanent flat-code boundary}
    jmp SpecialEnterMap
.choseCancel:
    xor al, al
    mov [ebp + wMenuJoypadPollCount], al
    call Delay3
    ; callfar CloseLinkConnection
    call CloseLinkConnection        ; TODO-HW: network HAL
    ; drop the whole LinkMenu window stack back to the entry baseline, then show
    ; the "link canceled" dialog. The structured projection deviation above covers
    ; this window-stack restore for the pret
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
; # RunLinkMenuTest — %ifdef DEBUG_I1 FRAME.BIN gate.
; #
; # The harness DRAWS NOTHING of its own: it loads the font and calls the real
; # routine, so what FRAME.BIN photographs is this file's code.  (Until row 20
; # part 2 it called an extracted `lm_cup_setup` helper — the routine's own body,
; # lifted out purely so the harness could reach it, which broke Func_f531b into
; # a shape faithdiff could not follow.  The helper is gone; nothing here reshapes
; # the routine.)
; #
; # Both menus park in HandleMenuInput waiting for A/B, which no headless run can
; # press — so the build is DEBUG_AUTOKEY + AUTOKEY_QUIET (no presses, ever) and
; # AutoKeyDrive writes FRAME.BIN from the joypad ISR at AUTOKEY_DUMP_FRAME while
; # the menu spins, then exits.  That is exactly the open state to look at.
; #   DEBUG_I1      -> Func_f531b, the Colosseum cup-select screen
; #   DEBUG_I1_LINK -> LinkMenu, the TRADE CENTER/COLOSSEUM/COLOSSEUM2/CANCEL box
; ###########################################################################
%ifdef DEBUG_I1
global RunLinkMenuTest
extern LoadFontTilePatterns         ; gfx/load_font.asm
extern LoadTextBoxTilePatterns      ; gfx/load_font.asm
extern ClearSprites                 ; gfx/sprites.asm

RunLinkMenuTest:
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0
%ifdef DEBUG_I1_LINK
    call LinkMenu                   ; spins in .waitForInputLoop; AUTOKEY dumps
%else
    mov byte [ebp + H_SERIAL_CONN_STATUS], CONNECTION_NOT_ESTABLISHED
    call Func_f531b                 ; spins in .asm_f5377;      AUTOKEY dumps
%endif
.hang:
    call DelayFrame                 ; keep the frame counter running for AUTOKEY
    jmp .hang
%endif

; ===========================================================================
; RunLinkCupsTest — DEBUG_I2 harness. Seeds a 3-mon party and exercises:
;   1. PokeCup on a passing team (levels 53/52/50, sum 155 -- both boundary
;      values) -> expect al=0.
;   2. PokeCup on the same team with mon1's level pushed to 60 -> expect
;      al=4 (LevelAbove55), the "cp 56 / jnc" gate.
;   3. PetitCup on a passing team of small real Pokemon (Diglett 0'8"/2lb,
;      Nidoran-F 1'4"/15lb, Pikachu 1'4"/13lb) at levels 28/27/25 (sum 80,
;      boundary) -> expect al=0. This is the one that actually walks the
;      real PokedexEntryPointers data end-to-end.
;   4. PetitCup with the third slot replaced by Rhydon (6'3", 265 lb, real
;      dex data) at the same valid levels -> expect al=14 (asm_f569b, the
;      two-byte weight-compare fail: 2650 tenths >> 441-tenth/44.1lb cutoff).
; Results land in `link_cups_test_results` (this file's own flat .bss, NOT
; GB WRAM -- avoids claiming any WRAM scratch address). No rendering; this
; harness has no UI. `make DEBUG_I2=1` (root wires the flag + call site).
; ===========================================================================
%ifdef DEBUG_I2
global RunLinkCupsTest

SPECIES_RHYDON      equ 0x01
SPECIES_KANGASKHAN  equ 0x02
SPECIES_NIDORAN_M   equ 0x03
SPECIES_NIDORAN_F   equ 0x0f
SPECIES_DIGLETT     equ 0x3b
SPECIES_PIKACHU     equ 0x54

section .bss
align 4
link_cups_test_results: resb 4         ; [0]=PokeCup pass [1]=PokeCup fail
                                        ; [2]=PetitCup pass [3]=PetitCup fail

section .text
RunLinkCupsTest:
    ; --- scenario 1: PokeCup, valid team ---
    mov byte [ebp + wPartyCount], 3
    mov byte [ebp + wPartySpecies + 0], SPECIES_RHYDON
    mov byte [ebp + wPartySpecies + 1], SPECIES_KANGASKHAN
    mov byte [ebp + wPartySpecies + 2], SPECIES_NIDORAN_M
    mov byte [ebp + wPartyMon1Level], 53
    mov byte [ebp + wPartyMon2Level], 52
    mov byte [ebp + wPartyMon3Level], 50
    call PokeCup
    mov [link_cups_test_results + 0], al

    ; --- scenario 2: PokeCup, mon1 level pushed above the L55 ceiling ---
    mov byte [ebp + wPartyMon1Level], 60
    call PokeCup
    mov [link_cups_test_results + 1], al

    ; --- scenario 3: PetitCup, valid team of small real Pokemon ---
    mov byte [ebp + wPartySpecies + 0], SPECIES_DIGLETT
    mov byte [ebp + wPartySpecies + 1], SPECIES_NIDORAN_F
    mov byte [ebp + wPartySpecies + 2], SPECIES_PIKACHU
    mov byte [ebp + wPartyMon1Level], 28
    mov byte [ebp + wPartyMon2Level], 27
    mov byte [ebp + wPartyMon3Level], 25
    call PetitCup
    mov [link_cups_test_results + 2], al

    ; --- scenario 4: PetitCup, mon3 = Rhydon (real dex weight 265lb >> 44lb) ---
    mov byte [ebp + wPartySpecies + 2], SPECIES_RHYDON
    call PetitCup
    mov [link_cups_test_results + 3], al

.hang:
    jmp .hang
%endif
