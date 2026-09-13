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
complete -c dirsesh-extras -n '__fish_use_subcommand' -a session-switcher -d 'Switch to another running session'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a last-session -d 'Switch back to the session you came from'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a kill-session -d 'Kill a running session'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a toggle-window -d 'Switch to a window, creating it if it is not there'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a smart-split -d 'Split the current pane, evenly or small'
complete -c dirsesh-extras -n '__fish_use_subcommand' -a help -d 'Show help message'

# Subcommand arguments. The pickers and last-session take none, so they are
# absent here and keep the disabled file completion above.
complete -c dirsesh-extras -n '__fish_seen_subcommand_from session-switcher kill-session' \
    -xa '(tmux list-sessions -F "#{session_name}" 2>/dev/null)' -d 'Session'
# -a: every window on the server, not just the current session's. The window a
# toggle is looking for is often in the session you are not in.
complete -c dirsesh-extras -n '__fish_seen_subcommand_from toggle-window' \
    -xa '(tmux list-windows -a -F "#{window_name}" 2>/dev/null | sort -u)' -d 'Window'
complete -c dirsesh-extras -n '__fish_seen_subcommand_from smart-split' -xa '-h -v'
# Every subcommand documents itself with -help in first position.
complete -c dirsesh-extras -n '__fish_seen_subcommand_from pick-dir pick-repo pick-repo-brief pick-worktree session-switcher last-session kill-session toggle-window smart-split' \
    -xa '-help' -d 'Show what this command does, in detail'
