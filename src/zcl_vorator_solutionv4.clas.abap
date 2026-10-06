**********************************************************************
* The goal of this scenario is to improve performance by buffering all available data and reduce database queries
* ex02: correction of the number of seats (incorrect attribute reading)
* ex03: correction of the next available flight (incorrect calculation)
* ex05: only one query is executed against the DB and the result is buffered
* ex06: correction of incorrect attribute type assignment (carrier_id and connection_id swap)
* ex07: added calculation for the flight duration
* ex10: implemented an left outer join to unify queries into a single result structure
* ex11-12: calculations moved within the SQL statements
* ex14: improvement of the db access by eliminating redundant queries ("reduce" usage)
* ex15: field symbol usage to reduce overhead
* ex16: table types converted to hashed and sorted to improve performance (field-symbol required)
* ex17: usage of 2nd key on hashed table
* ex18: adding security with CDS access control
* ex19: applying inheritance to improve modulation
* ex21: applying interface
* ex23: factory method
* ex24: exceptions with objects

class zcl_vorator_solutionv4 definition
  public
  final
  create public.

  public section.
    interfaces if_oo_adt_classrun.

  protected section.
  private section.
endclass.



class zcl_vorator_solutionv4 implementation.


  method if_oo_adt_classrun~main.

    constants c_carrier_id type /dmo/carrier_id value 'LH'.
*    constants c_carrier_id type /dmo/carrier_id value 'UA'.

    try.
        data(carrier) = lcl_carrier=>get_instance( i_carrier_id = c_carrier_id ).
        data(carrier2) = lcl_carrier=>get_instance( i_carrier_id = c_carrier_id ).


        out->write( name = `Carrier Overview`
                    data = carrier->get_output(  ) ).
*      catch cx_abap_invalid_value into data(exc_inv).
*        "out->write( |Carrier { c_carrier_id } does not exist| ).
*        out->write( exc_inv->get_text( ) ).
*      catch cx_abap_auth_check_exception into data(exc_auth).
*        "out->write( |No authorization to display carrier { c_carrier_id }| ).
*        out->write( exc_auth->get_text( ) ).
      catch zcx_vorator_failed into data(exc_fail).
        out->write( exc_fail->get_text( ) ).
    endtry.

    if carrier is bound.
      out->write(  `--------------------------------------------------` ).

      "Find a passenger flight from Frankfurt to New York
      "starting as soon as possible
      "with at least 5 free seats
      data(today) = cl_abap_context_info=>get_system_date( ).

      carrier->find_passenger_flight(
         exporting
           i_airport_from_id = 'FRA'
           i_airport_to_id   = 'JFK'
           i_from_date       = today
           i_seats           = 5
         importing
           e_flight =     data(pass_flight)
           e_days_later = data(days_later)
               ).

      if pass_flight is bound.
        out->write( name = |Found a suitable passenger flight in { days_later } days:|
                    data = pass_flight->get_output( ) ).
      else.
        out->write( data = `No passenger flight found` ).
      endif.

      out->write(  `--------------------------------------------------` ).

      "Find a cargo flight from Frankfurt to New York
      "starting as soon as possible
      "with at least 1200 KG free capacity
      carrier->find_cargo_flight(
         exporting
           i_airport_from_id = 'FRA'
           i_airport_to_id   = 'JFK'
           i_from_date       = today
           i_cargo           = 1200
         importing
           e_flight =     data(cargo_flight)
           e_days_later = data(days_later2)
               ).

      if cargo_flight is bound.
        out->write( name = |Found a suitable cargo flight in { days_later2 } days:|
                    data = cargo_flight->get_output( ) ).
      else.
        out->write( data = `No cargo flight found` ).
      endif.

    endif.

  endmethod.
endclass.
