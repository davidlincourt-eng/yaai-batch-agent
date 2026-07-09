*&---------------------------------------------------------------------*
*& Example 1: Simple Chat (Hello World)
*& Sends a single message via SAP AI Core and prints the response.
*&
*& Prerequisites:
*&   - TVARVC entries in STVARV (Lowercase checkbox enabled for all):
*&       YAAI_AICORE_AUTH_URL       https://def-ai.authentication.ap10.hana.ondemand.com
*&       YAAI_AICORE_CLIENT_ID      sb-f694b84d-...
*&       YAAI_AICORE_CLIENT_SECRET  a3a3df27-...
*&       YAAI_AICORE_BASE_URL       https://api.ai.prod.../v2/inference/deployments/<id>
*&       YAAI_AICORE_RESOURCE_GROUP default
*&   - SSL certs imported in STRUST (see batch_agent/certs/)
*&   - ZCL_YAAI_AICORE_CONN active in SE24
*&---------------------------------------------------------------------*
REPORT zyaai_ex1_simple_chat.

START-OF-SELECTION.

  DATA lo_conn TYPE REF TO ycl_aai_conn.
  TRY.
      lo_conn = NEW zcl_yaai_aicore_conn( )->get_connection( ).
    CATCH cx_root INTO DATA(lx).
      WRITE: / |Connection error: { lx->get_text( ) }|.
      RETURN.
  ENDTRY.

  DATA(lo_ai) = NEW ycl_aai_openai(
    i_model        = 'gpt-4.1'
    i_o_connection = lo_conn
  ).
  lo_ai->use_completions( abap_true ).

  lo_ai->chat(
    EXPORTING
      i_message    = 'What is SAP ABAP in one sentence?'
    IMPORTING
      e_t_response = DATA(lt_response)
  ).

  LOOP AT lt_response INTO DATA(lv_line).
    WRITE: / lv_line.
  ENDLOOP.
