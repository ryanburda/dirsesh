#compdef dirsesh
# Zsh completion for dirsesh (one tmux session per directory)
#
# compinit finds a completion by file name, so link this into a directory on
# your fpath as `_dirsesh`:
#
#     mkdir -p ~/.zsh/completions
#     ln -s /path/to/dirsesh.zsh ~/.zsh/completions/_dirsesh
#
# and, in .zshrc before compinit runs:
#
#     fpath=(~/.zsh/completions $fpath)
#     autoload -Uz compinit && compinit
#
# Sourcing this file instead defines the function but registers nothing, and
# needs a compdef of its own: `compdef _dirsesh dirsesh`.

_dirsesh_commands() {
    local commands=(
        'at:Start a session at a directory'
        'match:Configurations claiming a path, best first'
        'init:Install the tmux session-closed hook'
        'help:Show help message'
    )

    _describe 'command' commands
}

_dirsesh() {
    local context state state_descr line
    typeset -A opt_args

    _arguments -C \
        '1:command:_dirsesh_commands' \
        '*::arg:->args' \
        && return 0

    case "$line[1]" in
        at)
            _alternative \
                'directories:directory:_files -/' \
                'options:option:(-noconfig -name)'
            ;;
        match)
            _files -/
            ;;
    esac
}

_dirsesh "$@"
