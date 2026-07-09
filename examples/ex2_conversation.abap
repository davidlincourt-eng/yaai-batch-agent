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
  p_model  TYPE c LENGTH 50  LOWER CASE DEFAULT 'claude-3-5-sonnet-20241022',
  p_msg    TYPE c LENGTH 200 LOWER CASE OBLIGATORY.

CLASS lcl_app DEFINITION.
  PUBLIC SECTION.
    METHODS run.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.
  METHOD run.

    DATA(lo_conn) = NEW ycl_aai_conn( i_api = yif_aai_const=>c_anthropic ).

    DATA(lo_claude) = NEW ycl_aai_anthropic(
      i_model        = p_model
      i_o_connection = lo_conn
    ).

    "Send user message
    lo_claude->chat(
      EXPORTING
        i_message    = p_msg
      IMPORTING
        e_t_response = DATA(lt_response)
    ).

    "---- Print latest reply ----
    WRITE: / '=== Claude Reply ==='.
    LOOP AT lt_response INTO DATA(lv_line).
      WRITE: / lv_line.
    ENDLOOP.

    "---- Print full conversation history as JSON ----
    DATA(lo_conversation) = lo_claude->get_conversation( ).
    DATA(lv_json) = /ui2/cl_json=>serialize(
      data             = lo_conversation
      pretty_name      = /ui2/cl_json=>pretty_mode-low_case
      compress         = abap_false
    ).

    WRITE: / ''.
    WRITE: / '=== Full Conversation (JSON) ==='.
    "Print in chunks because WRITE has a line length limit
    DATA lv_offset TYPE i VALUE 0.
    DATA lv_chunk  TYPE string.
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
  %_p_model_%_app_%-text = 'Model'.
  %_p_msg_%_app_%-text   = 'Your message'.

START-OF-SELECTION.
  NEW lcl_app( )->run( ).
