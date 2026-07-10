# yaai Initial Setup — Running YCL_AAI_BASIC_SETUP

Before using the AI Tools Cockpit, the database tables `YAAI_API`, `YAAI_MODEL`, and `YAAI_TOOL` must be populated. The class `YCL_AAI_BASIC_SETUP` does this in one step.

---

## Part 1 — Connect Eclipse to the SAP System

### 1.1 Open Eclipse

Launch Eclipse. If this is the first time, you will see a **Welcome** screen — close it by clicking the **X** on the Welcome tab.

### 1.2 Open the ABAP perspective

Eclipse uses "perspectives" to organise views for different tasks. You need the **ABAP perspective**.

1. Menu: **Window → Perspective → Open Perspective → Other...**
2. Select **ABAP** from the list → click **Open**

The left panel will change to show the **Project Explorer** for ABAP projects.

### 1.3 Create an ABAP project (first time only)

If no project appears in Project Explorer:

1. Menu: **File → New → ABAP Project**
2. In the **System Connection** dialog:
   - Click **New Connection** if your system isn't listed
   - Fill in:
     | Field | Value |
     |-------|-------|
     | System ID | `S4H` |
     | Application Server | `vhcals4hci.dummy.nodomain` |
     | Instance Number | `00` |
     | System Type | `Custom Application Server` |
   - Click **Next**
3. **Logon** screen:
   - Client: `100`
   - User: `I801786`
   - Password: your password
   - Language: `EN`
   - Click **Next**
4. **Project Name** screen: leave the default name → click **Finish**

Eclipse connects to the SAP system. You will see a project appear in the **Project Explorer** on the left.

> If you see a certificate warning when connecting, click **Trust** or **Accept** — this is expected for the `.dummy.nodomain` test system.

### 1.4 Verify the connection

The project in Project Explorer should show a green connected indicator (small plug icon). If it shows a red X, right-click the project → **Log On** and enter your credentials.

---

## Part 2 — Find and Open YCL_AAI_BASIC_SETUP

### 2.1 Open the class using Quick Search

The fastest way to find any ABAP object in Eclipse is the **Open ABAP Development Object** dialog:

1. Press **Ctrl+Shift+A** (or menu **Navigate → Open ABAP Development Object**)
2. Type `YCL_AAI_BASIC_SETUP`
3. The class will appear in the results — select it and click **OK**

The class source code opens in the editor.

### 2.2 Alternative — Navigate via Project Explorer

If the search doesn't find it:

1. Expand your project in **Project Explorer**
2. Expand **Dictionary Objects** or browse to the yaai package
3. Right-click the project → **Find/Replace in ABAP Repository** → search for `YCL_AAI_BASIC_SETUP`

---

## Part 3 — Run the Class

### 3.1 Run with F9

With `YCL_AAI_BASIC_SETUP` open in the editor:

1. Press **F9** — this runs the class as an ABAP console application
2. If prompted to select a run configuration, choose **ABAP Application (Console)** → click **OK**
3. Eclipse will connect to the SAP system and execute the `MAIN` method

### 3.2 Check the Console output

The **Console** view opens automatically at the bottom of the screen. You should see output similar to:

```
Setup complete.
YAAI_API: 5 records inserted.
YAAI_MODEL: 10 records inserted.
YAAI_TOOL: 12 records inserted.
```

If you see an error like `Table already contains records`, the setup has already been run — check the data in SE16 (see Part 4) before running again to avoid duplicates.

> **If F9 does nothing:** Click anywhere in the editor to make sure the class is in focus, then try again. Alternatively use menu **Run → Run As → ABAP Application (Console)**.

---

## Part 4 — Verify the Data

Open **SAP GUI** and run transaction **SE16** to confirm the tables were populated:

| Table | Expected rows | What to check |
|-------|--------------|---------------|
| `YAAI_API` | 5 | OpenAI, Anthropic, Google, Mistral, Ollama entries |
| `YAAI_MODEL` | 10 | Models mapped to each provider |
| `YAAI_TOOL` | 12 | Internal yaai tool definitions |

---

## Part 5 — What was inserted

### YAAI_API — LLM provider endpoints

| API | Base URL |
|-----|---------|
| OpenAI | `https://api.openai.com` |
| Anthropic | `https://api.anthropic.com` |
| Google | `https://generativelanguage.googleapis.com` |
| Mistral | `https://api.mistral.ai` |
| Ollama | `http://192.168.1.173:11434` |

> **Note:** After running, update the **OpenAI** entry in the cockpit (**LLM APIs** section) to point to your SAP AI Core deployment URL. See [SETUP_GUIDE.md](SETUP_GUIDE.md) Step 3.

### YAAI_MODEL — Default models per provider

| Provider | Default Model |
|---------|--------------|
| OpenAI | gpt-5.4-mini |
| Anthropic | claude-sonnet-4-6 |
| Google | gemini-2.5-flash |
| Mistral | mistral-medium-latest |
| Ollama | gemma3:1b |

> **Note:** Update the OpenAI model to `gpt-4.1` in the cockpit after setup.

### YAAI_TOOL — Built-in yaai tools

12 tool definitions covering function calling, RAG document access, planning, and task management. These are internal yaai tools used by the agent framework and do not need to be modified.

---

## Part 6 — After Setup

1. Open the cockpit:
   ```
   https://vhcals4hci.dummy.nodomain:44300/sap/bc/ui5_ui5/sap/yaai_cockpit/index.html?sap-client=100
   ```
2. Navigate to **LLM APIs** — you should now see the 5 providers listed.
3. Update the **OpenAI** entry to point to AI Core:
   - **Base URL**: `https://api.ai.prod.ap-southeast-2.aws.ml.hana.ondemand.com/v2/inference/deployments/d8f6fe1fd20b9978`
   - **Model**: `gpt-4.1`
4. Continue with [SETUP_GUIDE.md](SETUP_GUIDE.md) to configure the Batch Management Agent.
