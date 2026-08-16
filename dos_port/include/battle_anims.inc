; battle_anims.inc — the `special_effect` row macro shared by pret's two
; battle-animation dispatch tables, which live in separate mirrored files
; (data/battle_anims/special_effect_pointers.asm and .../special_effects.asm).
;
; pret uses `db id / dw ptr` (3-byte rows, 16-bit ROM pointers). The flat DPMI
; model uses `db id / dd ptr` (5-byte rows, 32-bit program-image addresses),
; which is why PlayAnimation's search loop strides by 5 and
; DoSpecialEffectByAnimationId passes stride 5 to IsInArray.
%macro special_effect 2
    db %1
    dd %2
%endmacro
