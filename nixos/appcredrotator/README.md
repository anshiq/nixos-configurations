# App Config Rotator

Config for the settings app's Credentials page
(`../desktop/settings-app/pages/CredentialsPage.qml`, `settings-app
credentials`), which replaced the old Quickshell bar plugin. Lets you switch
an app between alternate configs/credentials (Git work vs. personal, Helix
config.toml + languages.toml, an auth token per account, ...).

Everything - reading this file, checking which source is active, copying a
source onto its destination - is done by the page itself in QML/JS via
Quickshell's `FileView` (see `CredentialsPage.qml`'s header comment for the
full design). There is no helper process of any kind; `apps.json` is plain
JSON specifically so the page can read it with `JSON.parse()`.

## Schema

Top level: a list of apps. Each app has a list of destinations. Each
destination has a list of source files to switch between.

```json
[
  {
    "name": "Git",
    "icon": "",
    "destinations": [
      {
        "label": "Config",
        "path": "~/.config/git/config",
        "paths": [
          "~/.dotfiles/git/config.work",
          "~/.dotfiles/git/config.personal"
        ]
      }
    ]
  }
]
```

- `name` (required, string) - display name in the panel.
- `icon` (optional, string) - single glyph (Nerd Font), defaults to `""`.
- `destinations` (required, non-empty list):
  - `label` (optional, string) - defaults to the basename of `path`.
  - `path` (required, string) - the file the app actually reads. `~`
    expands to `$HOME`.
  - `paths` (required, non-empty list of strings) - the named profiles to
    switch `path` between. `~` expands to `$HOME`.

## Behavior

Switching `path` to a given `paths` entry **copies** that source's content
onto `path` (not a symlink - QML/Quickshell has no symlink primitive, and
shelling out to `ln`/`readlink` for just that would defeat the point of
having no subprocess at all). A small `state.json` in `~/.local/share/appcredrotator/`
(runtime-only, paths only, no secrets, never committed) records which
source each destination is currently set to, which gives switching two
properties a plain "last one wins" copy wouldn't:

- **The panel always shows what's actually active**, read from `state.json`,
  not a remembered UI guess.
- **No lost updates.** Many apps rewrite their own config/token file after
  login or a token refresh. Every switch flushes the destination's current
  content back into the source it's recorded as belonging to *before*
  copying in the new one, so a profile's file always reflects its latest
  state - switching away and back never discards what the app itself wrote.

The first time a destination is put under management, if `path` already
exists as a real pre-existing file, it's copied once to
`<path>.appcredrotator-original` before being overwritten - a single safety
snapshot, not a backup chain.

## Example: Helix (multi-destination)

Helix has two config files that usually move together (`config.toml` +
`languages.toml`). Each destination is independent in the panel - pick a
source for each, then "Apply all" (or Apply per row) to commit the swap.

```json
{
  "name": "Helix",
  "destinations": [
    {
      "label": "Config",
      "path": "~/.config/helix/config.toml",
      "paths": [
        "~/.dotfiles/helix/work/config.toml",
        "~/.dotfiles/helix/personal/config.toml"
      ]
    },
    {
      "label": "Languages",
      "path": "~/.config/helix/languages.toml",
      "paths": [
        "~/.dotfiles/helix/work/languages.toml",
        "~/.dotfiles/helix/personal/languages.toml"
      ]
    }
  ]
}
```

Note that `~/.config/helix/config.toml` and `languages.toml` are themselves
live links into this repo (`../helix/`), so switching them writes the chosen
profile into `../helix/*.toml` and shows up in `git diff`.

`~/.local/share/appcredrotator/apps.json` is a live link to `apps.json` in
this repo: edit it here and the page picks it up on its next open, no
rebuild needed. Only a first-time setup on a new machine needs a rebuild
(to create the link).
