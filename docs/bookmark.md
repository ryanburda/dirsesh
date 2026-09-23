# Bookmarks

The `dirsesh bm*` commands map a character to a directory, the way vim marks do, and open a
tmux session there.

```bash
dirsesh bm-set m ~/code/api      # m is now ~/code/api
dirsesh bm m                     # a session at ~/code/api
dirsesh bm                       # ...or at one you choose from the list
```

Bookmarks are for the handful of directories you return to constantly. There is no ranking,
no history and no decay: `m` points where you put it until you put it somewhere else. That
is the difference between this and the [fuzzy pickers](pickers.md) beside it, and the reason
both are worth having.

`bm` is `dirsesh at` with the path filled in, so everything
[`at`](../README.md#session-creation) does still happens: a bookmark whose directory already has
a session switches to it rather than opening a second one, and a
[configuration](configured-sessions.md) claiming that directory still builds the session.

A bookmark is a file holding a directory, so the store is readable without any of this:

| instead of | you would write |
| --- | --- |
| `dirsesh bm m` | `dirsesh at "$(cat ~/.local/state/dirsesh/bookmarks/m)"` |
| `dirsesh bm-set m` | `pwd > ~/.local/state/dirsesh/bookmarks/m` |
| `dirsesh bm-rm m` | `rm ~/.local/state/dirsesh/bookmarks/m` |

Those are the shape rather than the equivalent — what you would be hand-rolling is the character
validation, the atomic write, the fzf list, the status line, and backing out of a tmux prompt
without setting anything. See [Storage](#storage) for the format itself.

## Dependencies

- [`fzf`](https://github.com/junegunn/fzf), for `bm` without a character
- `tmux`, for `bm-status` and `bm-status-init`

Everything else runs with a shell and `awk`.

## Usage

```bash
dirsesh bm [char] [-p]         # Open a session at a bookmark
  char                         # The character the bookmark is keyed by; chooses one with fzf when left off
  -p                           # Print every bookmark as "char<TAB>directory" instead
dirsesh bm-set <char> [path]   # Bookmark a directory (path defaults to the current directory)
dirsesh bm-rm <char>           # Remove a bookmark
dirsesh bm-status [path]       # Bookmarks with a tmux session open at them, for a status line
dirsesh bm-status-init         # Install the tmux hooks `bm-status` needs (put this in tmux.conf)
```

`dirsesh bm -help`, and `bm-<command> -help`, print the same thing — they are one program and
share one `-help`.

### Setting and removing

```bash
dirsesh bm-set m                 # bookmark the current directory at m
dirsesh bm-set m ~/code/api      # ...or one you name
dirsesh bm-rm m
```

A bookmark is keyed by a single printable ASCII character — any of `!` through `~` except `/`
and `.`, which can't name the file a bookmark is stored in — so digits and punctuation work as
well as letters, and upper and lower case are two different bookmarks. Setting a character that
is already set replaces it, no confirmation, the same way `m` does in vim. The path is resolved
to an absolute one with symlinks followed, so a bookmark keeps pointing at the same directory
whatever you were standing in when you set it.

### Going to one

`dirsesh bm m` opens a session at whatever `m` bookmarks. It exits non-zero and opens nothing if
the character is not bookmarked, so a typo says so rather than sending you somewhere.

`dirsesh bm` with no character opens the bookmarks in fzf, and starts a session at the one you
choose. `ctrl-x` removes the bookmark under the cursor and rebuilds the list, which is how a
bookmark you have stopped using gets cleaned up without having to remember which character it
was.

Backing out of that list opens nothing and exits 0.

### Listing them

`bm -p` is the one bookmark command that prints rather than opens: the whole store, one
`char<TAB>directory` line at a time, sorted by character — for scripts, and for looking at:

```console
$ dirsesh bm -p
c	/home/you/.config
m	/home/you/code/api
n	/home/you/.config/nvim
```

It is also the way to hand a bookmark to something that is not `dirsesh`:

```bash
cd "$(dirsesh bm -p | awk -F'\t' '$1 == "m" { print $2 }')"
```

### Status line (`bm-status`)

Prints the characters of the bookmarks that have a **tmux session open** at their directory, the
current session's styled differently. Bookmarks with nothing open are left out, so the line stays
short and reads as "where can I already jump to":

```tmux
set -g status-right "#(dirsesh bm-status '#{session_path}')"
```

Two flags set the styles, written without their `#[]` wrapper: `-s`/`--style` for the other open
sessions (default `dim`) and `-c`/`--current-style` for the current one (default
`fg=yellow,bold`):

```tmux
set -g status-right "#(dirsesh bm-status '#{session_path}' -s 'fg=colour244' -c 'fg=black,bg=blue,bold')"
```

The path argument matters: tmux runs a `#()` command without a client and shares one run's
output between all of them, so `bm-status` cannot ask which session is current and get a
per-client answer. Passing `#{session_path}` is what makes the highlight follow each client.

A status line is only redrawn every `status-interval` seconds, so a session opened or killed
elsewhere would take that long to appear. Two tmux hooks make it immediate, on every attached
client, and `dirsesh init` installs them — so a `tmux.conf` that already has

```tmux
run-shell "dirsesh init"
```

needs nothing further. `bm-status-init` installs those two on their own, without the session
cleanup hook that comes with them:

```tmux
run-shell "dirsesh bm-status-init"
```

Either way it hangs a refresh off `session-created` and `session-closed`, appending to both so
anything else on them survives — `dirsesh init`'s own `session-closed` hook included — and
dropping the hooks a previous run left behind so re-sourcing `tmux.conf` does not stack
duplicates. The hooks are only needed for the status line; nothing else in `bm*` goes through
one. Setting and removing a bookmark refresh the line on their own.

> **NOTE:** if your `tmux.conf` sets `session-created` or `session-closed` with a bare
> `set-hook -g`, put `run-shell "dirsesh init"` after it — a later `set-hook -g` clears what
> it appended.

## tmux keybindings

These are shell commands, not tmux commands, so there is nothing to type at tmux's own command
prompt. Bind them instead — and where a character is wanted, let the binding ask for it.

`bm`, `bm-set` and `bm-rm` take that character as an argument and have no keypress prompt of
their own. `command-prompt -1` is what asks, and it reaches all three with a single keypress:

```tmux
bind-key m  command-prompt -1 -p "Set bookmark:"    "run-shell -b \"dirsesh bm-set '%%%'\""
bind-key M  command-prompt -1 -p "Remove bookmark:" "run-shell -b \"dirsesh bm-rm '%%%'\""
bind-key \' command-prompt -1 -p "Go to bookmark:"  "run-shell -b \"dirsesh bm '%%%'\""
bind-key b  popup -E 'dirsesh bm'
```

`-1` takes exactly one key and `%%%` substitutes it with quotation marks escaped, so these ask
in tmux's status line and need no popup. `'` and `;` are the two keys that cannot be answered
with — `;` is tmux's own command separator — so do not bookmark at those.

Escape backs out of the prompt. `-1` hands back whatever key was pressed, escape included, so
backing out reaches `bm`, `bm-set` and `bm-rm` as a character no bookmark can be keyed by: they
take it for what it is, do nothing and exit 0. Nothing is set, removed or opened, and no error
is shown.

The last binding needs no prompt at all: `dirsesh bm` with no character opens the fzf list, and
a popup is where that belongs.

`bm-set` bound this way bookmarks the directory the *session* is rooted at. To bookmark the
current pane's directory instead:

```tmux
bind-key m command-prompt -1 -p "Set bookmark:" "run-shell -b \"dirsesh bm-set '%%%' '#{pane_current_path}'\""
```

As with the pickers, a bookmark is worth binding twice — once in `tmux.conf` for when tmux is
running, and once in your shell for when no tmux server is:

```zsh
# ~/.zshrc

alias b='dirsesh bm'
```

> **Troubleshooting:** tmux's `run-shell` and `popup -E` run in a non-interactive, non-login
> shell, so `dirsesh` must be on PATH when that shell starts.
>
> - **zsh:** put your PATH setup in `~/.zshenv` (not `.zshrc`).
> - **bash:** set `BASH_ENV` to a file that configures your PATH, or use `/etc/environment`.
>
> Fallback: use the full path in the bindings, e.g.
> `run-shell -b "~/.local/share/dirsesh/dirsesh bm-set '%%%'"`.

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
DIRSESH_BOOKMARKS_DIR=~/.config/work-bookmarks dirsesh bm-set m ~/work/api
```
