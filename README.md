# dirsesh

_One configurable tmux session per directory_


`dirsesh` launches tmux sessions at directories.

```bash
dirsesh at [path]
```

The `path` argument can be:
```bash
# a specific path:
#
# the location of a project
dirsesh at "$HOME/code/project_name"
# your root directory
dirsesh at /
# your current directory
dirsesh at .

# the result of a command:
#
# the root of the repo you are currently in
dirsesh at "$(git rev-parse --show-toplevel)"
# a fresh scratch directory
dirsesh at "$(mktemp -d)"

# or the result of an interactive command/fuzzy finder:
#
# fuzzy find directories in your HOME folder
dirsesh at "$(find $HOME -type d | fzf)"
# fuzzy find worktrees of the current git repo
dirsesh at "$(git worktree list | fzf | awk '{print $1}')"
# type something and start a session wherever zoxide takes you
(printf 'z '; read -r q; z "$q" && dirsesh at .)
```

### Session creation

Once a directory is passed to `dirsesh at <path>`, every session is created the same way:

1. **Does a session already exist for that directory?**

    Switch to it.

    This makes `dirsesh at` idempotent, preventing multiple sessions from being created
    at the same directory even if a session has been renamed.

    A session is identified by the directory it started at, not by its name. `dirsesh` records
    that directory in the session's state directory when it creates it, and compares against
    that record.

    Only sessions `dirsesh` started are compared against. A plain `tmux new-session -c <path>`
    has no record, so `dirsesh at <path>` neither finds it nor is stopped by it -- which is the
    escape hatch when you do want two sessions at one directory. `dirsesh` complements the tmux
    commands rather than standing in front of them.

2. **Does a configuration claim that directory?**

    Use that configuration when creating/naming the session.

    See [Configured Sessions](docs/configured-sessions.md) for details on how to customize sessions.

3. **Otherwise:**

    Create a plain session named after the directory.

### Session teardown

A session built by a configuration's `start` should always get its matching `kill`. `dirsesh`
therefore hangs teardown off a `session-closed` hook rather than a command, so `kill` is
invoked whether you kill the session explicitly or its last pane simply exits:

```bash
# Add this to ~/.tmux.conf to install the hook
run-shell "dirsesh init"
```

That one line is the whole of dirsesh's tmux setup: it installs the `session-closed` hook
teardown works through, and the hooks that keep [`bm-status`](docs/bookmark.md) current.
`dirsesh init -help` spells out what lands where.

That last case is the one that matters, and it is why teardown is a hook rather than a command
to parallel `dirsesh at`. A shell exiting closes the session without anything asking `dirsesh`
to, and `dirsesh kill` is an ordinary `tmux kill-session` that goes through the same hook as
everything else. Sessions killed outside of `dirsesh`'s control are still handled correctly.

The hook fires for every session tmux closes but it acts only on sessions `dirsesh at` built from
a configuration. Everything else closes exactly as it would on a server with no `dirsesh` on it.

### Goal

`dirsesh at [path]` is designed to be a convenient wrapper around `tmux new-session -c <path>` where:
- sessions for paths that already exist are switched to instead of recreated
- configuration scripts are applied at session creation based on the directory
- tear down scripts are automatically run no matter how the session is killed

### Extras

`dirsesh at` creates sessions. Switching between them and killing them are separate jobs that
plenty of other tools already do well, so if you have one you like, keep using it.

`dirsesh` does ship with a few other commands for a more well rounded experience. Each of the
first two chooses a directory and hands it to `dirsesh at` itself, so there is nothing to chain:

```bash
dirsesh git      # choose a repository under $HOME, and open a session there
dirsesh bm m     # ...or go straight to the one bookmarked at m
```

- [Pickers](docs/pickers.md) — `ls`, `git`, `git-wt`
- [Bookmarks](docs/bookmark.md) — `bm`, `bm-set`, `bm-rm`, `bm-status`
- [Session Management](docs/session-management.md) — `switch`, `last`, `kill`, `logs`


## Usage

```bash
dirsesh - One configurable tmux session per directory

Usage:
  dirsesh                                        # Show help message
  dirsesh <command> -help                        # Show what one command does, in detail

  dirsesh at <path> [-noconfig] [-name[=NAME]]   # Start or switch to session at a directory
    path                                         # The directory to start the session at
    -noconfig                                    # Ignore any configuration claiming that path
    -name[=NAME]                                 # Name the session; prompts for one if NAME is not given

  dirsesh config-match [path]                    # Configurations claiming a path (defaults to the current directory)

  dirsesh init                                   # Install dirsesh's tmux hooks (put this in tmux.conf)

  dirsesh ls                                     # Choose a directory under $HOME, and open a session there
    $DIRSESH_LS_ROOT                             # Where to search, instead of $HOME
    $DIRSESH_LS_MAX_DEPTH                        # How deep to search, instead of no limit
  dirsesh git [-brief] [-filter] [-fetch]        # Choose a git repository under $HOME, and open a session there
    -brief                                       # Show what each repository has waiting, beside its path
    -filter                                      # List only the repositories that have something waiting
    -fetch                                       # Fetch first, so the ahead/behind counts are current
    $DIRSESH_GIT_ROOT                            # Where to search, instead of $HOME
    $DIRSESH_GIT_MAX_DEPTH                       # How deep to search, instead of 5 levels (0 for no limit)
  dirsesh git-wt                                 # Choose a worktree of the current repository, and open a session there

  dirsesh bm [char] [-p]                         # Open a session at a bookmark; chooses one with fzf when char is left off
    char                                         # The character the bookmark is keyed by
    -p                                           # Print every bookmark as "char<TAB>directory" instead
  dirsesh bm-set <char> [path]                   # Bookmark a directory, one printable character each
    char                                         # The character to bookmark at
    path                                         # The directory to bookmark (defaults to the current directory)
  dirsesh bm-rm <char>                           # Remove a bookmark
  dirsesh bm-status [path]                       # Bookmarks with a tmux session open at them, for a status line
  dirsesh bm-status-init                         # Install the tmux hooks `bm-status` needs (`dirsesh init` too)

  dirsesh switch [session]                       # Switch to another running session
    session                                      # Switch straight to this one instead of picking
  dirsesh last                                   # Switch back to the session you came from
  dirsesh kill [session]                         # Kill a running session
    session                                      # Kill this one instead of picking
  dirsesh logs [session]                         # Browse the logs a dirsesh configuration wrote
    session                                      # Browse only this session's logs

Every command that chooses a directory opens a session at it, so none of them
has to be chained with `dirsesh at`:

  dirsesh git
  dirsesh bm m

`at` is the one that takes a path rather than finding one, and `bm -p` the one
that prints rather than opens.

See https://github.com/ryanburda/dirsesh for more documentation
```


## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ryanburda/dirsesh/main/install.sh | sh
```

The install script:
- clones the repository to `${XDG_DATA_HOME:-~/.local/share}/dirsesh`
- symlinks `dirsesh` into `~/.local/bin`.

Re-run it any time to update.

<details>
<summary><strong style="font-size: 1.25em;">Custom Installation</strong></summary>

Two environment variables change where things land: `DIRSESH_HOME` (where the repo is cloned) and
`BIN_DIR` (where the symlinks go).

```bash
curl -fsSL https://raw.githubusercontent.com/ryanburda/dirsesh/main/install.sh \
  | DIRSESH_HOME=~/src/dirsesh BIN_DIR=~/bin sh
```

Or manually: clone the repo, symlink `dirsesh` into a directory on your PATH. Every
subcommand runs a script under `src/`, which `dirsesh` finds relative to itself with the
symlink resolved, so that one link is the whole install.

```bash
git clone https://github.com/ryanburda/dirsesh.git ~/git/dirsesh
ln -s ~/git/dirsesh/dirsesh ~/.local/bin/dirsesh
```
</details>

<details>
<summary><strong style="font-size: 1.25em;">Shell Completions</strong></summary>

Completions cover subcommands, their flags, and directories. Paths below assume the install script's checkout location; substitute your own if you
cloned elsewhere.

**Bash**: add to `~/.bashrc`:

```bash
source ~/.local/share/dirsesh/completions/dirsesh.bash
```

**Zsh**: `compinit` finds a completion by file name, so link it in as `_dirsesh`:

```bash
mkdir -p ~/.zsh/completions
ln -s ~/.local/share/dirsesh/completions/dirsesh.zsh ~/.zsh/completions/_dirsesh
```

and add to `~/.zshrc`, before `compinit` runs:

```bash
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
```
</details>


## License

MIT


## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
