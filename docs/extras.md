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

  dirsesh-extras session-switcher [session]                              # Switch to another running session
    session                                                              # Switch straight to this one instead of picking
  dirsesh-extras last-session                                            # Switch back to the session you came from
  dirsesh-extras kill-session [session]                                  # Kill a running session
    session                                                              # Kill this one instead of picking

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

See https://github.com/ryanburda/tmux-dirsesh for more documentation
```

## The `pick-*` commands

A picker prints a path and nothing else. That is the whole contract, and it is the same one
`dirsesh at` expects of any command you substitute into it:

```bash
dirsesh at "$(dirsesh-extras pick-repo)"
```

They all behave the same way at the edges:

- **You choose something** — the path goes to stdout, and `dirsesh at` opens a session there.
- **You press escape** — nothing is printed and the command succeeds. Backing out of a picker is
  not a failure, and `dirsesh at ""` opens nothing rather than erroring.
- **There is nothing to pick, or `fzf` is missing** — a message and a non-zero exit. The message
  goes to `tmux display-message` inside tmux and to stderr outside it, never to stdout. A picker
  run from a `popup -E` loses its stderr when the popup closes, so anything printed there would
  be lost.

Everything a picker says that is *not* the answer stays off stdout for that reason. If you write
your own, do the same.

### `pick-dir`

Every directory under `$HOME`, hidden ones pruned, handed to `fzf`.

```bash
dirsesh at "$(dirsesh-extras pick-dir)"
```

No git involved and no depth limit: this is the picker for the times the thing you want a
session at is a plain directory. It is also the slowest to appear on a large `$HOME`, since it
walks the whole tree.

### `pick-repo`

Git repositories under `$HOME`, handed to `fzf`.

```bash
dirsesh at "$(dirsesh-extras pick-repo)"
```

This is the default picker — a bare `dirsesh at` runs exactly this.

The walk is bounded at 5 levels deep and prunes `.git`, `node_modules` and every hidden
directory, so it stays fast and does not descend into a dependency that vendored its own
repository. Repositories are found by their `.git` rather than by asking each directory whether
it is one, which is what makes linked worktrees and bare-clone checkouts show up alongside
ordinary clones: both carry a `.git` *file* rather than a directory.

### `pick-repo-brief`

The same repositories as `pick-repo`, narrowed to the ones with something waiting in them, and
annotated with what that something is.

```bash
dirsesh at "$(dirsesh-extras pick-repo-brief)"
```

A repository earns a row if it has commits to pull, commits to push, or uncommitted work:

```
:: 3 of 27 repositories have changes

~/code/api          main ↑2 +41 -7
~/code/dotfiles     main ↓1
~/code/site         draft ↑1 ?3
```

| | |
|---|---|
| `↑n` | commits ahead of upstream |
| `↓n` | commits behind upstream |
| `+n` `-n` | lines added and removed against `HEAD`, staged work included |
| `?n` | untracked files, counting a new directory once |

The header counts how many repositories made the list out of how many were checked, so a short
list is distinguishable from a broken one.

Every repository is fetched before it is inspected, eight at a time, which is what makes the
ahead/behind counts trustworthy and the picker slow to appear. It is worth it first thing in
the morning and annoying at every other moment; bind it separately from `pick-repo` rather than
replacing it.

### `pick-worktree`

The worktrees of the repository you are currently in, with their branches.

```bash
dirsesh at "$(dirsesh-extras pick-worktree)"
```

```
path                     branch
~/code/tmux-dirsesh/base main
~/code/tmux-dirsesh/fix  bugfix/hook-order
```

Unlike the others this one is relative to where you are: it reads `git worktree list` in the
current directory, so it has to be run from inside a repository (or one of its worktrees) and
says `No worktrees found` when it is not. A bare repository is skipped — there is no working
tree to sit in — and the worktrees checked out beside it are listed on their own. A detached
`HEAD` shows as `(detached)`.

Pairing this with `dirsesh at` is the point of the whole arrangement: a session per worktree,
each laid out by whatever [configuration](configured-sessions.md) claims it, switched between
by name rather than by `cd`.

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
