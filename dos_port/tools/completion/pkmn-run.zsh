# pkmn-run.zsh — zsh completion for dos_port/run and dos_port/run-mcp.
#
# Opt-in. Add ONE line to ~/.zshrc:
#     source /path/to/dos_port/tools/completion/pkmn-run.zsh
#
# It binds by COMMAND NAME (`run` / `run-mcp`), so any other command called
# `run` in a shell that sourced this also gets the completion. That is the
# tradeoff of not requiring fpath setup; the words offered are dos_port/run's,
# so the worst case is a stale list on an unrelated `run`.
#
# Completion reflects run's three argument namespaces (see dos_port/run):
#   /FLAG   -> a PKMN.EXE flag inside DOS
#   -FLAG   -> a DOSBox-X flag
#   NAME=   -> a make variable
# The DOS flag list is kept in sync with boot/entry.asm's arg_* table.

_pkmn_run() {
    local cur=${words[CURRENT]}
    local -a dos_flags host_flags make_vars

    dos_flags=(
        '/NOSOUND' '/NOENH' '/LOOP' '/NODMA'
        '/MT32' '/GM' '/TANDY' '/INNOVA' '/COVOX' '/GB' '/PAS' '/IMFC' '/SPK'
        '/LINKLOG' '/PARTYB' '/IPX' '/IPXSOCK=' '/PKTINT='
        '/COM1' '/COM2' '/COM3' '/COM4' '/BAUD='
        '/TCPWAIT' '/TCP=' '/IP=' '/MASK=' '/GW='
        '/PRINT9' '/PRNCOLOR' '/PRNFILE'
    )
    host_flags=(
        '--help' '--dry-run' '--'
        '-fullscreen' '-window' '-conf' '-defaultdir' '-c' '-set'
        '-userconf' '-nolgc' '-exit'
    )
    make_vars=(
        'SKIP_TITLE=1' 'BUG_FIX_LEVEL=1' 'BUG_FIX_LEVEL=2'
        'DEBUG_DUMP=1' 'DEBUG_AUDIO=1' 'DEBUG_PERF=1' 'DEBUG_TRANSITION=1'
        'DEBUG_WALK_NORTH=1' 'DEBUG_STATUS=1' 'DEBUG_STARTMENU=1'
        'TRACK='
    )

    case "$cur" in
        /*) compadd -- "${dos_flags[@]}" ;;
        -*) compadd -- "${host_flags[@]}" ;;
        *)  compadd -- "${make_vars[@]}"
            _files 2>/dev/null ;;
    esac
}

compdef _pkmn_run run run-mcp
