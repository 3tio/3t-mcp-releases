# PII scanning

`scan-pii` detects fields containing personally identifiable information in a MongoDB collection. It is **exclusive to this tool** — not available in `mongosh`, Compass, or standard drivers.

**Why it matters:** regulations like **GDPR** and **PCI-DSS** require you to know where personal data lives. `scan-pii` automates that discovery and flags each field with the regulations that apply.

---

## Quick start

```bash
stt-cli scan-pii \
    --connection atlas \
    --database payments \
    --collection transactions
```

The tool samples 1000 random documents, classifies every field, and prints a risk report:

```
Collection: payments.transactions  |  1000 docs sampled (random)  |  26 fields scanned

PII (3)
────────────────────────────────────────────────────────────
  device_telemetry.geo_location.city            0.600  [contact_pii]
                                                       ↳ GDPR Art. 4(1) — personal data
  device_telemetry.geo_location.coordinates     0.600  [location]
                                                       ↳ GDPR Art. 4(1) — personal data
  device_telemetry.ip_address                   0.632  [contact_pii, location]  ipv4:50, phone_intl:50
                                                       ↳ GDPR Art. 4(1) — personal data

LIKELY SAFE (23) — use --verbose to show
```

**Reading a row:**

- **Field path** — dotted, e.g. `device_telemetry.ip_address` is `ip_address` nested under `device_telemetry`.
- **Confidence (0–1)** — how certain the classifier is. `0.632` for the IP field above.
- **`[name signals]`** — PII categories inferred from the field *name* (`contact_pii`, `location`).
- **value-pattern hits** — regex matches in actual values, `ipv4:50` = 50 sampled values matched the IPv4 pattern. Shown only when patterns matched.
- **`↳` regulation hints** — which regulations apply.

The **Likely Safe** bucket is collapsed by default; `--verbose` expands it.

---

## How it works

Detection runs in two passes:

1. **Field-name classification** — the path is matched against 8 PII categories: `secret`, `direct_pii`, `contact_pii`, `name_pii`, `financial`, `health`, `sensitive_demographic`, `location`.
2. **Value-level pattern matching** — sampled string values are scanned for: email, phone, IBAN, credit card (with Luhn check), JWT, IPv4/IPv6, bcrypt hash, UUID, and more.

The final confidence combines both signals. **Sample values are redacted** in all output — only a masked hint like `1********2` is ever shown, never the raw value.

---

## CLI reference

```bash
stt-cli scan-pii \
    --connection <id> --database <db> --collection <coll> \
    [--sample-size N] [--sample-method random|first|last|all] \
    [--deep-scan] [--verbose] [--json]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--connection` | required | Connection id from `connections.yaml`. |
| `--database` | required | Database name. |
| `--collection` | required | Collection to scan. |
| `--sample-size N` | 1000 | Documents to sample. Clamped to 10–10000. Ignored when `--sample-method all`. |
| `--sample-method` | random | `random` (MongoDB `$sample`), `first`, `last`, or `all` (full scan). |
| `--deep-scan` | off | Collect 200 string samples per field instead of 50. Use when PII is sparse. |
| `--verbose` | off | Show the **Likely Safe** bucket (hidden by default). |
| `--json` | off | Print raw JSON instead of the table — for scripting or saving a report. |

---

## Choosing options

- **Default (random, 1000 docs)** — fast and representative; good for most collections.
- **`--sample-method all`** — small collections (under ~50k docs), or when PII may appear in a small minority of documents and you can't miss it.
- **`--deep-scan`** — sparse PII, e.g. a `paymentMethod` present in 5% of documents.
- **`--sample-size 5000 --deep-scan`** — highest recall; slower but thorough. Good for a compliance audit on a critical collection.

---

## JSON output

```bash
stt-cli scan-pii --connection atlas --database payments \
    --collection transactions --json > /tmp/pii.json
```

Top-level shape:

```json
{
  "database": "payments",
  "collection": "transactions",
  "documentsAnalyzed": 1000,
  "fieldsScanned": 26,
  "sampleMethod": "random",
  "verbosity": "full",
  "bucketCounts": { "critical": 0, "pii": 3, "potentiallySensitive": 0, "likelySafe": 23 },
  "samplingTruncated": false,
  "fieldsTruncated": false,
  "fields": [ ... ]
}
```

A single field entry (the IP-address field above):

```json
{
  "field": "device_telemetry.ip_address",
  "bucket": "PII",
  "confidence": 0.631,
  "suggestedAction": "mask in non-prod; access-log in prod",
  "types": ["string"],
  "occurrences": 1288,
  "nameSignals": ["contact_pii", "location"],
  "valueSignals": { "ipv4": 50, "phone_intl": 50 },
  "sampleValuesRedacted": ["1********2", "1********9", "1********4"],
  "regulationHints": ["GDPR Art. 4(1) — personal data"]
}
```

- `valueSignals` is present only when value patterns matched; omitted otherwise.
- `sampleValuesRedacted` holds masked strings, never raw values.
- `suggestedAction` is one of: `"no action"` (Likely Safe), `"human review required"` (Potentially Sensitive), `"mask in non-prod; access-log in prod"` (PII), `"remove or encrypt (client-side FLE / Queryable Encryption)"` (Critical).
- `samplingTruncated: true` — the document cap was hit; not all documents were covered.
- `fieldsTruncated: true` — the collection has unusually many distinct field paths and some were excluded (rare).

Filter a saved report with `jq`:

```bash
# Critical and PII fields only
jq '[.fields[] | select(.bucket == "Critical" or .bucket == "PII")
      | {field, bucket, confidence, regulations: .regulationHints}]' /tmp/pii.json
```

Without `jq`, open the file and search for `"bucket": "Critical"` or `"bucket": "PII"`.

---

## Buckets

| Bucket | Meaning |
|--------|---------|
| **Critical** | High-confidence PII with direct regulatory impact (email, SSN, IBAN, credit card). Immediate attention. |
| **PII** | Likely PII — phone numbers, names, physical addresses, IP, health and financial fields. |
| **Potentially Sensitive** | Context-dependent — birth date, demographic data. Review manually. |
| **Likely Safe** | Low confidence, no strong signals. Hidden unless `--verbose`. |

---

## MCP tool (`scan_pii`)

As an MCP server, the AI client calls `scan_pii` with:

```json
{
  "connectionId": "atlas",
  "database": "payments",
  "collection": "transactions",
  "sampleSize": 1000,
  "sampleMethod": "random",
  "deepScan": false
}
```

Only `connectionId`, `database`, and `collection` are required. The response matches the JSON shape above.

**Concurrency:** at most 2 concurrent scans; a third waits up to 30 s for a slot. **Timeout:** 120 s per scan.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `error: unknown connection "xyz"; available: ...` | `--connection` id not in `connections.yaml`. | Run `stt-cli connections list`; use a listed id. |
| `...server selection failed: ... Verify the host and port are reachable and that the cluster is running.` | MongoDB unreachable or wrong host/port. | Confirm the cluster is up; check the `uri`. |
| `...authentication failed: ... Verify the connection's username and password.` | Wrong credentials. | Check `username`/`password`; for `env:VAR`, run `echo $VAR`. |
| `error: collection "xyz" does not exist ...` | The collection doesn't exist — the scan fails fast. | Run `stt-cli collections list --connection <id> --database <db>`. |
| `0 docs sampled`, `0 fields scanned` | The collection exists but is empty. | Confirm with `stt-cli query execute ... --limit 1`. |
| `operation timed out after 120s` | Very large collection, slow network, or sample too large. | Start with `--sample-size 100`; increase gradually. |

See [troubleshooting.md](troubleshooting.md) for the full list.
