; events.inc — event-flag accessors over wEventFlags (wEventFlags).
;
; Faithful translation of pret's CheckEvent / SetEvent / ResetEvent
; (macros/scripts/events.asm). An event is a bit index (EVENT_*, from
; assets/event_constants.inc) into the wEventFlags bit array; this header turns an
; index into (byte offset, bit mask) at assembly time.
;
; Requires (include before this): gb_memmap.inc (wEventFlags) and
; assets/event_constants.inc (EVENT_* indices).
;
; Convention: EBP = base of emulated GB memory. All three macros CLOBBER AL.
; CheckEvent additionally sets ZF (and is the only one that reads flags):
;   ZF=1  → event is CLEAR   (use `jz` / `je`)
;   ZF=0  → event is SET     (use `jnz` / `jne`)
; matching pret's `bit n,[hl]` → `jr z` idiom exactly.

%ifndef EVENTS_INC
%define EVENTS_INC

; idx → byte offset within wEventFlags, and the single-bit mask. Modulo is written
; as idx-(idx/8)*8 to avoid NASM's '%' (preprocessor) in expressions.
%define EVENT_BYTE(i)  ((i) / 8)
%define EVENT_MASK(i)  (1 << ((i) - ((i) / 8) * 8))

; CheckEvent EVENT_X — test the flag; sets ZF (see header). Clobbers AL.
%macro CheckEvent 1
    mov al, [ebp + wEventFlags + EVENT_BYTE(%1)]
    test al, EVENT_MASK(%1)
%endmacro

; SetEvent EVENT_X — set the flag. Clobbers AL.
%macro SetEvent 1
    mov al, [ebp + wEventFlags + EVENT_BYTE(%1)]
    or  al, EVENT_MASK(%1)
    mov [ebp + wEventFlags + EVENT_BYTE(%1)], al
%endmacro

; ResetEvent EVENT_X — clear the flag. Clobbers AL.
%macro ResetEvent 1
    mov al, [ebp + wEventFlags + EVENT_BYTE(%1)]
    and al, ~EVENT_MASK(%1) & 0xFF
    mov [ebp + wEventFlags + EVENT_BYTE(%1)], al
%endmacro

; ---------------------------------------------------------------------------
; The *ReuseHL family — pret macros/scripts/events.asm.
;
; pret's versions skip reloading the pointer when the PREVIOUS event macro
; already pointed HL at the same byte of wEventFlags, using `event_byte`: a
; variable the ASSEMBLER carries across macro invocations. These mirrors do the
; same thing with NASM's %assign, so the elision happens where pret does it
; rather than being reconstructed by a tool that would have to model rgbasm's
; bookkeeping and could omit a needed reload — which reads the WRONG event flag
; with nothing to show for it.
;
; ESI is HL. Unlike CheckEvent/SetEvent above, these operate on [ebp+esi]
; directly and DO NOT clobber AL, matching pret's `bit`/`set`/`res` on [hl].
;
; SEAM RULE: `event_byte` tracks the EMITTED sequence, so anything that breaks
; the correspondence with pret's sequence — a bailed region between two of these
; — must reset it. Emitters reset with `%assign event_byte -1` at each region
; head, which forces a reload and degrades safely to the always-reload form.
%assign event_byte -1

%macro CheckEventReuseHL 1
    %if event_byte != EVENT_BYTE(%1)
        %assign event_byte EVENT_BYTE(%1)
        mov esi, wEventFlags + event_byte
    %endif
    test byte [ebp + esi], EVENT_MASK(%1)
%endmacro

%macro SetEventReuseHL 1
    %if event_byte != EVENT_BYTE(%1)
        %assign event_byte EVENT_BYTE(%1)
        mov esi, wEventFlags + event_byte
    %endif
    or byte [ebp + esi], EVENT_MASK(%1)
%endmacro

%macro ResetEventReuseHL 1
    %if event_byte != EVENT_BYTE(%1)
        %assign event_byte EVENT_BYTE(%1)
        mov esi, wEventFlags + event_byte
    %endif
    and byte [ebp + esi], ~EVENT_MASK(%1) & 0xFF
%endmacro

; The AfterBranch forms take the event used BEFORE the branch as %2: pret cannot
; know which path was taken, so it states the incoming state explicitly. THE PORT
; DOES NOT USE %2 TO ELIDE, and always reloads. pret's assertion is about pret's
; emitted code; in the port the pre-branch region may have BAILED and not been
; emitted at all — measured on SilphCo2F, where the region holding the
; EventFlagAddress that sets the pointer bails and only `.unlock_door1` survives.
; Eliding there would write through whatever ESI happened to hold.
%macro CheckEventAfterBranchReuseHL 2
    %assign event_byte EVENT_BYTE(%1)
    mov esi, wEventFlags + event_byte
    test byte [ebp + esi], EVENT_MASK(%1)
%endmacro

%macro SetEventAfterBranchReuseHL 2
    %assign event_byte EVENT_BYTE(%1)
    mov esi, wEventFlags + event_byte
    or byte [ebp + esi], EVENT_MASK(%1)
%endmacro

%macro ResetEventAfterBranchReuseHL 2
    %assign event_byte EVENT_BYTE(%1)
    mov esi, wEventFlags + event_byte
    and byte [ebp + esi], ~EVENT_MASK(%1) & 0xFF
%endmacro

; pret: "dangerous, only use when HL is guaranteed to be the desired value", and
; it emits no reload at all. THE PORT RELOADS ANYWAY. pret's guarantee is that HL
; already equals wEventFlags + byte(%1), so loading exactly that cannot change the
; pointer — but in the port the code that established it may sit in a region the
; transpiler BAILED and never emitted, in which case ESI holds something unrelated
; and the write lands in the wrong memory with nothing to show for it.
%macro CheckEventForceReuseHL 1
    %assign event_byte EVENT_BYTE(%1)
    mov esi, wEventFlags + event_byte
    test byte [ebp + esi], EVENT_MASK(%1)
%endmacro

%macro SetEventForceReuseHL 1
    %assign event_byte EVENT_BYTE(%1)
    mov esi, wEventFlags + event_byte
    or byte [ebp + esi], EVENT_MASK(%1)
%endmacro

%macro ResetEventForceReuseHL 1
    %assign event_byte EVENT_BYTE(%1)
    mov esi, wEventFlags + event_byte
    and byte [ebp + esi], ~EVENT_MASK(%1) & 0xFF
%endmacro

; pret does `bit` then `set`: on SM83 `set` writes no flags, so the Z from the
; test survives to the consumer. x86's `or` DOES write ZF, so the mutation is
; wrapped — same convention as CheckAndSetEvent below.
%macro CheckAndSetEventReuseHL 1
    %if event_byte != EVENT_BYTE(%1)
        %assign event_byte EVENT_BYTE(%1)
        mov esi, wEventFlags + event_byte
    %endif
    test byte [ebp + esi], EVENT_MASK(%1)
    pushfd
    or byte [ebp + esi], EVENT_MASK(%1)
    popfd
%endmacro

%macro CheckAndResetEventReuseHL 1
    %if event_byte != EVENT_BYTE(%1)
        %assign event_byte EVENT_BYTE(%1)
        mov esi, wEventFlags + event_byte
    %endif
    test byte [ebp + esi], EVENT_MASK(%1)
    pushfd
    and byte [ebp + esi], ~EVENT_MASK(%1) & 0xFF
    popfd
%endmacro

%macro CheckAndSetEvent 1
    mov al, [ebp + wEventFlags + EVENT_BYTE(%1)]
    test al, EVENT_MASK(%1)
    pushfd
    or al, EVENT_MASK(%1)
    mov [ebp + wEventFlags + EVENT_BYTE(%1)], al
    popfd
%endmacro

%macro CheckAndResetEvent 1
    mov al, [ebp + wEventFlags + EVENT_BYTE(%1)]
    test al, EVENT_MASK(%1)
    pushfd
    and al, ~EVENT_MASK(%1) & 0xFF
    mov [ebp + wEventFlags + EVENT_BYTE(%1)], al
    popfd
%endmacro

%macro SetEvents 1-*
    %rep %0
        SetEvent %1
        %rotate 1
    %endrep
%endmacro

%macro ResetEvents 1-*
    %rep %0
        ResetEvent %1
        %rotate 1
    %endrep
%endmacro

%macro SetEventRange 2
    %assign i %1
    %rep (%2) - (%1) + 1
        SetEvent i
        %assign i i + 1
    %endrep
%endmacro

; The optional THIRD argument is pret's "A is already zero" hint: its macro tests
; `IF (_NARG < 3) || (((\1) % 8) != 0)` purely to decide whether to emit a `xor a`
; before a run of `ld [hli], a`. This expansion is a per-event run of ResetEvent,
; each of which loads, masks and stores through AL on its own, so it never depends
; on A arriving zeroed. The argument is accepted and ignored.
%macro ResetEventRange 2-3
    %assign i %1
    %rep (%2) - (%1) + 1
        ResetEvent i
        %assign i i + 1
    %endrep
%endmacro

%macro CheckBothEventsSet 2
    ; Emulates pret's CheckBothEventsSet.
    ; "returns whether both events are set in Z flag.
    ; This sets the Z flag when the event IS set."
    CheckEvent %1
    jz %%not_set
    CheckEvent %2
    jz %%not_set
    ; both are set -> ZF=1
    cmp al, al
    jmp %%done
%%not_set:
    ; not both set -> ZF=0. `test al,0` always yields ZF=1 (AND with 0 is
    ; always 0) regardless of AL's value, so it can't be used here; force a
    ; known-nonzero value into AL first instead.
    mov al, 1
    test al, al
%%done:
%endmacro

%macro CheckEitherEventSet 2
    ; "returns the complement of whether either event is set in Z flag"
    ; "Z flag=0 if either is set."
    CheckEvent %1
    jnz %%set
    CheckEvent %2
    jnz %%set
    ; neither is set -> ZF=1
    cmp al, al
    jmp %%done
%%set:
    ; either is set -> ZF=0. See CheckBothEventsSet: `test al,0` always
    ; yields ZF=1, so force a known-nonzero value into AL first instead.
    mov al, 1
    test al, al
%%done:
%endmacro

; Register-reuse variants as no-op `%define` aliases.
;
; The *ReuseHL family USED TO BE ALIASED HERE TOO, and is not any more: it has
; real macros above that mirror pret's `event_byte` elision. The aliases had two
; defects that never surfaced only because nothing in the port called them yet:
;   * the AfterBranch forms take TWO event indices and were aliased onto 1-arg
;     macros, so `SetEventAfterBranchReuseHL A, B` could not assemble at all;
;   * every alias routes through AL, while pret's `bit`/`set`/`res` on [hl] do
;     not touch A — so the alias silently clobbered a register pret preserves.
; A `%define` also SHADOWS a `%macro` of the same name, so leaving these in place
; would quietly disable the mirrors above.
%define CheckEventReuseA CheckEvent
%define CheckEventAfterBranchReuseA CheckEvent
%define CheckEventHL CheckEvent
%define CheckAndSetEventA CheckAndSetEvent
%define CheckAndResetEventA CheckAndResetEvent
%define CheckEitherEventSetReuseA CheckEitherEventSet

%endif ; EVENTS_INC
