*&---------------------------------------------------------------------*
*& ZCL_YAAI_AICORE_CONN
*& Helper that fetches an OAuth2 Bearer token from SAP AI Core's
*& XSUAA token endpoint, then builds a configured YCL_AAI_CONN ready
*& for use with YCL_AAI_OPENAI (AI Core is OpenAI-API-compatible).
*&
*& Create in SE24 as PUBLIC FINAL global class.
*&
*& TVARVC entries required (STVARV):
*&   YAAI_AICORE_AUTH_URL       https://def-ai.authentication.ap10.hana.ondemand.com
*&   YAAI_AICORE_CLIENT_ID      sb-f694b84d-...
*&   YAAI_AICORE_CLIENT_SECRET  a3a3df27-...
*&   YAAI_AICORE_BASE_URL       https://api.ai.prod.ap-southeast-2.aws.ml.hana.ondemand.com/v2/inference/deployments/d8f6fe1fd20b9978
*&   YAAI_AICORE_RESOURCE_GROUP default
*&
*& The full deployment URL (including /deployments/<id>) goes into
*& YAAI_AICORE_BASE_URL — no separate deployment ID entry is needed.
*&
*& Flow:
*&   1. Read credentials from TVARVC
*&   2. POST to {AUTH_URL}/oauth/token with client_credentials grant
*&   3. Parse the returned access_token
*&   4. Create YCL_AAI_CONN, set base URL, set the token as the API key
*&      (YCL_AAI_CONN sends it as "Authorization: Bearer <token>")
*&   5. Add the "AI-Resource-Group" custom header required by AI Core
*&   6. Return the ready connection object
*&---------------------------------------------------------------------*

CLASS zcl_yaai_aicore_conn DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    "Build a ready-to-use YCL_AAI_CONN for AI Core.
    "Raises cx_root if token fetch fails.
    METHODS get_connection
      RETURNING
        VALUE(r_connection) TYPE REF TO ycl_aai_conn
      RAISING
        cx_root.

  PRIVATE SECTION.

    METHODS read_tvarvc
      IMPORTING i_name         TYPE string
      RETURNING VALUE(r_value) TYPE string.

    METHODS fetch_oauth_token
      IMPORTING
        i_auth_url      TYPE string
        i_client_id     TYPE string
        i_client_secret TYPE string
      RETURNING
        VALUE(r_token) TYPE string
      RAISING
        cx_root.

ENDCLASS.


CLASS zcl_yaai_aicore_conn IMPLEMENTATION.

  METHOD get_connection.

    DATA(lv_auth_url)       = read_tvarvc( 'YAAI_AICORE_AUTH_URL' ).
    DATA(lv_client_id)      = read_tvarvc( 'YAAI_AICORE_CLIENT_ID' ).
    DATA(lv_client_secret)  = read_tvarvc( 'YAAI_AICORE_CLIENT_SECRET' ).
    DATA(lv_base_url)       = read_tvarvc( 'YAAI_AICORE_BASE_URL' ).
    DATA(lv_resource_group) = read_tvarvc( 'YAAI_AICORE_RESOURCE_GROUP' ).

    IF lv_auth_url IS INITIAL OR lv_client_id IS INITIAL OR lv_client_secret IS INITIAL.
      RAISE EXCEPTION TYPE cx_sy_no_handler.
    ENDIF.

    DATA(lv_token) = fetch_oauth_token(
      i_auth_url      = lv_auth_url
      i_client_id     = lv_client_id
      i_client_secret = lv_client_secret
    ).

    DATA(lo_conn) = NEW ycl_aai_conn( ).

    "YAAI_AICORE_BASE_URL is the full deployment URL including /inference/deployments/<id>
    lo_conn->yif_aai_conn~set_base_url( lv_base_url ).

    "yaai sends this as: Authorization: Bearer <token>
    lo_conn->yif_aai_conn~set_api_key( i_api_key = lv_token ).

    lo_conn->yif_aai_conn~add_http_header_param(
      i_name  = 'AI-Resource-Group'
      i_value = lv_resource_group
    ).

    r_connection = lo_conn.

  ENDMETHOD.


  METHOD read_tvarvc.
    SELECT SINGLE low FROM tvarvc
      INTO @r_value
      WHERE name = @i_name
        AND type = 'P'.

    IF r_value IS INITIAL.
      SELECT SINGLE low FROM tvarvc
        INTO @r_value
        WHERE name = @i_name.
    ENDIF.

    CONDENSE r_value NO-GAPS.
  ENDMETHOD.


  METHOD fetch_oauth_token.
    DATA(lv_token_url) = |{ i_auth_url }/oauth/token|.

    DATA(lv_credentials) = |{ i_client_id }:{ i_client_secret }|.
    DATA(lv_encoded) = cl_http_utility=>encode_base64( unencoded = lv_credentials ).
    "encode_base64 may append a newline — strip it to avoid corrupting the auth header
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_encoded WITH ''.
    CONDENSE lv_encoded NO-GAPS.

    DATA lo_http TYPE REF TO if_http_client.

    cl_http_client=>create_by_url(
      EXPORTING
        url                = lv_token_url
        ssl_id             = 'ANONYM'
      IMPORTING
        client             = lo_http
      EXCEPTIONS
        argument_not_found = 1
        plugin_not_active  = 2
        internal_error     = 3
        OTHERS             = 4
    ).

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_no_handler.
    ENDIF.

    lo_http->request->set_method( 'POST' ).

    lo_http->request->set_header_field(
      name  = 'Authorization'
      value = |Basic { lv_encoded }|
    ).

    lo_http->request->set_header_field(
      name  = 'Content-Type'
      value = 'application/x-www-form-urlencoded'
    ).

    lo_http->request->set_cdata(
      data = 'grant_type=client_credentials'
    ).

    lo_http->send(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        OTHERS                     = 3
    ).

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_no_handler.
    ENDIF.

    lo_http->receive(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4
    ).

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_no_handler.
    ENDIF.

    DATA(lv_response) = lo_http->response->get_cdata( ).
    lo_http->close( ).

    "Parse access_token from JSON response by finding the value between quotes
    "Response format: {"access_token":"<token>","token_type":"Bearer",...}
    DATA: lv_search TYPE string,
          lv_pos    TYPE i,
          lv_len    TYPE i,
          lv_start  TYPE i,
          lv_rest   TYPE string,
          lv_end    TYPE i,
          lv_token  TYPE string.

    lv_search = `"access_token":"`.

    FIND lv_search IN lv_response MATCH OFFSET lv_pos MATCH LENGTH lv_len.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_no_handler.
    ENDIF.

    lv_start = lv_pos + lv_len.
    lv_rest  = lv_response+lv_start.

    FIND `"` IN lv_rest MATCH OFFSET lv_end.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_no_handler.
    ENDIF.

    lv_token = lv_rest(lv_end).

    IF lv_token IS INITIAL.
      RAISE EXCEPTION TYPE cx_sy_no_handler.
    ENDIF.

    r_token = lv_token.

  ENDMETHOD.

ENDCLASS.
