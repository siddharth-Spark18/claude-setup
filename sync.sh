#!/usr/bin/env bash
# Pull local changes back into the repo working tree (does NOT commit or push).
#  - adopts any new, unmanaged skill dir in ~/.claude/skills (moves it into the repo, symlinks it back)
#  - refreshes repo CLAUDE.md (minus the local-only section) and settings.json (portable keys only)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

for d in "$CLAUDE_HOME"/skills/*/; do
  d="${d%/}"; name="$(basename "$d")"
  [ -L "$d" ] && continue; [ "$name" = synced ] && continue   # synced/ is Claude-managed
  [ -e "$SRC/skills/$name" ] && { echo "skip $name: already in repo, resolve by hand"; continue; }
  mv "$d" "$SRC/skills/$name"; ln -s "$SRC/skills/$name" "$d"; echo "adopted skill: $name"
done
for dir in agents evals notes; do   # these are whole-dir symlinks; warn if one got replaced by a real dir
  [ -L "$CLAUDE_HOME/$dir" ] || echo "WARNING: $CLAUDE_HOME/$dir is not a symlink; run ./install.sh"
done

strip_local_section "$CLAUDE_HOME/CLAUDE.md" > "$SRC/CLAUDE.md"
python3 - "$CLAUDE_HOME/settings.json" "$SRC/settings.json" "$PORTABLE_SETTINGS_KEYS" <<'PY'
import json, sys
local = json.load(open(sys.argv[1])); keys = sys.argv[3].split()
json.dump({k: local[k] for k in keys if k in local}, open(sys.argv[2], "w"), indent=2); open(sys.argv[2], "a").write("\n")
PY
find "$SRC" -name .DS_Store -delete
echo "Synced. Review and commit:"; git -C "$REPO" status --short
