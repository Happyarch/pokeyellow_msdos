; home_stubs.asm — ret-only stubs for pret home/ routines that must resolve at
; link time but whose real bodies are deferred. Per the stub convention
; (project-conventions skill), the stand-in lives HERE under its exact pret
; label — never as a ret-only body in the file that will eventually hold the
; real routine (src/home/text_script.asm already holds the faithful body; it is
; simply not linkable yet).
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

section .text

; ---------------------------------------------------------------------------
; DisplayTextID — pret home/text_script.asm:DisplayTextID
;
; DEVIATION: integration stub (wild-live promotion, 2026-07-10).
;
; The faithful body is already translated in src/home/text_script.asm, but that
; file is CHECK-only: its link closure is 15 symbols deep and most of it is
; owned by another session. Unresolved, measured by `nm -u` against the linked
; build's defined globals:
;   Joypad                            — not defined anywhere in the port yet
;   _PlayerBlackedOutText,   _PokemartGreetingText,
;   _PokemonFaintedText,     _RepelWoreOffText      — Tier-1 generated strings
;   CableClubNPC, DisplayPokemartDialogue_, DisplayPokemonCenterDialogue_,
;   PrintSafariGameOverText, TalkToPikachu, TextScript_BillsPC,
;   TextScript_GameCornerPrizeMenu, TextScript_ItemStoragePC,
;   TextScript_PokemonCenterPC, VendingMachineMenu
;       — the DisplayTextID special-case dispatch targets, explicitly deferred by
;         docs/current_plan_script_engine.md (that session owns them).
;
; Why a ret is safe TODAY: the only linked caller is TryDoWildEncounter's
; `.lastRepelStep` branch (engine/battle/wild_encounters.asm), reached only when
; wRepelRemainingSteps transitions 1→0. Nothing in the port ever writes
; wRepelRemainingSteps — Repel is an item USE effect, and item-use dispatch
; (UseItem_/ItemUsePtrTable) is deferred items-plan work. So the repel-wore-off
; message is unreachable dead code in every current build; this stub drops a
; message that cannot fire. (The port's NPC dialog does NOT route through
; DisplayTextID — CheckNPCInteraction calls PrintText directly — so overworld
; text is unaffected.)
;
; Contract: pret's DisplayTextID returns nothing and its caller here ignores
; flags (`.lastRepelStep` falls through to `.cantEncounter2`, which sets its own
; ZF via `mov al,1 / or al,al`). A bare ret is therefore flag-safe.
;
; TODO(script_engine): retire by linking src/home/text_script.asm — i.e. port
; Joypad, generate the four text strings, and land the eight special-case
; dispatch targets. Deleting this stub is REQUIRED at that point: two linked
; globals of one name is a link error, so the collision will be loud, not a
; silent shadow. Also un-stub the repel path in wild_encounters.asm's comment.
; ---------------------------------------------------------------------------
global DisplayTextID
DisplayTextID:
    ret
