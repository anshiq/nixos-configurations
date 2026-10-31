.pragma library

// Pure helpers for DevServicesPage: parse docker ps and ss output.

// Only the fields shown: `{{json .}}` also makes docker compute container
// sizes, which takes seconds with many containers.
var PS_FORMAT = '{"id":{{json .ID}},"name":{{json .Names}},"image":{{json .Image}},"state":{{json .State}},"status":{{json .Status}},"ports":{{json .Ports}}}';

function parseContainers(text) {
    const out = [];
    for (const line of String(text || "").split("\n")) {
        if (!line.trim())
            continue;
        try {
            const c = JSON.parse(line);
            if (c && c.name)
                out.push({
                    id: String(c.id || ""),
                    name: String(c.name),
                    image: String(c.image || ""),
                    state: String(c.state || "").toLowerCase(),
                    status: String(c.status || ""),
                    ports: String(c.ports || "")
                });
        } catch (e) {}
    }
    const rank = s => s === "running" ? 0 : (s === "paused" || s === "restarting" ? 1 : 2);
    out.sort((a, b) => (rank(a.state) - rank(b.state)) || a.name.localeCompare(b.name));
    return out;
}

// "0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp" -> {"5432": "name"}, for
// running containers only (stopped ones still list their mappings).
function publishedPorts(containers) {
    const map = {};
    for (const c of containers) {
        if (c.state !== "running")
            continue;
        const re = /:(\d+)(?:-(\d+))?->/g;
        let m;
        while ((m = re.exec(c.ports)) !== null) {
            const lo = Number(m[1]), hi = Number(m[2] || m[1]);
            for (let p = lo; p <= hi && p - lo < 256; p++)
                map[p] = c.name;
        }
    }
    return map;
}

// Short human summary of the published ports only.
function portSummary(ports) {
    const seen = [];
    const re = /:(\d+(?:-\d+)?)->(\d+(?:-\d+)?\/\w+)/g;
    let m;
    while ((m = re.exec(String(ports || ""))) !== null) {
        const s = m[1] + "→" + m[2];
        if (seen.indexOf(s) === -1)
            seen.push(s);
    }
    return seen.join(", ");
}

function splitHostPort(local) {
    const i = local.lastIndexOf(":");
    return i < 0 ? [local, ""] : [local.substring(0, i), local.substring(i + 1)];
}

function scope(host) {
    const h = host.replace(/%.*$/, "");
    if (h === "127.0.0.1" || h === "[::1]" || h === "::1" || /^127\./.test(h))
        return "local";
    if (h === "0.0.0.0" || h === "*" || h === "[::]" || h === "::")
        return "all";
    return "other";
}

// `ss -ltnpH`: State Recv-Q Send-Q Local Peer [users:(("comm",pid=N,fd=M))]
// One entry per port; IPv4/IPv6 duplicates are merged.
function parseListeners(text) {
    const byPort = {};
    for (const line of String(text || "").split("\n")) {
        const f = line.trim().split(/\s+/);
        if (f.length < 5)
            continue;
        const hp = splitHostPort(f[3]);
        const port = Number(hp[1]);
        if (!(port > 0))
            continue;
        const users = f.slice(5).join(" ");
        const m = users.match(/\(\("([^"]*)",pid=(\d+)/);
        let e = byPort[port];
        if (!e)
            e = byPort[port] = {
                port: port,
                hosts: [],
                scope: "local",
                process: "",
                pid: 0
            };
        if (e.hosts.indexOf(hp[0]) === -1)
            e.hosts.push(hp[0]);
        const s = scope(hp[0]);
        if (s === "all" || (s === "other" && e.scope === "local"))
            e.scope = s;
        if (m && !e.process) {
            e.process = m[1];
            e.pid = Number(m[2]);
        }
    }
    return Object.keys(byPort).map(k => byPort[k]).sort((a, b) => a.port - b.port);
}

function scopeLabel(s) {
    return s === "all" ? "All interfaces" : (s === "local" ? "Localhost only" : "Specific address");
}

function friendlyDockerError(code, err) {
    const t = String(err || "").trim();
    if (code === 127)
        return "The docker CLI is not installed.";
    if (code === 124)
        return "Docker did not answer within 10 seconds.";
    if (/cannot connect|Is the docker daemon running|connection refused|no such file/i.test(t))
        return "The Docker daemon is not running (systemctl --user start docker).";
    if (/permission denied/i.test(t))
        return "Permission denied talking to the Docker socket.";
    return t !== "" ? t.split("\n")[0] : "docker ps failed.";
}

function clip(text, max) {
    const t = String(text || "").trim();
    return t.length > max ? t.substring(0, max - 1) + "…" : t;
}
