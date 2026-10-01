# pkmn-run.ps1 — PowerShell completion for dos_port/run.ps1.
#
# Opt-in. Add ONE line to your $PROFILE (paths with spaces need the & operator):
#     . /path/to/dos_port/tools/completion/pkmn-run.ps1
#
# Binds by command name (`run.ps1`), mirroring the bash/zsh completers. Reflects
# run's three argument namespaces:
#   /FLAG -> PKMN.EXE flag inside DOS;  -FLAG -> DOSBox-X flag;  NAME= -> make.
# The DOS flag list is synced with boot/entry.asm's arg_* table.

$script:PkmnRunDosFlags = @(
    '/NOSOUND', '/NOENH', '/LOOP', '/NODMA',
    '/MT32', '/GM', '/TANDY', '/INNOVA', '/COVOX', '/GB', '/PAS', '/IMFC', '/SPK',
    '/LINKLOG', '/PARTYB', '/IPX', '/IPXSOCK=', '/PKTINT=',
    '/COM1', '/COM2', '/COM3', '/COM4', '/BAUD=',
    '/TCPWAIT', '/TCP=', '/IP=', '/MASK=', '/GW=',
    '/PRINT9', '/PRNCOLOR', '/PRNFILE'
)
$script:PkmnRunHostFlags = @(
    '--help', '--dry-run', '--',
    '-fullscreen', '-window', '-conf', '-defaultdir', '-c', '-set',
    '-userconf', '-nolgc', '-exit'
)
$script:PkmnRunMakeVars = @(
    'SKIP_TITLE=1', 'BUG_FIX_LEVEL=1', 'BUG_FIX_LEVEL=2',
    'DEBUG_DUMP=1', 'DEBUG_AUDIO=1', 'DEBUG_PERF=1', 'DEBUG_TRANSITION=1',
    'DEBUG_WALK_NORTH=1', 'DEBUG_STATUS=1', 'DEBUG_STARTMENU=1',
    'TRACK='
)

$script:PkmnRunCompleter = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $cands =
        if ($wordToComplete -like '/*')      { $script:PkmnRunDosFlags }
        elseif ($wordToComplete -like '-*')  { $script:PkmnRunHostFlags }
        else                                 { $script:PkmnRunMakeVars }
    $cands |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

Register-ArgumentCompleter -CommandName 'run.ps1', 'run' -ScriptBlock $script:PkmnRunCompleter
