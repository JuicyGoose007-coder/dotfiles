# dotfiles

Arch Linux + [niri](https://github.com/YaLTeR/niri) (Wayland), themed Gruvbox
throughout. Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Fresh install

```sh
git clone git@github.com:JuicyGoose007-coder/dotfiles.git ~/dotfiles
~/dotfiles/bootstrap.sh
```

That installs every package, installs stow, and symlinks the configs into
`$HOME`. Log out and back in afterwards.

## Layout

Each top-level folder is a **stow package**. Inside it, the path is rebuilt as
`$HOME` sees it:

```
config/.config/niri/     ->  ~/.config/niri
shell/.zshrc             ->  ~/.zshrc
homescripts/scripts/     ->  ~/scripts
```

| Package | What it holds |
|---|---|
| `config` | everything under `~/.config` |
| `shell` | `.zshrc` |
| `homescripts` | `~/scripts` — standalone shell scripts |

To link them by hand:

```sh
stow --dir=$HOME/dotfiles --target=$HOME config shell homescripts
```

Add `--simulate --verbose=2` to preview without touching anything. Add
`--restow` to refresh after adding files, or `--delete` to unlink.

## What's in here

- **niri** — Wayland compositor config, split into `sections/`
- **noctalia** — shell/greeter theming
- **limine** — Gruvbox bootloader theme plus its install script
- **scripts/packages** — `pkglist.txt` (88 packages, repo and AUR together),
  with `install.sh` (bootstraps yay, then installs everything in one pass) and
  `update-lists.sh` to regenerate the list
- **starship, kitty, ghostty, yazi, superfile, lazygit, fastfetch, fuzzel** —
  prompt, terminals, file managers, launcher
- **gtk-3.0 / gtk-4.0 / qt5ct / qt6ct** — toolkit theming
- **mimeapps.list, user-dirs.dirs, xdg-terminals.list** — default apps and
  XDG paths

## Not in here

Browser and Discord profiles, `~/.config/gh` (holds a live auth token), binary
databases (`dconf`, `pulse`), and the Neovim config — that lives in its own
repo and is symlinked in from `~/Projects/nvim`.
