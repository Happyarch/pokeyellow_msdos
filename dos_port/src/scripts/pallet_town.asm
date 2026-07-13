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
oak_got_text:
    db 0x00, 0x8E, 0x80, 0x8A, 0x9C, 0x7F, 0x93, 0xA7, 0xA0, 0xB3, 0x7F, 0xB6, 0xA0, 0xB2, 0x4F, 0xA2
    db 0xAB, 0xAE, 0xB2, 0xA4, 0xE7, 0x57, 0x50
oak_got_text_end:

; "OAK: Hey! Wait! / Don't go out!"  (default — event clear)
oak_default_text:
    db 0x00, 0x8E, 0x80, 0x8A, 0x9C, 0x7F, 0x87, 0xA4, 0xB8, 0xE7, 0x7F, 0x96, 0xA0, 0xA8, 0xB3, 0xE7
    db 0x4F, 0x83, 0xAE, 0xAD, 0xBE, 0x7F, 0xA6, 0xAE, 0x7F, 0xAE, 0xB4, 0xB3, 0xE7, 0x57, 0x50
oak_default_text_end:

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
; for now; the player can move freely. ; STUB(misc): Oak intro trigger.
PalletTownDefaultScript:
    ret

; States 1–8: the Oak walk-up / Pikachu-battle cutscene. Deferred to the movement +
; battle milestone. ; STUB(battle,misc): Oak cutscene + Pikachu battle.
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
