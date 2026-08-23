; joypad.asm — INT 9h keyboard ISR → emulated GB joypad state.
;
; DEVIATION{class=HAL; pret=home/joypad.asm:ReadJoypad; behavior=joypad state comes from an INT 9h keyboard ISR reading scancodes from port 0x60 into two pressed-state nibbles, instead of pret's rJOYP column strobe; evidence=the DOS target has no Game Boy joypad register so rJOYP has no hardware behind it, and every label in this file is a port-only ISR or key-mapping primitive with no pret counterpart; lifetime=permanent, the input HAL boundary is by design}
;
; Hooks IRQ 1 (protected-mode vector 9) via DPMI, reads scancodes from port
; 0x60, and maintains two pressed-state nibbles in GB bit order:
;
;   pad_dpad    bit 0=Right  1=Left  2=Up    3=Down    (1 = held)
;   pad_buttons bit 0=A      1=B     2=Select 3=Start  (1 = held)
;
; Key mapping:
;   Arrow keys        → D-pad      (both E0-prefixed and numpad scancodes)
;   X                 → A
;   Z                 → B
;   Backspace (Right Shift / Tab) → Select
;   Enter             → Start
;   Esc               → sets [pad_quit] (host-side quit, not a GB button)
;
; joypad_update (called once per frame) composes the IO_JOYP shadow from
; these nibbles using the select bits the game last wrote to rJOYP:
; bit 4 low selects the D-pad nibble, bit 5 low selects the buttons nibble,
; and pressed keys read as 0 (GB joypad lines are active-low).
;
; ISR NOTE: we do NOT chain to the BIOS INT 9 handler, so DOS keyboard
; buffering is dead while the game runs (keys can't leak into the DOS prompt).
; joypad_restore puts the original vector back on exit. Same [cs:var] DS
; recovery technique as the PIT ISR (see boot/timing.asm).
;
; KEYBOARD TEXT-ENTRY MODE (link cable plan Stage 5 step 1, added beside the
; joypad path above; port-only, no pret counterpart): when g_kbd_text_mode is
; nonzero, kbd_isr ALSO pushes each make-code's (scancode, shift) pair into a
; small ring (kbd_ring), independent of and in parallel with the joypad
; mapping cascade above, which keeps running unchanged (arrows/Enter/etc.
; still produce pad bits — menus stay alive while a text field is being
; edited). kbd_shift_state tracks LSHIFT/RSHIFT make/break unconditionally,
; regardless of g_kbd_text_mode; RSHIFT (0x36) KEEPS its existing Select
; binding below. kbd_ring_pop (host-side, non-ISR) drains the ring;
; src/input/kbd_text.asm's kbd_text_edit is the consumer. No caller invokes
; kbd_text_edit yet in a normal build this step — this file's job is only to
; make the raw-scancode capture available and leave the existing joypad
; mapping provably unaffected when g_kbd_text_mode == 0 (its default).
;
; Build: nasm -f coff -I include/ -o joypad.o joypad.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

KBD_INT         equ 0x09    ; protected-mode vector for IRQ 1
KBD_DATA_PORT   equ 0x60
PIC_CMD_PORT    equ 0x20
PIC_EOI         equ 0x20

; Scancodes (set 1, make codes; break = make | 0x80)
SC_EXT          equ 0xE0    ; extended-key prefix
SC_UP           equ 0x48
SC_DOWN         equ 0x50
SC_LEFT         equ 0x4B
SC_RIGHT        equ 0x4D
SC_X            equ 0x2D
SC_Z            equ 0x2C
SC_ENTER        equ 0x1C
SC_LSHIFT       equ 0x2A    ; text-entry shift tracking only (no joypad binding)
SC_RSHIFT       equ 0x36
SC_TAB          equ 0x0F
SC_BACKSPACE    equ 0x0E    ; Select (the mGBA/VBA/SameBoy default binding)
SC_ESC          equ 0x01
%ifdef DEBUG_NOCLIP
SC_W            equ 0x11    ; noclip toggle key
%endif

; GB joypad bit positions (match constants/hardware.inc rJOYP semantics)
PAD_RIGHT_BIT   equ 0
PAD_LEFT_BIT    equ 1
PAD_UP_BIT      equ 2
PAD_DOWN_BIT    equ 3
PAD_A_BIT       equ 0
PAD_B_BIT       equ 1
PAD_SELECT_BIT  equ 2
PAD_START_BIT   equ 3

JOYP_GET_DPAD   equ 0x10    ; rJOYP bit 4 low → D-pad nibble selected
JOYP_GET_BTN    equ 0x20    ; rJOYP bit 5 low → buttons nibble selected

; hJoyInput/hJoyHeld byte format (active HIGH) bit masks — identical to the
; pret constants/hardware.inc PAD_* layout (bit 7=Down 6=Up 5=Left 4=Right,
; 3=Start 2=Select 1=B 0=A). Used by the faithful _Joypad edge/mask layer.
HJP_BUTTONS     equ 0x0F    ; PAD_A | PAD_B | PAD_SELECT | PAD_START
HJP_UP          equ 0x40    ; PAD_UP  (bit 6)

SOFT_RESET_FRAMES equ 16    ; pret Init sets hSoftReset = 16 (frames of combo)

KBD_RING_SIZE   equ 16      ; bytes; 2 bytes/key (scancode, shift) = 8 keys buffered

; hJoyLast / hJoyReleased are not yet in gb_memmap.inc; guard so this file
; assembles standalone. Addresses from ram/hram.asm (consecutive with the
; already-mapped hJoyPressed=0xFFB3 / hJoyHeld=0xFFB4). Root should promote
; these to gb_memmap.inc canonically (see SUMMARY.md).

; ---------------------------------------------------------------------------
; Exported symbols
; ---------------------------------------------------------------------------
global joypad_init
global joypad_restore
global joypad_update
global pad_dpad             ; byte: D-pad held state (1 = pressed)
global pad_buttons          ; byte: button held state (1 = pressed)
global pad_quit             ; byte: nonzero once Esc is pressed
global pad_reset            ; byte: nonzero once the A+B+Select+Start combo fires
; --- Keyboard text-entry mode (link cable plan Stage 5 step 1) ---
; Port-only: raw-scancode capture alongside the joypad mapping above. No
; consumer is wired yet (src/input/kbd_text.asm links and is callable, but
; nothing calls it in a normal build this step).
global g_kbd_text_mode      ; byte: nonzero -> kbd_isr also buffers scancodes
global kbd_ring_pop         ; AL=scancode, AH=shift, ZF=1 empty (cli/sti-guarded read)
%ifdef DEBUG_NOCLIP
global pad_noclip           ; byte: 1 = noclip active (W toggles)
%endif

; ---------------------------------------------------------------------------
; Imported symbols
; ---------------------------------------------------------------------------
; DiscardButtonPresses lived HERE until chunk 18, because its pret mirror file was
; unbuildable; `.discard` below calls it. Provenance worth keeping: it was once
; INLINED into joypad_update as the local label `.discard`, which made the label DB
; report a confident WRONG provider (the then-dead src/engine/joypad.asm), reading
; as "unported". Extracting it into a real global was the fix, and the picker bug
; behind the bad report is fixed too — memory label-db-wrong-provider-on-inlined-
; routines. Chunk 18 then repaired the mirror and moved the routine home.
extern DiscardButtonPresses ; src/engine/joypad.asm (returns AL = 0)

; ---------------------------------------------------------------------------
; BSS
; ---------------------------------------------------------------------------
section .bss
align 4
orig_irq1_off:  resd 1
orig_irq1_sel:  resw 1
pad_dpad:       resb 1
pad_buttons:    resb 1
pad_quit:       resb 1
pad_reset:      resb 1      ; set when the soft-reset combo countdown reaches 0
soft_reset_ctr: resb 1      ; frames-of-combo countdown (pret hSoftReset)
ext_pending:    resb 1      ; set when an E0 prefix byte was just received
%ifdef DEBUG_NOCLIP
pad_noclip:     resb 1      ; toggled by W key; 1 = collision disabled
%endif

; --- Keyboard text-entry ring (link cable plan Stage 5 step 1) ---
; g_kbd_text_mode gates the ring push in kbd_isr below; kbd_shift_state tracks
; LSHIFT/RSHIFT make/break unconditionally (independent of text mode) so shift
; state is already current the moment text mode is entered. kbd_ring is a
; flat 16-byte ring of (scancode, shift) byte pairs — 8 keys buffered; on
; overflow the oldest pair is dropped (kbd_ring_pop below is the only reader).
g_kbd_text_mode:  resb 1
kbd_shift_state:  resb 1
kbd_ring:         resb KBD_RING_SIZE
kbd_ring_head:    resb 1     ; next write offset into kbd_ring (0..15)
kbd_ring_tail:    resb 1     ; next read offset into kbd_ring (0..15)

; ---------------------------------------------------------------------------
; Data — reachable from the ISR via CS override (CS base == DS base, DJGPP)
; ---------------------------------------------------------------------------
section .data
align 4
kisr_ds:        dw 0

; ---------------------------------------------------------------------------
; Code
; ---------------------------------------------------------------------------
section .text

; ---------------------------------------------------------------------------
; joypad_init — save the original IRQ1 vector and install kbd_isr
; ---------------------------------------------------------------------------
joypad_init:
    push eax
    push ebx
    push ecx
    push edx

    mov ax, ds
    mov [kisr_ds], ax

    ; pret Init seeds hSoftReset = 16; mirror that here (joypad_init is the
    ; port's power-on entry). pad_reset starts clear.
    mov byte [soft_reset_ctr], SOFT_RESET_FRAMES
    mov byte [pad_reset], 0

    ; Save original protected-mode IRQ1 vector (DPMI fn 0204h)
    mov ax, 0x0204
    mov bl, KBD_INT
    int 0x31
    mov [orig_irq1_off], edx
    mov [orig_irq1_sel], cx

    ; Install kbd_isr (DPMI fn 0205h)
    mov ax, 0x0205
    mov bl, KBD_INT
    mov cx, cs
    mov edx, kbd_isr
    int 0x31

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; joypad_restore — put the original IRQ1 vector back (call before exit)
; ---------------------------------------------------------------------------
joypad_restore:
    push eax
    push ebx
    push ecx
    push edx

    mov ax, 0x0205
    mov bl, KBD_INT
    mov cx, [orig_irq1_sel]
    mov edx, [orig_irq1_off]
    int 0x31

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; kbd_isr — IRQ 1 handler: read scancode, update pad state, EOI
; ---------------------------------------------------------------------------
kbd_isr:
    push ds
    push es
    push eax
    push ebx

    mov ax, [cs:kisr_ds]
    mov ds, ax
    mov es, ax

    in  al, KBD_DATA_PORT

    cmp al, SC_EXT
    jne .not_prefix
    mov byte [ext_pending], 1
    jmp .eoi
.not_prefix:
    mov byte [ext_pending], 0   ; consume prefix state (arrows decode the same
                                ; with or without E0, so it isn't needed yet)

    ; BL = make code, BH = 0 for press / nonzero for release
    mov bl, al
    and bl, 0x7F
    mov bh, al
    and bh, 0x80

    ; --- Shift-state tracking (added path; keyboard text-entry mode) ---
    ; Runs unconditionally, independent of g_kbd_text_mode, so shift state is
    ; already current the moment text mode is entered. SC_RSHIFT (0x36) KEEPS
    ; its existing Select binding in the cascade below unchanged — this block
    ; only maintains kbd_shift_state and falls through; it does not intercept
    ; the scancode or skip the joypad dispatch.
    cmp bl, SC_LSHIFT
    je .shift_key
    cmp bl, SC_RSHIFT
    jne .not_shift_key
.shift_key:
    test bh, bh
    jnz .shift_up
    mov byte [kbd_shift_state], 1
    jmp .not_shift_key
.shift_up:
    mov byte [kbd_shift_state], 0
.not_shift_key:

    ; --- Text-entry ring push (added path; keyboard text-entry mode) ---
    ; ISR budget: push only, no calls, no charmap translation (that is
    ; host-side, in kbd_text_edit). The joypad mapping cascade below is
    ; unaffected — this buffers a copy of the raw scancode in parallel, it
    ; does not consume or skip it. When g_kbd_text_mode is 0 (the default,
    ; normal-build state) this is a single cmp+je and nothing else executes,
    ; so the existing joypad mapping stays byte-identical to before this file
    ; was touched.
    cmp byte [g_kbd_text_mode], 0
    je .ring_done
    test bh, bh
    jnz .ring_done              ; only make codes are buffered
    push eax
    push ecx
    push edx
    movzx ecx, byte [kbd_ring_head]
    mov al, bl                  ; AL = scancode (BL is untouched below)
    mov [kbd_ring + ecx], al
    inc ecx
    and ecx, KBD_RING_SIZE - 1
    mov al, [kbd_shift_state]
    mov [kbd_ring + ecx], al
    inc ecx
    and ecx, KBD_RING_SIZE - 1
    mov dl, [kbd_ring_tail]
    cmp cl, dl
    jne .ring_no_overflow
    ; ring full: drop the oldest key by advancing tail past it
    add dl, 2
    and dl, KBD_RING_SIZE - 1
    mov [kbd_ring_tail], dl
.ring_no_overflow:
    mov [kbd_ring_head], cl
    pop edx
    pop ecx
    pop eax
.ring_done:

    ; --- D-pad ---
    cmp bl, SC_RIGHT
    jne .chk_left
    mov al, 1 << PAD_RIGHT_BIT
    jmp .apply_dpad
.chk_left:
    cmp bl, SC_LEFT
    jne .chk_up
    mov al, 1 << PAD_LEFT_BIT
    jmp .apply_dpad
.chk_up:
    cmp bl, SC_UP
    jne .chk_down
    mov al, 1 << PAD_UP_BIT
    jmp .apply_dpad
.chk_down:
    cmp bl, SC_DOWN
    jne .chk_a
    mov al, 1 << PAD_DOWN_BIT
    jmp .apply_dpad

    ; --- Buttons ---
.chk_a:
    cmp bl, SC_X
    jne .chk_b
    mov al, 1 << PAD_A_BIT
    jmp .apply_btn
.chk_b:
    cmp bl, SC_Z
    jne .chk_start
    mov al, 1 << PAD_B_BIT
    jmp .apply_btn
.chk_start:
    cmp bl, SC_ENTER
    jne .chk_sel1
    mov al, 1 << PAD_START_BIT
    jmp .apply_btn
.chk_sel1:
    cmp bl, SC_BACKSPACE        ; Select — standard emulator default (mGBA/VBA)
    je .sel
    cmp bl, SC_RSHIFT           ; Select — alternates
    je .sel
    cmp bl, SC_TAB
    jne .chk_esc
.sel:
    mov al, 1 << PAD_SELECT_BIT
    jmp .apply_btn

    ; --- Host quit (and noclip toggle in debug builds) ---
.chk_esc:
%ifdef DEBUG_NOCLIP
    cmp bl, SC_W
    jne .not_noclip_key
    test bh, bh
    jnz .eoi                    ; toggle on key-press only, ignore release
    xor byte [pad_noclip], 1
    jmp .eoi
.not_noclip_key:
%endif
    cmp bl, SC_ESC
    jne .eoi
    test bh, bh
    jnz .eoi                    ; quit on press, ignore release
    ; Text-entry mode reassigns Esc to "cancel this field" (kbd_text_edit
    ; reads it from the ring): suppress the host-quit latch while active, or
    ; cancelling a field would exit the program on the widget's very next
    ; DelayFrame (vblank.asm's pad_quit check terminates via INT 21h/4C).
    ; Joypad-mode (g_kbd_text_mode == 0, the default) behavior is unchanged.
    cmp byte [g_kbd_text_mode], 0
    jne .eoi
    mov byte [pad_quit], 1
    jmp .eoi

.apply_dpad:
    test bh, bh
    jnz .release_dpad
    or  [pad_dpad], al
    jmp .eoi
.release_dpad:
    not al
    and [pad_dpad], al
    jmp .eoi

.apply_btn:
    test bh, bh
    jnz .release_btn
    or  [pad_buttons], al
    jmp .eoi
.release_btn:
    not al
    and [pad_buttons], al

.eoi:
    mov al, PIC_EOI
    out PIC_CMD_PORT, al

    pop ebx
    pop eax
    pop es
    pop ds
    iret

; ---------------------------------------------------------------------------
; kbd_ring_pop — pop one buffered (scancode, shift) pair from the ISR ring
; kbd_isr feeds above (link cable plan Stage 5 step 1). Port-only; no pret
; counterpart. Called from normal (non-ISR) code, e.g. kbd_text_edit's poll
; loop in src/input/kbd_text.asm.
;
; In:  (none)
; Out: AL = scancode (7-bit make code), AH = shift flag (0/1).
;      ZF = 1 if the ring was empty (AL/AH undefined in that case), ZF = 0 if
;      a pair was popped. The ZF check is deliberately independent of the
;      popped byte values (a scancode of 0 never legitimately occurs, but this
;      does not rely on that): each return path ends on its own
;      value-independent flag-setting instruction.
;      Clobbers EBX/ECX/EDX. Brackets the ring read in cli/sti — kbd_isr
;      writes kbd_ring_head/kbd_ring asynchronously.
; ---------------------------------------------------------------------------
kbd_ring_pop:
    cli
    mov bl, [kbd_ring_head]
    mov cl, [kbd_ring_tail]
    cmp bl, cl
    je .empty
    movzx edx, cl
    mov al, [kbd_ring + edx]
    inc edx
    and edx, KBD_RING_SIZE - 1
    mov ah, [kbd_ring + edx]
    inc edx
    and edx, KBD_RING_SIZE - 1
    mov [kbd_ring_tail], dl
    sti
    mov ecx, 1
    test ecx, ecx      ; ZF = 0 ("found"), independent of AL/AH
    ret
.empty:
    sti
    xor eax, eax
    xor ecx, ecx
    test ecx, ecx      ; ZF = 1 ("empty")
    ret

; ---------------------------------------------------------------------------
; joypad_update — compose the IO_JOYP shadow from the held-state nibbles
;
; Called once per frame from the main loop. Respects the select bits the
; game last wrote to rJOYP (bits 4/5, active low) and presents pressed keys
; as 0 in bits 0–3, matching real GB joypad reads. Unused high bits read 1.
;
; In:  EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
joypad_update:
    push eax
    push ebx
    push ecx
    push edx

    mov al, [ebp + IO_JOYP]
    or  al, 0xCF                ; start with all input lines released (1)

    test al, JOYP_GET_DPAD      ; bit 4 low → D-pad selected
    jnz .no_dpad
    mov bl, [pad_dpad]
    not bl
    or  bl, 0xF0
    and al, bl
.no_dpad:
    test al, JOYP_GET_BTN       ; bit 5 low → buttons selected
    jnz .no_btn
    mov bl, [pad_buttons]
    not bl
    or  bl, 0xF0
    and al, bl
.no_btn:
    mov [ebp + IO_JOYP], al

    ; -----------------------------------------------------------------
    ; Faithful pret _Joypad edge/mask layer (engine/joypad.asm:_Joypad,
    ; DiscardButtonPresses, TrySoftReset; SoftReset in home/init.asm).
    ;
    ; Compose this frame's input in hJoyInput byte format (active HIGH):
    ;   bit 7=Down 6=Up 5=Left 4=Right | 3=Start 2=Select 1=B 0=A
    ; (pad_dpad bits 3=Down..0=Right << 4; pad_buttons already A/B/Sel/Start.)
    ; This AL is the port's ReadJoypad_ result — pret's "b" (new input).
    ; -----------------------------------------------------------------
    movzx eax, byte [pad_dpad]
    shl al, 4
    or  al, [pad_buttons]        ; AL = b (new input, active high)

    ; Soft reset combo: A+B+Select+Start held AND Up released. pret:
    ;   and PAD_BUTTONS | PAD_UP / cp PAD_BUTTONS / jp z, TrySoftReset
    mov bl, al
    and bl, HJP_BUTTONS | HJP_UP
    cmp bl, HJP_BUTTONS
    je  .try_soft_reset

    ; hJoyReleased = (hJoyLast ^ b) & hJoyLast
    ; hJoyPressed  = (hJoyLast ^ b) & b
    mov cl, [ebp + hJoyLast]   ; e = old input
    mov ch, cl
    xor ch, al                   ; d = old ^ new  (changed bits)
    mov bl, ch
    and bl, cl                   ; released = changed & old
    mov [ebp + hJoyReleased], bl
    mov bl, ch
    and bl, al                   ; pressed  = changed & new
    mov [ebp + hJoyPressed], bl
    mov [ebp + hJoyLast], al   ; hJoyLast = b

    ; Global input disable (pret: wStatusFlags5 bit BIT_DISABLE_JOYPAD →
    ; DiscardButtonPresses, which zeroes held/pressed/released).
    mov bl, [ebp + wStatusFlags5]
    test bl, 1 << BIT_DISABLE_JOYPAD
    jnz .discard

    ; hJoyHeld = hJoyLast
    mov al, [ebp + hJoyLast]
    mov [ebp + hJoyHeld], al

    ; wJoyIgnore mask: clear ignored buttons from held & pressed (pret leaves
    ; hJoyReleased unmasked). ret early when the mask is empty.
    mov bl, [ebp + wJoyIgnore]
    test bl, bl
    jz  .done
    not bl                       ; b = ~wJoyIgnore
    and [ebp + hJoyHeld], bl
    and [ebp + hJoyPressed], bl
    jmp .done

.discard:
    ; pret _Joypad tail-jumps to DiscardButtonPresses here. The ISR must fall
    ; through to its own register restore instead of returning, so this calls the
    ; routine (below) rather than jumping. Clobbering AL is safe: .done pops EAX.
    call DiscardButtonPresses
    jmp .done

.try_soft_reset:
    ; pret TrySoftReset: DelayFrame; dec [hSoftReset]; jp z, SoftReset else
    ; re-poll (jp Joypad). joypad_update already runs once per frame from the
    ; DelayFrame pipeline, so one call == one held frame — the per-frame
    ; DelayFrame/re-poll cadence is provided by the caller, not re-entered here.
    ; Like pret, combo frames skip the edge layer (hJoyLast/Pressed/Released/
    ; Held are left untouched this frame).
    dec byte [soft_reset_ctr]
    jnz .done
    ; Countdown expired: request a soft reset. The port has no in-process
    ; re-init entry wired yet (Init is called once from entry.asm and runs the
    ; game loop), so we raise pad_reset instead of quitting — the Esc quit path
    ; is untouched. FOLLOW-UP: have the frame loop / entry honor pad_reset by
    ; re-entering Init (StopAllSounds → white-out → 32-frame delay → Init).
    mov byte [pad_reset], 1
    mov byte [soft_reset_ctr], SOFT_RESET_FRAMES  ; replenish (pret Init reseeds)

.done:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

