# Migration Notes: Ubuntu dotfiles → NixOS (WSL)

This document is the full record of the migration: what moved, where it went,
what was dropped on purpose, and what gaps existed in the *original* config
that got fixed along the way. Read this before you `nixos-rebuild switch`.

## Files that were migrated

| Original file      | What it configured        | Where it went in Nix |
|---------------------|---------------------------|------------------------|
| `config.fish`       | fish shell                | `home.nix` → `programs.fish` |
| `config.kdl`        | zellij global config      | `home.nix` → `programs.zellij.settings` + `extraConfig` |
| `dev.kdl`           | zellij layout             | `home.nix` → `programs.zellij.layouts.dev` |
| `yazi.toml`         | yazi manager/preview/opener | `yazi/yazi.toml` (imported via `lib.importTOML`) |
| `keymap.toml`       | yazi keybinds              | `yazi/keymap.toml` (imported via `lib.importTOML`) |
| `theme.toml`        | yazi cwd color + status separators | `yazi/theme.toml` (imported via `lib.importTOML`) |
| `package.toml`      | yazi plugin dependencies   | `home.nix` → `programs.yazi.plugins` (now uses nixpkgs `yaziPlugins`) |
| `alacritty.toml`    | terminal emulator          | **Not migrated** — see below |
| `config.toml` / `languages.toml` (top-level, duplicates) | helix | Already identical to `nixos/helix/*.toml` in your original zip — untouched |

## Why zellij's config lives inside `home.nix` as Nix strings, not as separate `.kdl` files

Two different, equally valid patterns exist in the Nix ecosystem for "external
tool config that Nix needs to place":

1. Keep the config as a plain file next to the flake, and `xdg.configFile.source`
   it in (or `lib.importTOML` it, for TOML). This is what I did for yazi and
   helix, because those files are large, config as data, and worth being able
   to open/diff independently of Nix syntax.
2. Inline the config as a Nix multi-line string directly in `home.nix`, using
   the module's structured options (`programs.zellij.settings`) where
   possible, and `extraConfig`/`layouts.<name>` for anything that needs to
   stay verbatim KDL.

I used approach 2 for zellij specifically because:

- `programs.zellij.settings` is a genuine typed Nix option — most of your
  `config.kdl` (theme, default_shell, mouse_mode, plugins block, etc.) maps
  onto it directly, and doing so means a typo like `moose_mode` would fail
  fast at `nixos-rebuild switch` time instead of silently doing nothing.
- Your `keybinds` block starts with `clear-defaults=true`, which is
  KDL-specific syntax the structured `settings` option doesn't model. That
  one block is passed through `extraConfig` **byte-for-byte** — nothing about
  your keybindings changed.
- Your `dev.kdl` layout is short enough that inlining it via
  `programs.zellij.layouts.dev` means there's exactly one copy of it, in one
  file, instead of a `.kdl` file that could silently drift out of sync with
  what `home.nix` actually applies. Home Manager writes it out to
  `$XDG_CONFIG_HOME/zellij/layouts/dev.kdl` at activation time — the same
  path your fish `dev` function already expected.

Net effect: identical runtime behavior, fewer files, and Nix now actually
validates the parts of the config it can validate.

## Fish: line-by-line accounting

Every active line in your original `config.fish` landed somewhere:

| Original | New location |
|---|---|
| `fish_add_path $HOME/.npm-global/bin` | `home.sessionPath` |
| `fish_add_path $HOME/.local/bin` | `home.sessionPath` |
| `fish_add_path $HOME/.tmuxifier/bin` | `home.sessionPath` |
| `set -gx BUN_INSTALL $HOME/.bun` | `home.sessionVariables.BUN_INSTALL` |
| `set -gx GOPATH $HOME/.go` | `home.sessionVariables.GOPATH` |
| `fish_add_path $GOPATH/bin` | `home.sessionPath` (`$HOME/.go/bin`, since `sessionPath` is set before `GOPATH` would be available as a fish variable) |
| `alias glog=...` | `programs.fish.shellAliases.glog` |
| `alias reload=...` | `programs.fish.shellAliases.reload` |
| `alias zjl=...` | `programs.fish.shellAliases.zjl` |
| `alias zja=...` | `programs.fish.shellAliases.zja` |
| `function mkcd` | `programs.fish.functions.mkcd` (body unchanged) |
| `function gfile` | `programs.fish.functions.gfile` (body unchanged) |
| `function y` | `programs.fish.functions.y` (body unchanged) |
| `function dev` | `programs.fish.functions.dev` (body unchanged, path updated to `${config.xdg.configHome}` so it always matches wherever Home Manager actually writes the layout) |
| `zoxide init fish \| source` + `alias cd='z'` | **Removed entirely** — you asked to drop zoxide during this migration |
| `fzf --fish \| source` | `programs.fzf.enableFishIntegration = true` — generates the identical init line, but Home Manager now owns both installing `fzf` *and* wiring it up, instead of splitting that across two files |

`home.sessionVariables` and `home.sessionPath` are Home Manager's
shell-agnostic mechanisms for exactly this kind of thing — they get exported
correctly regardless of shell, which matters less here since you're
fish-only, but it's the idiomatic option and costs nothing.

## Yazi: what changed vs. what's verbatim

- `yazi.toml`, `keymap.toml`, `theme.toml`: **byte-for-byte unchanged**, just
  moved into `yazi/` and loaded with `lib.importTOML`. Nothing in these was
  edited, added, or removed.
- `package.toml`: this declared two plugin dependencies, each pinned to a
  specific rev with a hash:
  - `yazi-rs/plugins:git` → replaced with `pkgs.yaziPlugins.git`
  - `yazi-rs/plugins:jump-to-char` → replaced with `pkgs.yaziPlugins."jump-to-char"`

  Both plugins are now packaged directly in nixpkgs, so the manual
  rev/hash pinning your old `package.toml` did by hand is no longer
  necessary — nixpkgs' maintainers keep these updated, and they'll move
  in lockstep with whatever nixpkgs revision your flake is pinned to.

### A pre-existing gap I did *not* silently fix

Your old `keymap.toml` never actually bound a key to the `git` or
`jump-to-char` plugins, and there's no `init.lua` wiring them into yazi's
linemode display either. In other words: on your old Ubuntu box, these two
plugins were *declared* as dependencies but not *wired up* to anything you'd
actually notice day-to-day (no keybind, no visible git status column). That
was true before this migration and remains true after it — I preserved your
`keymap.toml` exactly rather than inventing keybinds you never asked for. If
you want either plugin actually usable, the two common patterns are:

```toml
# Show git status as a linemode (in yazi/yazi.toml, [manager] section)
linemode = "git"
```
or, for jump-to-char, a keymap entry such as:
```toml
{ on = "f", run = "plugin jump-to-char", desc = "Jump to char" }
```
I left both out since they weren't in your original `keymap.toml` — adding
them is a one-line change to `yazi/keymap.toml` whenever you want it, and
since that file is still plain TOML, you can edit it without touching Nix at
all.

Also worth knowing: your `keymap.toml` comment says `g` is bound to
`cd --interactive` for *"Jump (zoxide)"* — but the actual command
(`cd --interactive`) is yazi's own built-in interactive-cd, not a zoxide
integration. It will keep working exactly as before with zoxide removed;
the comment was just slightly misleading on the original file.

## Zellij: previously missing from Nix entirely

This is the biggest actual gap the migration closes. Searching your original
`configuration.nix` and `home.nix`, `zellij` did not appear as an installed
package anywhere — despite `config.kdl`, `dev.kdl`, and three separate fish
aliases/functions (`zjl`, `zja`, `dev`) all depending on it. On your old
Ubuntu box this was presumably installed some other way (a `.deb`, cargo
install, curl script, etc.) that didn't get captured when these dotfiles were
exported.

`programs.zellij.enable = true` in the new `home.nix` installs the package
and applies your config in one place, closing that gap.

## Packages: what was already fine, and what needed adding

Your original `home.nix` already declared `lazygit` and `yazi` in
`home.packages`. In the new config:

- `yazi` is now installed via `programs.yazi.enable = true` instead of being
  listed separately in `home.packages` — same package, just not declared
  twice.
- `lazygit` is still listed explicitly in `home.packages` (used by your
  `dev`-adjacent workflow / zellij panes).
- `zellij` is newly added, as covered above.
- `bun` is newly added to `home.packages`. Your `config.fish` set
  `BUN_INSTALL` but nothing in your original Nix config actually installed
  the `bun` binary — same class of gap as zellij, just for a single tool
  rather than your whole multiplexer.

Everything else in `home.packages` (LSPs, formatters, C/C++/Java/Node/Go/
Rust/Python toolchains) is unchanged from your original `home.nix`.

## What was deliberately removed (your explicit instructions)

- **zoxide** — fully removed. Not in `environment.systemPackages` (where it
  was originally), not in `home.packages`, no `zoxide init fish` line, no
  `alias cd='z'`. If you change your mind later, re-adding it is:
  ```nix
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    options = [ "--cmd cd" ];  # replicates your old alias cd='z'
  };
  ```
  and removing `zoxide` from any exclusion notes.

- **alacritty.toml** — not migrated into this config at all. Since this
  NixOS installation runs under WSL, Alacritty is normally a Windows-side GUI
  application rather than something the WSL Linux guest itself runs or
  manages — `programs.alacritty` in Home Manager would configure a copy of
  Alacritty running *inside* the Linux environment, which isn't how WSL
  terminal emulators typically work. You confirmed you don't need it
  configured here, so the file was excluded entirely rather than guessed at.
  The original `alacritty.toml` you uploaded is not included in this zip; if
  you still use Alacritty on the Windows side, continue managing that config
  there (typically `%APPDATA%\alacritty\alacritty.toml` on Windows).

## Things worth double-checking after your first rebuild

- `wsl.defaultUser = "nixos"` and `home-manager.users.nixos` both assume your
  Linux username is `nixos`. If it's actually something else on the new
  install, update both.
- `time.timeZone = "Asia/Kolkata"` was carried over unchanged from your
  original `configuration.nix` — adjust if you're setting this up somewhere
  else.
- The dev-toolchain package versions (`jdk21`, `nodejs_22`) are pinned
  major-version floats from nixpkgs, same as your original `home.nix` — they
  will move forward as nixpkgs does, same behavior as before.
- `flake.lock` was left completely untouched, since no new flake *inputs*
  were added (only new packages/programs from the existing `nixpkgs` input).
  Run `nix flake update` whenever you're ready to move to newer package
  versions; it isn't required for this migration to work.
