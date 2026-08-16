; RockTunnelB1F.asm — translated from pret scripts/RockTunnelB1F.asm by dos_port/tools/sm83xlat.
;
; ONE-SHOT OUTPUT, NOW HAND-MAINTAINED. The transpiler ran once at the SHA
; recorded in dos_port/tools/sm83xlat/README.md and is not re-run; this file is
; ordinary Tier-2 source and editing it is the normal way it changes. There is
; deliberately no DO NOT EDIT header.
;
; Every pret label is preserved verbatim so the file stays line-for-line
; cross-referenceable against the disassembly.
;
; Regions the tool could not lower WITH CERTAINTY are reproduced below as
; commented pret source under a `; BAIL[reason]` banner, and define NO symbol —
; so a reference to one is a link error rather than a plausible wrong lowering.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "events.inc"
%include "assets/event_constants.inc"


global RockTunnelB1FCooltrainerF1Text
global RockTunnelB1FCooltrainerF2Text
global RockTunnelB1FHiker1Text
global RockTunnelB1FHiker2Text
global RockTunnelB1FHiker3Text
global RockTunnelB1FSuperNerd1Text
global RockTunnelB1FSuperNerd2Text
global RockTunnelB1FSuperNerd3Text
global RockTunnelB1F_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FCooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FCooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FCooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FCooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FCooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FCooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker1BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker2BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker3BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd1BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd2BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd3BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROCKTUNNELB1F_DEFAULT                   equ 0
SCRIPT_ROCKTUNNELB1F_START_BATTLE              equ 1
SCRIPT_ROCKTUNNELB1F_END_BATTLE                equ 2
TEXT_ROCKTUNNELB1F_COOLTRAINER_F1              equ 1
TEXT_ROCKTUNNELB1F_HIKER1                      equ 2
TEXT_ROCKTUNNELB1F_SUPER_NERD1                 equ 3
TEXT_ROCKTUNNELB1F_SUPER_NERD2                 equ 4
TEXT_ROCKTUNNELB1F_HIKER2                      equ 5
TEXT_ROCKTUNNELB1F_COOLTRAINER_F2              equ 6
TEXT_ROCKTUNNELB1F_HIKER3                      equ 7
TEXT_ROCKTUNNELB1F_SUPER_NERD3                 equ 8

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRockTunnelB1FCurScript                        equ 0xD61F

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

RockTunnelB1F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, RockTunnel2TrainerHeaders
    mov edi, RockTunnelB1F_ScriptPointers   ; pret: ld de, RockTunnelB1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRockTunnelB1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRockTunnelB1FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] RockTunnelB1F_ScriptPointers (scripts/RockTunnelB1F.asm:11-45) — a generated asset already defines RockTunnel2TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_ROCKTUNNELB1F_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_ROCKTUNNELB1F_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_ROCKTUNNELB1F_END_BATTLE
; PRET| 
; PRET| RockTunnelB1F_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const RockTunnelB1FCooltrainerF1Text, TEXT_ROCKTUNNELB1F_COOLTRAINER_F1
; PRET| 	dw_const RockTunnelB1FHiker1Text,        TEXT_ROCKTUNNELB1F_HIKER1
; PRET| 	dw_const RockTunnelB1FSuperNerd1Text,    TEXT_ROCKTUNNELB1F_SUPER_NERD1
; PRET| 	dw_const RockTunnelB1FSuperNerd2Text,    TEXT_ROCKTUNNELB1F_SUPER_NERD2
; PRET| 	dw_const RockTunnelB1FHiker2Text,        TEXT_ROCKTUNNELB1F_HIKER2
; PRET| 	dw_const RockTunnelB1FCooltrainerF2Text, TEXT_ROCKTUNNELB1F_COOLTRAINER_F2
; PRET| 	dw_const RockTunnelB1FHiker3Text,        TEXT_ROCKTUNNELB1F_HIKER3
; PRET| 	dw_const RockTunnelB1FSuperNerd3Text,    TEXT_ROCKTUNNELB1F_SUPER_NERD3
; PRET| 
; PRET| RockTunnel2TrainerHeaders:
; PRET| 	def_trainers
; PRET| RockTunnel2TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROCK_TUNNEL_2_TRAINER_0, 4, RockTunnelB1FCooltrainerF1BattleText, RockTunnelB1FCooltrainerF1EndBattleText, RockTunnelB1FCooltrainerF1AfterBattleText
; PRET| RockTunnel2TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_ROCK_TUNNEL_2_TRAINER_1, 3, RockTunnelB1FHiker1BattleText, RockTunnelB1FHiker1EndBattleText, RockTunnelB1FHiker1AfterBattleText
; PRET| RockTunnel2TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_ROCK_TUNNEL_2_TRAINER_2, 3, RockTunnelB1FSuperNerd1BattleText, RockTunnelB1FSuperNerd1EndBattleText, RockTunnelB1FSuperNerd1AfterBattleText
; PRET| RockTunnel2TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_ROCK_TUNNEL_2_TRAINER_3, 4, RockTunnelB1FSuperNerd2BattleText, RockTunnelB1FSuperNerd2EndBattleText, RockTunnelB1FSuperNerd2AfterBattleText
; PRET| RockTunnel2TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_ROCK_TUNNEL_2_TRAINER_4, 3, RockTunnelB1FHiker2BattleText, RockTunnelB1FHiker2EndBattleText, RockTunnelB1FHiker2AfterBattleText
; PRET| RockTunnel2TrainerHeader5:
; PRET| 	trainer EVENT_BEAT_ROCK_TUNNEL_2_TRAINER_5, 4, RockTunnelB1FCooltrainerF2BattleText, RockTunnelB1FCooltrainerF2EndBattleText, RockTunnelB1FCooltrainerF2AfterBattleText
; PRET| RockTunnel2TrainerHeader6:
; PRET| 	trainer EVENT_BEAT_ROCK_TUNNEL_2_TRAINER_6, 3, RockTunnelB1FHiker3BattleText, RockTunnelB1FHiker3EndBattleText, RockTunnelB1FHiker3AfterBattleText
; PRET| RockTunnel2TrainerHeader7:
; PRET| 	trainer EVENT_BEAT_ROCK_TUNNEL_2_TRAINER_7, 3, RockTunnelB1FSuperNerd3BattleText, RockTunnelB1FSuperNerd3EndBattleText, RockTunnelB1FSuperNerd3AfterBattleText
; PRET| 	db -1 ; end

RockTunnelB1FCooltrainerF1Text:
    mov esi, RockTunnel2TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FHiker1Text:
    mov esi, RockTunnel2TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FSuperNerd1Text:
    mov esi, RockTunnel2TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FSuperNerd2Text:
    mov esi, RockTunnel2TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FHiker2Text:
    mov esi, RockTunnel2TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FCooltrainerF2Text:
    mov esi, RockTunnel2TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FHiker3Text:
    mov esi, RockTunnel2TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FSuperNerd3Text:
    mov esi, RockTunnel2TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] RockTunnelB1FCooltrainerF1BattleText (scripts/RockTunnelB1F.asm:96-189) — a generated asset already defines RockTunnelB1FCooltrainerF1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _RockTunnelB1FCooltrainerF1BattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FCooltrainerF1EndBattleText:
; PRET| 	text_far _RockTunnelB1FCooltrainerF1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FCooltrainerF1AfterBattleText:
; PRET| 	text_far _RockTunnelB1FCooltrainerF1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FHiker1BattleText:
; PRET| 	text_far _RockTunnelB1FHiker1BattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FHiker1EndBattleText:
; PRET| 	text_far _RockTunnelB1FHiker1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FHiker1AfterBattleText:
; PRET| 	text_far _RockTunnelB1FHiker1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FSuperNerd1BattleText:
; PRET| 	text_far _RockTunnelB1FSuperNerd1BattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FSuperNerd1EndBattleText:
; PRET| 	text_far _RockTunnelB1FSuperNerd1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FSuperNerd1AfterBattleText:
; PRET| 	text_far _RockTunnelB1FSuperNerd1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FSuperNerd2BattleText:
; PRET| 	text_far _RockTunnelB1FSuperNerd2BattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FSuperNerd2EndBattleText:
; PRET| 	text_far _RockTunnelB1FSuperNerd2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FSuperNerd2AfterBattleText:
; PRET| 	text_far _RockTunnelB1FSuperNerd2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FHiker2BattleText:
; PRET| 	text_far _RockTunnelB1FHiker2BattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FHiker2EndBattleText:
; PRET| 	text_far _RockTunnelB1FHiker2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FHiker2AfterBattleText:
; PRET| 	text_far _RockTunnelB1FHiker2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FCooltrainerF2BattleText:
; PRET| 	text_far _RockTunnelB1FCooltrainerF2BattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FCooltrainerF2EndBattleText:
; PRET| 	text_far _RockTunnelB1FCooltrainerF2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FCooltrainerF2AfterBattleText:
; PRET| 	text_far _RockTunnelB1FCooltrainerF2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FHiker3BattleText:
; PRET| 	text_far _RockTunnelB1FHiker3BattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FHiker3EndBattleText:
; PRET| 	text_far _RockTunnelB1FHiker3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FHiker3AfterBattleText:
; PRET| 	text_far _RockTunnelB1FHiker3AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FSuperNerd3BattleText:
; PRET| 	text_far _RockTunnelB1FSuperNerd3BattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FSuperNerd3EndBattleText:
; PRET| 	text_far _RockTunnelB1FSuperNerd3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| RockTunnelB1FSuperNerd3AfterBattleText:
; PRET| 	text_far _RockTunnelB1FSuperNerd3AfterBattleText
; PRET| 	text_end
