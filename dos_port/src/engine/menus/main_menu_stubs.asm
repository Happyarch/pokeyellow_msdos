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

; DEVIATION: integration stub — OakSpeech (the new-game intro cutscene, which in
; pret also runs the naming screen, package C) is not ported (script/cutscene work,
; docs/current_plan_script_engine.md). StartNewGameDebug falls through to
; SpecialEnterMap after this returns, so a new game boots straight to the overworld
; (the SKIP_TITLE posture). Delete when OakSpeech lands.
global OakSpeech
OakSpeech:
    ret

; DEVIATION: integration stub — DisplayTitleScreen (B on the main menu returns to
; the title). The port's title module exports PrepareTitleScreen, not this seam;
; MainMenu is not yet the boot path, so returning is safe. Delete when the title
; screen is wired as a live main-loop state.
global DisplayTitleScreen
DisplayTitleScreen:
    ret

; DEVIATION: integration stub — PrepareForSpecialWarp (the Hall-of-Fame CONTINUE
; special-warp path). wNumHoFTeams stays 0 until the HoF-movie writer, so this
; path is unreachable in the live build; ret keeps the faithful branch linkable.
global PrepareForSpecialWarp
PrepareForSpecialWarp:
    ret
