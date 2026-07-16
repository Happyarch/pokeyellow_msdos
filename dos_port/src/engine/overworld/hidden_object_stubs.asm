; ===========================================================================
; hidden_object_stubs.asm — Tier-2 hidden-event handler stubs (overworld-events
; Stage 3, bullet 1).
;
; The generated HiddenEventMaps data (assets/hidden_events.inc, via
; src/data/hidden_events_data.asm) points every per-map hidden_event entry at one
; of the handler labels below. Each is invoked by
; CheckForHiddenEventOrBookshelfOrCardKeyDoor (src/home/hidden_events.asm) via
; JumpToAddress (jp hl) AFTER it presets hItemAlreadyFound = 0. A handler that
; simply `ret`s therefore leaves hItemAlreadyFound = 0 = "the A-press was
; consumed here": the overworld returns to OverworldLoop without falling through
; to the sprite/sign scan, and nothing visible happens. That is the correct,
; safe standing-in behavior for a hidden-event tile whose real handler is not yet
; ported — the location silently eats the button rather than mis-dispatching.
;
; RETIREMENT: these are per-object handlers (project-conventions two-tier rule:
; behavior is Tier-2 code). Each retires when its owning subsystem / map lands:
;   * HiddenItems / HiddenCoins  -> overworld-events Stage 3 bullets 2-3 + items plan
;   * StartSlotMachine           -> a real body exists in engine/slots/
;                                   game_corner_slots.asm but that file is not yet
;                                   in any Makefile SRCS list; promoting it there
;                                   RETIRES this stub (delete it — dup global = loud
;                                   link error, per the stub no-shadow rule).
;   * OpenPokemonCenterPC / OpenRedsPC / BillsHousePC / CableClub{Left,Right}Gameboy
;                                -> PC / cable-club service work (Stage 2 tails / Phase 4)
;   * Mansion{1..4}Script_Switches, GymTrashScript/GymStatues, the Print*Text
;     bodies, fossils, posters, pictures, quiz, binoculars
;                                -> their per-map story batches (Stage 5)
;
; When a real body lands in a *linked* file, DELETE the matching stub here and
; run tools/label_status --callers <Label>. Do not leave the stub shadowing it.
; ===========================================================================

bits 32

%include "gb_memmap.inc"

; hInteractedWithBookshelf shares HRAM $FFDB with hItemToRemoveID (golden 00:ffdb);
; the two never overlap in time. Local alias so the PrintBookshelfText stub can
; write the "no bookshelf here" sentinel without touching gb_memmap.inc.
%ifndef H_INTERACTED_WITH_BOOKSHELF
H_INTERACTED_WITH_BOOKSHELF equ 0xFFDB
%endif

section .text

; ---------------------------------------------------------------------------
; PrintBookshelfText — pret engine/events/hidden_events/bookshelves.asm.
; Dispatch callee of CheckForHiddenEventOrBookshelfOrCardKeyDoor's fallback (NOT a
; data-table handler). The caller reads hInteractedWithBookshelf right after: $00
; = "bookshelf handled" (suppresses the sprite/sign scan), $FF = "no bookshelf
; here" (falls through to the sprite/sign scan). This stub MUST report $FF, or a
; stale value would silently break NPC/sign interaction. The real body does a
; (tileset, tile-in-front) lookup in BookshelfTileIDs + a PrintCardKeyText tail.
; RETIREMENT: port bookshelves.asm + BookshelfTileIDs + card-key-door text.
; ---------------------------------------------------------------------------
global PrintBookshelfText
PrintBookshelfText:
    mov byte [ebp + H_INTERACTED_WITH_BOOKSHELF], 0xFF   ; no bookshelf found
    ret

; ---------------------------------------------------------------------------
; UpdateCinnabarGymGateTileBlocks_ — pret engine/events/hidden_events/
; cinnabar_gym_quiz.asm. Real body flips Cinnabar gym gate blocks per unlock
; flags. No linked caller reaches it yet (only the deep-tier
; UpdateCinnabarGymGateTileBlocks wrapper calls it). RETIREMENT: Stage 5 Cinnabar.
; ---------------------------------------------------------------------------
global UpdateCinnabarGymGateTileBlocks_
UpdateCinnabarGymGateTileBlocks_:
    ret

; --- ground items / coins (Stage 3 bullets 2-3) ---
global HiddenItems
HiddenItems:
    ret
global HiddenCoins
HiddenCoins:
    ret

; --- PC access (PC / cable-club service tails) ---
global OpenPokemonCenterPC
OpenPokemonCenterPC:
    ret
global OpenRedsPC
OpenRedsPC:
    ret
global BillsHousePC
BillsHousePC:
    ret
global CableClubLeftGameboy
CableClubLeftGameboy:
    ret
global CableClubRightGameboy
CableClubRightGameboy:
    ret

; --- Game Corner slots (real body in engine/slots/game_corner_slots.asm, unlinked) ---
global StartSlotMachine
StartSlotMachine:
    ret

; --- Pokémon Mansion switch scripts (Stage 5: Cinnabar) ---
global Mansion1Script_Switches
Mansion1Script_Switches:
    ret
global Mansion2Script_Switches
Mansion2Script_Switches:
    ret
global Mansion3Script_Switches
Mansion3Script_Switches:
    ret
global Mansion4Script_Switches
Mansion4Script_Switches:
    ret

; --- gym / dojo interactables (Stage 5) ---
global GymTrashScript
GymTrashScript:
    ret
global GymStatues
GymStatues:
    ret
global PrintFightingDojoText
PrintFightingDojoText:
    ret
global PrintFightingDojoText2
PrintFightingDojoText2:
    ret
global PrintFightingDojoText3
PrintFightingDojoText3:
    ret

; --- Print*Text bench/flavor handlers (Stage 5) ---
global PrintTrashText
PrintTrashText:
    ret
global PrintBenchGuyText
PrintBenchGuyText:
    ret
global PrintIndigoPlateauHQText
PrintIndigoPlateauHQText:
    ret
global PrintRedSNESText
PrintRedSNESText:
    ret
global PrintBookcaseText
PrintBookcaseText:
    ret
global PrintNotebookText
PrintNotebookText:
    ret
global PrintBlackboardLinkCableText
PrintBlackboardLinkCableText:
    ret
global PrintNewBikeText
PrintNewBikeText:
    ret
global PrintMagazinesText
PrintMagazinesText:
    ret
global PrintCinnabarQuiz
PrintCinnabarQuiz:
    ret

; --- Oak's Lab posters / email (Stage 5: Pallet) ---
global DisplayOakLabLeftPoster
DisplayOakLabLeftPoster:
    ret
global DisplayOakLabRightPoster
DisplayOakLabRightPoster:
    ret
global DisplayOakLabEmailText
DisplayOakLabEmailText:
    ret

; --- museum fossils (Stage 5: Pewter) ---
global AerodactylFossil
AerodactylFossil:
    ret
global KabutopsFossil
KabutopsFossil:
    ret

; --- Pokémon Fan Club pictures (Stage 5: Vermilion) ---
global FanClubPicture1
FanClubPicture1:
    ret
global FanClubPicture2
FanClubPicture2:
    ret

; --- Route 15 gate binoculars (Stage 5) ---
global Route15GateLeftBinoculars
Route15GateLeftBinoculars:
    ret
