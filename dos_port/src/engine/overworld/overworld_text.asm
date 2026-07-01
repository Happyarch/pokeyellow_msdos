; ===========================================================================
; overworld_text.asm — sign / interaction text dispatch (Wave 7, M7.2)
;
; Pret ref: home/overworld_text.asm (the collection of overworld TextScript_*
; routines) + the sign leg of home/overworld.asm:IsSpriteOrSignInFrontOfPlayer.
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
; CHECK-ONLY: no live caller yet (the A-press sign path is wired in a later step).
; Register map (SM83->x86): A->AL, HL->ESI, BC->BX, DE->DX; [ebp + SYM].
; ===========================================================================

%include "gb_memmap.inc"
%include "gb_macros.inc"

section .text

extern w_map_text_table_ptr             ; map_sprites.asm — flat ptr to cur map TextTable
extern ShowTextStream                   ; map_sprites.asm — copy TX stream -> buf, print, wait

global DisplaySignText

; ---------------------------------------------------------------------------
; DisplaySignText — show the sign text for the id SignLoop stashed in [hTextID].
;
; Mirrors CheckNPCInteraction's text-table dispatch (map_sprites.asm): the map's
; TextTable is an array of 8-byte entries {dd flat_ptr; dd byte_count}, keyed by
; text id.  A byte_count of 0xFFFFFFFF marks a SCRIPT (text_asm) entry.
;
; In:  [hTextID] = sign text id (0 = none).  Assumes the caller has already set
;      up the font + frozen the player exactly as CheckNPCInteraction does before
;      dispatch, and will restore them afterward (see the SignLoop integration
;      note in hidden_events.asm).
; Out: none.  All GP registers preserved.
;
; TODO(M7.2): script-entry signs (byte_count == $FFFFFFFF) are rare in Gen 1
; overworld signs; they are skipped here.  If a map needs one, CALL the flat
; routine like CheckNPCInteraction's .run_script path.
; ---------------------------------------------------------------------------
DisplaySignText:
    push eax
    push ecx
    push edx
    push esi
    push edi
    movzx eax, byte [ebp + hTextID]
    test eax, eax
    jz .done                            ; no sign text id
    mov ecx, [w_map_text_table_ptr]
    test ecx, ecx
    jz .done                            ; map has no text table
    lea edx, [eax * 8]                  ; 8 bytes per text-table entry
    mov edi, [ecx + edx]                ; flat ptr to TX stream (0 = none)
    test edi, edi
    jz .done
    mov eax, [ecx + edx + 4]            ; byte count, or 0xFFFFFFFF = script
    cmp eax, 0xFFFFFFFF
    je .done                            ; TODO: script-entry sign not handled here
    cmp eax, 256
    jae .done                           ; safety bound (matches CheckNPCInteraction)
    mov esi, edi                        ; flat src
    mov ecx, eax                        ; byte count
    call ShowTextStream
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; TextScript_* special cases — pret home/overworld_text.asm.
; These are Tier-2 dispatch stubs: they bankswitch (no-op under flat memory) and
; jump into a bank routine (PlayerPC / BillsPC_ / CeladonPrizeMenu / ActivatePC),
; then fall into HoldTextDisplayOpen.  All target routines are NI, so the
; dispatch bodies are scaffolded as TODO and guarded out of assembly until their
; targets land.  Kept here to record the faithful structure + integration point.
;
;   TextScript_ItemStoragePC   -> PlayerPC        (SaveScreenTilesToBuffer2 first)
;   TextScript_BillsPC         -> BillsPC_        (SaveScreenTilesToBuffer2 first)
;   TextScript_GameCornerPrizeMenu -> CeladonPrizeMenu
;   TextScript_PokemonCenterPC -> ActivatePC
; all converge on BankswitchAndContinue: Bankswitch + jp HoldTextDisplayOpen.
; ---------------------------------------------------------------------------
%ifdef M72_OVERWORLD_TEXTSCRIPTS
extern SaveScreenTilesToBuffer2         ; NI
extern HoldTextDisplayOpen              ; NI (home/text_script.asm — currently check-only)
extern PlayerPC                         ; NI
extern BillsPC_                         ; NI
extern CeladonPrizeMenu                 ; NI
extern ActivatePC                       ; NI

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
%endif ; M72_OVERWORLD_TEXTSCRIPTS
