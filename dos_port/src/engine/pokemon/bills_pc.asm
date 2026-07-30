; dos_port/src/engine/pokemon/bills_pc.asm
; Bill's PC — mirror of pret engine/pokemon/bills_pc.asm.
;
; Pret labels held here, in pret file order: DisplayPCMainMenu (+ its entry
; strings, generated), BillsPC_, BillsPCMenu, ExitBillsPC, BillsPCPrintBox,
; BillsPCDeposit, SleepingPikachuText2, BillsPCWithdraw, BillsPCRelease,
; BillsPCChangeBox, DisplayMonListMenu, BillsPCMenuText, BoxNoPCText,
; KnowsHMMove, HMMoveArray, DisplayDepositWithdrawMenu, DepositPCText,
; WithdrawPCText, StatsCancelPCText, and the text_far wrapper block.
; NOT here: CableClubLeftGameboy / CableClubRightGameboy / JustAMomentText /
; UnusedOpenBillsPC (+ OpenBillsPCText) — the serial-link tail of pret's file.
; The cable club is a serial-HAL boundary (TODO-HW: network HAL, Phase 4) and
; its entry points are owned by engine/link/cable_club.asm's package.
;
; PORT MODEL:
;  * SM83→x86: A=AL, B=BH, C=BL (BC=EBX), D=DH, E=DL (DE=EDX), HL=ESI;
;    EBP = GB base; GB memory at [EBP+addr]; flat program-image tables read via
;    [label] or [esi] (never [ebp+label]).
;  * DEVIATION(window-compositor), same shape as players_pc.asm: on the GB the
;    tilemap IS the screen; the port draws into the stride-20 W_TILEMAP scratch
;    and shows it through window descriptors.
;      - DisplayPCMainMenu publishes a 16-wide window clipped to the drawn
;        (event-gated) box height, over the live overworld (UI_PC_MAIN_MENU).
;      - The Bill's PC box UI is a full 20x18 GB-screen takeover window
;        (UI_BILLS_PC): menu box, message strip, BOX No. readout and the
;        deposit/withdraw submenu all live in one scratch, so every pret
;        coordinate lands 1:1. g_bg_whiteout=1 while it is up (the party-menu
;        screen class); the scratch's uncovered cells hold the Buffer2-restored
;        map mirror, exactly the tiles the GB shows there.
;      - Messages print through msgbox_bills_pc (MB_WIN_TILEMAP=0): pret's
;        message-box geometry, drawn into rows 12-17 of the same scratch, so
;        PrintText never collapses the window list (the msgbox_players_pc
;        reason). Visibility is by mirror, not per-character reveal — faithful
;        in effect because BillsPC_ sets BIT_NO_TEXT_DELAY, as pret does.
;      - DisplayListMenuID (the mon list) hides our window and shows its own
;        (its documented behaviour); every return path either re-appends via
;        bpc_show_window or redraws whole at BillsPCMenu. The list's PC-box
;        anchor is still the shared bag anchor — the list_menu.asm TODO(proj).
;
; Externs resolved:
;   MoveMon / RemovePokemon → src/home/move_mon.asm (the pret home wrappers)
;   ChangeBox               → src/engine/menus/save.asm (first live caller here)
;   PrintPCBox              → src/engine/printer/printer_stubs.asm (STUB)
;   PlayCry                 → src/home/home_stubs.asm (STUB)
;   ModifyPikachuHappiness  → src/engine/battle/battle_exp_stubs.asm (STUB)

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"                   ; text_far / text_end + TX_* codes
%include "msgbox.inc"                    ; MB_* — the message-box projection record
%include "events.inc"                    ; CheckEvent (clobbers AL, sets ZF)
%include "assets/event_constants.inc"    ; EVENT_MET_BILL / EVENT_GOT_POKEDEX
%include "assets/audio_constants.inc"    ; SFX_TURN_ON_PC / SFX_TURN_OFF_PC

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

global DisplayPCMainMenu
global KnowsHMMove

extern _MoveMon
extern _RemovePokemon
extern IsInArray                ; src/home/array2.asm (shared home global)
extern SaveScreenTilesToBuffer2 ; src/home/tilemap.asm
extern TextBoxBorder            ; home/text.asm — ESI=top-left, BL=int_w, BH=int_h
extern PlaceString              ; home/text.asm — ESI=dest, EAX=flat src; EBX=end
extern UpdateSprites            ; src/home/update_sprites.asm
extern add_window               ; ppu/ppu.asm — EAX=wx EBX=wy ECX=clip EDX=max_y ESI=tm EDI=row
extern text_row_stride          ; home/text.asm — active W_TILEMAP row stride
extern menu_item_step           ; home/window.asm — per-item cursor row step
extern menu_redraw_cb           ; home/window.asm — per-frame redraw cb (0=none)

; wMoveMonType/wRemoveMonFromBox values (constants/pokemon_data_constants.asm).
; Both live at the same WRAM address (wMoveMonType = wRemoveMonFromBox = $CF94).
; Not in the shared .inc files; defined locally.
%define BOX_TO_PARTY  0
%define PARTY_TO_BOX  1

BPC_STRIDE  equ 20              ; the GB-shaped scratch stride (NOT the 40-wide canvas)
TILE_SPC    equ 0x7F            ; blank space tile

; ===========================================================================
; Tier-1 DATA: the PC main-menu entry strings, the box-UI menu strings, and the
; fourteen message streams — generated from pret engine/pokemon/bills_pc.asm +
; data/text/text_3.asm.
%include "assets/bills_pc_text.inc"

section .bss
align 4
bpcm_rows:      resd 1          ; PC main menu: total drawn rows (int_h + 2)

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; DisplayPCMainMenu — pret ref: engine/pokemon/bills_pc.asm:DisplayPCMainMenu.
; Draws the BILL's / <player>'s / OAK's / LEAGUE / LOG OFF selector box (height
; event-gated on wNumHoFTeams and EVENT_GOT_POKEDEX, entries on EVENT_MET_BILL)
; and arms the menu vars for PCMainMenu's HandleMenuInput (pc.asm).
; In: EBP = GB base.
; ---------------------------------------------------------------------------
DisplayPCMainMenu:
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al   ; ldh [hAutoBGTransferEnabled], a
    call SaveScreenTilesToBuffer2
    ; DEVIATION{class=projection; pret=engine/pokemon/bills_pc.asm:DisplayPCMainMenu; behavior=draw into the stride-20 scratch and publish a height-clipped window instead of live tilemap cells; evidence=port window-compositor model, the players_pc.asm PlayerPCMenu precedent; lifetime=permanent window-compositor boundary}
    mov dword [text_row_stride], BPC_STRIDE
    mov al, [ebp + wNumHoFTeams]
    test al, al                              ; and a
    jnz .leaguePCAvailable                   ; jr nz
    CheckEvent EVENT_GOT_POKEDEX             ; ZF=1 → not yet
    jz .noOaksPC                             ; jr z
    mov al, [ebp + wNumHoFTeams]             ; pret re-reads it; kept
    test al, al
    jnz .leaguePCAvailable
    mov esi, W_TILEMAP                       ; hlcoord 0, 0
    mov bh, 8                                ; lb bc, 8, 14
    mov bl, 14
    jmp .next
.noOaksPC:
    mov esi, W_TILEMAP                       ; hlcoord 0, 0
    mov bh, 6                                ; lb bc, 6, 14
    mov bl, 14
    jmp .next
.leaguePCAvailable:
    mov esi, W_TILEMAP                       ; hlcoord 0, 0
    mov bh, 10                               ; lb bc, 10, 14
    mov bl, 14
.next:
    ; port: remember the drawn height — the window is clipped to it, so the
    ; shorter variants do not paint blank rows over the map (on the GB the
    ; undrawn rows simply keep showing the map).
    movzx eax, bh
    add eax, 2
    mov [bpcm_rows], eax
    call TextBoxBorder
    call UpdateSprites
    mov byte [ebp + wMaxMenuItem], 3         ; ld a, 3 / ld [wMaxMenuItem], a
    CheckEvent EVENT_MET_BILL                ; ZF=0 → met Bill
    jnz .metBill                             ; jr nz
    mov esi, W_TILEMAP + 2 * BPC_STRIDE + 2  ; hlcoord 2, 2
    mov eax, SomeonesPCText
    jmp .next2                               ; jr .next2
.metBill:
    mov esi, W_TILEMAP + 2 * BPC_STRIDE + 2  ; hlcoord 2, 2
    mov eax, BillsPCText
.next2:
    call PlaceString
    mov esi, W_TILEMAP + 4 * BPC_STRIDE + 2  ; hlcoord 2, 4
    lea eax, [ebp + wPlayerName]             ; ld de, wPlayerName (GB string → flat)
    call PlaceString
    mov esi, ebx                             ; ld l, c / ld h, b — continue at end
    mov eax, PlayersPCText
    call PlaceString
    CheckEvent EVENT_GOT_POKEDEX
    jz .noOaksPC2                            ; jr z
    mov esi, W_TILEMAP + 6 * BPC_STRIDE + 2  ; hlcoord 2, 6
    mov eax, OaksPCText
    call PlaceString
    mov al, [ebp + wNumHoFTeams]
    test al, al                              ; and a
    jz .noLeaguePC                           ; jr z
    mov byte [ebp + wMaxMenuItem], 4         ; ld a, 4 / ld [wMaxMenuItem], a
    mov esi, W_TILEMAP + 8 * BPC_STRIDE + 2  ; hlcoord 2, 8
    mov eax, PKMNLeaguePCText
    call PlaceString
    mov esi, W_TILEMAP + 10 * BPC_STRIDE + 2 ; hlcoord 2, 10
    mov eax, LogOffPCText
    jmp .next3                               ; jr .next3
.noLeaguePC:
    mov esi, W_TILEMAP + 8 * BPC_STRIDE + 2  ; hlcoord 2, 8
    mov eax, LogOffPCText
    jmp .next3                               ; jr .next3
.noOaksPC2:
    mov byte [ebp + wMaxMenuItem], 2         ; ld a, $2 / ld [wMaxMenuItem], a
    mov esi, W_TILEMAP + 6 * BPC_STRIDE + 2  ; hlcoord 2, 6
    mov eax, LogOffPCText
.next3:
    call PlaceString
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    mov byte [ebp + wTopMenuItemY], 2
    mov byte [ebp + wTopMenuItemX], 1
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al
    mov byte [ebp + hAutoBGTransferEnabled], 1
    ; port: publish the finished box as this screen's window, and hand
    ; HandleMenuInput (called next by PCMainMenu, pc.asm) the live-cursor
    ; mirror. pc.asm clears menu_redraw_cb when HandleMenuInput returns.
    call bpcm_show_window
    mov dword [menu_item_step], 2 * BPC_STRIDE
    mov dword [menu_redraw_cb], BPCMainMenuMirror
    ret

; ---------------------------------------------------------------------------
; bpcm_show_window — mirror the scratch and append the PC main-menu box
; (scratch rows 0..bpcm_rows-1 → GB_TILEMAP0) as this screen's window, clipped
; to the drawn variant height. Port-only (window-compositor boundary).
; ---------------------------------------------------------------------------
bpcm_show_window:
    call BPCMainMenuMirror
    mov eax, UI_PC_MAIN_MENU_WX
    mov ebx, UI_PC_MAIN_MENU_WY
    mov ecx, UI_PC_MAIN_MENU_CLIP
    mov edx, [bpcm_rows]
    shl edx, 3                               ; rows → pixels
    mov esi, GB_TILEMAP0
    xor edi, edi
    call add_window
    ret

; ---------------------------------------------------------------------------
; BPCMainMenuMirror — carry the stride-20 scratch rows 0-11 (the tallest menu
; variant) to GB_TILEMAP0; the window descriptor clips shorter variants. All
; registers preserved, so it also serves as HandleMenuInput's menu_redraw_cb
; (the live ▶ cursor is a scratch tile). Port-only.
; ---------------------------------------------------------------------------
BPCMainMenuMirror:
    pushad
    xor ebx, ebx
.row:
    imul esi, ebx, BPC_STRIDE
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                               ; row * 32
    lea edi, [ebp + edi + GB_TILEMAP0]
    mov ecx, UI_PC_MAIN_MENU_GBW
    rep movsb
    inc ebx
    cmp ebx, UI_PC_MAIN_MENU_GBH
    jb .row
    popad
    ret

section .text

global BillsPCDepositLogic
global BillsPCWithdrawLogic
global BillsPCReleaseLogic

; ---------------------------------------------------------------------------
; BillsPCDepositLogic
; Backend for depositing the party mon at [wWhichPokemon] into the current box.
; Sets wMoveMonType = PARTY_TO_BOX, calls _MoveMon (copy party→box),
; sets wRemoveMonFromBox = 0, calls _RemovePokemon (remove from party).
;
; MON_CATCH_RATE (struct offset 7, Gen-2 held-item slot) is preserved verbatim
; because _MoveMon copies all BOXMON_STRUCT_LENGTH (33) bytes of the party struct
; into the box entry unchanged.
;
; Inputs (WRAM): wWhichPokemon = party slot; wPartyCount, wBoxCount current.
; Returns: C clear on success; C set if party has only 1 mon, or box is full.
; ---------------------------------------------------------------------------
BillsPCDepositLogic:
    mov al, byte [ebp + wPartyCount]
    dec al
    jz .fail                        ; only 1 mon left — can't deposit last mon

    mov al, byte [ebp + wBoxCount]
    cmp al, MONS_PER_BOX
    je .fail                        ; box is full

    ; copy party[wWhichPokemon] → box, add to box species list, update wBoxCount
    mov byte [ebp + wMoveMonType], PARTY_TO_BOX
    call _MoveMon

    ; shift party entries up, decrement wPartyCount
    mov byte [ebp + wRemoveMonFromBox], 0   ; 0 = operate on party
    call _RemovePokemon

    clc
    ret
.fail:
    stc
    ret

; ---------------------------------------------------------------------------
; BillsPCWithdrawLogic
; Backend for withdrawing the box mon at [wWhichPokemon] into the party.
; Sets wMoveMonType = BOX_TO_PARTY, calls _MoveMon (copy box→party, recompute
; stats via CalcStats/CalcLevelFromExperience inside _MoveMon's BOX_TO_PARTY
; branch), sets wRemoveMonFromBox = 1, calls _RemovePokemon (remove from box).
;
; MON_CATCH_RATE (struct offset 7) is preserved: _MoveMon copies BOXMON_STRUCT_LENGTH
; bytes into the new party slot unchanged before the stat recompute overwrites
; only MON_STATS (offsets $22–$2B).
;
; Inputs (WRAM): wWhichPokemon = box slot; wBoxCount, wPartyCount current.
; Returns: C clear on success; C set if box is empty or party is full.
; ---------------------------------------------------------------------------
BillsPCWithdrawLogic:
    mov al, byte [ebp + wBoxCount]
    test al, al
    jz .fail                        ; box is empty

    mov al, byte [ebp + wPartyCount]
    cmp al, PARTY_LENGTH
    je .fail                        ; party is full

    ; copy box[wWhichPokemon] → party, rebuild party struct, recompute stats
    mov byte [ebp + wMoveMonType], BOX_TO_PARTY
    call _MoveMon

    ; shift box entries up, decrement wBoxCount
    mov byte [ebp + wRemoveMonFromBox], 1   ; 1 = operate on box
    call _RemovePokemon

    clc
    ret
.fail:
    stc
    ret

; ---------------------------------------------------------------------------
; BillsPCReleaseLogic
; Backend for releasing (permanently discarding) the box mon at [wWhichPokemon].
; Only calls _RemovePokemon — no copy is needed.
;
; Inputs (WRAM): wWhichPokemon = box slot; wBoxCount current.
; Returns: C clear on success; C set if box is empty.
; ---------------------------------------------------------------------------
BillsPCReleaseLogic:
    mov al, byte [ebp + wBoxCount]
    test al, al
    jz .fail                        ; box is empty

    mov byte [ebp + wRemoveMonFromBox], 1   ; 1 = operate on box
    call _RemovePokemon

    clc
    ret
.fail:
    stc
    ret


; ---------------------------------------------------------------------------
; KnowsHMMove
; Returns whether the party mon at index [wWhichPokemon] knows any HM move.
; Sets C flag if yes; clears C flag if no.
; Faithful to pret, including the dead wBoxMon1Moves branch below .next.
;
; Inputs (WRAM): wWhichPokemon = 0-based party slot index.
; Clobbers: EAX, ECX, EDX, ESI, EBX.
; ---------------------------------------------------------------------------
KnowsHMMove:
    mov esi, W_PARTY_MON1_MOVES     ; ld hl, wPartyMon1Moves ($D172)
    mov ecx, PARTYMON_STRUCT_LENGTH  ; ld bc, PARTYMON_STRUCT_LENGTH (44)
    jmp .next
    ; --- unreachable — pret-faithful dead code (mirrors the original binary) ---
    mov esi, W_BOX_MON1_MOVES       ; ld hl, wBoxMon1Moves ($DA9D)
    mov ecx, BOXMON_STRUCT_LENGTH   ; ld bc, BOXMON_STRUCT_LENGTH (33)
.next:
    ; AddNTimes equivalent: esi += wWhichPokemon * ecx (stride)
    movzx eax, byte [ebp + wWhichPokemon]   ; ld a,[wWhichPokemon]
    imul ecx, eax                            ; ecx = index × stride
    add esi, ecx                             ; esi → moves[wWhichPokemon]

    mov bh, NUM_MOVES               ; ld b, NUM_MOVES (4)
.loop:
    mov al, byte [ebp + esi]        ; ld a,[hli]  — read move id from GB mem
    inc esi                         ; (hli post-increment)

    push esi                        ; push hl  (save GB pointer)
    push ebx                        ; push bc  (save B=move-counter, C=scratch)

    lea esi, [HMMoveArray]          ; ld hl, HMMoveArray  — flat program address
    mov edx, 1                      ; ld de, 1  (stride = 1 byte)
    call IsInArray                  ; C set if AL found in HMMoveArray

    pop ebx                         ; pop bc
    pop esi                         ; pop hl

    jc .done                        ; ret c → jump to ret-with-carry

    dec bh                          ; dec b
    jnz .loop

    clc                             ; and a  (clear carry = not found)
.done:
    ret

; ---------------------------------------------------------------------------
section .data

; HM move list — searched by KnowsHMMove via IsInArray.
; Matches data/moves/hm_moves.asm (pret); terminated by $FF (-1).
; Move IDs from gb_constants.inc: CUT=$0F FLY=$13 SURF=$39 STRENGTH=$46 FLASH=$94
HMMoveArray:
    db CUT
    db FLY
    db SURF
    db STRENGTH
    db FLASH
    db -1       ; terminator ($FF / -1); matches pret's "db -1"
