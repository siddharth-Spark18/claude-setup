#!/usr/bin/env bash
# Set up ~/.claude from this repo. Safe to re-run. Anything it would overwrite is moved to
# ~/.claude/backups/claude-setup-<timestamp>/ first, never deleted.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
mkdir -p "$CLAUDE_HOME"
echo "Installing into $CLAUDE_HOME"

echo "Symlinked (edits in ~/.claude land in this repo):"
link "$SRC/agents" "$CLAUDE_HOME/agents"
link "$SRC/evals"  "$CLAUDE_HOME/evals"
link "$SRC/notes"  "$CLAUDE_HOME/notes"
mkdir -p "$CLAUDE_HOME/skills"   # skills/ also holds Claude-managed dirs, so link per skill
for d in "$SRC"/skills/*/; do link "${d%/}" "$CLAUDE_HOME/skills/$(basename "$d")"; done

echo "Copied (run ./sync.sh to pull local changes back into the repo):"
# CLAUDE.md: repo copy + this machine's local-only section, if it already has one.
local_section=""
[ -f "$CLAUDE_HOME/CLAUDE.md" ] && local_section="$(extract_local_section "$CLAUDE_HOME/CLAUDE.md")"
new="$(mktemp)"; cp "$SRC/CLAUDE.md" "$new"
[ -n "$local_section" ] && { printf '\n%s\n' "$local_section" >> "$new"; echo "  kept this machine's '$LOCAL_ONLY_HEADING' section"; }
if [ -f "$CLAUDE_HOME/CLAUDE.md" ] && cmp -s "$new" "$CLAUDE_HOME/CLAUDE.md"; then echo "  ok      CLAUDE.md"
else [ -f "$CLAUDE_HOME/CLAUDE.md" ] && cp "$CLAUDE_HOME/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md.pre-install" && echo "  saved   old CLAUDE.md -> CLAUDE.md.pre-install"
     cp "$new" "$CLAUDE_HOME/CLAUDE.md"; echo "  wrote   CLAUDE.md"; fi
rm -f "$new"

# settings.json: overwrite only the portable keys; hooks/env/etc. on this machine are untouched.
python3 - "$SRC/settings.json" "$CLAUDE_HOME/settings.json" "$PORTABLE_SETTINGS_KEYS" "$BACKUP" <<'PY'
import json, os, shutil, sys
src, dst, keys, backup = sys.argv[1], sys.argv[2], sys.argv[3].split(), sys.argv[4]
repo = json.load(open(src))
local = json.load(open(dst)) if os.path.exists(dst) else {}
merged = dict(local); merged.update({k: repo[k] for k in keys if k in repo})
if merged == local: print("  ok      settings.json")
else:
    if os.path.exists(dst):
        os.makedirs(backup, exist_ok=True); shutil.copy(dst, os.path.join(backup, "settings.json"))
    json.dump(merged, open(dst, "w"), indent=2); open(dst, "a").write("\n")
    print("  merged  settings.json (portable keys: %s; other keys kept)" % ", ".join(keys))
PY
echo "Done. Restart Claude Code to pick up changes."
