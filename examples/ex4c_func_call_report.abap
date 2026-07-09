*&---------------------------------------------------------------------*
*& Example 4c: Function Calling — Main report
*& Registers the calculator tools with the model and sends a prompt.
*& The model will automatically call add/multiply when it needs to compute.
*&
*& Prerequisites:
*&   - ZCL_YAAI_CALCULATOR and ZCL_YAAI_CALCULATOR_PROXY created (ex4a/b)
*&   - ZCL_YAAI_AICORE_CONN active in SE24
*&---------------------------------------------------------------------*
REPORT zyaai_ex4_func_call.

PARAMETERS:
  p_prompt TYPE c LENGTH 200 LOWER CASE OBLIGATORY
    DEFAULT 'What is 42 multiplied by 7? Also add 13 and 29.'.

CLASS lcl_app DEFINITION.
  PUBLIC SECTION.
    METHODS run.
    METHODS on_tool_call FOR EVENT on_tool_call OF ycl_aai_func_call_openai
      IMPORTING
        class_name
        method_name.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.

  METHOD run.

    DATA lo_conn TYPE REF TO ycl_aai_conn.
    TRY.
        lo_conn = NEW zcl_yaai_aicore_conn( )->get_connection( ).
      CATCH cx_root INTO DATA(lx).
        WRITE: / |Connection error: { lx->get_text( ) }|.
        RETURN.
    ENDTRY.

    DATA(lo_ai) = NEW ycl_aai_openai(
      i_model        = 'gpt-4.1'
      i_o_connection = lo_conn
    ).
    lo_ai->use_completions( abap_true ).

    "System instructions: tell the model it has calculator tools
    DATA lv_sys TYPE string.
    lv_sys = |You are a helpful math assistant.\n|.
    lv_sys = |{ lv_sys }When the user asks for arithmetic, use the provided tools to compute results accurately.\n|.
    lv_sys = |{ lv_sys }Always include the numeric result in your final answer.|.
    lo_ai->set_system_instructions( lv_sys ).

    "Register tools: proxy class handles STRING->P conversion
    DATA(lo_tools) = NEW ycl_aai_func_call_openai( ).
    SET HANDLER me->on_tool_call FOR lo_tools.

    lo_tools->add_methods( VALUE #(
      ( proxy_class = 'ZCL_YAAI_CALCULATOR_PROXY'
        class_name  = 'ZCL_YAAI_CALCULATOR'
        method_name = 'ADD'
        description = 'Add two numbers. Use this for addition.' )
      ( proxy_class = 'ZCL_YAAI_CALCULATOR_PROXY'
        class_name  = 'ZCL_YAAI_CALCULATOR'
        method_name = 'MULTIPLY'
        description = 'Multiply two numbers. Use this for multiplication.' )
    ) ).

    lo_ai->bind_tools( lo_tools ).

    lo_ai->chat(
      EXPORTING
        i_message    = p_prompt
      IMPORTING
        e_t_response = DATA(lt_response)
    ).

    WRITE: / '=== Response (with tools) ==='.
    LOOP AT lt_response INTO DATA(lv_line).
      WRITE: / lv_line.
    ENDLOOP.

  ENDMETHOD.

  METHOD on_tool_call.
    WRITE: / |  [tool called] { class_name }->{ method_name }|.
  ENDMETHOD.

ENDCLASS.

INITIALIZATION.
  %_p_prompt_%_app_%-text = 'Prompt'.

START-OF-SELECTION.
  NEW lcl_app( )->run( ).
