# Workmux

Installed binary: `~/.local/bin/workmux` (v0.1.276).
Global settings: `~/.config/workmux/config.yaml`.
Claude Code and Codex lifecycle hooks are installed; start new agent sessions
after setup so they load the hooks. Existing hooks and notifications are retained.

## Daily workflow

Inside tmux, from a Git repository with at least one commit:

```sh
workmux add my-task -a codex
workmux add another-task -a claude
# Both agents sharing a single task worktree:
workmux add shared-task -l pair
```

The default layout has an agent and a shell. The pair layout has Claude and
Codex side by side. Separate worktrees isolate separate tasks; agents in the
pair layout share files and need coordinated edits.

`Ctrl-a A` opens the dashboard; `q` closes it. No sidebar is enabled.
Worktrees live beside each repository under `<repo>__worktrees/`.
Review before `workmux merge`. `merge_keep: true` keeps the worktree, branch,
and window after merging so you can inspect them before removing them.

## Config previews

From a Neovim task worktree:

```sh
nvim-preview .
# Or open a particular file in that preview:
nvim-preview . init.lua
```

The config is linked into a private XDG config directory. Plugin installations,
state, and cache are separate for each worktree, under
`~/.local/share/config-previews/`. First launch installs preview plugins.
This separates application config/state; plugins and external commands can
still perform their normal filesystem actions.

From a dotfiles task worktree:

```sh
tmux-preview .
```

This launches an independent tmux server. The generated config loads themes
from that worktree, excludes resurrect/continuum plugin loading, and binds
`Ctrl-a r` to regenerate and reload the preview. Detach with `Ctrl-a d`.
Exit its shells to stop the preview server. Generated configs are stored under
`~/.cache/config-previews/`.

Neither launcher repoints the live configuration symlinks. Merge reviewed
changes into the live checkout, then restart/reload the application.

## File manager first run

`~/Projects/rust/fm` currently has an unborn `master` branch (no commits).
Review its `.gitignore` and initial files, then create the initial commit before
running `workmux add`. Build each worktree separately; do not share Rust's
`target/` directory. The existing `sfm` symlink points at the original checkout's
release binary; use `cargo run` in the task worktree to test that task's version.
