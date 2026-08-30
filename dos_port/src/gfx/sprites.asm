; sprites.asm — pret gfx/sprites.asm mirror
;
; Player and NPC sprite sheet data.
; RedBikeSprite / player_sprite (RedSprite) / SeelSprite / SurfingPikachuSprite.
;
; Register map: N/A (data).

bits 32

section .data

global player_sprite
%include "assets/player_sprite.inc"

section .text

global RedBikeSprite
global SeelSprite
global SurfingPikachuSprite
%include "assets/red_bike_sprite.inc"
%include "assets/seel_sprite.inc"
%include "assets/surfing_pikachu_sprite.inc"
