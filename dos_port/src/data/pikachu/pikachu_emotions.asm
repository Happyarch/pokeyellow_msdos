%include "assets/script_constants.inc"; shared constants (%define: emits no COFF symbol)
; pikachu_emotions.asm — pret mirror of data/pikachu/pikachu_emotions.asm.
;
; Pikachu emotion bytecode scripts (0 to 32) and movement scripts.
;
; Register map (CLAUDE.md): A->AL, HL->ESI, BC->BX, DE->DX; GB mem = [ebp+SYM].

bits 32

; ---------------------------------------------------------------------------
; Constants
; ---------------------------------------------------------------------------

section .data

global PikachuEmotion0
global PikachuEmotion1
global PikachuEmotion2
global PikachuEmotion3
global PikachuEmotion4
global PikachuEmotion5
global PikachuEmotion6
global PikachuEmotion7
global PikachuEmotion8
global PikachuEmotion9
global PikachuEmotion10
global PikachuEmotion11
global PikachuEmotion12
global PikachuEmotion13
global PikachuEmotion14
global PikachuEmotion15
global PikachuEmotion16
global PikachuEmotion17
global PikachuEmotion18
global PikachuEmotion19
global PikachuEmotion20
global PikachuEmotion21
global PikachuEmotion22
global PikachuEmotion23
global PikachuEmotion24
global PikachuEmotion25
global PikachuEmotion26
global PikachuEmotion27
global PikachuEmotion28
global PikachuEmotion29
global PikachuEmotion30
global PikachuEmotion31
global PikachuEmotion32
global PikachuMovementData_fd218
global PikachuMovementData_fd21e
global PikachuMovementData_fd224
global PikachuMovementData_fd22c
global PikachuMovementData_fd230
global PikachuMovementData_fd238

PikachuEmotion0:
    db 0xFF

PikachuEmotion1:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 0xFF
    db PIKAEMOTION_5, 1
    db 0xFF

PikachuEmotion2:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_DOEMOTIONBUBBLE, SMILE_BUBBLE
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 34         ; PikachuCry35
    db PIKAEMOTION_5, 2
    db 0xFF

PikachuEmotion3:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 39         ; PikachuCry40
    db PIKAEMOTION_5, 3
    db 0xFF

PikachuEmotion4:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_LOADEXTRAPIKASPRITES
    db PIKAEMOTION_4
    dd PikachuMovementData_fd230
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 28         ; PikachuCry29
    db PIKAEMOTION_5, 4
    db 0xFF

PikachuEmotion5:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 30         ; PikachuCry31
    db PIKAEMOTION_5, 5
    db 0xFF

PikachuEmotion6:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_LOADEXTRAPIKASPRITES
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 0xFF
    db PIKAEMOTION_4
    dd PikachuMovementData_fd21e
    db PIKAEMOTION_DOEMOTIONBUBBLE, SKULL_BUBBLE
    db PIKAEMOTION_5, 6
    db 0xFF

PikachuEmotion7:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_LOADEXTRAPIKASPRITES
    db PIKAEMOTION_4
    dd PikachuMovementData_fd224
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 0          ; PikachuCry1
    db PIKAEMOTION_4
    dd PikachuMovementData_fd224
    db PIKAEMOTION_5, 7
    db 0xFF

PikachuEmotion8:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 38         ; PikachuCry39
    db PIKAEMOTION_5, 8
    db 0xFF

PikachuEmotion9:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_LOADEXTRAPIKASPRITES
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 5          ; PikachuCry6
    db PIKAEMOTION_4
    dd PikachuMovementData_fd218
    db PIKAEMOTION_DOEMOTIONBUBBLE, SKULL_BUBBLE
    db PIKAEMOTION_5, 9
    db 0xFF

PikachuEmotion10:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_LOADEXTRAPIKASPRITES
    db PIKAEMOTION_DOEMOTIONBUBBLE, HEART_BUBBLE
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 4          ; PikachuCry5
    db PIKAEMOTION_5, 10
    db 0xFF

PikachuEmotion11:
    db PIKAEMOTION_DOEMOTIONBUBBLE, ZZZ_BUBBLE
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 36         ; PikachuCry37
    db PIKAEMOTION_5, 11
    db 0xFF

PikachuEmotion12:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 0xFF
    db PIKAEMOTION_5, 12
    db 0xFF

PikachuEmotion13:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_LOADEXTRAPIKASPRITES
    db PIKAEMOTION_4
    dd PikachuMovementData_fd21e
    db PIKAEMOTION_5, 13
    db 0xFF

PikachuEmotion14:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_DOEMOTIONBUBBLE, BOLT_BUBBLE
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 9          ; PikachuCry10
    db PIKAEMOTION_5, 14
    db 0xFF

PikachuEmotion15:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 33         ; PikachuCry34
    db PIKAEMOTION_5, 15
    db 0xFF

PikachuEmotion16:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 32         ; PikachuCry33
    db PIKAEMOTION_5, 16
    db 0xFF

PikachuEmotion17:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 12         ; PikachuCry13
    db PIKAEMOTION_5, 17
    db 0xFF

PikachuEmotion18:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 0xFF
    db PIKAEMOTION_5, 18
    db 0xFF

PikachuEmotion19:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_DOEMOTIONBUBBLE, HEART_BUBBLE
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 32         ; PikachuCry33
    db PIKAEMOTION_5, 19
    db 0xFF

PikachuEmotion20:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_DOEMOTIONBUBBLE, HEART_BUBBLE
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 4          ; PikachuCry5
    db PIKAEMOTION_5, 20
    db 0xFF

PikachuEmotion21:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_DOEMOTIONBUBBLE, FISH_BUBBLE
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 0xFF
    db PIKAEMOTION_5, 21
    db 0xFF

PikachuEmotion22:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 3          ; PikachuCry4
    db PIKAEMOTION_5, 22
    db 0xFF

PikachuEmotion23:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 18         ; PikachuCry19
    db PIKAEMOTION_5, 23
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_SHOWMAPVIEW
    db 0xFF

PikachuEmotion24:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_DOEMOTIONBUBBLE, EXCLAMATION_BUBBLE
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 0xFF
    db PIKAEMOTION_5, 24
    db 0xFF

PikachuEmotion25:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_DOEMOTIONBUBBLE, BOLT_BUBBLE
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 34         ; PikachuCry35
    db PIKAEMOTION_5, 25
    db 0xFF

PikachuEmotion26:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_DOEMOTIONBUBBLE, ZZZ_BUBBLE
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 36         ; PikachuCry37
    db PIKAEMOTION_5, 26
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_SHOWMAPVIEW
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_CHECKPEWTERCENTER
    db 0xFF

PikachuEmotion27:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 8          ; PikachuCry9
    db PIKAEMOTION_5, 27
    db 0xFF

PikachuEmotion28:
    db PIKAEMOTION_DUMMY2
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 14         ; PikachuCry15
    db PIKAEMOTION_5, 28
    db 0xFF

PikachuEmotion29:
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 4          ; PikachuCry5
    db PIKAEMOTION_5, 10
    db 0xFF

PikachuEmotion30:
    db PIKAEMOTION_9
    db PIKAEMOTION_DOEMOTIONBUBBLE, HEART_BUBBLE
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 4          ; PikachuCry5
    db PIKAEMOTION_5, 20
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_SHOWMAPVIEW
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_LOADFONT
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_CHECKLAVENDERTOWER
    db 0xFF

PikachuEmotion31:
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 18         ; PikachuCry19
    db PIKAEMOTION_5, 23
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_SHOWMAPVIEW
    db PIKAEMOTION_SUBCMD, PIKAEMOTION_SUBCMD_CHECKBILLSHOUSE
    db 0xFF

PikachuEmotion32:
    db PIKAEMOTION_PLAYPCMSOUNDCLIP, 25         ; PikachuCry26
    db PIKAEMOTION_5, 23
    db 0xFF

PikachuMovementData_fd218:
    db 0x00
    db 0x39, 1
    db 0x3E, 30
    db 0x3F

PikachuMovementData_fd21e:
    db 0x00
    db 0x39, 0
    db 0x3E, 30
    db 0x3F

PikachuMovementData_fd224:
    db 0x00
    db 0x3C, 7, 0x2F
    db 0x3C, 7, 0x2F
    db 0x3F

PikachuMovementData_fd22c:
    db 0x3B, 31, 3
    db 0x3F

PikachuMovementData_fd230:
    db 0x00
    db 0x3C, 15, 0x1F
    db 0x3C, 15, 0x1F
    db 0x3F

PikachuMovementData_fd238:
    db 0x00
    db 0x05, 7
    db 0x39, 0
    db 0x05, 7
    db 0x06, 7
    db 0x39, 0
    db 0x06, 7
    db 0x08, 7
    db 0x39, 0
    db 0x08, 7
    db 0x07, 7
    db 0x39, 0
    db 0x07, 7
    db 0x3F
