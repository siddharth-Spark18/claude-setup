# claude-setup

My Claude Code workflow, kept in git so it's the same on every machine and can keep improving:
orchestration rules (`CLAUDE.md`), specialist agents, skills, eval cases, and portable settings.
No project data, transcripts, memory or credentials live here.

## Layout

| Path | What | How it reaches `~/.claude` |
|---|---|---|
| `claude/agents/` | Specialist subagents | symlink |
| `claude/skills/<name>/` | My own skills (not Claude-managed `skills/synced`) | symlink per skill |
| `claude/evals/` | Eval cases used by `/agent-retro` | symlink |
| `claude/notes/` | Design drafts | symlink |
| `claude/CLAUDE.md` | Global orchestration guide | copied |
| `claude/settings.json` | Portable keys only: `permissions`, `model`, `effortLevel`, `tui` | merged |

**Local-only on each machine (never committed):** `hooks` and any other `settings.json` keys, and the
`## AgentWatch Correlation` section of `CLAUDE.md`. Both are preserved across installs and stripped by `sync.sh`.

## New machine

```sh
git clone https://github.com/<you>/claude-setup.git ~/Projects/claude-setup
cd ~/Projects/claude-setup && ./install.sh
```

Anything `install.sh` would overwrite is moved to `~/.claude/backups/claude-setup-<timestamp>/`. Safe to re-run.

## Evolving it

Agents, evals, notes and skills are symlinked, so edits (including `/agent-retro`) land straight in this repo's working tree.
`CLAUDE.md` and `settings.json` are copies, so after changing them run:

```sh
./sync.sh        # pulls them back in; also adopts any newly created skill
git diff         # review
git commit -am "..." && git push
```

Adding a new portable settings key or a new local-only section: edit `PORTABLE_SETTINGS_KEYS` / `LOCAL_ONLY_HEADING` in `lib.sh`.
