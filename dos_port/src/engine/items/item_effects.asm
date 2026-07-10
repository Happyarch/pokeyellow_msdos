; item_effects.asm — non-UI item-use effect math (items layer, Stage 3).
;
; Source: engine/items/item_effects.asm (pret/pokeyellow). These are the pure
; data-mutation cores of the ItemUse* handlers, lifted out of their UI: the
; surrounding text ("used ITEM!"), menus, animations, and in-battle stat-copy
; are stubbed/omitted; only the WRAM mutations remain. Callers supply the target
; pointer and amount; we return CF for had-effect / no-effect.
;
;   WakeUpEntireParty  — Poke Flute: clear SLP for every party mon, flag wakes.
;   RestorePPAmount    — Ether/Max Ether/Elixer: raise a move's current PP.
;   ApplyHealingItem   — Potion/Revive family: add HP, clamp to (half) max HP.
;   CureStatusAilment  — Antidote/.../Full Heal: clear a status flag if present.
;   ApplyVitamin       — HP Up/.../Calcium: add 2560 stat exp (capped at 25600).
;   RareCandyLevelUp   — Rare Candy: +1 level, set min exp, recalc stats, grow HP.
;
; Register map: a=AL, b=BH, c=BL, hl=ESI, de=EDX. GB memory at [EBP+addr].
;
; DEFERRED: Func_d85d (ItemUseEvoStone applicability check) is NOT translated
; here. It walks EvosMovesPointerTable + FarCopyData to test whether the used
; stone evolves the selected mon, but the DOS port stores EvosMovesPointerTable
; with its own flat addressing (see src/engine/pokemon/evos_moves.asm) — the
; pret `add hl,bc` twice / copy-2-bytes-as-a-16-bit-pointer logic does not carry
; over verbatim. It belongs with the evolution path and is left for that work.
;
; Build: nasm -f coff -I include/ -I . -o item_effects.o item_effects.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global WakeUpEntireParty
global RestorePPAmount
global ApplyHealingItem
global CureStatusAilment
global ApplyVitamin
global RareCandyLevelUp

extern CalcStats        ; home/move_mon.asm (BH=consider-exp, ESI=stat-exp ptr, EDX=dest)
extern CalcExperience   ; engine/pokemon/experience.asm (DH=level -> H_EXPERIENCE)
extern AddNTimes        ; home/array.asm (ESI += AL*BX)
extern LoadMovePPs      ; engine/pokemon/write_moves.asm (predef; reads wPredefHL/DE)
extern AddBonusPP       ; engine/pokemon/get_max_pp.asm (EDX = max-PP src, ESI = PP byte)

section .text

; ---------------------------------------------------------------------------
; WakeUpEntireParty — clear the Sleep status of every party mon (Poke Flute).
; In:  ESI (hl) = first party mon's status byte
;      BL       = sleep-clear mask (~SLP_MASK, the bits to keep)
;      ECX      = PARTY_LENGTH (number of mons to walk)
; Out: wWereAnyMonsAsleep = 1 if any mon was asleep and got woken.
; ---------------------------------------------------------------------------
WakeUpEntireParty:
    mov edx, PARTYMON_STRUCT_LENGTH
.loop:
    mov al, [ebp + esi]
    push eax
    and al, SLP_MASK
    jz .notAsleep
    mov byte [ebp + wWereAnyMonsAsleep], 1
.notAsleep:
    pop eax
    and al, bl                       ; remove Sleep status, keep other bits
    mov [ebp + esi], al
    add esi, edx
    dec ecx
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; RestorePPAmount — restore PP of one move (Ether/Max Ether/Elixer/Max Elixer).
; In:  ESI (hl)        = the move's PP byte
;      [wMaxPP]        = the move's max PP
;      [wPPRestoreItem] = item id (MAX_ETHER fully restores)
; Faithfully reproduces the original Max-Ether/Max-Elixer bug: the full-restore
; path doesn't mask the PP-Up bits, so a maxed-PP move with PP Ups applied is
; not detected as "no effect".
; ---------------------------------------------------------------------------
RestorePPAmount:
    mov al, [ebp + wMaxPP]
    mov bl, al                       ; b (here bl) = max PP
    mov al, [ebp + wPPRestoreItem]
    cmp al, MAX_ETHER
    jz .fullyRestorePP

    mov al, [ebp + esi]
    and al, PP_MASK
    cmp al, bl                       ; already at max PP?
    jz .ret
    add al, 10                       ; +10 PP
    cmp al, bl                       ; meets/exceeds max?
    jnc .storeNewAmount              ; if so leave bl = max
    mov bl, al                       ; else new amount is the cap
.storeNewAmount:
    mov al, [ebp + esi]
    and al, PP_UP_MASK               ; keep the PP-Up bits
    add al, bl
    mov [ebp + esi], al
.ret:
    ret

.fullyRestorePP:
    ; BUG (faithful): upper two PP-Up bits not masked here (pret intentional).
    mov al, [ebp + esi]
    cmp al, bl
    jz .ret
    jmp .storeNewAmount

; ---------------------------------------------------------------------------
; ApplyHealingItem — add HP to a mon and clamp to its max HP (potions/revives).
; In:  ESI (hl) = mon's current-HP low byte (HP is big-endian: low byte first,
;                 high byte at hl-1, as in the party struct)
;      BL       = heal amount (caller picks it from the item; UI selection
;                 omitted). REVIVE sets HP to half max instead of adding.
;      [wCurItem] = item id (REVIVE / HYPER_POTION / MAX_REVIVE branch points)
; Out: mon HP updated; wHPBarNewHP (word) = the new current HP for the UI bar.
; ---------------------------------------------------------------------------
ApplyHealingItem:
    mov al, [ebp + esi]
    add al, bl
    mov [ebp + esi], al
    mov [ebp + wHPBarNewHP], al

    dec esi                          ; -> HP high byte
    mov al, [ebp + esi]
    mov [ebp + wHPBarNewHP+1], al
    jnc .noCarry
    inc al
    mov [ebp + esi], al
    mov [ebp + wHPBarNewHP+1], al
.noCarry:
    inc esi                          ; -> HP low byte
    mov edx, esi                     ; de = current-HP low byte

    mov ecx, edx
    add ecx, (MON_MAXHP + 1) - (MON_HP + 1)  ; ecx -> max-HP low byte

    mov al, [ebp + wCurItem]
    cmp al, REVIVE
    jz .setCurrentHPToHalfMaxHP

    ; compare current HP with max HP (16-bit, big-endian)
    mov al, [ebp + ecx]              ; max HP low
    mov bl, al
    mov al, [ebp + edx]              ; current HP low
    sub al, bl
    dec ecx                          ; -> max HP high (dec preserves CF)
    dec edx                          ; -> current HP high
    mov bl, [ebp + ecx]              ; max HP high
    mov al, [ebp + edx]              ; current HP high
    sbb al, bl
    jnc .setCurrentHPToMaxHp         ; current HP >= max HP after healing

    mov al, [ebp + wCurItem]
    cmp al, HYPER_POTION
    jc .setCurrentHPToMaxHp          ; Full Restore / Max Potion
    cmp al, MAX_REVIVE
    jz .setCurrentHPToMaxHp
    ret

.setCurrentHPToHalfMaxHP:
    dec ecx                          ; -> max HP high
    dec edx                          ; -> current HP high
    mov al, [ebp + ecx]
    shr al, 1                        ; max high >> 1, bit0 -> CF
    mov [ebp + edx], al
    mov [ebp + wHPBarNewHP+1], al
    inc ecx                          ; -> max HP low (inc preserves CF)
    inc edx                          ; -> current HP low
    mov al, [ebp + ecx]
    rcr al, 1                        ; rotate CF into max low >> 1
    mov [ebp + edx], al
    mov [ebp + wHPBarNewHP], al
    ret

.setCurrentHPToMaxHp:
    mov al, [ebp + ecx]              ; max HP high
    mov [ebp + edx], al
    mov [ebp + wHPBarNewHP+1], al
    inc ecx                          ; -> low bytes
    inc edx
    mov al, [ebp + ecx]              ; max HP low
    mov [ebp + edx], al
    mov [ebp + wHPBarNewHP], al
    ret

; ---------------------------------------------------------------------------
; CureStatusAilment — clear a status flag the item heals, if present.
; In:  ESI (hl)   = mon's status byte
;      [wCurItem] = the status-heal item id (Full Heal cures everything)
; Out: CF set if a curable status was present and cleared; CF clear (no effect)
;      otherwise. The cured-status message id (pret's b register) and in-battle
;      stat copy are UI/battle integration and omitted here.
; ---------------------------------------------------------------------------
CureStatusAilment:
    mov al, [ebp + wCurItem]
    mov cl, (1 << PSN)
    cmp al, ANTIDOTE
    jz .checkMonStatus
    mov cl, (1 << BRN)
    cmp al, BURN_HEAL
    jz .checkMonStatus
    mov cl, (1 << FRZ)
    cmp al, ICE_HEAL
    jz .checkMonStatus
    mov cl, SLP_MASK
    cmp al, AWAKENING
    jz .checkMonStatus
    mov cl, (1 << PAR)
    cmp al, PARLYZ_HEAL
    jz .checkMonStatus
    mov cl, 0xff                     ; FULL_HEAL: cure everything
.checkMonStatus:
    mov al, [ebp + esi]
    and al, cl                       ; any curable status set?
    jz .noEffect
    xor al, al
    mov [ebp + esi], al              ; clear status in party data
    stc
    ret
.noEffect:
    clc
    ret

; ---------------------------------------------------------------------------
; ApplyVitamin — add 2560 (256*10) stat experience for the matching stat.
; In:  ESI (hl)   = mon's party-struct base
;      [wCurItem] = vitamin id (HP_UP..CALCIUM; picks the stat by offset)
; Out: CF set if applied; CF clear (no effect) if that stat already has >= 25600
;      stat exp (MSB >= 100). Caller follows up with GetMonHeader + CalcStats to
;      re-derive the stats (that recalc needs the loaded header — UI-adjacent).
; The stat-exp word is big-endian; we touch only its MSB (the +2560 step).
; ---------------------------------------------------------------------------
ApplyVitamin:
    movzx ebx, byte [ebp + wCurItem]
    sub bl, HP_UP                    ; stat index 0..4
    add bl, bl                       ; *2 (word stride)
    lea ecx, [esi + MON_HP_EXP]      ; ecx -> HP stat-exp MSB
    add ecx, ebx                     ; -> chosen stat-exp MSB
    mov al, [ebp + ecx]
    cmp al, 100                      ; already >= 25600 stat exp?
    jnc .noEffect
    add al, 10                       ; +2560 stat exp
    jnc .store                       ; (al < 100 here, so carry is impossible)
    mov al, 255
.store:
    mov [ebp + ecx], al
    stc
    ret
.noEffect:
    clc
    ret

; ---------------------------------------------------------------------------
; RareCandyLevelUp — raise the mon one level: set experience to the new level's
; minimum, recalculate stats, and add the max-HP gain to current HP.
; In:  ESI (hl) = mon's party-struct base. PRECONDITION: GetMonHeader has loaded
;      this mon's base stats into wMonHeader (CalcStats reads it), exactly as
;      pret's shared .useVitamin entry does before reaching .useRareCandy.
; Out: CF set if leveled (level/exp/stats/HP updated, [wCurEnemyLevel] = new
;      level); CF clear (no effect) if already MAX_LEVEL. Move-learning,
;      evolution, the stats box and party-menu redraw are UI/engine follow-ups
;      handled elsewhere (deferred), so they are not done here.
; ---------------------------------------------------------------------------
RareCandyLevelUp:
    mov al, [ebp + esi + MON_LEVEL]
    cmp al, MAX_LEVEL
    jz .noEffect
    inc al
    mov [ebp + esi + MON_LEVEL], al
    mov [ebp + wCurEnemyLevel], al

    mov dh, al                       ; CalcExperience: DH = new level
    push esi
    call CalcExperience              ; -> H_EXPERIENCE (3 bytes, big-endian)
    pop esi
    ; copy H_EXPERIENCE to the mon's experience BEFORE any Multiply/CalcStats —
    ; H_EXPERIENCE aliases H_MULTIPLICAND, which CalcStats clobbers.
    mov al, [ebp + H_EXPERIENCE]
    mov [ebp + esi + MON_EXP], al
    mov al, [ebp + H_EXPERIENCE + 1]
    mov [ebp + esi + MON_EXP + 1], al
    mov al, [ebp + H_EXPERIENCE + 2]
    mov [ebp + esi + MON_EXP + 2], al

    ; remember old max HP (big-endian) so we can add the gain to current HP
    mov bh, [ebp + esi + MON_MAXHP]
    mov bl, [ebp + esi + MON_MAXHP + 1]
    push ebx
    push esi
    call RecalcMonStats              ; rewrites the 5 stats incl. new max HP
    pop esi
    pop ebx                          ; bh:bl = old max HP

    mov al, [ebp + esi + MON_MAXHP + 1]   ; new max HP low
    sub al, bl
    mov cl, al                            ; cl = HP gained, low
    mov al, [ebp + esi + MON_MAXHP]       ; new max HP high
    sbb al, bh
    mov ch, al                            ; ch = HP gained, high

    mov al, [ebp + esi + MON_HP + 1]      ; current HP low
    add al, cl
    mov [ebp + esi + MON_HP + 1], al
    mov al, [ebp + esi + MON_HP]          ; current HP high
    adc al, ch
    mov [ebp + esi + MON_HP], al
    stc
    ret
.noEffect:
    clc
    ret

; RecalcMonStats — pret .recalculateStats: CalcStats over the mon at ESI (base),
; considering stat exp. In: ESI = struct base. Tail-calls CalcStats (clobbers
; ESI/EDX/EBX and the H_MULTIPLICAND scratch); callers save the base if needed.
RecalcMonStats:
    mov edx, esi
    add edx, MON_STATS               ; de -> stats destination
    add esi, MON_EXP + 2             ; hl -> exp LSB == stat-exp base for CalcStat
    mov bh, 1                        ; consider stat exp
    jmp CalcStats

; ===========================================================================
; TossItem_ — confirm and toss an item (menus-port Session 4).
; pret ref: engine/items/item_effects.asm:TossItem_ (2829-2878).
;
; In:  ESI (hl) = inventory count addr (wNumBagItems / wNumBoxItems),
;      [wCurItem], [wWhichPokemon], [wItemQuantity].
; Out: CF clear if tossed, CF set if not (key item / HM / player chose No).
;
; DEVIATION(text): pret prints IsItOKToTossItemText / ThrewAwayItemText /
; TooImportantToTossText via PrintText (typewriter reveal in the message box).
; The port's PrintText_Overworld collapses the window list to the dialog alone
; (set_single_window), which would hide the item list beneath — on the GB the
; list survives in the BG tilemap. Until dialog printing can composite with
; existing windows (and the far-text streams exist as GB-space assets), the
; three dialogs are drawn whole into the message box (pret wording, ▼ +
; A/B-wait reproducing the texts' terminal `prompt`), appended over the list —
; visually matching the GB's list+dialog screen minus the per-letter reveal.
; ===========================================================================
global TossItem_

extern TextBoxBorder                 ; text/text.asm — ESI=top-left, BL=int_w, BH=int_h
extern place_flat_str                ; text/text.asm — ESI=dest, EAX=flat src
extern DelayFrame                    ; video/frame.asm
extern IsItemHM                      ; home/item_predicates.asm — AL → CF
extern IsKeyItem                     ; home/item_predicates.asm — [wCurItem] → [wIsKeyItem]
extern GetItemName                   ; home/names.asm — [wNamedObjectIndex] → wNameBuffer
extern CopyToStringBuffer            ; engine/battle/core.asm — EDX=src → wStringBuffer
extern RemoveItemFromInventory       ; engine/items/inventory.asm
extern InitYesNoTextBoxParameters    ; home/yes_no.asm — YES_NO_MENU at GB(14,7)
extern DisplayTextBoxID              ; home/textbox.asm
extern add_window                    ; ppu/ppu.asm
extern g_window_count                ; ppu/ppu.asm

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

; charmap glyphs
TI_CHAR_TERM  equ 0x50               ; '@'
TI_CHAR_QUEST equ 0xE6               ; ?
TI_CHAR_EXCL  equ 0xE7               ; !
TI_CHAR_DOT   equ 0xE8               ; .
TI_CHAR_DOWN  equ 0xEE               ; ▼
TI_TILE_SPC   equ 0x7F

section .data
align 4
; Toss dialog message lines — pret data/text/text_9.asm wording, GB charmap.
ti_msg_threw:  db 0x93,0xA7,0xB1,0xA4,0xB6,0x7F,0xA0,0xB6,0xA0,0xB8, TI_CHAR_TERM              ; "Threw away"
ti_msg_isok:   db 0x88,0xB2,0x7F,0xA8,0xB3,0x7F,0x8E,0x8A,0x7F,0xB3,0xAE,0x7F,0xB3,0xAE,0xB2,0xB2, TI_CHAR_TERM ; "Is it OK to toss"
; "That's too impor-" / "tant to toss!" ($BD = 's ligature, $E3 = '-')
ti_msg_imp1:   db 0x93,0xA7,0xA0,0xB3,0xBD,0x7F,0xB3,0xAE,0xAE,0x7F,0xA8,0xAC,0xAF,0xAE,0xB1,0xE3, TI_CHAR_TERM
ti_msg_imp2:   db 0xB3,0xA0,0xAD,0xB3,0x7F,0xB3,0xAE,0x7F,0xB3,0xAE,0xB2,0xB2, TI_CHAR_EXCL, TI_CHAR_TERM

section .bss
align 4
ti_saved_wc:   resd 1                ; g_window_count before the dialog appended

section .text

TossItem_:
    push esi                            ; push hl — inventory ptr
    mov al, [ebp + wCurItem]
    call IsItemHM                       ; CF = is HM
    pop esi                             ; pop hl
    jc .tooImportantToToss
    push esi
    call IsKeyItem                      ; pret IsKeyItem_ — [wCurItem] → [wIsKeyItem]
    mov al, [ebp + wIsKeyItem]
    pop esi
    test al, al                         ; and a
    jnz .tooImportantToToss
    push esi
    mov al, [ebp + wCurItem]
    mov [ebp + wNamedObjectIndex], al
    call GetItemName
    mov edx, wNameBuffer
    call CopyToStringBuffer
    ; "Is it OK to toss <wStringBuffer>?" (pret IsItOKToTossItemText + prompt)
    call ti_dialog_isok
    ; hlcoord 14,7 / lb bc,8,15 / TWO_OPTION_MENU — the port's two-option box
    ; takes its parameters from yes_no.asm state; InitYesNoTextBoxParameters
    ; sets exactly pret's YES_NO_MENU at GB(14,7).
    call InitYesNoTextBoxParameters
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    call DisplayTextBoxID               ; yes/no menu (appends + drops its window)
    mov al, [ebp + wMenuExitMethod]
    cmp al, CHOSE_SECOND_ITEM
    pop esi                             ; pop hl
    jne .choseYes
    call ti_dialog_drop                 ; port: drop the dialog window
    stc                                 ; player chose No
    ret
.choseYes:
    push esi
    call ti_dialog_drop                 ; drop the "Is it OK" dialog window before
                                        ; the "Threw away" dialog re-appends (same
                                        ; box region; avoids stacking a duplicate)
    mov al, [ebp + wWhichPokemon]       ; pret ld a,[wWhichPokemon] (worker reads it)
    call RemoveItemFromInventory        ; ESI = inventory ptr (passes through)
    mov al, [ebp + wCurItem]
    mov [ebp + wNamedObjectIndex], al
    call GetItemName
    mov edx, wNameBuffer
    call CopyToStringBuffer
    ; "Threw away <wNameBuffer>." (pret ThrewAwayItemText + prompt)
    call ti_dialog_threw
    call ti_dialog_drop
    pop esi                             ; pop hl
    clc                                 ; and a — tossed
    ret
.tooImportantToToss:
    push esi
    ; "That's too impor-/tant to toss!" (pret TooImportantToTossText + prompt)
    call ti_dialog_important
    call ti_dialog_drop
    pop esi
    stc
    ret

; ---------------------------------------------------------------------------
; Dialog plumbing (port; see DEVIATION note above). Each ti_dialog_* draws the
; message box into the stride-20 W_TILEMAP scratch rows 12-17, mirrors it to
; GB_TILEMAP1 rows 0-5, appends the dialog window (saving the count for
; ti_dialog_drop), and waits out the text's terminal `prompt` (▼ + A/B).
; ; PROJ menus: GB(0,12) 20x6 --(anchor=center/bottom, X+10, Y+7)--> wx=87
;   wy=152 clip=160 max_y=200 [UI_MESSAGE_BOX_*]
; ---------------------------------------------------------------------------
ti_dialog_isok:
    call ti_dialog_box
    mov esi, W_TILEMAP + 14 * 20 + 1
    mov eax, ti_msg_isok
    call place_flat_str
    lea eax, [ebp + wStringBuffer]      ; text_ram wStringBuffer
    mov esi, W_TILEMAP + 16 * 20 + 1
    call place_flat_str                 ; ESI advances past the name
    mov byte [ebp + esi], TI_CHAR_QUEST
    call ti_dialog_show
    jmp ti_dialog_prompt

ti_dialog_threw:
    call ti_dialog_box
    mov esi, W_TILEMAP + 14 * 20 + 1
    mov eax, ti_msg_threw
    call place_flat_str
    lea eax, [ebp + wNameBuffer]        ; text_ram wNameBuffer
    mov esi, W_TILEMAP + 16 * 20 + 1
    call place_flat_str
    mov byte [ebp + esi], TI_CHAR_DOT
    call ti_dialog_show
    jmp ti_dialog_prompt

ti_dialog_important:
    call ti_dialog_box
    mov esi, W_TILEMAP + 14 * 20 + 1
    mov eax, ti_msg_imp1
    call place_flat_str
    mov esi, W_TILEMAP + 16 * 20 + 1
    mov eax, ti_msg_imp2
    call place_flat_str
    call ti_dialog_show
    jmp ti_dialog_prompt

; draw the empty message-box border into scratch rows 12-17 (stride 20)
ti_dialog_box:
    mov esi, W_TILEMAP + 12 * 20
    mov bl, 18                          ; interior width  (total 20)
    mov bh, 4                           ; interior height (total 6)
    call TextBoxBorder
    ret

; mirror scratch rows 12-17 → GB_TILEMAP1 rows 0-5 (pad cols 20-31), append
; the dialog descriptor (remembering the caller's window count).
ti_dialog_show:
    pushad
    mov ecx, 6
    lea esi, [ebp + W_TILEMAP + 12 * 20]
    lea edi, [ebp + GB_TILEMAP1]
.row:
    push ecx
    push edi
    mov ecx, 20
    rep movsb
    mov al, TI_TILE_SPC
    mov ecx, 12                         ; pad cols 20-31
    rep stosb
    pop edi
    pop ecx
    add edi, 32
    dec ecx
    jnz .row
    mov eax, [g_window_count]
    mov [ti_saved_wc], eax
    mov eax, UI_MESSAGE_BOX_WX          ; 87 — the overworld dialog anchor
    mov ebx, UI_MESSAGE_BOX_WY          ; 152
    mov ecx, UI_MESSAGE_BOX_CLIP        ; 160
    mov edx, UI_MESSAGE_BOX_MAXY        ; 200
    mov esi, GB_TILEMAP1
    xor edi, edi
    call add_window
    popad
    ret

; ▼ + wait for an A/B press cycle (the texts' terminal `prompt`), clear the ▼.
ti_dialog_prompt:
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], TI_CHAR_DOWN
.release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .release
.press:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jz .press
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], TI_TILE_SPC
    ret

; drop the dialog window (restore the count ti_dialog_show saved)
ti_dialog_drop:
    push eax
    mov eax, [ti_saved_wc]
    mov [g_window_count], eax
    pop eax
    ret

; ===========================================================================
; IsNextTileShoreOrWater — pret engine/items/item_effects.asm:3118 (OW-A.6).
; CF=1 if the tile in front of the player (wTileInFrontOfPlayer, pre-read by
; the caller via the front-tile helper) is water — or a shore tile, on the
; tilesets that treat shore as surfable. CF=0 otherwise (incl. tilesets with
; no water at all). Consumed by CollisionCheckOnWater (surf collision) and,
; later, the Good Rod / Super Rod + Surf item-use checks.
; Clobbers AL, BH, CL, ESI, EDX (IsInArray ABI: AL=value, ESI=flat table,
; EDX=stride; CF=1 found).
; ===========================================================================

global IsNextTileShoreOrWater

extern IsInArray                     ; src/home/array.asm

; Tileset ids (OVERWORLD/FOREST/DOJO/GYM/SHIP/SHIP_PORT/CAVERN/FACILITY/
; PLATEAU) come from the generated assets/map_dims.inc TILESET_IDS block.
%include "assets/map_dims.inc"

section .data
; pret data/tilesets/water_tilesets.asm (inlined, port convention for small
; pret data includes). ShoreTiles deliberately falls through into WaterTile —
; the shore lists END at WaterTile's -1 terminator, exactly as in pret.
WaterTilesets:
    db OVERWORLD
    db FOREST
    db DOJO
    db GYM
    db SHIP
    db SHIP_PORT
    db CAVERN
    db FACILITY
    db PLATEAU
    db -1                            ; end
ShoreTiles:                          ; tiles that allow surfing and fishing,
    db 0x48, 0x32                    ; depending on the tileset (see IsNextTileShoreOrWater)
    ; fallthrough
WaterTile:
    db 0x14
    db -1                            ; end

section .text

IsNextTileShoreOrWater:
    mov al, [ebp + W_CUR_MAP_TILESET]
    mov esi, WaterTilesets           ; ld hl, WaterTilesets (flat table)
    mov edx, 1                       ; ld de, 1
    call IsInArray                   ; does the current map allow surfing?
    jnc .done                        ; ret nc — no water in this tileset (CF=0)
    mov esi, WaterTile               ; ld hl, WaterTile
    mov al, [ebp + W_CUR_MAP_TILESET]
    cmp al, SHIP_PORT                ; Vermilion Dock: water tile only
    je .skipShoreTiles
    cmp al, GYM                      ; Cerulean Gym pool: water tile only
    je .skipShoreTiles
    cmp al, DOJO                     ; (shares the GYM tile behavior)
    je .skipShoreTiles
    mov esi, ShoreTiles              ; ld hl, ShoreTiles
.skipShoreTiles:
    mov al, [ebp + W_TILE_IN_FRONT_OF_PLAYER]
    mov edx, 1                       ; ld de, 1
    call IsInArray                   ; CF=1 → tile is shore/water
.done:
    ret

; ---------------------------------------------------------------------------
; RestoreBonusPP — re-apply each PP-Up bonus to the PP slots of the mon at
; [wWhichPokemon]. Pret ref: engine/items/item_effects.asm:RestoreBonusPP.
;
; Called per party mon by HealParty (engine/events/heal_party.asm), and by the
; PP-Up item path once item USE lands. When [wUsingPPUp] == 1 only the move at
; [wCurrentMenuItem] is touched (a PP Up is being applied right now); otherwise
; every move gets its full stored PP-Up bonus re-added (the heal case).
;
; DIVERGENCE (predef → direct call, port-wide): pret reaches LoadMovePPs through
; `predef`; the port has no bank/predef dispatch, so we stage wPredefHL/wPredefDE
; (big-endian, as GetPredefRegisters reads them) and CALL LoadMovePPs directly —
; the same idiom as engine/battle/load_enemy_moves.asm. LoadMovePPs clobbers
; ESI/EDX/EBX via GetPredefRegisters, so ESI is saved across it exactly where
; pret pushes hl.
;
; In:  [wWhichPokemon] = party index.  Clobbers AL, ECX, EDX, ESI; BH = 4 on exit.
; ---------------------------------------------------------------------------
global RestoreBonusPP
RestoreBonusPP:
    mov esi, wPartyMon1Moves                 ; ld hl, wPartyMon1Moves
    mov bx, PARTYMON_STRUCT_LENGTH           ; ld bc, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wWhichPokemon]
    call AddNTimes                           ; ESI += wWhichPokemon * 44

    push esi                                 ; push hl
    ; predef LoadMovePPs: hl = this mon's move ids, de = wNormalMaxPPList - 1
    mov ecx, esi
    mov [ebp + wPredefHL], ch                ; big-endian: high byte first
    mov [ebp + wPredefHL + 1], cl
    mov ecx, wNormalMaxPPList - 1
    mov [ebp + wPredefDE], ch
    mov [ebp + wPredefDE + 1], cl
    call LoadMovePPs                         ; → wNormalMaxPPList[0..3]
    pop esi                                  ; pop hl

    add esi, MON_PP - MON_MOVES              ; ld c,MON_PP-MON_MOVES / ld b,0 / add hl,bc
    mov edx, wNormalMaxPPList                ; ld de, wNormalMaxPPList
    xor bh, bh                               ; ld b, 0 — move counter
.loop:
    inc bh                                   ; inc b
    cmp bh, 5                                ; reached the end of the moves?
    je .done                                 ; ret z
    mov al, [ebp + wUsingPPUp]
    dec al                                   ; using a PP Up?
    jnz .skipMenuItemIDCheck
    ; applying a PP Up: only touch the move it is used on
    mov al, [ebp + wCurrentMenuItem]
    inc al
    cmp al, bh
    jne .nextMove
.skipMenuItemIDCheck:
    mov al, [ebp + esi]                      ; move PP byte (PP-Up bits in 7-6)
    and al, PP_UP_MASK                       ; ZF set => no PP Ups on this move
    jz .nextMove                             ; pret: call nz, AddBonusPP
    call AddBonusPP                          ; EDX = normal max PP addr, ESI = PP byte
.nextMove:
    inc esi                                  ; inc hl
    inc edx                                  ; inc de
    jmp .loop
.done:
    ret
