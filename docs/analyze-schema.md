# Schema analysis

`analyze-schema` infers the structure of a MongoDB collection by sampling documents and reporting which fields exist, how often they appear, and what types they hold. It is **exclusive to this tool** — not available in `mongosh`, Compass, or standard drivers.

**Why it matters:** MongoDB is schemaless — documents in one collection can have different fields and different types for the same field. Before writing queries, pipelines, or application code against an unfamiliar collection, you need to know what's actually there. `analyze-schema` gives you that picture in seconds.

---

## Quick start

```bash
stt-cli analyze-schema \
    --connection local \
    --database demo \
    --collection restaurants
```

Output is JSON on stdout. Pipe it to a file or to `jq`:

```bash
# Save and browse
stt-cli analyze-schema --connection local --database demo \
    --collection restaurants > /tmp/schema.json

# List every field path and how often it appears (needs jq)
jq '[.fields[] | {path, probability}]' /tmp/schema.json
```

Without `jq`, open the file and search the `"fields"` array — each entry begins with `"path"`.

---

## How it works

The tool samples documents (1000 by default, via MongoDB's `$sample` stage for randomness), walks each one, and accumulates per-field statistics. The result is a flat list of field paths in dotted notation: a document with `{ "address": { "street": "Mulberry" } }` produces the path `"address.street"`.

Statistics per field:

- **Occurrence probability** — `occurrenceCount / analyzedCount`.
- **BSON type breakdown** — how often the field holds a string, int32, double, objectId, array, null, etc.
- **Top distinct values** — most frequent values per type (great for spotting enums).
- **Numeric magnitude bins** — distribution of numeric values across magnitude ranges.

> **Dotted-name caveat:** a literal field named `"address.street"` and a nested `address → street` both produce the path `"address.street"`. Rare in practice, but worth knowing if your data uses dotted field names intentionally.

---

## CLI reference

```bash
stt-cli analyze-schema \
    --connection <id> --database <db> --collection <coll> \
    [--sample-size N] [--sample-method random|first|last|all]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--connection` | required | Connection id from `connections.yaml`. |
| `--database` | required | Database name. |
| `--collection` | required | Collection to analyze. |
| `--sample-size N` | 1000 | Documents to sample. Clamped to 10–10000. Ignored when `--sample-method all`. |
| `--sample-method` | random | `random` — representative sample via `$sample`. `first` / `last` — sequential from the start or end (faster, potentially biased). `all` — full scan; ignores `--sample-size`. |

Output is always JSON to stdout.

---

## Reading the output

Example output, trimmed to a few illustrative fields:

```json
{
  "database": "demo",
  "collection": "restaurants",
  "documentCount": 25355,
  "analyzedCount": 1000,
  "sampling": "random",
  "verbosity": "full",
  "fields": [
    {
      "path": "_id",
      "occurrenceCount": 1000,
      "probability": 1.0,
      "types": [
        { "name": "objectId", "count": 1000, "probability": 1.0 }
      ]
    },
    {
      "path": "borough",
      "occurrenceCount": 1000,
      "probability": 1.0,
      "types": [
        {
          "name": "string",
          "count": 1000,
          "probability": 1.0,
          "topValues": [
            { "value": "Manhattan", "count": 364 },
            { "value": "Brooklyn",  "count": 262 },
            { "value": "Queens",    "count": 242 }
          ]
        }
      ]
    },
    {
      "path": "address.coord",
      "occurrenceCount": 3000,
      "probability": 3.0,
      "isArray": true,
      "types": [
        { "name": "array",  "count": 1000, "probability": 0.333 },
        {
          "name": "double",
          "count": 2000,
          "probability": 0.667,
          "numericBins": [
            { "range": "<0",    "count": 1000 },
            { "range": "10-99", "count": 1000 }
          ]
        }
      ]
    },
    {
      "path": "grades.score",
      "occurrenceCount": 3094,
      "probability": 3.094,
      "isArray": true,
      "types": [
        {
          "name": "int32",
          "count": 3092,
          "probability": 0.999,
          "topValues": [
            { "value": "12", "count": 449 },
            { "value": "10", "count": 320 }
          ],
          "numericBins": [
            { "range": "0",     "count": 56 },
            { "range": "1-9",   "count": 1159 },
            { "range": "10-99", "count": 1877 }
          ]
        },
        { "name": "null", "count": 2, "probability": 0.001 }
      ]
    }
  ]
}
```

### Field-by-field guide

| Output field | Meaning |
|--------------|---------|
| `documentCount` | Estimated total documents in the collection (from `estimatedDocumentCount`). May differ slightly on sharded clusters. |
| `analyzedCount` | Documents actually sampled. |
| `sampling` | The sample method used (`random`, `first`, `last`, `all`). |
| `verbosity` | Output detail level. |
| `path` | Dotted field path. |
| `occurrenceCount` | How many times the field (or array element) was seen across the sample. |
| `probability` | `occurrenceCount / analyzedCount`. For top-level fields this is 0–1 (fraction of documents containing the field). For fields **inside arrays** it can exceed 1.0 — e.g. `grades.score` at `3.094` means ~3.1 grade entries per restaurant. |
| `isArray` | Present and `true` for array fields and for paths found inside array elements (e.g. `address.coord`, `grades.score`). Omitted otherwise. |
| `types[]` | A field can hold several BSON types across documents (polymorphic); each type carries its own `count` and `probability`. |
| `topValues` | Most-frequent values for that type. A few values with high counts ⇒ likely an enum (`borough` above). |
| `numericBins` | Magnitude distribution for numeric types — useful for spotting unexpected ranges or outliers. |

> There is no `depth` field in the output. Nesting is implied by the dots in `path`.

---

## Useful queries on the output

These use `jq` (install: `brew install jq` / `apt install jq`, or [jqlang.org](https://jqlang.org/download/)). Without it, open the JSON and search manually.

```bash
# Sparse top-level fields (present in fewer than 50% of documents).
# Array-element paths have probability > 1.0 — exclude them with isArray.
jq '[.fields[] | select((.isArray // false) == false and .probability < 0.5) | {path, probability}]' schema.json

# Fields that hold null in some documents
jq '[.fields[] | select(any(.types[]; .name == "null")) | .path]' schema.json

# Polymorphic fields (more than one BSON type)
jq '[.fields[] | select((.types | length) > 1) | {path, types: [.types[].name]}]' schema.json

# Enum candidates — top values of a specific field
jq '.fields[] | select(.path == "borough") | .types[].topValues' schema.json
```

---

## MCP tool (`analyze_schema`)

As an MCP server, the AI client calls `analyze_schema` with:

```json
{
  "connectionId": "local",
  "database": "demo",
  "collection": "restaurants",
  "sampleSize": 1000,
  "sampleMethod": "random"
}
```

`sampleSize` and `sampleMethod` are optional. The response shape matches the JSON above.

**Concurrency:** at most 2 concurrent analyses; a third waits up to 30 s for a slot. **Timeout:** 60 s per analysis.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `error: unknown connection "xyz"; available: ...` | Unknown connection id. | Run `stt-cli connections list`; use an id from the list. |
| `...server selection failed: ... Verify the host and port are reachable and that the cluster is running.` | MongoDB unreachable or wrong URI. | Confirm the cluster is up and the `uri` is correct. |
| `...authentication failed: ... Verify the connection's username and password.` | Wrong credentials. | Check `username`/`password`; for `env:VAR`, run `echo $VAR`. |
| `error: collection "xyz" does not exist ...` | The collection doesn't exist — analysis fails fast. | Run `stt-cli collections list --connection <id> --database <db>`. |
| `"fields": []` with `analyzedCount: 0` | The collection exists but is empty. | Confirm with `stt-cli query execute ... --limit 1`. |
| `operation timed out after 60s` | Large collection + slow `$sample`. | Try `--sample-method first` (no `$sample`) or a smaller `--sample-size`. |

See [troubleshooting.md](troubleshooting.md) for the full list.
