# tmux-dirsesh

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

# the result of a command:
#
# your current working directory
dirsesh at "$(pwd)"
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
# Search your most-used directories
dirsesh at "$(zoxide query -i)"
```

### Session creation

Once a directory is passed to `dirsesh at <path>`, every session is created the same way:

1. **Does a session already exist for that directory?**

    Switch to it.

    This makes `dirsesh at` idempotent, preventing multiple sessions from being created
    at the same directory even if a session has been renamed.

    A session is identified by the directory it started at, not by its name. `dirsesh` records
    that directory on the session in the `@dirsesh_path` tmux option and compares against that.
    Sessions `dirsesh` did not create have no `@dirsesh_path` and fall back to tmux's `#{session_path}`,
    so a plain `tmux new-session` at that directory is found too.

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
teardown works through, and the hooks that keep [`bookmark status`](docs/bookmark.md) current.
`dirsesh init -help` spells out what lands where.

That last case is the one that matters, and it is why there is no session-killing command to
parallel `dirsesh at`. A shell exiting closes the session without anything asking `dirsesh` to.
Sessions killed outside of `dirsesh`'s control are still handled correctly.

The hook fires for every session tmux closes but it acts only on sessions `dirsesh at` built from
a configuration. Everything else closes exactly as it would on a server with no `dirsesh` on it.

### Goal

`dirsesh at [path]` is designed to be a convenient wrapper around `tmux new-session -c <path>` where:
- sessions for paths that already exist are switched to instead of recreated
- configuration scripts are applied at session creation based on the directory
- tear down scripts are automatically run no matter how the session is killed

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

  dirsesh match [path]                           # Configurations claiming a path (defaults to the current directory)

  dirsesh init                                   # Install dirsesh's tmux hooks (put this in tmux.conf)

  dirsesh session-switch [session]               # Switch to another running session
    session                                      # Switch straight to this one instead of picking
  dirsesh session-last                           # Switch back to the session you came from
  dirsesh session-kill [session]                 # Kill a running session
    session                                      # Kill this one instead of picking
  dirsesh session-logs [session]                 # Browse the logs a dirsesh configuration wrote
    session                                      # Browse only this session's logs

  dirsesh bookmark <command> [args...]           # Bookmark directories, one printable character each
    set <char> [path]                            # Bookmark a directory (path defaults to the current directory)
    remove <char>                                # Remove a bookmark
    get <char>                                   # Print the directory a bookmark points at
    pick                                         # Choose a bookmark with fzf and print its directory
    list                                         # Every bookmark as "char<TAB>directory"
    status [path]                                # Bookmarks with a tmux session open at them, for a status line
    status-init                                  # Install the tmux hooks `status` needs (`dirsesh init` does this too)

  dirsesh pick-dir                               # Print a directory under $HOME
  dirsesh pick-repo                              # Print a git repository under $HOME
  dirsesh pick-repo-brief                        # Print a git repository under $HOME that has changes
  dirsesh pick-worktree                          # Print a worktree of the current repository

The pickers print a path on stdout, so they compose with `dirsesh at`:

  dirsesh at "$(dirsesh pick-repo)"
  dirsesh at "$(dirsesh bookmark get m)"

See https://github.com/ryanburda/tmux-dirsesh for more documentation
```

## Extras

`dirsesh at` creates sessions. Switching between them and killing them are separate jobs that
plenty of other tools already do well, so if you have one you like, keep using it.

If you would rather `dirsesh` be your session manager anyway, the rest of its subcommands are
the other half:
- the directory pickers that pair with `dirsesh at`
- a session switcher/killer that uses fzf
- a directory bookmarker, one printable character per directory
- and other handy features

None of them is wired into `dirsesh at`: a picker prints a path and stops, and it is you who
substitutes that path in. See [Extras](docs/extras.md) and [Bookmarks](docs/bookmark.md).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ryanburda/tmux-dirsesh/main/install.sh | sh
```

The install script:
- clones the repository to `${XDG_DATA_HOME:-~/.local/share}/tmux-dirsesh`
- symlinks `dirsesh` into `~/.local/bin`.

Re-run it any time to update.

<details>
<summary><strong style="font-size: 1.25em;">Custom Installation</strong></summary>

Two environment variables change where things land: `DIRSESH_HOME` (where the repo is cloned) and
`BIN_DIR` (where the symlinks go).

```bash
curl -fsSL https://raw.githubusercontent.com/ryanburda/tmux-dirsesh/main/install.sh \
  | DIRSESH_HOME=~/src/dirsesh BIN_DIR=~/bin sh
```

Or manually: clone the repo, symlink `dirsesh` into a directory on your PATH. Every
subcommand runs a script under `src/`, which `dirsesh` finds relative to itself with the
symlink resolved, so that one link is the whole install.

```bash
git clone https://github.com/ryanburda/tmux-dirsesh.git ~/git/tmux-dirsesh
ln -s ~/git/tmux-dirsesh/dirsesh ~/.local/bin/dirsesh
```
</details>

<details>
<summary><strong style="font-size: 1.25em;">Shell Completions</strong></summary>

Completions cover subcommands, their flags, and directories. Paths below assume the install script's checkout location; substitute your own if you
cloned elsewhere.

**Bash**: add to `~/.bashrc`:

```bash
source ~/.local/share/tmux-dirsesh/completions/dirsesh.bash
```

**Zsh**: `compinit` finds a completion by file name, so link it in as `_dirsesh`:

```bash
mkdir -p ~/.zsh/completions
ln -s ~/.local/share/tmux-dirsesh/completions/dirsesh.zsh ~/.zsh/completions/_dirsesh
```

and add to `~/.zshrc`, before `compinit` runs:

```bash
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
```

**Fish**:

```bash
ln -s ~/.local/share/tmux-dirsesh/completions/dirsesh.fish ~/.config/fish/completions/
```
</details>

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
