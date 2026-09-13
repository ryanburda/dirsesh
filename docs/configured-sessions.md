# Configured Sessions

A session configuration is an executable program that calls `tmux` commands directly. There is
no DSL and no YAML abstraction, so anything tmux can do a configuration can do, and `man tmux`
is the reference for all of it.

Configurations live in `${XDG_CONFIG_HOME:-~/.config}/dirsesh/`. `dirsesh at` applies the one claiming
the directory you open; a tmux hook that [`dirsesh init`](#why-one-hook-dirsesh-init) installs runs its
`kill` when the session closes, however it closes.

## The contract

dirsesh runs your program with a verb and reads its answer. It never looks inside the file (it just
execs it), which is why a configuration can be written in any language, or be a compiled binary:

| Verb | Called when | What it should do |
| --- | --- | --- |
| `pattern` | resolving which configuration claims a directory | print an ERE of the directories it claims, on stdout |
| `name` | naming the session, before it exists | print the session name for the directory given as `$2`, on stdout |
| `start` | after `dirsesh at` has created the session | build the layout |
| `kill` | asynchronously, when the session closes ([`dirsesh init`](#why-one-hook-dirsesh-init)) | tear down what `start` built |

Three rules make it work in every language:

- **Only `pattern` and `name` treat stdout as an answer.** For `start` and `kill`, stdout is the
  [session log](#logging). A stray `echo` under `name` corrupts the name; under `start` it is
  just a log line.
- **A verb the program does not handle must exit 0.** A `case` with no matching branch falls
  through and exits clean, which is exactly right. Only `pattern` is really required.
- **Nothing a configuration answers can fail the session.** A `pattern` that fails or prints
  nothing simply does not match. A `name` that fails or prints nothing falls back to the
  default derivation. `kill` is best-effort: it runs after tmux has already closed the
  session, and nothing waits for it.

Environment: `ROOT` (the claimed directory) is set for `name`, `start` and `kill`, but not for
`pattern`, which is asked before a directory is settled on. `SESSION` (the session name) is set
for `start` and `kill`, but not for `name`, which is the verb that decides it.

## The configuration file

**The file must be executable.** `chmod +x` is what makes it a configuration; a file without
the bit is ignored, which keeps a stray README from being mistaken for one.

**The file's name, minus any extension, identifies the configuration** in logs and error
messages: `work`, `work.sh` and `work.py` are all the configuration `work`. Nesting works, and
the whole path identifies it:

```
~/.config/dirsesh/
  notes.sh                ->  configuration "notes"
  work/api.fish           ->  configuration "work/api"
  work/web.py             ->  configuration "work/web"
```

dirsesh owns the session's lifecycle: `dirsesh at` names the session, creates it and runs your `start`
in it, and a [`session-closed` hook](#why-one-hook-dirsesh-init) runs your `kill` after tmux closes
it. Everything beyond `pattern` is optional and describes what you want *beyond* a plain
session named after its directory. The smallest useful configuration:

```bash
#!/bin/bash
# ~/.config/dirsesh/notes.sh  ->  claims ~/notes, session named "notes"
case "$1" in
  pattern) printf '%s\n' "^$HOME/notes$" ;;
esac
```

**NOTE:** Session names cannot contain `.` or `:`. tmux reads both as target separators, so a
session named `my.project` would be created and then be unreachable. Derived names and `name`
answers are [sanitized](#naming-the-session) rather than refused; a name you give to `-name`
(typed directly, or at its prompt) is refused, since it is not dirsesh's to rewrite.

**NOTE:** The program runs once per verb, and dirsesh asks every configuration for its
`pattern`, so keep the top level cheap: anything expensive there is paid on every `dirsesh at`.

## Pane addressing

The session already exists when `start` runs, with one window holding one pane, rooted at
`ROOT`. Building a session means splitting that pane, creating windows, and sending commands
into the panes that result:

```bash
#!/bin/bash
case "$1" in
  pattern)
    printf '%s\n' "^$HOME/code/myproject$"
    ;;
  start)
    code=$(tmux display-message -p -t "$SESSION" '#{pane_id}')
    ai=$(tmux split-window -P -F '#{pane_id}' -h -l 35% -t "$code" -c "$ROOT")
    ;;
esac
```

Pane addressing is the thing that is easy to get wrong:

- `-P -F '#{pane_id}'` makes `split-window` and `new-window` print the id of the pane they
  created, so layouts are built by capturing ids and splitting off them. Positional targets
  like `"$SESSION:code.1"` shift as soon as a later split renumbers things; ids never do.
- `tmux display-message -p -t "$SESSION" '#{pane_id}'` is the way in: it prints the id of the
  one pane the session starts with. A pane id is also a valid `-t` for `rename-window`: it
  names the window the pane is in.
- Pass `-c "$ROOT"` to every `split-window` and `new-window`. Without it a new pane inherits
  the working directory of the pane it came from.

## Example: a useful default

A `code` window with your editor on the left and a coding agent on the right, plus a `terminal`
window:

```bash
#!/bin/bash
# ~/.config/dirsesh/myproject.sh   (chmod +x)

case "$1" in
  pattern)
    printf '%s\n' "^$HOME/projects/myproject$"
    ;;

  start)
    # code window with `nvim` on left and `ai` on right.
    code_window='code'
    nvim=$(tmux display-message -p -t "$SESSION" '#{pane_id}')
    tmux rename-window -t "$nvim" "$code_window"
    ai=$(tmux split-window -P -F '#{pane_id}' -h -l 35% -t "$nvim" -c "$ROOT")
    tmux send-keys -t "$nvim" 'nvim' Enter
    tmux send-keys -t "$ai" 'ai' Enter

    # terminal window
    tmux new-window -t "$SESSION" -n 'terminal' -c "$ROOT"

    # session starts focused on `nvim` in 'code' window
    tmux select-window -t "$SESSION:$code_window"
    tmux select-pane -t "$nvim"
    ;;
esac
```

## Example: starting and stopping services

A `kill` branch tears down what `start` brought up:

```bash
#!/bin/bash

case "$1" in
  pattern)
    printf '%s\n' "^$HOME/projects/myproject$"
    ;;

  start)
    # 'code' window: nvim on top 80%, a terminal below.
    code=$(tmux display-message -p -t "$SESSION" '#{pane_id}')
    tmux rename-window -t "$code" code
    tmux split-window -v -l 20% -t "$code" -c "$ROOT"   # a plain shell; no pane id needed
    tmux send-keys -t "$code" 'nvim' Enter

    # 'docker' window: docker compose on top, following its logs below.
    compose=$(tmux new-window -P -F '#{pane_id}' -t "$SESSION" -n docker -c "$ROOT")
    logs=$(tmux split-window -P -F '#{pane_id}' -v -l 50% -t "$compose" -c "$ROOT")
    tmux send-keys -t "$compose" 'docker compose up --force-recreate --detach' Enter
    tmux send-keys -t "$logs" 'docker compose logs -f' Enter
    tmux select-layout -t "$SESSION:docker" even-vertical

    tmux select-window -t "$SESSION:code"
    ;;

  # kill runs in the background after the session has closed, so the session
  # goes away immediately even when cleanup is slow.
  kill)
    docker compose --project-directory "$ROOT" down
    ;;
esac
```

## Writing a configuration in another language

The contract is argv in, stdout and exit status out. The same `notes` configuration in fish and
Python:

```fish
#!/usr/bin/env fish
# ~/.config/dirsesh/notes.fish   (chmod +x)

# Quoted so that no verb at all expands to one empty argument rather than zero.
set -l verb "$argv[1]"

switch "$verb"
    case pattern
        printf '%s\n' "^$HOME/notes$"

    case name
        printf '%s\n' notes

    case start
        set -l code (tmux display-message -p -t "$SESSION" '#{pane_id}')
        tmux rename-window -t "$code" notes
        tmux send-keys -t "$code" 'nvim .' Enter

    case '*'
        exit 0
end
```

```python
#!/usr/bin/env python3
# ~/.config/dirsesh/notes.py   (chmod +x)

import os
import subprocess
import sys

SESSION = os.environ.get("SESSION", "")
ROOT = os.environ.get("ROOT", "")


def tmux(*args):
    """stderr is deliberately not captured, so tmux's own complaints reach the
    session log. check=True makes any failure fail the verb."""
    return subprocess.run(
        ("tmux",) + args, check=True, stdout=subprocess.PIPE, text=True
    ).stdout.strip()


def pattern():
    print("^" + os.path.expanduser("~/notes") + "$")


def name(path):
    print("notes")


def start(path):
    code = tmux("display-message", "-p", "-t", SESSION, "#{pane_id}")
    tmux("rename-window", "-t", code, "notes")
    tmux("send-keys", "-t", code, "nvim .", "Enter")


VERBS = {"pattern": lambda _: pattern(), "name": name, "start": start}

if __name__ == "__main__":
    verb = sys.argv[1] if len(sys.argv) > 1 else ""
    path = sys.argv[2] if len(sys.argv) > 2 else ROOT
    VERBS.get(verb, lambda _: None)(path)
```

**NOTE:** A `pattern` is matched by dirsesh with `grep -E`, so it must be a POSIX extended regular
expression whatever language printed it. Python's `re`-only syntax (`\d`, lookahead, non-greedy
`*?`) will not work.

## Naming the session

A session is named after the directory it starts at: the sanitized basename, or `repo/worktree`
inside a git worktree. The `name` verb replaces that for every directory the configuration
claims:

```bash
  name)
    # The claimed directory arrives as $2, and as $ROOT.
    echo "work/$(basename "$2")"
    ;;
```

Only the first line of output is used, whitespace-trimmed. A configuration that does not handle
`name`, prints nothing, or fails gets the default derivation; a naming scheme with no opinion
about a particular directory is normal and should not wedge dirsesh. What it does print is
sanitized rather than refused (every character outside `[A-Za-z0-9_-/]` becomes `_`), since
names usually come from things the configuration does not control: `feature/v1.2` is a
reasonable thing to hand back, and it arrives as `feature/v1_2`.

Some useful `name` implementations:

```bash
  # Name worktree sessions after their branch. A branch can be checked out in
  # only one worktree at a time, so it is unique across the repository. (The
  # session keeps the name of the branch that was checked out when it started.)
  name)
    git -C "$2" branch --show-current 2>/dev/null
    ;;

  # Let a directory name itself; cat fails when there is no .dirsesh-name, which
  # is exactly the fallback contract.
  name)
    cat "$2/.dirsesh-name" 2>/dev/null
    ;;

  # Put a whole tree under one prefix. This is also how to make a recurring
  # collision stop: ~/work/api named work/api no longer collides with
  # ~/code/api's "api".
  name)
    echo "work/$(basename "$2")"
    ;;
```

**NOTE:** `-name` beats `name` either way. Given a name outright (`-name=code`), that name is
used as typed and `name` is never consulted. Given bare (`-name`), it prompts instead, offering
what `name` returned as the default, so pressing enter accepts it.

## Claiming directories

`pattern` is a [POSIX extended regular expression](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html#tag_09_04)
tested against the resolved directory, so one file can claim a whole tree ("every
repository under `~/code/work` gets this layout") without a file per repository.

The match is unanchored, so anchor it yourself when you mean it:

| pattern | claims |
| --- | --- |
| `^$HOME/code/work/[^/]+$` | the directories directly under `~/code/work`, nothing deeper |
| `^$HOME/code/work/` | everything beneath `~/code/work`, at any depth (not `~/code/work` itself) |
| `^$HOME/code/work/myproject$` | exactly one directory |

Being a regex rather than a glob is easy to forget. `~/code/*` matches nothing quoted (`~` does
not expand) and the wrong thing unquoted (`*` quantifies the `/`, also claiming `~/codegen`).
Use `$HOME` and anchor with `^`.

A directory no `pattern` claims gets a bare session and runs nothing.

### Precedence

Two patterns can claim the same directory, and only one configuration can name and build the
session. **The longest pattern wins.** Length is a proxy for specificity, and it is the length
of the *pattern*, not the text it matched, so a catch-all `.*`, which matches the entire path,
still loses to everything, being the shortest useful pattern there is:

```bash
#!/bin/bash
# ~/.config/dirsesh/default.sh   (chmod +x), a default for everything
case "$1" in
  pattern) printf '%s\n' ".*" ;;
esac
```

| Path | `^$HOME/code/work/[^/]+$` | `^$HOME/code/` | `.*` | Winner |
| --- | --- | --- | --- | --- |
| `~/code/work/repo` | 26 | 16 | 2 | `^$HOME/code/work/[^/]+$` |
| `~/code/scratch` | - | 16 | 2 | `^$HOME/code/` |
| `~/notes` | - | - | 2 | `.*` |

Two patterns of the same length tie-break by byte order (`LC_ALL=C`) on the file path, first
wins, which is deterministic and independent of your locale.

The configurations that lose are simply ignored. If a specific configuration should build on a
shared one, remember that configurations are ordinary executables: call the shared file
yourself. `SESSION` and `ROOT` are already in the environment, so it behaves exactly as if it
had claimed the directory itself:

```bash
  start)
    "$HOME/.config/dirsesh/work.sh" start                          # the shared layout first
    docker compose --project-directory "$ROOT" up --detach &       # then this project's services
    ;;

  kill)
    "$HOME/.config/dirsesh/work.sh" kill
    docker compose --project-directory "$ROOT" down
    ;;
```

**NOTE:** An empty `pattern` does not mean "match everything": it reads as declaring no
pattern, and the file is skipped. Print `.*`.

### Seeing the ranking (`dirsesh match`)

Precedence depends on every other file too, so it cannot be read off one file. `dirsesh match`
answers it for a directory (default: the current one):

```
$ dirsesh match ~/code/work/repo
26	/home/you/.config/dirsesh/work.sh
16	/home/you/.config/dirsesh/code.sh
2	/home/you/.config/dirsesh/default.sh
```

One `<score>\t<file>` per claiming configuration, best first. The first line is the
configuration that would name and build a session at that path. Nothing on stdout means
nothing claims the directory; that exits non-zero, so
`dirsesh match "$dir" >/dev/null` is a usable test.

It is also the fastest way to find a pattern that is not claiming what you think. For example,
`^$HOME/code/project/` has a trailing slash, so it claims everything *under* `~/code/project`
but not that directory itself.

## Beyond tmux commands

A configuration is a full program, so it is not limited to tmux panes and windows. Background
slow commands with `&` so they don't block startup; their output is captured in the
[log file](#logging):

```bash
  start)
    code=$(tmux display-message -p -t "$SESSION" '#{pane_id}')
    tmux send-keys -t "$code" 'nvim' Enter

    echo "$(date '+%Y-%m-%d %H:%M:%S'): Starting my webapp"
    docker compose --project-directory "$ROOT" up --build --force-recreate --detach &
    ;;

  kill)
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Stopping my webapp"
    docker compose --project-directory "$ROOT" down
    ;;
```

## Why one hook (`dirsesh init`)

Configurations are applied by `dirsesh at`, in the foreground, because you asked:

```bash
dirsesh at ~/code/myproject      # named, `start` run, switched to
```

Teardown is a tmux hook, installed once from `~/.tmux.conf`:

```bash
run-shell "dirsesh init"
```

(`dirsesh init` also installs the hooks that keep the [`bookmark status`](bookmark.md) line
current. They have nothing to do with configurations; one `init` line in `tmux.conf` is simply
all of dirsesh's setup.)

The asymmetry is the design, not an accident. **Creating a session has a natural opt-in point;
destroying one does not.** Something always asks for a session, and `dirsesh at` is that request.
A plain `tmux new-session` at a claimed directory is left alone, because it is a different
request and dirsesh has no business rewriting it. A session created via `dirsesh` should always be torn
down by `dirsesh`. This should happen regardless of how it is killed (via `tmux kill-session` or
from the last pane's shell exiting). There is no one command to hang cleanup off, so dirsesh hangs
it off the event instead.

### The hook is global but not universal

`session-closed` fires for every session tmux closes. Almost all of them stop at the first
check: was there a cleanup record for this session?

Only `dirsesh at` writes one, and only after a configuration's `start` has actually run. A session
dirsesh did not build (an unclaimed directory, `dirsesh at -noconfig`, a bare `tmux new-session`) has no
record, and closes exactly as it would on a server with no dirsesh on it. The hook is installed
globally; what it acts on is opt-in.

```bash
dirsesh at ~/code/myproject             # record written; `kill` runs when it closes
dirsesh at ~/code/myproject -noconfig   # no configuration applied, no record, no `kill`
tmux new-session -c ~/code/myproject    # an ordinary tmux session, start to finish
```

### Consequences worth knowing

- **The hook must be global, and `set-hook -g` clears the array.** If your `~/.tmux.conf` sets
  `session-closed` with a bare `set-hook -g`, put `run-shell "dirsesh init"` *after* it: dirsesh
  appends, so it is what a later `set-hook -g` would wipe. `dirsesh init` is idempotent and leaves
  other hooks on that event alone.
- **Without `dirsesh init`, `start` still runs and `kill` never does.** `dirsesh at` says so when it
  builds a session whose configuration it cannot arrange to clean up, and builds it anyway.
- **A session's options are gone by `session-closed`.** Neither `@dirsesh_path` nor the session
  environment can be read from that hook, which is why the record in
  `${XDG_STATE_HOME:-~/.local/state}/dirsesh/sessions/` holds the directory as well as marking the
  session.
- **The configuration is resolved again at close.** Editing a `pattern` between opening a
  session and closing it can change which configuration tears it down, or leave it with none.
- **`tmux kill-server` is not a reliable teardown.** tmux exits without closing its sessions
  one by one, so most of them never fire `session-closed`. Kill sessions, not the server, when
  `kill` matters. (`dirsesh init` reaps the records a dead server left behind.)
- **`dirsesh at` sizes the session to the client that is about to attach.** tmux creates a detached
  session at 80x24, so a `start` that splits by percentage would build the layout at the wrong
  size and drift when the client arrives.

## Logging

Output from `start` and `kill` is redirected to
`${XDG_STATE_HOME:-~/.local/state}/dirsesh/logs/<session-name>/dirsesh.log`. A session that matched no
configuration, or was created with `-noconfig`, runs no program and gets no log. They are ordinary
files: `tail -f` one, open it in an editor, or point a picker at the directory.

A `kill` that fails has nowhere to complain to -- the session is already gone -- so its log is
the place to look when cleanup does not happen.

**NOTE:** Each `dirsesh.log` is wiped on each start or kill, so it only holds the most recent
invocation's output.

**NOTE:** Output from multiple backgrounded processes may interleave. To avoid that, give each
its own file in the session's log directory:

```bash
docker compose up --detach > "$HOME/.local/state/dirsesh/logs/$SESSION/docker.log" 2>&1 &
pg_ctl start -l "$HOME/.local/state/dirsesh/logs/$SESSION/postgres.log" &
```
