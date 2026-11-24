import base64, json, subprocess, sys
cli, port, tok, out, tool = sys.argv[1:6]
args = json.loads(sys.argv[6]) if len(sys.argv) > 6 else {}
p = subprocess.Popen([cli, "mcp", "--bridge", port, "--control-token-file", tok], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
msgs = [{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"s","version":"0"}}},
        {"jsonrpc":"2.0","method":"notifications/initialized"},
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":tool,"arguments":args}}]
for m in msgs: p.stdin.write(json.dumps(m)+"\n")
p.stdin.flush()
for line in p.stdout:
    m = json.loads(line)
    if m.get("id") == 2:
        for c in m["result"]["content"]:
            if c.get("type") == "image": open(out, "wb").write(base64.b64decode(c["data"])); print("image saved")
            else: print(c.get("text", ""))
        break
p.kill()
