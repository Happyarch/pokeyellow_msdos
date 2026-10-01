# pkmn-run.bash — bash completion for dos_port/run and dos_port/run-mcp.
#
# Opt-in. Add ONE line to ~/.bashrc:
#     source /path/to/dos_port/tools/completion/pkmn-run.bash
#
# Binds by command name (`run` / `run-mcp`) — see the note in pkmn-run.zsh.
# Reflects run's three argument namespaces:
#   /FLAG -> PKMN.EXE flag inside DOS;  -FLAG -> DOSBox-X flag;  NAME= -> make.
# DOS flag list synced with boot/entry.asm's arg_* table.

_pkmn_run_complete() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"

    local dos_flags=(
        '/NOSOUND' '/NOENH' '/LOOP' '/NODMA'
        '/MT32' '/GM' '/TANDY' '/INNOVA' '/COVOX' '/GB' '/PAS' '/IMFC' '/SPK'
        '/LINKLOG' '/PARTYB' '/IPX' '/IPXSOCK=' '/PKTINT='
        '/COM1' '/COM2' '/COM3' '/COM4' '/BAUD='
        '/TCPWAIT' '/TCP=' '/IP=' '/MASK=' '/GW='
        '/PRINT9' '/PRNCOLOR' '/PRNFILE'
    )
    local host_flags=(
        '--help' '--dry-run' '--'
        '-fullscreen' '-window' '-conf' '-defaultdir' '-c' '-set'
        '-userconf' '-nolgc' '-exit'
    )
    local make_vars=(
        'SKIP_TITLE=1' 'BUG_FIX_LEVEL=1' 'BUG_FIX_LEVEL=2'
        'DEBUG_DUMP=1' 'DEBUG_AUDIO=1' 'DEBUG_PERF=1' 'DEBUG_TRANSITION=1'
        'DEBUG_WALK_NORTH=1' 'DEBUG_STATUS=1' 'DEBUG_STARTMENU=1'
        'TRACK='
    )

    case "$cur" in
        /*) COMPREPLY=( $(compgen -W "${dos_flags[*]}" -- "$cur") ) ;;
        -*) COMPREPLY=( $(compgen -W "${host_flags[*]}" -- "$cur") ) ;;
        *)  COMPREPLY=( $(compgen -W "${make_vars[*]}" -- "$cur") \
                        $(compgen -f -- "$cur") ) ;;
    esac
    return 0
}

complete -F _pkmn_run_complete run run-mcp
