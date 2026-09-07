# dotfiles

Arch Linux + [niri](https://github.com/YaLTeR/niri) (Wayland), themed Gruvbox
throughout. Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Fresh install

Start from a working base Arch install with a network connection and your user
account with `sudo`. Then, top to bottom:

```sh
# Arch's `base` does not ship git, and a new machine has no SSH key yet,
# so this first clone has to be HTTPS.
sudo pacman -Sy git
git clone https://github.com/JuicyGoose007-coder/dotfiles.git ~/dotfiles

# packages, stow, symlinks, login shell
~/dotfiles/bootstrap.sh

# /etc, services and the UKI. Needs root, prompts before overwriting.
~/dotfiles/system/restore.sh

# Neovim lives in its own repo and is not installed by bootstrap.sh
git clone https://github.com/JuicyGoose007-coder/minimal-nvim.git ~/Projects/nvim
ln -s ~/Projects/nvim ~/.config/nvim

reboot
```

Reboot rather than just logging out: `restore.sh` rebuilds the boot image and
enables `greetd`.

Once you have added an SSH key to GitHub, switch the remotes over so you can
push:

```sh
git -C ~/dotfiles remote set-url origin git@github.com:JuicyGoose007-coder/dotfiles.git
git -C ~/Projects/nvim remote set-url origin git@github.com:JuicyGoose007-coder/minimal-nvim.git
```

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

`system/` is **not** a stow package — it holds the parts that live outside
`$HOME` and need root. Apply it with `system/restore.sh`, which copies into
`/etc`, enables the services in `services-enabled.txt`, and rebuilds the UKI.

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
- **scripts/packages** — `pkglist.txt` (93 packages, repo and AUR together),
  with `install.sh` (bootstraps yay, then installs everything in one pass) and
  `update-lists.sh` to regenerate the list
- **starship, kitty, ghostty, tmux, yazi, lazygit, fastfetch, fuzzel** —
  prompt, terminals, multiplexer, file manager, launcher
- **gtk-3.0 / gtk-4.0 / qt5ct / qt6ct** — toolkit theming
- **mimeapps.list, user-dirs.dirs, xdg-terminals.list** — default apps and
  XDG paths

## System config (`system/`)

Captured because a package list alone cannot rebuild these:

- `etc/greetd/config.toml` + `etc/pam.d/greetd` — the login screen, pointed at
  `noctalia-greeter-session`. Stock greetd would not launch it.
- `etc/mkinitcpio.conf` + `etc/mkinitcpio.d/linux.preset` — this machine boots a
  UKI (kernel and initramfs fused into one `.efi`), which the preset defines.
- `etc/pacman.d/hooks/99-limine.hook` — redeploys Limine after every upgrade.
- `etc/systemd/zram-generator.conf` — zstd-compressed zram swap.
- `etc/vconsole.conf`, `etc/locale.conf`, `etc/hostname`
- `services-enabled.txt` — `greetd`, `NetworkManager`, `fstrim.timer` and the
  pipewire user units. Installing a package does not enable it.

## Not in here

Browser and Discord profiles, `~/.config/gh` (holds a live auth token), binary
databases (`dconf`, `pulse`), and the Neovim config — that lives in its own
repo and is symlinked in from `~/Projects/nvim`.
