#compdef dirsesh-extras
# Zsh completion for dirsesh-extras (pickers and session management for dirsesh)
#
# compinit finds a completion by file name, so link this into a directory on
# your fpath as `_dirsesh-extras`:
#
#     mkdir -p ~/.zsh/completions
#     ln -s /path/to/dirsesh-extras.zsh ~/.zsh/completions/_dirsesh-extras
#
# and, in .zshrc before compinit runs:
#
#     fpath=(~/.zsh/completions $fpath)
#     autoload -Uz compinit && compinit
#
# Sourcing this file instead defines the function but registers nothing, and
# needs a compdef of its own: `compdef _dirsesh_extras dirsesh-extras`.

_dirsesh_extras_commands() {
    local commands=(
        'pick-dir:Print a directory under $HOME'
        'pick-repo:Print a git repository under $HOME'
        'pick-repo-brief:Print a git repository under $HOME that has changes'
        'pick-worktree:Print a worktree of the current repository'
        'session-switcher:Switch to another running session'
        'last-session:Switch back to the session you came from'
        'kill-session:Kill a running session'
        'logs:Browse the logs a dirsesh configuration wrote'
        'toggle-window:Switch to a window, creating it if it is not there'
        'smart-split:Split the current pane, evenly or small'
        'help:Show help message'
    )

    _describe 'command' commands
}

_dirsesh_extras_sessions() {
    local -a sessions
    sessions=(${(f)"$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"})
    _describe 'session' sessions
}

_dirsesh_extras_log_sessions() {
    # The sessions dirsesh has written logs for, which are not always sessions
    # that are still running.
    local -a log_sessions
    local dir="${XDG_STATE_HOME:-$HOME/.local/state}/dirsesh/logs"
    log_sessions=(${(f)"$(find $dir -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)"})
    _describe 'session' log_sessions
}

_dirsesh_extras_windows() {
    # -a: every window on the server, not just the current session's. The
    # window a toggle is looking for is often in the session you are not in.
    local -a windows
    windows=(${(f)"$(tmux list-windows -a -F '#{window_name}' 2>/dev/null | sort -u)"})
    _describe 'window' windows
}

_dirsesh_extras() {
    local context state state_descr line
    typeset -A opt_args

    _arguments -C \
        '1:command:_dirsesh_extras_commands' \
        '*::arg:->args' \
        && return 0

    # In this state CURRENT counts from the subcommand, so its first argument
    # is 2. Every subcommand takes -help there; zsh holds option-like matches
    # back until a `-` is typed, so it appears on `<command> -<TAB>`.
    #
    # The flags go on with compadd rather than through _alternative, so they
    # add to whatever the helper above them offered instead of replacing it.
    # `--` because compadd would read a leading `-` as an option of its own.
    case "$line[1]" in
        session-switcher | kill-session)
            if (( CURRENT == 2 )); then
                _dirsesh_extras_sessions
                compadd -- -help
            fi
            ;;
        logs)
            if (( CURRENT == 2 )); then
                _dirsesh_extras_log_sessions
                compadd -- -help
            fi
            ;;
        toggle-window)
            if (( CURRENT == 2 )); then
                _dirsesh_extras_windows
                compadd -- -help
            else
                _command_names -e
            fi
            ;;
        smart-split)
            (( CURRENT == 2 )) && compadd -- -h -v -help
            ;;
        pick-* | last-session)
            (( CURRENT == 2 )) && compadd -- -help
            ;;
    esac
}

_dirsesh_extras "$@"
