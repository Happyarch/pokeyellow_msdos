; uncompress.asm — faithful port of the Gen-1 runtime sprite decompressor.
;
; Source: home/uncompress.asm (pret/pokeyellow), 1:1 in behavior.
; Reference: docs/translation_log.md (UncompressSpriteData entry),
;            docs/current_plan_battle_frontend.md (Stage 1c research).
;
; WHY a faithful runtime port (not a build-time PNG→2bpp shortcut): many Gen-1
; sprite/ACE glitches and glitch-Pokemon front sprites depend on the exact
; behavior of this RLE + length-encoded bit-stream decoder on malformed data.
; A build-time decode would silently kill them. (User directive 2026-06-28.)
;
; ---------------------------------------------------------------------------
; Addressing model (port-specific; see CLAUDE.md memory model)
; ---------------------------------------------------------------------------
;   * All emulated-GB state (the wSprite* scratch vars at $D0A0+, the input
;     stream, and the three sprite buffers at $A000/$A188/$A310) lives in the
;     EBP-relative GB space and is accessed as [EBP + addr]. Input + buffers are
;     all GB addresses < $10000, so the 16-bit pointer math (kept in SI/DX low
;     words, stored back as `mov [ebp+var], si`) never wraps and is faithful.
;   * The const decode tables are ROM in pret, read through [hl]. In the port
;     they are FLAT .data (NOT [ebp+...]). The differential-decode table chosen
;     per-call is held in FLAT 32-bit selectors sp_dtbl0/sp_dtbl1 (.bss) rather
;     than the 16-bit wSpriteDecodeTable*Ptr GB vars (which can't hold a flat
;     address). LengthEncodingOffsetList / NybbleReverseTable are read directly
;     by flat label + index.
;
; ---------------------------------------------------------------------------
; Register model (this is a tightly-coupled "naked" cluster, like the GB)
; ---------------------------------------------------------------------------
; A=AL, BC=BX (B=BH,C=BL), DE=DX (D=DH,E=DL), HL=ESI, EBP=GB base. All durable
; state lives in WRAM vars; registers are transient within short spans (the GB
; reloads pointers from the vars rather than keeping them live). The control-flow
; routines (_UncompressSpriteData, UncompressSpriteDataLoop, MoveToNextBuffer-
; Position, UnpackSprite, SpriteDifferentialDecode, XorSpriteChunks,
; UnpackSpriteMode2) carry NO register-saving prologue: the GB terminates its
; "endless" decode loop by popping the loop's return address off the stack
; (MoveToNextBufferPosition .allColumnsDone: `pop hl`), so adding prologues would
; desync the stack. The `pop hl` is mirrored as `pop esi` (discard 4-byte return).
; Leaf helpers are register-balanced.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; wSpriteLoadFlags bit masks (pret const_def order):
;   bit 0 = BIT_USE_SPRITE_BUFFER_2, bit 1 = BIT_LAST_SPRITE_CHUNK
%define MASK_USE_BUFFER_2  0x01
%define MASK_LAST_CHUNK    0x02

extern FillMemory

global UncompressSpriteData
global _UncompressSpriteData

; ---------------------------------------------------------------------------
section .text

; ---------------------------------------------------------------------------
; UncompressSpriteData — public entry (pics.asm caller).
; In:  [wSpriteInputPtr] = GB addr of compressed stream, [wSpriteFlipped] set.
; Out: sSpriteBuffer1 / sSpriteBuffer2 hold the two final 1bpp planes
;      (column-major, dense WxH). pret bankswitch/OpenSRAM are no-ops in the port.
; ---------------------------------------------------------------------------
UncompressSpriteData:
    call _UncompressSpriteData
    ret

; ---------------------------------------------------------------------------
; _UncompressSpriteData — init decode state, then fall into the decode loop.
; (No prologue — part of the naked cluster.)
; ---------------------------------------------------------------------------
_UncompressSpriteData:
    mov esi, sSpriteBuffer1
    mov bx, 2 * SPRITEBUFFERSIZE         ; clear sprite buffer 1 + 2
    xor al, al
    call FillMemory                      ; (preserves ESI/EAX/EBX/EDX/EBP)
    mov byte [ebp + wSpriteInputBitCounter], 1
    mov byte [ebp + wSpriteOutputBitOffset], 3
    xor al, al
    mov [ebp + wSpriteCurPosX], al
    mov [ebp + wSpriteCurPosY], al
    mov [ebp + wSpriteLoadFlags], al
    call ReadNextInputByte               ; first byte = dims (hi nyb=W, lo nyb=H) in tiles
    mov bl, al                           ; save dims byte
    and al, 0x0f                         ; low nybble = height in tiles
    shl al, 3                            ;   *8 = pixels
    mov [ebp + wSpriteHeight], al
    mov al, bl
    shr al, 4                            ; high nybble = width in tiles
    shl al, 3                            ;   *8 = pixels
    mov [ebp + wSpriteWidth], al
    call ReadNextInputBit                ; first bit picks the buffer for chunk 0
    mov [ebp + wSpriteLoadFlags], al
    ; fall through

; ---------------------------------------------------------------------------
; UncompressSpriteDataLoop — decode one 1bpp chunk into buffer 1 or 2.
; Endless loop; terminated inside MoveToNextBufferPosition by popping the stack.
; ---------------------------------------------------------------------------
UncompressSpriteDataLoop:
    mov esi, sSpriteBuffer1
    mov al, [ebp + wSpriteLoadFlags]
    test al, MASK_USE_BUFFER_2
    jz .useBuffer1
    mov esi, sSpriteBuffer2
.useBuffer1:
    call StoreSpriteOutputPointer
    mov al, [ebp + wSpriteLoadFlags]
    test al, MASK_LAST_CHUNK
    jz .startDecompression               ; only the last chunk carries an unpack mode
    call ReadNextInputBit
    test al, al
    jz .unpackingMode0                   ; 0   -> mode 0
    call ReadNextInputBit                ; 1 0 -> mode 1
    inc al                               ; 1 1 -> mode 2
.unpackingMode0:
    mov [ebp + wSpriteUnpackMode], al
.startDecompression:
    call ReadNextInputBit
    test al, al
    jz .readRLEncodedZeros               ; leading bit 0 -> stream starts with zeros
.readNextInput:
    call ReadNextInputBit
    mov bl, al                           ; c = first bit
    call ReadNextInputBit
    shl bl, 1                            ; sla c
    or al, bl                            ; a = (bit0<<1) | bit1  (2-bit group)
    test al, al
    jz .readRLEncodedZeros               ; 00 -> RLE zeros
    call WriteSpriteBitsToBuffer
    call MoveToNextBufferPosition
    jmp .readNextInput
.readRLEncodedZeros:
    xor bl, bl                           ; c = 0; count consecutive 1s = bit-length of the number
.countOnesLoop:
    call ReadNextInputBit
    test al, al
    jz .countOnesDone
    inc bl
    jmp .countOnesLoop
.countOnesDone:
    movzx eax, bl
    add eax, eax                         ; 2*c = byte offset into the 16-bit table
    mov dx, [LengthEncodingOffsetList + eax]   ; de = 2^(c+1)-1 offset (flat read)
    push edx                             ; save offset
    inc bl                               ; read c+1 bits
    xor dx, dx                           ; de = number = 0
.readNumberLoop:
    call ReadNextInputBit
    or al, dl
    mov dl, al                           ; e = (e | bit)
    dec bl
    jz .readNumberDone
    shl dl, 1                            ; sla e \  16-bit shift-left of de
    rcl dh, 1                            ; rl  d /
    jmp .readNumberLoop
.readNumberDone:
    pop eax                              ; ax = offset
    add dx, ax                           ; de = number + offset = run length
.writeZerosLoop:
    mov bh, dl                           ; save e across WriteSpriteBitsToBuffer (it clobbers DL)
    xor al, al                           ; write 00
    call WriteSpriteBitsToBuffer
    mov dl, bh                           ; restore e
    call MoveToNextBufferPosition
    dec dx                               ; dec de
    test dh, dh
    jnz .continueZeros
    test dl, dl
.continueZeros:
    jnz .writeZerosLoop
    jmp .readNextInput

; ---------------------------------------------------------------------------
; MoveToNextBufferPosition — advance the output cursor; on the last column of
; the last chunk, cancel the decode loop (pop its return) and go to UnpackSprite.
; ---------------------------------------------------------------------------
MoveToNextBufferPosition:
    mov bh, [ebp + wSpriteHeight]
    mov al, [ebp + wSpriteCurPosY]
    inc al
    cmp al, bh
    je .curColumnDone
    mov [ebp + wSpriteCurPosY], al
    movzx esi, word [ebp + wSpriteOutputPtr]
    inc si
    mov [ebp + wSpriteOutputPtr], si
    ret
.curColumnDone:
    xor al, al
    mov [ebp + wSpriteCurPosY], al
    mov al, [ebp + wSpriteOutputBitOffset]
    test al, al
    jz .bitOffsetsDone
    dec al                               ; same column byte, next 2-bit field
    mov [ebp + wSpriteOutputBitOffset], al
    mov ax, [ebp + wSpriteOutputPtrCached]
    mov [ebp + wSpriteOutputPtr], ax
    ret
.bitOffsetsDone:
    mov byte [ebp + wSpriteOutputBitOffset], 3
    mov al, [ebp + wSpriteCurPosX]
    add al, 8
    mov [ebp + wSpriteCurPosX], al
    mov bh, al
    mov al, [ebp + wSpriteWidth]
    cmp al, bh
    je .allColumnsDone
    movzx esi, word [ebp + wSpriteOutputPtr]
    inc si
    jmp StoreSpriteOutputPointer
.allColumnsDone:
    pop esi                              ; GB `pop hl`: discard the loop's return addr
    xor al, al
    mov [ebp + wSpriteCurPosX], al
    mov al, [ebp + wSpriteLoadFlags]
    test al, MASK_LAST_CHUNK
    jnz .done
    xor al, MASK_USE_BUFFER_2            ; flip target buffer
    or al, MASK_LAST_CHUNK               ; mark last chunk
    mov [ebp + wSpriteLoadFlags], al
    jmp UncompressSpriteDataLoop
.done:
    jmp UnpackSprite

; ---------------------------------------------------------------------------
; WriteSpriteBitsToBuffer — OR the 2-bit value in AL into the output byte at the
; current bit offset.  Clobbers AL, DL, ESI.
; ---------------------------------------------------------------------------
WriteSpriteBitsToBuffer:
    mov dl, al                           ; e = value
    mov al, [ebp + wSpriteOutputBitOffset]
    test al, al
    jz .offset0
    cmp al, 2
    jb .offset1
    je .offset2
    ror dl, 1                            ; offset 3: rrc e, rrc e
    ror dl, 1
    jmp .offset0
.offset1:
    shl dl, 1
    shl dl, 1
    jmp .offset0
.offset2:
    rol dl, 4                            ; swap e
.offset0:
    movzx esi, word [ebp + wSpriteOutputPtr]
    mov al, [ebp + esi]
    or al, dl
    mov [ebp + esi], al
    ret

; ---------------------------------------------------------------------------
; ReadNextInputBit — return the next stream bit in AL (0/1).  Clobbers AL, ESI.
; ---------------------------------------------------------------------------
ReadNextInputBit:
    mov al, [ebp + wSpriteInputBitCounter]
    dec al
    jnz .haveBits
    call ReadNextInputByte
    mov [ebp + wSpriteInputCurByte], al
    mov al, 8
.haveBits:
    mov [ebp + wSpriteInputBitCounter], al
    mov al, [ebp + wSpriteInputCurByte]
    rol al, 1                            ; rlca — MSB first
    mov [ebp + wSpriteInputCurByte], al
    and al, 1
    ret

; ---------------------------------------------------------------------------
; ReadNextInputByte — return the next stream byte in AL.  Clobbers AL, ESI.
; ---------------------------------------------------------------------------
ReadNextInputByte:
    movzx esi, word [ebp + wSpriteInputPtr]
    mov al, [ebp + esi]
    inc si
    mov [ebp + wSpriteInputPtr], si
    ret

; ---------------------------------------------------------------------------
; UnpackSprite — postprocess the two decoded chunks per the unpack mode.
; ---------------------------------------------------------------------------
UnpackSprite:
    mov al, [ebp + wSpriteUnpackMode]
    cmp al, 2
    je UnpackSpriteMode2
    test al, al
    jnz XorSpriteChunks
    mov esi, sSpriteBuffer1              ; mode 0: differential-decode both chunks
    call SpriteDifferentialDecode
    mov esi, sSpriteBuffer2
    ; fall through

; ---------------------------------------------------------------------------
; SpriteDifferentialDecode — in: ESI(HL) = buffer to decode in place.
; bit 0 preserves the running bit value, bit 1 toggles it (start value 0).
; ---------------------------------------------------------------------------
SpriteDifferentialDecode:
    xor al, al
    mov [ebp + wSpriteCurPosX], al
    mov [ebp + wSpriteCurPosY], al
    call StoreSpriteOutputPointer
    mov al, [ebp + wSpriteFlipped]
    test al, al
    jz .notFlipped
    mov dword [sp_dtbl0], DecodeNybble0TableFlipped
    mov dword [sp_dtbl1], DecodeNybble1TableFlipped
    jmp .tablesStored
.notFlipped:
    mov dword [sp_dtbl0], DecodeNybble0Table
    mov dword [sp_dtbl1], DecodeNybble1Table
.tablesStored:
    xor dl, dl                           ; e = last decoded nybble = 0
.decodeNextByteLoop:
    movzx esi, word [ebp + wSpriteOutputPtr]
    mov al, [ebp + esi]
    mov bh, al                           ; b = byte
    shr al, 4                            ; high nybble
    call DifferentialDecodeNybble
    shl al, 4                            ; decoded high -> high position
    mov dh, al                           ; d = decoded high
    mov al, bh
    and al, 0x0f                         ; low nybble
    call DifferentialDecodeNybble
    or al, dh                            ; combine
    mov bh, al
    movzx esi, word [ebp + wSpriteOutputPtr]
    mov al, bh
    mov [ebp + esi], al                  ; write decoded byte
    movzx eax, byte [ebp + wSpriteHeight]
    movzx esi, word [ebp + wSpriteOutputPtr]
    add si, ax                           ; next column (down one tile-column of bytes)
    mov [ebp + wSpriteOutputPtr], si
    mov al, [ebp + wSpriteCurPosX]
    add al, 8
    mov [ebp + wSpriteCurPosX], al
    mov bh, al
    mov al, [ebp + wSpriteWidth]
    cmp al, bh
    jne .decodeNextByteLoop              ; row not done
    xor al, al
    mov dl, al                           ; e = 0 (reset run value for next row)
    mov [ebp + wSpriteCurPosX], al
    mov al, [ebp + wSpriteCurPosY]
    inc al
    mov [ebp + wSpriteCurPosY], al
    mov bh, al
    mov al, [ebp + wSpriteHeight]
    cmp al, bh
    je .done
    movzx esi, word [ebp + wSpriteOutputPtrCached]
    inc si
    call StoreSpriteOutputPointer
    jmp .decodeNextByteLoop
.done:
    mov byte [ebp + wSpriteCurPosY], 0
    ret

; ---------------------------------------------------------------------------
; DifferentialDecodeNybble — in: AL = nybble, DL(E) = last decoded nybble.
; out: AL = decoded nybble, DL = updated last decoded.  Clobbers EAX, ECX, ESI.
;      Preserves DH and BX.
; ---------------------------------------------------------------------------
DifferentialDecodeNybble:
    shr al, 1                            ; CF = old bit0; al = nybble>>1 (table index)
    setc cl                              ; cl = which nybble half (0=high,1=low)
    mov ch, al                           ; ch = table index (0..7)
    mov al, [ebp + wSpriteFlipped]
    test al, al
    jz .notFlipped
    test dl, 0x08                        ; flipped: MSB of last decoded
    jmp .haveBit
.notFlipped:
    test dl, 0x01                        ; else LSB of last decoded
.haveBit:
    jnz .initialValue1
    mov esi, [sp_dtbl0]
    jmp .lookup
.initialValue1:
    mov esi, [sp_dtbl1]
.lookup:
    movzx eax, ch
    mov al, [esi + eax]                  ; flat table byte
    test cl, cl
    jnz .selectLow
    shr al, 4                            ; high nybble (GB swap a)
.selectLow:
    and al, 0x0f
    mov dl, al                           ; update last decoded
    ret

; ---------------------------------------------------------------------------
; XorSpriteChunks — differential-decode the source chunk, then XOR it into the
; destination chunk (used by unpack modes 1 and 2).
; ---------------------------------------------------------------------------
XorSpriteChunks:
    xor al, al
    mov [ebp + wSpriteCurPosX], al
    mov [ebp + wSpriteCurPosY], al
    call ResetSpriteBufferPointers
    movzx esi, word [ebp + wSpriteOutputPtr]
    call SpriteDifferentialDecode
    call ResetSpriteBufferPointers
    movzx esi, word [ebp + wSpriteOutputPtr]        ; hl = source
    movzx edx, word [ebp + wSpriteOutputPtrCached]  ; de = dest
.xorLoop:
    mov al, [ebp + wSpriteFlipped]
    test al, al
    jz .notFlipped
    push edx                             ; ReverseNybble path: preserve dest ptr
    mov al, [ebp + edx]
    mov bh, al                           ; b = dest byte
    shr al, 4
    call ReverseNybble
    shl al, 4
    mov bl, al                           ; c = reversed high nybble
    mov al, bh
    and al, 0x0f
    call ReverseNybble
    or al, bl
    pop edx
    mov [ebp + edx], al
.notFlipped:
    mov al, [ebp + esi]                  ; ld a,[hli]
    inc si
    mov bh, al                           ; b = source byte
    mov al, [ebp + edx]
    xor al, bh
    mov [ebp + edx], al
    inc dx                               ; inc de
    mov al, [ebp + wSpriteCurPosY]
    inc al
    mov [ebp + wSpriteCurPosY], al
    mov bh, al
    mov al, [ebp + wSpriteHeight]
    cmp al, bh
    jne .xorLoop
    xor al, al
    mov [ebp + wSpriteCurPosY], al
    mov al, [ebp + wSpriteCurPosX]
    add al, 8
    mov [ebp + wSpriteCurPosX], al
    mov bh, al
    mov al, [ebp + wSpriteWidth]
    cmp al, bh
    jne .xorLoop
    mov byte [ebp + wSpriteCurPosX], 0
    ret

; ---------------------------------------------------------------------------
; ReverseNybble — in: AL = nybble (0..15); out: AL = bit-reversed nybble.
; Clobbers ECX.
; ---------------------------------------------------------------------------
ReverseNybble:
    movzx ecx, al
    mov al, [NybbleReverseTable + ecx]
    ret

; ---------------------------------------------------------------------------
; ResetSpriteBufferPointers — set output/cached ptrs to buffer 1/2 per the
; BIT_USE_SPRITE_BUFFER_2 flag (output = the chunk decoded this pass).
; ---------------------------------------------------------------------------
ResetSpriteBufferPointers:
    mov al, [ebp + wSpriteLoadFlags]
    test al, MASK_USE_BUFFER_2
    jnz .buffer2Selected
    mov word [ebp + wSpriteOutputPtr], sSpriteBuffer2
    mov word [ebp + wSpriteOutputPtrCached], sSpriteBuffer1
    ret
.buffer2Selected:
    mov word [ebp + wSpriteOutputPtr], sSpriteBuffer1
    mov word [ebp + wSpriteOutputPtrCached], sSpriteBuffer2
    ret

; ---------------------------------------------------------------------------
; UnpackSpriteMode2 — differential-decode BOTH chunks, then XOR (flipped flag is
; cleared for the destination decode, restored before the XOR).
; ---------------------------------------------------------------------------
UnpackSpriteMode2:
    call ResetSpriteBufferPointers
    mov al, [ebp + wSpriteFlipped]
    push eax
    mov byte [ebp + wSpriteFlipped], 0
    movzx esi, word [ebp + wSpriteOutputPtrCached]
    call SpriteDifferentialDecode
    call ResetSpriteBufferPointers
    pop eax
    mov [ebp + wSpriteFlipped], al
    jmp XorSpriteChunks

; ---------------------------------------------------------------------------
; StoreSpriteOutputPointer — store ESI(HL) into the output + cached pointers.
; ---------------------------------------------------------------------------
StoreSpriteOutputPointer:
    mov [ebp + wSpriteOutputPtr], si
    mov [ebp + wSpriteOutputPtrCached], si
    ret

; ---------------------------------------------------------------------------
section .data
align 4

; Differential-decode tables (pret `dn x,y` = db (x<<4)|y, pre-expanded).
DecodeNybble0Table:         db 0x01, 0x32, 0x76, 0x45, 0xFE, 0xCD, 0x89, 0xBA
DecodeNybble1Table:         db 0xFE, 0xCD, 0x89, 0xBA, 0x01, 0x32, 0x76, 0x45
DecodeNybble0TableFlipped:  db 0x08, 0xC4, 0xE6, 0x2A, 0xF7, 0x3B, 0x19, 0xD5
DecodeNybble1TableFlipped:  db 0xF7, 0x3B, 0x19, 0xD5, 0x08, 0xC4, 0xE6, 0x2A

; maps each nybble to its bit-reverse
NybbleReverseTable:         db 0x0, 0x8, 0x4, 0xC, 0x2, 0xA, 0x6, 0xE
                            db 0x1, 0x9, 0x5, 0xD, 0x3, 0xB, 0x7, 0xF

; the nth item is 2^(n+1) - 1
LengthEncodingOffsetList:
    dw 0x0001, 0x0003, 0x0007, 0x000F, 0x001F, 0x003F, 0x007F, 0x00FF
    dw 0x01FF, 0x03FF, 0x07FF, 0x0FFF, 0x1FFF, 0x3FFF, 0x7FFF, 0xFFFF

; ---------------------------------------------------------------------------
section .bss
align 4

; Flat 32-bit selectors for the chosen differential-decode tables (port-local;
; the GB stored ROM addresses in 16-bit wSpriteDecodeTable*Ptr, which can't hold
; a flat .data address — see header).
sp_dtbl0: resd 1
sp_dtbl1: resd 1
