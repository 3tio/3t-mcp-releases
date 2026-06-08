# Troubleshooting

Find your error message or symptom below. All messages are quoted as the CLI prints them (to stderr, prefixed with `error:`).

---

## Connection errors

### `error: unknown connection "xyz"; available: a, b`

The id passed to `--connection` doesn't match any entry in `connections.yaml`. The message lists the ids that are configured.

**Fix:**
1. Run `stt-cli connections list` to see the configured ids.
2. Re-run with one of those ids.
3. If the id you expected is missing, add it: `stt-cli connections add <id> <uri>`.

---

### `error: MongoDB server selection failed: ... Verify the host and port are reachable and that the cluster is running.`

The binary can't reach MongoDB. The middle of the message carries the driver detail (often `Connection refused`); the closing sentence is the hint. Common causes: MongoDB isn't running, wrong host/port, or an Atlas IP allowlist blocking your machine.

**Fix:**
1. Confirm MongoDB is running and reachable:
   - Local: `mongosh mongodb://localhost:27017` — if this fails, start MongoDB.
   - Remote: check network reachability to the host and port.
2. Check the `uri` in `connections.yaml` for a wrong host or port.
3. **Atlas:** open **Network Access** in the Atlas console and confirm your current IP is allowlisted — the error gives no hint that IP access is the cause.
4. For `mongodb+srv://`, confirm DNS resolves: `nslookup <cluster-host>`.
5. Behind a VPN or firewall, confirm the MongoDB port is open.

---

### `error: MongoDB authentication failed: ... Verify the connection's username and password.`

Wrong username or password.

**Fix:**
1. Check the `username` and `password` for the connection in `connections.yaml`.
2. If the password uses `env:VAR_NAME`, confirm the variable is set:
   ```bash
   echo $VAR_NAME          # macOS / Linux
   echo $Env:VAR_NAME      # Windows PowerShell
   ```
   If blank, set it and retry.
3. Confirm the MongoDB user has at least the `readAnyDatabase` role.

---

## Database / collection not found

### `error: database "xyz" does not exist on connection "id". Run list_databases to see available databases.`
### `error: collection "xyz" does not exist in database "db" on connection "id". Run list_collections to see available collections.`

The command fails fast when the target database or collection doesn't exist, rather than returning empty results. (The message names the MCP tools `list_databases` / `list_collections`; the CLI equivalents are `databases list` and `collections list`.)

**Fix:**
1. List what's actually there:
   ```bash
   stt-cli databases list --connection <id>
   stt-cli collections list --connection <id> --database <db>
   ```
2. Re-run with a name from those lists. Check for typos and case — names are case-sensitive.

---

### A scan or query returns 0 results on a collection that exists

An **existing but empty** collection is not an error — `scan-pii` reports `0 docs sampled | 0 fields scanned`, and `query execute` returns an empty `documents` array. If you expected data:

1. Confirm there is data: `stt-cli query execute --connection <id> --database <db> --collection <coll> --limit 1`.
2. For `query execute`, check your `--filter` isn't too restrictive — drop it first to see if anything comes back.

---

## Config file errors

### `error: config file not found: <path>`

`connections.yaml` is missing at the default location (`~/.stt-mcp/connections.yaml`) or the `--config` path.

**Fix:** create it with at least one connection:
```bash
stt-cli connections add local mongodb://localhost:27017
```
Or validate a specific file: `stt-cli mcp --validate --config <path>`.

A minimal valid file:
```yaml
connections:
  - id: local
    uri: mongodb://localhost:27017
```

---

### `error: failed to parse config file <path>: ...`

The YAML is malformed.

**Fix:** open the file and look for indentation mistakes, missing colons, or tab characters — YAML requires spaces, not tabs.

---

### `error: connections.yaml at <path> has no entries; add at least one connection`

The file exists but the `connections` list is empty.

**Fix:**
```bash
stt-cli connections add local mongodb://localhost:27017
```

---

### `error: env variable "XYZ" is not set; required by connection credential`

A `password: env:XYZ` entry references a variable that isn't defined.

**Fix:**
1. Set it: `export XYZ="your-value"` (macOS/Linux) or `$Env:XYZ="your-value"` (PowerShell).
2. To persist, add it to your shell profile and reload.
3. Running via Claude Desktop / Cursor? The client does **not** inherit your shell environment — add the variable to the `"env"` block of the MCP server config (see [README](../README.md#4-configure-your-ai-client)).

---

## Invalid arguments

### `error: invalid JSON for --filter: ...`

The value passed to `--filter`, `--sort`, `--projection`, or `--pipeline` is not valid JSON. Example: `invalid JSON for --filter: key must be a string at line 1 column 2`.

**Fix:**
- Use a valid JSON object: `'{"field": "value"}'` (keys quoted).
- Wrap the JSON in single quotes on the command line to avoid shell escaping.
- Or read from stdin: `echo '{"field":"value"}' | stt-cli query execute ... --filter -`.

---

### `error: the following required arguments were not provided: --collection <NAME>`

A required flag is missing; the message names it.

**Fix:** add the missing flag. Most data commands require all of `--connection`, `--database`, and `--collection`.

---

## Timeouts

### `error: operation timed out after Xs`

| Command | Timeout |
|---------|---------|
| `scan-pii` | 120 s |
| `analyze-schema` | 60 s |
| `query explain` | 30 s |

**Fix:**
- **`scan-pii` / `analyze-schema`:** lower `--sample-size` (try `100`), then increase. Try `--sample-method first` to skip the `$sample` stage, which can be slow on large collections.
- **`query explain`:** simplify the filter or run against a smaller collection.
- **General:** check network latency to the MongoDB host.

When used as an MCP server, at most 2 concurrent scans / analyses run; a third waits up to 30 s for a slot before timing out.

---

## 3T account authentication

### `error: Not authenticated. Run \`stt-cli login\`...` / `error: Session expired. ...`

A command needs a 3T account session that is missing or expired.

**Fix:**
```bash
stt-cli login
```
A browser opens; after sign-in, retry. To reset a stale session:
```bash
stt-cli logout && stt-cli login
```

---

## MCP server issues

### Tools don't appear in Claude Desktop / Cursor after editing the config

1. Use an **absolute** binary path (e.g. `/usr/local/bin/stt-cli`), not bare `stt-cli`.
2. Test it directly: `/usr/local/bin/stt-cli --version`.
3. Fully quit and reopen the client — a window reload is often not enough.
4. Run the smoke test from the [README](../README.md#4-configure-your-ai-client).

### `spawn ENOENT` / binary not found in the client

Find the exact path with `which stt-cli` (macOS/Linux) or `Get-Command stt-cli` (Windows) and use it verbatim in the config — don't rely on `$PATH`.

### `env:` credentials work in the terminal but not in the client

The client launches the binary as a subprocess and doesn't inherit your shell environment. Add the variables to the `"env"` block of the MCP server config.

---

## Still stuck?

Logs go to **stderr**. Capture a full trace:

```bash
RUST_LOG=debug stt-cli <your-command> 2>/tmp/debug.log
```

Open `/tmp/debug.log` to inspect it.
