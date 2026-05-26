# Studio 3T MCP

Studio 3T MCP is a single binary that works two ways: as an MCP server giving AI assistants direct, read-safe access to your MongoDB and MongoDB-compatible databases, and as a CLI you can integrate into scripts and automation workflows. Point it at a connection and you can list databases, run queries, inspect indexes, analyze schemas, and scan for PII — without writing application code.

The MCP server runs locally on your machine as a standard [MCP](https://modelcontextprotocol.io) stdio process. Your data never passes through an intermediate service.

---

## Contents

1. [Install](#1-install)
2. [Log in](#2-log-in)
3. [Add a connection](#3-add-a-connection)
4. [Configure your AI client](#4-configure-your-ai-client)
5. [Tool reference](#5-tool-reference)
6. [Server flags](#6-server-flags)

---

## 1. Install

### macOS / Linux

```sh
curl -sSf https://raw.githubusercontent.com/3tio/3t-mcp-releases/main/install.sh | sh
```

The script detects your OS and architecture, downloads the correct binary, and installs it to `/usr/local/bin` when writable, or `~/.local/bin` otherwise.

> **PATH note — `~/.local/bin` only:** If the script prints a message about `~/.local/bin`, add the directory to your shell's PATH:
>
> ```sh
> export PATH="$HOME/.local/bin:$PATH"
> ```
>
> To make it permanent, add the line above to `~/.bashrc`, `~/.zshrc`, or your shell's equivalent, then open a new terminal.

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/3tio/3t-mcp-releases/main/install.ps1 | iex
```

### Verify

```sh
stt-cli --version
```

### Update later

```sh
stt-cli update
```

---

## 2. Log in

Studio 3T MCP requires a Studio 3T account. Authentication happens once; credentials are stored locally and reused automatically.

```sh
stt-cli login
```

This opens your browser to complete sign-in. Return to the terminal once the browser confirms success.

If a tool later returns an authentication error, run `stt-cli login` again to refresh your credentials.

---

## 3. Add a connection

Connections are stored in `~/.stt-mcp/connections.yaml`. Each connection gets a short **ID** — you will pass this ID to every tool call to tell the server which MongoDB instance to use.

```sh
stt-cli connections add <id> <uri>
```

**Examples:**

```sh
# Local MongoDB (no auth)
stt-cli connections add local mongodb://localhost:27017

# Local MongoDB with authentication
stt-cli connections add local mongodb://localhost:27017 --username alice --password s3cr3t

# MongoDB Atlas (SRV URI)
stt-cli connections add atlas mongodb+srv://cluster0.example.mongodb.net --username alice --password s3cr3t

# With a human-readable label (shown in listings)
stt-cli connections add staging mongodb://staging.internal:27017 --label "Staging"
```

### Keeping credentials out of the YAML file

`connections.yaml` is stored in plain text. To avoid writing a password directly into the file, use the `env:` prefix — the value is read from an environment variable at runtime:

```sh
stt-cli connections add prod mongodb://myhost:27017 --username alice --password env:DB_PASSWORD
```

The YAML entry will contain the literal string `env:DB_PASSWORD`, not the secret. Set `DB_PASSWORD` in your shell environment (or your AI client's `env` block — see below) before starting the server.

### Manage connections

```sh
stt-cli connections list             # show all connections (ID, host, label)
stt-cli connections remove <id>      # remove a connection by ID
```

To overwrite an existing connection:

```sh
stt-cli connections add <id> <new-uri> --force
```

### Manual YAML editing

You can also edit `~/.stt-mcp/connections.yaml` directly:

```yaml
connections:
  - id: local
    uri: mongodb://localhost:27017
    label: Local dev

  - id: prod
    uri: mongodb://myhost:27017
    username: alice
    password: "env:DB_PASSWORD"
```

**Connection ID rules:** lowercase letters (`a–z`), digits (`0–9`), underscores, and hyphens; must start with a letter or digit; max 64 characters.

---

## 4. Configure your AI client

Studio 3T MCP runs as a local process started by `stt-cli mcp`. Your AI client needs to know how to launch it.

### Claude Desktop

Edit the Claude Desktop config file:

- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "studio-3t": {
      "command": "stt-cli",
      "args": ["mcp"]
    }
  }
}
```

Restart Claude Desktop after saving.

### VS Code

Create or edit `.vscode/mcp.json` in your workspace root. For a user-level (global) config, open the Command Palette (`Cmd/Ctrl+Shift+P`) and run **MCP: Open User Configuration**.

```json
{
  "servers": {
    "studio-3t": {
      "type": "stdio",
      "command": "stt-cli",
      "args": ["mcp"]
    }
  }
}
```

### Cursor

Edit `~/.cursor/mcp.json` for a global config, or `.cursor/mcp.json` in your project root for a project-specific one. You can also go to **Cursor → Settings → MCP** and add a new server from the UI.

```json
{
  "mcpServers": {
    "studio-3t": {
      "command": "stt-cli",
      "args": ["mcp"]
    }
  }
}
```

### Any MCP-compatible client

For clients not listed above, use these settings:

| Field | Value |
|-------|-------|
| Transport | `stdio` |
| Command | `stt-cli` |
| Args | `["mcp"]` |

### Passing server flags

Add flags after `"mcp"` in the `args` array. For example, to raise the document cap and allow write stages in aggregate pipelines:

```json
{
  "mcpServers": {
    "studio-3t": {
      "command": "stt-cli",
      "args": ["mcp", "--max-documents-per-query", "500", "--allow-writes"]
    }
  }
}
```

See [Server flags](#6-server-flags) for the full list.

### Passing environment variables to the server

If you use the `env:` credential prefix, set the variable in your client's `env` block so the server process inherits it:

```json
{
  "mcpServers": {
    "studio-3t": {
      "command": "stt-cli",
      "args": ["mcp"],
      "env": {
        "DB_PASSWORD": "your-password-here"
      }
    }
  }
}
```

---

## 5. Tool reference

All tools that operate on data require a `connectionId` — the ID you assigned when adding the connection.

---

### `login`

Authenticate with Studio 3T. Opens your browser to complete sign-in. Call this when other tools return an authentication error.

No parameters required.

---

### `list_connections`

List all configured connections from `~/.stt-mcp/connections.yaml`. Returns each connection's ID, host, and label.

No parameters required.

---

### `list_databases`

List databases on a connection.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `connectionId` | string | yes | — | Connection ID |
| `includeCollectionCounts` | boolean | no | `false` | Run an extra query per database to include its collection count |

---

### `list_collections`

List collections in a database.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `connectionId` | string | yes | — | Connection ID |
| `database` | string | yes | — | Database name |
| `includeStats` | boolean | no | `false` | Run an extra `collStats` query per collection to include document count, storage size, and index count. May be slow on databases with many collections. |

---

### `list_indexes`

List indexes on a collection.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `connectionId` | string | yes | — | Connection ID |
| `database` | string | yes | — | Database name |
| `collection` | string | yes | — | Collection name |

---

### `execute_query`

Run a MongoDB `find` on a collection. Returns paginated results.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `connectionId` | string | yes | — | Connection ID |
| `database` | string | yes | — | Database name |
| `collection` | string | yes | — | Collection name |
| `filter` | object | no | `{}` | MongoDB query filter, e.g. `{"status": "active"}` |
| `sort` | object | no | — | Sort spec, e.g. `{"createdAt": -1}` |
| `projection` | object | no | — | Field projection, e.g. `{"name": 1, "_id": 0}` |
| `limit` | integer | no | `10` | Max documents to return. Server cap: 100. Pass `0` for unlimited (subject to server cap). |
| `skip` | integer | no | `0` | Documents to skip. Use for pagination. |
| `responseBytesLimit` | integer | no | `1048576` | Response byte budget (1 MB). Server cap: 16 MB. Pass `0` for unlimited (subject to server cap). |

**Pagination:** when the response contains `metadata.hasMore: true`, fetch the next page by passing `skip: metadata.nextSkip` on the next call. Repeat until `hasMore` is `false`.

---

### `explain_query`

Run MongoDB `explain` on a find query. Returns the query plan without fetching documents.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `connectionId` | string | yes | — | Connection ID |
| `database` | string | yes | — | Database name |
| `collection` | string | yes | — | Collection name |
| `filter` | object | no | `{}` | Query filter |
| `sort` | object | no | — | Sort specification |
| `projection` | object | no | — | Field projection |
| `limit` | integer | no | — | Adds a `LIMIT` stage to the plan |
| `skip` | integer | no | `0` | Adds a `SKIP` stage to the plan |

---

### `analyze_schema`

Sample documents from a collection and infer its schema. Returns field names, BSON types, occurrence rates, and nested structure.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `connectionId` | string | yes | — | Connection ID |
| `database` | string | yes | — | Database name |
| `collection` | string | yes | — | Collection name |
| `sampleSize` | integer | no | `1000` | Documents to sample (range: 10–10000). Ignored when `sampleMethod` is `"all"`. |
| `sampleMethod` | string | no | `"random"` | `"random"` (MongoDB `$sample`), `"first"`, `"last"`, or `"all"` (full collection scan) |

---

### `aggregate`

Run a MongoDB aggregation pipeline.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `connectionId` | string | yes | — | Connection ID |
| `database` | string | yes | — | Database name |
| `collection` | string | yes | — | Collection name |
| `pipeline` | array | yes | — | Aggregation pipeline as a JSON array of stage documents |
| `limit` | integer | no | `10` | Max documents to return. Server cap: 100. |
| `skip` | integer | no | `0` | Documents to skip. |
| `responseBytesLimit` | integer | no | `1048576` | Response byte budget (1 MB). Server cap: 16 MB. |

> **Write stages are disabled by default.** Pipelines containing `$out` or `$merge` are rejected unless the server is started with the `--allow-writes` flag.

Pagination works the same way as `execute_query`: check `metadata.hasMore` and pass `metadata.nextSkip` on the next call.

---

### `scan_pii`

Scan a collection for Personally Identifiable Information. Samples documents, classifies each field by name (8 categories: `secret`, `direct_pii`, `contact_pii`, `name_pii`, `financial`, `health`, `sensitive_demographic`, `location`) and applies value-level pattern matching (email, phone, IBAN, credit card with Luhn check, JWT, IPv4/6, bcrypt hash, UUID, and more).

Each field in the result includes:

- A **confidence score** (0–1)
- A **risk bucket** — Critical / PII / Potentially Sensitive / Likely Safe
- **Regulation hints** — GDPR, PCI-DSS
- **Redacted sample values** used during detection

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `connectionId` | string | yes | — | Connection ID |
| `database` | string | yes | — | Database name |
| `collection` | string | yes | — | Collection name |
| `sampleSize` | integer | no | `1000` | Documents to sample (range: 10–10000). Ignored when `sampleMethod` is `"all"`. |
| `sampleMethod` | string | no | `"random"` | `"random"`, `"first"`, `"last"`, or `"all"` (full scan) |
| `deepScan` | boolean | no | `false` | Collect 200 string samples per field instead of 50. Improves detection recall for sparse PII at the cost of higher memory use. |

**Limits:** at most 2 concurrent scans; each scan times out after 120 seconds.

---

## 6. Server flags

Pass flags after `"mcp"` in the `args` array of your AI client config, or on the command line when running `stt-cli mcp` directly.

| Flag | Default | Description |
|------|---------|-------------|
| `--allow-writes` | off | Allow `$out` and `$merge` stages in aggregation pipelines. Off by default to prevent accidental data modification. |
| `--max-documents-per-query N` | `100` | Server-wide cap on `execute_query` result count. `0` = unlimited. |
| `--max-bytes-per-query N` | `16777216` | Server-wide byte budget for `execute_query` responses (16 MB). `0` = unlimited. |
| `--max-documents-per-aggregate N` | `100` | Server-wide cap on `aggregate` result count. `0` = unlimited. |
| `--max-bytes-per-aggregate N` | `16777216` | Server-wide byte budget for `aggregate` responses (16 MB). `0` = unlimited. |
| `--validate` | — | Parse `connections.yaml` and exit without starting the server. Useful for checking your config. |
| `--config PATH` | `~/.stt-mcp/connections.yaml` | Path to a custom `connections.yaml` file. |

The per-tool `limit` and `responseBytesLimit` parameters are clamped to these server caps. Passing a value higher than the cap silently uses the cap instead; the actual limits in effect are visible in the `guardrails` field of each response.

---

## Releases

See the [Releases](https://github.com/3tio/3t-mcp-releases/releases) tab for changelogs and direct binary downloads.
