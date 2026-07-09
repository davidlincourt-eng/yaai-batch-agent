*&---------------------------------------------------------------------*
*& Example 4c: Function Calling — Main report
*& Registers the calculator tools with Claude and sends a prompt.
*& Claude will automatically call add/multiply when it needs to compute.
*&
*& Prerequisites:
*&   - ZCL_YAAI_CALCULATOR and ZCL_YAAI_CALCULATOR_PROXY created (ex4a/b)
*&---------------------------------------------------------------------*
REPORT zyaai_ex4_func_call.

PARAMETERS:
  p_prompt TYPE c LENGTH 200 LOWER CASE OBLIGATORY
    DEFAULT 'What is 42 multiplied by 7? Also add 13 and 29.',
  p_model  TYPE c LENGTH 50  LOWER CASE
    DEFAULT 'claude-3-5-sonnet-20241022'.

CLASS lcl_app DEFINITION.
  PUBLIC SECTION.
    METHODS run.
    METHODS on_tool_call FOR EVENT on_tool_call OF ycl_aai_func_call_anthropic
      IMPORTING
        class_name
        method_name.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.

  METHOD run.

    DATA(lo_conn) = NEW ycl_aai_conn( i_api = yif_aai_const=>c_anthropic ).

    DATA(lo_claude) = NEW ycl_aai_anthropic(
      i_model        = p_model
      i_o_connection = lo_conn
    ).

    "System instructions: tell Claude it has calculator tools
    DATA lv_sys TYPE string.
    lv_sys = |You are a helpful math assistant.\n|.
    lv_sys = |{ lv_sys }When the user asks for arithmetic, use the provided tools to compute results accurately.\n|.
    lv_sys = |{ lv_sys }Always include the numeric result in your final answer.|.
    lo_claude->set_system_instructions( lv_sys ).

    "Register tools: proxy class handles STRING->P conversion
    DATA(lo_tools) = NEW ycl_aai_func_call_anthropic( ).

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

    lo_claude->bind_tools( lo_tools ).

    "Send the user prompt — Claude may call tools, get results, then reply
    lo_claude->chat(
      EXPORTING
        i_message    = p_prompt
      IMPORTING
        e_t_response = DATA(lt_response)
    ).

    WRITE: / '=== Claude (with tools) ==='.
    LOOP AT lt_response INTO DATA(lv_line).
      WRITE: / lv_line.
    ENDLOOP.

  ENDMETHOD.

  METHOD on_tool_call.
    "Fired each time Claude invokes a tool — useful for logging/audit
    WRITE: / |  [tool called] { class_name }->{ method_name }|.
  ENDMETHOD.

ENDCLASS.

INITIALIZATION.
  %_p_prompt_%_app_%-text = 'Prompt'.
  %_p_model_%_app_%-text  = 'Model'.

START-OF-SELECTION.
  NEW lcl_app( )->run( ).
