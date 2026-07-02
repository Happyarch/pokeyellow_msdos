"""ui_layout — subsystem-generic UI layout editing pipeline for the DOS port.

Pipeline:  editor.py (pygame) <-> assets/ui_layout_<subsystem>_sidecar.json
           -> tools/gen_ui_layout.py -> assets/ui_layout_<subsystem>.inc

The sidecar JSON is the hand-positioned source of truth (edited ONLY via the
editor); the .inc is machine-owned Tier-1 output. Projection math lives in
canvas.py and is imported by both the editor and the generator so the preview
can never drift from the emitted coordinates. Nothing in this package is
specific to the menus subsystem — battle later loads its own sidecar unchanged.
"""
