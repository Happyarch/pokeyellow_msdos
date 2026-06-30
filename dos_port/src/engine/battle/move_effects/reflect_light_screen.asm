%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

extern Bankswitch
extern LightScreenProtectedText
extern ReflectGainedArmorText

global EffectCallBattleCore
EffectCallBattleCore:
    mov bh, 0
    jmp Bankswitch


