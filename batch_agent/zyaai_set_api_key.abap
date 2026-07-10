REPORT zyaai_set_api_key.

"Stores (or replaces) the AI Core Bearer token in YAAI_API_KEY for OPENAI.
"Deletes any existing entry first, then inserts the new token.
"Token expires after ~12 hours — re-run with a new token when it expires.

START-OF-SELECTION.

  DATA(lv_token) = `eyJ0eXAiOiJKV1Qi...`.  "paste your full token here

  DATA(lo_key) = NEW ycl_aai_api_key( ).

  "Delete existing entry first (INSERT fails silently on duplicate)
  lo_key->delete( i_id = 'OPENAI' ).

  lo_key->create(
    EXPORTING
      i_id      = 'OPENAI'
      i_api_key = lv_token
  ).

  WRITE: / 'API key stored for OPENAI.'.
