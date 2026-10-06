*"* use this source file for your ABAP unit test classes
class ltcl_find_flights definition final for testing
  duration medium
  risk level harmless.

  private section.

    class-data the_carrier type ref to lcl_carrier.
    class-data some_flight_data type /lrn/cargoflight.

    methods:
      test_find_cargo_flight for testing raising cx_static_check.

    class-methods class_setup.

endclass.

class ltcl_find_flights implementation.

  method test_find_cargo_flight.

    the_carrier->find_cargo_flight(
      exporting
        i_airport_from_id = some_flight_data-airport_from_id
        i_airport_to_id = some_flight_data-airport_to_id
        i_from_date = some_flight_data-flight_date
        i_cargo = 1
      importing
        e_flight = data(flight)
        e_days_later = data(days_later)
    ).

    cl_abap_unit_assert=>assert_bound(
      act = flight
      msg = |Method find_cargo_flight does not return a result|
    ).

    cl_abap_unit_assert=>assert_equals(
      act = days_later
      exp = 0
      msg = |Method find_cargo_flight returns wrong result|
    ).
  endmethod.

  method class_setup.

    select single
      from /lrn/cargoflight
      fields carrier_id, connection_id, flight_date, airport_from_id, airport_to_id
      where maximum_load - actual_load >= 1
      into corresponding fields of @some_flight_data.

    if sy-subrc <> 0.
      cl_abap_unit_assert=>fail( |No suitable data in the table /lrn/cargoflight| ).
    endif.

    try.
        "the_carrier = new lcl_carrier( i_carrier_id = some_flight_data-carrier_id ).
        the_carrier = lcl_carrier=>get_instance( i_carrier_id = some_flight_data-carrier_id ).
      catch cx_abap_invalid_value.
        cl_abap_unit_assert=>fail( |Unable to instantiate lcl_carrier| ).
      catch cx_abap_auth_check_exception.
        cl_abap_unit_assert=>fail( `Unable to instantiate lcl_carrier` ).
    endtry.

  endmethod.

endclass.
