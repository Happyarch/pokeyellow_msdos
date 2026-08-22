; hidden_events_stubs.asm — ret-only stubs for the 17 TextPredefs entries that are
; NOT printable data (predef-text plan Stage 2; docs/current_plan_predef_text.md).
;
; pret's TextPredefs table (data/text_predef_pointers.asm) has 68 entries. 51 are
; pure printable streams and are GENERATED into assets/predef_text.inc; the other
; 17 are 14 `text_asm` wrappers (the message IS code — paged readers, a quiz state
; machine, menu handlers, badge-count branches, WaitForSoundToFinish tails) and 3
; `script_*` dispatch markers. All 17 measure `missing`, and they belong to pret's
; engine/events/hidden_events/ subsystem (plus hidden_items.asm and bills_pc.asm),
; which the port has not taken on. Building the flat TextPredefs table requires
; these symbols to resolve at link; each stub just returns, so the entry is inert
; until the real routine lands. Remove a stub when its batch provides the real one.
;
; REACHABILITY IN THE LIVE BUILD: none of these is reached today. They are reached
; only from DisplayTextID's TEXT_PREDEF branch, which for a code row does
; `call esi` then jumps to AfterDisplayingTextID — and the only things that raise a
; predef text id are the per-object hidden-event HANDLERS (PrintNotebookText,
; PrintCinnabarQuiz, PrintBookcaseText, …), every one of which is itself still a
; ret-stub in src/engine/overworld/hidden_object_stubs.asm. So a stub here means
; "this predef text displays nothing", the text box is torn down normally, and no
; live path even gets that far.
;
; Register map: A→AL, HL→ESI; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

section .text

; --- script_* dispatch markers (3) -----------------------------------------

; RedBedroomPCText — RETIRED. The real faithful body is LINKED at its pret
; mirror src/engine/events/hidden_events/reds_room.asm (jumps into the linked
; TextScript_ItemStoragePC, src/home/map_objects.asm).

; PokemonCenterPCText — RETIRED. The real faithful body is LINKED at its pret
; mirror src/engine/events/hidden_events/pokecenter_pc.asm (jumps into the
; linked TextScript_PokemonCenterPC, src/home/map_objects.asm).

; OpenBillsPCText — RETIRED. The real body is LINKED at its pret mirror
; src/engine/pokemon/bills_pc.asm (jumps into the linked TextScript_BillsPC,
; src/home/map_objects.asm, and on into BillsPC_).

; --- text_asm wrappers (14) -------------------------------------------------

; SaffronCityPokecenterBenchGuyText — RETIRED (hidden-text-a batch). The real faithful
; body is LINKED at its pret mirror src/engine/events/hidden_events/bench_guys.asm.

; ViridianSchoolNotebook — RETIRED (school-notebooks batch). The real faithful
; body is LINKED at its pret mirror
; src/engine/events/hidden_events/school_notebooks.asm.

; ViridianSchoolBlackboard / LinkCableHelp / PrintBlackboardLinkCableText —
; RETIRED (school-blackboard batch). The real faithful bodies are LINKED at their
; pret mirror src/engine/events/hidden_events/school_blackboard.asm.

; FoundHiddenItemText — RETIRED. The real faithful body is LINKED at its pret
; mirror src/engine/events/hidden_items.asm (prints the generated far intro,
; then gives the item and sets the obtained flag). No reachable map carries a
; hidden item yet (the same gap that leaves ItemUseItemfinder's must-hit
; scenario owing evidence, docs/items_blockers.md), so it is still unreached in
; the live build — but the body itself is complete and correct.

; BillsHouseInitiatedText / BillsHousePokemonList — RETIRED 2026-08-21. The
; real faithful bodies are LINKED at their pret mirror
; src/engine/events/hidden_events/bills_house_pc.asm (whose handler
; BillsHousePC is likewise linked at that same file, no longer a ret-stub in
; hidden_object_stubs.asm).

; IndigoPlateauStatues — RETIRED (hidden-text-b batch). Real body at its pret
; mirror src/engine/events/hidden_events/indigo_plateau_statues.asm.

; TownMapText — RETIRED (hidden-text-c batch). Real body at its pret mirror
; src/engine/events/hidden_events/town_map.asm.

; BookOrSculptureText — RETIRED (hidden-text-a batch). The real faithful body is
; LINKED at its pret mirror src/engine/events/hidden_events/book_or_sculpture.asm.

; DisplayMonFrontSpriteInBox — RETIRED at integration. hidden-text-a added a
; ret-stub for it because route_15_binoculars.asm calls it and the label was
; missing on that branch; hidden-text-c ported museum_fossils2.asm, which is
; pret's home for it. Both branches were correct alone and collided on merge
; (multiple definition). The real body wins, per stub rule 5: retire, do not
; shadow. Real body: src/engine/events/hidden_events/museum_fossils2.asm.
