# Bash completion for dirsesh-extras (pickers and session management for dirsesh)
# Source this file in your .bashrc:
#   source /path/to/dirsesh-extras.bash
# Or copy to /etc/bash_completion.d/dirsesh-extras

_dirsesh_extras_sessions() {
    tmux list-sessions -F '#{session_name}' 2>/dev/null
}

_dirsesh_extras_windows() {
    # -a: every window on the server, not just the current session's. The
    # window a toggle is looking for is often in the session you are not in.
    tmux list-windows -a -F '#{window_name}' 2>/dev/null | sort -u
}

_dirsesh_extras_completions() {
    local cur cmd subcmds
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    cmd="${COMP_WORDS[1]}"

    subcmds="pick-dir pick-repo pick-repo-brief pick-worktree"
    subcmds="$subcmds session-switcher last-session kill-session"
    subcmds="$subcmds toggle-window smart-split help"

    # Completing the subcommand itself
    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "$subcmds" -- "$cur"))
        return 0
    fi

    # Completing an argument to a subcommand. The pickers and last-session
    # take none, so they are absent here and complete nothing.
    case "$cmd" in
        session-switcher | kill-session)
            # The one optional argument is a running session.
            [ "$COMP_CWORD" -eq 2 ] || return 0
            COMPREPLY=($(compgen -W "$(_dirsesh_extras_sessions)" -- "$cur"))
            return 0
            ;;
        toggle-window)
            # The window's name first, then the command that runs in it.
            if [ "$COMP_CWORD" -eq 2 ]; then
                COMPREPLY=($(compgen -W "$(_dirsesh_extras_windows)" -- "$cur"))
            else
                COMPREPLY=($(compgen -c -- "$cur"))
            fi
            return 0
            ;;
        smart-split)
            # The direction first; the two percentages after it are numbers,
            # and anything past those is forwarded to tmux split-window.
            [ "$COMP_CWORD" -eq 2 ] || return 0
            COMPREPLY=($(compgen -W "-h -v" -- "$cur"))
            return 0
            ;;
    esac
}

complete -F _dirsesh_extras_completions dirsesh-extras
