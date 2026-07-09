*&---------------------------------------------------------------------*
*& ZYAAI_TOKEN_DIAG
*& Diagnostic report — tests XSUAA token fetch and shows exactly
*& what is being read from TVARVC and what the API returns.
*& Run in SE38, check output to diagnose auth failures.
*&---------------------------------------------------------------------*
REPORT zyaai_token_diag.

START-OF-SELECTION.

  "--- 1. Read and display TVARVC values ---
  DATA lv_val TYPE string.

  SELECT SINGLE low FROM tvarvc INTO @lv_val WHERE name = 'YAAI_AICORE_AUTH_URL'.
  WRITE: / |AUTH_URL    ({ strlen( lv_val ) } chars): { lv_val }|.

  SELECT SINGLE low FROM tvarvc INTO @lv_val WHERE name = 'YAAI_AICORE_CLIENT_ID'.
  WRITE: / |CLIENT_ID   ({ strlen( lv_val ) } chars): { lv_val }|.

  SELECT SINGLE low FROM tvarvc INTO @lv_val WHERE name = 'YAAI_AICORE_CLIENT_SECRET'.
  WRITE: / |SECRET      ({ strlen( lv_val ) } chars): { lv_val }|.

  SELECT SINGLE low FROM tvarvc INTO @lv_val WHERE name = 'YAAI_AICORE_BASE_URL'.
  WRITE: / |BASE_URL    ({ strlen( lv_val ) } chars): { lv_val }|.

  WRITE: / ''.
  WRITE: / '--- Raw TVARVC field length check ---'.

  "Check the actual field length of TVARVC-LOW in this system
  DATA lr_descr TYPE REF TO cl_abap_elemdescr.
  lr_descr ?= cl_abap_typedescr=>describe_by_data( lv_val ).
  WRITE: / |TVARVC-LOW field length: { lr_descr->length }|.

  WRITE: / ''.
  WRITE: / '--- Token fetch ---'.

  "--- 2. Attempt token fetch and show raw response ---
  DATA: lv_auth_url     TYPE string,
        lv_client_id    TYPE string,
        lv_secret       TYPE string.

  SELECT SINGLE low FROM tvarvc INTO @lv_auth_url WHERE name = 'YAAI_AICORE_AUTH_URL'.
  SELECT SINGLE low FROM tvarvc INTO @lv_client_id WHERE name = 'YAAI_AICORE_CLIENT_ID'.
  SELECT SINGLE low FROM tvarvc INTO @lv_secret    WHERE name = 'YAAI_AICORE_CLIENT_SECRET'.

  DATA(lv_credentials) = |{ lv_client_id }:{ lv_secret }|.
  DATA(lv_encoded) = cl_http_utility=>encode_base64( unencoded = lv_credentials ).
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_encoded WITH ''.
  CONDENSE lv_encoded NO-GAPS.

  WRITE: / |Credential string length: { strlen( lv_credentials ) }|.
  WRITE: / |Encoded length: { strlen( lv_encoded ) }|.

  DATA lo_http TYPE REF TO if_http_client.
  DATA(lv_token_url) = |{ lv_auth_url }/oauth/token|.

  cl_http_client=>create_by_url(
    EXPORTING
      url    = lv_token_url
      ssl_id = 'ANONYM'
    IMPORTING
      client = lo_http
    EXCEPTIONS
      OTHERS = 4
  ).

  IF sy-subrc <> 0.
    WRITE: / 'ERROR: Could not create HTTP client (check SSL cert for auth URL)'.
    RETURN.
  ENDIF.

  lo_http->request->set_method( 'POST' ).
  lo_http->request->set_header_field( name = 'Authorization'  value = |Basic { lv_encoded }| ).
  lo_http->request->set_header_field( name = 'Content-Type'   value = 'application/x-www-form-urlencoded' ).
  lo_http->request->set_cdata( data = 'grant_type=client_credentials' ).

  lo_http->send( EXCEPTIONS OTHERS = 3 ).
  IF sy-subrc <> 0.
    WRITE: / 'ERROR: HTTP send failed (network/SSL issue)'.
    RETURN.
  ENDIF.

  lo_http->receive( EXCEPTIONS OTHERS = 4 ).
  IF sy-subrc <> 0.
    WRITE: / 'ERROR: HTTP receive failed'.
    RETURN.
  ENDIF.

  DATA lv_status TYPE i.
  lo_http->response->get_status( IMPORTING code = lv_status ).
  DATA(lv_response) = lo_http->response->get_cdata( ).
  lo_http->close( ).

  WRITE: / |HTTP status: { lv_status }|.
  WRITE: / 'Response body:'.
  WRITE: / lv_response.
