import base64, json, subprocess, sys
cli, port, outdir = sys.argv[1:4]; secs = [float(s) for s in sys.argv[4:]]
p = subprocess.Popen([cli, "--bridge", f"127.0.0.1:{port}", "mcp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
def send(m): p.stdin.write(json.dumps(m)+"\n"); p.stdin.flush()
send({"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"f","version":"0"}}})
send({"jsonrpc":"2.0","method":"notifications/initialized"})
for i, s in enumerate(secs, 1):
    send({"jsonrpc":"2.0","id":i,"method":"tools/call","params":{"name":"render_frame","arguments":{"seconds":s,"max_side":800}}})
want = set(range(1, len(secs)+1))
for line in p.stdout:
    m = json.loads(line); i = m.get("id")
    if i in want:
        for c in m["result"]["content"]:
            if c.get("type") == "image":
                open(f"{outdir}/f{secs[i-1]:.2f}.png", "wb").write(base64.b64decode(c["data"]))
            else: print(c.get("text","")[:300])
        want.discard(i)
        if not want: break
p.kill()
