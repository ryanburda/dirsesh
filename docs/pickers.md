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
  $DIRSESH_PICK_DIR_ROOT                # Where to search, instead of $HOME
  $DIRSESH_PICK_DIR_MAX_DEPTH           # How deep to search, instead of no limit
dirsesh pick-repo [-brief] [-filter] [-fetch]
                                        # Print a git repository under $HOME
  -brief                                # Show what each repository has waiting, beside its path
  -filter                               # List only the repositories that have something waiting
  -fetch                                # Fetch first, so the ahead/behind counts are current
  $DIRSESH_PICK_REPO_ROOT               # Where to search, instead of $HOME
  $DIRSESH_PICK_REPO_MAX_DEPTH          # How deep to search, instead of 5 levels (0 for no limit)
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

Every directory under `$HOME` — or under `$DIRSESH_PICK_DIR_ROOT`, if you
[set one](#dirsesh_pick_dir_root). No git involved, and no depth limit unless
[you set one](#dirsesh_pick_dir_max_depth). This is the picker for when the thing you want a
session at is a plain directory. It is also the slowest to appear on a large root, since it
walks the whole tree. Hidden directories are left out, the root itself aside.

#### `DIRSESH_PICK_DIR_ROOT`

Where the walk starts. `$HOME` unless you name somewhere else — `~/code`, a notes directory,
anywhere you keep more than one directory worth sitting in:

```bash
DIRSESH_PICK_DIR_ROOT="$HOME/code" dirsesh pick-dir
```

A value that names something which is not a directory is an error rather than an empty picker.
A root that is itself hidden works — `DIRSESH_PICK_DIR_ROOT="$HOME/.config"` lists what is under
it — even though hidden directories are otherwise left out of the walk.

#### `DIRSESH_PICK_DIR_MAX_DEPTH`

How far down from the root to walk. `0` — no limit, the whole tree — unless you say otherwise:

```bash
DIRSESH_PICK_DIR_MAX_DEPTH=3 dirsesh pick-dir
```

Counted in directories below the root: `1` is the root and what sits directly in it, `2` adds
their children. This is the one knob that makes `pick-dir` quick on a large root, since the walk
is the whole of the wait.

It is counted one level shallower than
[`DIRSESH_PICK_REPO_MAX_DEPTH`](#dirsesh_pick_repo_max_depth), which has to reach a repository's
`.git` rather than the repository itself.

Both are worth setting for good rather than typing each time — see
[Setting them for good](#setting-them-for-good).

### `pick-repo`

Every git repository under `$HOME` — or under `$DIRSESH_PICK_REPO_ROOT`, if you
[set one](#dirsesh_pick_repo_root). The walk goes [5 levels](#dirsesh_pick_repo_max_depth) down
from that root and prunes `.git`, `node_modules` and every hidden directory, so it stays fast
and does not descend into a dependency that vendored its own repository.

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

#### `DIRSESH_PICK_REPO_ROOT`

`$HOME` is the default root, not a fixed one. Set `DIRSESH_PICK_REPO_ROOT` to crawl somewhere
else — `~/code`, a work checkout, anywhere you keep more than one repository under one directory:

```bash
DIRSESH_PICK_REPO_ROOT="$HOME/code" dirsesh pick-repo
```

The depth limit is counted from that root, so a narrower one also reaches further into it. A
value that names something which is not a directory is an error rather than an empty list, and
one that names a directory with no repositories under it says which directory it walked.

A root that is itself hidden works — `DIRSESH_PICK_REPO_ROOT="$HOME/.config"` finds the
repositories under it — even though hidden directories are otherwise left out of the walk.

#### `DIRSESH_PICK_REPO_MAX_DEPTH`

How far down from the root to walk. 5 unless you say otherwise:

```bash
DIRSESH_PICK_REPO_MAX_DEPTH=3 dirsesh pick-repo
```

A repository is found by its `.git`, which sits one level below the repository itself, so 5
reaches a repository four directories down — `$ROOT/a/b/c/repo` — and 1 finds only a repository
at the root itself. Raise it for repositories kept deeper than that, at the cost of a longer
walk; lower it to cut the walk short on a deep tree.

`0` turns the limit off and walks as deep as the tree goes:

```bash
DIRSESH_PICK_REPO_MAX_DEPTH=0 dirsesh pick-repo
```

The pruning still applies, so that is not the whole tree — no hidden directory, no
`node_modules`, and nothing below a repository already found — but it is the slowest the walk
gets, and on a large root it is slow enough to notice on a picker meant to open on a keypress.
It is the setting for a root you know is shallow and tidy, or for one deep enough that guessing
a number is worse than paying for the walk.

The two go together, and both are worth setting for good rather than typing each time — see
[Setting them for good](#setting-them-for-good).

### `pick-worktree`

The worktrees of the repository you are standing in, branch beside path:

```console
path                branch
~/code/dirsesh/base main
~/code/dirsesh/fix  bugfix/hook-order
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

## Setting them for good

The four variables above — `DIRSESH_PICK_DIR_ROOT`, `DIRSESH_PICK_DIR_MAX_DEPTH`,
`DIRSESH_PICK_REPO_ROOT` and `DIRSESH_PICK_REPO_MAX_DEPTH` — are meant to be set once rather
than typed each time.

**Export them from the file your shell reads for _every_ shell, not just interactive ones.** For
zsh that is `~/.zshenv`; for bash, `~/.bash_profile` (or `~/.profile`):

```zsh
# ~/.zshenv

export DIRSESH_PICK_DIR_ROOT="$HOME"
export DIRSESH_PICK_DIR_MAX_DEPTH=4
export DIRSESH_PICK_REPO_ROOT="$HOME/code"
export DIRSESH_PICK_REPO_MAX_DEPTH=3
```

Spell the roots `$HOME` rather than `~`: a quoted `"~/code"` is never expanded, and the picker
would be looking for a directory literally named `~`.

`~/.zshenv` rather than `~/.zshrc` because of how a popup binding runs:

```tmux
bind-key r popup -E 'dirsesh at "$(dirsesh pick-repo)"'
```

tmux runs that through `$SHELL -c`, a shell that is neither interactive nor a login shell. zsh
reads `~/.zshenv` for such a shell and nothing else — not `~/.zshrc`, not `~/.zprofile`. A
variable exported from `~/.zshrc` reaches the popup only if it was already in the environment
the tmux server happened to be started from, which is why it works until the day the server is
started by something else — a service manager, a login script, an `attach` from a fresh login —
and the picker quietly falls back to its default. `~/.zprofile` is a smaller version of the same
problem: it covers ordinary panes, which tmux starts as login shells, but not popups.
