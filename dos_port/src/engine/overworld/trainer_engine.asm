; ============================================================================
; trainer_engine.asm — overworld trainer-header engine  (home-rectify M8.2)
;
; Intended repo path: dos_port/src/engine/overworld/trainer_engine.asm
;
; Faithful translation of:
;   home/trainers.asm    — StoreTrainerHeaderPointer, ExecuteCurMapScriptInTable,
;                          LoadGymLeaderAndCityName, ReadTrainerHeaderInfo,
;                          TrainerFlagAction, TalkToTrainer, CheckFightingMapTrainers,
;                          DisplayEnemyTrainerTextAndStartBattle, TrainerWalkUpToPlayer_Bank0,
;                          CheckForEngagingTrainers, SaveEndBattleTextPointers,
;                          EngageMapTrainer, PrintEndBattleText, GetSavedEndBattleTextPointer,
;                          TrainerEndBattleText, PlayTrainerMusic
;   home/trainers2.asm   — MOVED to the pret mirror src/home/trainers2.asm (2026-07-24)
;   engine/overworld/trainer_sight.asm  — MOVED to the pret mirror
;                          src/engine/overworld/trainer_sight.asm (2026-07-24)
;   engine/overworld/emotion_bubbles.asm — EmotionBubble
;   data/trainers/encounter_types.asm    — FemaleTrainerList / EvilTrainerList
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH, C->BL, D->DH, E->DL.
; RAM is EBP-relative: emulated GB byte X is [ebp + X].  Tier-1 asset data (trainer
; headers, pic/money tables, text) are FLAT 32-bit host pointers (like MapScriptPointers,
; w_map_text_table_ptr, TrainerPicPointers) — read as [flat_ptr] WITHOUT ebp.
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
; npc_beaten_flags -> TrainerFlagAction CONVERGENCE  (see SUMMARY.md).
; ----------------------------------------------------------------------------
; The bespoke port keeps trainers-beaten state in map_sprites.asm's `npc_beaten_flags`
; (a 16-bit BSS reset every InitMapSprites => NON-persistent: trainers un-beat on every
; map reload).  This engine's persistent `TrainerFlagAction` is the faithful replacement:
; it drives the home global `FlagAction` against the header's flag_ptr => wEventFlags
; (persistent across warps).  ROOT FOLLOW-UP: once trainer-header DATA exists, delete
; npc_beaten_flags and route map_sprites.asm's CheckTrainerSight / TrainerEncounterFlow
; beaten-gate through TrainerFlagAction(FLAG_TEST/FLAG_SET).  (This worker does NOT edit
; map_sprites.asm.)
;
; STATUS: CHECK-ONLY.  Many cross-subsystem deps are unported (extern + TODO below); the
; trainer-header DATA layer + generator do not exist yet, so nothing calls this at runtime
; until M8.1 (sight->battle) + the data generator land.  Root wires the call sites.
;
; Build (check):
;   nasm -f coff -I dos_port/include/ -I dos_port/ -o trainer_engine.o \
;        dos_port/src/engine/overworld/trainer_engine.asm
; ============================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "m8_2_pending_symbols.inc"   ; ROOT: fold into gb_memmap/gb_constants, then delete
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
; --- home globals already ported (link targets exist) ---
extern FlagAction               ; src/engine/flag_action.asm (persistent flag array)
extern CallFunctionInTable      ; src/home/run_map_script.asm
extern CopyData                 ; src/home/copy_data.asm
extern BankswitchHome           ; src/home/bankswitch.asm (no-op flat)
extern BankswitchBack           ; src/home/bankswitch.asm (no-op flat)
extern FillMemory               ; home/copy2.asm  (ESI unchanged on return!)
extern WriteOAMBlock            ; src/home/oam.asm
extern DelayFrame               ; src/video/frame.asm
extern DelayFrames              ; src/video/frame.asm
extern UpdateSprites            ; src/engine/overworld/movement.asm
extern PrintText                ; src/home/window.asm
extern PlaySound                ; src/home/audio.asm (real gateway)
extern DisplayTextID            ; src/home/text_script.asm — pret: home/text_script.asm


; --- UNPORTED deps: extern + TODO(M8.2 follow-up); root supplies or stubs ---
extern StartTrainerBattle       ; src/home/trainers.asm (pret mirror, LINKED)
extern InitBattleEnemyParameters; src/home/trainers.asm (pret mirror, LINKED)
extern ResetButtonPressedAndMapScript ; TODO(M8.2 follow-up): unported, no body anywhere yet (pret home/trainers.asm)
extern StopAllMusic             ; src/home/audio.asm (real gateway)
extern WaitForSoundToFinish     ; src/home/audio.asm (real gateway)
extern SaveTrainerName          ; TODO(M8.2 follow-up): engine/battle/*, unported
extern SetEnemyTrainerToStayAndFaceAnyDirection ; TODO(M8.2 follow-up): unported
extern TextCommandProcessor     ; TODO(M8.2 follow-up): text.asm has it; verify global name
extern TextScriptEnd            ; TODO(M8.2 follow-up): text_script, unported
extern HideObject               ; TODO(M8.2 follow-up): hidden_events, unported
extern CopyVideoData            ; src/home/copy2.asm (ported): ESI=dst VRAM offset, EDX=flat src, BL=tile count
; EmotionBubbleGfx is now defined here via %include "assets/emotes.inc" (gen_emotes.py).
extern _TrainerNameText         ; TODO(M8.2 follow-up): Tier-1 text (data/text) — NOT in port
extern msgbox_dialog                    ; src/home/text.asm — overworld dialog projection
extern text_msgbox                      ; src/home/text.asm — active msgbox projection (msgbox.inc)

; ----------------------------------------------------------------------------
; Globals
; ----------------------------------------------------------------------------
global StoreTrainerHeaderPointer
global ExecuteCurMapScriptInTable
global LoadGymLeaderAndCityName
global ReadTrainerHeaderInfo
global TrainerFlagAction
global TalkToTrainer
global CheckFightingMapTrainers
global DisplayEnemyTrainerTextAndStartBattle
global TrainerWalkUpToPlayer_Bank0
global CheckForEngagingTrainers
global SaveEndBattleTextPointers
global GetSavedEndBattleTextPointer
global EngageMapTrainer
global PrintEndBattleText
global PlayTrainerMusic
global w_trainer_header_ptr
; (TrainerWalkUpToPlayer / ReadTrainerScreenPosition / TrainerEngage moved to
;  src/engine/overworld/trainer_sight.asm; GetTrainerInformation / GetTrainerName
;  to src/home/trainers2.asm — both pret mirrors, 2026-07-24.)
extern TrainerWalkUpToPlayer    ; src/engine/overworld/trainer_sight.asm
extern TrainerEngage            ; src/engine/overworld/trainer_sight.asm

; ============================================================================
section .bss
; Flat header pointer (supersedes pret's emulated wTrainerHeaderPtr — see header note).
w_trainer_header_ptr:  resd 1
; CheckForEngagingTrainers scans with a flat header cursor; b/c are consumed by
; FlagAction, so the cursor can't live in EBX. Keep it here.
cef_header_cursor:     resd 1

section .data
; ---- data/trainers/encounter_types.asm (Tier-1: trainer-music class lists) ----
; small, deterministic, class-id membership lists — inlined as flat data.
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

; EmotionBubble OAM block (tile id, attributes) — pret EmotionBubblesOAMBlock
EmotionBubblesOAMBlock:
    db 0xF8, 0
    db 0xF9, 0
    db 0xFA, 0
    db 0xFB, 0

; Overworld emotion-bubble tiles (pret gfx/emotes/*.2bpp). Defines EmotionBubbles /
; EmotionBubbleGfx + EMOTE_TILE_BYTES/EMOTE_TILES_PER_BUBBLE/EMOTE_BUBBLE_BYTES/NUM_EMOTES.
%include "assets/emotes.inc"

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
; equivalent used elsewhere (see item_predicates.asm note).  This is the PERSISTENT
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
    inc byte [ebp + wCurMapScript]  ; advance map script (next = EndTrainerBattle)
    jmp StartTrainerBattle          ; TODO(M8.2 follow-up): M8.1 owns StartTrainerBattle
.done:
    ret

; ----------------------------------------------------------------------------
; CheckFightingMapTrainers — any trainer seeing the player and wanting to fight?
; pret: home/trainers.asm:CheckFightingMapTrainers (_DEBUG B-skip omitted — no _DEBUG)
; This is the faithful, persistent replacement for map_sprites.asm's bespoke
; CheckTrainerSight (root rewires OverworldLoop's sight hook here later — see SUMMARY).
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
; pret: home/trainers.asm:DisplayEnemyTrainerTextAndStartBattle (falls into StartTrainerBattle)
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
    jmp StartTrainerBattle          ; TODO(M8.2 follow-up): M8.1 owns StartTrainerBattle

; ----------------------------------------------------------------------------
; TrainerWalkUpToPlayer_Bank0 — pret farjp TrainerWalkUpToPlayer (flat: direct jmp).
; ----------------------------------------------------------------------------
TrainerWalkUpToPlayer_Bank0:
    jmp TrainerWalkUpToPlayer

; (TrainerWalkUpToPlayer, ReadTrainerScreenPosition, TrainerEngage,
;  CheckSpriteCanSeePlayer and CheckPlayerIsInFrontOfSprite moved to their pret
;  mirror src/engine/overworld/trainer_sight.asm — relocated-labels grind,
;  2026-07-24. TrainerWalkUpToPlayer_Bank0 above and CheckForEngagingTrainers
;  below reach them via extern.)

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
; EngageMapTrainer — load the engaged trainer's class/set + play battle music.
; pret: home/trainers.asm:EngageMapTrainer
; In: wSpriteIndex = engaged trainer's sprite id.  Reads wMapSpriteExtraData[(idx-1)*2].
; NOTE: wMapSpriteExtraData is populated by M8.1 (InitMapSprites currently discards
;       trainer class/num) — until M8.1 lands this reads zeros. (root wiring note)
; ----------------------------------------------------------------------------
EngageMapTrainer:
    movzx eax, byte [ebp + wSpriteIndex]
    dec eax
    add eax, eax                    ; (idx-1)*2
    lea esi, [ebp + eax + wMapSpriteExtraData]
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
    call SaveTrainerName            ; TODO(M8.2 follow-up): unported
    mov esi, TrainerEndBattleText   ; flat text-script
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    call PrintText
    call SetEnemyTrainerToStayAndFaceAnyDirection ; TODO(M8.2 follow-up): unported
    jmp WaitForSoundToFinish        ; pret: jp WaitForSoundToFinish (real, OW-A.14)
.noText:
    and byte [ebp + wStatusFlags3], ~(1 << BIT_PRINT_END_BATTLE_TEXT)
    ret

; ----------------------------------------------------------------------------
; TrainerEndBattleText — text-script: trainer name, then the saved end-battle text.
; pret: home/trainers.asm:TrainerEndBattleText  (text_far _TrainerNameText / text_asm)
; Encoded as a flat text-script: $17 (TX_FAR) <dd flat ptr>, $08 (TX_ASM) marker
; meant to run the TrainerEndBattleText_asm callback below.
;
; OW-A.9 KNOWN-BROKEN, DEFERRED (file is check-only; not on any live path today):
;   1. The port's TextCommandProcessor treats $08 (TX_ASM) as a silent no-operand
;      SKIP (text.asm:959) — it does NOT dispatch the callback. So TrainerEndBattleText_asm
;      is DEAD, and after the skip the processor parses into the callback's machine-code
;      bytes as if they were text opcodes (garbage run-on). Cross-cutting with the same
;      TX_ASM gap in charge.asm.
;   2. TX_FAR here points at _TrainerNameText, which is Tier-1 text NOT yet generated
;      into the port (extern, unresolved as data).
; Two unblock paths (pick when the deps land): (a) add real TX_ASM ($08) dispatch to
; TextCommandProcessor, or (b) bypass the script — have PrintEndBattleText call the
; trainer-name print + GetSavedEndBattleTextPointer/PrintText directly. Both need the
; _TrainerNameText Tier-1 text generated first. Left as-is until then.
; ----------------------------------------------------------------------------
TrainerEndBattleText:
    db 0x17                         ; TX_FAR
    dd _TrainerNameText             ; flat far-text ptr (extern; Tier-1 text — NOT in port)
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

; (GetTrainerInformation / IsFightingJessieJames / GetTrainerName moved to
;  their pret mirror src/home/trainers2.asm — relocated-labels grind,
;  2026-07-24.)

; ============================================================================
; engine/overworld/emotion_bubbles.asm
; ============================================================================

; ----------------------------------------------------------------------------
; EmotionBubble — draw an emotion bubble (e.g. "!") above a sprite for a beat.
; pret: engine/overworld/emotion_bubbles.asm:EmotionBubble
; In: wWhichEmotionBubble = which bubble, wEmotionBubbleSpriteIndex = target sprite.
; CopyVideoData is ported (copy2.asm); EmotionBubbleGfx is now generated
; (assets/emotes.inc). The gfx load below is fully wired; the only remaining gap is
; the WriteOAMBlock call further down (flat OAM block vs EBP-relative src — see there).
; ----------------------------------------------------------------------------
EmotionBubble:
    ; source tiles: EmotionBubbleGfx + (wWhichEmotionBubble & $f) * EMOTE_BUBBLE_BYTES.
    ; pret: `swap a` (*16) then four `add hl,bc` = *64 (each emote is 4 tiles = 64 bytes).
    mov al, [ebp + wWhichEmotionBubble]
    and al, 0x0f
    movzx ebx, al
    shl ebx, 6                      ; * EMOTE_BUBBLE_BYTES (64); was *16 (wrong stride)
    ; CopyVideoData ABI (copy2.asm:62): ESI = dst VRAM offset, EDX = flat src, BL = tiles.
    lea edx, [EmotionBubbleGfx + ebx]    ; EDX = flat source (was wrongly in ESI)
    mov esi, GB_VCHARS1_TILE78           ; ESI = dst VRAM offset (was wrongly in EDI)
    mov bl, EMOTE_TILES_PER_BUBBLE       ; BL = tile count 4 (was wrongly BH; BH = bank, flat no-op)
    call CopyVideoData
    ; force sprite updates on while the bubble shows
    mov al, [ebp + wUpdateSpritesEnabled]
    push eax
    mov byte [ebp + wUpdateSpritesEnabled], 0xff
    ; shift shadow-OAM forward 16 bytes to make room for the 4 bubble sprites.
    ; last-4-OAM reserved for shadow/rod if BIT_LEDGE_OR_FISHING set.
    test byte [ebp + wMovementFlags], (1 << BIT_LEDGE_OR_FISHING)
    jnz .reserved
    ; wShadowOAMSprite35Attributes -> wShadowOAMSprite39Attributes
    mov esi, W_SHADOW_OAM + 35*4 + 3
    mov edi, W_SHADOW_OAM + 39*4 + 3
    jmp .shift
.reserved:
    mov esi, W_SHADOW_OAM + 31*4 + 3
    mov edi, W_SHADOW_OAM + 35*4 + 3
.shift:
    mov ecx, 0x90
.shiftLoop:
    mov al, [ebp + esi]
    mov [ebp + edi], al
    dec esi
    dec edi
    dec ecx
    jnz .shiftLoop
    ; screen coords of the target sprite (YPIXELS -> b, XPIXELS+8 -> c)
    movzx esi, byte [ebp + wEmotionBubbleSpriteIndex]
    shl esi, 4                      ; slot*0x10
    mov bh, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_YPIXELS]
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_XPIXELS]
    add al, 8
    mov bl, al                      ; c = x+8
    ; WriteOAMBlock now takes the tile/attr source as a FLAT pointer in EDX
    ; (home/oam.asm — the OAM-block tables are flat .data labels, not GB offsets;
    ; the prior DX-as-GB-offset model was wrong for every caller). pret: ld de, block.
    mov edx, EmotionBubblesOAMBlock ; de = OAM block (flat)
    xor al, al
    call WriteOAMBlock
    mov bl, 60
    call DelayFrames                ; c = 60 frames
    pop eax
    mov [ebp + wUpdateSpritesEnabled], al
    call DelayFrame
    call UpdateSprites
    ret

; VRAM target for the emotion bubble tiles (vChars1 tile $78).
; TODO(M8.2 follow-up): confirm the port's vChars1 base + tile-$78 byte offset symbol.
; pret `vChars1 tile $78`: vChars1 = GB_VFONT ($8800), tile $78 → +$780 = $8F80.
; That is OBJ tile $F8 ($8000 + $F8*$10), matching EmotionBubblesOAMBlock's $F8-$FB ids.
; (Was 0x8000+0x780 = $8780 = OBJ tile $78 — wrong base; the OAM block reads tiles $F8+.)
GB_VCHARS1_TILE78 equ GB_VFONT + 0x780

; ============================================================================
; Get/SetSpritePosition1/2 — pret bank-wrapper trampolines (home/trainers.asm:246-262)
; around the byte-verified _Get/_SetSpritePosition1/2 bodies, which live at their
; pret mirror src/engine/overworld/trainer_sight.asm (moved 2026-07-24). pret loads
; the target into hl then `ld b, BANK("Trainer Sight") / jp Bankswitch`; under the
; port's flat model banking is a no-op, so each is a direct tail-jump. (pret's
; shared SpritePositionBankswitch tail collapses into these four jmps — its
; SetSpritePosition2 fallthrough is realized by SetSpritePosition2's own jmp.)
; Called by scripts/OaksLab.asm (Oak cutscene, not yet ported) — provided so the
; pret labels resolve. OW-A.9.
; ============================================================================
extern _GetSpritePosition1      ; src/engine/overworld/trainer_sight.asm
extern _GetSpritePosition2      ; src/engine/overworld/trainer_sight.asm
extern _SetSpritePosition1      ; src/engine/overworld/trainer_sight.asm
extern _SetSpritePosition2      ; src/engine/overworld/trainer_sight.asm

global GetSpritePosition1
global GetSpritePosition2
global SetSpritePosition1
global SetSpritePosition2

GetSpritePosition1:
    jmp _GetSpritePosition1
GetSpritePosition2:
    jmp _GetSpritePosition2
SetSpritePosition1:
    jmp _SetSpritePosition1
SetSpritePosition2:
    jmp _SetSpritePosition2
