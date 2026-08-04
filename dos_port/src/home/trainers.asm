; trainers.asm — the trainer-header engine, at the pret mirror of
; home/trainers.asm. FULL MIRROR as of the M8.2 promotion (2026-07-24): every
; pret home/trainers.asm label lives here, in pret's in-file order (the three
; M8.1 labels StartTrainerBattle/EndTrainerBattle/InitBattleEnemyParameters were
; already here; the remainder came home from the dissolved check-only
; engine/overworld/trainer_engine.asm bundle, whose registered relocations are
; retired). The EmotionBubble family moved to its own pret mirror,
; src/engine/overworld/emotion_bubbles.asm (linked).
;
; Pret in-file fallthroughs, all realized as real adjacency below:
;   * DisplayEnemyTrainerTextAndStartBattle -> StartTrainerBattle
;   * EndTrainerBattle -> ResetButtonPressedAndMapScript (conditional ret nz seam)
;   * SetSpritePosition2 -> SpritePositionBankswitch — NOT preserved: under the
;     flat model pret's shared bank tail collapses into four direct jmps to the
;     _-prefixed bodies (see the Get/SetSpritePosition block below).
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH, C->BL, D->DH, E->DL.
; RAM is EBP-relative: emulated GB byte X is [ebp + X].  Tier-1 asset data
; (trainer headers, text) are FLAT 32-bit host pointers (like MapScriptPointers,
; w_map_text_table_ptr) — read as [flat_ptr] WITHOUT ebp.
;
; ----------------------------------------------------------------------------
; FLAT-POINTER MODEL (the load-bearing adaptation — read this).
; ----------------------------------------------------------------------------
; pret trainer headers live in banked ROM addressed by 16-bit GB pointers, and
; wTrainerHeaderPtr is a 2-byte GB address.  The port addresses all overworld asset
; data with FLAT 32-bit host pointers.  So this engine stores the header pointer as a
; FLAT dword in `w_trainer_header_ptr` (BSS), NOT in emulated wTrainerHeaderPtr.  This
; supersedes pret's wTrainerHeaderPtr — matching the port precedent w_map_text_table_ptr
; (map_sprites.asm) which is likewise a flat .bss dword, not emulated WRAM.
;
; The generated (Tier-1) trainer-header blob a future `tools/generators/gen_trainer_headers.py`
; must emit has this FLAT per-entry layout (stride TH_SIZE=22, replacing pret's $c):
;   +0  db   flag_bit            (0..7 within its wEventFlags byte)
;   +1  db   view_range << 4     (pret packs it shifted; kept verbatim)
;   +2  dd   flag_ptr            GB WRAM OFFSET into wEventFlags  (used by FlagAction,
;                                which does [ebp+ESI]; so this is an emulated offset,
;                                NOT a flat pointer)
;   +6  dd   before_battle_text  FLAT text ptr
;   +10 dd   after_battle_text   FLAT text ptr
;   +14 dd   end_battle_win_text FLAT text ptr   (pret \4)
;   +18 dd   end_battle_lose_text FLAT text ptr  (pret \4 again — same value in Gen1)
; A per-map table `dd`-indexes these; the map's _Script passes its header table's flat
; base to StoreTrainerHeaderPointer (exactly as pret map scripts pass `hl, Headers`).
;
; ReadTrainerHeaderInfo keeps pret's caller ABI (selector 0/2/4/6/8/$a) and maps each
; selector to the flat field above, so every caller in this file is byte-faithful.
;
; ----------------------------------------------------------------------------
; npc_beaten_flags -> TrainerFlagAction CONVERGENCE.
; ----------------------------------------------------------------------------
; The bespoke port keeps trainers-beaten state in map_sprites.asm's `npc_beaten_flags`
; (a 16-bit BSS reset every InitMapSprites => NON-persistent: trainers un-beat on every
; map reload).  This engine's persistent `TrainerFlagAction` is the faithful replacement:
; it drives the home global `FlagAction` against the header's flag_ptr => wEventFlags
; (persistent across warps).  ROOT FOLLOW-UP: once trainer-header DATA exists, delete
; npc_beaten_flags and route map_sprites.asm's CheckTrainerSight / TrainerEncounterFlow
; beaten-gate through TrainerFlagAction(FLAG_TEST/FLAG_SET).
;
; LIVE GATE: InitBattle now has a measured trainer-data path (class metadata,
; ReadTrainer roster, production trainer picture, first active mon and AI state),
; but the complete win/loss/return contract is not yet golden-proven. Therefore
; StartTrainerBattle keeps the TRAINER_BATTLE_LIVE handoff until Stage 1b/1c;
; DEBUG_TRAINER_INIT enables it only for the deterministic initialization gate.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null src/home/trainers.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "assets/audio_constants.inc" ; MUSIC_MEET_* ids (generated, Tier-1)

; ----------------------------------------------------------------------------
; Flat trainer-header struct offsets (Tier-1 layout described above)
; ----------------------------------------------------------------------------
TH_FLAG_BIT    equ 0
TH_VIEW_RANGE  equ 1
TH_FLAG_PTR    equ 2      ; dd, GB WRAM offset
TH_BEFORE_TXT  equ 6      ; dd, flat
TH_AFTER_TXT   equ 10     ; dd, flat
TH_END_WIN     equ 14     ; dd, flat
TH_END_LOSE    equ 18     ; dd, flat
TH_SIZE        equ 22

; ----------------------------------------------------------------------------
; Externs
; ----------------------------------------------------------------------------
extern FlagAction               ; src/engine/flag_action.asm (persistent flag array)
extern CallFunctionInTable      ; src/home/array2.asm
extern CopyData                 ; src/home/copy.asm
extern PrintText                ; src/home/window.asm
extern PlaySound                ; src/home/audio.asm (real gateway)
extern StopAllMusic             ; src/home/audio.asm (real gateway)
extern WaitForSoundToFinish     ; src/home/delay.asm (real gateway)
extern DisplayTextID            ; src/home/text_script.asm — pret: home/text_script.asm
extern EmotionBubble            ; src/engine/overworld/emotion_bubbles.asm (pret: predef)
extern TrainerWalkUpToPlayer    ; src/engine/overworld/trainer_sight.asm
extern map_sprite_extra_data    ; src/engine/overworld/map_sprites.asm — flat alias of
                                ; wMapSpriteExtraData (see EngageMapTrainer's note)
extern TrainerEngage            ; src/engine/overworld/trainer_sight.asm
extern _GetSpritePosition1      ; src/engine/overworld/trainer_sight.asm
extern _GetSpritePosition2      ; src/engine/overworld/trainer_sight.asm
extern _SetSpritePosition1      ; src/engine/overworld/trainer_sight.asm
extern _SetSpritePosition2      ; src/engine/overworld/trainer_sight.asm
extern SaveTrainerName          ; src/engine/battle/battle_stubs.asm — STUB (pret engine/battle/save_trainer_name.asm)
extern SetEnemyTrainerToStayAndFaceAnyDirection ; src/engine/overworld/npc_movement_2.asm
extern TextCommandProcessor     ; src/home/text.asm
extern TextScriptEnd            ; src/home/overworld_text.asm
extern HideObject               ; src/engine/overworld/toggleable_objects.asm
extern IsInArray                ; src/home/array2.asm (flat [ESI] reads; pass lea esi,[ebp+..] for WRAM)
extern msgbox_dialog            ; src/home/text.asm — overworld dialog projection
extern text_msgbox              ; src/home/text.asm — active msgbox projection (msgbox.inc)
%ifdef TRAINER_BATTLE_LIVE
extern InitBattle               ; src/engine/battle/init_battle.asm (wild/trainer dispatcher)
%endif

; ----------------------------------------------------------------------------
; Globals (pret home/trainers.asm labels, in pret order)
; ----------------------------------------------------------------------------
global StoreTrainerHeaderPointer
global ExecuteCurMapScriptInTable
global LoadGymLeaderAndCityName
global ReadTrainerHeaderInfo
global TrainerFlagAction
global TalkToTrainer
global CheckFightingMapTrainers
global DisplayEnemyTrainerTextAndStartBattle
global StartTrainerBattle
global EndTrainerBattle
global ResetButtonPressedAndMapScript
global TrainerWalkUpToPlayer_Bank0
global InitBattleEnemyParameters
global GetSpritePosition1
global GetSpritePosition2
global SetSpritePosition1
global SetSpritePosition2
global CheckForEngagingTrainers
global SaveEndBattleTextPointers
global EngageMapTrainer
global PrintEndBattleText
global GetSavedEndBattleTextPointer
global PlayTrainerMusic
global w_trainer_header_ptr

; ============================================================================
section .bss
; Flat header pointer (supersedes pret's emulated wTrainerHeaderPtr — see header note).
w_trainer_header_ptr:  resd 1
; CheckForEngagingTrainers scans with a flat header cursor; b/c are consumed by
; FlagAction, so the cursor can't live in EBX. Keep it here.
cef_header_cursor:     resd 1

; ============================================================================
section .text

; ----------------------------------------------------------------------------
; StoreTrainerHeaderPointer — [w_trainer_header_ptr] = ESI (flat header base)
; pret: home/trainers.asm:StoreTrainerHeaderPointer (stores hl in wTrainerHeaderPtr)
; In: ESI = flat header base.  All else preserved.
; ----------------------------------------------------------------------------
StoreTrainerHeaderPointer:
    mov [w_trainer_header_ptr], esi
    ret

; ----------------------------------------------------------------------------
; ExecuteCurMapScriptInTable — run the current map sub-script from a jumptable.
; pret: home/trainers.asm:ExecuteCurMapScriptInTable
; In:  AL  = map-script index (unless overridden by wStatusFlags7 BIT_USE_CUR_MAP_SCRIPT)
;      ESI = flat trainer-header base (stored for the map's trainers)
;      EDI = flat function-pointer jumptable (pret's `de`)
; Out: AL  = wCurMapScript after dispatch
; ----------------------------------------------------------------------------
ExecuteCurMapScriptInTable:
    push eax                        ; save script index
    call StoreTrainerHeaderPointer  ; [w_trainer_header_ptr] = ESI
    ; test-and-reset BIT_USE_CUR_MAP_SCRIPT (capture bit before clearing it)
    mov cl, [ebp + wStatusFlags7]
    and byte [ebp + wStatusFlags7], ~(1 << BIT_USE_CUR_MAP_SCRIPT)
    pop eax
    test cl, (1 << BIT_USE_CUR_MAP_SCRIPT)
    jz .useProvidedIndex            ; not overridden: use caller's index
    mov al, [ebp + wCurMapScript]   ; overridden: use the stored current index
.useProvidedIndex:
    mov [ebp + wCurMapScript], al
    mov esi, edi                    ; ESI = flat jumptable for CallFunctionInTable
    call CallFunctionInTable        ; calls table[AL] (flat dd)
    mov al, [ebp + wCurMapScript]
    ret

; ----------------------------------------------------------------------------
; LoadGymLeaderAndCityName — copy gym city + leader names.
; pret: home/trainers.asm:LoadGymLeaderAndCityName
; In (pret ABI, register-mapped): ESI (hl) = city-name source GB offset,
;                                 EDX (de) = leader-name source GB offset.
; CopyData is src(ESI)->dst(EDX), BX=count; dst must be a GB OFFSET in DX
; (CopyData does movzx edi,dx / lea edi,[ebp+edi]), NOT an [ebp+..] lea.
; OW-A.9 fix: two ABI bugs corrected — (1) dst was in EDI (CopyData ignores EDI,
; reads dst from DX) → wrote to garbage; (2) the entry `push esi/pop esi` restored
; the CITY src as the leader src (would copy the city name into wGymLeaderName).
; Now push edx/pop esi, matching pret's push de / pop hl (leader src arrives in DE).
; ----------------------------------------------------------------------------
LoadGymLeaderAndCityName:
    ; --- city name: src ESI, dst wGymCityName, len GYM_CITY_LENGTH ---
    push edx                        ; pret: push de — save leader-name src
    mov edx, wGymCityName           ; dst GB offset (DX), pret: ld de, wGymCityName
    mov ebx, GYM_CITY_LENGTH        ; count (BX)
    call CopyData                   ; [ebp+ESI] -> [ebp+wGymCityName]
    ; --- leader name: src ESI = leader src, dst wGymLeaderName, len NAME_LENGTH ---
    pop esi                         ; pret: pop hl — ESI = leader-name src
    mov edx, wGymLeaderName         ; dst GB offset (DX)
    mov ebx, NAME_LENGTH
    call CopyData                   ; [ebp+ESI] -> [ebp+wGymLeaderName]
    ret

; ----------------------------------------------------------------------------
; ReadTrainerHeaderInfo — read a field from the current trainer header.
; pret: home/trainers.asm:ReadTrainerHeaderInfo.  Selector ABI preserved.
; In:  AL = selector: 0->flag bit, 2->flag ptr, 4->before, 6->after, 8->end-win, $a->end-lose
; Out: sel 0 : wTrainerHeaderFlagBit = flag_bit ; ESI = flat header base
;      sel 2 : ESI = flag_ptr (GB WRAM offset)
;      sel 4/6/8 : ESI = flat text ptr
;      sel $a : EDX = flat text ptr (pret's `de`)
; Preserves EDX except on sel $a (by design).  Clobbers AL (pret restores; callers reload).
; ----------------------------------------------------------------------------
ReadTrainerHeaderInfo:
    push edi
    movzx eax, al
    mov edi, [w_trainer_header_ptr] ; flat header base
    test al, al
    jnz .nonZero
    ; sel 0
    mov cl, [edi + TH_FLAG_BIT]     ; FLAT read
    mov [ebp + wTrainerHeaderFlagBit], cl
    mov esi, edi                    ; return base in ESI (CheckForEngagingTrainers needs it)
    pop edi
    ret
.nonZero:
    cmp al, 2
    je .pFlag
    cmp al, 4
    je .pBefore
    cmp al, 6
    je .pAfter
    cmp al, 8
    je .pEndWin
    cmp al, 0x0a
    je .pEndLose
    pop edi                         ; other selectors: no-op (pret .done)
    ret
.pFlag:
    mov esi, [edi + TH_FLAG_PTR]
    pop edi
    ret
.pBefore:
    mov esi, [edi + TH_BEFORE_TXT]
    pop edi
    ret
.pAfter:
    mov esi, [edi + TH_AFTER_TXT]
    pop edi
    ret
.pEndWin:
    mov esi, [edi + TH_END_WIN]
    pop edi
    ret
.pEndLose:
    mov edx, [edi + TH_END_LOSE]    ; into "de"
    pop edi
    ret

; ----------------------------------------------------------------------------
; TrainerFlagAction — persistent trainer-beaten flag op (FLAG_TEST/SET/RESET).
; pret: home/trainers.asm:TrainerFlagAction  (predef_jump FlagActionPredef)
; The port calls the FlagAction leaf directly (regs set by hand) — same faithful
; equivalent used elsewhere (see the DEVIATION on engine/menus/pokedex.asm:IsPokemonBitSet).
; This is the PERSISTENT
; replacement for map_sprites.asm's non-persistent npc_beaten_flags (see header).
; In:  ESI = flag array base (GB WRAM offset, e.g. wEventFlags+N), CL = bit, BH = action.
; Out: CL = result (FLAG_TEST).
; ----------------------------------------------------------------------------
TrainerFlagAction:
    jmp FlagAction

; ----------------------------------------------------------------------------
; TalkToTrainer — player talks to (or is engaged by) a trainer.
; pret: home/trainers.asm:TalkToTrainer
; In: ESI = flat trainer header base.
; ----------------------------------------------------------------------------
TalkToTrainer:
    call StoreTrainerHeaderPointer  ; [ptr] = ESI
    xor eax, eax
    call ReadTrainerHeaderInfo      ; sel 0: flag bit -> wTrainerHeaderFlagBit
    mov al, 2
    call ReadTrainerHeaderInfo      ; sel 2: ESI = flag_ptr
    mov cl, [ebp + wTrainerHeaderFlagBit]
    mov bh, FLAG_TEST
    call TrainerFlagAction          ; CL = beaten bit (ESI = flag_ptr from sel 2)
    test cl, cl
    jz .trainerNotYetFought
    ; already fought -> print after-battle text
    mov al, 6
    call ReadTrainerHeaderInfo      ; sel 6: ESI = after-battle text (flat)
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    jmp PrintText
.trainerNotYetFought:
    mov al, 4
    call ReadTrainerHeaderInfo      ; sel 4: ESI = before-battle text (flat)
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    call PrintText
    mov al, 0x0a
    call ReadTrainerHeaderInfo      ; sel $a: EDX = end-lose text
    push edx                        ; pret: push de
    mov al, 8
    call ReadTrainerHeaderInfo      ; sel 8: ESI = end-win text (hl)
    pop edx                         ; pret: pop de (lose)
    call SaveEndBattleTextPointers  ; hl=ESI(win), de=EDX(lose)
    or byte [ebp + wStatusFlags7], (1 << BIT_USE_CUR_MAP_SCRIPT) ; arm map-script override
    ; if already engaged (trainer saw the player) return; the sight flow drives battle.
    test byte [ebp + wMiscFlags], (1 << BIT_SEEN_BY_TRAINER)
    jnz .done
    ; player talked of his own volition:
    call EngageMapTrainer
    inc byte [ebp + wCurMapScript]  ; pret: inc [hl] — next script fn = EndTrainerBattle
    jmp StartTrainerBattle          ; pret: jp StartTrainerBattle
.done:
    ret

; ----------------------------------------------------------------------------
; CheckFightingMapTrainers — any trainer seeing the player and wanting to fight?
; pret: home/trainers.asm:CheckFightingMapTrainers (_DEBUG B-skip omitted — no _DEBUG)
; This is the faithful, persistent replacement for map_sprites.asm's bespoke
; CheckTrainerSight (root rewires OverworldLoop's sight hook here later).
; ----------------------------------------------------------------------------
CheckFightingMapTrainers:
    call CheckForEngagingTrainers
    mov al, [ebp + wSpriteIndex]
    cmp al, 0xff
    jne .trainerEngaging
    ; none engaging: clear state
    xor al, al
    mov [ebp + wSpriteIndex], al
    mov [ebp + wTrainerHeaderFlagBit], al
    ret
.trainerEngaging:
    or byte [ebp + wStatusFlags7], (1 << BIT_TRAINER_BATTLE)
    mov [ebp + wEmotionBubbleSpriteIndex], al    ; a = engaging sprite index
    xor al, al                                   ; EXCLAMATION_BUBBLE (0)
    mov [ebp + wWhichEmotionBubble], al
    call EmotionBubble                           ; pret: predef EmotionBubble
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    xor al, al
    mov [ebp + hJoyHeld], al
    call TrainerWalkUpToPlayer_Bank0
    inc byte [ebp + wCurMapScript]  ; next = DisplayEnemyTrainerTextAndStartBattle
    ret

; ----------------------------------------------------------------------------
; DisplayEnemyTrainerTextAndStartBattle — after the trainer has walked up.
; pret: home/trainers.asm:DisplayEnemyTrainerTextAndStartBattle
; Falls through into StartTrainerBattle, exactly as pret does (the M8.1-era
; cross-file `jmp StartTrainerBattle` is retired — real adjacency restored).
; ----------------------------------------------------------------------------
DisplayEnemyTrainerTextAndStartBattle:
    mov al, [ebp + wStatusFlags5]
    and al, (1 << BIT_SCRIPTED_NPC_MOVEMENT)
    jz .doneWalking
    ret                             ; trainer still walking to the player
.doneWalking:
    mov [ebp + wJoyIgnore], al      ; a = 0 here
    mov al, [ebp + wSpriteIndex]
    mov [ebp + hSpriteIndex], al
    call DisplayTextID
    ; fall through (pret: fall through)

; ---------------------------------------------------------------------------
; StartTrainerBattle — enter a trainer battle.  Pret ref: home/trainers.asm:172.
; Seeds enemy params, marks the trainer-battle status bits, then (gated) enters
; the trainer-aware battle dispatcher. See the LIVE GATE note above.
; ---------------------------------------------------------------------------
StartTrainerBattle:
    mov byte [ebp + W_JOY_IGNORE], 0        ; xor a; ld [wJoyIgnore], a
    call InitBattleEnemyParameters
    ; ld hl, wStatusFlags3 / set BIT_TALKED_TO_TRAINER / set BIT_PRINT_END_BATTLE_TEXT
    or byte [ebp + W_STATUS_FLAGS_3], (1 << BIT_TALKED_TO_TRAINER) | (1 << BIT_PRINT_END_BATTLE_TEXT)
    ; ld hl, wStatusFlags4 / set BIT_UNKNOWN_4_1
    or byte [ebp + W_STATUS_FLAGS_4], (1 << BIT_UNKNOWN_4_1)
    ; pret: ld hl, wCurMapScript / inc [hl] — next script fn is usually EndTrainerBattle.
    ; (M8.2: restored — wCurMapScript is golden-resolved to 0xDA38; the old M8.1 TODO
    ; predated the symbol. Nothing in the live build starts a trainer battle yet.)
    inc byte [ebp + wCurMapScript]
%ifdef TRAINER_BATTLE_LIVE
    call InitBattle
%endif
    ret

; ---------------------------------------------------------------------------
; EndTrainerBattle — exit a trainer battle.  Pret ref: home/trainers.asm:185.
; M8.2: full pret tail restored (was an M8.1 partial that ret'd after the status
; bookkeeping): battle-lost early exit, persistent beaten-flag set, conditional
; sprite removal, BIT_UNKNOWN_5_4 gate, and the pret fall-through into
; ResetButtonPressedAndMapScript.
; ---------------------------------------------------------------------------
EndTrainerBattle:
    ; ld hl, wCurrentMapScriptFlags / set BIT_CUR_MAP_LOADED_1 / set BIT_CUR_MAP_LOADED_2
    or byte [ebp + W_CURRENT_MAP_SCRIPT_FLAGS], (1 << BIT_CUR_MAP_LOADED_1) | (1 << BIT_CUR_MAP_LOADED_2)
    ; ld hl, wStatusFlags3 / res BIT_PRINT_END_BATTLE_TEXT
    and byte [ebp + W_STATUS_FLAGS_3], (~(1 << BIT_PRINT_END_BATTLE_TEXT)) & 0xFF
    ; ld hl, wMiscFlags / res BIT_SEEN_BY_TRAINER — player is no longer engaged
    and byte [ebp + wMiscFlags], (~(1 << BIT_SEEN_BY_TRAINER)) & 0xFF
    ; battle lost (wIsInBattle == $ff): skip the beaten-flag/sprite work entirely
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz ResetButtonPressedAndMapScript       ; pret: jp z
    ; DEVIATION{class=temporary; pret=home/trainers.asm:EndTrainerBattle; behavior=skip the beaten-flag set and sprite removal when no trainer header was ever stored; evidence=the bespoke map_sprites.asm TrainerEncounterFlow (TRAINER_BATTLE_LIVE) reaches EndTrainerBattle without calling StoreTrainerHeaderPointer so ReadTrainerHeaderInfo would dereference a null flat base and FlagAction would write at a garbage EBP offset, while pret map scripts guarantee wTrainerHeaderPtr is valid here; lifetime=until gen_trainer_headers lands and the map-script trainer flow replaces TrainerEncounterFlow}
    cmp dword [w_trainer_header_ptr], 0
    je .skipRemoveSprite
    ; flag the trainer as fought (persistent wEventFlags bit via the header)
    mov al, 2
    call ReadTrainerHeaderInfo              ; sel 2: ESI = flag_ptr (GB WRAM offset)
    mov cl, [ebp + wTrainerHeaderFlagBit]
    mov bh, FLAG_SET
    call TrainerFlagAction
    mov al, [ebp + wEnemyMonOrTrainerClass]
    cmp al, OPP_ID_OFFSET
    jae .skipRemoveSprite                   ; pret: jr nc — a real trainer stays on the map
    ; A non-trainer opponent fought through the trainer flow: remove its sprite.
    ; DEVIATION{class=data-model; pret=home/trainers.asm:EndTrainerBattle; behavior=skip the wToggleableObjectList search plus HideObject when the list is empty; evidence=the port never populates wToggleableObjectList (toggleable_objects.asm precomputes global indices into toggle_list data, see its header divergence) so pret's IsInArray over it would scan unterminated zero-filled WRAM; lifetime=until the wToggleableObjectList build (pret MarkTownVisitedAndLoadToggleableObjects list tail) is ported}
    cmp byte [ebp + wToggleableObjectList], 0
    je .skipRemoveSprite                    ; list never built in the port — see DEVIATION
    lea esi, [ebp + wToggleableObjectList]  ; pret: ld hl, wToggleableObjectList (flat view of WRAM)
    mov edx, 2                              ; pret: ld de, $2 (entry stride)
    mov al, [ebp + wSpriteIndex]
    call IsInArray                          ; search for sprite ID; ESI = match on CF=1
    inc esi                                 ; pret: inc hl
    mov al, [esi]                           ; paired toggleable object index (flat read)
    mov [ebp + wToggleableObjectIndex], al
    call HideObject                         ; pret: predef HideObject (port: direct call)
.skipRemoveSprite:
    ; pret: bit BIT_UNKNOWN_5_4, [wStatusFlags5] / res / ret nz — SM83 res preserves
    ; flags, x86 `and` does not: capture the bit first, clear, then test the capture.
    mov cl, [ebp + wStatusFlags5]
    and byte [ebp + wStatusFlags5], (~(1 << BIT_UNKNOWN_5_4)) & 0xFF
    test cl, (1 << BIT_UNKNOWN_5_4)
    jnz .bitWasSet                          ; pret: ret nz
    ; fall through (pret: fall through on the ret nz seam)

; ----------------------------------------------------------------------------
; ResetButtonPressedAndMapScript — clear joypad state + reset the map script.
; pret: home/trainers.asm:ResetButtonPressedAndMapScript (EndTrainerBattle's
; conditional fall-through target; also reached by its `jp z` battle-lost exit).
; ----------------------------------------------------------------------------
ResetButtonPressedAndMapScript:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + hJoyHeld], al
    mov [ebp + H_JOY_PRESSED], al           ; pret: ldh [hJoyPressed], a
    mov [ebp + H_JOY_RELEASED], al          ; pret: ldh [hJoyReleased], a
    mov [ebp + wCurMapScript], al           ; reset battle status
    ret
EndTrainerBattle.bitWasSet:                 ; pret's ret nz exit
    ret

; ----------------------------------------------------------------------------
; TrainerWalkUpToPlayer_Bank0 — pret farjp TrainerWalkUpToPlayer (flat: direct jmp).
; pret: home/trainers.asm:TrainerWalkUpToPlayer_Bank0
; ----------------------------------------------------------------------------
TrainerWalkUpToPlayer_Bank0:
    jmp TrainerWalkUpToPlayer

; ---------------------------------------------------------------------------
; InitBattleEnemyParameters — set opponent type + mon set/level from the engaging
; trainer data.  Pret ref: home/trainers.asm:233.
;
; In:  wEngagedTrainerClass = OPP_* value (trainer) or a wild species id (< OPP_ID_OFFSET)
;      wEngagedTrainerSet   = trainer party set index (trainer) or level (wild)
; Out: wCurOpponent   = engaged class/species
;      wEnemyMonOrTrainerClass = same (pret's separate copy — survives wCurOpponent clears)
;      wTrainerNo     = trainer party set   (trainer path)
;      wTrainerClass  = class = wCurOpponent - OPP_ID_OFFSET   (see DIVERGENCE below)
;      wCurEnemyLevel = level               (wild/noTrainer path)
; ---------------------------------------------------------------------------
InitBattleEnemyParameters:
    mov al, [ebp + wEngagedTrainerClass]   ; ld a, [wEngagedTrainerClass]
    mov [ebp + wCurOpponent], al           ; ld [wCurOpponent], a
    ; M8.2: restored — wEnemyMonOrTrainerClass is golden-resolved to 0xD712 (the old
    ; M8.1 TODO predated the symbol; EndTrainerBattle reads it back after battle).
    mov [ebp + wEnemyMonOrTrainerClass], al ; ld [wEnemyMonOrTrainerClass], a
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

; ============================================================================
; Get/SetSpritePosition1/2 — pret bank-wrapper trampolines (home/trainers.asm:246-262)
; around the byte-verified _Get/_SetSpritePosition1/2 bodies, which live at their
; pret mirror src/engine/overworld/trainer_sight.asm. pret loads the target into
; hl then shares `SpritePositionBankswitch: ld b, BANK("Trainer Sight") / jp
; Bankswitch`; under the port's flat model banking is a no-op, so pret's shared
; bank tail COLLAPSES into these four direct tail-jumps (SetSpritePosition2's
; fallthrough into SpritePositionBankswitch is realized by its own jmp).
; Called by scripts/OaksLab.asm (Oak cutscene, not yet ported) — provided so the
; pret labels resolve.
; ============================================================================
GetSpritePosition1:
    jmp _GetSpritePosition1
GetSpritePosition2:
    jmp _GetSpritePosition2
SetSpritePosition1:
    jmp _SetSpritePosition1
SetSpritePosition2:
    jmp _SetSpritePosition2

; ----------------------------------------------------------------------------
; CheckForEngagingTrainers — scan the map's trainer headers for one engaging.
; pret: home/trainers.asm:CheckForEngagingTrainers
; Requires w_trainer_header_ptr already set to the map's header table (map _Script does
; this).  Iterates flat headers by TH_SIZE; per header runs TrainerEngage.
; Out: wSpriteIndex = engaging trainer's flag bit, or unchanged $-1 sentinel on none.
; ----------------------------------------------------------------------------
CheckForEngagingTrainers:
    xor eax, eax
    call ReadTrainerHeaderInfo      ; sel 0: ESI = flat header base
    mov [cef_header_cursor], esi    ; de = header base (flat cursor)
.trainerLoop:
    mov esi, [cef_header_cursor]
    call StoreTrainerHeaderPointer  ; [ptr] = current header (ESI)
    mov edi, [cef_header_cursor]
    mov al, [edi + TH_FLAG_BIT]     ; flag bit (FLAT read via cursor = pret ld a,[de])
    mov [ebp + wSpriteIndex], al
    mov [ebp + wTrainerHeaderFlagBit], al
    cmp al, 0xff                    ; -1 terminator
    je .doneNone
    mov al, 2
    call ReadTrainerHeaderInfo      ; sel 2: ESI = flag_ptr
    mov bh, FLAG_TEST
    mov cl, [ebp + wTrainerHeaderFlagBit]
    call TrainerFlagAction          ; CL = beaten?
    test cl, cl
    jnz .continue                   ; already defeated -> skip
    ; not defeated: set up engage distance + sprite offset, run TrainerEngage
    xor eax, eax
    call ReadTrainerHeaderInfo      ; sel 0: ESI = header base
    ; view range at header+1 (pret: inc hl; ld a,[hl])
    mov al, [esi + TH_VIEW_RANGE]
    mov [ebp + wTrainerEngageDistance], al
    mov al, [ebp + wSpriteIndex]
    shl al, 4                       ; pret: swap a (slot*0x10)
    mov [ebp + wTrainerSpriteOffset], al
    call TrainerEngage              ; pret: predef TrainerEngage
    mov al, [ebp + wTrainerSpriteOffset]
    test al, al
    jnz .engaging                   ; nonzero ($ff) -> engaging: stop
.continue:
    add dword [cef_header_cursor], TH_SIZE   ; pret: hl=$c; add hl,de; de=hl
    jmp .trainerLoop
.engaging:
    ret
.doneNone:
    ret

; ----------------------------------------------------------------------------
; SaveEndBattleTextPointers — stash win/lose end-battle text pointers + bank.
; pret: home/trainers.asm:SaveEndBattleTextPointers
; In: ESI = win text (flat), EDX = lose text (flat).  (flat-adapted: 4-byte slots)
; ----------------------------------------------------------------------------
SaveEndBattleTextPointers:
    mov al, [ebp + hLoadedROMBank]  ; TODO-HW: bank meaningless under flat model; kept faithful
    mov [ebp + wEndBattleTextRomBank], al
    mov [ebp + wEndBattleWinTextPointer], esi
    mov [ebp + wEndBattleLoseTextPointer], edx
    ret

; ----------------------------------------------------------------------------
; EngageMapTrainer — load the engaged trainer's class/set + play battle music.
; pret: home/trainers.asm:EngageMapTrainer
; In: wSpriteIndex = engaged trainer's sprite id.  Reads wMapSpriteExtraData[(idx-1)*2].
; ⚠ THE ARRAY IS FLAT .bss, NOT GB WRAM — read it flat, never as [ebp + …].
; This file used not to reach it by its pret name at all: include/m8_2_pending_symbols.inc
; defined `wMapSpriteExtraData equ 0xD503` (pret's WRAM address), which nothing in the
; port ever writes, so `[ebp + wMapSpriteExtraData]` returned unwritten emulated RAM —
; zeros — which is exactly what the route3_sight golden caught (want class $CA set $04,
; got $00/$00). That scaffold was deleted 2026-07-27 and the shadowing equ was NOT
; folded into gb_memmap.inc, so the pret name now resolves to the real .bss label.
; The code below keeps the port-only flat alias `map_sprite_extra_data`, which
; map_sprites.asm exports alongside the pret name at the same address; the writer
; (LoadSprite, overworld.asm) and the other reader (TrainerEncounterFlow) both index
; the flat array too.
; NOTE: wMapSpriteExtraData is populated by InitMapSprites (M8.1) from the map
;       object binary's trainer class/set pairs.
; ----------------------------------------------------------------------------
EngageMapTrainer:
    movzx eax, byte [ebp + wSpriteIndex]
    dec eax
    add eax, eax                    ; (idx-1)*2
    lea esi, [eax + map_sprite_extra_data]  ; FLAT array alias (see the ⚠ above)
    mov al, [esi]                   ; trainer class
    mov [ebp + wEngagedTrainerClass], al
    mov al, [esi + 1]               ; trainer mon set
    mov [ebp + wEngagedTrainerSet], al
    jmp PlayTrainerMusic

; ----------------------------------------------------------------------------
; PrintEndBattleText — print the saved end-battle text (once), after a trainer battle.
; pret: home/trainers.asm:PrintEndBattleText
; ----------------------------------------------------------------------------
PrintEndBattleText:
    test byte [ebp + wStatusFlags3], (1 << BIT_PRINT_END_BATTLE_TEXT)
    jz .noText
    and byte [ebp + wStatusFlags3], ~(1 << BIT_PRINT_END_BATTLE_TEXT)
    ; TODO-HW: bank save/restore is a no-op under the flat model (kept structurally).
; STUB{label=SaveTrainerName; class=stub; pret=home/trainers.asm:PrintEndBattleText; behavior=the call returns without copying the trainer class name into wNameBuffer, so the TX_RAM wNameBuffer prefix of TrainerEndBattleText prints whatever the buffer last held; evidence=label DB reports SaveTrainerName status=stub with stub_file dos_port/src/engine/battle/battle_stubs.asm, whose body is ret-only; lifetime=retired with that stub, once TrainerNamePointers exists as generated Tier-1 data and the real save_trainer_name.asm body is ported}
    call SaveTrainerName
    mov esi, TrainerEndBattleText   ; flat text-script
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    call PrintText
    call SetEnemyTrainerToStayAndFaceAnyDirection ; real (npc_movement_2.asm)
    jmp WaitForSoundToFinish        ; pret: jp WaitForSoundToFinish (real, OW-A.14)
.noText:
    and byte [ebp + wStatusFlags3], ~(1 << BIT_PRINT_END_BATTLE_TEXT)
    ret

; ----------------------------------------------------------------------------
; GetSavedEndBattleTextPointer — pick win/lose text by battle result.
; pret: home/trainers.asm:GetSavedEndBattleTextPointer
; Out: ESI = flat text ptr for the outcome.
; ----------------------------------------------------------------------------
GetSavedEndBattleTextPointer:
    mov al, [ebp + wBattleResult]
    test al, al
    jnz .lost
    mov esi, [ebp + wEndBattleWinTextPointer]
    ret
.lost:
    mov esi, [ebp + wEndBattleLoseTextPointer]
    ret

; ----------------------------------------------------------------------------
; TrainerEndBattleText — text-script: trainer name, then the saved end-battle text.
; pret: home/trainers.asm:TrainerEndBattleText  (text_far _TrainerNameText / text_asm)
; Encoded as a flat text-script: $17 (TX_FAR) <dd flat ptr>, $08 (TX_ASM) whose
; inline code is TrainerEndBattleText_asm below — the port TextCommandProcessor's
; .cmd_asm (`push .next_cmd / jmp esi`, home/text.asm) runs it exactly as pret's
; `ld de, NextTextCommand / push de / jp hl`. (The former OW-A.9 KNOWN-BROKEN note
; here is RETIRED: text-engine finding T-1 gave TX_ASM real dispatch and TX_FAR its
; 32-bit flat splice, and _TrainerNameText is generated Tier-1 data now —
; assets/trainer_text.inc, %included below.)
; ----------------------------------------------------------------------------
TrainerEndBattleText:
    db 0x17                         ; TX_FAR
    dd _TrainerNameText             ; flat far-text ptr (assets/trainer_text.inc)
    db 0x08                         ; TX_ASM (run the routine below)
TrainerEndBattleText_asm:
    call GetSavedEndBattleTextPointer   ; ESI = outcome text
    call TextCommandProcessor
    jmp TextScriptEnd

; ----------------------------------------------------------------------------
; PlayTrainerMusic — pick + play the pre-battle trainer music.
; pret: home/trainers.asm:PlayTrainerMusic
; ----------------------------------------------------------------------------
PlayTrainerMusic:
    mov al, [ebp + wEngagedTrainerClass]
    cmp al, OPP_RIVAL1
    je .retNow
    cmp al, OPP_RIVAL2
    je .retNow
    cmp al, OPP_RIVAL3
    je .retNow
    cmp byte [ebp + wGymLeaderNo], 0
    jne .retNow                     ; gym leaders keep the gym music
    xor al, al                              ; pret: xor a
    mov [ebp + wAudioFadeOutControl], al    ;   ld [wAudioFadeOutControl], a
    call StopAllMusic
    ; pret: ld a, BANK(Music_MeetEvilTrainer) / ld [wAudioROMBank],a /
    ;       ld [wAudioSavedROMBank],a. The real engine selects the song table by
    ; wAudioROMBank (home/audio.asm:PlaySound), so this IS load-bearing now (OW-A.14).
    mov al, MUSIC_MEET_EVIL_TRAINER_BANK
    mov [ebp + wAudioROMBank], al
    mov [ebp + wAudioSavedROMBank], al
    mov bh, [ebp + wEngagedTrainerClass]   ; b = class to search
    mov esi, EvilTrainerList
.evilLoop:
    mov al, [esi]
    inc esi
    cmp al, 0xff
    je .noEvil
    cmp al, bh
    jne .evilLoop
    mov al, MUSIC_MEET_EVIL_TRAINER
    jmp .play
.noEvil:
    mov esi, FemaleTrainerList
.femaleLoop:
    mov al, [esi]
    inc esi
    cmp al, 0xff
    je .male
    cmp al, bh
    jne .femaleLoop
    mov al, MUSIC_MEET_FEMALE_TRAINER
    jmp .play
.male:
    mov al, MUSIC_MEET_MALE_TRAINER
.play:
    ; pret: ld [wNewSoundID], a; jp PlaySound.  Port PlaySound takes the id in AL.
    jmp PlaySound
.retNow:
    ret

; ============================================================================
section .data
; ---- pret home/trainers.asm:432  INCLUDE "data/trainers/encounter_types.asm" ----
; (Tier-1 trainer-music class lists: small, deterministic class-id membership,
; inlined as flat data at pret's include position.)
FemaleTrainerList:
    db OPP_LASS
    db OPP_JR_TRAINER_F
    db OPP_BEAUTY
    db OPP_COOLTRAINER_F
    db 0xFF                         ; end
EvilTrainerList:
    db OPP_UNUSED_JUGGLER
    db OPP_GAMBLER
    db OPP_ROCKER
    db OPP_JUGGLER
    db OPP_CHIEF
    db OPP_SCIENTIST
    db OPP_GIOVANNI
    db OPP_ROCKET
    db 0xFF                         ; end

; _TrainerNameText — generated Tier-1 far stream (pret data/text/text_1.asm),
; consumed by TrainerEndBattleText's TX_FAR above. Port-position note: pret keeps
; this in data/text (a different bank); the flat model inlines it here.
%include "assets/trainer_text.inc"
