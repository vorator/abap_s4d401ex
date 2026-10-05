*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

class lcl_passenger_flight definition .

  public section.

    data carrier_id    type /dmo/carrier_id       read-only.
    data connection_id type /dmo/connection_id    read-only.
    data flight_date   type /dmo/flight_date      read-only.

    methods constructor
      importing
        i_carrier_id    type /dmo/carrier_id
        i_connection_id type /dmo/connection_id
        i_flight_date   type /dmo/flight_date.

    types:
      begin of st_connection_details,
        airport_from_id type /dmo/airport_from_id,
        airport_to_id   type /dmo/airport_to_id,
        departure_time  type /dmo/flight_departure_time,
        arrival_time    type /dmo/flight_departure_time,
        duration        type i,
      end of st_connection_details.

    types
      tt_flights type standard table of ref to lcl_passenger_flight with default key.

    methods: get_connection_details
      returning
        value(r_result) type st_connection_details.

    methods get_free_seats
      returning
        value(r_result) type i.

    methods get_description returning value(r_result) type string_table.

    class-methods class_constructor.

    class-methods get_flights_by_carrier
      importing
        i_carrier_id    type /dmo/carrier_id
      returning
        value(r_result) type tt_flights.

  protected section.

  private section.
    types: begin of st_flights_buffer,
             carrier_id     type /lrn/passflight-carrier_id,
             connection_id  type /lrn/passflight-connection_id,
             flight_date    type /lrn/passflight-flight_date,
             plane_type_id  type /lrn/passflight-plane_type_id,
             seats_max      type /lrn/passflight-seats_max,
             seats_occupied type /lrn/passflight-seats_occupied,
             seats_free     type i,
             price          type /lrn/passflight-price,
             currency_code  type /lrn/passflight-currency_code,
           end of st_flights_buffer.

    types:
      begin of st_connection_buffer,
        carrier_id      type /dmo/carrier_id,
        connection_id   type /dmo/connection_id,
        airport_from_id type /dmo/airport_from_id,
        airport_to_id   type /dmo/airport_to_id,
        departure_time  type /dmo/flight_departure_time,
        arrival_time    type /dmo/flight_departure_time,
        timzone_from    type timezone,
        timzone_to      type timezone,
        duration        type i,

      end of st_connection_buffer.

*    class-data flights_buffer type table of st_flights_buffer.
    class-data flights_buffer type hashed table of st_flights_buffer
      with unique key carrier_id connection_id flight_date
      with non-unique sorted key sk_carrier components carrier_id.

    data planetype type /dmo/plane_type_id.
    data seats_max  type /dmo/plane_seats_max.
    data seats_occ  type /dmo/plane_seats_occupied.
    data seats_free type i.

    data price type /dmo/flight_price.
    data connection_details type st_connection_details.

    class-data currency type /dmo/currency_code value 'EUR'.

*    class-data connections_buffer type table of st_connection_buffer.
    class-data connections_buffer type hashed table of st_connection_buffer
      with unique key carrier_id connection_id.


endclass.

class lcl_passenger_flight implementation.

  method class_constructor.

    data(today) = cl_abap_context_info=>get_system_date( ).

    select
      from /lrn/connection as c
      left outer join /lrn/airport as f on c~airport_from_id = f~airport_id
      left outer join /lrn/airport as t on c~airport_to_id = t~airport_id
      fields  carrier_id,
              connection_id,
              airport_from_id,
              airport_to_id,
              departure_time,
              arrival_time,
              f~timzone as timezone_from,
              t~timzone as timezone_to,
              div(
                tstmp_seconds_between(
                  tstmp1 = dats_tims_to_tstmp(
                    date = @today,
                    time = c~departure_time,
                    tzone = f~timzone
                  ),
                  tstmp2 = dats_tims_to_tstmp(
                    date = @today,
                    time = c~arrival_time,
                    tzone = t~timzone
                  )
                ), 60 ) as duration
      into table @connections_buffer.

    loop at connections_buffer assigning field-symbol(<connection>).
*    loop at connections_buffer into data(connection).
      convert
        date today
        time <connection>-departure_time
        time zone <connection>-timzone_from
        into utclong data(departure_utclong).

      convert
        date today
        time <connection>-arrival_time
        time zone <connection>-timzone_to
        into utclong data(arrival_utclong).

      <connection>-duration = utclong_diff(
        high = arrival_utclong
        low = departure_utclong
      ) / 60.

*      modify connections_buffer from connection transporting duration.

    endloop.

  endmethod.

  method get_flights_by_carrier.

    if not line_exists( flights_buffer[ key sk_carrier components carrier_id = i_carrier_id ] ).
      select
        from /lrn/passflight
        fields  carrier_id,
                connection_id,
                flight_date,
                plane_type_id,
                seats_max,
                seats_occupied, seats_max - seats_occupied as seats_free,
                currency_conversion(
                  amount = price,
                  source_currency = currency_code,
                  target_currency = @currency,
                  exchange_rate_date = flight_date,
                  on_error = @sql_currency_conversion=>c_on_error-set_to_null ) as price,
                @currency as currency_code
        where carrier_id = @i_carrier_id
        appending table @flights_buffer.
    endif.

    r_result = value #(
      for <flight> in flights_buffer using key sk_carrier where ( carrier_id = i_carrier_id ) (
        new lcl_passenger_flight(
          i_carrier_id = <flight>-carrier_id
          i_connection_id = <flight>-connection_id
          i_flight_date = <flight>-flight_date
        )
      )
    ).

  endmethod.


  method constructor.

    try.
        data(flight_raw) = flights_buffer[
          carrier_id = i_carrier_id
          connection_id = i_connection_id
          flight_date = i_flight_date
         ].

      catch cx_sy_itab_line_not_found.

        select single
          from /lrn/passflight
          fields  plane_type_id,
                  seats_max,
                  seats_occupied,
                  seats_max - seats_occupied as seats_free,
                  currency_conversion(
                    amount = price,
                    source_currency = currency_code,
                    target_currency = @currency,
                    exchange_rate_date = flight_date,
                    on_error = @sql_currency_conversion=>c_on_error-set_to_null ) as price,
                  @currency as currency_code
          where carrier_id    = @i_carrier_id
            and connection_id = @i_connection_id
            and flight_date   = @i_flight_date
          into corresponding fields of @flight_raw.

    endtry.

    if flight_raw is not initial.
      me->carrier_id    = i_carrier_id.
      me->connection_id = i_connection_id.
      me->flight_date   = i_flight_date.

      planetype = flight_raw-plane_type_id.
      seats_max = flight_raw-seats_max.
      seats_occ = flight_raw-seats_occupied.
      seats_free = flight_raw-seats_free.

      connection_details = corresponding #(
          connections_buffer[
            carrier_id = i_carrier_id
            connection_id = i_connection_id
           ]
        ).

* convert currencies
      try.
          cl_exchange_rates=>convert_to_local_currency(
            exporting
              date              = me->flight_date
              foreign_amount    = flight_raw-price
              foreign_currency  = flight_raw-currency_code
              local_currency    = currency
            importing
              local_amount      = me->price
          ).
        catch cx_exchange_rates.
          clear price.
      endtry.

    endif.
  endmethod.

  method get_connection_details.
    r_result = me->connection_details.
  endmethod.


  method get_free_seats.
    r_result = me->seats_free.
  endmethod.

  method get_description.

    data txt type string.
    txt = 'Flight &carrid& &connid& on &date& from &from& to &to&'(005).
    txt = replace( val = txt sub = '&carrid&' with = carrier_id ).
    txt = replace( val = txt sub = '&connid&' with = connection_id ).
    txt = replace( val = txt sub = '&date&' with = |{ flight_date date = user }| ).
    txt = replace( val = txt sub = '&from&' with = connection_details-airport_from_id ).
    txt = replace( val = txt sub = '&to&' with = connection_details-airport_to_id ).


    append txt to r_result.
    append |{ 'Planetype:'(006)      } { planetype  }                                     | to r_result.
    append |{ 'Maximum Seats:'(007)  } { seats_max  }                                     | to r_result.
    append |{ 'Occupied Seats:'(008) } { seats_occ }                                      | to r_result.
    append |{ 'Free Seats:'(009)     } { seats_free }                                     | to r_result.
    append |{ 'Ticket Price:'(010)   } { price currency = currency } { currency }         | to r_result.
    append |{ 'Duration:'(011)       } { connection_details-duration } { 'minutes'(112) } | to r_result.

  endmethod.

endclass.

class lcl_cargo_flight definition .

  public section.

    types: begin of st_connection_details,
             airport_from_id type /dmo/airport_from_id,
             airport_to_id   type /dmo/airport_to_id,
             departure_time  type /dmo/flight_departure_time,
             arrival_time    type /dmo/flight_departure_time,
             duration        type i,
           end of st_connection_details.

    types
       tt_flights type standard table of ref to lcl_cargo_flight with default key.

    data carrier_id    type /dmo/carrier_id     read-only.
    data connection_id type /dmo/connection_id  read-only.
    data flight_date   type /dmo/flight_date    read-only.

    methods constructor
      importing
        i_carrier_id    type /dmo/carrier_id
        i_connection_id type /dmo/connection_id
        i_flight_date   type /dmo/flight_date.

    methods get_connection_details
      returning
        value(r_result) type st_connection_details.

    methods
      get_free_capacity
        returning
          value(r_result) type /lrn/plane_actual_load.

    methods get_description
      returning
        value(r_result) type string_table.

    class-methods
      get_flights_by_carrier
        importing
          i_carrier_id    type /dmo/carrier_id
        returning
          value(r_result) type tt_flights.

  protected section.
  private section.

    types: begin of st_flights_buffer,
             carrier_id      type /dmo/carrier_id,
             connection_id   type /dmo/connection_id,
             flight_date     type /dmo/flight_date,
             plane_type_id   type /dmo/plane_type_id,
             maximum_load    type /lrn/plane_maximum_load,
             actual_load     type /lrn/plane_actual_load,
             load_unit       type /lrn/plane_weight_unit,
             airport_from_id type /dmo/airport_from_id,
             airport_to_id   type /dmo/airport_to_id,
             departure_time  type /dmo/flight_departure_time,
             arrival_time    type /dmo/flight_arrival_time,
           end of st_flights_buffer.

    types tt_flights_buffer type hashed table of st_flights_buffer
                            with unique key carrier_id connection_id flight_date.

    data connection_details type st_connection_details.

    data planetype type /dmo/plane_type_id.

    data maximum_load type /lrn/plane_maximum_load.
    data actual_load type /lrn/plane_actual_load.
    data load_unit    type /lrn/plane_weight_unit.

    class-data flights_buffer type tt_flights_buffer.

endclass.

class lcl_cargo_flight implementation.

  method get_flights_by_carrier.

    select
      from /lrn/cargoflight
      fields  carrier_id,
              connection_id,
              flight_date,
              plane_type_id,
              maximum_load,
              actual_load,
              load_unit,
              airport_from_id,
              airport_to_id,
              departure_time,
              arrival_time
      where carrier_id    = @i_carrier_id
      order by flight_date ascending
      into corresponding fields of table @flights_buffer.

    loop at flights_buffer into data(flight).
      append new lcl_cargo_flight( i_carrier_id    = flight-carrier_id
                                   i_connection_id = flight-connection_id
                                   i_flight_date   = flight-flight_date )
              to r_result.

    endloop.
  endmethod.

  method constructor.

    " Read buffer
    try.
        data(flight_raw) = flights_buffer[ carrier_id    = i_carrier_id
                                           connection_id = i_connection_id
                                           flight_date   = i_flight_date ].

      catch cx_sy_itab_line_not_found.
        " Read from database if data not found in buffer
        select single
          from /lrn/cargoflight
        fields plane_type_id, maximum_load, actual_load, load_unit,
               airport_from_id, airport_to_id, departure_time, arrival_time
         where carrier_id    = @i_carrier_id
           and connection_id = @i_connection_id
           and flight_date   = @i_flight_date
          into corresponding fields of @flight_raw.
    endtry.

    carrier_id    = i_carrier_id.
    connection_id = i_connection_id.
    flight_date   = i_flight_date.

    planetype = flight_raw-plane_type_id.
    maximum_load = flight_raw-maximum_load.
    actual_load = flight_raw-actual_load.
    load_unit = flight_raw-load_unit.

    connection_details = corresponding #( flight_raw ).

    connection_details-duration = ( connection_details-arrival_time
                                  - connection_details-departure_time )
                                  / 60.

  endmethod.


  method get_connection_details.
    r_result = me->connection_details.
  endmethod.


  method get_free_capacity.
    r_result = maximum_load - actual_load.
  endmethod.

  method get_description.

    append |Flight { carrier_id } { connection_id } on { flight_date date = user } | &&
           |from { connection_details-airport_from_id } to { connection_details-airport_to_id } | to r_result.
    append |Planetype:     { planetype } |                         to r_result.
    append |Maximum Load:  { maximum_load         } { load_unit }| to r_result.
    append |Free Capacity: { get_free_capacity( ) } { load_unit }| to r_result.

  endmethod.

endclass.

class lcl_carrier definition .

  public section.

    types t_output type string.
    types tt_output type standard table of t_output
                    with non-unique default key.

    data carrier_id type /dmo/carrier_id read-only.

    methods constructor
      importing
                i_carrier_id type /dmo/carrier_id
      raising   cx_abap_invalid_value.

    methods get_output returning value(r_result) type tt_output.

    methods find_passenger_flight
      importing
        i_airport_from_id type /dmo/airport_from_id
        i_airport_to_id   type /dmo/airport_to_id
        i_from_date       type /dmo/flight_date
        i_seats           type i
      exporting
        e_flight          type ref to lcl_passenger_flight
        e_days_later      type i.

    methods find_cargo_flight
      importing
        i_airport_from_id type /dmo/airport_from_id
        i_airport_to_id   type /dmo/airport_to_id
        i_from_date       type /dmo/flight_date
        i_cargo           type /lrn/plane_actual_load
      exporting
        e_flight          type ref to lcl_cargo_flight
        e_days_later      type i.

  protected section.
  private section.

    data name          type string.
    data currency_code type /dmo/currency_code ##needed.

    data passenger_flights type lcl_passenger_flight=>tt_flights.

    data cargo_flights type lcl_cargo_flight=>tt_flights.

    methods get_average_free_seats
      returning value(r_result) type i.

endclass.

class lcl_carrier implementation.

  method constructor.

    me->carrier_id = i_carrier_id.

    select single
      from /lrn/carrier
    fields concat_with_space( carrier_id, name,1 ), currency_code
     where carrier_id = @i_carrier_id
     into ( @me->name, @me->currency_code ).

    if sy-subrc <> 0.
      raise exception type cx_abap_invalid_value.
    endif.

    passenger_flights =
        lcl_passenger_flight=>get_flights_by_carrier(
              i_carrier_id    = i_carrier_id ).

    cargo_flights =
        lcl_cargo_flight=>get_flights_by_carrier(
              i_carrier_id    = i_carrier_id ).

  endmethod.

  method get_output.

    append |{ 'Carrier Name:'(001) }       { me->name } | to r_result.
    append |{ 'Passenger Flights:'(002) }  { lines( passenger_flights ) } | to r_result.
    append |{ 'Average free seats:'(003) } { get_average_free_seats(  ) } | to r_result.
    append |{ 'Cargo Flights:'(004) }      { lines( cargo_flights     ) } | to r_result.

  endmethod.

  method find_cargo_flight.

    e_days_later = 99999999.

    loop at me->cargo_flights into data(flight)
        where table_line->flight_date >= i_from_date.

      data(connection_details) = flight->get_connection_details(  ).

      if connection_details-airport_from_id = i_airport_from_id
       and connection_details-airport_to_id = i_airport_to_id
       and flight->get_free_capacity(  ) >= i_cargo.

        data(days_later) =  flight->flight_date - i_from_date.

        if days_later < e_days_later. "earlier than previous one?
          e_flight = flight.
          e_days_later = days_later.
        endif.
      endif.

    endloop.
  endmethod.

  method find_passenger_flight.

    e_days_later = 99999999.

    loop at me->passenger_flights into data(flight)
         where table_line->flight_date >= i_from_date.

      data(connection_details) = flight->get_connection_details(  ).

      if connection_details-airport_from_id = i_airport_from_id
       and connection_details-airport_to_id = i_airport_to_id
       and flight->get_free_seats( ) >= i_seats.
        data(days_later) = flight->flight_date - i_from_date.

        if days_later < e_days_later. "earlier than previous one?
          e_flight = flight.
          e_days_later = days_later.
        endif.
      endif.

    endloop.

  endmethod.

  method get_average_free_seats.

    r_result = reduce #(
      init i = 0
      for flight in passenger_flights
        next i = i + flight->get_free_seats( )
    ) / lines( passenger_flights ).

  endmethod.

endclass.
