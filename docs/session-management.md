# Session Management

`dirsesh at` creates tmux sessions. That's its whole job.

Switching between sessions and killing them are different jobs, and they have been solved a
thousand times over — by tmux's own `choose-tree`, by sessionx, by fzf one-liners people have
carried in their `tmux.conf` for years. If you already have something you like for that, keep
using it. `dirsesh at` is happy to sit next to it; nothing in it assumes it is the only thing
touching your sessions.

`switch`, `last`, `kill` and `logs` are for the other case. If you would rather `dirsesh` be
your session manager and not just the half that creates them, it ships the other half too. Like
the [pickers](pickers.md), none of them is wired into `dirsesh at`: they are something you bind,
one key at a time.

## Dependencies

- [`fzf`](https://github.com/junegunn/fzf)

## Usage

```bash
dirsesh switch [session]                # Switch to another running session
  session                               # Switch straight to this one instead of picking
dirsesh last                            # Switch back to the session you came from
dirsesh kill [session]                  # Kill a running session
  session                               # Kill this one instead of picking
dirsesh logs [session]                  # Browse the logs a dirsesh configuration wrote
  session                               # Browse only this session's logs
```

Each command documents itself. `-help` prints what it lists, how it behaves at the edges, and
anything worth knowing before you bind it to a key:

```bash
dirsesh logs -help
dirsesh switch -help
```

That is where the per-command detail lives, so it cannot drift from the scripts the way a second
copy in this file would.

### `switch` and `kill`

Both show a picker of the running sessions, and both take a session name to skip the picker and
act straight away. Sessions are listed by `#{session_name}` rather than cut out of `tmux ls`, so
a name with a colon in it survives.

The two differ in what they offer. `switch` drops the session you are on — it is not a
destination — and names it in the header instead, so the list is only the places you can go.
`kill` lists every session, the current one included: killing the session you are sitting in is
a thing you may well mean to do.

### `last`

Switches back to where you came from, with a fallback ladder rather than a hard failure:

1. The last session, if it is still around.
2. The only other session, if there are exactly two.
3. Otherwise a popup with the `switch` picker.

That last step is what makes it worth a single key: it always does something, whether or not
tmux still remembers a last session.

### `logs`

`dirsesh` writes a configuration's `start` and `kill` output to
`$XDG_STATE_HOME/dirsesh/logs/<session>/dirsesh.log`, and a configuration may write more files
of its own beside it. See [Configured Sessions](configured-sessions.md) for what puts them
there.

They are ordinary files, so this picks one and tails it; `tail` or an editor does just as well.
The sessions it offers are the ones that have logs, which are not always sessions that are still
running.

## Binding them

```tmux
# ~/.config/tmux/tmux.conf

bind-key \; run-shell -b "dirsesh last"
bind-key s popup -E "dirsesh switch"
bind-key k popup -E "dirsesh kill"
bind-key l new-window -n dirsesh-logs "dirsesh logs"
```

These are shell commands, not tmux commands: what `popup -E` and `run-shell` run above is a
shell, and the same string works in either place. There is nothing to type at tmux's own command
prompt.

`last` on `;` is the one that earns its key fastest: it is the bounce between two sessions that
most switching actually is.
