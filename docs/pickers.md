# Pickers

A picker prints a directory on stdout and stops. It does not open anything, and nothing in
`dirsesh at` calls one — it is you who substitutes the path it printed:

```bash
dirsesh at "$(dirsesh pick-dir)"
dirsesh at "$(dirsesh pick-repo)"
dirsesh at "$(dirsesh pick-worktree)"
```

That is the whole interface. It is also why the pickers are opinionated in a way `dirsesh at`
deliberately is not: the opinions stay something you opt into, one binding at a time, rather
than something you have to work around. Anything else that names a directory — `zoxide query
-i`, `find | fzf`, a script of your own — substitutes in exactly the same place.

Backing out of a picker prints nothing and exits 0, so `dirsesh at "$(dirsesh pick-repo)"`
opens nothing when you press escape, rather than erroring.

## Dependencies

- [`fzf`](https://github.com/junegunn/fzf)

## Usage

```bash
dirsesh pick-dir                        # Print a directory under $HOME
dirsesh pick-repo [-brief] [-filter] [-fetch]
                                        # Print a git repository under $HOME
  -brief                                # Show what each repository has waiting, beside its path
  -filter                               # List only the repositories that have something waiting
  -fetch                                # Fetch first, so the ahead/behind counts are current
dirsesh pick-worktree                   # Print a worktree of the current repository
```

Each picker documents itself. `-help` prints what it lists, how it behaves at the edges, and
anything worth knowing before you bind it to a key:

```bash
dirsesh pick-repo -help
dirsesh pick-worktree -help
```

That is where the per-command detail lives, so it cannot drift from the scripts the way a second
copy in this file would.

### `pick-dir`

Every directory under `$HOME`, no git involved and no depth limit. This is the picker for when
the thing you want a session at is a plain directory. It is also the slowest to appear on a
large `$HOME`, since it walks the whole tree.

### `pick-repo`

Every git repository under `$HOME`. The walk is bounded at 5 levels deep and prunes `.git`,
`node_modules` and every hidden directory, so it stays fast and does not descend into a
dependency that vendored its own repository.

Repositories are found by their `.git` rather than by asking each directory whether it is one,
which is what makes linked worktrees show up alongside ordinary clones — a worktree carries a
`.git` *file* rather than a directory. Only directories with a working tree are listed, so a
bare repository never appears, and neither does the `~/code/project` holding a `.bare` and its
worktrees. The worktrees themselves are listed, and are what you want a session at.

`pick-repo` has three flags, and they are independent. `-brief` says what to show — each
repository's branch and what it has waiting, `↑` unpushed, `↓` waiting upstream, `+`/`-`
uncommitted, `?` untracked. `-filter` says what to leave out — everything with nothing waiting.
`-fetch` says how current the remote half of both is, at the cost of a network round trip per
repository, which is the whole of the wait:

```bash
dirsesh pick-repo                          # every repository, path only
dirsesh pick-repo -brief                   # every repository, and what it has waiting
dirsesh pick-repo -filter                  # only the ones with something waiting
dirsesh pick-repo -brief -filter           # both, read from the working tree
dirsesh pick-repo -brief -filter -fetch    # ...and against fetched remotes
```

`-brief` looks like this:

```console
/home/you/code/api        main ↑2 +41 -7
/home/you/code/dotfiles   main ↓1
/home/you/code/site       draft ↑1 ?3
/home/you/code/tools      main
```

A repository with none of the counts shows its branch alone, which is the whole point of
`-brief` without `-filter`: the quiet ones stay on the list. `-filter` drops them and heads the
list with how many that was out of how many were checked, so a short list is distinguishable
from a broken one:

```console
:: 3 of 27 repositories have changes
```

Without `-fetch`, `↑` and `↓` are counted against the upstream ref as it stands on disk — the
same counts `git status` reports, and stale in the same way. Everything else is read from the
working tree and is current either way.

### `pick-worktree`

The worktrees of the repository you are standing in, branch beside path:

```console
path                     branch
~/code/tmux-dirsesh/base main
~/code/tmux-dirsesh/fix  bugfix/hook-order
```

Must be run from inside a git repository (or another worktree). A bare repository is skipped —
there is no working tree to sit in — and the worktrees checked out beside it are listed on their
own. A detached HEAD shows as `(detached)`.

## Binding them

```tmux
# ~/.config/tmux/tmux.conf

bind-key d popup -E 'dirsesh at "$(dirsesh pick-dir)"'
bind-key r popup -E 'dirsesh at "$(dirsesh pick-repo)"'
bind-key R popup -E 'dirsesh at "$(dirsesh pick-repo -brief -filter -fetch)"'
bind-key w popup -E 'dirsesh at "$(dirsesh pick-worktree)"'
```

A picker is worth binding twice — once in `tmux.conf` like the above for when tmux is running,
and once in your shell for when no tmux server is running:

```zsh
# ~/.zshrc

alias d='dirsesh at "$(dirsesh pick-dir)"'
alias r='dirsesh at "$(dirsesh pick-repo)"'
alias R='dirsesh at "$(dirsesh pick-repo -brief -filter -fetch)"'
alias w='dirsesh at "$(dirsesh pick-worktree)"'
```

This ensures your muscle memory is similar no matter if you are in or out of tmux.

The [bookmarks](bookmark.md) bind the same way, and are the other half of this: a picker is for
when you are looking for a directory, a bookmark for when you already know which one you want.
