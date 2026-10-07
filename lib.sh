# Shared helpers for install.sh / sync.sh. Sourced, not executed.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SRC="$REPO/claude"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$CLAUDE_HOME/backups/claude-setup-$STAMP"

# Settings keys that are portable across machines. Everything else (hooks, env, ...) stays local.
PORTABLE_SETTINGS_KEYS="permissions model effortLevel tui"
# CLAUDE.md section that stays local to each machine (from its heading to the next "## " or EOF).
LOCAL_ONLY_HEADING="## AgentWatch Correlation"

backup() { # move a path into the backup dir instead of deleting it
  mkdir -p "$BACKUP"; mv "$1" "$BACKUP/$(basename "$1")"; echo "  backed up $1 -> $BACKUP/"
}

link() { # link <src> <dst>: make dst a symlink to src, backing up whatever was there
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then echo "  ok      $dst"; return; fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then backup "$dst"; fi
  mkdir -p "$(dirname "$dst")"; ln -s "$src" "$dst"; echo "  linked  $dst -> $src"
}

# Print a CLAUDE.md with the local-only section removed.
strip_local_section() {
  awk -v h="$LOCAL_ONLY_HEADING" 'index($0,h)==1{skip=1;next} skip && /^## /{skip=0} !skip' "$1" \
    | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}
# Print only the local-only section (empty if absent).
extract_local_section() {
  awk -v h="$LOCAL_ONLY_HEADING" 'index($0,h)==1{p=1} p && index($0,h)!=1 && /^## /{p=0} p' "$1"
}
