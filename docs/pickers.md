# Pickers

A picker opens an fzf list, and starts a tmux session at whatever you choose:

```bash
dirsesh ls        # a directory under $HOME
dirsesh git       # a git repository under $HOME
dirsesh git-wt    # a worktree of the repository you are standing in
```

That is the whole interface. Each one is `dirsesh at` with the path filled in for you, so
everything [`at`](../README.md#session-creation) does still happens: a directory that already
has a session is switched to rather than opened twice, and a
[configuration](configured-sessions.md) claiming it still builds the session.

Backing out of a picker opens nothing and exits 0, so pressing escape is a no-op rather than an
error.

These are opinionated in a way `dirsesh at` deliberately is not, and that stays something you
opt into, one binding at a time. Anything else that names a directory substitutes into `dirsesh
at` exactly as it always did:

```bash
dirsesh at "$(zoxide query -i)"
dirsesh at "$(git rev-parse --show-toplevel)"
```

## Dependencies

- [`fzf`](https://github.com/junegunn/fzf)

## Usage

```bash
dirsesh ls                              # Choose a directory under $HOME, and open a session there
  $DIRSESH_LS_ROOT                      # Where to search, instead of $HOME
  $DIRSESH_LS_MAX_DEPTH                 # How deep to search, instead of no limit
dirsesh git [-brief] [-filter] [-fetch]
                                        # Choose a git repository under $HOME, and open a session there
  -brief                                # Show what each repository has waiting, beside its path
  -filter                               # List only the repositories that have something waiting
  -fetch                                # Fetch first, so the ahead/behind counts are current
  $DIRSESH_GIT_ROOT                     # Where to search, instead of $HOME
  $DIRSESH_GIT_MAX_DEPTH                # How deep to search, instead of 5 levels (0 for no limit)
dirsesh git-wt                          # Choose a worktree of the current repository, and open a session there
```

Each picker documents itself. `-help` prints what it lists, how it behaves at the edges, and
anything worth knowing before you bind it to a key:

```bash
dirsesh git -help
dirsesh git-wt -help
```

That is where the per-command detail lives, so it cannot drift from the scripts the way a second
copy in this file would.

### `ls`

Every directory under `$HOME` — or under `$DIRSESH_LS_ROOT`, if you [set one](#dirsesh_ls_root).
No git involved, and no depth limit unless [you set one](#dirsesh_ls_max_depth). This is the
picker for when the thing you want a session at is a plain directory. It is also the slowest to
appear on a large root, since it walks the whole tree. Hidden directories are left out, the root
itself aside.

#### `DIRSESH_LS_ROOT`

Where the walk starts. `$HOME` unless you name somewhere else — `~/code`, a notes directory,
anywhere you keep more than one directory worth sitting in:

```bash
DIRSESH_LS_ROOT="$HOME/code" dirsesh ls
```

A value that names something which is not a directory is an error rather than an empty picker.
A root that is itself hidden works — `DIRSESH_LS_ROOT="$HOME/.config"` lists what is under it —
even though hidden directories are otherwise left out of the walk.

#### `DIRSESH_LS_MAX_DEPTH`

How far down from the root to walk. `0` — no limit, the whole tree — unless you say otherwise:

```bash
DIRSESH_LS_MAX_DEPTH=3 dirsesh ls
```

Counted in directories below the root: `1` is the root and what sits directly in it, `2` adds
their children. This is the one knob that makes `dirsesh ls` quick on a large root, since the
walk is the whole of the wait.

It is counted one level shallower than [`DIRSESH_GIT_MAX_DEPTH`](#dirsesh_git_max_depth), which
has to reach a repository's `.git` rather than the repository itself.

Both are worth setting for good rather than typing each time — see
[Setting them for good](#setting-them-for-good).

### `git`

Every git repository under `$HOME` — or under `$DIRSESH_GIT_ROOT`, if you
[set one](#dirsesh_git_root). The walk goes [5 levels](#dirsesh_git_max_depth) down from that
root and prunes `.git`, `node_modules` and every hidden directory, so it stays fast and does not
descend into a dependency that vendored its own repository.

Repositories are found by their `.git` rather than by asking each directory whether it is one,
which is what makes linked worktrees show up alongside ordinary clones — a worktree carries a
`.git` *file* rather than a directory. Only directories with a working tree are listed, so a
bare repository never appears, and neither does the `~/code/project` holding a `.bare` and its
worktrees. The worktrees themselves are listed, and are what you want a session at.

`dirsesh git` has three flags, and they are independent. `-brief` says what to show — each
repository's branch and what it has waiting, `↑` unpushed, `↓` waiting upstream, `+`/`-`
uncommitted, `?` untracked. `-filter` says what to leave out — everything with nothing waiting.
`-fetch` says how current the remote half of both is, at the cost of a network round trip per
repository, which is the whole of the wait:

```bash
dirsesh git                          # every repository, path only
dirsesh git -brief                   # every repository, and what it has waiting
dirsesh git -filter                  # only the ones with something waiting
dirsesh git -brief -filter           # both, read from the working tree
dirsesh git -brief -filter -fetch    # ...and against fetched remotes
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

#### `DIRSESH_GIT_ROOT`

`$HOME` is the default root, not a fixed one. Set `DIRSESH_GIT_ROOT` to crawl somewhere else —
`~/code`, a work checkout, anywhere you keep more than one repository under one directory:

```bash
DIRSESH_GIT_ROOT="$HOME/code" dirsesh git
```

The depth limit is counted from that root, so a narrower one also reaches further into it. A
value that names something which is not a directory is an error rather than an empty list, and
one that names a directory with no repositories under it says which directory it walked.

A root that is itself hidden works — `DIRSESH_GIT_ROOT="$HOME/.config"` finds the repositories
under it — even though hidden directories are otherwise left out of the walk.

#### `DIRSESH_GIT_MAX_DEPTH`

How far down from the root to walk. 5 unless you say otherwise:

```bash
DIRSESH_GIT_MAX_DEPTH=3 dirsesh git
```

A repository is found by its `.git`, which sits one level below the repository itself, so 5
reaches a repository four directories down — `$ROOT/a/b/c/repo` — and 1 finds only a repository
at the root itself. Raise it for repositories kept deeper than that, at the cost of a longer
walk; lower it to cut the walk short on a deep tree.

`0` turns the limit off and walks as deep as the tree goes:

```bash
DIRSESH_GIT_MAX_DEPTH=0 dirsesh git
```

The pruning still applies, so that is not the whole tree — no hidden directory, no
`node_modules`, and nothing below a repository already found — but it is the slowest the walk
gets, and on a large root it is slow enough to notice on a picker meant to open on a keypress.
It is the setting for a root you know is shallow and tidy, or for one deep enough that guessing
a number is worse than paying for the walk.

The two go together, and both are worth setting for good rather than typing each time — see
[Setting them for good](#setting-them-for-good).

### `git-wt`

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

bind-key d popup -E 'dirsesh ls'
bind-key r popup -E 'dirsesh git'
bind-key R popup -E 'dirsesh git -brief -filter -fetch'
bind-key w popup -E 'dirsesh git-wt'
```

A picker is worth binding twice — once in `tmux.conf` like the above for when tmux is running,
and once in your shell for when no tmux server is running:

```zsh
# ~/.zshrc

alias d='dirsesh ls'
alias r='dirsesh git'
alias R='dirsesh git -brief -filter -fetch'
alias w='dirsesh git-wt'
```

This ensures your muscle memory is similar no matter if you are in or out of tmux.

These are ordinary shell commands, not tmux commands: what `popup -E` runs above is a shell, and
the same string works in either place. There is nothing to type at tmux's own command prompt.

The [bookmarks](bookmark.md) bind the same way, and are the other half of this: a picker is for
when you are looking for a directory, a bookmark for when you already know which one you want.

## Setting them for good

The four variables above — `DIRSESH_LS_ROOT`, `DIRSESH_LS_MAX_DEPTH`, `DIRSESH_GIT_ROOT` and
`DIRSESH_GIT_MAX_DEPTH` — are meant to be set once rather than typed each time.

**Export them from the file your shell reads for _every_ shell, not just interactive ones.** For
zsh that is `~/.zshenv`; for bash, `~/.bash_profile` (or `~/.profile`):

```zsh
# ~/.zshenv

export DIRSESH_LS_ROOT="$HOME"
export DIRSESH_LS_MAX_DEPTH=4
export DIRSESH_GIT_ROOT="$HOME/code"
export DIRSESH_GIT_MAX_DEPTH=3
```

Spell the roots `$HOME` rather than `~`: a quoted `"~/code"` is never expanded, and the picker
would be looking for a directory literally named `~`.

`~/.zshenv` rather than `~/.zshrc` because of how a popup binding runs:

```tmux
bind-key r popup -E 'dirsesh git'
```

tmux runs that through `$SHELL -c`, a shell that is neither interactive nor a login shell. zsh
reads `~/.zshenv` for such a shell and nothing else — not `~/.zshrc`, not `~/.zprofile`. A
variable exported from `~/.zshrc` reaches the popup only if it was already in the environment
the tmux server happened to be started from, which is why it works until the day the server is
started by something else — a service manager, a login script, an `attach` from a fresh login —
and the picker quietly falls back to its default. `~/.zprofile` is a smaller version of the same
problem: it covers ordinary panes, which tmux starts as login shells, but not popups.
