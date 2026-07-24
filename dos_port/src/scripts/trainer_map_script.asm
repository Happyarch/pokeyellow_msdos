; trainer_map_script.asm — the generic map-script driver (map-script fidelity plan,
; Stage 2). PORT-ONLY: these two routines have no pret counterpart label, because in
; pret they are not routines at all — they are the same handful of instructions
; copy-pasted into every standard trainer map's script file.
;
; pret's "standard trainer map" is a map whose entire script layer is boilerplate:
;
;   <Map>_Script:                             <Map>Youngster1Text:
;       call EnableAutoTextBoxDrawing             text_asm
;       ld hl, <Map>TrainerHeaders                ld hl, <Map>TrainerHeader0
;       ld de, <Map>_ScriptPointers               call TalkToTrainer
;       ld a, [w<Map>CurScript]                   jp TextScriptEnd
;       call ExecuteCurMapScriptInTable
;       ld [w<Map>CurScript], a
;       ret
;
; Seventeen maps are exactly this and nothing more, with one talk hook per trainer
; on top (Route 3 alone had eight). Hand-translating them would mean ~150 lines of
; identical assembly per wave, all of it invisible to faithdiff (scripts/ labels
; carry no call-graph model — see the faithfulness-review skill, "Map scripts"), so
; the port keeps the shape ONCE here and moves the per-map difference into generated
; Tier-1 data: assets/map_script_tables.inc (MapScriptParams + the per-map
; <Map>_ScriptPointers tables) and the trainer-header pointer already carried in the
; map's generated text table.
;
; The instruction sequences below are pret's, unchanged; only the operands that pret
; writes as immediates are loaded from the table. Both routines are ordinary port
; code in a mirrored-by-subsystem file, so lint_pret_labels, dup_def and the golden
; scenarios cover them the way they cover any other routine — which is the whole
; point of collapsing the copies into one place.
;
; In: EBP = GB memory base.
;
; Build: nasm -f coff -I include/ -I . -o trainer_map_script.o trainer_map_script.asm

bits 32

%include "gb_memmap.inc"

; MapScriptParams — assets/map_script_tables.inc, carried by src/data/map_script_tables.asm.
; Entry stride MSP_SIZE = 12: +0 dd <Map>TrainerHeaders, +4 dd <Map>_ScriptPointers,
; +8 dd w<Map>CurScript (a GB WRAM offset, used as [ebp + offset]).
extern MapScriptParams
MSP_HEADERS     equ 0
MSP_POINTERS    equ 4
MSP_CUR_SCRIPT  equ 8

extern EnableAutoTextBoxDrawing              ; src/home/textbox.asm (pret home)
extern ExecuteCurMapScriptInTable            ; src/home/trainers.asm
extern TalkToTrainer                         ; src/home/trainers.asm
extern TextScriptEnd                         ; src/home/overworld_text.asm

section .text

global TrainerMapScript
global TrainerTalkHook

; ---------------------------------------------------------------------------
; TrainerMapScript — the body every standard <Map>_Script shares.
;
; Reached from MapScriptPointers[wCurMap] (gen_map_scripts.py wires the maps in
; gen_map_script_tables.py's WIRED_MAPS list), so the map index IS the parameter:
; wCurMap selects the MapScriptParams row that supplies the three operands pret
; writes as immediates.
;
;   pret                                    here
;   call EnableAutoTextBoxDrawing           same
;   ld hl, <Map>TrainerHeaders              ESI = params[+0]
;   ld de, <Map>_ScriptPointers             EDI = params[+4]   (port ABI: EDI, not
;                                             DX — see ExecuteCurMapScriptInTable)
;   ld a, [w<Map>CurScript]                 AL  = [ebp + params[+8]]
;   call ExecuteCurMapScriptInTable         same
;   ld [w<Map>CurScript], a                 [ebp + params[+8]] = AL
;   ret                                     same
; ---------------------------------------------------------------------------
TrainerMapScript:
    movzx ecx, byte [ebp + wCurMap]
    lea ecx, [ecx + ecx*2]                       ; index * 3 dwords = * MSP_SIZE
    cmp dword [MapScriptParams + ecx*4 + MSP_HEADERS], 0
    je .noScript
    push ecx                                     ; EnableAutoTextBoxDrawing clobbers freely
    call EnableAutoTextBoxDrawing
    pop ecx
    mov esi, [MapScriptParams + ecx*4 + MSP_HEADERS]     ; pret: ld hl, <Map>TrainerHeaders
    mov edi, [MapScriptParams + ecx*4 + MSP_POINTERS]    ; pret: ld de, <Map>_ScriptPointers
    mov ebx, [MapScriptParams + ecx*4 + MSP_CUR_SCRIPT]  ; GB offset of w<Map>CurScript
    push ebx
    mov al, [ebp + ebx]                          ; pret: ld a, [w<Map>CurScript]
    call ExecuteCurMapScriptInTable
    pop ebx
    mov [ebp + ebx], al                          ; pret: ld [w<Map>CurScript], a
    ret
.noScript:
    ; Unreachable in a consistent build: gen_map_scripts.py points a map here only
    ; if gen_map_script_tables.py emitted its parameter block, and the generator
    ; exits if WIRED_MAPS names a map with no standard script. Kept as a hard floor
    ; so a hand-edited table degrades to "this map has no script" rather than
    ; dispatching through a null jumptable.
    ret

; ---------------------------------------------------------------------------
; TrainerTalkHook — the body every standard <Map><Trainer>Text text_asm hook shares.
;
;   pret:  ld hl, <Map>TrainerHeaderN / call TalkToTrainer / jp TextScriptEnd
;
; The header pointer that pret writes as an immediate arrives in ESI, straight from
; the map's generated text-table entry (gen_npc_dialogs emits
; `dd <Map>TrainerHeaderN, TEXT_ENTRY_TRAINER_TALK` for these slots), so the
; (map, text id) -> header mapping stays exactly where pret puts it: in the map's
; own text pointer table.
;
; In: ESI = flat trainer-header pointer.
; Called (not jumped to) by CheckNPCInteraction's `call edi` dispatch; pret's
; `jp TextScriptEnd` ends in TextScriptEnd's own `ret`, which returns to that
; dispatcher exactly as a plain ret would.
; ---------------------------------------------------------------------------
TrainerTalkHook:
    call TalkToTrainer
    jmp TextScriptEnd
