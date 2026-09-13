# Extras

`dirsesh at` creates tmux sessions. That's its whole job.

Switching between sessions and killing them are different jobs, and they have been solved a
thousand times over — by tmux's own `choose-tree`, by sessionx, by fzf one-liners people have
carried in their `tmux.conf` for years. If you already have something you like for that, keep
using it. `dirsesh at` is happy to sit next to it; nothing in it assumes it is the only thing
touching your sessions.

The rest of the subcommands are for the other case. If you would rather `dirsesh` be your
session manager and not just the half that creates them, it ships the other half too — the
pickers here, the [bookmarks](bookmark.md) that pin the directories you keep coming back to,
and the session switching and killing commands that pair with them.

They are opinionated in a way `dirsesh at` deliberately is not, which is why none of them is
wired into it: a picker prints a path and stops, and it is you who substitutes that path into
`dirsesh at`. The opinions stay something you opt into, one binding at a time, rather than
something you have to work around.

## Dependencies
- [`fzf`](https://github.com/junegunn/fzf)

## Usage

```bash
dirsesh session-switch [session]        # Switch to another running session
  session                               # Switch straight to this one instead of picking
dirsesh session-last                    # Switch back to the session you came from
dirsesh session-kill [session]          # Kill a running session
  session                               # Kill this one instead of picking
dirsesh session-logs [session]          # Browse the logs a dirsesh configuration wrote
  session                               # Browse only this session's logs

dirsesh bookmark <command> [args...]    # Bookmark directories, one printable character each
  set <char> [path]                     # Bookmark a directory (path defaults to the current directory)
  remove <char>                         # Remove a bookmark
  get <char>                            # Print the directory a bookmark points at
  pick                                  # Choose a bookmark with fzf and print its directory
  list                                  # Every bookmark as "char<TAB>directory"
  status [path]                         # Bookmarks with a tmux session open at them, for a status line
  status-init                           # Install the tmux hooks `status` needs (put this in tmux.conf)

dirsesh pick-dir                        # Print a directory under $HOME
dirsesh pick-repo                       # Print a git repository under $HOME
dirsesh pick-repo-brief                 # Print a git repository under $HOME that has changes
dirsesh pick-worktree                   # Print a worktree of the current repository
```

The pickers print a path on stdout, so they compose with `dirsesh at`:

```bash
dirsesh at "$(dirsesh pick-repo)"
dirsesh at "$(dirsesh bookmark get m)"
```

Each subcommand documents itself. `-help` prints what it lists, how it behaves at the edges,
and anything worth knowing before you bind it to a key:

```bash
dirsesh pick-repo-brief -help
dirsesh session-logs -help
```

That is where the per-command detail lives, so it cannot drift from the scripts the way a second
copy in this file would.

`bookmark` is the exception: it has subcommands of its own, a tmux status line and the
keybindings that go with them, which is more than a header comment holds. See
[Bookmarks](bookmark.md).

## Binding them

```tmux
# ~/.config/tmux/tmux.conf

bind-key d popup -E 'dirsesh at "$(dirsesh pick-dir)"'
bind-key r popup -E 'dirsesh at "$(dirsesh pick-repo)"'
bind-key R popup -E 'dirsesh at "$(dirsesh pick-repo-brief)"'
bind-key w popup -E 'dirsesh at "$(dirsesh pick-worktree)"'

bind-key b popup -E 'dirsesh at "$(dirsesh bookmark pick)"'
bind-key m command-prompt -1 -p "Set bookmark:"    "run-shell -b \"dirsesh bookmark set '%%%'\""
bind-key M command-prompt -1 -p "Remove bookmark:" "run-shell -b \"dirsesh bookmark remove '%%%'\""

bind-key \; run-shell -b "dirsesh session-last"
bind-key s popup -h 35% -w 40% -E "dirsesh session-switch"
bind-key T popup -h 35% -w 40% -E "dirsesh at $(mktemp -d)"
```

A picker is worth binding twice — once in `tmux.conf` like the above for when tmux is running,
and once in your shell for when no tmux server is running:

```zsh
# ~/.zshrc

alias d='dirsesh at "$(dirsesh pick-dir)"'
alias r='dirsesh at "$(dirsesh pick-repo)"'
alias R='dirsesh at "$(dirsesh pick-repo-brief)"'
alias w='dirsesh at "$(dirsesh pick-worktree)"'
alias b='dirsesh at "$(dirsesh bookmark pick)"'
```

This ensures your muscle memory is similar no matter if you are in or out of tmux.
