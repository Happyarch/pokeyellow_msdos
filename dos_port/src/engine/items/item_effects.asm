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
%include "assets/event_constants.inc"   ; EVENT_* bit indices (ItemUseBall's catch flags)
%include "events.inc"                   ; CheckEvent over W_EVENT_FLAGS

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

; --------------------------------------------------------------------------

; === UseItem_ / ItemUsePtrTable dispatch + the medicine family (Stage 5) ===
;
;
; Source: engine/items/item_effects.asm (pret/pokeyellow), lines 1-103 (UseItem_
; + the pointer table), 898-1565 (ItemUseVitamin / ItemUseMedicine) and the
; shared tails at 2396-2600 (UnusableItem, RemoveUsedItem, ItemUseNoEffect,
; ItemUseNotTime, ItemUseNotYoursToUse, Func_e4bf, ItemUseFailed).
;
; The remaining ItemUse* families (balls, TM/HM, evo stones, repels, battle
; items, key items, rods) are ret-stubs in item_use_stubs.asm — see
; docs/current_plan_items.md stages 6-11.
;
; Register map (CLAUDE.md): a=AL, b=BH, c=BL, d=DH, e=DL, hl=ESI, de=EDX,
; bc=EBX; GB memory at [EBP + addr]. GB data (HP, max HP, stat exp) is
; BIG-endian and stays that way.
;
; ---------------------------------------------------------------------------
; PORT DEVIATIONS (justified; each names what retires it)
;
; 1. DEVIATION(video) — `predef UpdateHPBar2` (the animated party-menu HP bar,
;    twice: the Softboiled drain and the heal fill) is NOT called: the port has
;    no party-menu HP-bar animator (engine/gfx/hp_bar.asm ports the length
;    predef; battle_hud.asm's AnimateHPBar is battle-HUD-coordinate-bound).
;    RedrawPartyMenu below redraws the bar at its final length, so the healed
;    value is shown — it just doesn't sweep. The one *observable* side effect of
;    pret's UpdateHPBar that outlives the animation is wHPBarHPDifference, which
;    PotionText prints ("recovered by N!"), so we compute it here.
;    Retired by: a party-menu HP-bar animator (items-plan Stage 5 tail).
;
; 2. DEVIATION(text/window) — pret prints through PrintText, which composites the
;    message box over the live screen buffer. The port's PrintText_Overworld
;    collapses the window list to the dialog alone (set_single_window), so the
;    bag list / party panel beneath it disappears for the duration. Every caller
;    of these refusal texts redraws its screen right after (StartMenu_Item's
;    reload, or .done's ReloadMapData), so the end state matches; the transient
;    does not. Same DEVIATION TossItem_ carries (item_effects.asm).
;    Retired by: a dialog printer that composites with the existing windows.
;
; 3. DEVIATION(palette) — `call z, RunDefaultPaletteCommand` after GBPalWhiteOut
;    is a TODO-HW boundary (SGB/CGB palette commands, Phase 5).
;
; 4. predef → direct call (port-wide, no bank/predef dispatch): FlagActionPredef
;    becomes `call FlagAction` (same idiom as home/item_predicates.asm),
;    LearnMoveFromLevelUp / PrintStatsBox are called directly.
;
; Build: nasm -f coff -I include/ -I . -o item_use.o src/engine/items/item_use.asm


%include "assets/audio_constants.inc"

global UseItem_
global ItemUsePtrTable
global ItemUseVitamin
global ItemUseMedicine
global UnusableItem
global RemoveUsedItem
global ItemUseNoEffect
global ItemUseNotTime
global ItemUseNotYoursToUse
global ItemUseFailed
global Func_e4bf
global iu_print_text                 ; port-only: the item layer's overworld text printer

; --- the medicine family's effect cores (items-plan Stage 3, native-validated) ---
extern ApplyHealingItem     ; item_effects.asm — pret .addHealAmount…setCurrentHPToMaxHp
extern ApplyVitamin         ; item_effects.asm — pret .useVitamin's stat-exp add
extern RareCandyLevelUp     ; item_effects.asm — pret .useRareCandy's level/exp/stat math
extern RemoveItemFromInventory ; inventory.asm
extern VitaminStats         ; data/item_data.asm (generated) — 5 × STAT_NAME_LENGTH

; --- party menu / mon data ---
extern DisplayPartyMenu     ; home/pokemon.asm — CF=1 if no mon chosen
extern GoBackToPartyMenu    ; home/pokemon.asm
extern RedrawPartyMenu      ; home/pokemon.asm
extern GetPartyMonName      ; home/pokemon.asm — AL = index, ESI = name list
extern GetMonHeader         ; home/pokemon.asm — [wCurSpecies] → wMonHeader
extern LoadMonData          ; engine/pokemon/load_mon_data.asm
extern CalcStats            ; home/move_mon.asm
extern AddNTimes            ; home/array.asm — ESI += AL*BX
extern CopyData             ; home/copy_data.asm — ESI → EDX, BX bytes
extern Divide               ; home/math.asm — BH = dividend bytes
extern FlagAction           ; engine/flag_action.asm — ESI=array, CL=index, BH=action
extern PrintStatsBox        ; engine/battle/battle_menu.asm — DH = box type
extern LearnMoveFromLevelUp ; engine/battle/battle_menu.asm (predef)
extern TryEvolvingMon       ; engine/pokemon/evolution.asm
extern ModifyPikachuHappiness    ; battle_exp_stubs.asm (deferred)
extern RespawnOverworldPikachu   ; battle_exp_stubs.asm (deferred)
extern DoubleOrHalveSelectedStats ; battle_exp_stubs.asm (deferred)

; --- screen / text / sound ---
extern ClearScreen          ; movie/title.asm (pret home/copy2.asm)
extern GBPalWhiteOut        ; home/fade.asm
extern ReloadMapData        ; home/reload_tiles.asm
extern DelayFrames          ; video/frame.asm — BL = frames
extern WaitForTextScrollButtonPress ; engine/battle/battle_menu.asm
extern ItemUseText00_ref            ; assets/item_text.inc — "<PLAYER> used <ITEM>!"
extern PrintText_Overworld  ; home/text.asm — ESI = GB-space TX stream
extern PlaySound            ; home/audio.asm — AL = sound id
extern PlaySoundWaitForCurrent ; home/audio.asm

; --- generated text streams (assets/item_text.inc, flat .data) ---
; Each `<Label>_ref` is the generator's {dd stream, dd length} pair: iu_print_text
; needs the byte count to stage the stream in GB space, and a cross-object
; `Label_end - Label` is not a relocatable immediate.
extern ItemUseNoEffectText_ref
extern ItemUseNotTimeText_ref
extern ItemUseNotYoursToUseText_ref
extern DontHavePokemonText_ref
extern VitaminStatRoseText_ref
extern VitaminNoEffectText_ref

; --- the deferred ItemUse* families (item_use_stubs.asm) ---
extern ItemUseTownMap
extern ItemUseBicycle
extern ItemUseSurfboard
extern ItemUsePokedex
extern ItemUseEvoStone
extern ItemUseBait
extern ItemUseRock
extern ItemUseEscapeRope
extern ItemUseRepel
extern ItemUseSuperRepel
extern ItemUseMaxRepel
extern ItemUseXAccuracy
extern ItemUseCardKey
extern ItemUsePokeDoll
extern ItemUseGuardSpec
extern ItemUseDireHit
extern ItemUseXStat
extern ItemUseCoinCase
extern ItemUseOaksParcel
extern ItemUseItemfinder
extern ItemUsePokeFlute
extern ItemUseOldRod
extern ItemUseGoodRod
extern ItemUseSuperRod
extern ItemUsePPUp
extern ItemUsePPRestore
extern ItemUseTMHM

section .data
align 4

; ---------------------------------------------------------------------------
; ItemUsePtrTable — one entry per item id (1..MAX_ELIXER). Tier-2 CODE: a
; pointer table is hand-written in the .asm (never generated), keyed by the item
; id the generated data tables use. pret stores `dw`; the port stores flat `dd`.
; pret ref: engine/items/item_effects.asm:18.
; ---------------------------------------------------------------------------
ItemUsePtrTable:
    dd ItemUseBall          ; MASTER_BALL
    dd ItemUseBall          ; ULTRA_BALL
    dd ItemUseBall          ; GREAT_BALL
    dd ItemUseBall          ; POKE_BALL
    dd ItemUseTownMap       ; TOWN_MAP
    dd ItemUseBicycle       ; BICYCLE
    dd ItemUseSurfboard     ; SURFBOARD
    dd ItemUseBall          ; SAFARI_BALL
    dd ItemUsePokedex       ; POKEDEX
    dd ItemUseEvoStone      ; MOON_STONE
    dd ItemUseMedicine      ; ANTIDOTE
    dd ItemUseMedicine      ; BURN_HEAL
    dd ItemUseMedicine      ; ICE_HEAL
    dd ItemUseMedicine      ; AWAKENING
    dd ItemUseMedicine      ; PARLYZ_HEAL
    dd ItemUseMedicine      ; FULL_RESTORE
    dd ItemUseMedicine      ; MAX_POTION
    dd ItemUseMedicine      ; HYPER_POTION
    dd ItemUseMedicine      ; SUPER_POTION
    dd ItemUseMedicine      ; POTION
    dd ItemUseBait          ; BOULDERBADGE
    dd ItemUseRock          ; CASCADEBADGE
    dd UnusableItem         ; THUNDERBADGE
    dd UnusableItem         ; RAINBOWBADGE
    dd UnusableItem         ; SOULBADGE
    dd UnusableItem         ; MARSHBADGE
    dd UnusableItem         ; VOLCANOBADGE
    dd UnusableItem         ; EARTHBADGE
    dd ItemUseEscapeRope    ; ESCAPE_ROPE
    dd ItemUseRepel         ; REPEL
    dd UnusableItem         ; OLD_AMBER
    dd ItemUseEvoStone      ; FIRE_STONE
    dd ItemUseEvoStone      ; THUNDER_STONE
    dd ItemUseEvoStone      ; WATER_STONE
    dd ItemUseVitamin       ; HP_UP
    dd ItemUseVitamin       ; PROTEIN
    dd ItemUseVitamin       ; IRON
    dd ItemUseVitamin       ; CARBOS
    dd ItemUseVitamin       ; CALCIUM
    dd ItemUseVitamin       ; RARE_CANDY
    dd UnusableItem         ; DOME_FOSSIL
    dd UnusableItem         ; HELIX_FOSSIL
    dd UnusableItem         ; SECRET_KEY
    dd UnusableItem         ; ITEM_2C
    dd UnusableItem         ; BIKE_VOUCHER
    dd ItemUseXAccuracy     ; X_ACCURACY
    dd ItemUseEvoStone      ; LEAF_STONE
    dd ItemUseCardKey       ; CARD_KEY
    dd UnusableItem         ; NUGGET
    dd UnusableItem         ; ITEM_32
    dd ItemUsePokeDoll      ; POKE_DOLL
    dd ItemUseMedicine      ; FULL_HEAL
    dd ItemUseMedicine      ; REVIVE
    dd ItemUseMedicine      ; MAX_REVIVE
    dd ItemUseGuardSpec     ; GUARD_SPEC
    dd ItemUseSuperRepel    ; SUPER_REPEL
    dd ItemUseMaxRepel      ; MAX_REPEL
    dd ItemUseDireHit       ; DIRE_HIT
    dd UnusableItem         ; COIN
    dd ItemUseMedicine      ; FRESH_WATER
    dd ItemUseMedicine      ; SODA_POP
    dd ItemUseMedicine      ; LEMONADE
    dd UnusableItem         ; S_S_TICKET
    dd UnusableItem         ; GOLD_TEETH
    dd ItemUseXStat         ; X_ATTACK
    dd ItemUseXStat         ; X_DEFEND
    dd ItemUseXStat         ; X_SPEED
    dd ItemUseXStat         ; X_SPECIAL
    dd ItemUseCoinCase      ; COIN_CASE
    dd ItemUseOaksParcel    ; OAKS_PARCEL
    dd ItemUseItemfinder    ; ITEMFINDER
    dd UnusableItem         ; SILPH_SCOPE
    dd ItemUsePokeFlute     ; POKE_FLUTE
    dd UnusableItem         ; LIFT_KEY
    dd UnusableItem         ; EXP_ALL
    dd ItemUseOldRod        ; OLD_ROD
    dd ItemUseGoodRod       ; GOOD_ROD
    dd ItemUseSuperRod      ; SUPER_ROD
    dd ItemUsePPUp          ; PP_UP
    dd ItemUsePPRestore     ; ETHER
    dd ItemUsePPRestore     ; MAX_ETHER
    dd ItemUsePPRestore     ; ELIXER
    dd ItemUsePPRestore     ; MAX_ELIXER
ItemUsePtrTable_end:

section .bss
align 4
iu_mon_base:  resd 1        ; the selected party mon's struct base (pret keeps this
                            ; on the stack across the heal math; the port re-derives
                            ; its HP/status/maxHP pointers from it instead)
iu_softboiled_heal: resd 1  ; Softboiled's 1/5-max-HP heal amount (pret's pushed af)

section .text

; ===========================================================================
; UseItem_ — pret ref: engine/items/item_effects.asm:1.
; In:  [wCurItem]. Out: [wActionResultOrTookBattleTurn] (0 fail / 1 ok / 2 no menu).
; ===========================================================================
UseItem_:
    mov byte [ebp + wActionResultOrTookBattleTurn], 1  ; initialise to success value
    mov al, [ebp + wCurItem]
    cmp al, HM01
    jae ItemUseTMHM                     ; jp nc, ItemUseTMHM
    dec al                              ; dec a
    movzx eax, al
    jmp [ItemUsePtrTable + eax * 4]     ; pret: add a / add hl,bc / ld a,[hli] / jp hl

; ===========================================================================
; ItemUseVitamin / ItemUseMedicine — pret ref: item_effects.asm:898 / 903.
; ===========================================================================
ItemUseVitamin:
    mov al, [ebp + wIsInBattle]
    test al, al
    jnz ItemUseNotTime                  ; jp nz — vitamins can't be used in battle
    ; fall through

ItemUseMedicine:
    mov al, [ebp + wPartyCount]
    test al, al
    jz Func_e4bf                        ; jp z — "You don't have a #MON!"
    movzx eax, byte [ebp + wWhichPokemon]
    push eax                            ; push af — the bag's list index
    movzx eax, byte [ebp + wCurItem]
    push eax                            ; push af
    mov byte [ebp + wPartyMenuTypeOrMessageID], USE_ITEM_PARTY_MENU
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF
    mov al, [ebp + wPseudoItemID]
    test al, al                         ; using Softboiled?
    jz .notUsingSoftboiled
    call GoBackToPartyMenu
    jmp .getPartyMonDataAddress
.notUsingSoftboiled:
    call DisplayPartyMenu
.getPartyMonDataAddress:
    jc .canceledItemUse                 ; jp c — B pressed

    mov esi, wPartyMons
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wWhichPokemon]
    call AddNTimes                      ; ESI = the chosen mon's struct base
    mov [iu_mon_base], esi
    mov al, [ebp + wWhichPokemon]
    mov [ebp + wUsedItemOnWhichPokemon], al
    mov dh, al                          ; ld d, a — party index
    mov al, [ebp + wCurPartySpecies]
    mov dl, al                          ; ld e, a
    mov [ebp + wCurSpecies], al

    pop eax                             ; pop af (wCurItem)
    push eax                            ; push af
    cmp al, CALCIUM + 1
    jae .noHappinessBoost               ; jr nc
    push esi
    push edx
    mov al, PIKAHAPPY_USEDITEM
    call ModifyPikachuHappiness         ; farcall_ModifyPikachuHappiness
    pop edx
    pop esi
.noHappinessBoost:
    pop eax
    mov [ebp + wCurItem], al
    pop eax
    mov [ebp + wWhichPokemon], al       ; restore the bag's list index

    mov al, [ebp + wPseudoItemID]
    test al, al                         ; using Softboiled?
    jz .checkItemType
    mov al, [ebp + wWhichPokemon]
    cmp al, dh                          ; Softboiled on the mon that used it?
    jz ItemUseMedicine                  ; if so, force another choice
.checkItemType:
    mov al, [ebp + wCurItem]
    cmp al, REVIVE
    jae .healHP                         ; jr nc — Revive or Max Revive
    cmp al, FULL_HEAL
    jz .cureStatusAilment
    cmp al, HP_UP
    jae .useVitamin                     ; jp nc — vitamin or Rare Candy
    cmp al, FULL_RESTORE
    jae .healHP                         ; jr nc — Full Restore or a potion
    ; fall through — a status-specific healing item

; --- pret .cureStatusAilment (item_effects.asm:967) ------------------------
; ESI = struct base on entry; DH = party index, DL = species.
; NOTE: item_effects.asm's Stage-3 CureStatusAilment core computes the same mask
; but discards pret's message id (its `b`), which wPartyMenuTypeOrMessageID needs
; here — so the cmp chain is inlined, exactly as pret writes it. The core stays
; for its native test / the battle-item path.
.cureStatusAilment:
    add esi, MON_STATUS                 ; ld bc,MON_STATUS / add hl,bc
    mov al, [ebp + wCurItem]
    mov bh, ANTIDOTE_MSG                ; lb bc, ANTIDOTE_MSG, 1 << PSN
    mov bl, 1 << PSN
    cmp al, ANTIDOTE
    jz .checkMonStatus
    mov bh, BURN_HEAL_MSG
    mov bl, 1 << BRN
    cmp al, BURN_HEAL
    jz .checkMonStatus
    mov bh, ICE_HEAL_MSG
    mov bl, 1 << FRZ
    cmp al, ICE_HEAL
    jz .checkMonStatus
    mov bh, AWAKENING_MSG
    mov bl, SLP_MASK
    cmp al, AWAKENING
    jz .checkMonStatus
    mov bh, PARALYZ_HEAL_MSG
    mov bl, 1 << PAR
    cmp al, PARLYZ_HEAL
    jz .checkMonStatus
    mov bh, FULL_HEAL_MSG               ; lb bc, FULL_HEAL_MSG, $ff
    mov bl, 0xFF
.checkMonStatus:
    mov al, [ebp + esi]                 ; the mon's status
    and al, bl                          ; a status this item can cure?
    jz .healingItemNoEffect
    mov byte [ebp + esi], 0             ; remove it from the party data
    mov [ebp + wPartyMenuTypeOrMessageID], bh   ; the message to show
    mov al, [ebp + wPlayerMonNumber]
    cmp al, dh                          ; is this mon the active battler?
    jne .doneHealing                    ; jp nz
    mov byte [ebp + wBattleMonStatus], 0
    and byte [ebp + wPlayerBattleStatus3], (~(1 << BADLY_POISONED)) & 0xFF ; heal Toxic
    ; copy the party stats into the in-battle stat data
    mov esi, [iu_mon_base]
    add esi, MON_STATS
    mov edx, wBattleMonStats
    mov bx, NUM_STATS * 2
    call CopyData                       ; ESI → EDX (dest is EDX, not EDI)
    call DoubleOrHalveSelectedStats     ; predef
    mov dh, [ebp + wUsedItemOnWhichPokemon]  ; CopyData clobbered EDX
    jmp .doneHealing

; --- pret .healHP (item_effects.asm:1014) ---------------------------------
.healHP:
    mov esi, [iu_mon_base]
    add esi, MON_HP                     ; inc hl — hl = current HP (high byte)
    mov bh, [ebp + esi]                 ; ld a,[hli] / ld b,a
    mov [ebp + wHPBarOldHP + 1], bh
    inc esi
    mov bl, [ebp + esi]                 ; ld a,[hl] / ld c,a
    mov [ebp + wHPBarOldHP], bl         ; current HP at wHPBarOldHP (big-endian)
    mov al, bl
    or al, bh                           ; or b — is the mon fainted?
    jnz .notFainted
    ; fainted
    mov al, [ebp + wCurItem]
    cmp al, REVIVE
    jz .updateInBattleFaintedData
    cmp al, MAX_REVIVE
    jz .updateInBattleFaintedData
    jmp .healingItemNoEffect

.updateInBattleFaintedData:
    call .respawnPikachuForUsedMon      ; pret: swap wWhichPokemon / RespawnOverworldPikachu
    mov al, [ebp + wIsInBattle]
    test al, al
    jz .compareCurrentHPToMaxHP
    ; a revived mon that fought this battle re-joins the EXP split
    mov cl, [ebp + wUsedItemOnWhichPokemon]
    mov esi, wPartyFoughtCurrentEnemyFlags
    mov bh, FLAG_TEST
    call FlagAction                     ; predef FlagActionPredef → CL = the flag
    test cl, cl
    jz .next
    mov cl, [ebp + wUsedItemOnWhichPokemon]
    mov esi, wPartyGainExpFlags
    mov bh, FLAG_SET
    call FlagAction
.next:
    mov dh, [ebp + wUsedItemOnWhichPokemon]  ; FlagAction clobbered EDX
    jmp .compareCurrentHPToMaxHP

.notFainted:
    mov al, [ebp + wCurItem]
    cmp al, REVIVE
    jz .healingItemNoEffect             ; jp z — a Revive on a healthy mon
    cmp al, MAX_REVIVE
    jz .healingItemNoEffect

.compareCurrentHPToMaxHP:
    ; BH:BL still hold the current HP (big-endian) read above.
    mov esi, [iu_mon_base]
    mov al, [ebp + esi + MON_MAXHP]     ; max HP high
    cmp al, bh
    jne .skipComparingLSB               ; no need to compare the LSBs if the MSBs differ
    mov al, [ebp + esi + MON_MAXHP + 1] ; max HP low
    cmp al, bl
.skipComparingLSB:
    jnz .notFullHP
    ; current HP == max HP
    mov al, [ebp + wCurItem]
    cmp al, FULL_RESTORE
    jne .healingItemNoEffect            ; jp nz
    mov al, [ebp + esi + MON_STATUS]    ; does it at least have a status ailment?
    test al, al
    jz .healingItemNoEffect
    mov byte [ebp + wCurItem], FULL_HEAL
    jmp .cureStatusAilment              ; (ESI = struct base, as .cureStatusAilment wants)

.notFullHP:
    mov byte [ebp + wLowHealthAlarm], 0 ; disable the low-health alarm
    mov byte [ebp + wChannelSoundIDs + CHAN5], 0
    ; wHPBarMaxHP = the mon's max HP (big-endian)
    mov al, [ebp + esi + MON_MAXHP]
    mov [ebp + wHPBarMaxHP + 1], al
    mov al, [ebp + esi + MON_MAXHP + 1]
    mov [ebp + wHPBarMaxHP], al

    mov al, [ebp + wPseudoItemID]
    test al, al                         ; using Softboiled?
    jz .notUsingSoftboiled2
    call .softboiledDrain               ; take 1/5 max HP off the mon that used it
    mov bl, [iu_softboiled_heal]        ; ld b,a — the heal amount
    jmp .addHealAmount

.notUsingSoftboiled2:
    mov al, [ebp + wCurItem]
    cmp al, SODA_POP
    mov bl, 60                          ; Soda Pop heal amount
    jz .addHealAmount
    mov bl, 80                          ; Lemonade heal amount
    jnc .addHealAmount                  ; jr nc (item > SODA_POP: LEMONADE)
    cmp al, FRESH_WATER
    mov bl, 50                          ; Fresh Water heal amount
    jz .addHealAmount
    cmp al, SUPER_POTION
    mov bl, 200                         ; Hyper Potion heal amount
    jc .addHealAmount                   ; item < SUPER_POTION → HYPER/MAX/FULL_RESTORE
    mov bl, 50                          ; Super Potion heal amount
    jz .addHealAmount
    mov bl, 20                          ; Potion heal amount

.addHealAmount:
    ; pret .addHealAmount…setCurrentHPToMaxHp == the Stage-3 ApplyHealingItem core
    ; (add BL, clamp to max HP / half max HP for Revive, publish wHPBarNewHP).
    mov esi, [iu_mon_base]
    add esi, MON_HP + 1                 ; ESI = current-HP LOW byte, the core's input
    call ApplyHealingItem

.doneHealingPartyHP:
    ; wHPBarHPDifference = new HP - old HP. Mind the two byte orders: wHPBarOldHP /
    ; wHPBarNewHP hold the low byte at +0 (item_effects.asm:1020 writes the high
    ; byte to +1), but wHPBarHPDifference is BIG-endian — pret's UpdateHPBar stores
    ; d (high) at +0 and e (low) at +1 (engine/gfx/hp_bar.asm:63-66), and that is
    ; the order PotionText's `text_decimal wHPBarHPDifference, 2, 3` reads.
    ; pret computes this while animating the bar; only the HP path publishes it,
    ; exactly as in pret. See DEVIATION 1.
    mov al, [ebp + wHPBarNewHP]
    sub al, [ebp + wHPBarOldHP]         ; low byte first — sets the borrow
    mov [ebp + wHPBarHPDifference + 1], al
    mov al, [ebp + wHPBarNewHP + 1]
    sbb al, [ebp + wHPBarOldHP + 1]     ; high byte (inc/mov above would keep CF)
    mov [ebp + wHPBarHPDifference], al

    mov esi, [iu_mon_base]
    mov al, [ebp + wCurItem]
    cmp al, FULL_RESTORE
    jne .updateInBattleData
    mov byte [ebp + esi + MON_STATUS], 0  ; Full Restore also clears the status

.updateInBattleData:
    mov dh, [ebp + wUsedItemOnWhichPokemon]  ; ApplyHealingItem clobbered EDX
    mov al, [ebp + wPlayerMonNumber]
    cmp al, dh                          ; is this mon the active battler?
    jne .doneHealing
    ; copy the party HP into the in-battle HP (big-endian, high byte first)
    mov al, [ebp + esi + MON_HP]
    mov [ebp + wBattleMonHP], al
    mov al, [ebp + esi + MON_HP + 1]
    mov [ebp + wBattleMonHP + 1], al
    mov al, [ebp + wCurItem]
    cmp al, FULL_RESTORE
    jne .doneHealing
    mov byte [ebp + wBattleMonStatus], 0
    ; pret's .calculateHPBarCoords (hlcoord 4,-1 + d rows) feeds UpdateHPBar2,
    ; which the port does not run — see DEVIATION 1. RedrawPartyMenu redraws the
    ; bar from the party data instead, so no coordinate is needed.
    jmp .doneHealing

.healingItemNoEffect:
    call ItemUseNoEffect
    jmp .done

.doneHealing:
    mov al, [ebp + wPseudoItemID]
    test al, al                         ; using Softboiled? (no item to remove)
    jnz .skipRemovingItem
    call RemoveUsedItem
.skipRemovingItem:
    mov al, [ebp + wCurItem]
    cmp al, FULL_RESTORE
    jb .playStatusAilmentCuringSound    ; jr c — a status-specific healing item
    cmp al, FULL_HEAL
    jz .playStatusAilmentCuringSound
    mov al, SFX_HEAL_HP
    call PlaySoundWaitForCurrent
    ; predef UpdateHPBar2 (animate the bar filling) — DEVIATION 1.
    mov byte [ebp + wHPBarType], 0x02
    mov byte [ebp + wPartyMenuTypeOrMessageID], REVIVE_MSG
    mov al, [ebp + wCurItem]
    cmp al, REVIVE
    jz .showHealingItemMessage
    cmp al, MAX_REVIVE
    jz .showHealingItemMessage
    mov byte [ebp + wPartyMenuTypeOrMessageID], POTION_MSG
    jmp .showHealingItemMessage

.playStatusAilmentCuringSound:
    mov al, SFX_HEAL_AILMENT
    call PlaySoundWaitForCurrent

.showHealingItemMessage:
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 0
    call ClearScreen
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF   ; dec a → $ff
    call RedrawPartyMenu                ; redraws the menu and prints the message
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1
    mov bl, 50                          ; ld c, 50
    call DelayFrames
    call WaitForTextScrollButtonPress
    jmp .done

.canceledItemUse:
    mov byte [ebp + wActionResultOrTookBattleTurn], 0   ; item use failed
    pop eax                             ; pop af
    pop eax                             ; pop af
.done:
    mov al, [ebp + wPseudoItemID]
    test al, al                         ; using Softboiled?
    jnz .ret                            ; ret nz
    call GBPalWhiteOut
    ; call z, RunDefaultPaletteCommand — TODO-HW: SGB/CGB palette command (Phase 5)
    mov al, [ebp + wIsInBattle]
    test al, al
    jnz .ret                            ; ret nz
    jmp ReloadMapData
.ret:
    ret

; --- pret .useVitamin (item_effects.asm:1379) ------------------------------
.useVitamin:
    ; ESI = struct base; [hl] = species.
    mov al, [ebp + esi]
    mov [ebp + wCurSpecies], al
    mov [ebp + wPokedexNum], al
    mov al, [ebp + esi + MON_LEVEL]
    mov [ebp + wCurEnemyLevel], al
    call GetMonHeader                   ; CalcStats reads wMonHeader
    mov al, dh                          ; ld a,d — the party index
    mov esi, wPartyMonNicks
    call GetPartyMonName                ; → wNameBuffer (the texts' text_ram)
    mov esi, [iu_mon_base]

    mov al, [ebp + wCurItem]
    cmp al, RARE_CANDY
    jz .useRareCandy                    ; jp z

    call ApplyVitamin                   ; +2560 stat exp, CF=0 if already capped
    jnc .vitaminNoEffect
    mov esi, [iu_mon_base]
    call .recalculateStats

    ; walk VitaminStats to the name of the stat this vitamin raises
    mov esi, VitaminStats               ; flat table (not GB space)
    mov al, [ebp + wCurItem]
    sub al, HP_UP - 1
    mov bl, al                          ; ld c, a
.statNameLoop:
    dec bl
    jz .gotStatName
.statNameInnerLoop:
    mov al, [esi]                       ; scan forward past this entry's '@'
    inc esi
    cmp al, 0x50                        ; '@'
    jne .statNameInnerLoop
    jmp .statNameLoop

.gotStatName:
    ; pret: CopyData hl→wStringBuffer, STAT_NAME_LENGTH bytes. The port's CopyData
    ; is GB→GB and VitaminStats is a FLAT .data table, so inline the flat→GB copy
    ; (same substitution home/item_predicates.asm makes for KeyItemFlags).
    push esi
    lea edi, [ebp + wStringBuffer]
    mov ecx, STAT_NAME_LENGTH
    rep movsb
    pop esi
    mov al, SFX_HEAL_AILMENT
    call PlaySound
    mov esi, [VitaminStatRoseText_ref]
    mov ecx, [VitaminStatRoseText_ref + 4]
    call iu_print_text
    jmp RemoveUsedItem                  ; jp RemoveUsedItem

.vitaminNoEffect:
    mov esi, [VitaminNoEffectText_ref]
    mov ecx, [VitaminNoEffectText_ref + 4]
    call iu_print_text
    jmp GBPalWhiteOut                   ; jp GBPalWhiteOut

; pret .recalculateStats — CalcStats over the mon at ESI (struct base).
.recalculateStats:
    mov edx, esi
    add edx, MON_STATS                  ; de → the stats
    add esi, MON_EXP + 2                ; hl → LSB of experience (CalcStats' base)
    mov bh, 1                           ; consider stat exp
    jmp CalcStats

; --- pret .useRareCandy (item_effects.asm:1460) ----------------------------
.useRareCandy:
    ; RareCandyLevelUp does pret's level++/CalcExperience/exp write/.recalculateStats/
    ; max-HP-gain-to-current-HP chain (Stage 3, native-validated). CF=0 at MAX_LEVEL.
    call RareCandyLevelUp
    jnc .vitaminNoEffect                ; can't raise the level above 100

    ; pret pushes wWhichPokemon (currently the BAG list index — .noHappinessBoost
    ; restored it) and wCurItem here, and pops both back just before RemoveUsedItem,
    ; because the level-up UI below re-points wWhichPokemon at the party slot.
    movzx eax, byte [ebp + wWhichPokemon]
    push eax
    mov byte [ebp + wPartyMenuTypeOrMessageID], RARE_CANDY_MSG
    call RedrawPartyMenu
    mov al, [ebp + wUsedItemOnWhichPokemon]
    mov [ebp + wWhichPokemon], al       ; pret: pop de / ld a,d — the party index
    ; pret: ld a,e (the species it stashed in e). wCurPartySpecies aliases wCurItem
    ; in WRAM ($CF90) and now holds RARE_CANDY, so read the species back from
    ; wCurSpecies, which .useVitamin wrote from the same source byte.
    mov al, [ebp + wCurSpecies]
    mov [ebp + wPokedexNum], al
    mov byte [ebp + wMonDataLocation], PLAYER_PARTY_DATA
    call LoadMonData
    mov dh, LEVEL_UP_STATS_BOX
    call PrintStatsBox                  ; callfar PrintStatsBox
    call WaitForTextScrollButtonPress
    mov byte [ebp + wMonDataLocation], PLAYER_PARTY_DATA
    call LearnMoveFromLevelUp           ; predef

    mov byte [ebp + wForceEvolution], 0
    mov al, PIKAHAPPY_LEVELUP
    call ModifyPikachuHappiness
    call .respawnPikachuForUsedMon      ; leaves wWhichPokemon = the party index
    call TryEvolvingMon                 ; callfar TryEvolvingMon — reads wWhichPokemon
    mov byte [ebp + wUpdateSpritesEnabled], 1
    mov byte [ebp + wCurItem], RARE_CANDY    ; pret: pop af / ld [wCurItem],a
    pop eax
    mov [ebp + wWhichPokemon], al       ; pret: pop af — back to the bag list index
    jmp RemoveUsedItem                  ; jp RemoveUsedItem

; --- shared helper: pret's wWhichPokemon swap around RespawnOverworldPikachu ---
.respawnPikachuForUsedMon:
    movzx eax, byte [ebp + wWhichPokemon]
    push eax
    mov al, [ebp + wUsedItemOnWhichPokemon]
    mov [ebp + wWhichPokemon], al
    call RespawnOverworldPikachu        ; callfar RespawnOverworldPikachu
    pop eax
    mov [ebp + wWhichPokemon], al
    ret

; --- Softboiled: subtract 1/5 of the user's max HP (pret item_effects.asm:1123) ---
; The HP-bar drain animation (predef UpdateHPBar2) is not run — DEVIATION 1.
; Out: [iu_softboiled_heal] = the amount taken (== the amount to heal with).
;      wHPBarMaxHP/OldHP/NewHP are left as pret leaves them for the TARGET mon.
.softboiledDrain:
    ; save the target's HP-bar words (pret pushes the four bytes)
    movzx eax, byte [ebp + wHPBarMaxHP]
    push eax
    movzx eax, byte [ebp + wHPBarMaxHP + 1]
    push eax
    movzx eax, byte [ebp + wHPBarOldHP]
    push eax
    movzx eax, byte [ebp + wHPBarOldHP + 1]
    push eax

    ; hl = the USER's max HP (wWhichPokemon is the Softboiled user here)
    mov esi, wPartyMon1MaxHP
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wWhichPokemon]
    call AddNTimes
    mov al, [ebp + esi]                 ; max HP high
    mov [ebp + wHPBarMaxHP + 1], al
    mov [ebp + H_DIVIDEND], al
    mov al, [ebp + esi + 1]             ; max HP low
    mov [ebp + wHPBarMaxHP], al
    mov [ebp + H_DIVIDEND + 1], al
    mov byte [ebp + H_DIVISOR], 5
    mov bh, 2                           ; ld b, 2 — dividend byte count
    push esi
    call Divide                         ; 1/5 of the user's max HP
    pop esi

    ; hl → the user's current HP (LSB); subtract the quotient
    add esi, (MON_HP + 1) - (MON_MAXHP + 1)  ; ESI = current-HP LOW byte
    mov al, [ebp + H_QUOTIENT + 3]
    mov [iu_softboiled_heal], al        ; pret: push af (the heal amount)
    mov bl, al
    mov al, [ebp + esi]
    sub al, bl
    mov [ebp + esi], al
    dec esi                             ; -> current-HP HIGH byte (dec preserves CF)
    mov al, [ebp + H_QUOTIENT + 2]
    mov bl, al
    mov al, [ebp + esi]
    sbb al, bl
    mov [ebp + esi], al

    ; restore the target's HP-bar words
    pop eax
    mov [ebp + wHPBarOldHP + 1], al
    pop eax
    mov [ebp + wHPBarOldHP], al
    pop eax
    mov [ebp + wHPBarMaxHP + 1], al
    pop eax
    mov [ebp + wHPBarMaxHP], al
    ret

; ===========================================================================
; Shared tails — pret ref: engine/items/item_effects.asm:2396-2600.
; ===========================================================================
UnusableItem:
    jmp ItemUseNotTime

RemoveUsedItem:
    mov esi, wNumBagItems
    mov byte [ebp + wItemQuantity], 1   ; one item
    jmp RemoveItemFromInventory

ItemUseNoEffect:
    mov esi, [ItemUseNoEffectText_ref]
    mov ecx, [ItemUseNoEffectText_ref + 4]
    jmp ItemUseFailed

ItemUseNotTime:
    mov esi, [ItemUseNotTimeText_ref]
    mov ecx, [ItemUseNotTimeText_ref + 4]
    jmp ItemUseFailed

ItemUseNotYoursToUse:
    mov esi, [ItemUseNotYoursToUseText_ref]
    mov ecx, [ItemUseNotYoursToUseText_ref + 4]
    jmp ItemUseFailed

Func_e4bf:
    mov byte [ebp + wActionResultOrTookBattleTurn], 2
    mov esi, [DontHavePokemonText_ref]
    mov ecx, [DontHavePokemonText_ref + 4]
    jmp iu_print_text                   ; jp PrintText

; In: ESI = flat text stream, ECX = its length (pret passes hl alone; the port
; needs the length to stage the stream in GB space — see iu_print_text).
ItemUseFailed:
    mov byte [ebp + wActionResultOrTookBattleTurn], 0   ; item use failed
    jmp iu_print_text                   ; jp PrintText

; ---------------------------------------------------------------------------
; iu_print_text — print a generated TX stream through the port's text engine.
; The streams are flat .data (assets/item_text.inc) but TextCommandProcessor
; reads its stream EBP-relative, so stage it in the GB-space dialog buffer first
; — the same copy ShowTextStream (map_sprites.asm) makes for NPC dialogs.
; In: ESI = flat stream, ECX = length (<= 256, the NPC_DIALOG_BUF window).
; See DEVIATION 2 for the window behaviour.
; ---------------------------------------------------------------------------
iu_print_text:
    pushad
    lea edi, [ebp + NPC_DIALOG_BUF]
    rep movsb                           ; flat → GB WRAM (both flat selectors)
    mov esi, NPC_DIALOG_BUF             ; EBP-relative for PrintText_Overworld
    call PrintText_Overworld
    popad
    ret

; ---------------------------------------------------------------------------

; === ItemUseBall — catching (items-plan Stage 6) ============================
;
; Source: engine/items/item_effects.asm:104-609 (ItemUseBall), 2569-2591
; (ThrowBallAtTrainerMon, BoxFullCannotThrowBall) and 2932-3112 (SendNewMonToBox).
; The Gen-1 catch algorithm is translated verbatim, including its two documented
; quirks (the Transform→assumed-Ditto bug and the old-man/Pikachu battle's
; player-name copy into wGrassRate, the Cinnabar Missingno. glitch's other half).
;
; PORT DEVIATIONS (this block; the file header's four still apply)
; 5. predef MoveAnimation → `call PlayMoveAnimation` (animations.asm), the port's
;    faithful ANIMATION=OFF realization: a 30-frame delay where the ball toss would
;    play. Retired by the subanimation engine (TODO-HW, battle plan).
; 6. predef IndexToPokedex → direct table index. IndexToPokedex is a flat .data
;    TABLE in this port, never a routine (see home/pics.asm; calling it faults).
; 7. predef FlagActionPredef → `call FlagAction` (ESI=array, CL=index, BH=action,
;    result back in CL) — the port-wide no-predef-dispatch rule.
; 8. In-battle text goes through the battle printer PrintText (=PrintBattleText,
;    EAX/ESI = flat stream), NOT iu_print_text/PrintText_Overworld: ItemUseBall only
;    ever runs with wIsInBattle set, and the battle box is where pret's PrintText
;    draws here. Same split naming_screen.asm documents.
; ---------------------------------------------------------------------------

global ItemUseBall
global ThrowBallAtTrainerMon
global BoxFullCannotThrowBall
global SendNewMonToBox

extern PrintText              ; engine/battle/move_effect_helpers.asm — battle printer, ESI = flat stream
extern PlayMoveAnimation      ; engine/battle/animations.asm — AL = animation id (predef MoveAnimation)
extern IsGhostBattle          ; engine/battle/ghost.asm — ZF=1 → unidentified ghost
extern LoadScreenTilesFromBuffer1 ; engine/battle/battle_menu.asm
extern Delay3                 ; video/frame.asm
extern Random                 ; home/random.asm — AL = next random byte
extern Multiply               ; home/math.asm — hMultiplicand(3) * hMultiplier → hProduct(4)
extern IndexToPokedex         ; data/pokemon_data.asm — FLAT TABLE: [species-1] → dex number
extern ShowPokedexData        ; engine/menus/pokedex_entry.asm (predef)
extern AskName                ; engine/menus/naming_screen.asm (predef; hl = nickname dest)
extern LoadEnemyMonData       ; engine/battle/load_enemy_mon_data.asm
extern CalcExperience         ; engine/pokemon/experience.asm — DH = level → hExperience
extern ClearSprites           ; home/sprites.asm
extern AddPartyMon            ; home/move_mon.asm — adds wCurPartySpecies to the party

; --- generated text streams (assets/item_text.inc) ---
extern ItemUseText00                ; "<PLAYER> used ITEM!"
extern ItemUseBallText00            ; "It dodged the thrown ball!" / can't be caught
extern ItemUseBallText01            ; "You missed the POKéMON!"
extern ItemUseBallText02            ; "Darn! The POKéMON broke free!"
extern ItemUseBallText03            ; "Aww! It appeared to be caught!"
extern ItemUseBallText04            ; "Shoot! It was so close too!"
extern ItemUseBallText05            ; "All right! <MON> was caught!"
extern ItemUseBallText06            ; "New DEX data will be added..."
extern ItemUseBallText07            ; "…was transferred to BILL's PC"
extern ItemUseBallText08            ; "…was transferred to someone's PC"
extern ThrowBallAtTrainerMonText1
extern ThrowBallAtTrainerMonText2
extern BoxFullCannotThrowBallText_ref

; ---------------------------------------------------------------------------
; ItemUseBall — pret item_effects.asm:104.
; ---------------------------------------------------------------------------
ItemUseBall:
; Balls can't be used out of battle.
    mov al, [ebp + wIsInBattle]
    test al, al
    jz ItemUseNotTime                   ; jp z

; Balls can't catch trainers' Pokémon.
    dec al
    jnz ThrowBallAtTrainerMon           ; jp nz (wIsInBattle 2 = trainer)

; The old-man / Pikachu tutorial battles skip the party+box full check.
    mov al, [ebp + wBattleType]
    cmp al, BATTLE_TYPE_OLD_MAN
    je .canUseBall
    cmp al, BATTLE_TYPE_PIKACHU
    je .canUseBall

    mov al, [ebp + wPartyCount]         ; is the party full?
    cmp al, PARTY_LENGTH
    jne .canUseBall
    mov al, [ebp + wBoxCount]           ; is the box full too?
    cmp al, MONS_PER_BOX
    je BoxFullCannotThrowBall           ; jp z

.canUseBall:
    mov byte [ebp + wCapturedMonSpecies], 0

    mov al, [ebp + wBattleType]
    cmp al, BATTLE_TYPE_SAFARI
    jne .skipSafariZoneCode
.safariZone:
    dec byte [ebp + wNumSafariBalls]    ; dec [hl] — remove a Safari Ball

.skipSafariZoneCode:
    ; call RunDefaultPaletteCommand — TODO-HW: palette HAL (Phase 5), no-op here.
    ; DEVIATION 3 (file header); same treatment as pokedex_entry.asm / league_pc.asm.
    mov byte [ebp + wPokeBallAnimData], 0x43   ; successful-capture value
    call LoadScreenTilesFromBuffer1
    mov esi, ItemUseText00
    call PrintText

; An unidentified ghost can never be caught.
    call IsGhostBattle                  ; callfar
    mov bh, 0x10                        ; can't-be-caught value (mov: keeps ZF)
    jz .setAnimData                     ; jp z

    mov al, [ebp + wBattleType]
    cmp al, BATTLE_TYPE_OLD_MAN
    je .oldManBattle
    cmp al, BATTLE_TYPE_PIKACHU
    je .oldManBattle                    ; the Pikachu battle is technically an old-man battle
    jmp .notOldManBattle

.oldManBattle:
; GLITCH: the player's name is copied over the wild-mon data (wGrassRate) — this is
; the write half of the Cinnabar Island Missingno. glitch. Faithful, kept.
; Safety: bounded copy into WRAM under DPMI; no ACE reachable.
    mov esi, wGrassRate
    mov edx, wPlayerName
    mov bx, NAME_LENGTH
    call CopyData
    mov al, [ebp + wBattleType]
    cmp al, BATTLE_TYPE_OLD_MAN
    jne .captured                       ; jp nz (the Pikachu battle DOES "catch")
    mov byte [ebp + wCapturedMonSpecies], 1
    CheckEvent EVENT_INITIAL_CATCH_TRAINING     ; clobbers AL, sets ZF
    mov bh, 0x63                        ; 3 shakes
    jnz .setAnimData                    ; jp nz — already trained: just shake, no catch
    jmp .captured

.notOldManBattle:
; The ghost Marowak (Pokémon Tower 6F) can never be caught.
    mov al, [ebp + wCurMap]
    cmp al, POKEMON_TOWER_6F
    jne .loop
    mov al, [ebp + wEnemyMonSpecies2]
    cmp al, RESTLESS_SOUL
    mov bh, 0x10                        ; can't-be-caught value (mov: keeps ZF)
    je .setAnimData                     ; jp z

; Rand1 (BH) must land in the ball's range: Poké [0,255], Great [0,200],
; Ultra/Safari [0,150]. Loop until it does.
.loop:
    call Random
    mov bh, al                          ; ld b, a

    mov al, [ebp + wCurItem]
    cmp al, MASTER_BALL                 ; the Master Ball always succeeds
    je .captured                        ; jp z
    cmp al, POKE_BALL                   ; anything does for a Poké Ball
    je .checkForAilments

    cmp bh, 200                         ; pret: ld a,200 / cp b / jr c,.loop
    ja .loop                            ; (carry there == 200 < Rand1 here)
    mov al, [ebp + wCurItem]
    cmp al, GREAT_BALL
    je .checkForAilments

    cmp bh, 150
    ja .loop

.checkForAilments:
; Status (BL): none 0, Burn/Paralysis/Poison 12, Freeze/Sleep 25. Subtract it from
; Rand1; if it underflows, the mon is caught outright.
    mov al, [ebp + wEnemyMonStatus]
    test al, al
    jz .skipAilmentValueSubtraction
    and al, (1 << FRZ) | SLP_MASK
    mov bl, 12
    jz .notFrozenOrAsleep
    mov bl, 25
.notFrozenOrAsleep:
    mov al, bh
    sub al, bl
    jc .captured                        ; jp c
    mov bh, al

.skipAilmentValueSubtraction:
    push ebx                            ; push bc — save (Rand1 - Status) in BH

; MaxHP * 255
    mov byte [ebp + H_MULTIPLICAND], 0
    mov esi, wEnemyMonMaxHP
    mov al, [ebp + esi]                 ; big-endian: high byte first
    mov [ebp + H_MULTIPLICAND + 1], al
    mov al, [ebp + esi + 1]
    mov [ebp + H_MULTIPLICAND + 2], al
    mov byte [ebp + H_MULTIPLIER], 255
    call Multiply

; BallFactor: 8 for a Great Ball, 12 for everything else.
    mov al, [ebp + wCurItem]
    cmp al, GREAT_BALL
    mov al, 12
    jne .skip1
    mov al, 8
.skip1:
; (MaxHP * 255) / BallFactor — every division below floors.
    mov [ebp + H_DIVISOR], al
    mov bh, 4                           ; b = bytes in the dividend
    call Divide

; max(HP / 4, 1) — HP never exceeds 999, so the result fits in a byte.
    mov esi, wEnemyMonHP
    mov bh, [ebp + esi]                 ; b = HP high byte
    mov al, [ebp + esi + 1]             ; a = HP low byte
    shr bh, 1                           ; srl b
    rcr al, 1                           ; rr a  (CF from the srl)
    shr bh, 1
    rcr al, 1
    test al, al
    jnz .skip2
    inc al                              ; a quotient of 0 becomes 1
.skip2:

; W = ((MaxHP * 255) / BallFactor) / max(HP / 4, 1)
    mov [ebp + H_DIVISOR], al
    mov bh, 4
    call Divide

; X = min(W, 255), kept in hQuotient+3.
    mov al, [ebp + H_QUOTIENT + 2]
    test al, al
    jz .skip3
    mov byte [ebp + H_QUOTIENT + 3], 255

.skip3:
    pop ebx                             ; pop bc — BH = Rand1 - Status

; Rand1 - Status > CatchRate → the ball fails.
    mov al, [ebp + wEnemyMonActualCatchRate]
    cmp al, bh
    jb .failedToCapture                 ; jr c

; W > 255 → caught.
    mov al, [ebp + H_QUOTIENT + 2]
    test al, al
    jnz .captured

    call Random                         ; Rand2

; Rand2 > X → the ball fails.
    mov bh, al
    mov al, [ebp + H_QUOTIENT + 3]
    cmp al, bh
    jb .failedToCapture                 ; jr c

.captured:
    jmp .skipShakeCalculations          ; jr

.failedToCapture:
    mov al, [ebp + H_QUOTIENT + 3]
    mov [ebp + wPokeBallCaptureCalcTemp], al   ; save X

; CatchRate * 100
    mov byte [ebp + H_MULTIPLICAND], 0
    mov byte [ebp + H_MULTIPLICAND + 1], 0
    mov al, [ebp + wEnemyMonActualCatchRate]
    mov [ebp + H_MULTIPLICAND + 2], al
    mov byte [ebp + H_MULTIPLIER], 100
    call Multiply

; BallFactor2: Poké 255, Great 200, Ultra/Safari 150.
    mov al, [ebp + wCurItem]
    mov bh, 255
    cmp al, POKE_BALL
    je .skip4
    mov bh, 200
    cmp al, GREAT_BALL
    je .skip4
    mov bh, 150
    cmp al, ULTRA_BALL
    je .skip4

.skip4:
; Y = (CatchRate * 100) / BallFactor2
    mov al, bh
    mov [ebp + H_DIVISOR], al
    mov bh, 4
    call Divide

; Y > 255 → 3 shakes. (Unreachable in practice: max Y = (255*100)/150 = 170.)
    mov al, [ebp + H_QUOTIENT + 2]
    test al, al
    mov bh, 0x63                        ; 3 shakes (mov: keeps ZF)
    jnz .setAnimData

; (X * Y) / 255
    mov al, [ebp + wPokeBallCaptureCalcTemp]
    mov [ebp + H_MULTIPLIER], al
    call Multiply
    mov byte [ebp + H_DIVISOR], 255
    mov bh, 4
    call Divide

; Status2: none 0, Burn/Paralysis/Poison 5, Freeze/Sleep 10.
    mov al, [ebp + wEnemyMonStatus]
    test al, al
    jz .skip5
    and al, (1 << FRZ) | SLP_MASK
    mov bh, 5
    jz .addAilmentValue
    mov bh, 10

.addAilmentValue:
    mov al, [ebp + H_QUOTIENT + 3]
    add al, bh
    mov [ebp + H_QUOTIENT + 3], al

.skip5:
; Z = ((X * Y) / 255) + Status2 decides the shake count:
;   Z < 10 → 0 shakes (miss), < 30 → 1, < 70 → 2, else 3.
    mov al, [ebp + H_QUOTIENT + 3]
    cmp al, 10
    mov bh, 0x20
    jb .setAnimData
    cmp al, 30
    mov bh, 0x61
    jb .setAnimData
    cmp al, 70
    mov bh, 0x62
    jb .setAnimData
    mov bh, 0x63

.setAnimData:
    mov al, bh
    mov [ebp + wPokeBallAnimData], al

.skipShakeCalculations:
    mov bl, 20                          ; ld c, 20
    call DelayFrames

; The toss animation. wWhichPokemon / wCurItem are saved across it (the animation
; engine reuses both), exactly as pret does.
    mov byte [ebp + wAnimationID], TOSS_ANIM
    mov byte [ebp + hWhoseTurn], 0
    mov byte [ebp + wAnimationType], 0
    mov byte [ebp + wDamageMultipliers], 0
    movzx eax, byte [ebp + wWhichPokemon]
    push eax                            ; push af
    movzx eax, byte [ebp + wCurItem]
    push eax                            ; push af
    mov al, TOSS_ANIM
    call PlayMoveAnimation              ; predef MoveAnimation (DEVIATION 5)
    pop eax
    mov [ebp + wCurItem], al
    pop eax
    mov [ebp + wWhichPokemon], al

; The animation outcome picks the message. Anything else means "caught".
    mov al, [ebp + wPokeBallAnimData]
    cmp al, 0x10
    mov esi, ItemUseBallText00
    je .printMessage
    cmp al, 0x20
    mov esi, ItemUseBallText01
    je .printMessage
    cmp al, 0x61
    mov esi, ItemUseBallText02
    je .printMessage
    cmp al, 0x62
    mov esi, ItemUseBallText03
    je .printMessage
    cmp al, 0x63
    mov esi, ItemUseBallText04
    je .printMessage

; --- caught: reload the mon's data, then restore its live HP + status ---
; pret pushes HP high/low and the status byte, walks hl back down over them after
; LoadEnemyMonData and pops them into place. The port keeps the same three values
; (the stack juggling becomes explicit stores — same bytes, same order).
    mov al, [ebp + wEnemyMonHP]
    push eax                            ; HP high
    mov al, [ebp + wEnemyMonHP + 1]
    push eax                            ; HP low
    mov al, [ebp + wEnemyMonStatus]
    push eax                            ; status

; BUG: a transformed mon is assumed to be a Ditto. A wild mon could have used
; Transform via Mirror Move, but Ditto is the only wild mon that knows Transform.
; pret ships this; keep it (no BUG_FIX_LEVEL block — the fix would need to record
; the pre-Transform species, which the original never stores).
    mov esi, wEnemyBattleStatus3
    test byte [ebp + esi], 1 << TRANSFORMED
    jz .notTransformed
    mov byte [ebp + wEnemyMonSpecies2], DITTO
    jmp .skip6

.notTransformed:
; Not transformed: set the bit and stash the DVs so LoadEnemyMonData below reuses
; them instead of rolling new ones.
    or byte [ebp + esi], 1 << TRANSFORMED
    mov al, [ebp + wEnemyMonDVs]
    mov [ebp + wTransformedEnemyMonOriginalDVs], al
    mov al, [ebp + wEnemyMonDVs + 1]
    mov [ebp + wTransformedEnemyMonOriginalDVs + 1], al

.skip6:
    movzx eax, byte [ebp + wCurPartySpecies]
    push eax                            ; push af
    mov al, [ebp + wEnemyMonSpecies2]
    mov [ebp + wCurPartySpecies], al
    mov al, [ebp + wEnemyMonLevel]
    mov [ebp + wCurEnemyLevel], al
    call LoadEnemyMonData               ; callfar
    pop eax
    mov [ebp + wCurPartySpecies], al

    pop eax                             ; status
    mov [ebp + wEnemyMonStatus], al
    pop eax                             ; HP low
    mov [ebp + wEnemyMonHP + 1], al
    pop eax                             ; HP high
    mov [ebp + wEnemyMonHP], al

    mov al, [ebp + wEnemyMonSpecies]
    mov [ebp + wCapturedMonSpecies], al
    mov [ebp + wCurPartySpecies], al    ; NB: = wCurItem ($CF90), as in pret — the ball
    mov [ebp + wPokedexNum], al         ; is removed by bag INDEX (wWhichPokemon), not id

    mov al, [ebp + wBattleType]
    cmp al, BATTLE_TYPE_OLD_MAN
    je .oldManCaughtMon                 ; the tutorial battles don't hand the mon over
    cmp al, BATTLE_TYPE_PIKACHU
    je .oldManCaughtMon
    mov esi, ItemUseBallText05
    call PrintText

; Add the caught mon to the Pokédex (test first — a new species shows its entry).
    movzx eax, byte [ebp + wPokedexNum]
    dec eax
    movzx eax, byte [IndexToPokedex + eax]   ; predef IndexToPokedex (DEVIATION 6)
    mov [ebp + wPokedexNum], al
; BUG(critical): "Index #000 Post-Capture" — pret ref: engine/items/item_effects.asm
; :ItemUseBall (.captured); docs/bug_categorization.md (Battle table). A species with
; no pokédex number (the MISSINGNO./glitch indices) maps to dex 0 here, and the
; unconditional `dec a` below wraps it to $FF. FlagAction then addresses bit 255 —
; byte 31 of the 19-byte wPokedexOwned bitset — writing 12 bytes past its end, into
; wPokedexSeen and beyond. That OOB write is the ACE vector; under DPMI it stays
; inside the GB image (bounded, no fault), so it is left live by default.
%if BUG_FIX_LEVEL >= 1
    test al, al
    jz .skipShowingPokedexData          ; dex 0 = not a real species: no flag, no entry
%endif
    dec al
    mov cl, al
    mov bh, FLAG_TEST
    mov esi, wPokedexOwned
    call FlagAction                     ; predef FlagActionPredef (DEVIATION 7)
    movzx eax, cl
    push eax                            ; push af — was it already owned?
    mov al, [ebp + wPokedexNum]
    dec al
    mov cl, al
    mov bh, FLAG_SET
    mov esi, wPokedexOwned
    call FlagAction
    pop eax

    test al, al                         ; already in the Pokédex?
    jnz .skipShowingPokedexData

    mov esi, ItemUseBallText06
    call PrintText
    call ClearSprites
    mov al, [ebp + wEnemyMonSpecies]
    mov [ebp + wPokedexNum], al
    call ShowPokedexData                ; predef

.skipShowingPokedexData:
    mov byte [ebp + wPikachuEmotionModifier], 1
    mov byte [ebp + wPikachuMood], 0x85
    mov al, [ebp + wPartyCount]
    cmp al, PARTY_LENGTH                ; party full?
    je .sendToBox
    mov byte [ebp + wMonDataLocation], 0    ; PLAYER_PARTY_DATA
    call ClearSprites
    mov esi, iu_ball_emptyString        ; pret .emptyString — clears the message box
    call PrintText
    call AddPartyMon
    jmp .done

.sendToBox:
    call ClearSprites
    call SendNewMonToBox
    mov esi, ItemUseBallText07          ; "…was transferred to BILL's PC"
    CheckEvent EVENT_MET_BILL           ; clobbers AL only; ESI survives
    jnz .printTransferredToPCText
    mov esi, ItemUseBallText08          ; "…someone's PC" (Bill not met yet)
.printTransferredToPCText:
    call PrintText
    jmp .done

.oldManCaughtMon:
    mov esi, ItemUseBallText05

.printMessage:
    call PrintText
    call ClearSprites

.done:
    mov al, [ebp + wBattleType]
    test al, al                         ; the old-man battle doesn't consume a ball
    jnz .ret                            ; ret nz

; Remove one ball from the bag (by list index, wWhichPokemon — see the note above).
    mov esi, wNumBagItems
    inc al                              ; a was 0 → 1
    mov [ebp + wItemQuantity], al
    jmp RemoveItemFromInventory         ; jp
.ret:
    ret

; ---------------------------------------------------------------------------
; ThrowBallAtTrainerMon — pret item_effects.asm:2569. "The trainer blocked the
; ball!" / "Don't be a thief!" — the ball is still consumed.
; ---------------------------------------------------------------------------
ThrowBallAtTrainerMon:
    ; call RunDefaultPaletteCommand — TODO-HW: palette HAL (Phase 5), no-op (DEVIATION 3).
    call LoadScreenTilesFromBuffer1     ; restore the saved screen
    call Delay3
    mov byte [ebp + wAnimationID], TOSS_ANIM
    mov al, TOSS_ANIM
    call PlayMoveAnimation              ; predef MoveAnimation (DEVIATION 5)
    mov esi, ThrowBallAtTrainerMonText1
    call PrintText
    mov esi, ThrowBallAtTrainerMonText2
    call PrintText
    jmp RemoveUsedItem                  ; jr

; ---------------------------------------------------------------------------
; BoxFullCannotThrowBall — pret item_effects.asm:2586.
; ---------------------------------------------------------------------------
BoxFullCannotThrowBall:
    mov esi, [BoxFullCannotThrowBallText_ref]
    mov ecx, [BoxFullCannotThrowBallText_ref + 4]
    jmp ItemUseFailed                   ; jr

; ---------------------------------------------------------------------------
; SendNewMonToBox — pret item_effects.asm:2932. Store the newly caught mon in the
; FIRST box slot, shifting every existing box entry (species list, OT names,
; nicknames, mon structs) down one. Then nickname it (predef AskName).
;
; Gen-2 rule: the box struct is copied byte-for-byte, and the Kadabra
; TWISTEDSPOON_GSC write into MON_CATCH_RATE (offset 7) is carried verbatim.
; ---------------------------------------------------------------------------
SendNewMonToBox:
    mov edx, wBoxCount
    mov al, [ebp + edx]
    inc al
    mov [ebp + edx], al                 ; wBoxCount++

; Shift the species list down one, inserting the new species at the front. The
; list is $FF-terminated, so the walk ends when the byte we displaced IS the $FF.
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wCurSpecies], al
    mov cl, al                          ; c = the species being inserted
.shiftSpeciesLoop:
    inc edx
    mov al, [ebp + edx]                 ; b = the byte we're about to overwrite
    mov bh, al
    mov al, cl
    mov cl, bh                          ; c = displaced byte (carried to the next slot)
    mov [ebp + edx], al
    cmp al, 0xFF                        ; cp -1 — was the byte we WROTE the sentinel?
    jne .shiftSpeciesLoop

    call GetMonHeader

; Shift the OT names down one (skip if the box was empty before this mon).
    mov esi, wBoxMonOT
    mov bx, NAME_LENGTH
    mov al, [ebp + wBoxCount]
    dec al
    jz .skipOTshift

    dec al
    call AddNTimes                      ; hl = last existing OT slot
    push esi
    add esi, NAME_LENGTH
    mov edx, esi                        ; de = one slot further down (the destination)
    pop esi
    mov al, [ebp + wBoxCount]
    dec al
    mov bh, al                          ; b = number of names to move
.shiftMonOTLoop:
    push ebx
    push esi
    mov bx, NAME_LENGTH
    call CopyData                       ; ESI → EDX, BX bytes
    pop esi
    mov edx, esi                        ; de = hl (the slot we just copied FROM)
    sub esi, NAME_LENGTH                ; hl -= NAME_LENGTH (bc = -NAME_LENGTH)
    pop ebx
    dec bh
    jnz .shiftMonOTLoop

.skipOTshift:
    mov esi, wPlayerName
    mov edx, wBoxMon1OT
    mov bx, NAME_LENGTH
    call CopyData

; Shift the nicknames down one, same shape.
    mov al, [ebp + wBoxCount]
    dec al
    jz .skipNickShift

    mov esi, wBoxMonNicks
    mov bx, NAME_LENGTH
    dec al
    call AddNTimes
    push esi
    add esi, NAME_LENGTH
    mov edx, esi
    pop esi
    mov al, [ebp + wBoxCount]
    dec al
    mov bh, al
.shiftNickLoop:
    push ebx
    push esi
    mov bx, NAME_LENGTH
    call CopyData
    pop esi
    mov edx, esi
    sub esi, NAME_LENGTH
    pop ebx
    dec bh
    jnz .shiftNickLoop

.skipNickShift:
; Nickname prompt for the new box mon (predef AskName; hl = wBoxMon1Nick).
    mov byte [ebp + wPredefHL], wBoxMon1Nick >> 8
    mov byte [ebp + wPredefHL + 1], wBoxMon1Nick & 0xFF
    mov byte [ebp + wNamingScreenType], NAME_MON_SCREEN
    call AskName                        ; predef

; Shift the box mon structs down one.
    mov al, [ebp + wBoxCount]
    dec al
    jz .skipMonDataShift

    mov esi, wBoxMons
    mov bx, BOXMON_STRUCT_LENGTH
    dec al
    call AddNTimes
    push esi
    add esi, BOXMON_STRUCT_LENGTH
    mov edx, esi
    pop esi
    mov al, [ebp + wBoxCount]
    dec al
    mov bh, al
.shiftMonDataLoop:
    push ebx
    push esi
    mov bx, BOXMON_STRUCT_LENGTH
    call CopyData
    pop esi
    mov edx, esi
    sub esi, BOXMON_STRUCT_LENGTH
    pop ebx
    dec bh
    jnz .shiftMonDataLoop

.skipMonDataShift:
; Build the new box mon in slot 1 from the enemy mon.
    mov al, [ebp + wEnemyMonLevel]
    mov [ebp + wEnemyMonBoxLevel], al
    mov esi, wEnemyMon
    mov edx, wBoxMon1
    mov bx, wEnemyMonDVs - wEnemyMon    ; species..PP-less head of the struct
    call CopyData                       ; leaves EDX just past the copied bytes

; OT id (big-endian word, straight from wPlayerID).
    mov al, [ebp + wPlayerID]
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + wPlayerID + 1]
    mov [ebp + edx], al
    inc edx

; EXP for the caught level (3 bytes, big-endian).
    push edx
    mov dh, [ebp + wCurEnemyLevel]      ; d = level
    call CalcExperience                 ; callfar — → hExperience (3 bytes)
    pop edx
    mov al, [ebp + H_EXPERIENCE]
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + H_EXPERIENCE + 1]
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + H_EXPERIENCE + 2]
    mov [ebp + edx], al
    inc edx

; Stat exp: NUM_STATS * 2 zero bytes.
    xor al, al
    mov bh, NUM_STATS * 2
.statLoop:
    mov [ebp + edx], al
    inc edx
    dec bh
    jnz .statLoop

; DVs, then the four move PPs.
    mov esi, wEnemyMonDVs
    mov al, [ebp + esi]
    mov [ebp + edx], al
    inc edx
    inc esi
    mov al, [ebp + esi]
    mov [ebp + edx], al

    mov esi, wEnemyMonPP
    mov bh, NUM_MOVES
.movePPLoop:
    mov al, [ebp + esi]
    inc esi
    inc edx
    mov [ebp + edx], al
    dec bh
    jnz .movePPLoop

; Gen-2 forward-compat: a boxed Kadabra ships holding a TwistedSpoon, stored in the
; catch-rate byte (MON_CATCH_RATE, offset 7) — the Time Capsule's held-item slot.
    mov al, [ebp + wCurPartySpecies]
    cmp al, KADABRA
    jne .notKadabra
    mov byte [ebp + wBoxMon1CatchRate], TWISTEDSPOON_GSC
.notKadabra:
    ret

section .data
; pret .emptyString: `db "@"` — a bare terminator, printed to blank the message box
; before AddPartyMon. A lone control byte, not a glyph run (see the text-data rule).
iu_ball_emptyString: db 0x50

section .text

; === ItemUseTMHM — teaching a TM/HM (items-plan Stage 7) ====================
;
; Source: engine/items/item_effects.asm:2399-2500 (pret).
;
; PORT DEVIATIONS (this block; the file's earlier ones still apply)
;  9. predef TMToMove / predef CanLearnTM / predef LearnMove and
;     `callfar CheckIfMoveIsKnown` all become direct calls — the port has no predef
;     dispatcher (the same boundary as DEVIATIONS 5-7).
; 10. RunDefaultPaletteCommand on the cancel path is a TODO-HW no-op (Phase 5); it is
;     file-local elsewhere in the port, not a global (as in ItemUseBall).
; 11. Text goes through iu_print_text (the item layer's overworld printer), taking the
;     generated stream + length from each <Label>_ref pair, not pret's `ld hl, Label`.
;
; wTempTMHM ($D11D) unions with wNamedObjectIndex exactly as in pret, so storing the
; TM/HM number there is also what hands GetMoveName its index — do not "fix" that.

extern TMToMove                   ; engine/items/tms.asm (predef TMToMove)
extern CanLearnTM                 ; engine/items/tms.asm (predef CanLearnTM) — out: CL
extern CheckIfMoveIsKnown         ; engine/items/tmhm.asm (callfar) — CF = already knows
extern LearnMove                  ; engine/pokemon/learn_move.asm (predef) — out: BH
extern GetMoveName                ; home/names.asm — [wNamedObjectIndex] → wNameBuffer
extern IsThisPartyMonStarterPikachu ; engine/pikachu/pikachu_status.asm — CF = yes
extern GBPalWhiteOutWithDelay3    ; home/fade.asm
extern BootedUpTMText_ref
extern BootedUpHMText_ref
extern TeachMachineMoveText_ref
extern MonCannotLearnMachineMoveText_ref

global ItemUseTMHM
ItemUseTMHM:
    mov al, [ebp + wIsInBattle]
    test al, al
    jnz ItemUseNotTime                  ; jp nz — no TMs mid-battle
    mov al, [ebp + wCurItem]
    sub al, TM01                        ; underflows (CF) for HMs — they sit below TM01
    pushf                               ; push af — CF is the HM flag, live across the calls
    jnc .skipAdding
    add al, NUM_TMS + NUM_HMS           ; HM ids come after the TM ids
.skipAdding:
    inc al
    mov [ebp + wTempTMHM], al
    call TMToMove                       ; predef TMToMove — TM/HM number → move id
    mov al, [ebp + wTempTMHM]
    mov [ebp + wMoveNum], al
    call GetMoveName
    mov edx, wNameBuffer
    call CopyToStringBuffer
    popf
    mov esi, [BootedUpTMText_ref]
    mov ecx, [BootedUpTMText_ref + 4]
    jnc .printBootedUpMachineText       ; CF (from the popf) = it's an HM
    mov esi, [BootedUpHMText_ref]
    mov ecx, [BootedUpHMText_ref + 4]
.printBootedUpMachineText:
    call iu_print_text
    mov esi, [TeachMachineMoveText_ref]
    mov ecx, [TeachMachineMoveText_ref + 4]
    call iu_print_text
    ; hlcoord 14,7 / lb bc,8,15 / TWO_OPTION_MENU — as in TossItem_, the port's
    ; two-option box takes its geometry from yes_no.asm state.
    call InitYesNoTextBoxParameters
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    call DisplayTextBoxID               ; yes/no menu
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jz .useMachine
    mov byte [ebp + wActionResultOrTookBattleTurn], 2   ; item not used
    ret

.useMachine:
    movzx eax, byte [ebp + wWhichPokemon]
    push eax                            ; push af — the bag's list index
    movzx eax, byte [ebp + wCurItem]
    push eax                            ; push af
.chooseMon:
    ; Park the move name: DisplayPartyMenu overwrites wStringBuffer.
    mov esi, wStringBuffer
    mov edx, wTempMoveNameBuffer
    mov bx, MOVE_NAME_LENGTH
    call CopyData
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF
    mov byte [ebp + wPartyMenuTypeOrMessageID], TMHM_PARTY_MENU
    call DisplayPartyMenu
    pushf                               ; push af — CF = the player backed out
    mov esi, wTempMoveNameBuffer
    mov edx, wStringBuffer
    mov bx, MOVE_NAME_LENGTH
    call CopyData
    popf
    jnc .checkIfAbleToLearnMove
; the player canceled teaching the move
    pop eax
    pop eax
    call GBPalWhiteOutWithDelay3
    call ClearSprites
    ; call RunDefaultPaletteCommand — TODO-HW: default palette set (Phase 5), no-op
    jmp LoadScreenTilesFromBuffer1      ; jp — restore the saved screen

.checkIfAbleToLearnMove:
    call CanLearnTM                     ; predef CanLearnTM — CL = 0 if it can't
    push ebx                            ; push bc
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMonNicks
    call GetPartyMonName
    pop ebx                             ; pop bc
    mov al, bl                          ; ld a, c
    test al, al
    jnz .checkIfAlreadyLearnedMove
; the mon can't learn the move
    mov al, SFX_DENIED
    call PlaySoundWaitForCurrent
    mov esi, [MonCannotLearnMachineMoveText_ref]
    mov ecx, [MonCannotLearnMachineMoveText_ref + 4]
    call iu_print_text
    jmp .chooseMon

.checkIfAlreadyLearnedMove:
    call CheckIfMoveIsKnown             ; callfar — CF = it already knows the move
    jc .chooseMon
    call LearnMove                      ; predef LearnMove — BH = 1 if learned
    mov al, [ebp + wWhichPokemon]
    mov dh, al                          ; ld d, a — the taught mon's party index
    pop eax
    mov [ebp + wCurItem], al
    pop eax
    mov [ebp + wWhichPokemon], al       ; restore the bag's list index
    test bh, bh                         ; ld a, b / and a
    jz .done                            ; ret z — not learned: keep the TM

    movzx eax, byte [ebp + wWhichPokemon]
    push eax
    mov al, dh
    mov [ebp + wWhichPokemon], al       ; the happiness/Pikachu checks want the mon
    mov al, PIKAHAPPY_USEDTMHM
    call ModifyPikachuHappiness
    call IsThisPartyMonStarterPikachu   ; CF = it's the player's own Pikachu
    jnc .notTeachingThunderboltOrThunderToPikachu
    mov al, [ebp + wCurItem]
    cmp al, TM_THUNDERBOLT
    je .teachingThunderboltOrThunderToPlayerPikachu
    cmp al, TM_THUNDER
    jne .notTeachingThunderboltOrThunderToPikachu
.teachingThunderboltOrThunderToPlayerPikachu:
    mov byte [ebp + wPikachuEmotionModifier], 5
    mov byte [ebp + wPikachuMood], 0x85
.notTeachingThunderboltOrThunderToPikachu:
    pop eax
    mov [ebp + wWhichPokemon], al

    mov al, [ebp + wCurItem]
    call IsItemHM
    jc .done                            ; ret c — an HM is never consumed
    jmp RemoveUsedItem                  ; jp RemoveUsedItem
.done:
    ret

; === ItemUseEvoStone — evolution stones (items-plan Stage 8) ================
;
; Source: engine/items/item_effects.asm:790-848 (ItemUseEvoStone) and 849-889
; (Func_d85d, the stone-applicability scan).
;
; DEVIATION 12 (flat model): pret's Func_d85d cannot address the evo/moves blob
; directly — it lives in another ROM bank — so it FarCopyData's the mon's 2-byte
; pointer out of EvosMovesPointerTable into wEvoDataBuffer, dereferences that,
; then FarCopyData's 13 bytes of the blob into the same buffer and scans the copy.
; The port's EvosMovesPointerTable is a flat .data table of 32-bit pointers (a
; TABLE, never callable), so the blob is directly readable: we scan it in place
; and wEvoDataBuffer has no reason to exist. The scan itself — entry strides, the
; EVOLVE_ITEM item-id compare, the CF contract — is byte-for-byte pret's.
;
; DEVIATION 13: pret's player-Pikachu refusal plays PikachuCry28 through
; PlayPikachuSoundClip (ldpikacry / callfar). The Pikachu PCM path is Phase 3
; audio work; the cry is a TODO-HW no-op here. Everything else on that branch —
; GetPartyMonName, RefusingText, the emotion/mood writes, the "item not used"
; tail — is faithful.

extern EvosMovesPointerTable        ; src/data/pokemon_data.asm — flat dd TABLE (never call it)
extern WaitForSoundToFinish         ; src/home/audio.asm
extern RefusingText_ref             ; assets/item_text.inc

global ItemUseEvoStone
global Func_d85d

ItemUseEvoStone:
    mov al, [ebp + wIsInBattle]
    test al, al
    jnz ItemUseNotTime                  ; jp nz — no stones mid-battle
    mov al, [ebp + wWhichPokemon]
    push eax                            ; push af — the BAG slot, restored at the tail
    mov al, [ebp + wCurItem]
    mov [ebp + wEvoStoneItemID], al
    push eax                            ; push af — pret pops this into B
    mov byte [ebp + wPartyMenuTypeOrMessageID], EVO_STONE_PARTY_MENU
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF
    call DisplayPartyMenu               ; CF = 1 → the player canceled
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wLoadedMon], al          ; Func_d85d reads the species from here
    pop ebx                             ; pop bc — BL holds pret's B (the saved item id)
    jc .canceledItemUse                 ; CF still DisplayPartyMenu's (mov/pop leave it)
    mov [ebp + wCurPartySpecies], bl    ; ld a,b / ld [wCurPartySpecies],a (faithful: pret
                                        ; parks the ITEM id here; the species lives in
                                        ; wLoadedMon for the scan below)
    call Func_d85d                      ; CF = 1 → this stone evolves this mon
    jnc .noEffect
    call IsThisPartyMonStarterPikachu   ; callfar — CF = it's the player's Pikachu
    jnc .notPlayerPikachu
    ; TODO-HW: pret plays PikachuCry28 via PlayPikachuSoundClip (Phase 3 audio).
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMonNicks
    call GetPartyMonName
    mov esi, [RefusingText_ref]         ; ld hl, RefusingText
    mov ecx, [RefusingText_ref + 4]
    call iu_print_text
    mov byte [ebp + wPikachuEmotionModifier], 0x4
    mov byte [ebp + wPikachuMood], 0x82
    jmp .canceledItemUse

.notPlayerPikachu:
    mov al, SFX_HEAL_AILMENT
    call PlaySoundWaitForCurrent
    call WaitForSoundToFinish
    mov byte [ebp + wForceEvolution], 1     ; TRUE
    call TryEvolvingMon                 ; callfar — evolve it
    pop eax
    mov [ebp + wWhichPokemon], al       ; restore the BAG slot for RemoveItemFromInventory
    mov esi, wNumBagItems
    mov byte [ebp + wItemQuantity], 1   ; remove 1 stone
    jmp RemoveItemFromInventory         ; jp

.noEffect:
    call ItemUseNoEffect
.canceledItemUse:
    mov byte [ebp + wActionResultOrTookBattleTurn], 0    ; xor a — item not used
    pop eax
    ret

; ---------------------------------------------------------------------------
; Func_d85d — can [wLoadedMon] (species) evolve with [wCurItem] (the stone)?
; Out: CF = 1 if an EVOLVE_ITEM entry for this item exists, CF = 0 otherwise.
; Entry strides (constants/pokemon_constants.asm): EVOLVE_LEVEL/EVOLVE_TRADE are
; 3 bytes, EVOLVE_ITEM is 4 (type, item, min_level, species); a 0 type ends the list.
; ---------------------------------------------------------------------------
Func_d85d:
    movzx eax, byte [ebp + wLoadedMon]
    dec eax                             ; dec a — table is 0-based on the internal index
    mov esi, [EvosMovesPointerTable + eax * 4]  ; flat blob ptr (see DEVIATION 12)
.loop:
    mov al, [esi]                       ; ld a, [hli] — evolution type
    test al, al
    jz .cannotEvolveWithUsedStone       ; 0 → end of the evolution list
    cmp al, EVOLVE_ITEM
    je .itemEntry
    add esi, 3                          ; EVOLVE_LEVEL / EVOLVE_TRADE stride
    jmp .loop
.itemEntry:
    mov bh, [esi + 1]                   ; ld b, [hl] — the item this entry needs
    mov al, [ebp + wCurItem]
    add esi, 4                          ; past this 4-byte entry either way
    cmp al, bh                          ; cp b
    jne .loop
    stc                                 ; scf — this stone works
    ret
.cannotEvolveWithUsedStone:
    clc
    ret


; === ItemUseRepel family (items-plan Stage 9) ==============================
;
; Source: engine/items/item_effects.asm:ItemUseRepel / ItemUseSuperRepel /
; ItemUseMaxRepel / ItemUseRepelCommon / PrintItemUseTextAndRemoveItem.
;
; These are the first-ever writers of wRepelRemainingSteps, which brings the
; already-translated TryDoWildEncounter `.lastRepelStep` branch
; (engine/battle/wild_encounters.asm) to life. That branch calls DisplayTextID,
; which is still a ret-stub (owned by docs/current_plan_script_engine.md), so the
; "REPEL's effect wore off." message does not display yet — the step counter and
; the encounter suppression themselves are fully live. See home_stubs.asm.
; ===========================================================================

global ItemUseRepel
ItemUseRepel:
    mov bh, 100                         ; pret: ld b, 100
    ; fallthrough (pret: ItemUseRepelCommon is the next label)

global ItemUseRepelCommon
ItemUseRepelCommon:
    mov al, [ebp + wIsInBattle]
    test al, al
    jnz ItemUseNotTime                  ; pret: jp nz, ItemUseNotTime
    mov al, bh
    mov [ebp + wRepelRemainingSteps], al
    jmp PrintItemUseTextAndRemoveItem

global ItemUseSuperRepel
ItemUseSuperRepel:
    mov bh, 200                         ; pret: ld b, 200
    jmp ItemUseRepelCommon

global ItemUseMaxRepel
ItemUseMaxRepel:
    mov bh, 250                         ; pret: ld b, 250
    jmp ItemUseRepelCommon

; ---------------------------------------------------------------------------
; PrintItemUseTextAndRemoveItem — "<PLAYER> used <ITEM>!", the get-item jingle,
; a button wait, then consume the item.
;
; DEVIATION (structural): pret FALLS THROUGH into RemoveUsedItem (the two labels
; are contiguous). RemoveUsedItem is already defined earlier in this file, so the
; port tail-jumps instead — same control flow, no shared code path lost.
;
; NOTE: ItemUseText00 prints the item name via TX_RAM from wStringBuffer. pret's
; item menu loads it (GetItemName + CopyToStringBuffer) before calling UseItem;
; the port's bag menu does not do that yet, so the name reads as whatever is in
; wStringBuffer. Tracked in the items plan (Stage 9) — a bag-menu gap, not an
; item-effect one.
; ---------------------------------------------------------------------------
global PrintItemUseTextAndRemoveItem
PrintItemUseTextAndRemoveItem:
    mov esi, [ItemUseText00_ref]
    mov ecx, [ItemUseText00_ref + 4]
    call iu_print_text                  ; pret: ld hl, ItemUseText00 / call PrintText
    mov al, SFX_HEAL_AILMENT
    call PlaySound
    call WaitForTextScrollButtonPress
    jmp RemoveUsedItem                  ; pret: fallthrough
