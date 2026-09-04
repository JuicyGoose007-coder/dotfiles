# niri setup notes

## xwayland-satellite is PINNED to 0.8.1 — do not upgrade blindly

**Date:** 2026-09-01

**Symptom if this pin is lost:** Steam's menu-bar popups (Steam / View / Friends /
Games / Help) appear for one frame and vanish. Steam only; native Wayland apps are
fine.

**Cause:** xwayland-satellite 0.8.2 (upstream commit `3273a0f`) broke X11
override-redirect popups. Steam draws those menus with its CEF web UI, so they go
through this bridge.

**Fix:** stay on 0.8.1-2, pinned via `IgnorePkg` in `/etc/pacman.conf`.

**Upstream:**
- https://github.com/Supreeeme/xwayland-satellite/issues/468 (open — 0.8.2 broke
  dropdowns, 0.8.1 last good)
- https://github.com/Supreeeme/xwayland-satellite/issues/435 (closed — same symptom,
  CachyOS + niri)

**When to un-pin:** after #468 is fixed, or a release newer than 0.8.2 appears.
Remove the `IgnorePkg` line, then `sudo pacman -S xwayland-satellite`.

### IMPORTANT: how to test a version change

niri spawns the bridge **once per session** and keeps that process alive. Replacing
the binary on disk does NOT affect the running process. You must **log out and back
in**, or you are still testing the old version. This cost hours of debugging once
already — a downgrade looked like it "didn't work" when it had simply never loaded.

Check which one is actually running:

    ps -eo pid,lstart,args | grep '[x]wayland-satellite'

Its start time must be *after* the package change.

## Config layout

`config.kdl` is only a list of includes. Real settings live in `sections/`.
All included files are watched, so editing any of them live-reloads niri — no
restart. Include **order matters**: window-rule / output / workspace entries stack in
order, and `noctalia.kdl` must stay last so its theme colors win.
