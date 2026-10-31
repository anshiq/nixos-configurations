.pragma library

// Pure helpers for CredentialsPage: validate apps.json, shape paths.

function expandHome(p, home) {
    if (p === "~")
        return home;
    return p.indexOf("~/") === 0 ? home + p.substring(1) : p;
}

function tildify(p, home) {
    return home && p.indexOf(home + "/") === 0 ? "~" + p.substring(home.length) : p;
}

function basename(p) {
    return p.substring(p.lastIndexOf("/") + 1);
}

function isObject(v) {
    return typeof v === "object" && v !== null && !Array.isArray(v);
}

function isText(v) {
    return typeof v === "string" && v.trim() !== "";
}

// Throws an Error with a readable message on any schema problem. Returns
// [{name, icon, destinations: [{label, path, sources: [path]}]}], expanded.
function validateApps(raw, home) {
    if (!Array.isArray(raw))
        throw new Error("apps.json must be a list of apps");
    return raw.map((app, i) => {
        if (!isObject(app))
            throw new Error(`app #${i} is not an object`);
        if (!isText(app.name))
            throw new Error(`app #${i} is missing a "name"`);
        const name = app.name;
        const icon = app.icon === undefined || app.icon === null ? "" : app.icon;
        if (typeof icon !== "string")
            throw new Error(`${name}: "icon" must be a string`);
        if (!Array.isArray(app.destinations) || app.destinations.length === 0)
            throw new Error(`${name}: "destinations" must be a non-empty list`);
        const destinations = app.destinations.map((d, j) => {
            if (!isObject(d))
                throw new Error(`${name} destination #${j} is not an object`);
            if (!isText(d.path))
                throw new Error(`${name} destination #${j} is missing a "path"`);
            const path = expandHome(d.path, home);
            const label = isText(d.label) ? d.label : basename(path);
            if (!Array.isArray(d.paths) || d.paths.length === 0)
                throw new Error(`${name} / ${label}: "paths" must be a non-empty list`);
            const sources = d.paths.map((s, k) => {
                if (!isText(s))
                    throw new Error(`${name} / ${label}: source #${k} is not a string`);
                return expandHome(s, home);
            });
            return {
                label: label,
                path: path,
                sources: sources
            };
        });
        return {
            name: name,
            icon: icon,
            destinations: destinations
        };
    });
}
