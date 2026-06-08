# CLI reference

Every command with representative output. Connection, database, and collection names are illustrative — substitute your own. For installation and connection setup, see the [main README](../README.md).

All commands accept the global `--config PATH` flag to use an alternate `connections.yaml`:

```bash
stt-cli --config /path/to/connections.yaml <command> ...
```

Tip: `stt-cli --help`, and `stt-cli <command> --help`, print usage and examples for any command.

---

## connections

Manage entries in `connections.yaml`. These commands never open a MongoDB connection.

### list

```bash
stt-cli connections list
```

```
ID     HOST                                LABEL
-----  ----------------------------------  -------------
local  localhost:27017                     Local MongoDB
atlas  cluster0.example.mongodb.net:27017  -
```

The `ID` column is the value you pass to `--connection` on every data command.

### add

```bash
stt-cli connections add <id> <uri> [--username U] [--password P] [--label L] [--force]
```

```bash
# Local MongoDB, no auth
stt-cli connections add local mongodb://localhost:27017 --label "Local MongoDB"

# Atlas with the password read from an environment variable
stt-cli connections add atlas mongodb+srv://cluster0.example.mongodb.net \
    --username myuser \
    --password env:ATLAS_PW \
    --label "Atlas staging"

# Overwrite an existing id (without --force the command errors if the id exists)
stt-cli connections add atlas mongodb+srv://new.example.mongodb.net \
    --username newuser --password env:ATLAS_PW --force
```

### remove

```bash
stt-cli connections remove <id>
```

> `add` and `remove` rewrite `connections.yaml` from the parsed in-memory model — YAML comments and formatting are not preserved.

---

## databases list

Lists databases on a connection.

```bash
stt-cli databases list --connection <id> [--include-collection-counts] [--json]
```

Default — name, size, and whether the database is empty:

```
NAME       SIZE       EMPTY
---------  ---------  -----
demo       5.18 MB    no
admin      40.00 KB   no
config     108.00 KB  no
local      72.00 KB   no
analytics  12.00 KB   no
scratch    8.00 KB    no

6 database(s)  |  total size: 5.42 MB
```

With `--include-collection-counts` (one extra query per database):

```
NAME       COLLECTIONS  SIZE       EMPTY
---------  -----------  ---------  -----
demo       1            5.18 MB    no
admin      1            40.00 KB   no
config     1            108.00 KB  no
local      1            72.00 KB   no
analytics  1            12.00 KB   no
scratch    1            8.00 KB    no

6 database(s)  |  total size: 5.42 MB
```

`--json` prints the raw structure instead of a table.

---

## collections list

Lists collections in a database, with optional per-collection stats.

```bash
stt-cli collections list --connection <id> --database <db> [--include-stats] [--json]
```

With `--include-stats` (an extra `collStats` per collection — may be slow with many collections):

```
NAME         TYPE        DOCUMENTS  SIZE      STORAGE  INDEXES
-----------  ----------  ---------  --------  -------  -------
restaurants  collection  25355      10.13 MB  3.85 MB  2

1 collection(s) in demo
```

---

## indexes list

Lists indexes on a collection with their key spec and options.

```bash
stt-cli indexes list --connection <id> --database <db> --collection <coll> [--json]
```

```
NAME  TYPE    KEY                            UNIQUE  SPARSE  HIDDEN
----  ------  -----------------------------  ------  ------  ------
_id_  single  {"_id":"ascending"}            -       -       -
r     single  {"address.coord":"ascending"}  -       -       -

2 index(es) on demo.restaurants
```

---

## query execute

Runs a MongoDB `find` and prints a JSON envelope with results and pagination metadata.

```bash
stt-cli query execute \
    --connection <id> --database <db> --collection <coll> \
    [--filter <JSON>] [--sort <JSON>] [--projection <JSON>] \
    [--limit <N>] [--skip <N>] [--response-bytes-limit <N>]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--filter` | `{}` | Query filter as a JSON object. Pass `-` to read from stdin. |
| `--sort` | none | Sort spec, e.g. `{"createdAt": -1}`. |
| `--projection` | none | Fields to include/exclude, e.g. `{"name": 1, "_id": 0}`. |
| `--limit` | none (all) | Maximum documents to return. |
| `--skip` | 0 | Documents to skip; pair with `metadata.nextSkip` for pagination. |
| `--response-bytes-limit` | none | Byte cap on the response. |

Example — one document:

```bash
stt-cli query execute --connection local --database demo \
    --collection restaurants --limit 1
```

```json
{
  "database": "demo",
  "collection": "restaurants",
  "filter": {},
  "documents": [
    {
      "_id": "5eb3d668b31de5d588f42d17",
      "address": {
        "building": "164",
        "coord": [-73.996905, 40.719626],
        "street": "Mulberry Street",
        "zipcode": "10013"
      },
      "borough": "Manhattan",
      "cuisine": "Italian",
      "grades": [
        { "date": "2014-10-07T00:00:00Z", "grade": "Z", "score": 18 },
        { "date": "2014-01-30T00:00:00Z", "grade": "A", "score": 7 }
      ],
      "name": "Da Nico Restaurant",
      "restaurant_id": "40396264"
    }
  ],
  "metadata": { "returned": 1, "limit": 1, "hasMore": true, "nextSkip": 1, "estimatedTokens": 268 },
  "guardrails": { "maxDocuments": 1, "timeoutSeconds": 30 }
}
```

`metadata.limit` and `guardrails.maxDocuments` appear only when `--limit` is set; `metadata.skip` only when `--skip > 0`; `guardrails.maxResponseBytes` only when `--response-bytes-limit` is set.

**Paginate** by re-running with `--skip` equal to `metadata.nextSkip`, while `hasMore` is `true`.

More filter examples:

```bash
# Filter by a field
stt-cli query execute --connection local --database demo \
    --collection restaurants --filter '{"cuisine": "Italian"}'

# Filter + sort + projection + limit
stt-cli query execute --connection local --database demo \
    --collection restaurants \
    --filter '{"borough": "Manhattan"}' \
    --sort '{"name": 1}' \
    --projection '{"name": 1, "cuisine": 1, "_id": 0}' \
    --limit 20

# Read the filter from stdin
echo '{"cuisine": "Pizza"}' | stt-cli query execute \
    --connection local --database demo \
    --collection restaurants --filter -
```

---

## query explain

Runs `explain` with `executionStats` verbosity so you can see whether a query uses an index or scans the whole collection.

```bash
stt-cli query explain \
    --connection <id> --database <db> --collection <coll> \
    [--filter <JSON>] [--sort <JSON>] [--projection <JSON>] [--limit <N>] [--skip <N>]
```

```bash
stt-cli query explain --connection local --database demo \
    --collection restaurants --filter '{"borough": "Manhattan"}'
```

```json
{
  "database": "demo",
  "collection": "restaurants",
  "filter": { "borough": "Manhattan" },
  "result": {
    "queryPlanner": {
      "winningPlan": {
        "stage": "COLLSCAN",
        "filter": { "borough": { "$eq": "Manhattan" } },
        "direction": "forward"
      }
    },
    "executionStats": {
      "nReturned": 10259,
      "executionTimeMillis": 13,
      "totalKeysExamined": 0,
      "totalDocsExamined": 25355
    }
  }
}
```

What to look for:

- `winningPlan.stage: "IXSCAN"` — the query uses an index. Good.
- `winningPlan.stage: "COLLSCAN"` — full collection scan (above, all 25 355 documents examined for 10 259 returned). Consider an index on the filtered field.
- `totalDocsExamined` much larger than `totalKeysExamined` — the query is not well covered by indexes.

Timeout: 30 s. The CLI applies no size cap; the 256 KB cap applies only to the MCP `explain_query` tool.

---

## aggregate execute

Runs an aggregation pipeline and prints a JSON envelope.

```bash
stt-cli aggregate execute \
    --connection <id> --database <db> --collection <coll> \
    --pipeline <JSON> \
    [--limit <N>] [--skip <N>] [--response-bytes-limit <N>] [--allow-writes]
```

`--pipeline` takes a JSON array; pass `-` to read from stdin. Write stages (`$out`, `$merge`) are rejected unless `--allow-writes` is set.

```bash
stt-cli aggregate execute --connection local --database demo \
    --collection restaurants \
    --pipeline '[{"$group":{"_id":"$cuisine","count":{"$sum":1}}},{"$sort":{"count":-1}},{"$limit":5}]'
```

```json
{
  "database": "demo",
  "collection": "restaurants",
  "pipeline": [ { "$group": { "_id": "$cuisine", "count": { "$sum": 1 } } }, { "$sort": { "count": -1 } }, { "$limit": 5 } ],
  "documents": [
    { "_id": "American", "count": 6182 },
    { "_id": "Chinese", "count": 2417 },
    { "_id": "Café/Coffee/Tea", "count": 1214 },
    { "_id": "Pizza", "count": 1163 },
    { "_id": "Italian", "count": 1069 }
  ],
  "metadata": { "returned": 5, "hasMore": false, "estimatedTokens": 199 },
  "guardrails": { "timeoutSeconds": 30 }
}
```

---

## analyze-schema

Infers a collection's schema from a document sample. Full guide: [analyze-schema.md](analyze-schema.md).

```bash
stt-cli analyze-schema \
    --connection <id> --database <db> --collection <coll> \
    [--sample-size N] [--sample-method random|first|last|all]
```

---

## scan-pii

Scans a collection for PII and prints a risk report. Full guide: [scan-pii.md](scan-pii.md).

```bash
stt-cli scan-pii \
    --connection <id> --database <db> --collection <coll> \
    [--sample-size N] [--sample-method random|first|last|all] \
    [--deep-scan] [--verbose] [--json]
```

---

## mcp

Starts the MCP server over stdio. Client setup is in the [README](../README.md#4-configure-your-ai-client).

```bash
stt-cli mcp [--validate] [--allow-writes]
            [--max-documents-per-query N] [--max-bytes-per-query N]
            [--max-documents-per-aggregate N] [--max-bytes-per-aggregate N]
```

`--validate` parses the config and exits without starting the server — useful for checking `connections.yaml`.

---

## login / logout

```bash
stt-cli login    # opens a browser for 3T sign-in; stores the session token locally
stt-cli logout   # removes the stored session token
```

---

## update

```bash
stt-cli update   # updates stt-cli to the latest released version
```

---

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 2 | Error — bad config, connection failure, query error, or invalid arguments |
