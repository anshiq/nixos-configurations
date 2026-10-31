.pragma library

// Pure helpers for ServicesPage: parse systemctl output, filter, format.

function parseJsonList(text) {
    try {
        const v = JSON.parse(String(text || "[]"));
        return Array.isArray(v) ? v : null;
    } catch (e) {
        return null;
    }
}

// `systemctl --user list-units --type=service --all --output=json`
function parseUnits(text) {
    const raw = parseJsonList(text);
    if (raw === null)
        return null;
    const out = [];
    for (const u of raw) {
        if (!u || !u.unit)
            continue;
        out.push({
            unit: String(u.unit),
            load: String(u.load || ""),
            active: String(u.active || ""),
            sub: String(u.sub || ""),
            description: String(u.description || "")
        });
    }
    return out;
}

// `systemctl --user list-unit-files --type=service --output=json` ->
// installed services systemd has unloaded (stopped + nothing refers to them)
// are added back as stopped rows, so a stopped service can be started again.
// Templates ("foo@.service") need an instance name and are skipped.
function withInstalled(units, filesText) {
    const raw = parseJsonList(filesText) || [];
    const seen = {};
    for (const u of units)
        seen[u.unit] = true;
    const out = units.slice();
    for (const f of raw) {
        const name = String((f && f.unit_file) || "");
        const state = String((f && f.state) || "");
        if (!name || seen[name] || name.indexOf("@.") !== -1)
            continue;
        if (state !== "enabled" && state !== "disabled")
            continue;
        out.push({
            unit: name,
            load: "not-loaded",
            active: "inactive",
            sub: "dead",
            description: ""
        });
    }
    return out;
}

// `systemctl --user show -p Id,MemoryCurrent '*.service'` -> {unit: bytes}
function parseMemory(text) {
    const out = {};
    for (const block of String(text || "").split("\n\n")) {
        let id = "", mem = NaN;
        for (const line of block.split("\n")) {
            if (line.indexOf("Id=") === 0)
                id = line.substring(3);
            else if (line.indexOf("MemoryCurrent=") === 0)
                mem = Number(line.substring(14));
        }
        // Unset is "[not set]" (NaN) or UINT64_MAX on older systemd.
        if (id && isFinite(mem) && mem > 0 && mem < 1e18)
            out[id] = mem;
    }
    return out;
}

// systemd escapes names ("\x2d" for "-"); show the readable form.
function displayName(unit) {
    return String(unit || "").replace(/\\x([0-9a-fA-F]{2})/g, (_, h) => String.fromCharCode(parseInt(h, 16))).replace(/\.service$/, "");
}

function isRunning(u) {
    return u.active === "active" || u.active === "activating" || u.active === "reloading";
}

function isTransitioning(u) {
    return u.active === "activating" || u.active === "deactivating" || u.active === "reloading";
}

function rank(u) {
    return u.active === "failed" ? 0 : (isRunning(u) ? 1 : 2);
}

function filterUnits(units, query, showInactive) {
    const q = String(query || "").trim().toLowerCase();
    const out = units.filter(u => {
        if (u.load !== "loaded" && u.load !== "not-loaded")
            return false;
        // D-Bus activated transients are not started/stopped by hand.
        if (/^dbus-:/.test(u.unit))
            return false;
        if (!showInactive && !isRunning(u) && u.active !== "failed")
            return false;
        if (q !== "" && (displayName(u.unit) + " " + u.description).toLowerCase().indexOf(q) === -1)
            return false;
        return true;
    });
    out.sort((a, b) => (rank(a) - rank(b)) || displayName(a.unit).localeCompare(displayName(b.unit)));
    return out;
}

function formatBytes(n) {
    if (!(n > 0))
        return "";
    const units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let i = 0;
    while (n >= 1024 && i < units.length - 1) {
        n /= 1024;
        i++;
    }
    return (i === 0 || n >= 100 ? Math.round(n) : n.toFixed(1)) + " " + units[i];
}

function stateLabel(u) {
    if (u.active === "failed")
        return "Failed";
    if (u.active === "active")
        return u.sub === "running" ? "Running" : (u.sub === "exited" ? "Done" : "Active");
    if (u.active === "activating")
        return "Starting";
    if (u.active === "deactivating")
        return "Stopping";
    if (u.active === "reloading")
        return "Reloading";
    return "Stopped";
}

function clip(text, max) {
    const t = String(text || "").trim();
    return t.length > max ? t.substring(0, max - 1) + "…" : t;
}

// The sub-state, unless the badge already says it.
function extraSub(u) {
    const plain = ["running", "exited", "dead", "failed"];
    return plain.indexOf(u.sub) === -1 ? u.sub : "";
}
