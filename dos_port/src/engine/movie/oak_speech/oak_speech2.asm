; oak_speech2.asm — the Oak-speech naming flow (menu-intro A4.4).
;
; Source: engine/movie/oak_speech/oak_speech2.asm.
;
; This file is being ported incrementally. It currently holds GetDefaultName (the
; default-name lookup). ChoosePlayerName / ChooseRivalName, the OakSpeechSlidePic*
; slides, and DisplayIntroNameTextBox land in the following A4.4 steps, each with
; its own pixel/golden verification (the slides and the name menu draw into the
; projected UI_OAK_SPEECH surface, so they need runtime evidence, not just an
; assemble).
;
; PROJECTION: like every boot cinematic, the naming flow keeps the Game Boy's
; 160x144 composition centred on the canvas (movie_projection, UI_OAK_SPEECH).
; pret's hlcoord coordinates are offset by UI_OAK_SPEECH_(COL,ROW) = (10,3) into
; the 40-wide canvas, and the slide's row-stride math uses the port's 40-wide
; SCREEN_TILES_W, not pret's 20. (Applied as each routine lands.)
;
; The default-name DATA (DefaultNames{Player,Rival}{,List}) is Tier-1 generated
; data — see tools/generators/gen_default_names.py / assets/default_names.inc.
;
; Build: nasm -f coff -I include/ -I . -o oak_speech2.o oak_speech2.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "gb_constants.inc"

%include "assets/default_names.inc"   ; DefaultNames{Player,Rival}{,List} (section .data)

section .text

; ---------------------------------------------------------------------------
; GetDefaultName — copy the AL-th name from a default-name list into wNameBuffer.
;
; Source: engine/movie/oak_speech/oak_speech2.asm:GetDefaultName. pret walks the
; '@'-terminated list counting entries until the running index matches, then
; `jp CopyData` copies NAME_BUFFER_LENGTH bytes from that name to wNameBuffer.
;
; DEVIATION{class=data-model; pret=engine/movie/oak_speech/oak_speech2.asm:GetDefaultName; behavior=the tail jp CopyData is realised as an inline flat->GB rep movsb instead of a call; evidence=the name list is flat program-image data (assets/default_names.inc) not GB WRAM, and the port's CopyData adds EBP to BOTH source and dest (copy_data.asm), so a flat source pointer cannot go through it -- PrepareOakSpeech takes the same flat rep movsb path for the same reason; lifetime=permanent flat-memory model}
;
; In:  AL = name index (0-based), ESI = FLAT ptr to the '@'-terminated name list.
; Out: the chosen name (NAME_BUFFER_LENGTH bytes) copied to [EBP + wNameBuffer].
;      Clobbers EAX/EBX/ECX/ESI/EDI.
; ---------------------------------------------------------------------------
global GetDefaultName
GetDefaultName:
    mov bh, al                        ; BH = target index   (pret ld b, a)
    xor bl, bl                        ; BL = running index  (pret ld c, 0)
.loop:
    mov edi, esi                      ; EDI = start of current name (pret ld d,h / ld e,l)
.innerLoop:
    mov al, [esi]                     ; ld a, [hli]  — flat list read
    inc esi
    cmp al, '@'                       ; cp '@'
    jne .innerLoop
    cmp bh, bl                        ; ld a,b / cp c
    je .foundName
    inc bl                            ; inc c
    jmp .loop
.foundName:
    ; ESI (found name start) is in EDI; copy NAME_BUFFER_LENGTH bytes flat -> GB.
    mov esi, edi                      ; pret ld h,d / ld l,e
    lea edi, [ebp + wNameBuffer]      ; ld de, wNameBuffer (GB dest)
    mov ecx, NAME_BUFFER_LENGTH       ; ld bc, NAME_BUFFER_LENGTH
    rep movsb
    ret
