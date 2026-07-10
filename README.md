# yaai — ABAP AI Tools: Examples and Batch Management Agent

Companion code for the [yaai ABAP AI addon](https://github.com/christianjianelli/yaai) by Christian Jianelli.
This repository contains progressive learning examples and a fully working Batch Management chatbot agent backed by SAP AI Core.

---

## Repository Structure

```
├── examples/               Progressive yaai examples (SAP AI Core / gpt-4.1)
│   ├── GUIDE.md            Setup instructions and lessons learned
│   ├── ex1_simple_chat.abap
│   ├── ex2_conversation.abap
│   ├── ex3_system_instructions.abap
│   ├── ex4a_tool_class_template.abap
│   ├── ex4b_proxy_class_template.abap
│   └── ex4c_func_call_report.abap
│
└── batch_agent/            Production-ready Batch Management Agent
    ├── INITIAL_SETUP.md    First-time setup: run YCL_AAI_BASIC_SETUP in Eclipse
    ├── SETUP_GUIDE.md      Full step-by-step setup and troubleshooting
    ├── zcl_yaai_batch_tools.abap         Business logic (SE24)
    ├── zcl_yaai_batch_tools_proxy.abap   LLM string conversion proxy (SE24)
    ├── zcl_yaai_aicore_conn.abap         SAP AI Core OAuth2 connection (SE24)
    ├── zyaai_batch_agent_aicore.abap     Main chatbot report (SE38)
    ├── zyaai_chat_diag.abap              Connectivity diagnostic (SE38)
    ├── zyaai_token_diag.abap             Token / TVARVC diagnostic (SE38)
    ├── docs/
    │   ├── 01_system_instructions.md    Agent persona (upload to cockpit)
    │   └── 02_tool_usage_guide.md       Tool selection guide (upload to cockpit)
    └── certs/                           SSL certificates for STRUST import
        ├── digicert_g5_tls_rsa4096_sha384_2021_ca1.pem   XSUAA endpoint
        ├── isrg_root_yr.pem                               AI Core API root
        ├── letsencrypt_yr2.pem                            AI Core API intermediate
        ├── sectigo_public_server_auth_ca_dv_e36.pem       github.com intermediate
        └── sectigo_public_server_auth_root_e46.pem        github.com root
```

---

## Part 1 — Examples

Four progressive examples using **SAP AI Core** (gpt-4.1). Start here to understand the yaai API before building agents.

| Example | File | What it shows |
|---------|------|--------------|
| 1 | `ex1_simple_chat.abap` | One-shot message → response |
| 2 | `ex2_conversation.abap` | Multi-turn conversation with history as JSON |
| 3 | `ex3_system_instructions.abap` | Persona via system instructions |
| 4 | `ex4a/b/c` | Function calling with a calculator tool + proxy pattern |

See [examples/GUIDE.md](examples/GUIDE.md) for prerequisites and setup steps.

---

## Part 2 — Batch Management Agent

A production-ready chatbot that answers questions about SAP material batches using **SAP AI Core** (gpt-4.1) as the LLM provider and the **AI Tools Cockpit** as the UI.

### What it can answer

- Shelf life expiration date (SLED) for a specific batch
- Manufacturing date, last goods movement
- Shelf life configuration (minimum remaining, total shelf life)
- Batch classification classes and characteristic values
- Batches expiring within the next N days
- Batches already past their expiration date
- Batches with SLED within a specific date range

### ABAP classes

| Class | Role |
|-------|------|
| `ZCL_YAAI_BATCH_TOOLS` | Reads from `MCH1`, `MCHA`, `MARA`, `INOB`, `AUSP`, `CABN` |
| `ZCL_YAAI_BATCH_TOOLS_PROXY` | Receives STRING params from LLM, converts to typed ABAP types |
| `ZCL_YAAI_AICORE_CONN` | Fetches OAuth2 token from XSUAA, builds `YCL_AAI_CONN` for AI Core |

### Tools registered

| Method | Description |
|--------|-------------|
| `GET_BATCH_HEADER` | SLED, manufacturing date, shelf life config for one batch |
| `GET_BATCH_CLASSIFICATION` | Classes and characteristics assigned to a batch |
| `FIND_BATCHES_BY_SLED` | Batches within a SLED date range |
| `FIND_EXPIRING_BATCHES` | Batches expiring within N days |
| `FIND_EXPIRED_BATCHES` | Batches already past their SLED |

### Prerequisites — in order

1. **SSL certificates** imported in STRUST for github.com and AI Core — see `certs/` folder
2. **yaai** installed via abapGit from `https://github.com/christianjianelli/yaai`
3. **yaai_cockpit** installed via `/UI5/UI5_REPOSITORY_LOAD` from `https://github.com/christianjianelli/yaai_cockpit` and activated in SICF
4. **yaai framework patches** applied to two yaai classes — required for AI Core compatibility (see below)
5. **YCL_AAI_BASIC_SETUP** run in Eclipse/ADT to populate the `YAAI_API`, `YAAI_MODEL`, `YAAI_TOOL` tables — see [INITIAL_SETUP.md](batch_agent/INITIAL_SETUP.md)
6. **TVARVC entries** configured in **STVARV** — see [SETUP_GUIDE.md](batch_agent/SETUP_GUIDE.md) Step 0
7. **Custom ABAP classes** created: `ZCL_YAAI_BATCH_TOOLS`, `ZCL_YAAI_BATCH_TOOLS_PROXY`, `ZCL_YAAI_AICORE_CONN`
8. **SAP AI Core** subscription with a running GPT deployment (gpt-4.1 recommended)

### Quick start

Follow [batch_agent/SETUP_GUIDE.md](batch_agent/SETUP_GUIDE.md) — it covers every step from STRUST certificate import through cockpit agent configuration with a troubleshooting table at the end.

---

## Key Technical Notes

### STVARV vs SM31
Use **STVARV** to maintain TVARVC entries — SM31 shows an incomplete maintenance dialog for this table. Always enable the **Lowercase** checkbox for every entry; credentials are case-sensitive and TVARVC uppercases values by default.

### yaai Framework Patches Required for AI Core

Two yaai framework classes must be modified before the cockpit will work with AI Core. These are one-time changes made in SE24:

**`YCL_AAI_ASYNC_CHAT_OPENAI`** — replace the standard connection with `ZCL_YAAI_AICORE_CONN` so the cockpit's agent runner gets a fresh OAuth2 token and the `AI-Resource-Group` header on every call, and add `use_completions( abap_true )`:

```abap
" Replace:
DATA(lo_aai_conn) = NEW ycl_aai_conn( i_api = yif_aai_const=>c_openai ).
IF i_api_key IS NOT INITIAL.
  lo_aai_conn->set_api_key( i_api_key = i_api_key ).
ENDIF.

" With:
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

And after `NEW ycl_aai_openai( ... )`:
```abap
lo_aai_openai->use_completions( abap_true ).
```

**`YCL_AAI_OPENAI`** — add `i_camel_case = abap_true` to the `deserialize` call in `chat_completions` so AI Core response fields map correctly to ABAP structures.

These changes are permanent — no manual token refresh is ever needed.

### SAP AI Core — OpenAI compatibility
- AI Core GPT deployments expose `/v1/chat/completions` — yaai appends this automatically once `use_completions( abap_true )` is called
- Set `YAAI_AICORE_BASE_URL` (and `YAAI_API.BASE_URL` for OPENAI) to the deployment URL **without** `/v1`
- Anthropic model deployments on AI Core use a different API format and are **not compatible** with `ycl_aai_openai`
- OAuth2 tokens are fetched automatically by `ZCL_YAAI_AICORE_CONN` on every call — no manual rotation needed

### Batch data — MCH1 vs MCHA
- `VFDAT` (SLED) and `HSDAT` (manufacturing date) are stored in **`MCH1`** (cross-plant batch table)
- `MCHA` does **not** carry shelf life dates — always read dates from `MCH1`

### yaai_cockpit — SICF activation
After installing the cockpit via `/UI5/UI5_REPOSITORY_LOAD`, activate the ICF service in SICF:
- Navigate to `default_host → sap → yaai` → right-click → **Activate Service**
- Also activate `default_host → sap → bc → ui5_ui5 → sap → yaai_cockpit`
- Set the **Logon Procedure** to **Alternative logon** and check **Use all logon procedures**

---

## Dependencies

| Dependency | Install from | Required for |
|-----------|-------------|-------------|
| [yaai](https://github.com/christianjianelli/yaai) | abapGit | Core framework — install first |
| [yaai_cockpit](https://github.com/christianjianelli/yaai_cockpit) | `/UI5/UI5_REPOSITORY_LOAD` | Cockpit UI for agent management and chat |
| SAP AI Core | BTP cockpit | LLM provider |
| `/ui2/cl_json` | SAP UI Add-On (SAP_UI) | JSON serialization — already present on Fiori systems |
| Eclipse ADT | SAP tooling | Required to run `YCL_AAI_BASIC_SETUP` (initial data setup) |
