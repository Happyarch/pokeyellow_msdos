; route_3.asm — hand-translated script layer for Route 3 (pret scripts/Route3.asm).
;
; PILOT wiring of the faithful trainer-header engine (src/home/trainers.asm) into
; a live map. Route 3 is the first map whose _Script drives ExecuteCurMapScriptInTable
; over a generated trainer-header table (Route3TrainerHeaders, from
; assets/trainer_headers.inc via src/data/trainer_headers.asm).
;
; Model: src/scripts/pallet_town.asm (the text_asm/_Script template). As there,
; scripts/ labels are port_only (update_label_db scans only home/ + engine/, so the
; mirror linter never fires on these) — but pret label NAMES are preserved.
;
; ── Two flows, mirroring pret Route3_Script + Route3_ScriptPointers ──────────
;  * SIGHT flow (the pilot's primary driver): RunMapScript dispatches here every
;    overworld frame (MapScriptPointers[ROUTE_3] via gen_map_scripts SCRIPT_OVERRIDES).
;    Route3_Script runs the current sub-script from Route3_ScriptPointers:
;      0 SCRIPT_ROUTE3_DEFAULT      -> CheckFightingMapTrainers  (scans headers; a
;                                      trainer that sees the player engages + walks up)
;      1 SCRIPT_ROUTE3_START_BATTLE -> DisplayEnemyTrainerTextAndStartBattle
;      2 SCRIPT_ROUTE3_END_BATTLE   -> EndTrainerBattle
;  * TALK flow: the map's TextTable routes each trainer's text id to the matching
;    text_asm hook below (Route3Youngster1Text ... Route3CooltrainerF3Text), wired
;    through gen_npc_dialogs SCRIPT_OVERRIDES. Each loads its trainer header and
;    calls TalkToTrainer (pret: `ld hl, Route3TrainerHeaderN / call TalkToTrainer /
;    jp TextScriptEnd`).
;
; LIVE GATE: StartTrainerBattle only SEEDS battle parameters unless the build
; defines TRAINER_BATTLE_LIVE (src/home/trainers.asm) — so this pilot is fully
; linked and its sight/talk flow runs, but the actual battle screen is entered only
; under that gate. See the trainers.asm header.
;
; In: EBP = GB memory base. Fonts/window handled by the caller (RunMapScript for the
; _Script; CheckNPCInteraction for the text_asm hooks — font loaded, player frozen).

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; wRoute3CurScript — pret ram/wram.asm places it 8 bytes past wOaksLabCurScript
; (the wGameProgressFlags base). The port anchors wPalletTownCurScript at 0xD5F0
; (gb_memmap.inc), which is wOaksLabCurScript+1, so wOaksLabCurScript = 0xD5EF and
; wRoute3CurScript = 0xD5EF + 8 = 0xD5F7. (wCurMapScript 0xDA38 is the generic index
; ExecuteCurMapScriptInTable uses internally; this per-map byte is the persistent one.)
wRoute3CurScript equ 0xD5F7

; ── externs ─────────────────────────────────────────────────────────────────
extern EnableAutoTextBoxDrawing              ; src/home/textbox.asm (pret home)
extern ExecuteCurMapScriptInTable            ; src/home/trainers.asm
extern CheckFightingMapTrainers              ; src/home/trainers.asm
extern DisplayEnemyTrainerTextAndStartBattle ; src/home/trainers.asm
extern EndTrainerBattle                      ; src/home/trainers.asm
extern TalkToTrainer                         ; src/home/trainers.asm
extern TextScriptEnd                         ; src/home/overworld_text.asm

; Trainer-header table + per-trainer entry labels (assets/trainer_headers.inc,
; carried by src/data/trainer_headers.asm).
extern Route3TrainerHeaders
extern Route3TrainerHeader0
extern Route3TrainerHeader1
extern Route3TrainerHeader2
extern Route3TrainerHeader3
extern Route3TrainerHeader4
extern Route3TrainerHeader5
extern Route3TrainerHeader6
extern Route3TrainerHeader7

; ── globals ───────────────────────────────────────────────────────────────────
global Route3_Script
global Route3Youngster1Text
global Route3Youngster2Text
global Route3CooltrainerF1Text
global Route3Youngster3Text
global Route3CooltrainerF2Text
global Route3Youngster4Text
global Route3Youngster5Text
global Route3CooltrainerF3Text

section .text

; ---------------------------------------------------------------------------
; Route3_Script — pret scripts/Route3.asm:Route3_Script.
;   call EnableAutoTextBoxDrawing
;   ld hl, Route3TrainerHeaders   -> ESI = flat header base
;   ld de, Route3_ScriptPointers  -> EDI = flat jumptable (port ABI: EDI, not DE —
;                                    see src/home/trainers.asm ExecuteCurMapScriptInTable)
;   ld a, [wRoute3CurScript] / call ExecuteCurMapScriptInTable / ld [wRoute3CurScript], a
; ---------------------------------------------------------------------------
Route3_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route3TrainerHeaders
    mov edi, Route3_ScriptPointers
    mov al, [ebp + wRoute3CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute3CurScript], al
    ret

; ---------------------------------------------------------------------------
; TALK hooks — pret scripts/Route3.asm text_asm entries. Each:
;   ld hl, Route3TrainerHeaderN / call TalkToTrainer / jp TextScriptEnd
; The port dispatch (map_sprites.asm CheckNPCInteraction) does `call edi` and
; expects a return; `jmp TextScriptEnd` (which ends with `ret`) pops that return
; address, so control returns to the dispatcher exactly as after a plain ret.
; ---------------------------------------------------------------------------
Route3Youngster1Text:
    mov esi, Route3TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

Route3Youngster2Text:
    mov esi, Route3TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

Route3CooltrainerF1Text:
    mov esi, Route3TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

Route3Youngster3Text:
    mov esi, Route3TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

Route3CooltrainerF2Text:
    mov esi, Route3TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

Route3Youngster4Text:
    mov esi, Route3TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

Route3Youngster5Text:
    mov esi, Route3TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

Route3CooltrainerF3Text:
    mov esi, Route3TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route3_ScriptPointers — flat dd jumptable (pret def_script_pointers order).
; ---------------------------------------------------------------------------
section .data
align 4
global Route3_ScriptPointers
Route3_ScriptPointers:
    dd CheckFightingMapTrainers               ; SCRIPT_ROUTE3_DEFAULT (0)
    dd DisplayEnemyTrainerTextAndStartBattle  ; SCRIPT_ROUTE3_START_BATTLE (1)
    dd EndTrainerBattle                       ; SCRIPT_ROUTE3_END_BATTLE (2)
