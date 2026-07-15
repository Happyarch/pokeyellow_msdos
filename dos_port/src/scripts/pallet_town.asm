; pallet_town.asm — hand-translated text_asm scripts for Pallet Town.
;
; Reference port of the event/var-gated dialog in scripts/PalletTown.asm. This is
; the first faithful text_asm translation and the template for the rest: a script
; is a native routine reached from the map's TextTable via a SCRIPT entry
; (`dd <label>, 0xFFFFFFFF`, emitted by gen_npc_dialogs' SCRIPT_OVERRIDES). The
; dialog dispatcher (map_sprites.asm:CheckNPCInteraction) CALLs the routine after
; loading the font; the routine picks a text stream and prints it via ShowTextStream
; (PrintText on the flat stream, then wait for A/B), then returns.
;
; In: EBP = GB memory base; font already loaded; player frozen in a standing pose.
; The routine may use AL/flags freely (caller preserves via pushad).

bits 32

%include "gb_memmap.inc"
%include "assets/event_constants.inc"
%include "events.inc"

global PalletTownOakText
global PalletTown_Script
extern ShowTextStream            ; (ESI = flat TX stream — walked in place)
extern CallFunctionInTable       ; (AL = index, ESI = flat dd jumptable)
extern EnableAutoTextBoxDrawing

; PalletTown_ScriptPointers state indices (pret: def_script_pointers in
; scripts/PalletTown.asm — SCRIPT_PALLETTOWN_*).
SCRIPT_PALLETTOWN_DEFAULT              equ 0
SCRIPT_PALLETTOWN_OAK_HEY_WAIT         equ 1
SCRIPT_PALLETTOWN_OAK_WALKS_TO_PLAYER  equ 2
SCRIPT_PALLETTOWN_OAK_GREETS_PLAYER    equ 3
SCRIPT_PALLETTOWN_PIKACHU_BATTLE       equ 4
SCRIPT_PALLETTOWN_AFTER_PIKACHU_BATTLE equ 5
SCRIPT_PALLETTOWN_OAK_NOT_SAFE         equ 6
SCRIPT_PALLETTOWN_PLAYER_FOLLOWS_OAK   equ 7
SCRIPT_PALLETTOWN_DAISY                equ 8
SCRIPT_PALLETTOWN_NOOP                 equ 9

; ---------------------------------------------------------------------------
section .data

; pret: PalletTownOakText branches on wOakWalkedToPlayer to pick its line. This
; reference branches on an event flag to demonstrate the event-gated path end to
; end; the full intro variants land with the Oak walk-up cutscene (next milestone).
; "OAK: That was / close!"  (shown once EVENT_GOT_POKEBALLS_FROM_OAK is set)
%include "assets/pallet_runtime_strings.inc"

; "OAK: Hey! Wait! / Don't go out!"  (default — event clear)

; ---------------------------------------------------------------------------
section .text

PalletTownOakText:
    CheckEvent EVENT_GOT_POKEBALLS_FROM_OAK   ; ZF=1 ⇒ flag clear
    jz .default
    mov esi, oak_got_text
    jmp .show
.default:
    mov esi, oak_default_text
.show:
    call ShowTextStream
    ret

; ---------------------------------------------------------------------------
; PalletTown_Script — the map's per-frame _Script (RunMapScript dispatches here
; via MapScriptPointers[PALLET_TOWN]). Faithful skeleton of scripts/PalletTown.asm:
; PalletTown_Script: the event-gate, then CallFunctionInTable on the current-script
; index. The cutscene state routines themselves are deferred (they need scripted
; NPC movement + the Pikachu battle) and recorded as stubs below.
; ---------------------------------------------------------------------------
PalletTown_Script:
    CheckEvent EVENT_GOT_POKEBALLS_FROM_OAK   ; ZF=1 ⇒ flag clear
    jz .next
    SetEvent EVENT_PALLET_AFTER_GETTING_POKEBALLS
.next:
    call EnableAutoTextBoxDrawing              ; faithful: pret calls this before dispatch
    mov al, [ebp + wPalletTownCurScript]
    mov esi, PalletTown_ScriptPointers
    jmp CallFunctionInTable                    ; tail-call: run the current state

; State 0: the default trigger-check. The real script watches for the player
; reaching the north exit, then kicks off the Oak intro cutscene (StopAllMusic /
; PlayMusic / advance to SCRIPT_PALLETTOWN_OAK_HEY_WAIT). That whole trigger +
; cutscene is deferred (needs music + scripted NPC movement), so this is a no-op
; for now; the player can move freely.
; DEVIATION{class=temporary; pret=scripts/PalletTown.asm:PalletTownDefaultScript; behavior=Oak north-exit trigger returns without starting the cutscene; evidence=project_state:PalletTownDefaultScript plus pret source; lifetime=until current_plan_overworld_events Oak walk-up stage}
PalletTownDefaultScript:
    ret

; States 1–8: the Oak walk-up / Pikachu-battle cutscene. Deferred to the movement +
; battle milestone.
; DEVIATION{class=temporary; pret=scripts/PalletTown.asm:PalletTown_ScriptPointers; behavior=Oak cutscene states share a no-op tail; evidence=project_state:PalletTownNoopScript plus pret source; lifetime=until current_plan_overworld_events Oak walk-up stage}
PalletTown_CutsceneStub:
; State 9 (NOOP) and any unimplemented state fall here.
PalletTownNoopScript:
    ret

; ---------------------------------------------------------------------------
section .data
align 4

; Flat dd state table (pret: PalletTown_ScriptPointers, def_script_pointers).
PalletTown_ScriptPointers:
    dd PalletTownDefaultScript      ; SCRIPT_PALLETTOWN_DEFAULT
    dd PalletTown_CutsceneStub      ; SCRIPT_PALLETTOWN_OAK_HEY_WAIT (deferred)
    dd PalletTown_CutsceneStub      ; SCRIPT_PALLETTOWN_OAK_WALKS_TO_PLAYER (deferred)
    dd PalletTown_CutsceneStub      ; SCRIPT_PALLETTOWN_OAK_GREETS_PLAYER (deferred)
    dd PalletTown_CutsceneStub      ; SCRIPT_PALLETTOWN_PIKACHU_BATTLE (deferred)
    dd PalletTown_CutsceneStub      ; SCRIPT_PALLETTOWN_AFTER_PIKACHU_BATTLE (deferred)
    dd PalletTown_CutsceneStub      ; SCRIPT_PALLETTOWN_OAK_NOT_SAFE (deferred)
    dd PalletTown_CutsceneStub      ; SCRIPT_PALLETTOWN_PLAYER_FOLLOWS_OAK (deferred)
    dd PalletTown_CutsceneStub      ; SCRIPT_PALLETTOWN_DAISY (deferred)
    dd PalletTownNoopScript         ; SCRIPT_PALLETTOWN_NOOP
