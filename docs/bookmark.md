# Bookmarks

The `dirsesh bookmark-*` commands map a character to a directory, the way vim marks do.

```bash
dirsesh bookmark-set m ~/code/api      # m is now ~/code/api
dirsesh bookmark-get m                 # /home/you/code/api
cd "$(dirsesh bookmark-get m)"
```

Bookmarks are for the handful of directories you return to constantly. There is no ranking,
no history and no decay: `m` points where you put it until you put it somewhere else. That
is the difference between this and the [fuzzy pickers](pickers.md) beside it, and the reason
both are worth having.

`bookmark-get` and `bookmark-pick` print a directory on stdout and nothing else, which is the
same interface the pickers have, and the whole interface to everything downstream:

```bash
cd "$(dirsesh bookmark-pick)"                  # choose one with fzf
dirsesh at "$(dirsesh bookmark-get m)"         # a tmux session at whatever m bookmarks
dirsesh at "$(dirsesh bookmark-pick)"          # ...or at one you choose
```

## Dependencies

- [`fzf`](https://github.com/junegunn/fzf), for `bookmark-pick`
- `tmux`, for `bookmark-status` and `bookmark-status-init`

Everything else runs with a shell and `awk`.

## Usage

```bash
dirsesh bookmark-set <char> [path]     # Bookmark a directory (path defaults to the current directory)
dirsesh bookmark-remove <char>         # Remove a bookmark
dirsesh bookmark-get <char>            # Print the directory a bookmark points at
dirsesh bookmark-pick                  # Choose a bookmark with fzf and print its directory
dirsesh bookmark-list                  # Every bookmark as "char<TAB>directory"
dirsesh bookmark-status [path]         # Bookmarks with a tmux session open at them, for a status line
dirsesh bookmark-status-init           # Install the tmux hooks `bookmark-status` needs (put this in tmux.conf)
```

`dirsesh bookmark-<command> -help` prints the same thing — they are one program and share one
`-help`.

### Setting and removing

```bash
dirsesh bookmark-set m                 # bookmark the current directory at m
dirsesh bookmark-set m ~/code/api      # ...or one you name
dirsesh bookmark-remove m
```

A bookmark is keyed by a single printable ASCII character — any of `!` through `~` except `/`
and `.`, which can't name the file a bookmark is stored in — so digits and punctuation work as
well as letters, and upper and lower case are two different bookmarks. Setting a character that
is already set replaces it, no confirmation, the same way `m` does in vim. The path is resolved
to an absolute one with symlinks followed, so a bookmark keeps pointing at the same directory
whatever you were standing in when you set it.

### Reading

`bookmark-get` prints one directory and nothing else, so it composes:

```bash
cd "$(dirsesh bookmark-get m)"
ls "$(dirsesh bookmark-get m)"
```

It exits non-zero and says nothing on stdout if the character is not bookmarked, so
`cd "$(dirsesh bookmark-get z)"` fails rather than sending you home.

`bookmark-list` is the whole store, one `char<TAB>directory` line at a time, sorted by character — for
scripts, and for looking at:

```console
$ dirsesh bookmark-list
c	/home/you/.config
m	/home/you/code/api
n	/home/you/.config/nvim
```

### `bookmark-pick`

Lists the bookmarks in fzf and prints the directory of the one you choose. `ctrl-x` removes the
bookmark under the cursor and rebuilds the list, which is how a bookmark you have stopped using
gets cleaned up without having to remember which character it was.

Backing out prints nothing and exits 0 — the way the other pickers decline to answer — so
`dirsesh at "$(dirsesh bookmark-pick)"` opens nothing when you press escape, rather than
erroring.

### Status line (`bookmark-status`)

Prints the characters of the bookmarks that have a **tmux session open** at their directory, the
current session's styled differently. Bookmarks with nothing open are left out, so the line stays
short and reads as "where can I already jump to":

```tmux
set -g status-right "#(dirsesh bookmark-status '#{session_path}')"
```

Two flags set the styles, written without their `#[]` wrapper: `-s`/`--style` for the other open
sessions (default `dim`) and `-c`/`--current-style` for the current one (default
`fg=yellow,bold`):

```tmux
set -g status-right "#(dirsesh bookmark-status '#{session_path}' -s 'fg=colour244' -c 'fg=black,bg=blue,bold')"
```

The path argument matters: tmux runs a `#()` command without a client and shares one run's
output between all of them, so `bookmark-status` cannot ask which session is current and get a
per-client answer. Passing `#{session_path}` is what makes the highlight follow each client.

A status line is only redrawn every `status-interval` seconds, so a session opened or killed
elsewhere would take that long to appear. Two tmux hooks make it immediate, on every attached
client, and `dirsesh init` installs them — so a `tmux.conf` that already has

```tmux
run-shell "dirsesh init"
```

needs nothing further. `bookmark-status-init` installs those two on their own, without the
session cleanup hook that comes with them:

```tmux
run-shell "dirsesh bookmark-status-init"
```

Either way it hangs a refresh off `session-created` and `session-closed`, appending to both so
anything else on them survives — `dirsesh init`'s own `session-closed` hook included — and
dropping the hooks a previous run left behind so re-sourcing `tmux.conf` does not stack
duplicates. The hooks are only needed for the status line; nothing else in `bookmark-*` goes
through one. Setting and removing a bookmark refresh the line on their own.

> **NOTE:** if your `tmux.conf` sets `session-created` or `session-closed` with a bare
> `set-hook -g`, put `run-shell "dirsesh init"` after it — a later `set-hook -g` clears what
> it appended.

## tmux keybindings

`bookmark-set`, `bookmark-remove` and `bookmark-get` take the character as an argument — none
of them has a keypress prompt of its own. Inside tmux that is what `command-prompt -1` is for,
which reaches all of them by a single keypress:

```tmux
bind-key m command-prompt -1 -p "Set bookmark:"    "run-shell -b \"dirsesh bookmark-set '%%%'\""
bind-key M command-prompt -1 -p "Remove bookmark:" "run-shell -b \"dirsesh bookmark-remove '%%%'\""
bind-key \' command-prompt -1 -p "Go to bookmark:" "run-shell -b \"dirsesh at \$(dirsesh bookmark-get '%%%')\""
bind-key b popup -E 'dirsesh at "$(dirsesh bookmark-pick)"'
```

These ask in tmux's status line, so they need no popup: `-1` takes exactly one key and `%%%`
substitutes it with quotation marks escaped. `'` and `;` are the two keys that cannot be
answered with — `;` is tmux's own command separator — so do not bookmark at those.

The last two lines send the directory to `dirsesh`, which opens a tmux session there. Anything
that takes a path works the same way; bookmarks themselves do not know what tmux is, apart from
`bookmark-status`.

`bookmark-set` bound this way bookmarks the directory the *session* is rooted at. To bookmark
the current pane's directory instead:

```tmux
bind-key m command-prompt -1 -p "Set bookmark:" "run-shell -b \"dirsesh bookmark-set '%%%' '#{pane_current_path}'\""
```

As with the pickers, a bookmark is worth binding twice — once in `tmux.conf` for when tmux is
running, and once in your shell for when no tmux server is:

```zsh
# ~/.zshrc

alias b='dirsesh at "$(dirsesh bookmark-pick)"'
```

> **Troubleshooting:** tmux's `run-shell` and `popup -E` run in a non-interactive, non-login
> shell, so `dirsesh` must be on PATH when that shell starts.
>
> - **zsh:** put your PATH setup in `~/.zshenv` (not `.zshrc`).
> - **bash:** set `BASH_ENV` to a file that configures your PATH, or use `/etc/environment`.
>
> Fallback: use the full path in the bindings, e.g.
> `run-shell -b "~/.local/share/tmux-dirsesh/dirsesh bookmark-set '%%%'"`.

## Storage

Each bookmark is a file named after its character, holding the directory it points at, in
`${XDG_STATE_HOME:-~/.local/state}/dirsesh/bookmarks`:

```console
$ ls ~/.local/state/dirsesh/bookmarks
c  m
$ cat ~/.local/state/dirsesh/bookmarks/m
/home/you/code/api
```

Each bookmark is written whole through a temp file, so an interrupted write leaves the previous
bookmark rather than half a file. Editing a bookmark's file by hand is fine; anything in the
directory whose name is not a single character valid in a file name (not `/` or `.`), or whose
contents are empty, is not a bookmark and is ignored.

`DIRSESH_BOOKMARKS_DIR` points at a different directory, which is what to set for a per-project
or per-machine set of bookmarks:

```bash
DIRSESH_BOOKMARKS_DIR=~/.config/work-bookmarks dirsesh bookmark-set m ~/work/api
```
