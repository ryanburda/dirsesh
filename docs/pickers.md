# Pickers

A picker opens an fzf list, and starts a tmux session at whatever you choose:

```bash
dirsesh ls          # a directory under $HOME
dirsesh git         # a git repository under $HOME
dirsesh git-wt      # a worktree of the repository you are standing in
dirsesh z api       # a directory zoxide knows, named by keywords
dirsesh zi          # ...or chosen from zoxide's list
```

That is the whole interface. Each one is `dirsesh at` with the path filled in for you, so
everything [`at`](../README.md#session-creation) does still happens: a directory that already
has a session is switched to rather than opened twice, and a
[configuration](configured-sessions.md) claiming it still builds the session.

Each is opinionated in a way `dirsesh at` deliberately is not, and that stays something you opt
into, one binding at a time. Anything else that names a directory substitutes into `dirsesh at`
exactly as these do:

```bash
dirsesh at "$(zoxide query -i)"
dirsesh at "$(git rev-parse --show-toplevel)"
```

| instead of | you would write |
| --- | --- |
| `dirsesh ls` | `dirsesh at "$(find ~ -type d \| fzf)"` |
| `dirsesh git` | `dirsesh at "$(find ~ -name .git -prune -print \| sed 's#/\.git$##' \| fzf)"` |
| `dirsesh git-wt` | `dirsesh at "$(git worktree list \| fzf \| awk '{print $1}')"` |
| `dirsesh z api` | `dirsesh at "$(zoxide query -- api)"` |
| `dirsesh zi` | `dirsesh at "$(zoxide query -i)"` |

Those are the shape rather than the equivalent. What the sections below describe — the pruning,
the depth bounds, the `-brief` counts, backing out without erroring, bare repositories left off
the list — is the difference between the two columns.

## Dependencies

- [`fzf`](https://github.com/junegunn/fzf)
- [`zoxide`](https://github.com/ajeetdsouza/zoxide), for `z` and `zi` only

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
dirsesh z <query>...                    # Open a session at a directory zoxide knows, named by keywords
  query                                 # Keywords to match, or a directory to use as written
dirsesh zi [query]...                   # Choose a directory zoxide knows with fzf, and open a session there
  query                                 # Keywords to narrow the list with before it opens
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

### `z` and `zi`

These two go through [zoxide](https://github.com/ajeetdsouza/zoxide), which ranks the
directories you actually visit rather than walking the disk. `ls`, `git` and `git-wt` find
directories by what they *are*; these find them by where you have already been.

`dirsesh z` resolves keywords the way zoxide's own `z` does, and opens a session at what comes
back:

```bash
dirsesh z api            # the highest-ranked directory matching "api"
dirsesh z code api       # ...matching both keywords
dirsesh z ~/code/api     # a directory named outright
```

A single argument naming an existing directory is used as written — a path you spelled out is
not a search. Anything else is a query, and one argument holding several words is several
keywords: `dirsesh z "code api"` asks what `dirsesh z code api` asks. That matters because a
tmux `command-prompt` hands its whole answer over as one argument, and a query typed there
should mean what it means at a shell. A leading `~` is expanded for the same reason — a
command-prompt's answer arrives as written rather than through a shell that would have
expanded it.

An empty query is refused, and exits non-zero. zoxide would take it as "anything" and hand back
its top-ranked directory, which is a long way from what was asked for — and empty is exactly
what a command-prompt submitted with nothing in it gives. A query matching nothing is zoxide's
own error, on its own stderr, and opens nothing.

`dirsesh zi` is zoxide's interactive mode: the directories it knows, ranked, in fzf. A query
narrows the list before it opens rather than resolving to one answer:

```bash
dirsesh zi               # every directory zoxide knows, ranked
dirsesh zi code          # ...narrowed to the ones matching "code"
```

`z` is for when you know where you are going and `zi` for when you know you have been there —
the same split as [bookmarks](bookmark.md) against the pickers above, learned rather than
declared.

Both add the directory they open back to zoxide, so one reached through `dirsesh` ranks the same
as one reached by `z` at a shell. Without that, using dirsesh to get around would slowly make
zoxide worse at knowing where you go.

## Binding them

```tmux
# ~/.config/tmux/tmux.conf

bind-key d popup -E 'dirsesh ls'
bind-key r popup -E 'dirsesh git'
bind-key R popup -E 'dirsesh git -brief -filter -fetch'
bind-key w popup -E 'dirsesh git-wt'
bind-key i popup -E 'dirsesh zi'
bind-key z command-prompt -p "z:" "run-shell -b \"dirsesh z '%%%'\""
```

`z` is the one that takes typed input rather than offering a list, so it is bound through
`command-prompt` the way the [bookmark](bookmark.md) keys are — the binding asks, and passes the
answer in. Unlike those it uses `command-prompt` without `-1`, since a query is a word rather
than a single keypress, and `%%%` hands the whole answer over as one argument — which is why
`z` splits it back into keywords.

A picker is worth binding twice — once in `tmux.conf` like the above for when tmux is running,
and once in your shell for when no tmux server is running:

```zsh
# ~/.zshrc

alias d='dirsesh ls'
alias r='dirsesh git'
alias R='dirsesh git -brief -filter -fetch'
alias w='dirsesh git-wt'
alias z='dirsesh z'
alias zi='dirsesh zi'
```

An alias called `z` shadows the shell function zoxide's own `zoxide init` installs, so pick one:
either `z` cds and `dirsesh z` opens sessions, or the alias takes the name over. Nothing breaks
either way — both read and write the same database.

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
