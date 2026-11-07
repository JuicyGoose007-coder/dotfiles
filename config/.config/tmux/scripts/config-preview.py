#!/usr/bin/env python3
"""Launch a worktree config without repointing the live configuration symlinks."""
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys


def main():
    kind = Path(sys.argv[0]).name
    if kind not in ("nvim-preview", "tmux-preview"):
        raise SystemExit("Invoke as nvim-preview or tmux-preview")
    args = sys.argv[1:]
    reload_only = "--reload" in args
    if reload_only:
        args.remove("--reload")
    root = Path(args.pop(0) if args else ".").expanduser().resolve()
    identity = hashlib.sha256(str(root).encode()).hexdigest()[:12]
    env = os.environ.copy()

    if kind == "nvim-preview":
        if not (root / "init.lua").is_file():
            raise SystemExit("Pass the Neovim worktree root containing init.lua")
        base = Path(env.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "config-previews" / identity
        for name in ("config", "data", "state", "cache"):
            (base / name).mkdir(parents=True, exist_ok=True)
            env[f"XDG_{name.upper()}_HOME"] = str(base / name)
        link = base / "config/nvim-preview"
        if not link.is_symlink():
            link.symlink_to(root, target_is_directory=True)
        env["NVIM_APPNAME"] = "nvim-preview"
        os.execvpe("nvim", ["nvim", *args], env)

    if (root / "config/.config/tmux/tmux.conf").is_file():
        root = root / "config/.config/tmux"
    source = root / "tmux.conf"
    if not source.is_file():
        raise SystemExit("Pass a dotfiles worktree root or its tmux config directory")
    # Derive identity from the normalized tmux directory for reload consistency.
    identity = hashlib.sha256(str(root).encode()).hexdigest()[:12]
    socket = "config-preview-" + identity
    base = Path(env.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "config-previews" / identity
    base.mkdir(parents=True, exist_ok=True)
    preview = base / "tmux.conf"
    lines = []
    for line in source.read_text().splitlines():
        if line.startswith("run-shell ") and ("resurrect" in line or "continuum" in line):
            continue
        if line.startswith("bind-key -N \"Reload config\""):
            continue
        line = line.replace("$HOME/.config/tmux", str(root)).replace("~/.config/tmux", str(root))
        lines.append(line)
    # Invoke through the installed symlink so argv[0] selects tmux mode.
    command = shlex.join([str(Path.home() / ".local/bin/tmux-preview"), "--reload", str(root)])
    lines.extend([
        "set -g @continuum-restore off",
        "set -g @continuum-save-interval 0",
        "bind-key -N \"Reload preview config\" r run-shell " + json.dumps(command),
    ])
    preview.write_text("\n".join(lines) + "\n")
    env.pop("TMUX", None)
    tmux = ["tmux", "-L", socket]
    if reload_only:
        subprocess.run([*tmux, "source-file", str(preview)], env=env, check=True)
        return
    if args:
        raise SystemExit("tmux-preview accepts only a config directory")
    os.execvpe("tmux", [*tmux, "-f", str(preview), "new-session", "-A", "-s", "preview", "-c", str(root)], env)


if __name__ == "__main__":
    main()
