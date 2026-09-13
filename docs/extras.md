# Extras

`dirsesh` creates tmux sessions. That's its whole job.

Switching between sessions and killing them are different jobs, and they have been solved a
thousand times over — by tmux's own `choose-tree`, by sessionx, by fzf one-liners people have
carried in their `tmux.conf` for years. If you already have something you like for that, keep
using it. `dirsesh at` is happy to sit next to it; nothing in it assumes it is the only thing
touching your sessions.

`dirsesh-extras` is for the other case. If you would rather `dirsesh` be your session manager
and not just the half that creates them, it ships the other half as a separate command — the
pickers here, the [bookmarks](bookmark.md) that pin the directories you keep coming back to,
and the session switching and killing commands that pair with them.

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

  dirsesh-extras switch-session [session]                                # Switch to another running session
    session                                                              # Switch straight to this one instead of picking
  dirsesh-extras last-session                                            # Switch back to the session you came from
  dirsesh-extras kill-session [session]                                  # Kill a running session
    session                                                              # Kill this one instead of picking
  dirsesh-extras logs [session]                                          # Browse the logs a dirsesh configuration wrote
    session                                                              # Browse only this session's logs

  dirsesh-extras bookmark <command> [args...]                            # Bookmark directories, one printable character each
    set <char> [path]                                                    # Bookmark a directory (path defaults to the current directory)
    remove <char>                                                        # Remove a bookmark
    get <char>                                                           # Print the directory a bookmark points at
    pick                                                                 # Choose a bookmark with fzf and print its directory
    list                                                                 # Every bookmark as "char<TAB>directory"
    status [path]                                                        # Bookmarks with a tmux session open at them, for a status line
    status-init                                                          # Install the tmux hooks `status` needs (put this in tmux.conf)

  dirsesh-extras pick-dir                                                # Print a directory under $HOME
  dirsesh-extras pick-repo                                               # Print a git repository under $HOME
  dirsesh-extras pick-repo-brief                                         # Print a git repository under $HOME that has changes
  dirsesh-extras pick-worktree                                           # Print a worktree of the current repository

The pickers print a path on stdout, so they compose with dirsesh:

  dirsesh at "$(dirsesh-extras pick-repo)"
  dirsesh at "$(dirsesh-extras bookmark get m)"
```

Each subcommand documents itself. `-help` prints what it lists, how it behaves at the edges,
and anything worth knowing before you bind it to a key:

```bash
dirsesh-extras pick-repo-brief -help
dirsesh-extras logs -help
```

That is where the per-command detail lives, so it cannot drift from the scripts the way a second
copy in this file would.

`bookmark` is the exception: it has subcommands of its own, a tmux status line and the
keybindings that go with them, which is more than a header comment holds. See
[Bookmarks](bookmark.md).

## Binding them

```tmux
# ~/.config/tmux/tmux.conf

bind-key d popup -E 'dirsesh at "$(dirsesh-extras pick-dir)"'
bind-key r popup -E 'dirsesh at "$(dirsesh-extras pick-repo)"'
bind-key R popup -E 'dirsesh at "$(dirsesh-extras pick-repo-brief)"'
bind-key w popup -E 'dirsesh at "$(dirsesh-extras pick-worktree)"'

bind-key b popup -E 'dirsesh at "$(dirsesh-extras bookmark pick)"'
bind-key m command-prompt -1 -p "Set bookmark:"    "run-shell -b \"dirsesh-extras bookmark set '%%%'\""
bind-key M command-prompt -1 -p "Remove bookmark:" "run-shell -b \"dirsesh-extras bookmark remove '%%%'\""

bind-key \; run-shell -b "dirsesh-extras last-session"
bind-key s popup -h 35% -w 40% -E "dirsesh-extras switch-session"
bind-key T popup -h 35% -w 40% -E "dirsesh at $(mktemp -d)"
```

A picker is worth binding twice — once in `tmux.conf` like the above for when tmux is running,
and once in your shell for when no tmux server is running:

```zsh
# ~/.zshrc

alias d='dirsesh at "$(dirsesh-extras pick-dir)"'
alias r='dirsesh at "$(dirsesh-extras pick-repo)"'
alias R='dirsesh at "$(dirsesh-extras pick-repo-brief)"'
alias w='dirsesh at "$(dirsesh-extras pick-worktree)"'
alias b='dirsesh at "$(dirsesh-extras bookmark pick)"'
```

This ensures your muscle memory is similar no matter if you are in or out of tmux.
