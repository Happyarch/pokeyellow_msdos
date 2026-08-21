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
;   * StartSlotMachine           -> RETIRED 2026-08-15. engine/slots/ is in the
;                                   Makefile SRCS list and supplies the real body.
;   * OpenPokemonCenterPC / OpenRedsPC / BillsHousePC / CableClub{Left,Right}Gameboy
;                                -> PC / cable-club service work (Stage 2 tails / Phase 4)
;   * GymTrashScript / PrintTrashText -> RETIRED 2026-08-21. The real bodies are in
;                                   src/engine/events/hidden_events/vermilion_gym_trash.asm
;                                   (linked via GAME_SRCS).
;   * Mansion{1..4}Script_Switches, GymStatues, the remaining Print*Text
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


; --- Print*Text bench/flavor handlers (Stage 5) ---
; PrintBenchGuyText — RETIRED (hidden-text-a batch). The real faithful body is
; LINKED at its pret mirror src/engine/events/hidden_events/bench_guys.asm.
; PrintIndigoPlateauHQText — RETIRED (hidden-text-b batch). The real faithful
; body is LINKED at its pret mirror
; src/engine/events/hidden_events/indigo_plateau_hq.asm.
; PrintRedSNESText — RETIRED 2026-08-02 (predef-text plan). The real faithful body
; is LINKED at its pret mirror src/engine/events/hidden_events/reds_room.asm; it is
; the port's first real end-to-end predef-text call site (tx_pre_jump
; RedBedroomSNESText -> PrintPredefTextID).
; PrintNotebookText — RETIRED (school-notebooks batch). The real faithful body is
; LINKED at its pret mirror
; src/engine/events/hidden_events/school_notebooks.asm.
; PrintBlackboardLinkCableText — RETIRED (school-blackboard batch). The real
; faithful body is LINKED at its pret mirror
; src/engine/events/hidden_events/school_blackboard.asm.
; PrintNewBikeText — RETIRED (hidden-text-a batch). The real faithful body is
; LINKED at its pret mirror src/engine/events/hidden_events/new_bike.asm.
; PrintMagazinesText — RETIRED (hidden-text-a batch). The real faithful body is
; LINKED at its pret mirror src/engine/events/hidden_events/magazines.asm.

; DisplayOakLabLeftPoster, DisplayOakLabRightPoster — RETIRED. Real bodies in
; src/engine/events/hidden_events/oaks_lab_posters.asm.
; DisplayOakLabEmailText — RETIRED. Real body in
; src/engine/events/hidden_events/oaks_lab_email.asm.
; AerodactylFossil, KabutopsFossil — RETIRED. Real bodies in
; src/engine/events/hidden_events/museum_fossils.asm.
; FanClubPicture1, FanClubPicture2 — RETIRED. Real bodies in
; src/engine/events/hidden_events/fanclub_pictures.asm.

; --- Route 15 gate binoculars (Stage 5) ---
; Route15GateLeftBinoculars — RETIRED (hidden-text-a batch). The real faithful body
; is LINKED at its pret mirror src/engine/events/hidden_events/route_15_binoculars.asm.

