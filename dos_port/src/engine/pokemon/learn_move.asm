; learn_move.asm — LearnMove interactive teach flow (pret engine/pokemon/learn_move.asm).
;
; Source: engine/pokemon/learn_move.asm (pret/pokeyellow):
;   LearnMove, DontAbandonLearning, TryingToLearn, AbandonLearning, PrintLearnedMove.
; Structure-for-structure translation, including the interactive "delete a move to
; make room?" YES/NO + forget-list picker. Every call target keeps its pret name:
; DisplayTextBoxID, HandleMenuInput, TextBoxBorder, PlaceString, IsMoveHM,
; FormatMovesString, GetMoveName are all real, already-linked routines in this
; worktree (DisplayTextBoxID is now the real home/textbox.asm dispatcher, merged
; from menus-port — the former learn_move_stubs.asm placeholder has been deleted).
;
; Callers include LearnMoveFromLevelUp (src/engine/pokemon/evos_moves.asm) for
; battle level-ups and ItemUseMedicine's live Rare Candy flow, which recalculates
; stats and calls LearnMoveFromLevelUp before consuming the item.
;
; -----------------------------------------------------------------------
; DisplayTextBoxID (pret home/textbox.asm, TWO_OPTION_MENU dispatch) drives the
; two YES/NO prompts here. It is now the real, linked home/textbox.asm dispatcher
; (merged from the menus-port branch); the interim learn_move_stubs.asm placeholder
; that once stood in for it has been deleted from the tree and the Makefile.
;
; OneTwoAndText (the "1, 2 and... Poof!" message printed when a move is actually
; deleted to make room) is a COMPOSED wrapper at the bottom of this file: pret
; chains text_far -> text_pause -> text_asm, and only the far stream is data. The
; far half is generated (EXTRA_FAR in tools/generators/gen_battle_text.py); the
; wrapper bytes and the text_asm body (mute, SFX_SWAP on audio bank 1, continue
; at PoofText) are code here. Same split as engine/battle/common_text.asm's
; PlayerMon2Text and engine/battle/experience.asm's GainedText — the port's
; TextCommandProcessor gave TX_ASM real dispatch (text-engine finding T-1), so
; this needs no new machinery. The earlier "cannot exist yet" note here is
; RETIRED, along with the TODO-HW marker DontAbandonLearning carried in its place.
;
; Register map: A=AL, B=BH, C=BL (BC=EBX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; flat program-image tables (Moves) read via [label+off].
; hlcoord X,Y (macros/coords.asm) = wTileMap + Y*SCREEN_WIDTH + X, matching the
; established idiom in this port (bag_menu.asm/party_menu.asm use the same formula).
;
; Build: nasm -f coff -I include/ -I . -o learn_move.o learn_move.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "assets/audio_constants.inc"  ; SFX_SWAP / AUDIO_BANK_1 (generated)

; TextCommandProcessor opcodes (src/home/text.asm), same spelling common_text.asm
; uses for its composed text_far + text_asm wrappers.
TX_FAR_CMD   equ 0x17
TX_PAUSE_CMD equ 0x0A
TX_ASM_CMD   equ 0x08

section .text

global LearnMove
global DontAbandonLearning
global AbandonLearning
global TryingToLearn
global PrintLearnedMove
global OneTwoAndText

extern SaveScreenTilesToBuffer1     ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer1   ; src/home/tilemap.asm
extern GetPartyMonName              ; src/home/pokemon.asm
extern CopyData                     ; src/home/copy.asm
extern AddNTimes                    ; src/home/array.asm
extern PrintText                    ; src/home/window.asm
extern Moves                        ; src/data/moves/moves.asm — flat move-record table

extern GetMoveName                  ; src/home/names.asm — [wNamedObjectIndex] -> wNameBuffer
extern IsMoveHM                     ; src/home/names.asm — AL=move id -> CF
extern TextBoxBorder                ; src/home/text.asm — ESI=top-left, BL=width, BH=height
extern PlaceString                  ; src/home/text.asm — EAX=flat src, ESI=dest
extern FormatMovesString            ; src/engine/battle/misc.asm — wMoves -> wMovesString
extern HandleMenuInput              ; src/home/window.asm — AL = watched key(s) that ended input
extern text_row_stride              ; src/home/text.asm — current wTileMap row stride
extern menu_item_step               ; src/home/window.asm — HandleMenuInput cursor row step
extern DisplayTextBoxID             ; pret home/textbox.asm (linked, menus-port)
extern yn_box_col                   ; home/yes_no.asm — two-option box top-left, GB X
extern yn_box_row                   ; home/yes_no.asm — two-option box top-left, GB Y
extern yn_proj_mode                 ; home/yes_no.asm — 0 = overworld anchor, 1 = battle

extern DidNotLearnText               ; assets/battle_text.inc (gen_battle_text.py)
extern LearnedMove1Text
extern TryingToLearnText
extern AbandonLearningText
extern WhichMoveToForgetText
extern HMCantDeleteText
extern msgbox_centered                  ; src/engine/battle/core.asm — centered projection
extern text_msgbox                      ; src/home/text.asm — active msgbox projection (msgbox.inc)
extern _OneTwoAndText                   ; assets/battle_text.inc — the far stream only
extern PoofText                         ; assets/battle_text.inc (joined with ForgotAndText)
extern DelayFrame                       ; src/home/vblank.asm
extern PlaySound                        ; src/home/audio.asm — AL = sound id
extern WaitForSoundToFinish             ; src/home/delay.asm

; ---------------------------------------------------------------------------
; LearnMove — pret learn_move.asm:LearnMove.
; In:  [wWhichPokemon] = party index, [wMoveNum] = move id to teach.
; Out: BH = 0 (not learned) or 1 (learned) — matches pret's B.
; ---------------------------------------------------------------------------
LearnMove:
    call SaveScreenTilesToBuffer1
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMonNicks
    call GetPartyMonName             ; -> EDX = wNameBuffer (name copied there)
    mov esi, wNameBuffer
    mov edx, wLearnMoveMonName
    mov bx, NAME_LENGTH
    call CopyData

; ---------------------------------------------------------------------------
; DontAbandonLearning — pret learn_move.asm:DontAbandonLearning. Re-entered
; directly by AbandonLearning's "no, don't give up" path (picked a different
; move to forget).
; ---------------------------------------------------------------------------
DontAbandonLearning:
    mov esi, wPartyMon1
    add esi, MON_MOVES
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wWhichPokemon]
    call AddNTimes                   ; esi = wPartyMon1Moves + WhichPokemon*STRIDE
    mov edx, esi                     ; de = that base (preserved across the function)
    mov bh, NUM_MOVES
.findEmptyMoveSlotLoop:
    mov al, [ebp + esi]
    test al, al
    jz .next                         ; empty slot found — esi already points at it
    inc esi
    dec bh
    jnz .findEmptyMoveSlotLoop
    ; All 4 slots full — ask to delete a move.
    push edx
    call TryingToLearn
    pop edx
    jc AbandonLearning
    ; TryingToLearn succeeded: esi = the freed slot ptr, al = the forgotten move id.
    push esi
    push edx
    mov [ebp + wNamedObjectIndex], al
    call GetMoveName                 ; wNameBuffer = forgotten move's name
    mov esi, OneTwoAndText           ; ld hl, OneTwoAndText
    call PrintText
    pop edx
    pop esi
.next:
    mov al, [ebp + wMoveNum]
    mov [ebp + esi], al               ; write the new move into the slot
    mov edi, esi
    add edi, MON_PP - MON_MOVES       ; edi = the slot's corresponding PP byte
    ; New move's base PP, from the flat Moves table (matches add_mon.asm's
    ; LoadMovePPs idiom — flat model replaces pret's AddNTimes+FarCopyData+wBuffer
    ; ROM-bank roundtrip with a direct indexed read).
    movzx ecx, al
    dec ecx
    imul ecx, ecx, MOVE_LENGTH
    mov al, [Moves + ecx + MOVE_PP]
    mov [ebp + edi], al

    cmp byte [ebp + wIsInBattle], 0
    jz PrintLearnedMove
    mov al, [ebp + wWhichPokemon]
    mov bh, al
    mov al, [ebp + wPlayerMonNumber]
    cmp al, bh
    jnz PrintLearnedMove
    ; BUG{class=data-model; pret=engine/pokemon/learn_move.asm:LearnMove; behavior=level-up move refresh overwrites Mimic's temporary battle move with the party move array; evidence=pret LearnMove wPartyMonMoves to wBattleMonMoves CopyData plus yellow_glitches.md Mimic Level-Up entry; lifetime=permanent Gen-1 behavior}
    ; "Mimic Level-Up Glitch" — this unconditionally copies the
    ; PARTY struct's (permanent) move array over wBattleMonMoves. Mimic only
    ; ever overwrites the in-battle wBattleMonMoves copy of a slot, never the
    ; party struct, so if the active mon leveled up and learned a new move
    ; while Mimic's copied move was still active in another slot, this refresh
    ; clobbers that slot back to the party struct's un-Mimicked contents —
    ; Mimic's copied move reads as reset/"--" for the rest of the battle.
    ; Yellow-specific. Gen-1 behavior, preserved verbatim. pret ref:
    ; engine/pokemon/learn_move.asm:LearnMove (the wBattleMonMoves/PP
    ; CopyData refresh), docs/references/yellow_glitches.md#battle-system
    ; (Mimic Level-Up Glitch)
    mov esi, edx                      ; hl = de (move-array base)
    mov edx, wBattleMonMoves
    mov bx, NUM_MOVES
    call CopyData                     ; esi advances by NUM_MOVES -> base+MON_OTID
    add esi, MON_PP - MON_OTID        ; esi = the mon's PP array
    mov edx, wBattleMonPP
    mov bx, NUM_MOVES
    call CopyData
    jmp PrintLearnedMove

; ---------------------------------------------------------------------------
; AbandonLearning — pret learn_move.asm:AbandonLearning. Shows the real
; "Give up on it and forget trying to learn <MOVE>?" YES/NO prompt; NO routes
; back to DontAbandonLearning (pick a different move), YES prints DidNotLearnText.
; ---------------------------------------------------------------------------
AbandonLearning:
    mov esi, AbandonLearningText
    mov dword [text_msgbox], msgbox_centered   ; centered box: keep this screen's window list
    call PrintText
    mov esi, wTileMap + 7 * SCREEN_WIDTH + 14      ; hlcoord 14, 7
    mov bh, 8
    mov bl, 15                                       ; lb bc, 8, 15 (b,c = y,x cursor)
    ; The port places this box from yn_box_col/row/proj_mode (the window
    ; compositor), not from esi/bh/bl above — those stay for pret cross-
    ; reference only. Overworld/menu anchor.
    mov dword [yn_box_col], 14
    mov dword [yn_box_row], 7
    mov dword [yn_proj_mode], 0                      ; overworld/menu anchor
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    call DisplayTextBoxID                            ; yes/no menu
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz DontAbandonLearning
    mov esi, DidNotLearnText
    mov dword [text_msgbox], msgbox_centered   ; centered box: keep this screen's window list
    call PrintText
    xor bh, bh                        ; b = 0 (not learned)
    ret

; ---------------------------------------------------------------------------
; PrintLearnedMove — pret learn_move.asm:PrintLearnedMove. LearnedMove1Text's
; generated stream now correctly carries its own trailing TX_SOUND_GET_ITEM_1 /
; TX_PROMPT_BUTTON bytes (gen_battle_text.py's text_far-continuation fix), so
; PrintText's own TextCommandProcessor holds the box for the player exactly as
; pret does — no separate WaitForAPress bolt-on needed here.
; ---------------------------------------------------------------------------
PrintLearnedMove:
    mov esi, LearnedMove1Text
    mov dword [text_msgbox], msgbox_centered   ; centered box: keep this screen's window list
    call PrintText
    mov bh, 1                         ; b = 1 (learned)
    ret

; ---------------------------------------------------------------------------
; TryingToLearn — pret learn_move.asm:TryingToLearn. Real "Delete a move to
; make room for <MOVE>?" YES/NO; on YES, the real move-to-forget list menu
; (HandleMenuInput-driven, HM moves rejected via IsMoveHM).
; In:  esi (hl) = caller's cursor (moveArrayBase + NUM_MOVES), preserved/restored
;      across the YES/NO prompt exactly as pret's push hl / ... / pop hl does.
; Out (declined): CF = 1.
; Out (a move was freed): CF = 0, esi = freed slot ptr (within the party mon's own
;      move array), al = the forgotten move's id.
; ---------------------------------------------------------------------------
TryingToLearn:
    push esi                              ; save caller's hl
    mov esi, TryingToLearnText
    mov dword [text_msgbox], msgbox_centered   ; centered box: keep this screen's window list
    call PrintText
    mov esi, wTileMap + 7 * SCREEN_WIDTH + 14      ; hlcoord 14, 7
    mov bh, 8
    mov bl, 15                                       ; lb bc, 8, 15
    ; The port places this box from yn_box_col/row/proj_mode (the window
    ; compositor), not from esi/bh/bl above — those stay for pret cross-
    ; reference only. Overworld/menu anchor.
    mov dword [yn_box_col], 14
    mov dword [yn_box_row], 7
    mov dword [yn_proj_mode], 0                      ; overworld/menu anchor
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    call DisplayTextBoxID                            ; yes/no menu
    pop esi                                          ; restore caller's hl
    mov al, [ebp + wCurrentMenuItem]
    shr al, 1                                        ; rra (only bit0/CF matters)
    jnc .delete
    ret                                               ; ret c (declined)

.delete:
    add esi, -NUM_MOVES                              ; hl += -NUM_MOVES -> moveArrayBase
    push esi
    mov edx, wMoves
    mov ebx, NUM_MOVES
    call CopyData                                     ; party's move ids -> wMoves scratch
    call FormatMovesString                            ; callfar FormatMovesString (flat: no-op bank switch)
    pop esi
.loop:
    push esi
    mov esi, WhichMoveToForgetText
    mov dword [text_msgbox], msgbox_centered   ; centered box: keep this screen's window list
    call PrintText
    mov esi, wTileMap + 7 * SCREEN_WIDTH + 4        ; hlcoord 4, 7
    mov bl, 14
    mov bh, 4                                         ; lb bc, 4, 14 (TextBoxBorder: BH=height,BL=width)
    call TextBoxBorder
    mov esi, wTileMap + 8 * SCREEN_WIDTH + 6        ; hlcoord 6, 8
    lea eax, [ebp + wMovesString]
    or byte [ebp + hUILayoutFlags], 1 << BIT_SINGLE_SPACED_LINES
    call PlaceString
    and byte [ebp + hUILayoutFlags], ~(1 << BIT_SINGLE_SPACED_LINES)
    mov byte [ebp + wTopMenuItemY], 8
    mov byte [ebp + wTopMenuItemX], 5
    mov byte [ebp + wCurrentMenuItem], 0
    mov al, [ebp + wNumMovesMinusOne]
    mov byte [ebp + wMaxMenuItem], al
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    mov byte [ebp + wLastMenuItem], 0
    ; BIT_DOUBLE_SPACED_MENU-equivalent for this port's HandleMenuInput: it reads
    ; menu_item_step (not a hUILayoutFlags bit) — see src/home/window.asm header.
    mov eax, [text_row_stride]
    add eax, eax
    mov [menu_item_step], eax
    call HandleMenuInput
    push eax                                          ; save HandleMenuInput's returned key mask
    mov ecx, [text_row_stride]                        ; restore single-spaced default (scratch =
    mov [menu_item_step], ecx                         ; ECX, not EAX — pret's own res BIT_DOUBLE_
                                                       ; SPACED_MENU,[hl] is memory-only, doesn't touch A)
    call LoadScreenTilesFromBuffer1
    pop eax
    pop esi                                            ; hl restored = moveArrayBase (pushed at .loop)
    test al, PAD_B
    jnz .cancel
    push esi                                           ; save hl = moveArrayBase
    movzx ebx, byte [ebp + wCurrentMenuItem]           ; c = selectedIndex, b = 0
    add esi, ebx                                       ; hl = moveArrayBase + selectedIndex
    mov al, [ebp + esi]                                ; a = move id at that slot
    push eax
    push ebx
    call IsMoveHM                                      ; in: al=move id; out: CF=is-HM
    pop ebx
    pop eax
    jc .hm
    pop esi                                            ; hl restored = moveArrayBase
    add esi, ebx                                       ; hl = moveArrayBase + selectedIndex
    clc
    ret                                                 ; esi=freed slot ptr, al=forgotten move id, CF=0
.hm:
    mov esi, HMCantDeleteText
    mov dword [text_msgbox], msgbox_centered   ; centered box: keep this screen's window list
    call PrintText
    pop esi                                            ; hl restored = moveArrayBase
    jmp .loop
.cancel:
    stc
    ret

; ---------------------------------------------------------------------------
; OneTwoAndText — pret engine/pokemon/learn_move.asm:OneTwoAndText.
;
; pret spells it `text_far _OneTwoAndText` / `text_pause` / `text_asm <body>`.
; The far stream is generated (EXTRA_FAR in tools/generators/gen_battle_text.py);
; only the composed wrapper and the text_asm body are code, which is the same
; split common_text.asm's PlayerMon2Text and experience.asm's GainedText use.
;
; TX_ASM CONTRACT (src/home/text.asm:.cmd_asm is `push .next_cmd / jmp esi`,
; pret's `ld de, NextTextCommand / push de / jp hl`): the body runs with the
; stream pointer in ESI and, by RETURNING with ESI pointing at another stream,
; makes the processor continue there. pret's `ld hl, PoofText / ret` is exactly
; that, so it translates to `mov esi, PoofText / ret`.
;
; pret's own comment, kept: in Red/Blue SFX_SWAP was played from the wrong bank
; and the wrong sound came out; Yellow fixed it by switching to bank 1 first.
; The bank write is load-bearing in this port too — home/audio.asm:PlaySound
; selects the engine by [wAudioROMBank] (see the note at src/home/init.asm:161).
; ---------------------------------------------------------------------------
OneTwoAndText:
    db TX_FAR_CMD
    dd _OneTwoAndText
    db TX_PAUSE_CMD                                 ; text_pause
    db TX_ASM_CMD
.asm:
    push eax                                        ; push af
    push ebx                                        ; push bc
    push edx                                        ; push de
    push esi                                        ; push hl
    mov byte [ebp + wMuteAudioAndPauseMusic], 1     ; ld a,$1 / ld [wMuteAudioAndPauseMusic],a
    call DelayFrame
    mov al, [ebp + wAudioROMBank]
    push eax                                        ; push af
    mov al, AUDIO_BANK_1                            ; ld a, BANK(SFX_Swap_1)
    mov [ebp + wAudioROMBank], al
    mov [ebp + wAudioSavedROMBank], al
    call WaitForSoundToFinish
    mov al, SFX_SWAP
    call PlaySound
    call WaitForSoundToFinish
    pop eax                                         ; pop af
    mov [ebp + wAudioROMBank], al
    mov [ebp + wAudioSavedROMBank], al
    mov byte [ebp + wMuteAudioAndPauseMusic], 0     ; xor a / ld [...],a
    pop esi                                         ; pop hl
    pop edx                                         ; pop de
    pop ebx                                         ; pop bc
    pop eax                                         ; pop af
    mov esi, PoofText                               ; ld hl, PoofText
    ret                                             ; .cmd_asm resumes at ESI
