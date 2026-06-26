; run_map_script.asm — RunMapScript + CallFunctionInTable (script engine, Stage 5).
;
; Faithful translation of home/overworld.asm:RunMapScript (the per-frame map-script
; dispatcher) and home/scripting.asm:CallFunctionInTable (the generic jumptable
; dispatch every map _Script uses on its current-script index).
;
; Each overworld frame, RunMapScript runs the current map's _Script. In the flat
; port the dispatch is a flat `dd` MapScriptPointers table indexed by wCurMap
; (gen_map_scripts.py), defaulting to DefaultMapScript (a no-op) for maps without a
; ported script — mirroring WildDataPointers / EvosMovesPointerTable.
;
; Deferred (this is the skeleton; cutscenes land with the movement + battle milestone):
;   - TryPushingBoulder + DoBoulderDustAnimation — no Strength/boulder system yet.
;   - RunNPCMovementScript — scripted NPC movement; the port already calls it at the
;     top of OverworldLoop, so RunMapScript does not duplicate it.
;   - SwitchToMapRomBank — ; TODO-HW: no-op under the flat address model.
;
; Register map: a=AL, hl=ESI, ecx scratch.
;
; Build: nasm -f coff -I include/ -I . -o run_map_script.o run_map_script.asm

bits 32

%include "gb_memmap.inc"

extern MapScriptPointers

section .text

global RunMapScript
global DefaultMapScript
global CallFunctionInTable

RunMapScript:
    movzx ecx, byte [ebp + wCurMap]
    call dword [MapScriptPointers + ecx*4]   ; run this map's _Script (flat ptr)
    ret

; No-op script for maps without a ported _Script (the table default).
DefaultMapScript:
    ret

; CallFunctionInTable — call function index AL in the flat dd jumptable ESI.
; pret's version is a 16-bit table (add a / ld a,[hli] / ld h,[hl]); here the table
; is flat dd, so index ×4 and load a 32-bit pointer. ESI/EDX/EBX preserved.
CallFunctionInTable:
    push esi
    push edx
    push ebx
    movzx ecx, al
    mov esi, [esi + ecx*4]
    call esi
    pop ebx
    pop edx
    pop esi
    ret
