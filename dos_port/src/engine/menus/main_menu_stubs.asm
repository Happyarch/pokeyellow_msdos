; main_menu_stubs.asm — integration-spine stubs for the boot seams main_menu.asm
; (menus S7, package E) reaches but that are not yet ported. The port boots the
; overworld via SKIP_TITLE, so these seams are exercised only through the real
; MainMenu flow (not yet the boot path) and the DEBUG_MAINMENU harness never hits
; them; ret/faithful stubs let the faithful MainMenu control flow link today.
; Each is deleted when its real routine lands (title screen / OakSpeech cutscene /
; special-warp), the same convention as league_pc_stubs.asm.
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

section .text

; OakSpeech stub RETIRED (menu-intro A4.5): the real cutscene now links from
; engine/movie/oak_speech/oak_speech.asm (music, four intro pics + text, the
; player/rival naming flow, shrink-into-overworld hand-off). It still calls
; InitPlayerData2 first, exactly as pret keeps it. StartNewGame(Debug) calls the
; real OakSpeech now; a debug-mode (BIT_DEBUG_MODE) new game still skips the speech
; and naming, so the seeded debug names survive.

; DisplayTitleScreen (B on the main menu returns to the title) is now REAL — the
; title module (src/movie/title.asm) exports its complete DisplayTitleScreen body;
; the former ret stub here is retired. (MainMenu is still not the boot path, so this
; seam is not yet exercised live, but it now resolves to the faithful renderer.)

; PrepareForSpecialWarp stub RETIRED (wild-live promotion, 2026-07-10): the real
; body now links from engine/overworld/special_warps.asm, which was unblocked by
; linking engine/debug/debug_party.asm unconditionally (PrepareNewGameDebug).
; HandleBlackOut calls it for real, so this is no longer a dead path.

; STUB{class=stub; label=DisplayPokemartDialogue_; pret=engine/menus/pokemart.asm:DisplayPokemartDialogue_; behavior=return immediately after DisplayTextID loads the mart item list instead of running buy/sell/service dialogs; evidence=overworld-events Stage 2 keeps mart transaction loops open; lifetime=until Stage 2 ports DisplayPokemartDialogue_ and the buy/sell loops}
; The home-layer DisplayPokemartDialogue wrapper is linked now so normal
; DisplayTextID text can run; the transaction UI remains a separate Stage 2 task.
global DisplayPokemartDialogue_
DisplayPokemartDialogue_:
    ret

; STUB{class=stub; label=DisplayPokemonCenterDialogue_; pret=engine/menus/pokemon_center.asm:DisplayPokemonCenterDialogue_; behavior=return immediately instead of running nurse heal flow and Pokemon Center PC shell; evidence=overworld-events Stage 2 keeps nurse verification open; lifetime=until Stage 2 ports the nurse heal flow}
global DisplayPokemonCenterDialogue_
DisplayPokemonCenterDialogue_:
    ret

; STUB{class=stub; label=VendingMachineMenu; pret=engine/menus/vending_machine.asm:VendingMachineMenu; behavior=return immediately instead of opening the vending-machine menu; evidence=overworld-events Stage 2 leaves vending tails open; lifetime=until vending service tail lands}
global VendingMachineMenu
VendingMachineMenu:
    ret

; STUB{class=stub; label=CeladonPrizeMenu; pret=engine/menus/game_corner_prizes.asm:CeladonPrizeMenu; behavior=return immediately instead of opening the Game Corner prize menu; evidence=overworld-events Stage 2 records CeladonPrizeMenu as missing; lifetime=until prize-service tail lands}
global CeladonPrizeMenu
CeladonPrizeMenu:
    ret

; STUB{class=stub; label=CableClubNPC; pret=engine/menus/cable_club.asm:CableClubNPC; behavior=return immediately instead of opening cable-club flow; evidence=overworld-events Stage 2 says cable-club behavior remains Phase 4; lifetime=until Phase 4 cable/link behavior lands}
global CableClubNPC
CableClubNPC:
    ret

; DoClearSaveDialogue lives at its pret mirror, engine/movie/oak_speech/
; clear_save.asm (a temporary-DEVIATION body, not a stub — pret reaches it with
; farjp, so a ret-only stub cannot model it).
