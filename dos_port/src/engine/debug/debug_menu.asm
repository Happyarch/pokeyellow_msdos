; debug_menu.asm — mirror of pret engine/debug/debug_menu.asm.
;
; ===========================================================================
; READ THIS BEFORE TREATING THIS FILE'S 99 `missing` ROWS AS A BACKLOG.
;
; `label_status --subsystem '*'` reports `engine/debug/debug_menu.asm  99 missing`,
; the single largest gap in the tree. **98 of those 99 labels DO NOT EXIST IN THE
; SHIPPED GAME.** pret's file is ONE `IF DEF(_DEBUG) ... ELSE ret ENDC` block
; spanning lines 2-1649: with `_DEBUG` unset — which is retail Yellow, and what this
; port builds — the assembler emits exactly one routine, `DebugMenu`, whose entire
; body is `ret`. That is what is below.
;
; Its only call site is `callfar DebugMenu` at engine/movie/title.asm:204, which is
; ALSO inside an `IF DEF(_DEBUG)` block; the release arm is `jp MainMenu`, and the
; port already takes it (src/engine/movie/title.asm). So the routine is unreachable
; in a release build on both sides, exactly as it should be.
;
; Whether to port the other 98 — the debug menu proper, its TestBattle harness, party
; and item seeding, the map-warp picker — is a SCOPE DECISION, not translation work,
; and it belongs to the maintainer alongside the other entries in
; tools/port_scope_exclusions.json. They are genuinely portable; they are simply not
; part of the game this port is a port of. Measured 2026-08-23; do not silently
; adopt either answer.
; ===========================================================================
;
; Build: nasm -f coff -I include/ -I . -o debug_menu.o debug_menu.asm

bits 32

section .text

; ---------------------------------------------------------------------------
; DebugMenu — pret engine/debug/debug_menu.asm:1. In a release build its body is
; the `ELSE ret` arm of the file-wide `_DEBUG` guard, and nothing reaches it.
; Carried because a dummied-out routine is still what the shipped game contains —
; the same call LoadPresentsGraphic (engine/movie/intro.asm) and
; DebugPressedOrHeldB (home/npc_movement.asm) already make.
;
; EXPECT A LOUD faithdiff ON THIS LABEL, and do not "fix" it: it reports 13 dropped
; calls and 9 dropped stores, because it compares this `ret` against pret's _DEBUG
; body (TextBoxBorder, PlaceString, HandleMenuInput, TestBattle, the menu-state
; stores...). faithdiff has no model of `IF DEF(_DEBUG)`, so it cannot see that the
; release assembler emits none of that. The drop set IS the guard. Nothing here is
; suppressed, because a suppression would hide the same shape on a routine where it
; would be a real defect.
; ---------------------------------------------------------------------------
global DebugMenu
DebugMenu:
    ret
