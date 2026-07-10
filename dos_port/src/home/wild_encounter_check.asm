; wild_encounter_check.asm — StepCountCheck / NewBattle / AllPokemonFainted /
; AnyPartyAlive (Wave 7, M7.1 — overworld wild-encounter + step counting).
;
; Faithful translation of the three step/encounter routines in pret
; home/overworld.asm:
;   StepCountCheck::      (home/overworld.asm:298-314) — per-step counter decrement
;   AllPokemonFainted::   (home/overworld.asm:316-320) — blackout jump target
;   NewBattle::           (home/overworld.asm:324-336) — wild/trainer encounter gate
; plus the party-HP scan helper AnyPartyAlive (pret engine, `callfar AnyPartyAlive`
; at home/overworld.asm:289) that NewBattle's blackout decision reads.
;
; --------------------------------------------------------------------------
; STATUS — wild encounters are LIVE (gate retired 2026-07-10)
; --------------------------------------------------------------------------
; All four routines are compiled + LINKED unconditionally. The former
; -D WILD_ENCOUNTERS_LIVE gate (and the matching %ifdefs in overworld.asm) is
; retired: every blocker it guarded is closed.
;   * StepCountCheck / AnyPartyAlive — always were self-contained (WRAM only).
;     StepCountCheck's wNumberOfNoRandomBattleStepsLeft countdown is now load-
;     bearing: it is the post-battle 3-step encounter-free window.
;   * NewBattle → TryDoWildEncounter — engine/battle/wild_encounters.asm is LINKED.
;     Its two former blockers are closed: IsPlayerStandingOnDoorTileOrWarpTile
;     (engine/overworld/player_state.asm, promoted) and DisplayTextID (a documented
;     ret-stub in src/home/home_stubs.asm — its only call site is the repel-wore-off
;     branch, unreachable until item USE lands; see that stub's header).
;   * AllPokemonFainted → HandleBlackOut — HandleBlackOut + StopMusic are ported
;     into engine/overworld/overworld.asm (the port's home/overworld.asm), backed by
;     engine/events/black_out.asm (ResetStatusAndHalveMoneyOnBlackout) and
;     engine/events/heal_party.asm (HealParty). PrepareForSpecialWarp is the REAL
;     body from engine/overworld/special_warps.asm (the main_menu_stubs.asm ret-stub
;     is deleted, not shadowed).
;   * IsPlayerCharacterBeingControlledByGame is a real linked routine
;     (src/home/npc_movement.asm).
;
; NAMING NOTE (important divergence): pret's NewBattle does `farjp InitBattle`, and
; pret's InitBattle (engine/battle/init_battle.asm) is the ENCOUNTER GATE — it runs
; DetermineWildOpponent -> TryDoWildEncounter before falling into the battle-screen
; setup. The PORT's `InitBattle` (dos_port/src/engine/battle/init_battle.asm) is
; ONLY the battle-screen setup (the DEBUG_BATTLE path) and does NOT roll an
; encounter. So a faithful port NewBattle cannot just call the port InitBattle
; (that would always start a battle with no roll). Instead NewBattle here inlines
; pret InitBattle's DetermineWildOpponent gate (wCurOpponent / no-random-steps /
; TryDoWildEncounter) and only then calls the port InitBattle for the screen.
;
; Register map: a=AL, hl=ESI, bc=BX, de=DX (d=DH); EBP = GB memory base;
; GB memory = [EBP + addr].
;
; Build (LINK):  nasm -f coff -I include/ -I . -o wild_encounter_check.o \
;                    wild_encounter_check.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; --------------------------------------------------------------------------
; Symbols missing from gb_memmap.inc / gb_constants.inc (see SUMMARY "missing
; symbols"). Defined locally here because those shared files are outside this
; member's lane. Addresses derived from W_IGNORE_INPUT_COUNTER = 0xD139
; (pret wIgnoreInputCounter, ram/wram.asm:1848); wStepCounter is the next db
; (ram/wram.asm:1851). Bit values from constants/ram_constants.asm:87,95,106.
; NOTE: NASM permits an `equ` redefinition to the *same* value, so these locals
; coexist with any equal-valued gb_memmap.inc definition; at integration, promote
; them and DELETE the local (a *differing* value would redefinition-error).
; wNumberOfNoRandomBattleStepsLeft promoted to gb_memmap.inc (0xD13B) — OW-A.4.
wStepCounter                    equ 0xD13A
BIT_WILD_ENCOUNTER_COOLDOWN     equ 0        ; wStatusFlags2 bit 0
BIT_ON_DUNGEON_WARP             equ 4        ; wStatusFlags3 bit 4
BIT_NO_BATTLES                  equ 4        ; wStatusFlags4 bit 4

section .text

global StepCountCheck
global AnyPartyAlive

global NewBattle
global AllPokemonFainted
extern TryDoWildEncounter                    ; engine/battle/wild_encounters.asm (LINKED)
extern _InitBattleCommon                     ; init_battle.asm — full wild-battle orchestration
extern IsPlayerCharacterBeingControlledByGame ; src/home/npc_movement.asm (real, linked — OW-A.6)
extern RunMapScript                          ; run_map_script.asm (exists)
extern HandleBlackOut                        ; engine/overworld/overworld.asm (pret home/overworld.asm)

; --------------------------------------------------------------------------
; StepCountCheck — decrement the per-step counters (pret home/overworld.asm:298).
; If simulated joypad input is active (scripted movement) it does nothing, so
; scripted door-exit steps don't count. Otherwise it decrements wStepCounter, and
; — only while the post-battle "no random battle" cooldown is armed — decrements
; wNumberOfNoRandomBattleStepsLeft, clearing the cooldown bit when it hits 0.
; Touches WRAM only; safe to call unconditionally.
; --------------------------------------------------------------------------
StepCountCheck:
    test byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jnz .doneStepCounting                     ; jr nz — inputs simulated, don't count
    dec byte [ebp + wStepCounter]             ; dec [hl] (wStepCounter)
    test byte [ebp + W_STATUS_FLAGS_2], (1 << BIT_WILD_ENCOUNTER_COOLDOWN)
    jz .doneStepCounting                      ; cooldown not armed
    dec byte [ebp + wNumberOfNoRandomBattleStepsLeft]
    jnz .doneStepCounting                     ; still counting down
    and byte [ebp + W_STATUS_FLAGS_2], (~(1 << BIT_WILD_ENCOUNTER_COOLDOWN)) & 0xFF
.doneStepCounting:
    ret

; --------------------------------------------------------------------------
; AnyPartyAlive — OR together every party mon's 2-byte HP. Returns the OR in DH
; (pret returns it in d): DH == 0 => all party mons fainted; DH != 0 => at least
; one is alive. This is pret's `callfar AnyPartyAlive` (home/overworld.asm:289),
; the scan NewBattle's blackout decision consumes. Self-contained; LINK-clean.
; Guard: pret assumes wPartyCount >= 1; the port adds a count==0 -> DH=0 guard so
; an empty/uninitialised party can't spin the loop 2^32 times.
; --------------------------------------------------------------------------
AnyPartyAlive:
    movzx ecx, byte [ebp + wPartyCount]       ; e = party count
    xor al, al
    test ecx, ecx
    jz .done                                  ; port safety: empty party => all fainted
    lea esi, [ebp + wPartyMon1 + MON_HP]      ; hl = &wPartyMon1HP (0xD16B)
.partyLoop:
    or al, [esi]                              ; HP high byte
    or al, [esi + 1]                          ; HP low byte
    add esi, PARTYMON_STRUCT_LENGTH           ; next party mon (44 bytes)
    dec ecx
    jnz .partyLoop
.done:
    mov dh, al                                ; d = OR of all HP bytes
    ret

; --------------------------------------------------------------------------
; NewBattle — determine whether a battle happens this step and, if so, run it.
; Sets CF if a battle occurred, clears CF otherwise (pret home/overworld.asm:324).
; See the NAMING NOTE at the top: this inlines pret InitBattle's DetermineWildOpponent
; gate because the port's InitBattle is screen-setup only.
; --------------------------------------------------------------------------
NewBattle:
    test byte [ebp + W_STATUS_FLAGS_3], (1 << BIT_ON_DUNGEON_WARP)
    jnz .noBattle                             ; on a dungeon warp — no battle
    call IsPlayerCharacterBeingControlledByGame
    jnz .noBattle                             ; player under game control — no battle
    test byte [ebp + W_STATUS_FLAGS_4], (1 << BIT_NO_BATTLES)
    jnz .noBattle                             ; battles suppressed — no battle
    ; --- pret InitBattle / DetermineWildOpponent gate (engine/battle/init_battle.asm) ---
    mov al, [ebp + wCurOpponent]
    test al, al
    jnz .forcedOpponent                       ; wCurOpponent != 0 => forced (InitOpponent)
    ; DetermineWildOpponent:
    mov al, [ebp + wNumberOfNoRandomBattleStepsLeft]
    test al, al
    jnz .noBattle                             ; ret nz — still in no-battle window
    call TryDoWildEncounter                    ; ZF set => encounter, ZF clear => none
    jnz .noBattle                             ; ret nz — no wild encounter this step
    jmp .startBattle
.forcedOpponent:
    mov [ebp + wCurPartySpecies], al          ; InitOpponent: wCurPartySpecies = opponent
    mov [ebp + wEnemyMonSpecies2], al
.startBattle:
    call _InitBattleCommon                      ; run the real battle (data + intro + loop)
    ; _InitBattleCommon returns CF=1 (pret _InitBattleCommon: scf). The post-battle
    ; re-entry (pret .battleOccurred → AnyPartyAlive → EnterMap full map reload) is built
    ; into OverworldLoop (overworld.asm), which the CF=1 return below drives.
    stc                                        ; scf — a battle occurred (belt-and-braces)
    ret
.noBattle:
    clc                                        ; and a — CF=0, no battle
    ret

; --------------------------------------------------------------------------
; AllPokemonFainted — the whole party fainted mid-overworld: flag "battle lost"
; and hand off to the blackout handler (pret home/overworld.asm:316).
; --------------------------------------------------------------------------
AllPokemonFainted:
    mov byte [ebp + wIsInBattle], 0xFF         ; wIsInBattle = $ff (lost)
    call RunMapScript
    jmp HandleBlackOut
