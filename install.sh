#!/bin/sh
# Install dirsesh: symlink `dirsesh` into a directory on PATH.
#
#   curl -fsSL https://raw.githubusercontent.com/ryanburda/dirsesh/main/install.sh | sh
#
# Environment overrides:
#   DIRSESH_HOME  where the repo is cloned  (default: ~/.local/share/dirsesh)
#   BIN_DIR       where symlinks are placed (default: ~/.local/bin)

set -eu

REPO_URL=https://github.com/ryanburda/dirsesh.git
DEFAULT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/dirsesh"
DIRSESH_HOME=${DIRSESH_HOME:-"$DEFAULT_HOME"}
BIN_DIR=${BIN_DIR:-"$HOME/.local/bin"}

# The project was named tmux-dirsesh until it was renamed to dirsesh, and the
# default checkout location moved with it.
LEGACY_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/tmux-dirsesh"
LEGACY_REPO_URL=https://github.com/ryanburda/tmux-dirsesh.git

die() {
    echo "install.sh: $*" >&2
    exit 1
}

command -v git > /dev/null 2>&1 || die "git is required but was not found on PATH"
command -v tmux > /dev/null 2>&1 || die "tmux is required but was not found on PATH"

# A checkout made before the rename is still a good checkout: move it to the
# new default rather than let a second clone land beside it and orphan the
# first. Only when the default is where we are headed -- a DIRSESH_HOME given
# on the command line is an answer, not a guess to be corrected.
if [ "$DIRSESH_HOME" = "$DEFAULT_HOME" ] && [ ! -e "$DIRSESH_HOME" ] \
    && [ -d "$LEGACY_HOME/.git" ]; then
    echo "Moving $LEGACY_HOME to $DIRSESH_HOME (tmux-dirsesh was renamed to dirsesh)"
    mkdir -p "$(dirname "$DIRSESH_HOME")"
    mv "$LEGACY_HOME" "$DIRSESH_HOME"

    # GitHub redirects the old URL to the new one, so this is tidiness rather
    # than repair -- and it is skipped for a remote pointing anywhere else,
    # which is someone's fork and none of this script's business.
    if [ "$(git -C "$DIRSESH_HOME" remote get-url origin 2>/dev/null)" = "$LEGACY_REPO_URL" ]; then
        git -C "$DIRSESH_HOME" remote set-url origin "$REPO_URL"
    fi
fi

# Fetch (or update) the source checkout that the symlink points at.
if [ -d "$DIRSESH_HOME/.git" ]; then
    echo "Updating existing checkout at $DIRSESH_HOME"
    git -C "$DIRSESH_HOME" fetch --quiet origin
    git -C "$DIRSESH_HOME" reset --quiet --hard origin/HEAD
elif [ -e "$DIRSESH_HOME" ]; then
    die "$DIRSESH_HOME exists but is not a git checkout; move it aside and retry"
else
    echo "Cloning $REPO_URL into $DIRSESH_HOME"
    mkdir -p "$(dirname "$DIRSESH_HOME")"
    git clone --quiet "$REPO_URL" "$DIRSESH_HOME"
fi

mkdir -p "$BIN_DIR"

# Only `dirsesh` is linked: every subcommand runs a script under src/, which
# it finds relative to itself with the symlink resolved.
src="$DIRSESH_HOME/dirsesh"
dest="$BIN_DIR/dirsesh"

[ -f "$src" ] || die "expected $src to exist"

if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    die "$dest exists and is not a symlink; remove it and retry"
fi

chmod +x "$src"
ln -sfn "$src" "$dest"
echo "Linked $dest -> $src"

# An earlier layout had a dirsesh-extras program of its own; its commands are
# `dirsesh` subcommands now, so a link left over from then points at nothing.
if [ -L "$BIN_DIR/dirsesh-extras" ]; then
    rm -f "$BIN_DIR/dirsesh-extras"
    echo "Removed $BIN_DIR/dirsesh-extras (now 'dirsesh' subcommands)"
fi

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo
        echo "install.sh: warning: $BIN_DIR is not on your PATH."
        echo "Add this to your shell profile (e.g. ~/.zshrc) and restart your shell:"
        echo
        echo "    export PATH=\"$BIN_DIR:\$PATH\""
        ;;
esac

echo
echo "Done. Run 'dirsesh help' to see its usage."
echo
echo "Shell completions are not installed by this script; see the Shell Completions"
echo "section of $DIRSESH_HOME/README.md for the one-liner for your shell."
