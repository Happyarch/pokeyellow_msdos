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

extern InitPlayerData2               ; engine/movie/oak_speech/init_player_data.asm

; DEVIATION: integration stub — OakSpeech's intro cutscene + naming screen (pret,
; package C) are not ported (script/cutscene work, docs/current_plan_script_engine.md).
; But its FIRST real action, `predef InitPlayerData2`, IS now ported and MUST run:
; it seeds the party/box/bag/box-item list terminators + starting money/ID. Without
; it a new game boots with uninitialised (DPMI-garbage) inventories and every list
; scan loops through memory (docs/glitch_safety.md). StartNewGameDebug falls through
; to SpecialEnterMap after this returns, so a new game boots straight to the
; overworld (the SKIP_TITLE posture). Replace the whole stub when the real OakSpeech
; cutscene lands (keep the InitPlayerData2 call — pret keeps it there too).
global OakSpeech
OakSpeech:
    call InitPlayerData2
    ret

; DisplayTitleScreen (B on the main menu returns to the title) is now REAL — the
; title module (src/movie/title.asm) exports its complete DisplayTitleScreen body;
; the former ret stub here is retired. (MainMenu is still not the boot path, so this
; seam is not yet exercised live, but it now resolves to the faithful renderer.)

; DEVIATION: integration stub — PrepareForSpecialWarp (the Hall-of-Fame CONTINUE
; special-warp path). wNumHoFTeams stays 0 until the HoF-movie writer, so this
; path is unreachable in the live build; ret keeps the faithful branch linkable.
global PrepareForSpecialWarp
PrepareForSpecialWarp:
    ret
