# Batch Management Agent — Cockpit Setup Guide

Complete walkthrough for wiring up the agent in the AI Tools Cockpit using **SAP AI Core** as the LLM provider.

---

## Step 0 — Store AI Core Credentials in TVARVC (STVARV)

> **Before this step:** The yaai database tables must be populated by running `YCL_AAI_BASIC_SETUP` in Eclipse (ADT). See [INITIAL_SETUP.md](INITIAL_SETUP.md) for instructions. Without this step the cockpit will show 404 errors on all API calls.

**Never hardcode credentials.** Use transaction **`STVARV`** (the dedicated TVARVC maintenance transaction) → **New Entries** → fill in Name, set Type to `P`, enter value in the **Low** field → **Save**.

> `SM31` with table `TVARVC` may show an incomplete or missing maintenance dialog — use `STVARV` directly instead.

Add these entries:

| TVARVC Name | Value |
|-------------|-------|
| `YAAI_AICORE_AUTH_URL` | `https://def-ai.authentication.ap10.hana.ondemand.com` |
| `YAAI_AICORE_CLIENT_ID` | `sb-f694b84d-...` (your client ID) |
| `YAAI_AICORE_CLIENT_SECRET` | `a3a3df27-...` (your client secret) |
| `YAAI_AICORE_BASE_URL` | `https://api.ai.prod.ap-southeast-2.aws.ml.hana.ondemand.com/v2/inference/deployments/d8f6fe1fd20b9978` |
| `YAAI_AICORE_RESOURCE_GROUP` | `default` |

> **`YAAI_AICORE_BASE_URL` must include the full deployment path** — the correct base path is `/v2/inference/deployments/<id>` (note `inference/` in the path). The value above uses `gpt-4.1` (`d8f6fe1fd20b9978`). To use a different model, replace the deployment ID — see the full list by running the deployment discovery script.
> To find URLs: in SAP AI Launchpad → **Deployments**, open your deployment and copy the **Deployment URL** field directly.

---

## Step 1 — Import SSL Certificates (STRUST)

Both AI Core hostnames use different certificate chains. You need **3 certificates** imported into your SSL client PSE before any HTTPS call will succeed.

### Which PSE to use

Open **STRUST** and import into **SSL client Anonymous** (`ANONYM`). This is the default PSE for outbound HTTP calls that don't use a client certificate, which is what `ZCL_YAAI_AICORE_CONN` does.

> If `ANONYM` is disabled in your system, use **SSL client Default** (`DEFAULT`) and update the `set_ssl_id` call in `ZCL_YAAI_AICORE_CONN` to pass `'DEFAULT'`.

### Import procedure

1. Go to **STRUST** → double-click the **SSL client Anonymous** PSE.
2. Scroll to the **Certificate List** section at the bottom.
3. Click **Import Certificate** (folder icon) → browse to the `.pem` file.
4. Click **Add to Certificate List**.
5. Repeat for each certificate.
6. Click **Save** (floppy icon) — the import is not persisted until you save.
7. ICM restart is **not** required for a certificate-only import.

The `.pem` files are in the [`certs/`](certs/) folder of this project.

### Certificate 1 — DigiCert G5 TLS RSA4096 SHA384 2021 CA1

File: [certs/digicert_g5_tls_rsa4096_sha384_2021_ca1.pem](certs/digicert_g5_tls_rsa4096_sha384_2021_ca1.pem)
Used by: `def-ai.authentication.ap10.hana.ondemand.com` (XSUAA / OAuth2 token endpoint)
Note: The root (`DigiCert TLS RSA4096 Root G5`) may already be present in your system. Import this intermediate regardless.

SHA-256: `C6:27:0A:15:06:91:FB:E1:90:D8:31:F5:13:9B:DF:EE:CF:7B:29:8B:4F:A0:CA:17:30:6A:69:D7:E9:1E:7B:A2`
Valid: Apr 2021 – Apr 2031

### Certificate 2 — ISRG Root YR

File: [certs/isrg_root_yr.pem](certs/isrg_root_yr.pem)
Used by: `api.ai.prod.ap-southeast-2.aws.ml.hana.ondemand.com` (AI Core REST API) — root CA
Cross-signed by ISRG Root X1, which is the established Let's Encrypt root already trusted widely.

SHA-256: `07:26:39:D0:B1:40:D5:BF:FA:E1:6A:D9:C3:F6:CC:60:86:04:06:21:F5:1E:E6:1A:6D:46:A8:91:5C:07:CF:76`
Valid: May 2026 – Sep 2032

### Certificate 3 — Let's Encrypt YR2

File: [certs/letsencrypt_yr2.pem](certs/letsencrypt_yr2.pem)
Used by: `api.ai.prod.ap-southeast-2.aws.ml.hana.ondemand.com` (AI Core REST API) — intermediate CA
This intermediate signs the 90-day leaf cert on the AI Core endpoint. The leaf rotates automatically; you only need to import this intermediate once.

SHA-256: `23:8B:85:A0:09:9C:65:B9:70:47:7D:57:24:F1:A1:D4:75:CE:50:58:CF:FE:4E:FA:87:33:89:9B:DB:86:3C:47`
Valid: Sep 2025 – Sep 2028

> **Note on leaf cert rotation:** Let's Encrypt renews the `*.prod.ap-southeast-2.aws.ml.hana.ondemand.com` leaf cert every 90 days. You do **not** import the leaf — only the intermediate (YR2) and root (ISRG Root YR). Those are stable for years and no STRUST update will be needed when the leaf rotates.

---

## Step 2 — Create the ABAP Classes (SE24)

### Prerequisites

- Developer authorization (`SAP_BC_ABAP_DEVELOPER` or equivalent)
- Developer key registered for your user (transaction `SLICENSE`)
- A development package, or use `$TMP` for local-only objects

### Activation order

`ZCL_YAAI_BATCH_TOOLS_PROXY` calls `NEW zcl_yaai_batch_tools()`, so it cannot activate before the real class exists. Always activate in this sequence:

| Order | Class | Source file | Purpose |
|-------|-------|-------------|---------|
| 1 | `ZCL_YAAI_BATCH_TOOLS` | `zcl_yaai_batch_tools.abap` | Real business logic (typed params) |
| 2 | `ZCL_YAAI_BATCH_TOOLS_PROXY` | `zcl_yaai_batch_tools_proxy.abap` | Proxy that accepts STRING from LLM |
| 3 | `ZCL_YAAI_AICORE_CONN` | `zcl_yaai_aicore_conn.abap` | Fetches OAuth2 token + builds connection |

### Creating each class — step by step

Repeat these steps for each of the three classes.

#### 2.1 Open SE24 and create

1. Enter transaction **SE24**.
2. Type the class name in the **Object Type** field (e.g. `ZCL_YAAI_BATCH_TOOLS`).
3. Click **Create**.

#### 2.2 Set class properties

Fill in the dialog that appears:

| Field | Value |
|-------|-------|
| **Description** | e.g. `Batch Management Tool Class` |
| **Instantiation** | `Public` |
| **Final** | ☑ checked |
| **Class Type** | `Usual ABAP Class` |

Click **Save**.

> If **Final** is greyed out in the dialog, save first then check it on the **Properties** tab.

#### 2.3 Assign to a package

- **For transport**: enter your development package → select or create a Workbench Request.
- **For local testing only**: click **Local Object** (assigns to `$TMP`, not transportable).

#### 2.4 Paste the source code

1. In the class editor toolbar click **Source Code** (or menu **Goto → Class → Source Code**).
   This shows the entire class as a single editable text — definition and implementation together.
2. Press **Ctrl+A** to select all existing content, then **Delete** it.
3. Open the corresponding `.abap` file from the `batch_agent/` folder and copy the entire contents.
4. Paste into the SE24 source code editor.

> **If Source Code view is not available** (older system): use the **Methods** tab instead.
> Each method must be created individually — enter the method name, parameters and types via the
> tab's columns and sub-screens, then double-click each method to open its implementation editor
> and paste the method body there.

#### 2.5 Check syntax

Press **Ctrl+F2** (or click the **Check** button — the tick icon in the toolbar).

- Green status bar = no errors, proceed to activation.
- Red messages = fix the issue before activating. Double-click any error message to jump to the offending line.

#### 2.6 Activate

Press **Ctrl+F3** (or click the **Activate** button — the flame icon in the toolbar).

- If an **inactive objects** dialog appears, ensure your class is ticked and click **Activate**.
- Successful activation shows: `Object ZCL_YAAI_BATCH_TOOLS activated` in the status bar.
- The **Activate** button will be greyed out after a successful activation — nothing left to activate.

### Verify all three are active

After activating all three, run transaction **SE80** → Repository Browser → Class Library → search `ZCL_YAAI*`. All three should appear with no inactive indicator.

### Common errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Class ZCL_... is not defined` | Dependency not yet active | Activate in the order above |
| `Type MATNR / WERKS_D unknown` | yaai not installed | Install yaai via abapGit first (Step 1 of GUIDE.md) |
| `Method has a different signature` | Previous partial entry via Methods tab conflicts | Switch to Source Code view and replace everything |
| `Object already exists` | Class exists from a prior attempt | Open it, switch to Source Code view, replace content |
| `No authorization for package` | Missing dev rights | Use `$TMP` or ask BASIS for package access |
| `Developer key not registered` | OSS key missing | Register via `SLICENSE` / SAP Support Portal |
| `REPORT statement unexpected` | SE38 auto-generated a `REPORT` line when the program was created; pasting added a second one | Press **Ctrl+A** in SE38 before pasting to replace all existing content |

---

## Step 2b — Patch yaai Framework Classes for AI Core

Three changes are required to yaai's framework classes to make them work with SAP AI Core. These are modifications to yaai's own classes (not our custom classes).

### YCL_AAI_ASYNC_CHAT_OPENAI

Open in **SE24 → Change → Source Code**. Find the connection block and replace it:

**Find:**
```abap
DATA(lo_aai_conn) = NEW ycl_aai_conn( i_api = yif_aai_const=>c_openai ).

IF i_api_key IS NOT INITIAL.
  lo_aai_conn->set_api_key( i_api_key = i_api_key ).
ENDIF.
```

**Replace with:**
```abap
DATA lo_aai_conn TYPE REF TO ycl_aai_conn.
TRY.
    lo_aai_conn = NEW zcl_yaai_aicore_conn( )->get_connection( ).
  CATCH cx_root.
    lo_aai_conn = NEW ycl_aai_conn( i_api = yif_aai_const=>c_openai ).
    IF i_api_key IS NOT INITIAL.
      lo_aai_conn->set_api_key( i_api_key = i_api_key ).
    ENDIF.
ENDTRY.
```

Then immediately after the `NEW ycl_aai_openai(` constructor closing `)`, add:
```abap
lo_aai_openai->use_completions( abap_true ).
```

> **Why:** `ZCL_YAAI_AICORE_CONN` fetches a fresh OAuth2 token and adds the `AI-Resource-Group` header — both required by AI Core. `use_completions( abap_true )` forces yaai to use `/v1/chat/completions` instead of the Responses API (`/v1/responses`) which AI Core does not support.

### YCL_AAI_OPENAI

Open in **SE24 → Change → Source Code**. Find the `deserialize` call inside the `chat_completions` method and add `i_camel_case = abap_true`:

**Find:**
```abap
lo_aai_util->deserialize(
  EXPORTING
    i_json = l_json
  IMPORTING
    e_data = me->_openai_chat_comp_response
).
```

**Replace with:**
```abap
lo_aai_util->deserialize(
  EXPORTING
    i_json       = l_json
    i_camel_case = abap_true
  IMPORTING
    e_data = me->_openai_chat_comp_response
).
```

> **Why:** AI Core responses include camelCase fields (`toolCalls`, `finishReason`) that need camelCase deserialization to map correctly to the ABAP structures.

Activate both classes after making the changes (**Ctrl+F3**).

---

The file `zyaai_batch_agent_aicore.abap` is an executable report for testing the agent directly from SE38 without the cockpit.

1. Enter transaction **SE38**.
2. Type `ZYAAI_BATCH_AGENT_AICORE` in the **Program** field → click **Create**.
3. In the dialog set **Type** to `Executable Program`, add a description → **Save** → assign package/request.
4. The editor opens with an auto-generated `REPORT ZYAAI_BATCH_AGENT_AICORE.` line already present.
5. Press **Ctrl+A** to select **all** existing content, then **Delete** it.
6. Paste the full contents of `zyaai_batch_agent_aicore.abap`.
7. Check with **Ctrl+F2**, activate with **Ctrl+F3**, run with **F8**.

> **Do not paste on top of the auto-generated skeleton.** SE38 inserts a `REPORT` line automatically when creating a new program. Pasting a file that also contains `REPORT` on top of it produces a syntax error on the duplicate statement. Always clear first with **Ctrl+A → Delete**, then paste.

---

## Step 3 — Configure LLM API (Cockpit → LLM APIs)

AI Core exposes an **OpenAI-compatible** endpoint, so register it as an OpenAI API:

1. Navigate to **LLM APIs** → **New**.
2. Fill in:
   - **API**: `OPENAI` (AI Core uses the OpenAI chat completions format)
   - **Base URL**: the value of `YAAI_AICORE_BASE_URL` — the full deployment URL including `/deployments/<id>`
   - **Model**: `gpt-4.1` (deployment `d8f6fe1fd20b9978`)
3. The API key and `AI-Resource-Group` header are set dynamically by `ZCL_YAAI_AICORE_CONN` — the cockpit agent framework will use the connection object built by that class.

> **Note on token refresh:** OAuth2 tokens from AI Core expire (typically after 12 hours). `ZCL_YAAI_AICORE_CONN` fetches a fresh token on every instantiation. For production, add token caching with expiry check to avoid a token-endpoint round-trip per chat turn.

---

## Step 4 — Register Tools (Cockpit → Tools)

Register **5 tools**, all pointing at the **proxy class** with the real class as the target:

| Tool # | Proxy Class | Real Class | Method | Description |
|--------|-------------|-----------|--------|-------------|
| 1 | `ZCL_YAAI_BATCH_TOOLS_PROXY` | `ZCL_YAAI_BATCH_TOOLS` | `GET_BATCH_HEADER` | Retrieve header data for a specific batch: shelf life expiration date (SLED), manufacturing date, restricted status, and shelf life configuration. |
| 2 | `ZCL_YAAI_BATCH_TOOLS_PROXY` | `ZCL_YAAI_BATCH_TOOLS` | `GET_BATCH_CLASSIFICATION` | Return all classification classes and characteristic values assigned to a batch (class type 023). |
| 3 | `ZCL_YAAI_BATCH_TOOLS_PROXY` | `ZCL_YAAI_BATCH_TOOLS` | `FIND_BATCHES_BY_SLED` | Find all batches for a material and plant whose shelf life expiration date falls within a given date range (YYYYMMDD). |
| 4 | `ZCL_YAAI_BATCH_TOOLS_PROXY` | `ZCL_YAAI_BATCH_TOOLS` | `FIND_EXPIRING_BATCHES` | Return batches that will expire within the next N days for a material and plant, sorted by expiration date. |
| 5 | `ZCL_YAAI_BATCH_TOOLS_PROXY` | `ZCL_YAAI_BATCH_TOOLS` | `FIND_EXPIRED_BATCHES` | Return all batches that have already passed their shelf life expiration date for a material and plant, sorted by most recently expired first. |

> **Tip:** Descriptions are what the LLM reads to decide which tool to call — keep them task-oriented as written above.

---

## Step 5 — Upload Documents (Cockpit → Documents)

Upload the two markdown files from `batch_agent/docs/`. The cockpit accepts only `.md` files.

| File | Document type | Role |
|------|--------------|------|
| `01_system_instructions.md` | System Instructions | Defines agent persona, scope, and behaviour rules |
| `02_tool_usage_guide.md` | Tool Usage Guide | Tells the LLM exactly when and how to call each tool |

---

## Step 6 — Create the Agent (Cockpit → Agents)

1. Navigate to **Agents** → **New**.
2. Fill in:
   - **Name**: `Batch Management Assistant`
   - **Description**: `Answers questions about SAP material batches: shelf life, expiration dates, classification characteristics.`
3. Save.

---

## Step 7 — Configure the Agent

Open the agent detail page and assign:

**Model**
- Select the OpenAI API entry configured in Step 3 (pointing at AI Core).
- Choose model: `gpt-4.1`.

**Tools** — assign all 5 tools registered in Step 4:
- `GET_BATCH_HEADER`
- `GET_BATCH_CLASSIFICATION`
- `FIND_BATCHES_BY_SLED`
- `FIND_EXPIRING_BATCHES`
- `FIND_EXPIRED_BATCHES`

**Documents** — assign both uploaded documents:
- `01_system_instructions.md` → type: **System Instructions**
- `02_tool_usage_guide.md` → type: **Tool Usage Guide**

---

## Step 8 — Test via the Chat Panel

Open the agent detail page. Use the side chat panel:

1. Select your **API** (the AI Core / OpenAI entry from Step 3).
2. Enter the **Agent ID** (shown on the agent detail page).
3. Run these test prompts in order:

| Test prompt | Expected behaviour |
|------------|-------------------|
| `What can you help me with?` | Agent describes its batch management scope |
| `Tell me about batch 0000000045 for material TG22 in plant 1710` | Calls `GET_BATCH_HEADER`, returns SLED + dates |
| `What classifications does that batch have?` | Calls `GET_BATCH_CLASSIFICATION` (remembers context) |
| `Which batches of TG22 in plant 1710 expire in the next 30 days?` | Calls `FIND_EXPIRING_BATCHES` |
| `List all expired batches for TG22 in plant 1710` | Calls `FIND_EXPIRED_BATCHES` |
| `Show batches expiring in Q1 2026` | Calls `FIND_BATCHES_BY_SLED` with converted dates |
| `Can you book a meeting for me?` | Refuses politely (out of scope) |

---

## Step 9 — Validate with Sequence Diagrams

In **Cockpit → Chats**, open the conversation and view the **sequence diagram**. You should see:

```
User → Agent → GET_BATCH_HEADER → Agent → User
```

If a tool is never called, check:
1. The tool description (Step 3) — is it clear enough for the LLM to recognise the intent?
2. The tool usage guide (Step 4) — does it cover this scenario?
3. The model — try a more capable model in your AI Core deployment.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `cx_root` raised in `get_connection` | TVARVC entries missing or wrong | Check Step 0; verify entries with STVARV |
| `"access_token"` not found in response | Client ID / secret wrong, or wrong auth URL | Verify XSUAA credentials in BTP cockpit; ensure **Lowercase** checkbox is checked in STVARV for all entries |
| STVARV saves values in UPPERCASE | Lowercase checkbox not enabled | In STVARV, edit each entry and tick the **Lowercase** checkbox before saving — credentials are case-sensitive |
| HTTP 401 on AI Core endpoint | Token expired or resource group wrong | `ZCL_YAAI_AICORE_CONN` fetches a fresh token each time; check `YAAI_AICORE_RESOURCE_GROUP` |
| HTTP 404 on AI Core endpoint | Wrong or incomplete deployment URL | Check `YAAI_AICORE_BASE_URL` in STVARV — must be `.../inference/deployments/<id>` without trailing `/v1` |
| `"Subpath 'chat/completions' is not allowed"` | Non-OpenAI model deployment selected | Only GPT deployments support the OpenAI API format; use a GPT deployment (e.g. `gpt-4.1`) with yaai's OpenAI class |
| `"We're having a little trouble..."` fallback message | yaai using Responses API instead of Chat Completions | Call `lo_ai->use_completions( abap_true )` after creating the `ycl_aai_openai` instance |
| SLED always blank / "not maintained" | Reading from `MCHA` instead of `MCH1` | `VFDAT` is stored in `MCH1` (cross-plant); `MCHA` does not carry shelf life dates |
| Tool parameters show as empty | LLM didn't extract values from prompt | Improve tool description; add examples to tool usage guide |
| Agent answers out-of-scope questions | System instructions not assigned | Check Step 7 — document must be type "System Instructions" |
| Dates returned as YYYYMMDD | Format conversion missing | System instructions tell the LLM to reformat — check they are loaded |
| Classification returns "no data" | Batch classification not active (`MARA-IPRKZ` blank) | Verify batch classification is configured for the material in MM02 |
