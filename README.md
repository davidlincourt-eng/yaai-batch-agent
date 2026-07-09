# yaai — ABAP AI Tools: Examples and Batch Management Agent

Companion code for the [yaai ABAP AI addon](https://github.com/christianjianelli/yaai) by Christian Jianelli.
This repository contains progressive learning examples and a fully working Batch Management chatbot agent backed by SAP AI Core.

---

## Repository Structure

```
├── examples/               Progressive yaai examples (Anthropic / direct API)
│   ├── GUIDE.md            Setup instructions and lessons learned
│   ├── ex1_simple_chat.abap
│   ├── ex2_conversation.abap
│   ├── ex3_system_instructions.abap
│   ├── ex4a_tool_class_template.abap
│   ├── ex4b_proxy_class_template.abap
│   └── ex4c_func_call_report.abap
│
└── batch_agent/            Production-ready Batch Management Agent
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

Four progressive examples using **Anthropic Claude** directly. Start here to understand the yaai API before building agents.

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

### Prerequisites

1. yaai installed via abapGit from `https://github.com/christianjianelli/yaai`
2. SSL certificates imported in STRUST (see `certs/` folder)
3. TVARVC entries configured in **STVARV** (not SM31) — see [SETUP_GUIDE.md](batch_agent/SETUP_GUIDE.md) Step 0
4. SAP AI Core subscription with a GPT deployment running

### Quick start

Follow [batch_agent/SETUP_GUIDE.md](batch_agent/SETUP_GUIDE.md) — it covers every step from STRUST certificate import through cockpit agent configuration with a troubleshooting table at the end.

---

## Key Technical Notes

### STVARV vs SM31
Use **STVARV** to maintain TVARVC entries — SM31 may show an incomplete maintenance dialog. Always enable the **Lowercase** checkbox for each entry; credentials are case-sensitive and TVARVC will uppercase values by default.

### SAP AI Core — OpenAI compatibility
AI Core exposes OpenAI-compatible endpoints for GPT models at `/v1/chat/completions`. When using yaai's `ycl_aai_openai`:
- Set `YAAI_AICORE_BASE_URL` to the deployment URL **without** `/v1` — yaai adds that path segment internally
- Call `lo_ai->use_completions( abap_true )` — yaai defaults to the Responses API which is not supported on AI Core
- Anthropic models on AI Core use a different API format and are **not compatible** with `ycl_aai_openai`; use a GPT deployment

### Batch data — MCH1 vs MCHA
- `VFDAT` (SLED) and `HSDAT` (manufacturing date) are stored in **`MCH1`** (cross-plant batch table)
- `MCHA` (plant-level batch table) does **not** carry shelf life dates — querying `MCHA` for VFDAT will always return blank

---

## Dependencies

- [yaai](https://github.com/christianjianelli/yaai) — ABAP AI Tools addon (install first via abapGit)
- [yaai_cockpit](https://github.com/christianjianelli/yaai_cockpit) — UI for agent configuration and testing (optional)
- SAP AI Core service instance with a running GPT deployment
- `/ui2/cl_json` — ships with SAP UI Add-On (SAP_UI component), required by yaai
