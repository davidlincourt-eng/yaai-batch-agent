REPORT zyaai_chat_diag.

"Simple chat diagnostic - no tools, shows raw HTTP response.
"Use to confirm basic AI Core connectivity before testing tool calling.

START-OF-SELECTION.

  DATA lo_conn TYPE REF TO ycl_aai_conn.

  TRY.
      lo_conn = NEW zcl_yaai_aicore_conn( )->get_connection( ).
    CATCH cx_root INTO DATA(lx_conn).
      WRITE: / |Connection error: { lx_conn->get_text( ) }|.
      RETURN.
  ENDTRY.

  WRITE: / |Base URL: { lo_conn->yif_aai_conn~m_base_url }|.
  WRITE: / ''.

  "--- Test 1: basic chat via yaai ---
  WRITE: / '--- Test 1: Basic chat via yaai ---'.

  DATA(lo_ai) = NEW ycl_aai_openai(
    i_model        = 'gpt-4.1'
    i_o_connection = lo_conn
  ).

  "AI Core uses /chat/completions — force yaai off the Responses API default
  lo_ai->use_completions( abap_true ).

  lo_ai->chat(
    EXPORTING
      i_message    = 'What is 2 plus 2? Reply with just the number.'
    IMPORTING
      e_t_response = DATA(lt_response)
  ).

  WRITE: / |Response lines: { lines( lt_response ) }|.
  LOOP AT lt_response INTO DATA(lv_line).
    WRITE: / lv_line.
  ENDLOOP.

  WRITE: / ''.

  "--- Test 2: raw HTTP call bypassing yaai parsing ---
  WRITE: / '--- Test 2: Raw HTTP call to chat/completions ---'.

  "Re-fetch a fresh connection (token may be consumed)
  DATA lo_conn2 TYPE REF TO ycl_aai_conn.
  TRY.
      lo_conn2 = NEW zcl_yaai_aicore_conn( )->get_connection( ).
    CATCH cx_root.
      WRITE: / 'Could not get second connection'.
      RETURN.
  ENDTRY.

  DATA: lo_http  TYPE REF TO if_http_client,
        lv_url   TYPE string,
        lv_body  TYPE string,
        lv_resp  TYPE string,
        lv_status TYPE i.

  "Get the bearer token from the connection headers
  DATA(lt_headers) = lo_conn2->yif_aai_conn~mt_http_header.
  DATA lv_token TYPE string.
  LOOP AT lt_headers INTO DATA(ls_hdr) WHERE name = 'AI-Resource-Group'.
  ENDLOOP.
  "Token is set as API key (Authorization header) - read base url
  DATA(lv_base) = lo_conn2->yif_aai_conn~m_base_url.

  "Build the full chat/completions URL
  lv_url = |{ lv_base }/chat/completions|.
  WRITE: / |Request URL: { lv_url }|.

  "Simple request body
  lv_body = '{"model":"gpt-4.1","messages":[{"role":"user","content":"Reply with exactly: OK"}],"max_tokens":10}'.

  cl_http_client=>create_by_url(
    EXPORTING url = lv_url ssl_id = 'ANONYM'
    IMPORTING client = lo_http
    EXCEPTIONS OTHERS = 4
  ).

  IF sy-subrc <> 0.
    WRITE: / 'ERROR: Could not create HTTP client'.
    RETURN.
  ENDIF.

  lo_http->request->set_method( 'POST' ).
  lo_http->request->set_header_field( name = 'Content-Type'      value = 'application/json' ).
  lo_http->request->set_header_field( name = 'AI-Resource-Group' value = 'default' ).
  DATA lo_conn3 TYPE REF TO ycl_aai_conn.
  TRY.
      lo_conn3 = NEW zcl_yaai_aicore_conn( )->get_connection( ).
      "The token was set via set_api_key - get it from the API key object
      DATA lv_bearer TYPE string.
      "Reconstruct by fetching token fresh via inner class - use STVARV values directly
      DATA: lv_auth_url TYPE string,
            lv_cid      TYPE string,
            lv_csec     TYPE string.
      SELECT SINGLE low FROM tvarvc INTO @lv_auth_url WHERE name = 'YAAI_AICORE_AUTH_URL'.
      SELECT SINGLE low FROM tvarvc INTO @lv_cid      WHERE name = 'YAAI_AICORE_CLIENT_ID'.
      SELECT SINGLE low FROM tvarvc INTO @lv_csec     WHERE name = 'YAAI_AICORE_CLIENT_SECRET'.

      DATA(lv_creds)   = |{ lv_cid }:{ lv_csec }|.
      DATA(lv_encoded) = cl_http_utility=>encode_base64( unencoded = lv_creds ).
      REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_encoded WITH ''.
      CONDENSE lv_encoded NO-GAPS.

      DATA lo_thttp TYPE REF TO if_http_client.
      cl_http_client=>create_by_url(
        EXPORTING url = |{ lv_auth_url }/oauth/token| ssl_id = 'ANONYM'
        IMPORTING client = lo_thttp
        EXCEPTIONS OTHERS = 4
      ).
      lo_thttp->request->set_method( 'POST' ).
      lo_thttp->request->set_header_field( name = 'Authorization'  value = |Basic { lv_encoded }| ).
      lo_thttp->request->set_header_field( name = 'Content-Type'   value = 'application/x-www-form-urlencoded' ).
      lo_thttp->request->set_cdata( data = 'grant_type=client_credentials' ).
      lo_thttp->send( EXCEPTIONS OTHERS = 3 ).
      lo_thttp->receive( EXCEPTIONS OTHERS = 4 ).
      DATA(lv_tresp) = lo_thttp->response->get_cdata( ).
      lo_thttp->close( ).

      "Parse token
      DATA: lv_pos TYPE i, lv_len TYPE i, lv_start TYPE i,
            lv_rest TYPE string, lv_end TYPE i.
      FIND `"access_token":"` IN lv_tresp MATCH OFFSET lv_pos MATCH LENGTH lv_len.
      lv_start = lv_pos + lv_len.
      lv_rest  = lv_tresp+lv_start.
      FIND `"` IN lv_rest MATCH OFFSET lv_end.
      lv_bearer = lv_rest(lv_end).

    CATCH cx_root.
      WRITE: / 'Could not fetch token for raw call'.
      RETURN.
  ENDTRY.

  lo_http->request->set_header_field( name = 'Authorization' value = |Bearer { lv_bearer }| ).
  lo_http->request->set_cdata( data = lv_body ).

  lo_http->send( EXCEPTIONS OTHERS = 3 ).
  IF sy-subrc <> 0.
    WRITE: / 'ERROR: send failed'.
    RETURN.
  ENDIF.

  lo_http->receive( EXCEPTIONS OTHERS = 4 ).
  lo_http->response->get_status( IMPORTING code = lv_status ).
  lv_resp = lo_http->response->get_cdata( ).
  lo_http->close( ).

  WRITE: / |HTTP status: { lv_status }|.
  WRITE: / 'Raw response (full):'.
  "Print in 200-char chunks to avoid line length limit
  DATA: lv_offset TYPE i VALUE 0,
        lv_chunk  TYPE string.
  DATA(lv_resp_len) = strlen( lv_resp ).
  WHILE lv_offset < lv_resp_len.
    DATA(lv_remaining) = lv_resp_len - lv_offset.
    DATA(lv_chunk_len) = COND i( WHEN lv_remaining > 200 THEN 200 ELSE lv_remaining ).
    lv_chunk = lv_resp+lv_offset(lv_chunk_len).
    WRITE: / lv_chunk.
    lv_offset = lv_offset + lv_chunk_len.
  ENDWHILE.

