// Pure helpers for the appcredrotator panel. No QML types here (no
// FileView, no Process, no Quickshell singleton access) - just string/
// JSON shaping - so this stays testable and reusable regardless of how
// Panel.qml does file I/O.
//
// Every function that needs $HOME takes it as an explicit argument
// rather than calling `Quickshell.env("HOME")` itself: a `.pragma
// library` script doesn't inherit the importing file's `import`
// statements, so `Quickshell` (or any other QML type) is only visible
// here if this file adds its own `.import` - and it's simpler and more
// testable to just have the one caller that already has it (Panel.qml)
// pass it in.
//
// Three things live here:
//   1. Path helpers: tilde expansion.
//   2. Schema validation: turning the raw JSON.parse() of apps.json
//      into a normalized app list, or throwing a descriptive Error if
//      the config is malformed. This is the JS equivalent of what
//      credrot.py's old `load_apps` did in Python - apps.json is
//      plain JSON now, so the "parse" half is just JSON.parse(); this
//      is the "validate the shape" half.
//   3. UI formatting: short labels for full paths, the "~/.config/..."
//      abbreviation the panel uses on collapsed rows, and the
//      current-source status line.
//
// Panel.qml owns everything that needs an actual FileView (reading
// apps.json/state.json, checking whether a source file exists,
// copying content on apply) since QML object types can't be created
// from a .pragma library. This file only shapes the data once Panel.qml
// hands it over.

.pragma library

// ---- Path helpers -----------------------------------------------------

// `~/.foo/bar` -> `home` + the rest. Tilde only at the start, no other
// expansion (matches the old Python behavior exactly).
function expandHome(p, home) {
  if (typeof p !== "string") return p
  home = home || ""
  if (p === "~") return home
  if (p.indexOf("~/") === 0) return home + p.substring(1)
  return p
}

// ---- Schema validation --------------------------------------------------

// Validates and normalizes the parsed apps.json array. Throws a plain
// Error with a human-readable message on any schema problem - the
// caller (Panel.qml) surfaces `.message` in its status strip, same as
// credrot.py's ValueError used to.
//
// Returns an array of:
//   { name, icon, destinations: [ { label, path, sources: [string, ...] } ] }
// `path` and every entry of `sources` are already tilde-expanded.
// This does *not* touch the filesystem - existence checks and "which
// source is current" are Panel.qml's job, since those need FileView.
function validateApps(raw, home) {
  if (!Array.isArray(raw)) {
    throw new Error("apps.json must be a list of app entries")
  }

  return raw.map(function (entry, idx) {
    if (typeof entry !== "object" || entry === null || Array.isArray(entry)) {
      throw new Error("app #" + idx + " is not an object")
    }
    var name = entry.name
    if (typeof name !== "string" || !name.trim()) {
      throw new Error("app #" + idx + " is missing a string \"name\"")
    }
    var icon = entry.icon === undefined || entry.icon === null ? "" : entry.icon
    if (typeof icon !== "string") {
      throw new Error("app " + JSON.stringify(name) + ": \"icon\" must be a string")
    }

    var destsRaw = entry.destinations
    if (!Array.isArray(destsRaw) || destsRaw.length === 0) {
      throw new Error("app " + JSON.stringify(name) + ": \"destinations\" must be a non-empty list")
    }

    var destinations = destsRaw.map(function (dest, didx) {
      if (typeof dest !== "object" || dest === null || Array.isArray(dest)) {
        throw new Error("app " + JSON.stringify(name) + " destination #" + didx + " is not an object")
      }
      var path = dest.path
      if (typeof path !== "string" || !path.trim()) {
        throw new Error("app " + JSON.stringify(name) + " destination #" + didx + " is missing a string \"path\"")
      }
      var expandedPath = expandHome(path, home)
      var label = dest.label
      if (typeof label !== "string" || !label.trim()) {
        label = basename(expandedPath) || path
      }
      var pathsRaw = dest.paths
      if (!Array.isArray(pathsRaw) || pathsRaw.length === 0) {
        throw new Error("app " + JSON.stringify(name) + " destination " + JSON.stringify(label) + ": \"paths\" must be a non-empty list")
      }
      var sources = pathsRaw.map(function (sp, sidx) {
        if (typeof sp !== "string" || !sp.trim()) {
          throw new Error(
            "app " + JSON.stringify(name) + " destination " + JSON.stringify(label) +
            " source #" + sidx + " is not a string"
          )
        }
        return expandHome(sp, home)
      })
      return { label: label, path: expandedPath, sources: sources }
    })

    return { name: name, icon: icon, destinations: destinations }
  })
}

// ---- UI formatting ----------------------------------------------------

// "/home/nixos/.config/git/config" -> "~/.config/git/config" for
// display. Falls back to the original if `home` is empty or the path
// doesn't actually start with it.

function shorten(p, home) {
    if (typeof p !== "string") return ""
    if (home && p.indexOf(home) === 0)
        return "~/.../" + p.substring(home.length).split("/").filter(Boolean).pop()
    return p
}

// Last component of a path, used as the default destination label.
function basename(p) {
  if (typeof p !== "string") return ""
  var slash = p.lastIndexOf("/")
  return slash >= 0 ? p.substring(slash + 1) : p
}

// ---- Display decoration -------------------------------------------------

// Adds display-only fields (`pathDisplay`) on top of the app list
// Panel.qml has already enriched with `current`/`sources[].exists`
// (see Panel.qml's `refresh()`). Kept separate from `validateApps` so
// re-decorating after an in-place `current` update (see Panel.qml's
// `updateDestination`) doesn't need to re-run schema validation or
// touch the filesystem again.
function decorateApps(apps, home) {
  return apps.map(function (a) {
    return {
      name: a.name,
      icon: a.icon,
      destinations: a.destinations.map(function (d) {
        return {
          label: d.label,
          path: d.path,
          pathDisplay: shorten(d.path, home),
          current: d.current,
          sources: d.sources.map(function (s) {
            return {
              path: s.path,
              pathDisplay: shorten(s.path, home),
              exists: s.exists
            }
          })
        }
      })
    }
  })
}

// One-line status for the area under a destination row: which source
// (if any) it's currently switched to. `current` comes from Panel.qml
// comparing state.json's record for this destination against its
// configured sources - ground truth about what was last applied, not
// a guess or a remembered UI selection.
function currentStatus(dest) {
  if (dest.current === null || dest.current === undefined) {
    return "Not yet managed (plain file)"
  }
  var src = dest.sources[dest.current]
  return "Current: " + (src ? src.pathDisplay : "unknown")
}
