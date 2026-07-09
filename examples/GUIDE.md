# yaai End-to-End Example Guide

A progressive set of 4 examples for the [yaai ABAP AI addon](https://github.com/christianjianelli/yaai).
All examples use **SAP AI Core** (gpt-4.1) as the LLM provider via `ZCL_YAAI_AICORE_CONN`.

---

## Prerequisites

### 1. Import SSL certificates for github.com (transaction STRUST)

abapGit clones over HTTPS, so the GitHub certificate chain must be trusted before you can install yaai.

Open **STRUST** → double-click **SSL client Anonymous** PSE → import both files below → **Save**.

| File | Role | Valid |
|------|------|-------|
| [../batch_agent/certs/sectigo_public_server_auth_ca_dv_e36.pem](../batch_agent/certs/sectigo_public_server_auth_ca_dv_e36.pem) | Intermediate CA | Mar 2021 – Mar 2036 |
| [../batch_agent/certs/sectigo_public_server_auth_root_e46.pem](../batch_agent/certs/sectigo_public_server_auth_root_e46.pem) | Root CA | Mar 2021 – Jan 2038 |

> The `github.com` leaf cert rotates every ~3 months and does **not** need to be imported — only these two stable CA certs are required.
> See [abapGit SSL guide](https://docs.abapgit.org/other/ssl-setup.html) for the full STRUST walkthrough.

### 2. Install yaai via abapGit
Clone `https://github.com/christianjianelli/yaai` into your system using abapGit.

### 3. Configure TVARVC entries (transaction STVARV)

Use transaction **`STVARV`** → **New Entries** → fill in Name, Type `P`, value in the **Low** field → **Save**.

> `SM31` may show an incomplete maintenance dialog for TVARVC — use `STVARV` instead.
> **Always enable the Lowercase checkbox** for each entry — credentials are case-sensitive and TVARVC uppercases values by default.

| Name | Value |
|------|-------|
| `YAAI_AICORE_AUTH_URL` | `https://def-ai.authentication.ap10.hana.ondemand.com` |
| `YAAI_AICORE_CLIENT_ID` | your client ID |
| `YAAI_AICORE_CLIENT_SECRET` | your client secret |
| `YAAI_AICORE_BASE_URL` | `https://api.ai.prod.ap-southeast-2.aws.ml.hana.ondemand.com/v2/inference/deployments/<your-id>` |
| `YAAI_AICORE_RESOURCE_GROUP` | `default` |

### 4. Import SSL certificates for AI Core (transaction STRUST)

Import the three `.pem` files from `batch_agent/certs/` into the **SSL client Anonymous** PSE — see [batch_agent/SETUP_GUIDE.md](../batch_agent/SETUP_GUIDE.md) Step 1 for details.

### 5. Create ZCL_YAAI_AICORE_CONN (SE24)

Create the connection helper class from [../batch_agent/zcl_yaai_aicore_conn.abap](../batch_agent/zcl_yaai_aicore_conn.abap) as a Public Final global class and activate it. This class is used by all examples.

---

## Examples

### Example 1 — Simple Chat (`ex1_simple_chat.abap`)
**What it does:** One-shot message → print response.
**Run:** SE38 → `ZYAAI_EX1_SIMPLE_CHAT`, paste code after the auto-generated REPORT line, F8.

Key calls:
```abap
DATA lo_conn TYPE REF TO ycl_aai_conn.
lo_conn = NEW zcl_yaai_aicore_conn( )->get_connection( ).
DATA(lo_ai) = NEW ycl_aai_openai( i_model = 'gpt-4.1' i_o_connection = lo_conn ).
lo_ai->use_completions( abap_true ).
lo_ai->chat( EXPORTING i_message = '...' IMPORTING e_t_response = DATA(lt_response) ).
```

---

### Example 2 — Multi-Turn Conversation (`ex2_conversation.abap`)
**What it does:** Selection-screen prompt, keeps in-memory history, dumps full conversation as JSON at the end.
**Run:** SE38 → `ZYAAI_EX2_CONVERSATION`, F8 for each turn.

Key calls:
```abap
DATA(lo_conversation) = lo_ai->get_conversation( ).
DATA(lv_json) = /ui2/cl_json=>serialize( data = lo_conversation ... ).
```

---

### Example 3 — System Instructions (`ex3_system_instructions.abap`)
**What it does:** Sets a persona (SAP MM support agent) before the first message, then tests an in-scope and an out-of-scope question.
**Run:** SE38 → `ZYAAI_EX3_SYSTEM_INSTRUCTIONS`, F8.

Key calls:
```abap
lo_ai->set_system_instructions( lv_sys ).   " called BEFORE first chat()
```

---

### Example 4 — Function Calling (`ex4a/b/c`)
**What it does:** The model automatically calls ABAP methods (`add`, `multiply`) when it needs to compute numbers.

**Steps:**
1. **SE24** → create global class `ZCL_YAAI_CALCULATOR` using the code in `ex4a_tool_class_template.abap` (remove comment markers `*`).
2. **SE24** → create global class `ZCL_YAAI_CALCULATOR_PROXY` using `ex4b_proxy_class_template.abap`.
   - The proxy accepts `STRING` parameters from the LLM and converts to typed values before calling the real class.
3. **SE38** → create report `ZYAAI_EX4_FUNC_CALL` from `ex4c_func_call_report.abap`, F8.

Key calls:
```abap
DATA(lo_tools) = NEW ycl_aai_func_call_openai( ).
lo_tools->add_methods( VALUE #(
  ( proxy_class = 'ZCL_YAAI_CALCULATOR_PROXY'
    class_name  = 'ZCL_YAAI_CALCULATOR'
    method_name = 'ADD'
    description = 'Add two numbers.' )
) ).
lo_ai->bind_tools( lo_tools ).
```

Expected output for prompt `"What is 42 multiplied by 7?"`:
```
  [tool called] ZCL_YAAI_CALCULATOR->MULTIPLY
=== Response (with tools) ===
42 multiplied by 7 equals 294.
```

---

## Key Classes at a Glance

| Class | Purpose |
|-------|---------|
| `zcl_yaai_aicore_conn` | Fetches OAuth2 token from AI Core XSUAA and builds connection |
| `ycl_aai_conn` | HTTP connection + API key |
| `ycl_aai_openai` | OpenAI-compatible chat client (used for AI Core GPT deployments) |
| `ycl_aai_func_call_openai` | Tool/function-calling registry for OpenAI format |

## Important Rules for Tool Classes
- Instance methods **only** (not `CLASS-METHODS`)
- All parameters must be `IMPORTING`
- Returning parameter must be named `R_RESPONSE TYPE STRING`
- Only flat scalar types and flat structures — **no nested structures**
- Always use a proxy class when the real class uses non-STRING parameter types

---

## Lessons Learned — SAP AI Core Integration

These issues were encountered when building the Batch Management Agent against SAP AI Core and are likely to affect any yaai project using AI Core.

| Issue | Root cause | Fix |
|-------|-----------|-----|
| STVARV saves values in UPPERCASE | Default TVARVC behaviour | Enable **Lowercase** checkbox on each entry in STVARV before saving — credentials are case-sensitive |
| HTTP 401 Bad Credentials | Client secret stored uppercase | Same as above — check Lowercase checkbox for `YAAI_AICORE_CLIENT_SECRET` |
| `"Subpath 'chat/completions' is not allowed"` | Non-OpenAI model deployment selected | Only GPT deployments support the OpenAI API format; use a GPT deployment (`gpt-4.1`, `gpt-4o`) with `ycl_aai_openai` |
| All deployments return HTTP 404 | Wrong path — AI Core requires `/v1/chat/completions` | Set `YAAI_AICORE_BASE_URL` to `.../inference/deployments/<id>` without `/v1`; yaai adds `/v1/chat/completions` via `use_completions( abap_true )` |
| `"We're having a little trouble..."` fallback | yaai defaults to Responses API (`/v1/responses`), not Chat Completions | Call `lo_ai->use_completions( abap_true )` after creating the `ycl_aai_openai` instance |
| SLED / `VFDAT` always blank | `MCHA` does not store shelf life dates | Read `VFDAT` and `HSDAT` from `MCH1` (cross-plant batch table); use `MCHA` only to confirm plant assignment |
