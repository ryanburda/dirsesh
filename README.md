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

Or leave `path` blank and dirsesh will fuzzy-find one for you:

```bash
dirsesh at
```

The default command walks `$HOME` (up to 5 levels deep, skipping hidden directories)
for git repos and hands them to `fzf`.

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

  dirsesh at [path] [-noconfig] [-name[=NAME]]   # Start or switch to session at a directory
    path                                         # Defaults to a fuzzy-find of git repos under $HOME
    -noconfig                                    # Ignore any configuration claiming that path
    -name[=NAME]                                 # Name the session; prompts for one if NAME is not given

  dirsesh match [path]                           # Configurations claiming a path (defaults to the current directory)

  dirsesh init                                   # Install the hook that cleans up configured sessions (put this in tmux.conf)
```

## Extras

`dirsesh` creates sessions. Switching between them and killing them are separate jobs that
plenty of other tools already do well, so if you have one you like, keep using it.

If you would rather `dirsesh` be your session manager anyway, `dirsesh-extras` is a second
command holding the rest of it:
- the directory pickers that pair with `dirsesh at`
- a session switcher/killer that uses fzf
- a directory bookmarker
- and other handy features

See [Extras](docs/extras.md).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ryanburda/tmux-dirsesh/main/install.sh | sh
```

The install script:
- clones the repository to `${XDG_DATA_HOME:-~/.local/share}/tmux-dirsesh`
- symlinks `dirsesh` and `dirsesh-extras` into `~/.local/bin`.

Re-run it any time to update.

<details>
<summary><strong style="font-size: 1.25em;">Custom Installation</strong></summary>

Two environment variables change where things land: `DIRSESH_HOME` (where the repo is cloned) and
`BIN_DIR` (where the symlinks go).

```bash
curl -fsSL https://raw.githubusercontent.com/ryanburda/tmux-dirsesh/main/install.sh \
  | DIRSESH_HOME=~/src/dirsesh BIN_DIR=~/bin sh
```

Or manually: clone the repo, symlink both programs into a directory on your PATH.

```bash
git clone https://github.com/ryanburda/tmux-dirsesh.git ~/git/tmux-dirsesh
ln -s ~/git/tmux-dirsesh/dirsesh        ~/.local/bin/dirsesh
ln -s ~/git/tmux-dirsesh/dirsesh-extras ~/.local/bin/dirsesh-extras
```
</details>

<details>
<summary><strong style="font-size: 1.25em;">Shell Completions</strong></summary>

Completions cover subcommands, their flags, and directories. Paths below assume the install script's checkout location; substitute your own if you
cloned elsewhere.

**Bash**: add to `~/.bashrc`:

```bash
source ~/.local/share/tmux-dirsesh/completions/dirsesh.bash
source ~/.local/share/tmux-dirsesh/completions/dirsesh-extras.bash
```

**Zsh**: `compinit` finds a completion by file name, so link them in as `_dirsesh` and
`_dirsesh-extras`:

```bash
mkdir -p ~/.zsh/completions
ln -s ~/.local/share/tmux-dirsesh/completions/dirsesh.zsh        ~/.zsh/completions/_dirsesh
ln -s ~/.local/share/tmux-dirsesh/completions/dirsesh-extras.zsh ~/.zsh/completions/_dirsesh-extras
```

and add to `~/.zshrc`, before `compinit` runs:

```bash
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
```

**Fish**:

```bash
ln -s ~/.local/share/tmux-dirsesh/completions/dirsesh.fish ~/.config/fish/completions/
ln -s ~/.local/share/tmux-dirsesh/completions/dirsesh-extras.fish ~/.config/fish/completions/
```
</details>

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
