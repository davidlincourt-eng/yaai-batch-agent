*&---------------------------------------------------------------------*
*& Example 3: System Instructions
*& Claude is given a persona (SAP MM support agent) via system
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

    DATA(lo_conn) = NEW ycl_aai_conn( i_api = yif_aai_const=>c_anthropic ).

    DATA(lo_claude) = NEW ycl_aai_anthropic(
      i_model        = 'claude-3-5-sonnet-20241022'
      i_o_connection = lo_conn
    ).

    "Build system instructions (multi-line string via concatenation)
    lv_sys = |# Identity\n|.
    lv_sys = |{ lv_sys }You are a knowledgeable and approachable support agent for SAP Materials Management (MM).\n|.
    lv_sys = |{ lv_sys }\n|.
    lv_sys = |{ lv_sys }# Instructions\n|.
    lv_sys = |{ lv_sys }- Assist users exclusively with SAP MM topics: procurement, inventory, master data, invoices.\n|.
    lv_sys = |{ lv_sys }- Keep answers concise and avoid jargon unless the user is clearly an expert.\n|.
    lv_sys = |{ lv_sys }- If a question is outside SAP MM scope, reply exactly:\n|.
    lv_sys = |{ lv_sys }  "I'm not sure about that, but I can escalate this to an SAP MM specialist."\n|.

    lo_claude->set_system_instructions( lv_sys ).

    "First user message
    lo_claude->chat(
      EXPORTING
        i_message    = 'How do I create a Purchase Order in SAP?'
      IMPORTING
        e_t_response = DATA(lt_response)
    ).

    WRITE: / '=== Claude (with SAP MM persona) ==='.
    LOOP AT lt_response INTO DATA(lv_line).
      WRITE: / lv_line.
    ENDLOOP.

    "Second message in same session (tests follow-up in persona)
    lo_claude->chat(
      EXPORTING
        i_message    = 'Can you also help me plan a birthday party?'
      IMPORTING
        e_t_response = lt_response
    ).

    WRITE: / ''.
    WRITE: / '=== Claude (out-of-scope question) ==='.
    LOOP AT lt_response INTO lv_line.
      WRITE: / lv_line.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  NEW lcl_app( )->run( ).
