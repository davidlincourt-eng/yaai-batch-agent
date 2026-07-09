*&---------------------------------------------------------------------*
*& Example 1: Simple Chat (Hello World)
*& Sends a single message to Claude and prints the response.
*&
*& Prerequisites:
*&   - TVARVC entry  YAAI_ANTHROPIC_BASE_URL = 'https://api.anthropic.com'
*&   - TVARVC entry  YAAI_ANTHROPIC_API_KEY  = '<your-key>'  (or use env var)
*&   - SSL cert for api.anthropic.com imported in STRUST (SSL client PSE)
*&---------------------------------------------------------------------*
REPORT zyaai_ex1_simple_chat.

START-OF-SELECTION.

  "Connection is auto-configured from TVARVC when i_api = 'ANTHROPIC'
  DATA(lo_conn) = NEW ycl_aai_conn( i_api = yif_aai_const=>c_anthropic ).

  DATA(lo_claude) = NEW ycl_aai_anthropic(
    i_model        = 'claude-3-5-sonnet-20241022'
    i_o_connection = lo_conn
  ).

  lo_claude->chat(
    EXPORTING
      i_message    = 'What is SAP ABAP in one sentence?'
    IMPORTING
      e_t_response = DATA(lt_response)
  ).

  LOOP AT lt_response INTO DATA(lv_line).
    WRITE: / lv_line.
  ENDLOOP.
