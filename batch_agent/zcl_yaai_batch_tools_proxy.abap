*&---------------------------------------------------------------------*
*& ZCL_YAAI_BATCH_TOOLS_PROXY
*& Proxy that receives all parameters as STRING (as the LLM sends them),
*& converts to the correct ABAP types, then delegates to the real class.
*& Create in SE24 as a PUBLIC FINAL global class.
*&
*& Date parameters: LLM must pass dates as YYYYMMDD (e.g. '20251231').
*& Integer parameters: LLM must pass plain numbers (e.g. '30').
*&---------------------------------------------------------------------*

CLASS zcl_yaai_batch_tools_proxy DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS get_batch_header
      IMPORTING
        i_matnr TYPE string   "Material number
        i_werks TYPE string   "Plant
        i_charg TYPE string   "Batch number
      RETURNING
        VALUE(r_response) TYPE string.

    METHODS get_batch_classification
      IMPORTING
        i_matnr TYPE string
        i_werks TYPE string
        i_charg TYPE string
      RETURNING
        VALUE(r_response) TYPE string.

    METHODS find_batches_by_sled
      IMPORTING
        i_matnr     TYPE string   "Material number
        i_werks     TYPE string   "Plant
        i_sled_from TYPE string   "Start date YYYYMMDD
        i_sled_to   TYPE string   "End date YYYYMMDD
      RETURNING
        VALUE(r_response) TYPE string.

    METHODS find_expiring_batches
      IMPORTING
        i_matnr TYPE string   "Material number
        i_werks TYPE string   "Plant
        i_days  TYPE string   "Number of days look-ahead
      RETURNING
        VALUE(r_response) TYPE string.

    METHODS find_expired_batches
      IMPORTING
        i_matnr TYPE string   "Material number
        i_werks TYPE string   "Plant
      RETURNING
        VALUE(r_response) TYPE string.

ENDCLASS.

CLASS zcl_yaai_batch_tools_proxy IMPLEMENTATION.

  METHOD get_batch_header.
    DATA: lv_matnr TYPE matnr,
          lv_werks TYPE werks_d,
          lv_charg TYPE charg_d.

    lv_matnr = i_matnr.
    lv_werks = i_werks.
    lv_charg = i_charg.

    r_response = NEW zcl_yaai_batch_tools( )->get_batch_header(
      i_matnr = lv_matnr
      i_werks = lv_werks
      i_charg = lv_charg
    ).
  ENDMETHOD.


  METHOD get_batch_classification.
    DATA: lv_matnr TYPE matnr,
          lv_werks TYPE werks_d,
          lv_charg TYPE charg_d.

    lv_matnr = i_matnr.
    lv_werks = i_werks.
    lv_charg = i_charg.

    r_response = NEW zcl_yaai_batch_tools( )->get_batch_classification(
      i_matnr = lv_matnr
      i_werks = lv_werks
      i_charg = lv_charg
    ).
  ENDMETHOD.


  METHOD find_batches_by_sled.
    DATA: lv_matnr     TYPE matnr,
          lv_werks     TYPE werks_d,
          lv_sled_from TYPE d,
          lv_sled_to   TYPE d.

    lv_matnr = i_matnr.
    lv_werks = i_werks.

    "Date arrives as YYYYMMDD string — direct assignment to TYPE d works
    TRY.
        lv_sled_from = i_sled_from.
        lv_sled_to   = i_sled_to.
      CATCH cx_root.
        r_response = 'Error: date parameters must be in YYYYMMDD format (e.g. 20251231)'.
        RETURN.
    ENDTRY.

    r_response = NEW zcl_yaai_batch_tools( )->find_batches_by_sled(
      i_matnr     = lv_matnr
      i_werks     = lv_werks
      i_sled_from = lv_sled_from
      i_sled_to   = lv_sled_to
    ).
  ENDMETHOD.


  METHOD find_expiring_batches.
    DATA: lv_matnr TYPE matnr,
          lv_werks TYPE werks_d,
          lv_days  TYPE i.

    lv_matnr = i_matnr.
    lv_werks = i_werks.

    TRY.
        lv_days = i_days.
      CATCH cx_sy_conversion_no_number.
        r_response = 'Error: days parameter must be a whole number (e.g. 30)'.
        RETURN.
    ENDTRY.

    r_response = NEW zcl_yaai_batch_tools( )->find_expiring_batches(
      i_matnr = lv_matnr
      i_werks = lv_werks
      i_days  = lv_days
    ).
  ENDMETHOD.


  METHOD find_expired_batches.
    DATA: lv_matnr TYPE matnr,
          lv_werks TYPE werks_d.

    lv_matnr = i_matnr.
    lv_werks = i_werks.

    r_response = NEW zcl_yaai_batch_tools( )->find_expired_batches(
      i_matnr = lv_matnr
      i_werks = lv_werks
    ).
  ENDMETHOD.

ENDCLASS.
