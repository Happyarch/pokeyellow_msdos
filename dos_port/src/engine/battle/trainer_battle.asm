; trainer_battle.asm — trainer battle entry/exit (Wave 8, M8.1).
;
; Faithful translation of pret home/trainers.asm:
;   InitBattleEnemyParameters  home/trainers.asm:233 (seed wCurOpponent/wTrainerNo)
;   StartTrainerBattle         home/trainers.asm:172
;   EndTrainerBattle           home/trainers.asm:184
;
; This closes the audit gap "bespoke CheckTrainerSight/TrainerEncounterFlow detect
; but never battle" (docs/current_plan_home_rectification.md, trainers/trainers2 row).
; The overworld sight layer (map_sprites.asm CheckTrainerSight / TrainerEncounterFlow)
; caches each trainer's class/set into wMapSpriteExtraData and, on a sighting, seeds
; wEngagedTrainerClass/wEngagedTrainerSet and calls StartTrainerBattle here.
;
; SAFETY / LIVE GATE (important): the port's InitBattle (src/engine/battle/init_battle.asm)
; is a WILD-ONLY screen setup — it sets wIsInBattle=1 and reads wEnemyMonSpecies/Level
; from the DEBUG_BATTLE harness; it has NO trainer path (no ReadTrainer, no trainer
; party load, no trainer pic).  So StartTrainerBattle only SEEDS the battle parameters
; by default; the actual `call InitBattle` is compiled only under -D TRAINER_BATTLE_LIVE.
; FOLLOW-UP (M8.2 + battle front-end): give InitBattle/InitOpponent a trainer branch
; (ReadTrainer + trainer party + _LoadTrainerPic, pret engine/battle/init_battle.asm:34+)
; then drop the gate.
;
; Register map: A=AL, EBP=GB memory base; GB WRAM = [EBP + symbol] (gb_memmap.inc).
;
; Build (check): nasm -f coff -I include/ -I . -o trainer_battle.o \
;                     src/engine/battle/trainer_battle.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

; --- constants (pret rgbds sources are not NASM-includable; mirror the values) ---
; constants/trainer_constants.asm:1  DEF OPP_ID_OFFSET EQU 200
%define OPP_ID_OFFSET 200
; constants/ram_constants.asm — wStatusFlags3 bits
%define BIT_TALKED_TO_TRAINER      6
%define BIT_PRINT_END_BATTLE_TEXT  7
; constants/ram_constants.asm — wStatusFlags4 bit
%define BIT_UNKNOWN_4_1            1
; constants/ram_constants.asm — wCurrentMapScriptFlags bits
%define BIT_CUR_MAP_LOADED_1      5
%define BIT_CUR_MAP_LOADED_2      6

section .text

global InitBattleEnemyParameters
global StartTrainerBattle
global EndTrainerBattle
%ifdef TRAINER_BATTLE_LIVE
extern InitBattle                       ; src/engine/battle/init_battle.asm (wild-only setup)
%endif

; ---------------------------------------------------------------------------
; InitBattleEnemyParameters — set opponent type + mon set/level from the engaging
; trainer data.  Pret ref: home/trainers.asm:233.
;
; In:  wEngagedTrainerClass = OPP_* value (trainer) or a wild species id (< OPP_ID_OFFSET)
;      wEngagedTrainerSet   = trainer party set index (trainer) or level (wild)
; Out: wCurOpponent   = engaged class/species
;      wTrainerNo     = trainer party set   (trainer path)
;      wTrainerClass  = class = wCurOpponent - OPP_ID_OFFSET   (see DIVERGENCE below)
;      wCurEnemyLevel = level               (wild/noTrainer path)
; ---------------------------------------------------------------------------
InitBattleEnemyParameters:
    mov al, [ebp + wEngagedTrainerClass]   ; ld a, [wEngagedTrainerClass]
    mov [ebp + wCurOpponent], al           ; ld [wCurOpponent], a
    ; pret also: ld [wEnemyMonOrTrainerClass], a — wEnemyMonOrTrainerClass has no
    ; port memmap alias yet; TODO(M8.2/battle): add it and mirror the write here.
    cmp al, OPP_ID_OFFSET                   ; cp OPP_ID_OFFSET  (carry => class < 200 = wild)
    mov al, [ebp + wEngagedTrainerSet]     ; ld a, [wEngagedTrainerSet] (flags preserved)
    jb .noTrainer                           ; jr c, .noTrainer
    mov [ebp + wTrainerNo], al             ; ld [wTrainerNo], a
    ; DIVERGENCE(M8.1): pret sets wTrainerClass later, inside InitBattle/InitOpponent
    ; (engine/battle/init_battle.asm:34-36  `sub OPP_ID_OFFSET; ld [wTrainerClass],a`).
    ; The port's InitBattle is wild-only and never runs that, so seed wTrainerClass
    ; here (M8.1 task explicitly seeds wCurOpponent/wTrainerClass/wTrainerNo) so
    ; trainer_ai.asm / read_trainer_party.asm see a valid class.  When InitOpponent
    ; gains its trainer branch this store becomes redundant (harmless).
    mov al, [ebp + wCurOpponent]
    sub al, OPP_ID_OFFSET
    mov [ebp + wTrainerClass], al
    ret
.noTrainer:
    mov [ebp + wCurEnemyLevel], al         ; ld [wCurEnemyLevel], a
    ret

; ---------------------------------------------------------------------------
; StartTrainerBattle — enter a trainer battle.  Pret ref: home/trainers.asm:172.
; Seeds enemy params, marks the trainer-battle status bits, then (gated) enters
; the battle screen.  See the SAFETY / LIVE GATE note at the top of this file.
; ---------------------------------------------------------------------------
StartTrainerBattle:
    mov byte [ebp + W_JOY_IGNORE], 0        ; xor a; ld [wJoyIgnore], a
    call InitBattleEnemyParameters
    ; ld hl, wStatusFlags3 / set BIT_TALKED_TO_TRAINER / set BIT_PRINT_END_BATTLE_TEXT
    or byte [ebp + W_STATUS_FLAGS_3], (1 << BIT_TALKED_TO_TRAINER) | (1 << BIT_PRINT_END_BATTLE_TEXT)
    ; ld hl, wStatusFlags4 / set BIT_UNKNOWN_4_1
    or byte [ebp + W_STATUS_FLAGS_4], (1 << BIT_UNKNOWN_4_1)
    ; pret: ld hl, wCurMapScript / inc [hl]  — advance the map-script index so the next
    ; script fn is EndTrainerBattle.  wCurMapScript (the index) has no port memmap alias
    ; yet; the port's script dispatch is M8.2.  TODO(M8.2): inc the ported wCurMapScript.
%ifdef TRAINER_BATTLE_LIVE
    call InitBattle                         ; port InitBattle = wild-only screen setup (see gate note)
    mov byte [ebp + wIsInBattle], 2         ; trainer battle (pret InitBattle sets this; port sets 1)
%endif
    ret

; ---------------------------------------------------------------------------
; EndTrainerBattle — exit a trainer battle.  Pret ref: home/trainers.asm:184.
; M8.1 keeps the port-representable status bookkeeping; the trainer-flag persistence
; (TrainerFlagAction), sprite removal (HideObject) and full map-script reset are the
; trainer-header engine's job — deferred to M8.2.
; ---------------------------------------------------------------------------
EndTrainerBattle:
    ; ld hl, wCurrentMapScriptFlags / set BIT_CUR_MAP_LOADED_1 / set BIT_CUR_MAP_LOADED_2
    or byte [ebp + W_CURRENT_MAP_SCRIPT_FLAGS], (1 << BIT_CUR_MAP_LOADED_1) | (1 << BIT_CUR_MAP_LOADED_2)
    ; ld hl, wStatusFlags3 / res BIT_PRINT_END_BATTLE_TEXT
    and byte [ebp + W_STATUS_FLAGS_3], (~(1 << BIT_PRINT_END_BATTLE_TEXT)) & 0xFF
    ; pret: res BIT_SEEN_BY_TRAINER, [wMiscFlags]  — wMiscFlags has no port memmap
    ; alias yet; TODO(M8.2): clear it so the player is no longer engaged.
    ; pret then, for a fought trainer: ReadTrainerHeaderInfo + TrainerFlagAction
    ; (persistent beaten flag) + HideObject + ResetButtonPressedAndMapScript — all
    ; M8.2 (trainer-header engine).  M8.1 uses map_sprites.asm's npc_beaten_flags as
    ; the (per-map, non-persistent) beaten proxy; TrainerFlagAction replaces it in M8.2.
    ret
