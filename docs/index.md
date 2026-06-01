# 3T MCP documentation

The single binary works two ways: as a **CLI** for MongoDB you can drive from a terminal or scripts, and as an **MCP server** that gives AI assistants (Claude Desktop, Cursor, VS Code) read-safe access to your databases.

Two capabilities are **exclusive to this tool** — not available in `mongosh`, Compass, or standard drivers:

- **`scan-pii`** — detects PII fields (email, phone, IBAN, credit card, IP, and more) and flags them with GDPR / PCI-DSS hints. See [scan-pii.md](scan-pii.md).
- **`analyze-schema`** — probabilistically infers a collection's schema from a document sample, without a schema defined upfront. See [analyze-schema.md](analyze-schema.md).

---

## Getting started

Install, login, connection config, AI-client setup, the full tool reference, and server flags live in the [main README](../README.md):

1. [Install](../README.md#1-install)
2. [Log in](../README.md#2-log-in)
3. [Add a connection](../README.md#3-add-a-connection)
4. [Configure your AI client](../README.md#4-configure-your-ai-client)
5. [Tool reference](../README.md#5-tool-reference)
6. [Server flags](../README.md#6-server-flags)

---

## Guides in this directory

| I want to… | Go to |
|------------|-------|
| Run, filter, and explore from the terminal with real output examples | [cli-reference.md](cli-reference.md) |
| Scan a collection for GDPR / PCI-DSS risk | [scan-pii.md](scan-pii.md) |
| Understand the shape of an unfamiliar collection | [analyze-schema.md](analyze-schema.md) |
| See end-to-end examples combining multiple commands | [workflows.md](workflows.md) |
| Fix an error | [troubleshooting.md](troubleshooting.md) |

---

Examples show representative command output. Connection ids (`local`, `atlas`), database, and collection names are illustrative — substitute your own.
