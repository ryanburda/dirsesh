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
        'config-match:Configurations claiming a path, best first'
        'init:Install the tmux hooks dirsesh works through'
        'ls:Open a session at a directory under $HOME'
        'git:Open a session at a git repository under $HOME'
        'git-wt:Open a session at a worktree of the current repository'
        'z:Open a session at a directory zoxide knows, named by keywords'
        'zi:Choose a directory zoxide knows with fzf, and open a session there'
        'bm:Open a session at a bookmark (-p to print them all)'
        'bm-set:Bookmark a directory at a character'
        'bm-rm:Remove a bookmark'
        'bm-status:Bookmarks with a tmux session open at them, for a status line'
        'bm-status-init:Install the tmux hooks `bm-status` needs'
        'switch:Switch to another running session'
        'last:Switch back to the session you came from'
        'kill:Kill a running session'
        'logs:Browse the logs a dirsesh configuration wrote'
        'help:Show help message'
    )

    _describe 'command' commands
}

_dirsesh_sessions() {
    local -a sessions
    sessions=(${(f)"$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"})
    _describe 'session' sessions
}

_dirsesh_log_sessions() {
    # The sessions dirsesh has written logs for, which are not always sessions
    # that are still running.
    local -a log_sessions
    local dir="${XDG_STATE_HOME:-$HOME/.local/state}/dirsesh/logs"
    log_sessions=(${(f)"$(find $dir -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)"})
    _describe 'session' log_sessions
}

_dirsesh_bookmark_chars() {
    # The `bm` list's rows: character, directory, then the column it displays
    # -- which makes a fine completion description.
    local -a bookmarks
    bookmarks=(${(f)"$(dirsesh _bookmark-entries 2>/dev/null | awk -F'\t' '{ d = $3; sub(/^[^ ]+ +/, "", d); print $1 ":" d }')"})
    _describe 'bookmark' bookmarks
}

_dirsesh() {
    local context state state_descr line
    typeset -A opt_args

    _arguments -C \
        '1:command:_dirsesh_commands' \
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
        at)
            _alternative \
                'directories:directory:_files -/' \
                'options:option:(-noconfig -name)'
            (( CURRENT == 2 )) && compadd -- -help
            ;;
        config-match)
            _files -/
            (( CURRENT == 2 )) && compadd -- -help
            ;;
        switch | kill)
            if (( CURRENT == 2 )); then
                _dirsesh_sessions
                compadd -- -help
            fi
            ;;
        logs)
            if (( CURRENT == 2 )); then
                _dirsesh_log_sessions
                compadd -- -help
            fi
            ;;
        bm)
            if (( CURRENT == 2 )); then
                _dirsesh_bookmark_chars
                compadd -- -help -p
            fi
            ;;
        bm-rm)
            if (( CURRENT == 2 )); then
                _dirsesh_bookmark_chars
                compadd -- -help
            fi
            ;;
        bm-set)
            # The character comes first and is the user's to pick; the
            # directory after it is the one being bookmarked.
            if (( CURRENT == 2 )); then
                compadd -- -help
            else
                _files -/
            fi
            ;;
        bm-status)
            _values -s ' ' 'bm-status options' '-s' '--style' '-c' '--current-style'
            (( CURRENT == 2 )) && compadd -- -help
            ;;
        z)
            # Keywords are the usual argument and cannot be completed; a
            # directory is the other thing it takes, and can be.
            _files -/
            (( CURRENT == 2 )) && compadd -- -help
            ;;
        git)
            _values -s ' ' 'git options' \
                '-brief[show what each repository has waiting]' \
                '-filter[list only repositories that have something waiting]' \
                '-fetch[fetch first, so the ahead/behind counts are current]'
            (( CURRENT == 2 )) && compadd -- -help
            ;;
        init | ls | git-wt | zi | last | bm-status-init)
            (( CURRENT == 2 )) && compadd -- -help
            ;;
    esac
}

_dirsesh "$@"
