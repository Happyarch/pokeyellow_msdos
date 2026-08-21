; dakutens.asm — pret data/text/dakutens.asm mirror.
;
; Dakutens / Handakutens: the naming screen's kana voicing tables, {plain,
; voiced} byte pairs terminated by $FF, searched with IsInArray at stride 2 by
; engine/menus/naming_screen.asm:DakutensAndHandakutens.
;
; Tier-1 generated data: tools/generators/gen_dakutens.py emits
; assets/dakutens.inc from the pret source table + constants/charmap.asm —
; never hand-edit, and never hand-encode charmap bytes.
;
; The English port never reaches the substitution (its alphabet grid has no
; kana pages — see the DEVIATION at naming_screen.asm's .dakutensAndHandakutens
; branch), so these tables are unreferenced at runtime; they exist so the pret
; data label lives at its mirrored path.
bits 32

global Dakutens
global Handakutens

section .data
%include "assets/dakutens.inc"
