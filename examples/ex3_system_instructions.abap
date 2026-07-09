*&---------------------------------------------------------------------*
*& Example 3: System Instructions
*& The model is given a persona (SAP MM support agent) via system
*& instructions before the first user message is sent.
*&---------------------------------------------------------------------*
REPORT zyaai_ex3_system_instructions.

CLASS lcl_app DEFINITION.
  PUBLIC SECTION.
    METHODS run.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.
  METHOD run.

    DATA lv_sys TYPE string.

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

    "Build system instructions
    lv_sys = |# Identity\n|.
    lv_sys = |{ lv_sys }You are a knowledgeable and approachable support agent for SAP Materials Management (MM).\n|.
    lv_sys = |{ lv_sys }\n|.
    lv_sys = |{ lv_sys }# Instructions\n|.
    lv_sys = |{ lv_sys }- Assist users exclusively with SAP MM topics: procurement, inventory, master data, invoices.\n|.
    lv_sys = |{ lv_sys }- Keep answers concise and avoid jargon unless the user is clearly an expert.\n|.
    lv_sys = |{ lv_sys }- If a question is outside SAP MM scope, reply exactly:\n|.
    lv_sys = |{ lv_sys }  "I'm not sure about that, but I can escalate this to an SAP MM specialist."\n|.

    lo_ai->set_system_instructions( lv_sys ).

    "First user message
    lo_ai->chat(
      EXPORTING
        i_message    = 'How do I create a Purchase Order in SAP?'
      IMPORTING
        e_t_response = DATA(lt_response)
    ).

    WRITE: / '=== Response (with SAP MM persona) ==='.
    LOOP AT lt_response INTO DATA(lv_line).
      WRITE: / lv_line.
    ENDLOOP.

    "Second message in same session (tests follow-up in persona)
    lo_ai->chat(
      EXPORTING
        i_message    = 'Can you also help me plan a birthday party?'
      IMPORTING
        e_t_response = lt_response
    ).

    WRITE: / ''.
    WRITE: / '=== Response (out-of-scope question) ==='.
    LOOP AT lt_response INTO lv_line.
      WRITE: / lv_line.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  NEW lcl_app( )->run( ).
