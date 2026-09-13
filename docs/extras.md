# Extras

`dirsesh` creates tmux sessions. That's its whole job.

Switching between sessions and killing them are different jobs, and they have been solved a
thousand times over — by tmux's own `choose-tree`, by sessionx, by fzf one-liners people have
carried in their `tmux.conf` for years. If you already have something you like for that, keep
using it. `dirsesh at` is happy to sit next to it; nothing in it assumes it is the only thing
touching your sessions.

`dirsesh-extras` is for the other case. If you would rather `dirsesh` be your session manager
and not just the half that creates them, it ships the other half as a separate command — the
pickers here, and the session switching and killing commands that pair with them.

It is a separate command on purpose. Everything in `dirsesh-extras` is opinionated in a way
`dirsesh` deliberately is not. Keeping it out of `dirsesh` means those opinions are something
you opt into rather than something you have to work around.

## Dependencies
- [`fzf`](https://github.com/junegunn/fzf)

## Usage

```bash
dirsesh-extras - Pickers and session management to pair with dirsesh

Usage:
  dirsesh-extras                                                         # Show help message
  dirsesh-extras <command> -help                                         # Show what one command does, in detail

  dirsesh-extras session-switcher [session]                              # Switch to another running session
    session                                                              # Switch straight to this one instead of picking
  dirsesh-extras last-session                                            # Switch back to the session you came from
  dirsesh-extras kill-session [session]                                  # Kill a running session
    session                                                              # Kill this one instead of picking
  dirsesh-extras logs [session]                                          # Browse the logs a dirsesh configuration wrote
    session                                                              # Browse only this session's logs

  dirsesh-extras toggle-window <name> <command...>                       # Switch to a window, creating it if it is not there
    name                                                                 # The window's name, and what it is found by
    command...                                                           # Run in the window when it is created
  dirsesh-extras smart-split <-h|-v> <threshold> <small-pct> [args...]   # Split the current pane, evenly or small
    -h|-v                                                                # Split left/right (-h) or top/bottom (-v)
    threshold                                                            # Percent of the window past which small-pct is used
    small-pct                                                            # Size of the new pane past the threshold
    args...                                                              # Forwarded to tmux split-window

  dirsesh-extras pick-dir                                                # Print a directory under $HOME
  dirsesh-extras pick-repo                                               # Print a git repository under $HOME
  dirsesh-extras pick-repo-brief                                         # Print a git repository under $HOME that has changes
  dirsesh-extras pick-worktree                                           # Print a worktree of the current repository

The pickers print a path on stdout, so they compose with dirsesh:

  dirsesh at "$(dirsesh-extras pick-repo)"
```

Each subcommand documents itself. `-help` prints what it lists, how it behaves at the edges,
and anything worth knowing before you bind it to a key:

```bash
dirsesh-extras pick-repo-brief -help
dirsesh-extras smart-split -help
```

That is where the per-command detail lives, so it cannot drift from the scripts the way a second
copy in this file would.

## Binding them

```tmux
# ~/.config/tmux/tmux.conf

bind-key d popup -E 'dirsesh at "$(dirsesh-extras pick-dir)"'
bind-key r popup -E 'dirsesh at "$(dirsesh-extras pick-repo)"'
bind-key R popup -E 'dirsesh at "$(dirsesh-extras pick-repo-brief)"'
bind-key w popup -E 'dirsesh at "$(dirsesh-extras pick-worktree)"'

bind-key \; run-shell -b "dirsesh-extras last-session"
bind-key s popup -h 35% -w 40% -E "dirsesh-extras session-switcher"
bind-key T popup -h 35% -w 40% -E "dirsesh at $(mktemp -d)"
bind-key j run-shell 'dirsesh-extras smart-split -v 78 22 -c "#{pane_current_path}"'
bind-key l run-shell 'dirsesh-extras smart-split -h 65 35 -c "#{pane_current_path}"'
```

A picker is worth binding twice — once in `tmux.conf` like the above for when tmux is running,
and once in your shell for when no tmux server is running:

```zsh
# ~/.zshrc

alias d='dirsesh at "$(dirsesh-extras pick-dir)"'
alias r='dirsesh at "$(dirsesh-extras pick-repo)"'
alias R='dirsesh at "$(dirsesh-extras pick-repo-brief)"'
alias w='dirsesh at "$(dirsesh-extras pick-worktree)"'
```

This ensures your muscle memory is similar no matter if you are in or out of tmux.
