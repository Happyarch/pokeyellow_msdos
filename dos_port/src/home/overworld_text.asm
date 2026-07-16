; ===========================================================================
; overworld_text.asm — sign / interaction text dispatch + overworld text-script
; ending helpers.
;
; Pret refs (OW-A.12 provenance fix — the old header wrongly attributed everything
; here to home/overworld_text.asm):
;   * DisplaySignText — BESPOKE port routine. It mirrors the port's own
;     CheckNPCInteraction text-table dispatch (map_sprites.asm; the sign leg of pret
;     home/overworld.asm:IsSpriteOrSignInFrontOfPlayer), and its first-byte special-
;     case handling follows pret home/text_script.asm:DisplayTextID (lines 71-84).
;   * TextScript_* special cases — pret home/text_script.asm (DisplayTextID's dispatch
;     targets), NOT home/overworld_text.asm.
;   * TextScriptEnd / TextScriptEndingText — pret home/overworld_text.asm (ported here;
;     the remaining 6 home/overworld_text.asm labels are DEFERRED — see the note below).
;
; TWO-TIER RULE (CLAUDE.md):
;   * DATA (Tier 1) — sign text streams: NOT authored here.  In Gen 1 a sign's
;     wSignTextIDs entry indexes the SAME per-map text pointer table that NPC
;     text IDs index.  That table is the port's generated `MapTextTablePointers`
;     -> w_map_text_table_ptr mechanism (map_sprites.asm / gen_map_scripts.py).
;     So the sign's text data already exists as generated map data; no new .inc.
;   * CODE (Tier 2) — this file: the small dispatch that turns a sign's hTextID
;     (set by SignLoop, hidden_events.asm) into a ShowTextStream call, plus the
;     hand-written TextScript_* special cases (PC / prize menu / Poke Center PC),
;     which are behavior, not data.
;
; LIVE (fidelity Stage 1b): DoSignInteraction (engine/overworld/overworld.asm) calls
; DisplaySignText from OverworldLoop's A-press dispatch, via
; IsSpriteOrSignInFrontOfPlayer's sign branch → SignLoop (home/hidden_events.asm).
; Goldened by the sign_pallet scenario.
; Register map (SM83->x86): A->AL, HL->ESI, BC->BX, DE->DX; [ebp + SYM].
; ===========================================================================

%include "gb_memmap.inc"
%include "gb_macros.inc"

; --- pret TX_SCRIPT_* sentinels (macros/scripts/text.asm:185-236). The first byte of
; a resolved text stream in $F6-$FF selects a special DisplayTextID handler instead of
; ordinary text. Defined locally (not in this file's include chain); mirror of the
; canonical copies in include/m1_3_pending_symbols.inc. -----------------------------
TX_SCRIPT_PRIZE_VENDOR              equ 0xF7
TX_SCRIPT_POKECENTER_PC             equ 0xF9
TX_SCRIPT_PLAYERS_PC                equ 0xFC
TX_SCRIPT_BILLS_PC                  equ 0xFD
TX_SCRIPT_LOWEST                    equ 0xF6  ; = TX_SCRIPT_CABLE_CLUB_RECEPTIONIST (range floor)

section .text

extern w_map_text_table_ptr             ; map_sprites.asm — flat ptr to cur map TextTable
extern ShowTextStream                   ; map_sprites.asm — print flat TX stream, wait
extern PickUpItem                       ; engine/events/pick_up_item.asm (PickUpItemText predef)

global DisplaySignText
global TextScriptEnd
global TextScriptEndingText

; ---------------------------------------------------------------------------
; DisplaySignText — show the sign text for the id SignLoop stashed in [hTextID].
;
; Mirrors CheckNPCInteraction's text-table dispatch (map_sprites.asm): the map's
; TextTable is an array of 8-byte entries {dd flat_ptr; dd byte_count}, keyed by
; text id.  A byte_count of 0xFFFFFFFF marks a text_asm SCRIPT entry.
;
; Before printing, the first byte of the resolved stream is checked for pret's
; TX_SCRIPT_* sentinels ($F6-$FF): those "signs" are menu openers (player's PC, mart
; counter, prize vendor, ...), not text — see the dispatch below.
;
; In:  [hTextID] = sign text id (0 = none).  Assumes the caller has already set
;      up the font + frozen the player exactly as CheckNPCInteraction does before
;      dispatch, and will restore them afterward (see the SignLoop integration
;      note in hidden_events.asm).
; Out: none.  All GP registers preserved via pushad/popad (OW-A.12: the old explicit
;      push set omitted EBX, which ShowTextStream->npc_dialog_wait_impl clobbers).
; ---------------------------------------------------------------------------
DisplaySignText:
    pushad
    movzx eax, byte [ebp + hTextID]     ; pret's 1-based sign text id
    test eax, eax
    jz .done                            ; id 0 = no sign text (pret's sentinel)
    mov ecx, [w_map_text_table_ptr]
    test ecx, ecx
    jz .done                            ; map has no text table
    ; Ids are pret's 1-based consts and pret subtracts one at the lookup
    ; (home/text_script.asm: `dec a`). Folded into the 8-byte entry scale.
    lea edx, [eax * 8 - 8]              ; 8 bytes per text-table entry
    mov edi, [ecx + edx]                ; flat ptr to TX stream (0 = none)
    test edi, edi
    jz .done

    ; --- pret DisplayTextID first-byte special-case dispatch (home/text_script.asm:71-84) ---
    mov al, [edi]                       ; first byte of the resolved TX stream
    cmp al, TX_SCRIPT_LOWEST            ; $F6 — lowest TX_SCRIPT sentinel
    jb  .printText                      ; ordinary text (< $F6) → print it
    ; A "sign" whose stream starts with a TX_SCRIPT sentinel ($F6-$FF) is a menu opener.
    ; The four with landed port handlers tail-dispatch below; the rest are recognized and
    ; SKIPPED so the sentinel byte is never rendered as a garbage glyph (the SCAFFOLD bug
    ; this fixes — pret would dispatch them to DisplayPokemartDialogue /
    ; DisplayPokemonCenterDialogue / CableClubNPC, all still NI here).
    cmp al, TX_SCRIPT_PLAYERS_PC        ; $FC → item-storage PC
    je  .toItemStoragePC
    cmp al, TX_SCRIPT_BILLS_PC          ; $FD → Bill's PC
    je  .toBillsPC
    cmp al, TX_SCRIPT_POKECENTER_PC     ; $F9 → Poke Center PC
    je  .toPokemonCenterPC
    cmp al, TX_SCRIPT_PRIZE_VENDOR      ; $F7 → Game Corner prize menu
    je  .toPrizeMenu
    ; TX_SCRIPT_MART ($FE), _POKECENTER_NURSE ($FF), vending ($F8), and cable
    ; ($F6) are owned by DisplayTextID proper, not this sign-only shim.
    jmp .done

.printText:
    mov eax, [ecx + edx + 4]            ; script/stream discriminator (0xFFFFFFFF = text_asm)
    cmp eax, 0xFFFFFFFF
    je .done                            ; text_asm SCRIPT entry — handled by CheckNPCInteraction, not here
    mov esi, edi                        ; flat src — TCP walks it in place
    call ShowTextStream
.done:
    popad
    ret

; The TextScript_* handlers tail-jump to HoldTextDisplayOpen (pret: jr AfterDisplayingTextID)
; and never return here, so restore the caller's registers (popad) before the tail-jump.
.toItemStoragePC:
    popad
    jmp TextScript_ItemStoragePC
.toBillsPC:
    popad
    jmp TextScript_BillsPC
.toPokemonCenterPC:
    popad
    jmp TextScript_PokemonCenterPC
.toPrizeMenu:
    popad
    jmp TextScript_GameCornerPrizeMenu

; ---------------------------------------------------------------------------
; TextScriptEnd / TextScriptEndingText — pret home/overworld_text.asm.
; TextScriptEnd returns HL(->ESI) pointing at an empty (terminator-only) text stream,
; used by text_asm scripts as their "nothing more to print" tail (e.g. pret PickUpItemText
; and the port's TrainerEndBattleText, trainer_engine.asm:808 `jmp TextScriptEnd`).
; Porting this pair here resolves the trainer_engine.asm extern (its promotion, OW-7.2)
; without pulling in the deferred text-data labels below.
; NOTE(consumer read-model): ESI is a FLAT .data pointer; whether the eventual consumer
; reads it flat vs EBP-relative rides the deferred TrainerEndBattleText work (OW-A.9
; KNOWN-BROKEN note) — porting the label here is purely to unblock the link.
; ---------------------------------------------------------------------------
TextScriptEnd:
    mov esi, TextScriptEndingText       ; ld hl, TextScriptEndingText
    ret

; ---------------------------------------------------------------------------
; PickUpItemText — pret home/overworld_text.asm: `text_asm / predef PickUpItem /
; jp TextScriptEnd`. A text_asm handler the map text table routes an item ball's
; text id to; DisplayTextID reaches it via text_script.asm's `call esi`.
; PickUpItem (src/engine/events/pick_up_item.asm) does its own printing, so this
; runs it (predef → direct call, no predef dispatcher in the port) and tails into
; TextScriptEnd. The dispatch discards the returned stream (text_script.asm:194
; `call esi` / `jmp AfterDisplayingTextID`), so the empty TextScriptEnd stream is
; harmless — it preserves pret's structure exactly.
; ---------------------------------------------------------------------------
global PickUpItemText
PickUpItemText:
    call PickUpItem                     ; predef PickUpItem
    jmp TextScriptEnd                   ; jp TextScriptEnd

; ---------------------------------------------------------------------------
; DEFERRED — the remaining 5 home/overworld_text.asm labels are NOT ported here:
;   ExclamationText, GroundRoseText, BoulderText, MartSignText, PokeCenterSignText
;     — each is `text_far _XxxText / text_end`; the underlying _XxxText strings are
;       Tier-1 DATA not yet generated for the port. Per the two-tier rule they must come
;       from a gen_*.py → assets/*.inc, NOT hand-encoded charmap bytes here.
; No live caller needs them today; port them with the sign-text string generator when a
; map that uses them lands.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; TextScript_* special cases — pret home/text_script.asm (DisplayTextID dispatch targets).
; Tier-2 dispatch stubs: they bankswitch (no-op under flat memory) and jump into a bank
; routine (PlayerPC / BillsPC_ / CeladonPrizeMenu / ActivatePC), then fall into
; HoldTextDisplayOpen. PlayerPC and ActivatePC are linked; BillsPC_ and
; CeladonPrizeMenu resolve through structured menu stubs until their real UIs land.
;
;   TextScript_ItemStoragePC   -> PlayerPC        (SaveScreenTilesToBuffer2 first)
;   TextScript_BillsPC         -> BillsPC_        (SaveScreenTilesToBuffer2 first)
;   TextScript_GameCornerPrizeMenu -> CeladonPrizeMenu
;   TextScript_PokemonCenterPC -> ActivatePC
; all converge on BankswitchAndContinue: Bankswitch + jp HoldTextDisplayOpen.
; ---------------------------------------------------------------------------
extern SaveScreenTilesToBuffer2         ; movie/title.asm
extern HoldTextDisplayOpen              ; home/text_script.asm
extern PlayerPC                         ; engine/menus/players_pc.asm
extern BillsPC_                         ; engine/menus/pc_stubs.asm
extern CeladonPrizeMenu                 ; engine/menus/main_menu_stubs.asm
extern ActivatePC                       ; engine/menus/pc.asm

global TextScript_ItemStoragePC
global TextScript_BillsPC
global TextScript_GameCornerPrizeMenu
global TextScript_PokemonCenterPC

TextScript_ItemStoragePC:
    call SaveScreenTilesToBuffer2
    mov esi, PlayerPC
    jmp BankswitchAndContinue

TextScript_BillsPC:
    call SaveScreenTilesToBuffer2
    mov esi, BillsPC_
    jmp BankswitchAndContinue

TextScript_GameCornerPrizeMenu:
    mov esi, CeladonPrizeMenu
    jmp BankswitchAndContinue

TextScript_PokemonCenterPC:
    mov esi, ActivatePC
BankswitchAndContinue:
    call esi                            ; Bankswitch is a no-op under flat memory
    jmp HoldTextDisplayOpen

; ---------------------------------------------------------------------------
section .data

TextScriptEndingText:
    db 0x50                             ; $50 = text terminator (pret home/overworld_text.asm: text_end)
