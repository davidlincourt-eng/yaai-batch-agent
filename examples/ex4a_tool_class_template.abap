*&---------------------------------------------------------------------*
*& Example 4a: Function Calling - Tool (global class)
*& This global class must be created in SE24 BEFORE running ex4_func_call.
*&
*& Rules enforced by yaai:
*&   - Instance methods only (not static)
*&   - IMPORTING parameters only (no CHANGING / TABLES)
*&   - Exactly one RETURNING parameter named R_RESPONSE of type STRING
*&   - Flat parameter types only (no nested structures / deep tables)
*&
*& Create this as global class ZCL_YAAI_CALCULATOR in SE24.
*&---------------------------------------------------------------------*

*---- Global class ZCL_YAAI_CALCULATOR (create in SE24) ----

* CLASS zcl_yaai_calculator DEFINITION
*   PUBLIC
*   FINAL
*   CREATE PUBLIC.
*
*   PUBLIC SECTION.
*     METHODS add
*       IMPORTING
*         i_a TYPE p DECIMALS 2
*         i_b TYPE p DECIMALS 2
*       RETURNING
*         VALUE(r_response) TYPE string.
*
*     METHODS multiply
*       IMPORTING
*         i_a TYPE p DECIMALS 2
*         i_b TYPE p DECIMALS 2
*       RETURNING
*         VALUE(r_response) TYPE string.
* ENDCLASS.
*
* CLASS zcl_yaai_calculator IMPLEMENTATION.
*
*   METHOD add.
*     DATA(lv_result) = i_a + i_b.
*     r_response = |{ i_a } + { i_b } = { lv_result }|.
*   ENDMETHOD.
*
*   METHOD multiply.
*     DATA(lv_result) = i_a * i_b.
*     r_response = |{ i_a } × { i_b } = { lv_result }|.
*   ENDMETHOD.
*
* ENDCLASS.
