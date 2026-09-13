# Fish completion for dirsesh-extras (pickers and session management for dirsesh)
# Copy to ~/.config/fish/completions/dirsesh-extras.fish
# Or symlink: ln -s /path/to/dirsesh-extras.fish ~/.config/fish/completions/

# Disable file completion by default
complete -c dirsesh-extras -f

# Subcommands
complete -c dirsesh-extras -n '__fish_use_subcommand' -a pick-dir -d 'Print a directory under $HOME'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a pick-repo -d 'Print a git repository under $HOME'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a pick-repo-brief -d 'Print a git repository under $HOME that has changes'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a pick-worktree -d 'Print a worktree of the current repository'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a switch-session -d 'Switch to another running session'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a last-session -d 'Switch back to the session you came from'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a kill-session -d 'Kill a running session'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a logs -d 'Browse the logs a dirsesh configuration wrote'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a bookmark -d 'Bookmark directories, one printable character each'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a help -d 'Show help message'

# Subcommand arguments. The pickers and last-session take none, so they are
# absent here and keep the disabled file completion above.
complete -c dirsesh-extras -n '__fish_seen_subcommand_from switch-session kill-session' \
    -xa '(tmux list-sessions -F "#{session_name}" 2>/dev/null)' -d 'Session'
# The sessions dirsesh has written logs for, which are not always sessions that
# are still running.
complete -c dirsesh-extras -n '__fish_seen_subcommand_from logs' \
    -xa '(find (set -q XDG_STATE_HOME; and echo $XDG_STATE_HOME; or echo $HOME/.local/state)/dirsesh/logs -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)' -d 'Session'

# bookmark is the one subcommand with subcommands of its own: offer them while
# none has been named, then whatever the named one takes.
function __dirsesh_extras_bookmark_chars
    # The picker's own rows: character, directory, then the column it
    # displays -- which makes a fine completion description.
    dirsesh-extras bookmark _entries 2>/dev/null \
        | awk -F'\t' '{ d = $3; sub(/^[^ ]+ +/, "", d); print $1 "\t" d }'
end
complete -c dirsesh-extras -n '__fish_seen_subcommand_from bookmark; and not __fish_seen_subcommand_from set remove get pick list status status-init' \
    -xa 'set remove get pick list status status-init'
complete -c dirsesh-extras -n '__fish_seen_subcommand_from bookmark; and __fish_seen_subcommand_from remove get' \
    -xa '(__dirsesh_extras_bookmark_chars)'
# The character comes first and is the user's to pick; the directory after it
# is the one being bookmarked.
complete -c dirsesh-extras -n '__fish_seen_subcommand_from bookmark; and __fish_seen_subcommand_from set' \
    -ra '(__fish_complete_directories)'
complete -c dirsesh-extras -n '__fish_seen_subcommand_from bookmark; and __fish_seen_subcommand_from status' \
    -xa '-s --style -c --current-style'
# Every subcommand documents itself with -help in first position.
complete -c dirsesh-extras -n '__fish_seen_subcommand_from pick-dir pick-repo pick-repo-brief pick-worktree switch-session last-session kill-session logs bookmark' \
    -xa '-help' -d 'Show what this command does, in detail'
