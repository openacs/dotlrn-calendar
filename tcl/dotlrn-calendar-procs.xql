<?xml version="1.0"?>

<queryset>

<fullquery name="dotlrn_calendar::add_applet_to_community.copy_cal_item_types">
  <querytext>

    insert into cal_item_types
    (item_type_id, calendar_id, type)
    select acs_object_id_seq.nextval, :group_calendar_id, type
    from cal_item_types
    where calendar_id = :old_calendar_id

  </querytext>
</fullquery>

</queryset>