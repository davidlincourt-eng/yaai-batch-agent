*&---------------------------------------------------------------------*
*& ZYAAI_BATCH_AGENT_AICORE
*& Batch Management chatbot backed by SAP AI Core.
*&
*& This report is for direct ABAP testing (SE38 / SA38).
*& The cockpit chat UI calls the agent framework directly — see SETUP_GUIDE.
*&
*& AI Core exposes an OpenAI-compatible endpoint, so YCL_AAI_OPENAI is
*& used with the AI Core deployment URL and a fresh OAuth2 token obtained
*& via ZCL_YAAI_AICORE_CONN.
*&
*& YAAI_AICORE_BASE_URL in TVARVC must be the full deployment URL + /v1:
*&   https://api.ai.prod.ap-southeast-2.aws.ml.hana.ondemand.com/v2/inference/deployments/d8f6fe1fd20b9978
*& (gpt-4.1 — yaai appends /v1/chat/completions to form the full path)
*&---------------------------------------------------------------------*
REPORT zyaai_batch_agent_aicore.

PARAMETERS:
  p_prompt TYPE c LENGTH 250 LOWER CASE OBLIGATORY
    DEFAULT 'List all batches for material TG22 in plant 1710 that are expired'.

CLASS lcl_app DEFINITION.
  PUBLIC SECTION.
    METHODS run.
    METHODS on_tool_call FOR EVENT on_tool_call OF ycl_aai_func_call_openai
      IMPORTING class_name method_name.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.

  METHOD run.

    "------------------------------------------------------------------
    " 1. Build AI Core connection (OAuth2 token + headers)
    "------------------------------------------------------------------
    DATA lo_conn TYPE REF TO ycl_aai_conn.
    TRY.
        lo_conn = NEW zcl_yaai_aicore_conn( )->get_connection( ).
      CATCH cx_root INTO DATA(lx).
        WRITE: / |Error connecting to AI Core: { lx->get_text( ) }|.
        WRITE: / 'Check TVARVC entries: YAAI_AICORE_AUTH_URL, YAAI_AICORE_CLIENT_ID,'.
        WRITE: / 'YAAI_AICORE_CLIENT_SECRET, YAAI_AICORE_BASE_URL, YAAI_AICORE_RESOURCE_GROUP'.
        RETURN.
    ENDTRY.

    "------------------------------------------------------------------
    " 2. Create an OpenAI-compatible chat client.
    "    YAAI_AICORE_BASE_URL already contains the full deployment URL:
    "    https://api.ai.prod.../v2/inference/deployments/<id>
    "    YCL_AAI_OPENAI appends /chat/completions automatically.
    "------------------------------------------------------------------
    DATA(lo_ai) = NEW ycl_aai_openai(
      i_model        = 'gpt-4.1'
      i_o_connection = lo_conn
    ).

    "AI Core uses /chat/completions — force yaai off the Responses API default
    lo_ai->use_completions( abap_true ).

    "------------------------------------------------------------------
    " 3. System instructions: Batch Management persona
    "------------------------------------------------------------------
    DATA lv_sys TYPE string.
    lv_sys = |# Identity\n|.
    lv_sys = |{ lv_sys }You are a Batch Management Assistant for SAP Materials Management.\n|.
    lv_sys = |{ lv_sys }You help users answer questions about material batches.\n\n|.
    lv_sys = |{ lv_sys }# Scope\n|.
    lv_sys = |{ lv_sys }Answer only questions about: shelf life expiration dates (SLED),\n|.
    lv_sys = |{ lv_sys }manufacturing dates, batch classification classes and characteristics.\n|.
    lv_sys = |{ lv_sys }For anything else, say: "I can only assist with SAP batch management queries."\n\n|.
    lv_sys = |{ lv_sys }# Rules\n|.
    lv_sys = |{ lv_sys }- Always ask for material number and plant if not provided.\n|.
    lv_sys = |{ lv_sys }- Format dates as DD.MM.YYYY in your responses.\n|.
    lv_sys = |{ lv_sys }- For expiring batches with no time window, default to 30 days.\n|.
    lv_sys = |{ lv_sys }- Show "not maintained" when a characteristic value is empty.|.

    lo_ai->set_system_instructions( lv_sys ).

    "------------------------------------------------------------------
    " 4. Register batch management tools
    "------------------------------------------------------------------
    DATA(lo_tools) = NEW ycl_aai_func_call_openai( ).
    SET HANDLER me->on_tool_call FOR lo_tools.

    lo_tools->add_methods( VALUE #(
      ( proxy_class = 'ZCL_YAAI_BATCH_TOOLS_PROXY'
        class_name  = 'ZCL_YAAI_BATCH_TOOLS'
        method_name = 'GET_BATCH_HEADER'
        description = 'Retrieve header data for a specific batch: shelf life expiration date (SLED), manufacturing date, restricted status, and shelf life configuration for the material.' )
      ( proxy_class = 'ZCL_YAAI_BATCH_TOOLS_PROXY'
        class_name  = 'ZCL_YAAI_BATCH_TOOLS'
        method_name = 'GET_BATCH_CLASSIFICATION'
        description = 'Return all classification classes and characteristic values assigned to a batch (class type 023). Use this when the user asks about batch characteristics or classification.' )
      ( proxy_class = 'ZCL_YAAI_BATCH_TOOLS_PROXY'
        class_name  = 'ZCL_YAAI_BATCH_TOOLS'
        method_name = 'FIND_BATCHES_BY_SLED'
        description = 'Find all batches for a material and plant whose shelf life expiration date (SLED) falls within a given date range. Dates must be in YYYYMMDD format.' )
      ( proxy_class = 'ZCL_YAAI_BATCH_TOOLS_PROXY'
        class_name  = 'ZCL_YAAI_BATCH_TOOLS'
        method_name = 'FIND_EXPIRING_BATCHES'
        description = 'Return batches expiring within the next N days for a material and plant, sorted by SLED ascending. Default to 30 days if not specified.' )
      ( proxy_class = 'ZCL_YAAI_BATCH_TOOLS_PROXY'
        class_name  = 'ZCL_YAAI_BATCH_TOOLS'
        method_name = 'FIND_EXPIRED_BATCHES'
        description = 'Return all batches that have already passed their shelf life expiration date (SLED is in the past) for a material and plant, sorted by most recently expired first.' )
    ) ).

    lo_ai->bind_tools( lo_tools ).

    "------------------------------------------------------------------
    " 5. Send user prompt and print response
    "------------------------------------------------------------------
    lo_ai->chat(
      EXPORTING
        i_message    = p_prompt
      IMPORTING
        e_t_response = DATA(lt_response)
    ).

    WRITE: / '=== Batch Agent Response ==='.
    LOOP AT lt_response INTO DATA(lv_line).
      WRITE: / lv_line.
    ENDLOOP.

  ENDMETHOD.

  METHOD on_tool_call.
    WRITE: / |  [tool] { class_name }->{ method_name }|.
  ENDMETHOD.

ENDCLASS.

INITIALIZATION.
  %_p_prompt_%_app_%-text = 'Question'.

START-OF-SELECTION.
  NEW lcl_app( )->run( ).
