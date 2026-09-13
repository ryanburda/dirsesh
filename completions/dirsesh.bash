# Bash completion for dirsesh (one tmux session per directory)
# Source this file in your .bashrc:
#   source /path/to/dirsesh.bash
# Or copy to /etc/bash_completion.d/dirsesh

_dirsesh_sessions() {
    tmux list-sessions -F '#{session_name}' 2>/dev/null
}

_dirsesh_log_sessions() {
    # The sessions dirsesh has written logs for, which are not always sessions
    # that are still running.
    local dir="${XDG_STATE_HOME:-$HOME/.local/state}/dirsesh/logs"
    [ -d "$dir" ] || return 0
    find "$dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort
}

_dirsesh_bookmark_chars() {
    # Every bookmark as "char<TAB>directory"; the character is the first field.
    dirsesh bookmark-list 2>/dev/null | cut -f1
}

_dirsesh_completions() {
    local cur cmd subcmds
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    cmd="${COMP_WORDS[1]}"

    subcmds="at match init"
    subcmds="$subcmds session-switch session-last session-kill session-logs"
    subcmds="$subcmds bookmark-set bookmark-remove bookmark-get bookmark-pick"
    subcmds="$subcmds bookmark-list bookmark-status bookmark-status-init"
    subcmds="$subcmds pick-dir pick-repo pick-worktree help"

    # Completing the subcommand itself
    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "$subcmds" -- "$cur"))
        return 0
    fi

    # Completing an argument to a subcommand. Every subcommand takes -help in
    # first position, so it is offered alongside whatever else fits there.
    case "$cmd" in
        at)
            # A directory and the session flags, in either order.
            COMPREPLY=($(compgen -d -W "-noconfig -name -help" -- "$cur"))
            return 0
            ;;
        match)
            COMPREPLY=($(compgen -d -W "-help" -- "$cur"))
            return 0
            ;;
        session-switch | session-kill)
            # The one optional argument is a running session.
            [ "$COMP_CWORD" -eq 2 ] || return 0
            COMPREPLY=($(compgen -W "-help $(_dirsesh_sessions)" -- "$cur"))
            return 0
            ;;
        session-logs)
            # The one optional argument is a session dirsesh has logged.
            [ "$COMP_CWORD" -eq 2 ] || return 0
            COMPREPLY=($(compgen -W "-help $(_dirsesh_log_sessions)" -- "$cur"))
            return 0
            ;;
        bookmark-remove | bookmark-get)
            # The one argument is a character something is bookmarked at.
            [ "$COMP_CWORD" -eq 2 ] || return 0
            COMPREPLY=($(compgen -W "-help $(_dirsesh_bookmark_chars)" -- "$cur"))
            return 0
            ;;
        bookmark-set)
            # The character comes first and is the user's to pick, so only
            # -help is offered there; the directory after it is the one being
            # bookmarked.
            if [ "$COMP_CWORD" -eq 2 ]; then
                COMPREPLY=($(compgen -W "-help" -- "$cur"))
            else
                COMPREPLY=($(compgen -d -- "$cur"))
            fi
            return 0
            ;;
        bookmark-status)
            COMPREPLY=($(compgen -W "-help -s --style -c --current-style" -- "$cur"))
            return 0
            ;;
        pick-repo)
            COMPREPLY=($(compgen -W "-help -brief -filter -fetch" -- "$cur"))
            return 0
            ;;
        init | pick-* | session-last | bookmark-pick | bookmark-list | bookmark-status-init)
            # No arguments of their own; -help is all there is to offer.
            [ "$COMP_CWORD" -eq 2 ] || return 0
            COMPREPLY=($(compgen -W "-help" -- "$cur"))
            return 0
            ;;
    esac
}

complete -F _dirsesh_completions dirsesh
