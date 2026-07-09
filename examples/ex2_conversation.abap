*&---------------------------------------------------------------------*
*& Example 2: Multi-Turn Conversation with History
*& Demonstrates a selection-screen driven chat loop that keeps
*& in-memory conversation history, then prints the full history as JSON.
*&
*& Run it multiple times (F8) with different prompts to continue the
*& conversation. Use a new program instance for a fresh session.
*&---------------------------------------------------------------------*
REPORT zyaai_ex2_conversation.

PARAMETERS:
  p_msg TYPE c LENGTH 200 LOWER CASE OBLIGATORY.

CLASS lcl_app DEFINITION.
  PUBLIC SECTION.
    METHODS run.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.
  METHOD run.

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

    "Send user message
    lo_ai->chat(
      EXPORTING
        i_message    = p_msg
      IMPORTING
        e_t_response = DATA(lt_response)
    ).

    "---- Print latest reply ----
    WRITE: / '=== Reply ==='.
    LOOP AT lt_response INTO DATA(lv_line).
      WRITE: / lv_line.
    ENDLOOP.

    "---- Print full conversation history as JSON ----
    DATA(lo_conversation) = lo_ai->get_conversation( ).
    DATA(lv_json) = /ui2/cl_json=>serialize(
      data        = lo_conversation
      pretty_name = /ui2/cl_json=>pretty_mode-low_case
      compress    = abap_false
    ).

    WRITE: / ''.
    WRITE: / '=== Full Conversation (JSON) ==='.
    DATA: lv_offset TYPE i VALUE 0,
          lv_chunk  TYPE string.
    DO.
      lv_chunk = lv_json+lv_offset(250).
      IF lv_chunk IS INITIAL.
        EXIT.
      ENDIF.
      WRITE: / lv_chunk.
      lv_offset = lv_offset + 250.
    ENDDO.

  ENDMETHOD.
ENDCLASS.

INITIALIZATION.
  %_p_msg_%_app_%-text = 'Your message'.

START-OF-SELECTION.
  NEW lcl_app( )->run( ).
