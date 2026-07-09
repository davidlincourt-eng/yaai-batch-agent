*&---------------------------------------------------------------------*
*& Example 4b: Function Calling — Proxy class for ZCL_YAAI_CALCULATOR
*& yaai always passes LLM-generated values as STRING, so the proxy
*& does the type conversion and then delegates to the real class.
*& Create this as ZCL_YAAI_CALCULATOR_PROXY in SE24.
*&---------------------------------------------------------------------*

* CLASS zcl_yaai_calculator_proxy DEFINITION
*   PUBLIC
*   FINAL
*   CREATE PUBLIC.
*
*   PUBLIC SECTION.
*     METHODS add
*       IMPORTING
*         i_a TYPE string
*         i_b TYPE string
*       RETURNING
*         VALUE(r_response) TYPE string.
*
*     METHODS multiply
*       IMPORTING
*         i_a TYPE string
*         i_b TYPE string
*       RETURNING
*         VALUE(r_response) TYPE string.
* ENDCLASS.
*
* CLASS zcl_yaai_calculator_proxy IMPLEMENTATION.
*
*   METHOD add.
*     DATA: lv_a TYPE p DECIMALS 2,
*           lv_b TYPE p DECIMALS 2.
*     TRY.
*         lv_a = i_a.
*         lv_b = i_b.
*       CATCH cx_sy_conversion_no_number.
*         r_response = 'Error: invalid number'.
*         RETURN.
*     ENDTRY.
*     r_response = NEW zcl_yaai_calculator( )->add( i_a = lv_a i_b = lv_b ).
*   ENDMETHOD.
*
*   METHOD multiply.
*     DATA: lv_a TYPE p DECIMALS 2,
*           lv_b TYPE p DECIMALS 2.
*     TRY.
*         lv_a = i_a.
*         lv_b = i_b.
*       CATCH cx_sy_conversion_no_number.
*         r_response = 'Error: invalid number'.
*         RETURN.
*     ENDTRY.
*     r_response = NEW zcl_yaai_calculator( )->multiply( i_a = lv_a i_b = lv_b ).
*   ENDMETHOD.
*
* ENDCLASS.
