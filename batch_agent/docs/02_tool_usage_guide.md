# Tool Usage Guide — Batch Management Assistant

This document describes when and how to call each available tool.
Always prefer using a tool over guessing from memory.

---

## Tool: `get_batch_header`

**When to use:**
Call this tool whenever the user asks for general information about a specific batch, such as:
- "What is the shelf life expiration date of batch X?"
- "When was batch X manufactured?"
- "Is batch X restricted?"
- "Show me the details of batch X"

**Parameters:**
- `i_matnr` — Material number (e.g. `MAT-0001` or `000000000000MAT001`)
- `i_werks` — Plant code (e.g. `1000`)
- `i_charg` — Batch number (e.g. `BATCH-001`)

**Example prompt → tool call:**
User: "What is the SLED for batch B001 of material MAT001 in plant 1000?"
→ Call `get_batch_header` with `i_matnr=MAT001`, `i_werks=1000`, `i_charg=B001`

---

## Tool: `get_batch_classification`

**When to use:**
Call this tool whenever the user asks about classification data, classes, or characteristics of a batch:
- "What classes is batch X assigned to?"
- "What are the characteristics of batch X?"
- "What is the value of characteristic STORAGE_TEMP for batch X?"
- "Show me the batch classification"

**Parameters:**
- `i_matnr` — Material number
- `i_werks` — Plant code
- `i_charg` — Batch number

**Example prompt → tool call:**
User: "What classification characteristics does batch B001 have?"
→ Call `get_batch_classification` with `i_matnr=MAT001`, `i_werks=1000`, `i_charg=B001`

---

## Tool: `find_batches_by_sled`

**When to use:**
Call this tool when the user wants to find batches within a specific expiration date range:
- "Which batches expire in January 2026?"
- "Show me all batches with SLED between 01.01.2026 and 31.03.2026"
- "What batches are valid until end of year?"

**Parameters:**
- `i_matnr` — Material number
- `i_werks` — Plant code
- `i_sled_from` — Start of SLED range in **YYYYMMDD** format (e.g. `20260101`)
- `i_sled_to` — End of SLED range in **YYYYMMDD** format (e.g. `20260331`)

**Important:** Always convert user-provided dates (e.g. "January 2026") to YYYYMMDD before calling this tool.

**Example prompt → tool call:**
User: "Which batches of MAT001 in plant 1000 expire in Q1 2026?"
→ Call `find_batches_by_sled` with `i_sled_from=20260101`, `i_sled_to=20260331`

---

## Tool: `find_expiring_batches`

**When to use:**
Call this tool when the user asks about batches that are about to expire soon:
- "Which batches are expiring soon?"
- "Are there any batches expiring in the next 30 days?"
- "Show me batches expiring this week"
- "What batches do I need to use up before they expire?"

**Parameters:**
- `i_matnr` — Material number
- `i_werks` — Plant code
- `i_days` — Number of days to look ahead (e.g. `30`)

**Defaults:**
- If the user does not specify a time window, use `i_days=30`.
- "This week" → `i_days=7`
- "This month" → `i_days=30`
- "This quarter" → `i_days=90`

**Example prompt → tool call:**
User: "Are there any batches of material MAT001 in plant 1000 expiring soon?"
→ Call `find_expiring_batches` with `i_matnr=MAT001`, `i_werks=1000`, `i_days=30`

---

## Decision Logic

```
User asks about a SPECIFIC batch?
  ├─ Wants header/SLED/dates?       → get_batch_header
  └─ Wants classes/characteristics? → get_batch_classification

User wants to SEARCH across batches?
  ├─ Has a date range in mind?      → find_batches_by_sled
  └─ "Expiring soon" / time window? → find_expiring_batches
```

## Missing Information Protocol
- No material number → ask: "Which material number are you referring to?"
- No plant → ask: "Which plant should I search in?"
- No batch (for specific-batch queries) → ask: "Do you have a specific batch number, or would you like me to search for all batches?"
