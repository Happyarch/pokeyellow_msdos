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

; DisplayTitleScreen (B on the main menu returns to the title) is now REAL — its
; pret mirror (src/engine/movie/title.asm) exports the complete DisplayTitleScreen body;
; the former ret stub here is retired. (MainMenu is still not the boot path, so this
; seam is not yet exercised live, but it now resolves to the faithful renderer.)

; PrepareForSpecialWarp stub RETIRED (wild-live promotion, 2026-07-10): the real
; body now links from engine/overworld/special_warps.asm, which was unblocked by
; linking engine/debug/debug_party.asm unconditionally (PrepareNewGameDebug).
; HandleBlackOut calls it for real, so this is no longer a dead path.

; DisplayPokemartDialogue_ stub RETIRED (overworld-events Stage 2):
; ported faithfully to src/engine/events/pokemart.asm.

; DisplayPokemonCenterDialogue_ stub RETIRED (overworld-events Stage 2):
; ported faithfully to src/engine/events/pokecenter.asm.

; VendingMachineMenu stub RETIRED (overworld-events Stage 2 / chunk 3):
; ported faithfully to src/engine/events/vending_machine.asm.

; CeladonPrizeMenu stub RETIRED (overworld-events Stage 2 / chunk 4):
; ported faithfully to src/engine/events/prize_menu.asm.

; DoClearSaveDialogue lives at its pret mirror, engine/movie/oak_speech/
; clear_save.asm (a temporary-DEVIATION body, not a stub — pret reaches it with
; farjp, so a ret-only stub cannot model it).
