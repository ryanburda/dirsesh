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
        'session-switch:Switch to another running session'
        'session-last:Switch back to the session you came from'
        'session-kill:Kill a running session'
        'session-logs:Browse the logs a dirsesh configuration wrote'
        'bookmark:Bookmark directories, one printable character each'
        'pick-dir:Print a directory under $HOME'
        'pick-repo:Print a git repository under $HOME'
        'pick-worktree:Print a worktree of the current repository'
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

_dirsesh_bookmark_commands() {
    local commands=(
        'set:Bookmark a directory at a character'
        'remove:Remove a bookmark'
        'get:Print the directory a bookmark points at'
        'pick:Choose a bookmark with fzf and print its directory'
        'list:Every bookmark as "char<TAB>directory"'
        'status:Bookmarks with a tmux session open at them, for a status line'
        'status-init:Install the tmux hooks `status` needs'
    )

    _describe 'command' commands
}

_dirsesh_bookmark_chars() {
    # The picker's own rows: character, directory, then the column it
    # displays -- which makes a fine completion description.
    local -a bookmarks
    bookmarks=(${(f)"$(dirsesh bookmark _entries 2>/dev/null | awk -F'\t' '{ d = $3; sub(/^[^ ]+ +/, "", d); print $1 ":" d }')"})
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
        match)
            _files -/
            (( CURRENT == 2 )) && compadd -- -help
            ;;
        session-switch | session-kill)
            if (( CURRENT == 2 )); then
                _dirsesh_sessions
                compadd -- -help
            fi
            ;;
        session-logs)
            if (( CURRENT == 2 )); then
                _dirsesh_log_sessions
                compadd -- -help
            fi
            ;;
        bookmark)
            # Its own subcommand sits where the other commands' first argument
            # does, so CURRENT is one further along for everything it takes.
            if (( CURRENT == 2 )); then
                _dirsesh_bookmark_commands
                compadd -- -help
            else
                case "$line[2]" in
                    remove | get)
                        (( CURRENT == 3 )) && _dirsesh_bookmark_chars
                        ;;
                    set)
                        # The character comes first and is the user's to pick;
                        # the directory after it is the one being bookmarked.
                        (( CURRENT > 3 )) && _files -/
                        ;;
                    status)
                        _values -s ' ' 'status options' '-s' '--style' '-c' '--current-style'
                        ;;
                esac
            fi
            ;;
        pick-repo)
            _values -s ' ' 'pick-repo options' \
                '-brief[show what each repository has waiting]' \
                '-filter[list only repositories that have something waiting]' \
                '-fetch[fetch first, so the ahead/behind counts are current]'
            (( CURRENT == 2 )) && compadd -- -help
            ;;
        init | pick-* | session-last)
            (( CURRENT == 2 )) && compadd -- -help
            ;;
    esac
}

_dirsesh "$@"
