*&---------------------------------------------------------------------*
*& ZCL_YAAI_BATCH_TOOLS
*& Real business logic class for batch management queries.
*& Create in SE24 as a PUBLIC FINAL global class.
*&
*& Rules:
*&   - Instance methods only
*&   - All IMPORTING params typed correctly (proxy handles STRING conversion)
*&   - RETURNING parameter must be named R_RESPONSE TYPE STRING
*&---------------------------------------------------------------------*

CLASS zcl_yaai_batch_tools DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    "Returns header data for a single batch: SLED, manufacturing date,
    "remaining shelf life, total shelf life, and batch status.
    METHODS get_batch_header
      IMPORTING
        i_matnr TYPE matnr    "Material number
        i_werks TYPE werks_d  "Plant
        i_charg TYPE charg_d  "Batch number
      RETURNING
        VALUE(r_response) TYPE string.

    "Returns all classification characteristics and their values
    "for a given batch (class type 023).
    METHODS get_batch_classification
      IMPORTING
        i_matnr TYPE matnr
        i_werks TYPE werks_d
        i_charg TYPE charg_d
      RETURNING
        VALUE(r_response) TYPE string.

    "Returns a list of batches for a material/plant filtered by
    "shelf life expiration date range (dates as YYYYMMDD strings).
    METHODS find_batches_by_sled
      IMPORTING
        i_matnr     TYPE matnr
        i_werks     TYPE werks_d
        i_sled_from TYPE d        "Earliest SLED (YYYYMMDD)
        i_sled_to   TYPE d        "Latest  SLED (YYYYMMDD)
      RETURNING
        VALUE(r_response) TYPE string.

    "Returns batches expiring within the next N days for a material/plant.
    METHODS find_expiring_batches
      IMPORTING
        i_matnr  TYPE matnr
        i_werks  TYPE werks_d
        i_days   TYPE i           "Look-ahead window in days
      RETURNING
        VALUE(r_response) TYPE string.

    "Returns all batches already past their shelf life expiration date.
    METHODS find_expired_batches
      IMPORTING
        i_matnr  TYPE matnr
        i_werks  TYPE werks_d
      RETURNING
        VALUE(r_response) TYPE string.

ENDCLASS.

CLASS zcl_yaai_batch_tools IMPLEMENTATION.

  METHOD get_batch_header.
    "MCH1 = cross-plant batch header (holds VFDAT, HSDAT)
    "MCHA = plant-level batch (VFDAT not stored here)
    SELECT SINGLE matnr, charg, vfdat, hsdat, lwedt
      FROM mch1
      INTO @DATA(ls_mch1)
      WHERE matnr = @i_matnr
        AND charg = @i_charg.

    IF sy-subrc <> 0.
      r_response = |Batch { i_charg } not found for material { i_matnr }.|.
      RETURN.
    ENDIF.

    "Confirm the batch exists in the given plant
    SELECT SINGLE matnr FROM mcha
      INTO @DATA(lv_check)
      WHERE matnr = @i_matnr
        AND werks = @i_werks
        AND charg = @i_charg.

    IF sy-subrc <> 0.
      r_response = |Batch { i_charg } for material { i_matnr } is not assigned to plant { i_werks }.|.
      RETURN.
    ENDIF.

    "Read shelf life config from MARA
    SELECT SINGLE mhdrz, mhdlp, iprkz
      FROM mara
      INTO @DATA(ls_mara)
      WHERE matnr = @i_matnr.

    r_response = |Batch: { ls_mch1-charg }\n|.
    r_response = |{ r_response }Material: { ls_mch1-matnr }\n|.
    r_response = |{ r_response }Plant: { i_werks }\n|.
    r_response = |{ r_response }Shelf Life Expiration Date (SLED): { ls_mch1-vfdat }\n|.
    r_response = |{ r_response }Manufacturing Date: { ls_mch1-hsdat }\n|.
    r_response = |{ r_response }Last Goods Movement: { ls_mch1-lwedt }\n|.
    r_response = |{ r_response }Minimum Remaining Shelf Life: { ls_mara-mhdrz } days\n|.
    r_response = |{ r_response }Total Shelf Life: { ls_mara-mhdlp } days\n|.
    r_response = |{ r_response }Batch Classification Active: { COND #( WHEN ls_mara-iprkz IS NOT INITIAL THEN 'Yes' ELSE 'No' ) }|.
  ENDMETHOD.


  METHOD get_batch_classification.
    "Resolve batch internal number from INOB (class type 023 = batch)
    DATA(lv_objek) = |{ i_matnr ALPHA = IN }{ i_charg ALPHA = IN }|.

    SELECT SINGLE cuobj
      FROM inob
      INTO @DATA(lv_cuobj)
      WHERE obtab = 'MCH1'
        AND klart = '023'
        AND objek = @lv_objek.

    IF sy-subrc <> 0.
      r_response = |No classification found for batch { i_charg } (material { i_matnr }).|.
      RETURN.
    ENDIF.

    "Get assigned classes via KSSK
    SELECT clint
      FROM kssk
      INTO TABLE @DATA(lt_kssk)
      WHERE objek = @lv_objek
        AND klart = '023'.

    DATA lt_classes TYPE TABLE OF string.
    LOOP AT lt_kssk INTO DATA(ls_kssk).
      SELECT SINGLE class
        FROM klah
        INTO @DATA(lv_class)
        WHERE clint = @ls_kssk-clint
          AND klart = '023'.
      IF sy-subrc = 0.
        APPEND lv_class TO lt_classes.
      ENDIF.
    ENDLOOP.

    "Get characteristic values from AUSP
    SELECT ausp~atinn, ausp~atwrt, ausp~atflv, cabn~atnam, cabnt~atbez
      FROM ausp
      INNER JOIN cabn  ON cabn~atinn  = ausp~atinn
      LEFT OUTER JOIN cabnt ON cabnt~atinn = ausp~atinn AND cabnt~spras = @sy-langu
      INTO TABLE @DATA(lt_chars)
      WHERE ausp~objek = @lv_cuobj
        AND ausp~mafid = 'O'
        AND ausp~klart = '023'.

    r_response = |Classification for batch { i_charg } (material { i_matnr }, plant { i_werks }):\n|.

    r_response = |{ r_response }Classes:\n|.
    LOOP AT lt_classes INTO DATA(lv_cls).
      r_response = |{ r_response }  { lv_cls }\n|.
    ENDLOOP.

    r_response = |{ r_response }Characteristics:\n|.
    LOOP AT lt_chars INTO DATA(ls_char).
      DATA(lv_value) = COND string(
        WHEN ls_char-atwrt IS NOT INITIAL THEN ls_char-atwrt
        WHEN ls_char-atflv <> 0           THEN |{ ls_char-atflv }|
        ELSE                                   'not maintained' ).
      DATA(lv_desc) = COND string(
        WHEN ls_char-atbez IS NOT INITIAL THEN ls_char-atbez
        ELSE                                   ls_char-atnam ).
      r_response = |{ r_response }  { ls_char-atnam } ({ lv_desc }) = { lv_value }\n|.
    ENDLOOP.
  ENDMETHOD.


  METHOD find_batches_by_sled.
    "MCH1 holds VFDAT cross-plant; filter by plant via JOIN with MCHA
    SELECT mch1~matnr, mch1~charg, mch1~vfdat, mch1~hsdat
      FROM mch1
      INNER JOIN mcha ON mcha~matnr = mch1~matnr
                     AND mcha~charg = mch1~charg
      INTO TABLE @DATA(lt_batches)
      WHERE mch1~matnr = @i_matnr
        AND mcha~werks  = @i_werks
        AND mch1~vfdat >= @i_sled_from
        AND mch1~vfdat <= @i_sled_to.

    IF lt_batches IS INITIAL.
      r_response = |No batches found for material { i_matnr } in plant { i_werks }|.
      r_response = |{ r_response } with SLED between { i_sled_from } and { i_sled_to }.|.
      RETURN.
    ENDIF.

    SORT lt_batches BY vfdat ASCENDING.

    r_response = |{ lines( lt_batches ) } batch(es) for material { i_matnr }, plant { i_werks }|.
    r_response = |{ r_response }, SLED { i_sled_from } to { i_sled_to }:\n|.

    LOOP AT lt_batches INTO DATA(ls_b).
      r_response = |{ r_response }  Batch { ls_b-charg }|.
      r_response = |{ r_response }  SLED: { ls_b-vfdat }|.
      r_response = |{ r_response }  Mfg: { ls_b-hsdat }\n|.
    ENDLOOP.
  ENDMETHOD.


  METHOD find_expiring_batches.
    DATA(lv_today) = sy-datum.
    DATA(lv_to)    = sy-datum + i_days.

    "MCH1 holds VFDAT cross-plant; filter by plant via JOIN with MCHA
    SELECT mch1~matnr, mch1~charg, mch1~vfdat, mch1~hsdat
      FROM mch1
      INNER JOIN mcha ON mcha~matnr = mch1~matnr
                     AND mcha~charg = mch1~charg
      INTO TABLE @DATA(lt_batches)
      WHERE mch1~matnr = @i_matnr
        AND mcha~werks  = @i_werks
        AND mch1~vfdat >= @lv_today
        AND mch1~vfdat <= @lv_to.

    IF lt_batches IS INITIAL.
      r_response = |No batches expiring within { i_days } days for material { i_matnr }|.
      r_response = |{ r_response } in plant { i_werks }.|.
      RETURN.
    ENDIF.

    SORT lt_batches BY vfdat ASCENDING.

    r_response = |{ lines( lt_batches ) } batch(es) expiring within { i_days } days|.
    r_response = |{ r_response } (today: { lv_today }, cutoff: { lv_to }):\n|.

    LOOP AT lt_batches INTO DATA(ls_b).
      DATA(lv_days_left) = ls_b-vfdat - lv_today.
      r_response = |{ r_response }  Batch { ls_b-charg }|.
      r_response = |{ r_response }  SLED: { ls_b-vfdat }|.
      r_response = |{ r_response }  ({ lv_days_left } days left)\n|.
    ENDLOOP.
  ENDMETHOD.


  METHOD find_expired_batches.
    DATA(lv_today) = sy-datum.

    SELECT mch1~matnr, mch1~charg, mch1~vfdat, mch1~hsdat
      FROM mch1
      INNER JOIN mcha ON mcha~matnr = mch1~matnr
                     AND mcha~charg = mch1~charg
      INTO TABLE @DATA(lt_batches)
      WHERE mch1~matnr = @i_matnr
        AND mcha~werks  = @i_werks
        AND mch1~vfdat  < @lv_today
        AND mch1~vfdat <> '00000000'.

    IF lt_batches IS INITIAL.
      r_response = |No expired batches found for material { i_matnr } in plant { i_werks }.|.
      RETURN.
    ENDIF.

    SORT lt_batches BY vfdat DESCENDING.

    r_response = |{ lines( lt_batches ) } expired batch(es) for material { i_matnr }|.
    r_response = |{ r_response } in plant { i_werks } (today: { lv_today }):\n|.

    LOOP AT lt_batches INTO DATA(ls_b2).
      DATA(lv_days_expired) = lv_today - ls_b2-vfdat.
      r_response = |{ r_response }  Batch { ls_b2-charg }|.
      r_response = |{ r_response }  SLED: { ls_b2-vfdat }|.
      r_response = |{ r_response }  ({ lv_days_expired } days ago)\n|.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
