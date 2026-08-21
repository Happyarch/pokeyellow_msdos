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

; RedBedroomPCText — pret engine/events/hidden_events/reds_room.asm:RedBedroomPCText.
; A `script_players_pc` marker: the real entry opens the item-storage PC rather than
; printing anything. Unreachable in the live build (its handler OpenRedsPC is a
; ret-stub in hidden_object_stubs.asm).
; TODO(PC service work): replace with the players-PC dispatch, then delete this stub.
; STUB{class=stub; pret=engine/events/hidden_events/reds_room.asm:RedBedroomPCText; behavior=the players-PC script marker returns without opening the item-storage PC, so the predef text displays nothing; evidence=pret RedBedroomPCText is a script_players_pc marker and label_status reports it missing; lifetime=until the PC service work lands a real body; label=RedBedroomPCText}
global RedBedroomPCText
RedBedroomPCText:
    ret

; PokemonCenterPCText — pret engine/events/hidden_events/pokecenter_pc.asm:PokemonCenterPCText.
; A `script_pokecenter_pc` marker: opens the Pokémon Center PC. Unreachable in the
; live build (its handler OpenPokemonCenterPC is a ret-stub in hidden_object_stubs.asm).
; TODO(PC service work): replace with the pokecenter-PC dispatch, then delete this stub.
; STUB{class=stub; pret=engine/events/hidden_events/pokecenter_pc.asm:PokemonCenterPCText; behavior=the pokecenter-PC script marker returns without opening the Pokemon Center PC; evidence=pret PokemonCenterPCText is a script_pokecenter_pc marker and label_status reports it missing; lifetime=until the PC service work lands a real body; label=PokemonCenterPCText}
global PokemonCenterPCText
PokemonCenterPCText:
    ret

; OpenBillsPCText — pret engine/pokemon/bills_pc.asm:OpenBillsPCText.
; A `script_bills_pc` marker. NOTE the faithful Bill's PC box UI IS linked
; (src/engine/pokemon/bills_pc.asm, golden-gated by bills_pc_ops and
; box_change_roundtrip) — what is missing is only this hidden-event entry point into
; it, so this stub is a WIRING gap, not an unported feature. Unreachable in the live
; build (its handler BillsHousePC is a ret-stub in hidden_object_stubs.asm).
; TODO(PC service work): dispatch to the linked Bill's PC UI, then delete this stub.
; STUB{class=stub; pret=engine/pokemon/bills_pc.asm:OpenBillsPCText; behavior=the Bills-PC script marker returns without dispatching into the box UI; evidence=pret OpenBillsPCText is a script_bills_pc marker and label_status reports it missing while the faithful box UI in src/engine/pokemon/bills_pc.asm is linked and reached only by its own callers; lifetime=until the hidden-event PC dispatch is wired to the linked Bills PC UI; label=OpenBillsPCText}
global OpenBillsPCText
OpenBillsPCText:
    ret

; --- text_asm wrappers (14) -------------------------------------------------

; SaffronCityPokecenterBenchGuyText — RETIRED (hidden-text-a batch). The real faithful
; body is LINKED at its pret mirror src/engine/events/hidden_events/bench_guys.asm.

; ViridianSchoolNotebook — RETIRED (school-notebooks batch). The real faithful
; body is LINKED at its pret mirror
; src/engine/events/hidden_events/school_notebooks.asm.

; ViridianSchoolBlackboard / LinkCableHelp / PrintBlackboardLinkCableText —
; RETIRED (school-blackboard batch). The real faithful bodies are LINKED at their
; pret mirror src/engine/events/hidden_events/school_blackboard.asm.

; FoundHiddenItemText — pret engine/events/hidden_items.asm:FoundHiddenItemText.
; The item-award tail that runs AFTER the far "found an item" intro: gives the item
; and sets the obtained flag. Unreachable in the live build — HiddenItems is a
; ret-stub, and no reachable map carries a hidden item yet (the same gap that leaves
; ItemUseItemfinder's must-hit scenario owing evidence, docs/items_blockers.md).
; TODO(overworld-events Stage 3 / items plan): port the award tail with the first
; reachable hidden-item map, then delete this stub.
; STUB{class=stub; pret=engine/events/hidden_items.asm:FoundHiddenItemText; behavior=the hidden-item award tail displays nothing and awards no item after the far intro text; evidence=pret FoundHiddenItemText is a text_asm item-award tail and label_status reports it missing; lifetime=until the hidden-item award path lands with the first reachable hidden-item map; label=FoundHiddenItemText}
global FoundHiddenItemText
FoundHiddenItemText:
    ret

; BillsHouseInitiatedText — pret engine/events/hidden_events/bills_house_pc.asm.
; StopAllMusic + SFX_SWITCH sequence when Bill's PC is switched on.
; Unreachable in the live build (BillsHousePC is a ret-stub).
; TODO(overworld-events Stage 5, Bill's house batch): port the sound sequence, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/bills_house_pc.asm:BillsHouseInitiatedText; behavior=no StopAllMusic or SFX_SWITCH sequence plays when Bills PC is switched on; evidence=pret BillsHouseInitiatedText is a text_asm sound sequence and label_status reports it missing; lifetime=until the overworld-events Bills-house batch lands; label=BillsHouseInitiatedText}
global BillsHouseInitiatedText
BillsHouseInitiatedText:
    ret

; BillsHousePokemonList — pret engine/events/hidden_events/bills_house_pc.asm.
; HandleMenuInput + DisplayPokedex menu over Bill's mon list.
; Unreachable in the live build (BillsHousePC is a ret-stub).
; TODO(overworld-events Stage 5, Bill's house batch): port the menu, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/bills_house_pc.asm:BillsHousePokemonList; behavior=the mon list displays nothing instead of running its HandleMenuInput plus DisplayPokedex menu; evidence=pret BillsHousePokemonList is a text_asm menu handler and label_status reports it missing; lifetime=until the overworld-events Bills-house batch lands; label=BillsHousePokemonList}
global BillsHousePokemonList
BillsHousePokemonList:
    ret

; IndigoPlateauStatues — pret engine/events/hidden_events/indigo_plateau_statues.asm.
; Counts obtained badges and picks the matching line.
; Unreachable in the live build (PrintIndigoPlateauHQText is a ret-stub).
; TODO(overworld-events Stage 5, Indigo batch): port the badge-count branch, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/indigo_plateau_statues.asm:IndigoPlateauStatues; behavior=the statues display nothing instead of branching on the badge count; evidence=pret IndigoPlateauStatues is a text_asm badge-count branch and label_status reports it missing; lifetime=until the overworld-events Indigo batch lands; label=IndigoPlateauStatues}
global IndigoPlateauStatues
IndigoPlateauStatues:
    ret

; TownMapText — pret engine/events/hidden_events/town_map.asm:TownMapText.
; Opens the town map from a wall map rather than printing. NOTE the town-map screen
; itself IS ported (src/engine/items/town_map.asm) — this is the hidden-event entry
; into it, so another WIRING gap rather than an unported feature.
; Unreachable in the live build (its handler is a ret-stub).
; TODO(overworld-events Stage 5): dispatch to the linked town map, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/town_map.asm:TownMapText; behavior=the wall town map displays nothing instead of opening the town map screen; evidence=pret TownMapText is a text_asm that opens the town map and label_status reports it missing while the town-map screen itself is ported at src/engine/items/town_map.asm; lifetime=until the hidden-event dispatch is wired to the linked town map; label=TownMapText}
global TownMapText
TownMapText:
    ret

; BookOrSculptureText — RETIRED (hidden-text-a batch). The real faithful body is
; LINKED at its pret mirror src/engine/events/hidden_events/book_or_sculpture.asm.

; DisplayMonFrontSpriteInBox — pret engine/events/hidden_events/museum_fossils2.asm.
; Displays a pokemon's front sprite in a pop-up window.
; STUB{class=stub; pret=engine/events/hidden_events/museum_fossils2.asm:DisplayMonFrontSpriteInBox; behavior=does not display pokemon front sprite popup box; evidence=pret DisplayMonFrontSpriteInBox and label_status reports it missing; lifetime=until museum_fossils2.asm lands; label=DisplayMonFrontSpriteInBox}
global DisplayMonFrontSpriteInBox
DisplayMonFrontSpriteInBox:
    ret
