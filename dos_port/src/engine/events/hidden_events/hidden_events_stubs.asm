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

; SaffronCityPokecenterBenchGuyText — pret engine/events/hidden_events/bench_guys.asm.
; Branches on EVENT_BEAT_SILPH_CO_GIOVANNI to pick which line the bench guy says.
; Unreachable in the live build (PrintBenchGuyText is a ret-stub).
; TODO(overworld-events Stage 5, Saffron batch): port the event branch, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/bench_guys.asm:SaffronCityPokecenterBenchGuyText; behavior=the bench guy says nothing instead of branching on EVENT_BEAT_SILPH_CO_GIOVANNI; evidence=pret SaffronCityPokecenterBenchGuyText is a text_asm event branch and label_status reports it missing; lifetime=until the overworld-events Saffron batch lands; label=SaffronCityPokecenterBenchGuyText}
global SaffronCityPokecenterBenchGuyText
SaffronCityPokecenterBenchGuyText:
    ret

; ViridianSchoolNotebook — pret engine/events/hidden_events/school_notebooks.asm.
; The 5-page TurnPageSchoolNotebook reader (page state + A/B paging loop).
; Unreachable in the live build (PrintNotebookText is a ret-stub).
; TODO(overworld-events Stage 5, Viridian batch): port the paged reader, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/school_notebooks.asm:ViridianSchoolNotebook; behavior=the notebook displays nothing instead of running the 5-page TurnPageSchoolNotebook reader; evidence=pret ViridianSchoolNotebook is a text_asm paged reader and label_status reports it missing; lifetime=until the overworld-events Viridian batch lands; label=ViridianSchoolNotebook}
global ViridianSchoolNotebook
ViridianSchoolNotebook:
    ret

; ViridianSchoolBlackboard — pret engine/events/hidden_events/school_blackboard.asm.
; Paged blackboard reader (same shape as the notebook).
; Unreachable in the live build (PrintBlackboardLinkCableText is a ret-stub).
; TODO(overworld-events Stage 5, Viridian batch): port the paged reader, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/school_blackboard.asm:ViridianSchoolBlackboard; behavior=the blackboard displays nothing instead of running its paged reader; evidence=pret ViridianSchoolBlackboard is a text_asm paged reader and label_status reports it missing; lifetime=until the overworld-events Viridian batch lands; label=ViridianSchoolBlackboard}
global ViridianSchoolBlackboard
ViridianSchoolBlackboard:
    ret

; LinkCableHelp — pret engine/events/hidden_events/school_blackboard.asm:LinkCableHelp.
; The link-cable help reader that shares the blackboard's paging machinery.
; Unreachable in the live build (PrintBlackboardLinkCableText is a ret-stub).
; TODO(overworld-events Stage 5, Viridian batch): port with the blackboard, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/school_blackboard.asm:LinkCableHelp; behavior=the link-cable help displays nothing instead of running its paged reader; evidence=pret LinkCableHelp is a text_asm paged reader and label_status reports it missing; lifetime=until the overworld-events Viridian batch lands; label=LinkCableHelp}
global LinkCableHelp
LinkCableHelp:
    ret

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

; CinnabarGymQuiz — pret engine/events/hidden_events/cinnabar_gym_quiz.asm.
; The gym's question state machine (per-question event flags, right/wrong branches,
; trainer engagement on a wrong answer).
; Unreachable in the live build (PrintCinnabarQuiz is a ret-stub).
; TODO(overworld-events Stage 5, Cinnabar batch): port the state machine, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/cinnabar_gym_quiz.asm:CinnabarGymQuiz; behavior=the gym quiz displays nothing instead of running its question state machine; evidence=pret CinnabarGymQuiz is a text_asm state machine and label_status reports it missing; lifetime=until the overworld-events Cinnabar batch lands; label=CinnabarGymQuiz}
global CinnabarGymQuiz
CinnabarGymQuiz:
    ret

; IndigoPlateauStatues — pret engine/events/hidden_events/indigo_plateau_statues.asm.
; Counts obtained badges and picks the matching line.
; Unreachable in the live build (PrintIndigoPlateauHQText is a ret-stub).
; TODO(overworld-events Stage 5, Indigo batch): port the badge-count branch, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/indigo_plateau_statues.asm:IndigoPlateauStatues; behavior=the statues display nothing instead of branching on the badge count; evidence=pret IndigoPlateauStatues is a text_asm badge-count branch and label_status reports it missing; lifetime=until the overworld-events Indigo batch lands; label=IndigoPlateauStatues}
global IndigoPlateauStatues
IndigoPlateauStatues:
    ret

; VermilionGymTrashSuccessText1 — pret engine/events/hidden_events/vermilion_gym_trash.asm.
; First-switch success line with a WaitForSoundToFinish tail.
; Unreachable in the live build (PrintTrashText / GymTrashScript are ret-stubs).
; TODO(overworld-events Stage 5, Vermilion batch): port the tail, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/vermilion_gym_trash.asm:VermilionGymTrashSuccessText1; behavior=the first trash-can success message displays nothing and waits for no sound; evidence=pret VermilionGymTrashSuccessText1 is a text_asm WaitForSoundToFinish tail and label_status reports it missing; lifetime=until the overworld-events Vermilion batch lands; label=VermilionGymTrashSuccessText1}
global VermilionGymTrashSuccessText1
VermilionGymTrashSuccessText1:
    ret

; VermilionGymTrashSuccessText3 — pret engine/events/hidden_events/vermilion_gym_trash.asm.
; Second-switch success line with a WaitForSoundToFinish tail.
; Unreachable in the live build (PrintTrashText / GymTrashScript are ret-stubs).
; TODO(overworld-events Stage 5, Vermilion batch): port the tail, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/vermilion_gym_trash.asm:VermilionGymTrashSuccessText3; behavior=the second trash-can success message displays nothing and waits for no sound; evidence=pret VermilionGymTrashSuccessText3 is a text_asm WaitForSoundToFinish tail and label_status reports it missing; lifetime=until the overworld-events Vermilion batch lands; label=VermilionGymTrashSuccessText3}
global VermilionGymTrashSuccessText3
VermilionGymTrashSuccessText3:
    ret

; VermilionGymTrashFailText — pret engine/events/hidden_events/vermilion_gym_trash.asm.
; Wrong-can line with a WaitForSoundToFinish tail (resets the switch pair).
; Unreachable in the live build (PrintTrashText / GymTrashScript are ret-stubs).
; TODO(overworld-events Stage 5, Vermilion batch): port the tail, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/vermilion_gym_trash.asm:VermilionGymTrashFailText; behavior=the wrong-can message displays nothing and waits for no sound; evidence=pret VermilionGymTrashFailText is a text_asm WaitForSoundToFinish tail and label_status reports it missing; lifetime=until the overworld-events Vermilion batch lands; label=VermilionGymTrashFailText}
global VermilionGymTrashFailText
VermilionGymTrashFailText:
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

; BookOrSculptureText — pret engine/events/hidden_events/book_or_sculpture.asm.
; Branches on wCurMapTileset to say "bookshelf" or "sculpture".
; Unreachable in the live build (PrintBookcaseText is a ret-stub).
; TODO(overworld-events Stage 5): port the tileset branch, then delete.
; STUB{class=stub; pret=engine/events/hidden_events/book_or_sculpture.asm:BookOrSculptureText; behavior=the bookshelf or sculpture displays nothing instead of branching on wCurMapTileset; evidence=pret BookOrSculptureText is a text_asm tileset branch and label_status reports it missing; lifetime=until the overworld-events story batch lands; label=BookOrSculptureText}
global BookOrSculptureText
BookOrSculptureText:
    ret
