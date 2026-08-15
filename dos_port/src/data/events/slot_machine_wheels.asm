; slot_machine_wheels.asm — mirror of pret data/events/slot_machine_wheels.asm
;
; Defines the three slot machine wheel symbol tables (54 dw entries total).
; Symbols are defined in include/gb_constants.inc (constants/script_constants.asm).
; RGBDS dw and NASM dw are both little-endian, preserving pret byte order directly.

bits 32

%include "gb_constants.inc"

global SlotMachineWheel1
global SlotMachineWheel2
global SlotMachineWheel3

section .data

SlotMachineWheel1:
	dw SLOTS7
	dw SLOTSMOUSE
	dw SLOTSFISH
	dw SLOTSBAR
	dw SLOTSCHERRY
	dw SLOTS7
	dw SLOTSFISH
	dw SLOTSBIRD
	dw SLOTSBAR
	dw SLOTSCHERRY
	dw SLOTS7
	dw SLOTSMOUSE
	dw SLOTSBIRD
	dw SLOTSBAR
	dw SLOTSCHERRY
	dw SLOTS7
	dw SLOTSMOUSE
	dw SLOTSFISH

SlotMachineWheel2:
	dw SLOTS7
	dw SLOTSFISH
	dw SLOTSCHERRY
	dw SLOTSBIRD
	dw SLOTSMOUSE
	dw SLOTSBAR
	dw SLOTSCHERRY
	dw SLOTSFISH
	dw SLOTSBIRD
	dw SLOTSCHERRY
	dw SLOTSBAR
	dw SLOTSFISH
	dw SLOTSBIRD
	dw SLOTSCHERRY
	dw SLOTSMOUSE
	dw SLOTS7
	dw SLOTSFISH
	dw SLOTSCHERRY

SlotMachineWheel3:
	dw SLOTS7
	dw SLOTSBIRD
	dw SLOTSFISH
	dw SLOTSCHERRY
	dw SLOTSMOUSE
	dw SLOTSBIRD
	dw SLOTSFISH
	dw SLOTSCHERRY
	dw SLOTSMOUSE
	dw SLOTSBIRD
	dw SLOTSFISH
	dw SLOTSCHERRY
	dw SLOTSMOUSE
	dw SLOTSBIRD
	dw SLOTSBAR
	dw SLOTS7
	dw SLOTSBIRD
	dw SLOTSFISH
