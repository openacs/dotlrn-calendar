<?xml version="1.0"?>

<queryset>
<rdbms><type>oracle</type><version>8.1.6</version></rdbms>

<fullquery name="dotlrn_calendar::clone.copy_cal_item_types">
  <querytext>

    insert into cal_item_types
    (item_type_id, calendar_id, type)
    select acs_object_id_seq.nextval, :calendar_id, type
    from cal_item_types
    where calendar_id = :old_calendar_id

  </querytext>
</fullquery>

</queryset>
