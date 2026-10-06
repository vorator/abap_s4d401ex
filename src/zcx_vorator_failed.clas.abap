class zcx_vorator_failed definition
  public
  inheriting from cx_static_check
  final
  create public .

  public section.

    interfaces if_t100_message .
    interfaces if_t100_dyn_msg .

    data carrier_id type /dmo/carrier_id read-only.

    constants:
      begin of carrier_not_exist,
        msgid TYPE symsgid VALUE 'ZVORATOR_MESSAGES',
        msgno TYPE symsgno VALUE '010',
        attr1 type scx_attrname value 'CARRIER_ID',
        attr2 type scx_attrname value '',
        attr3 type scx_attrname value '',
        attr4 type scx_attrname value '',
      end of carrier_not_exist.

    constants:
      begin of carrier_no_read_auth,
        msgid TYPE symsgid VALUE 'ZVORATOR_MESSAGES',
        msgno TYPE symsgno VALUE '020',
        attr1 type scx_attrname value 'CARRIER_ID',
        attr2 type scx_attrname value '',
        attr3 type scx_attrname value '',
        attr4 type scx_attrname value '',
      end of carrier_no_read_auth.

    methods constructor
      importing
        !textid     like if_t100_message=>t100key optional
        !previous   like previous optional
        carrier_id  like carrier_id optional.

  protected section.
  private section.
endclass.



class zcx_vorator_failed implementation.


  method constructor ##ADT_SUPPRESS_GENERATION.

    super->constructor(
    previous = previous
    ).

    clear me->textid.

    if textid is initial.
      if_t100_message~t100key = if_t100_message=>default_textid.
    else.
      if_t100_message~t100key = textid.
    endif.

    if carrier_id is not initial.
      me->carrier_id = carrier_id.
    endif.

  endmethod.
endclass.
