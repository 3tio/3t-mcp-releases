# Workflows

End-to-end examples that combine several commands. Each is self-contained — read them in any order. The commands use the `local` and `atlas` connections and sample collections; substitute your own.

A few steps use `jq` to filter JSON. Install it with `brew install jq` (macOS), `apt install jq` (Linux), or from [jqlang.org](https://jqlang.org/download/). Every `jq` step notes a no-`jq` alternative.

---

## 1. Explore an unfamiliar cluster

You have a connection but no idea what's on it.

**Step 1 — list databases:**

```bash
stt-cli databases list --connection local --include-collection-counts
```

**Step 2 — list collections in the database you picked:**

```bash
stt-cli collections list --connection local --database demo --include-stats
```

**Step 3 — see the indexes (tells you which queries will be fast):**

```bash
stt-cli indexes list --connection local --database demo --collection restaurants
```

**Step 4 — sample a couple of documents to learn the shape:**

```bash
stt-cli query execute --connection local --database demo \
    --collection restaurants --limit 2
```

---

## 2. Understand a collection before writing queries

You want to know which fields exist, which are optional, and what values they hold.

**Step 1 — infer the schema:**

```bash
stt-cli analyze-schema --connection local --database demo \
    --collection restaurants > /tmp/schema.json
```

**Step 2 — find enum-like fields** (a handful of distinct string values):

```bash
# With jq — show the top values for each string field
jq '[.fields[] | select(.types[]?.topValues) | {path, values: [.types[].topValues[]?.value]}]' /tmp/schema.json

# Without jq: open the file and look for "topValues" — short lists are likely enums
```

For the restaurants sample this surfaces `borough` (`Manhattan`, `Brooklyn`, `Queens`, …) and `cuisine` (`American`, `Chinese`, …).

**Step 3 — query using what you learned:**

```bash
stt-cli query execute --connection local --database demo \
    --collection restaurants \
    --filter '{"borough": "Manhattan", "cuisine": "Italian"}' \
    --projection '{"name": 1, "address.street": 1, "_id": 0}' \
    --limit 20
```

**Step 4 — check whether the query hits an index:**

```bash
stt-cli query explain --connection local --database demo \
    --collection restaurants --filter '{"borough": "Manhattan"}'
```

If `result.queryPlanner.winningPlan.stage` is `"COLLSCAN"`, the query scans every document — consider an index on the filtered field.

---

## 3. PII audit before sharing a dataset

Before exporting data or handing a collection to another team, check it for personal data.

**Step 1 — quick scan:**

```bash
stt-cli scan-pii --connection atlas --database payments --collection transactions
```

Fields in the **Critical** and **PII** buckets need attention.

**Step 2 — thorough scan for sparse PII** (optional sub-documents the default sample may under-cover):

```bash
stt-cli scan-pii --connection atlas --database payments --collection transactions \
    --sample-size 5000 --deep-scan
```

**Step 3 — save a JSON report and extract the flagged fields:**

```bash
stt-cli scan-pii --connection atlas --database payments --collection transactions \
    --deep-scan --json > /tmp/pii.json

# With jq
jq '[.fields[] | select(.bucket == "Critical" or .bucket == "PII")
      | {field, bucket, confidence, regulations: .regulationHints}]' /tmp/pii.json

# Without jq: open /tmp/pii.json and search for "bucket": "Critical" / "bucket": "PII"
```

**Step 4 — scan related collections** — PII often lives in more than one place:

```bash
stt-cli scan-pii --connection atlas --database catalog \
    --collection reviews --deep-scan
```

---

## 4. Schema-first aggregation

Build a correct pipeline without trial and error.

**Step 1 — analyze the schema first** to confirm field names and types:

```bash
stt-cli analyze-schema --connection local --database demo \
    --collection restaurants > /tmp/schema.json
```

From the output you can confirm, for example, that `cuisine` is an always-present string and `grades.score` is an integer inside the `grades` array.

**Step 2 — write the pipeline** against the confirmed shape — most common cuisines:

```bash
stt-cli aggregate execute --connection local --database demo \
    --collection restaurants \
    --pipeline '[{"$group":{"_id":"$cuisine","count":{"$sum":1}}},{"$sort":{"count":-1}},{"$limit":5}]'
```

```json
"documents": [
  { "_id": "American", "count": 6182 },
  { "_id": "Chinese", "count": 2417 },
  { "_id": "Café/Coffee/Tea", "count": 1214 },
  { "_id": "Pizza", "count": 1163 },
  { "_id": "Italian", "count": 1069 }
]
```

**Step 3 — verify the match stage hits an index** if your pipeline starts with `$match`:

```bash
stt-cli query explain --connection local --database demo \
    --collection restaurants --filter '{"cuisine": "Italian"}'
```

A large `totalDocsExamined` with a `COLLSCAN` stage means the `$match` scans the whole collection — consider an index.

---

## 5. PII field remediation prep

After a scan flags fields, use schema analysis to learn how they're stored before writing any remediation.

**Step 1 — list the fields that need work:**

```bash
stt-cli scan-pii --connection atlas --database payments --collection transactions --json \
    > /tmp/pii.json

jq '[.fields[] | select(.bucket == "Critical" or .bucket == "PII") | .field]' /tmp/pii.json
# → ["device_telemetry.geo_location.city", "device_telemetry.geo_location.coordinates", "device_telemetry.ip_address"]
```

**Step 2 — understand how those fields are stored:**

```bash
stt-cli analyze-schema --connection atlas --database payments --collection transactions \
    > /tmp/schema.json

jq '[.fields[] | select(.path | startswith("device_telemetry"))
      | {path, probability, isArray, types: [.types[].name]}]' /tmp/schema.json
```

This tells you whether each field is always present or sparse, plain or nested inside an array, and whether it is polymorphic (e.g. string in some documents, null in others) — which determines whether remediation needs a simple `updateMany`, an array update operator, or a multi-stage pipeline.
